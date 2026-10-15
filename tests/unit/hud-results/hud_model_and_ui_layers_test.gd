extends GdUnitTestSuite
## Story hud-results/001 (ADR-0014 §1, §3-§6): the full InputContextStack, UiLayers and HudModel.
## HudModel is fed by router handlers and the own snapshot entry only; phase and clock come from MatchDisplay.

const SERVER_PEER := 1

var _knobs: Knobs
var _router: ClientEventRouter
var _display: MatchDisplay
var _model: HudModel
var _fired: Array = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_router = ClientEventRouter.new()
	_display = MatchDisplay.new(_knobs)
	_model = HudModel.new(_display, _knobs, _router)
	_fired = []


func _deliver(tick: int, entries: Array) -> void:
	var bytes := EventBatch.build(tick, 0, [], [], Vector3.ZERO, null, -1, entries)
	_router.on_packet(SERVER_PEER, bytes)
	_display.receive(bytes)


func _snap(tick: int) -> void:
	_display.receive(SnapshotCodec.encode(tick, [] as Array[Dictionary]))


func _count(name: String) -> void:
	_fired.append(name)


# --- UiLayers ---

func test_ui_layers_match_the_adr_numbers_and_scare_layers_use_them() -> void:
	assert_array([UiLayers.WORLD_MARKERS, UiLayers.HUD, UiLayers.SCARE_FX, UiLayers.CAPTIONS, UiLayers.OVERLAY,
		UiLayers.MODAL]).is_equal([1, 2, 3, 4, 10, 20])
	assert_int(ScarePresenter.SCARE_FX_LAYER).is_equal(UiLayers.SCARE_FX)


# --- InputContextStack ---

func test_every_context_has_the_adr_flags() -> void:
	var want := {
		InputContextStack.Ctx.GAMEPLAY: [true, true, true],
		InputContextStack.Ctx.WHEEL: [true, false, false],
		InputContextStack.Ctx.OVERLAY: [false, false, false],
		InputContextStack.Ctx.MENU: [false, false, false],
		InputContextStack.Ctx.MODAL: [false, false, false],
	}
	for ctx: int in want:
		var s := InputContextStack.new()
		if ctx != InputContextStack.Ctx.GAMEPLAY:
			s.push(ctx, null)
		assert_array([s.allows_move(), s.allows_look(), s.allows_actions()]).is_equal(want[ctx])


func test_round_start_resets_to_gameplay_and_round_end_to_menu_dropping_stale_contexts() -> void:
	var s := InputContextStack.new()
	s.push(InputContextStack.Ctx.OVERLAY, null)
	s.push(InputContextStack.Ctx.MODAL, null)
	s.reset(InputContextStack.Ctx.GAMEPLAY)
	assert_int(s.top()).is_equal(InputContextStack.Ctx.GAMEPLAY)
	s.push(InputContextStack.Ctx.OVERLAY, null)
	s.reset(InputContextStack.Ctx.MENU)
	assert_int(s.top()).is_equal(InputContextStack.Ctx.MENU)
	assert_bool(s.allows_actions()).is_false()
	s.reset(InputContextStack.Ctx.GAMEPLAY)
	assert_bool(s.allows_actions()).is_true()


func test_stale_pop_is_an_error_and_changes_nothing() -> void:
	var s := InputContextStack.new()
	s.push(InputContextStack.Ctx.OVERLAY, null)
	s.push(InputContextStack.Ctx.MODAL, null)
	s.pop(InputContextStack.Ctx.OVERLAY)
	assert_int(s.top()).is_equal(InputContextStack.Ctx.MODAL)
	s.pop(InputContextStack.Ctx.MODAL)
	s.pop(InputContextStack.Ctx.OVERLAY)
	assert_int(s.top()).is_equal(InputContextStack.Ctx.GAMEPLAY)
	s.pop(InputContextStack.Ctx.GAMEPLAY) # the base is never popped
	assert_int(s.top()).is_equal(InputContextStack.Ctx.GAMEPLAY)


