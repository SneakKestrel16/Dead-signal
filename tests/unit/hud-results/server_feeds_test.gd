extends GdUnitTestSuite
## Story hud-results/011 (design/ux/hud.md H3, H4, H8, H9; interaction-patterns P3, P10; ADR-0004 §5): the
## round roster feed, the hold end reason feed, HoldService's reason hook, and the HudModel / InteractionHud
## handlers they drive.

const SERVER_PEER := 1
const MONSTER := 1
const ANA := 2
const BEN := 3
const DT := 0.05

var _knobs: Knobs
var _router: ClientEventRouter
var _display: MatchDisplay
var _model: HudModel
var _tick := 0
var _loaded: Array[int] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_router = ClientEventRouter.new()
	_display = MatchDisplay.new(_knobs)
	_model = HudModel.new(_display, _knobs, _router)
	_tick = 10
	_loaded = []


func _deliver(tick: int, entries: Array) -> void:
	var bytes := EventBatch.build(tick, 0, [], [], Vector3.ZERO, null, -1, entries)
	_router.on_packet(SERVER_PEER, bytes)
	_display.receive(bytes)


func _now() -> int:
	return _tick


func _loaded_ids() -> Array[int]:
	return _loaded


func _info(token: String) -> Dictionary:
	var pid := token.trim_prefix("t").to_int()
	return {"player_id": pid, "name": "Name%d" % pid}


func _roster() -> Roster:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	return Roster.lock(PackedStringArray(["t1", "t2", "t3", "t4", "t5"]), _info, "s", 1, _knobs, RotationQueue.new(),
			rng)


# --- RosterFeed (H4) ---

func test_roster_feed_sends_survivor_names_once_per_loaded_survivor_and_never_to_the_shapeshifter() -> void:
	var r := _roster()
	var survivors: Array[int] = []
	var monster := -1
	for id in r.player_ids():
		if r.entry(id).role == Roster.SHAPESHIFTER:
			monster = id
		else:
			survivors.append(id)
	var feed := RosterFeed.new(r, survivors, _loaded_ids)
	var s := survivors[0]
	assert_array(feed.entries(s)).override_failure_message("not before the map-loaded report").is_empty()
	_loaded.assign(r.player_ids())
	var e := feed.entries(s)
	assert_int(e.size()).is_equal(1)
	assert_str(e[0][0]).is_equal(EventBatch.ROSTER)
	var names: Dictionary = e[0][1]["survivors"]
	assert_array(names.keys()).contains_exactly_in_any_order(survivors)
	assert_bool(names.has(monster)).is_false()
	assert_str(names[s]).is_equal("Name%d" % s)
	assert_array(feed.entries(s)).override_failure_message("sent once").is_empty()
	assert_int(feed.entries(s, true).size()).override_failure_message("a rejoin gets it again").is_equal(1)
	assert_array(feed.entries(monster)).is_empty()
	assert_array(feed.entries(monster, true)).is_empty()


func test_model_takes_the_roster_entry_as_names_and_ignores_a_bad_one() -> void:
	_deliver(20, [[EventBatch.ROSTER, {"survivors": {ANA: "Ana", BEN: "Ben"}}]])
	assert_str(_model.name_of(ANA)).is_equal("Ana")
	assert_int(_model.roster().size()).is_equal(2)
	_deliver(21, [[EventBatch.ROSTER, {"survivors": {"x": 3}}]])
	_deliver(22, [[EventBatch.ROSTER, {"survivors": [ANA]}]])
	assert_int(_model.roster().size()).is_equal(2)


# --- Activation countdown (H3) from WorldProgress's ACTIVATION_KEY entry ---

func test_activation_entry_drives_the_countdown_and_paused() -> void:
	var evac := _knobs.objectives.evac_activation_s
	var hz := _knobs.net.sim_tick_hz
	_deliver(100, [[EventBatch.PROGRESS, {"key": WorldProgress.ACTIVATION_KEY, "at": Vector3.ZERO, "progress": 0.25,
		"rate": 1.0 / evac, "paused": false}]])
	assert_bool(_model.activation()["paused"]).is_false()
	assert_float(_model.activation()["remaining_s"]).is_equal_approx(0.75 * evac, 1e-4)
	_display.receive(SnapshotCodec.encode(100 + hz, [] as Array[Dictionary]))
	assert_float(_model.activation()["remaining_s"]).override_failure_message("runs between entries") \
			.is_equal_approx(0.75 * evac - 1.0, 1e-4)
	_deliver(100 + hz, [[EventBatch.PROGRESS, {"key": WorldProgress.ACTIVATION_KEY, "at": Vector3.ZERO,
		"progress": 0.5, "rate": 0.0, "paused": true}]])
	_display.receive(SnapshotCodec.encode(100 + 3 * hz, [] as Array[Dictionary]))
	assert_bool(_model.activation()["paused"]).is_true()
	assert_float(_model.activation()["remaining_s"]).override_failure_message("paused does not run") \
			.is_equal_approx(0.5 * evac, 1e-4)
	_deliver(100 + 4 * hz, [[EventBatch.PROGRESS, {"key": 5, "at": Vector3.ZERO, "progress": 0.9, "rate": 1.0,
		"paused": false}]])
	assert_float(_model.activation()["remaining_s"]).override_failure_message("a hold bar is not the countdown") \
			.is_equal_approx(0.5 * evac, 1e-4)
	_deliver(100 + 5 * hz, [[EventBatch.PROGRESS, {"key": WorldProgress.ACTIVATION_KEY, "end": true}]])
	assert_bool(_model.activation().is_empty()).is_true()


