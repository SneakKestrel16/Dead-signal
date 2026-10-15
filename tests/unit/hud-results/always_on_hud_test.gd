extends GdUnitTestSuite
## Story hud-results/002 (design/ux/hud.md H1-H6, Layout Zones, HUD States; ADR-0014 §5, §6): the
## always-on survivor HUD reads HudModel only, never takes focus or clicks, and keeps its safe margins.

const SERVER_PEER := 1
const OWN := 7
const OTHER := 8

var _knobs: Knobs
var _router: ClientEventRouter
var _display: MatchDisplay
var _model: HudModel
var _hud: AlwaysOnHud


func before_test() -> void:
	_knobs = Knobs.load_all()
	_router = ClientEventRouter.new()
	_display = MatchDisplay.new(_knobs)
	_model = HudModel.new(_display, _knobs, _router)
	_hud = auto_free(AlwaysOnHud.new(_model, OWN))
	add_child(_hud)
	_hud.size = Vector2(1920, 1080)


func _deliver(tick: int, entries: Array) -> void:
	var bytes := EventBatch.build(tick, 0, [], [], Vector3.ZERO, null, -1, entries)
	_router.on_packet(SERVER_PEER, bytes)
	_display.receive(bytes)


func _start() -> void:
	_deliver(100, [[&"RoundPhaseChanged", {"phase": MatchFlow.Phase.INFILTRATION}]])
	_display.receive(SnapshotCodec.encode(100, [] as Array[Dictionary]))
	_model.set_survivors({OWN: "Ana", OTHER: "Ben"})
	_hud.refresh()


func _texts(box: Container) -> Array[String]:
	var out: Array[String] = []
	for c in box.get_children():
		if (c as Label).visible:
			out.append((c as Label).text)
	return out


func _all_controls(n: Node, out: Array[Control]) -> Array[Control]:
	if n is Control:
		out.append(n)
	for c in n.get_children():
		_all_controls(c, out)
	return out


func test_every_hud_control_ignores_focus_and_mouse() -> void:
	_start()
	var controls := _all_controls(_hud, [] as Array[Control])
	assert_int(controls.size()).is_greater(5)
	for c in controls:
		assert_int(c.focus_mode).is_equal(Control.FOCUS_NONE)
		assert_int(c.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_hidden_before_the_round_then_clock_and_phase_follow_match_display() -> void:
	_hud.refresh()
	assert_bool(_hud.clock_plate.visible).is_false()
	_start()
	assert_bool(_hud.clock_plate.visible).is_true()
	var t := ceili(_display.time_remaining_s())
	assert_str(_hud.clock_label.text).is_equal("%02d:%02d" % [t / 60, t % 60])
	assert_str(_hud.phase_label.text).is_equal("INFILTRATION")
	_deliver(200, [[&"RoundPhaseChanged", {"phase": MatchFlow.Phase.EVACUATION}]])
	_hud.refresh()
	assert_str(_hud.phase_label.text).is_equal("EVACUATION")


func test_roster_shows_icon_and_word_and_show_roster_off_hides_it() -> void:
	_start()
	_deliver(150, [[&"SurvivorDowned", {"survivor": OTHER}]])
	_hud.refresh()
	assert_array(_texts(_hud.roster_box)).is_equal(["Ana  ● Healthy", "Ben  ✚ Downed"])
	assert_bool(_hud.roster_plate.visible).is_true()
	_hud.show_roster = false
	_hud.refresh()
	assert_bool(_hud.roster_plate.visible).is_false()


func test_checklist_counts_drives_and_names_the_carrier() -> void:
	_start()
	_deliver(150, [[&"ObjectiveProgressChanged", {"objective": SurvivorObjectives.DRIVE_ID,
		"state": SurvivorObjectives.DriveState.CARRIED, "carrier": OTHER, "discovered": true}]])
	_hud.refresh()
	assert_array(_texts(_hud.objectives_box)).is_equal(["Drives 1/2", "◆ Ben", "Fuses 0/2", "Terminal Locked"])
	assert_str(_texts(_hud.roster_box)[1]).is_equal("Ben  ● Healthy  ◆")


func test_activation_countdown_shows_paused_and_only_while_activating() -> void:
	_start()
	assert_bool(_hud.activation_label.visible).is_false()
	_deliver(150, [[&"ObjectiveProgressChanged", {"objective": SurvivorObjectives.TERMINAL_ID,
		"state": SurvivorObjectives.TerminalState.ACTIVATING, "discovered": true}]])
	_hud.refresh()
	assert_bool(_hud.activation_label.visible).is_true()
	assert_str(_hud.activation_label.text).is_equal("Activating")
	_model.on_activation(160, {"remaining_s": 9.2, "paused": false})
	_hud.refresh()
	assert_str(_hud.activation_label.text).is_equal("Activation 10 s")
	_model.on_activation(170, {"remaining_s": 9.2, "paused": true})
	_hud.refresh()
	assert_str(_hud.activation_label.text).is_equal("Paused")


func test_crosshair_hides_while_own_survivor_is_downed() -> void:
	_start()
	assert_bool(_hud.crosshair.visible).is_true()
	_deliver(150, [[&"SurvivorDowned", {"survivor": OWN}]])
	_hud.refresh()
	assert_bool(_hud.crosshair.visible).is_false()


func test_margins_hold_at_16_9_16_10_and_21_9() -> void:
	_start()
	for res: Vector2 in [Vector2(1920, 1080), Vector2(1920, 1200), Vector2(2560, 1080)]:
		_hud.size = res
		_hud.refresh()
		var safe := AlwaysOnHud.safe_rect(res)
		var m := AlwaysOnHud.margin_for(res)
		for plate: Control in [_hud.roster_plate, _hud.clock_plate, _hud.objectives_plate]:
			var r := plate.get_rect()
			assert_float(r.position.x - safe.position.x).is_greater_equal(m)
			assert_float(safe.end.x - r.end.x).is_greater_equal(m)
			assert_float(r.position.y).is_greater_equal(m)
	assert_object(AlwaysOnHud.safe_rect(Vector2(2560, 1080))).is_equal(Rect2(320, 0, 1920, 1080))
	assert_float(AlwaysOnHud.margin_for(Vector2(2560, 1080))).is_equal(64.0)
	assert_object(AlwaysOnHud.safe_rect(Vector2(1920, 1200))).is_equal(Rect2(0, 0, 1920, 1200))
	assert_float(AlwaysOnHud.margin_for(Vector2(1920, 1200))).is_equal(48.0)