func test_pop_restores_remembered_focus_else_lower_default() -> void:
	var view: SubViewport = auto_free(SubViewport.new())
	add_child(view)
	var a: Button = Button.new() # focused before the overlay opens
	var d: Button = Button.new() # the overlay's default
	var b: Button = Button.new() # focused inside the overlay when the modal opens
	var c: Button = Button.new() # the modal's default
	for n: Button in [a, d, b, c]:
		view.add_child(n)
	a.grab_focus()
	var s := InputContextStack.new()
	s.viewport = view
	s.push(InputContextStack.Ctx.OVERLAY, d) # remembers a
	b.grab_focus()
	s.push(InputContextStack.Ctx.MODAL, c) # remembers b
	c.grab_focus()
	s.pop(InputContextStack.Ctx.MODAL)
	assert_object(view.gui_get_focus_owner()).is_same(b)
	s.push(InputContextStack.Ctx.MODAL, c)
	b.hide() # the remembered control is no longer visible: the overlay's default takes the focus
	s.pop(InputContextStack.Ctx.MODAL)
	assert_object(view.gui_get_focus_owner()).is_same(d)
	s.pop(InputContextStack.Ctx.OVERLAY)
	assert_object(view.gui_get_focus_owner()).is_same(a)


func test_cursor_flag_per_context() -> void:
	assert_bool(InputContextStack.wants_cursor(InputContextStack.Ctx.GAMEPLAY)).is_false()
	assert_bool(InputContextStack.wants_cursor(InputContextStack.Ctx.WHEEL)).is_false()
	for c: int in [InputContextStack.Ctx.OVERLAY, InputContextStack.Ctx.MENU, InputContextStack.Ctx.MODAL]:
		assert_bool(InputContextStack.wants_cursor(c)).is_true()


# --- HudModel ---

func test_phase_and_clock_are_read_from_match_display() -> void:
	assert_int(_model.phase()).is_equal(-1)
	_deliver(10, [[&"RoundPhaseChanged", {"phase": MatchFlow.Phase.INFILTRATION}]])
	assert_int(_model.phase()).is_equal(MatchFlow.Phase.INFILTRATION)
	_snap(10 + 60 * 5)
	assert_float(_model.time_remaining_s()).is_equal_approx(_knobs.match_flow.round_duration_s - 5.0, 0.01)


func test_objective_event_updates_lines_and_fires_objectives_changed() -> void:
	_model.objectives_changed.connect(_count.bind("obj"))
	_deliver(5, [[&"ObjectiveProgressChanged", {"objective": 3, "state": 1, "carrier": -1}]])
	_deliver(6, [[&"ObjectiveProgressChanged", {"objective": 3, "state": 2, "carrier": 4, "at": Vector3.ONE}]])
	var lines := _model.objective_lines()
	assert_int(lines.size()).is_equal(1)
	assert_int(lines[0]["state"]).is_equal(2)
	assert_int(lines[0]["carrier"]).is_equal(4)
	assert_array(_fired).is_equal(["obj", "obj"])
	# An install-alert payload (no objective key) is not an objective line.
	_deliver(7, [[&"ObjectiveProgressChanged", {"centre": Vector3.ZERO, "radius_m": 3.0, "duration_s": 5.0}]])
	assert_int(_model.objective_lines().size()).is_equal(1)
	assert_array(_fired).is_equal(["obj", "obj"])