# --- HoldReasonFeed and HoldService's reason hook (H8/H9) ---

func test_reason_feed_sends_a_known_reason_to_the_actor_only_this_tick() -> void:
	var feed := HoldReasonFeed.new(_now)
	feed.note(ANA, &"range")
	feed.note(BEN, &"released") ## the client knows; not sent
	assert_array(feed.entries(BEN)).is_empty()
	assert_array(feed.entries(ANA)).is_equal([[EventBatch.HOLD_END, {"reason": &"range"}]])
	assert_array(feed.entries(ANA)).override_failure_message("sent once").is_empty()
	feed.note(ANA, &"in_use")
	_tick += 1
	assert_array(feed.entries(ANA)).override_failure_message("a stale reason is dropped").is_empty()


class Item extends Interactable:
	func eligible(_actor: int) -> bool:
		return true

	func start_progress_s() -> float:
		return 0.0

	func on_complete(_actor: int) -> void:
		pass

	func on_cancel(_actor: int, _progress_s: float, _reason: StringName) -> void:
		pass


var _frames: Dictionary = {}
var _centres: Dictionary = {}
var _ends: Array = []


func _players() -> Array:
	return [ANA, BEN]


func _frames_of(actor: int) -> Array:
	return _frames.get(actor, [])


func _centre_of(actor: int) -> Vector3:
	return _centres.get(actor, Vector3.ZERO)


func _yes(_a: int, _i: Interactable) -> bool:
	return true


func _aim_zero(_a: int) -> int:
	return 0


func _note_end(actor: int, reason: StringName) -> void:
	_ends.append([actor, reason])


func _press(actor: int, down: bool) -> void:
	var f := InputFrame.new()
	f.interact = down
	f.interact_target = 0
	_frames[actor] = [f]


func test_hold_service_reports_a_lock_refusal_and_a_range_cancel() -> void:
	_ends = []
	var holds := HoldService.new(_knobs, _players, _frames_of, _centre_of, _yes, _aim_zero)
	holds.on_end = _note_end
	var item := Item.new()
	item.duration_s = 5.0
	item.range_m = 1.5
	item.lock_key = &"k"
	holds.register(item)
	_press(ANA, true)
	holds.server_tick(1)
	assert_bool(holds.hold_of(ANA).is_empty()).is_false()
	_press(BEN, true)
	holds.server_tick(2)
	assert_array(_ends).is_equal([[BEN, &"in_use"]])
	_centres[ANA] = Vector3(10.0, 0.0, 0.0)
	holds.server_tick(3)
	assert_array(_ends).is_equal([[BEN, &"in_use"], [ANA, &"range"]])
	_centres[BEN] = Vector3(10.0, 0.0, 0.0)
	_press(BEN, false)
	holds.server_tick(4)
	_press(BEN, true)
	holds.server_tick(5)
	assert_array(_ends[-1]).is_equal([BEN, &"too_far"])


# --- InteractionHud shows the reason, whichever arrives first ---

func _interaction() -> InteractionHud:
	var bar: PredictedHoldBar = auto_free(PredictedHoldBar.new())
	bar.setup(_knobs)
	return auto_free(InteractionHud.new(InputGlyphs.new(), InputContextStack.new(), bar,
			func() -> Dictionary: return {}))


func test_reason_after_the_refusal_replaces_not_now() -> void:
	var hud := _interaction()
	hud.on_hold_ended(&"refused")
	assert_str(hud.label_text()).is_equal("Not now")
	hud.on_hold_end(0, {"reason": &"in_use"})
	assert_str(hud.label_text()).is_equal("In use")


func test_reason_before_the_cancel_is_used_by_it() -> void:
	var hud := _interaction()
	hud.on_hold_end(0, {"reason": &"range"})
	assert_str(hud.label_text()).override_failure_message("waits for the bar").is_equal("")
	hud.on_hold_ended(&"cancelled")
	assert_str(hud.label_text()).is_equal("Moved away")
	hud.step(InteractionHud.CAUSE_S + DT)
	hud.on_hold_ended(&"cancelled")
	assert_str(hud.label_text()).override_failure_message("a reason is used once").is_equal("Interrupted")


func test_unknown_or_malformed_reason_is_ignored() -> void:
	var hud := _interaction()
	hud.on_hold_ended(&"cancelled")
	hud.on_hold_end(0, {"reason": &"ineligible"})
	hud.on_hold_end(0, {"reason": "range"})
	hud.on_hold_end(0, {})
	assert_str(hud.label_text()).is_equal("Interrupted")
