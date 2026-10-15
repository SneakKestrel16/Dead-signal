extends GdUnitTestSuite
## Story hud-results/006 (design/ux/hud.md S1-S6; ADR-0004 §5, ADR-0014 §6): MonsterHudFeed sends the
## shapeshifter's own HUD state to its peer only; HudModel turns it into S1-S6 values; ShapeshifterHud is
## instanced only once that state arrives, so a client fed every survivor-side entry holds no S node.

const SERVER_PEER := 1
const MONSTER := 7
const SURVIVORS: Array[int] = [2, 3]

var _knobs: Knobs
var _router: ClientEventRouter
var _display: MatchDisplay
var _model: HudModel
var _layer: CanvasLayer
## Fake server state the feed reads.
var _now := 0
var _ready: Array[int] = [0, 0, 0]
var _form_ready := 0
var _transform_end := -1
var _lock_end := -1
var _free := -1
var _obs: Dictionary[int, float] = {2: 0.0, 3: 0.0}


func before_test() -> void:
	_now = 0
	_ready = [0, 0, 0]
	_form_ready = 0
	_transform_end = -1
	_lock_end = -1
	_free = -1
	_obs = {2: 0.0, 3: 0.0}
	_knobs = Knobs.load_all()
	_router = ClientEventRouter.new()
	_display = MatchDisplay.new(_knobs)
	_model = HudModel.new(_display, _knobs, _router)
	_layer = auto_free(CanvasLayer.new())
	add_child(_layer)
	ShapeshifterHud.mount(_layer, _model, null)


func _tick() -> int:
	return _now


func _ready_of(a: int) -> int:
	return _ready[a]


func _form_ready_of() -> int:
	return _form_ready


func _transform_end_of() -> int:
	return _transform_end


func _lock_end_of(_p: int) -> int:
	return _lock_end


func _free_of(_p: int) -> int:
	return _free


func _obs_of(s: int) -> float:
	return _obs[s]


func _appearance_of(s: int) -> int:
	return s - 1


func _feed() -> MonsterHudFeed:
	return MonsterHudFeed.new(MONSTER, SURVIVORS, _tick, _ready_of, _form_ready_of, _transform_end_of, _lock_end_of,
			_free_of, _obs_of, _appearance_of)


## Delivers `entries` as the server batch of `tick`, and a snapshot of that tick (the client's clock).
func _deliver(tick: int, entries: Array) -> void:
	var bytes := EventBatch.build(tick, 0, [], [], Vector3.ZERO, null, -1, entries)
	if not bytes.is_empty():
		_router.on_packet(SERVER_PEER, bytes)
	_display.receive(SnapshotCodec.encode(tick, [] as Array[Dictionary]))


func _s_nodes(root: Node) -> Array[String]:
	var out: Array[String] = []
	for n in root.find_children("*", "", true, false):
		if RegEx.create_from_string("^S[1-7]").search(n.name) != null or n is ShapeshifterHud:
			out.append(String(n.name))
	return out


# --- MonsterHudFeed (server) ---

func test_feed_reaches_the_shapeshifter_only_and_only_on_change() -> void:
	var feed := _feed()
	for s in SURVIVORS:
		assert_array(feed.entries(s)).is_empty()
		assert_array(feed.entries(s, true)).is_empty()
	var first := feed.entries(MONSTER)
	assert_int(first.size()).is_equal(1)
	assert_str(String(first[0][0])).is_equal(String(EventBatch.MONSTER_HUD))
	assert_array(feed.entries(MONSTER)).override_failure_message("unchanged: nothing re-sent").is_empty()
	assert_int(feed.entries(MONSTER, true).size()).override_failure_message("a rejoin gets it in full").is_equal(1)
	_ready[MonsterAbilities.Ability.LUNGE] = 300
	var changed := feed.entries(MONSTER)
	assert_int(changed[0][1]["ready"][&"lunge"]).is_equal(300)
	assert_int(changed[0][1]["ready"][&"form"]).is_equal(0)


# --- HudModel values (AC 1: within 0.1 s of server state) ---