func test_survivor_life_events_fill_the_roster_and_fire_roster_changed() -> void:
	_model.roster_changed.connect(_count.bind("roster"))
	_deliver(5, [[&"SurvivorDowned", {"survivor": 2, "bleed_out_s": 30.0}]])
	assert_int(_model.roster_state(2)).is_equal(HudModel.LIFE_DOWNED)
	_deliver(6, [[&"SurvivorRescued", {"survivor": 2}], [&"SurvivorEscaped", {"survivor": 3}],
		[&"SurvivorEliminated", {"survivor": 4, "reason": 1}]])
	assert_int(_model.roster_state(2)).is_equal(HudModel.LIFE_HEALTHY)
	assert_int(_model.roster_state(3)).is_equal(HudModel.LIFE_ESCAPED)
	assert_int(_model.roster_state(4)).is_equal(HudModel.LIFE_ELIMINATED)
	assert_int(_model.roster_state(9)).is_equal(HudModel.LIFE_UNKNOWN)
	assert_int(_model.roster().size()).is_equal(3)
	assert_int(_fired.size()).is_equal(4)
	_deliver(7, [[&"SurvivorDowned", {"survivor": "bad"}]]) # untrusted payload ignored
	assert_int(_fired.size()).is_equal(4)


func test_own_snapshot_entry_fires_own_state_changed() -> void:
	_model.own_state_changed.connect(_count.bind("own"))
	_model.on_own_body({"own": true, "gait": 2, "hold_net_id": 7, "hold_elapsed_ticks": 12})
	assert_int(_model.own_state()["gait"]).is_equal(2)
	assert_array(_fired).is_equal(["own"])
	_model.on_own_body({"own": true, "gait": 2, "hold_net_id": 7, "hold_elapsed_ticks": 12})
	assert_array(_fired).is_equal(["own"]) # unchanged: no signal


func test_cooldowns_report_remaining_and_zero_when_unknown() -> void:
	_model.cooldowns_changed.connect(_count.bind("cd"))
	assert_float(_model.cooldown_remaining_s(&"lunge")).is_equal(0.0)
	_snap(100)
	_model.on_cooldown(100, {"ability": &"lunge", "remaining_s": 4.0})
	assert_array(_fired).is_equal(["cd"])
	assert_float(_model.cooldown_remaining_s(&"lunge")).is_equal_approx(4.0, 0.001)
	_snap(100 + 60)
	assert_float(_model.cooldown_remaining_s(&"lunge")).is_equal_approx(3.0, 0.02)
	_snap(100 + 60 * 10)
	assert_float(_model.cooldown_remaining_s(&"lunge")).is_equal(0.0)
	_model.on_cooldown(100, {"ability": 5, "remaining_s": "x"}) # bad payload ignored
	assert_array(_fired).is_equal(["cd"])


func test_callout_adds_a_feed_line_and_fires_feed_line_added() -> void:
	var got: Array[Dictionary] = []
	_model.feed_line_added.connect(func(l: Dictionary) -> void: got.append(l))
	_deliver(5, [[EventBatch.CALLOUT, {"line": &"danger", "identity": 3, "origin": Vector3.ZERO,
		"gesture": false, "voice": &"C2"}]])
	assert_int(got.size()).is_equal(1)
	assert_str(got[0]["line"]).is_equal("danger")
	assert_int(_model.feed_lines().size()).is_equal(1)
	_deliver(6, [[EventBatch.CALLOUT, {"line": 5}]]) # bad payload ignored
	assert_int(got.size()).is_equal(1)


func test_ping_makes_a_marker_that_expires_and_fires_marker_changed() -> void:
	var ids: Array[int] = []
	_model.marker_changed.connect(func(id: int) -> void: ids.append(id))
	var life := _knobs.ticks(_knobs.ping.ping_lifetime_s)
	_deliver(50, [[EventBatch.PING, {"kind": 0, "point": Vector3(1, 0, 2), "item": -1, "type": &"",
		"identity": -1, "from": 2, "handle": 7}]])
	assert_array(ids).is_equal([7])
	assert_int(_model.markers().size()).is_equal(1)
	_snap(50 + life - 1)
	assert_int(_model.markers().size()).is_equal(1)
	_snap(50 + life)
	assert_int(_model.markers().size()).is_equal(0)
	_deliver(51, [[EventBatch.PING, {"handle": "x"}]]) # bad payload ignored
	assert_array(ids).is_equal([7])