func test_cooldowns_stun_immunity_and_transform_match_server_ticks() -> void:
	var hz := _knobs.net.sim_tick_hz
	var feed := _feed()
	_now = 100
	_ready = [100 + 4 * hz, 100 + 20 * hz, 100]
	_form_ready = 100 + 2 * hz
	_transform_end = 100 + _knobs.ticks(_knobs.borrowed_face.transform_duration_s) / 2
	_lock_end = 100 + hz
	_free = 100 + 6 * hz
	_obs[2] = _knobs.borrowed_face.observe_time_s
	_obs[3] = _knobs.borrowed_face.observe_time_s / 4.0
	_deliver(_now, feed.entries(MONSTER))
	assert_bool(_model.is_shapeshifter()).is_true()
	assert_float(_model.cooldown_remaining_s(&"lunge")).is_equal_approx(4.0, 0.1)
	assert_float(_model.cooldown_remaining_s(&"false_signal")).is_equal_approx(20.0, 0.1)
	assert_float(_model.cooldown_remaining_s(&"blackout")).is_equal(0.0)
	assert_float(_model.cooldown_remaining_s(&"form")).is_equal_approx(2.0, 0.1)
	assert_float(_model.transform_progress()).is_equal_approx(0.5, 0.05)
	assert_float(_model.stun_remaining_s()).is_equal_approx(1.0, 0.1)
	assert_float(_model.immunity_remaining_s()).override_failure_message("stun first").is_equal(0.0)
	var faces := _model.faces()
	assert_array(faces.map(func(f: Dictionary) -> int: return f["survivor"])).is_equal([2, 3])
	assert_bool(faces[0]["available"]).is_true()
	assert_float(faces[1]["progress"]).is_equal_approx(0.25, 0.01)
	assert_bool(faces[1]["available"]).is_false()
	# One second later (only snapshots arrive): the stun is over, immunity runs, Lunge counts down.
	_deliver(100 + hz, [])
	assert_float(_model.cooldown_remaining_s(&"lunge")).is_equal_approx(3.0, 0.1)
	assert_float(_model.stun_remaining_s()).is_equal(0.0)
	assert_float(_model.immunity_remaining_s()).is_equal_approx(5.0, 0.1)


func test_install_alert_lives_its_duration() -> void:
	var hz := _knobs.net.sim_tick_hz
	_deliver(10, [[&"ObjectiveProgressChanged", {"centre": Vector3(1, 0, 2), "radius_m": 6.0, "duration_s": 5.0}]])
	assert_int(_model.install_alerts().size()).is_equal(1)
	assert_array(_model.objective_lines()).override_failure_message("an alert is not a checklist line").is_empty()
	_deliver(10 + 5 * hz, [])
	assert_array(_model.install_alerts()).is_empty()


func test_bad_monster_payload_is_ignored() -> void:
	_model.on_monster_hud(1, {"ready": {&"lunge": "x"}, "faces": [], "transform_end": -1, "stun_end": -1,
		"immune_end": -1})
	_model.on_monster_hud(1, {"ready": {}, "faces": [[2, 0.5]], "transform_end": -1, "stun_end": -1, "immune_end": -1})
	_model.on_monster_hud(1, {"ready": {}})
	assert_bool(_model.is_shapeshifter()).is_false()


# --- ShapeshifterHud (widgets) ---

func test_survivor_side_entries_never_instance_an_s_node() -> void:
	# Everything a survivor client is sent: catalog events, its own non-catalog entries, pings and callouts.
	_deliver(5, [[&"RoundPhaseChanged", {"phase": 1}], [&"ObjectiveProgressChanged", {"objective": 0, "state": 1,
		"carrier": -1}], [&"SurvivorDowned", {"survivor": 2}], [&"PlayerShocked", {"handle": 4}],
		[&"MonsterStunned", {"body": 4}], [EventBatch.CHARGES, {"charges": 3}], [EventBatch.HIDING, {"spot": 1}],
		[EventBatch.BLEED_RING, {"survivor": 2, "remaining_s": 10.0, "rate": 1.0}],
		[EventBatch.CALLOUT, {"line": &"here", "identity": 2, "origin": Vector3.ZERO, "gesture": false}],
		[EventBatch.PING, {"handle": 3, "from": 2, "point": Vector3.ONE}]])
	await get_tree().process_frame
	assert_bool(_model.is_shapeshifter()).is_false()
	assert_array(_s_nodes(_layer)).is_empty()


func test_shapeshifter_hud_shows_s1_s3_always_and_s4_s6_in_their_trigger_states() -> void:
	var hz := _knobs.net.sim_tick_hz
	var feed := _feed()
	_now = 50
	_deliver(_now, feed.entries(MONSTER))
	await get_tree().process_frame
	var hud := _layer.get_node(^"ShapeshifterHud") as ShapeshifterHud
	assert_object(hud).is_not_null()
	for n: String in ["S1FaceList", "S2Form", "S3Abilities"]:
		assert_bool((hud.find_child(n, true, false) as Control).visible).override_failure_message(n).is_true()
	for n: String in ["S4Transforming", "S5Stun", "S6InstallAlert"]:
		assert_bool((hud.find_child(n, true, false) as Control).is_visible_in_tree()) \
				.override_failure_message(n + " hidden when idle").is_false()
	var s3 := hud.kit
	assert_str(s3.ability_text(&"lunge")).contains(tr("Ready"))
	_ready[MonsterAbilities.Ability.LUNGE] = _now + 3 * hz
	_transform_end = _now + hz
	_lock_end = _now + hz
	_deliver(_now, feed.entries(MONSTER))
	await get_tree().process_frame
	assert_str(s3.ability_text(&"lunge")).contains("3.0")
	assert_bool((hud.find_child("S4Transforming", true, false) as Control).visible).is_true()
	assert_bool((hud.find_child("S5Stun", true, false) as Control).visible).is_true()
	assert_int(_layer.get_children().filter(func(c: Node) -> bool: return c is ShapeshifterHud).size()) \
			.override_failure_message("mounted once").is_equal(1)
