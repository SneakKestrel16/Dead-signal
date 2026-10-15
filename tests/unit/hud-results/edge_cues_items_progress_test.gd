extends GdUnitTestSuite
## Story hud-results/005 (hud.md H11, H13, H14; interaction-patterns P4, P8; ADR-0014, ADR-0015 §4):
## the edge cues (lunge chevron, transform arc, flinch-off pulse), the taser count and the world progress
## bars with their server provider.

const SERVER_PEER := 1
const SURVIVOR := 1
const MONSTER := 2

var _knobs: Knobs
var _listener := Transform3D.IDENTITY ## at the origin, facing -Z
var _flinch_on := false
var _cues: EdgeCues
## WorldProgress fakes: actor -> hold_of dictionary; net id -> item; the activation dictionary; the tick.
var _holds: Dictionary = {}
var _items: Dictionary = {}
var _activation: Dictionary = {}
var _tick := 0
var _offset_records: Array = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_listener = Transform3D.IDENTITY
	_flinch_on = false
	_cues = auto_free(EdgeCues.new(_knobs, _get_listener, _get_flinch_on))
	_holds = {}
	_items = {}
	_activation = {}
	_tick = 0
	_offset_records = []


func _get_listener() -> Transform3D:
	return _listener


func _get_flinch_on() -> bool:
	return _flinch_on


func _lunge_at(at: Vector3) -> void:
	_cues.on_sound(10, {"pos": at, "set": MonsterAbilities.CUE_SOUND})


func _major_scare(at: Vector3) -> void:
	_cues.on_scare(10, {"scare": &"x", "scope": 0, "origin": at, "intensity": ScareEntry.Intensity.MAJOR})


# --- H14 lunge chevron ---

func test_lunge_chevron_shows_at_19_m_and_not_at_21_m() -> void:
	assert_float(_knobs.ability.lunge_cue_radius_m).is_equal(20.0)
	_lunge_at(Vector3(19.0, 0.0, 0.0))
	assert_int(_cues.cues().size()).is_equal(1)
	_cues.clear()
	_lunge_at(Vector3(21.0, 0.0, 0.0))
	assert_int(_cues.cues().size()).is_equal(0)


func test_lunge_chevron_points_toward_the_source() -> void:
	_lunge_at(Vector3(19.0, 0.0, 0.0)) ## to the listener's right
	var c: Dictionary = _cues.cues()[0]
	assert_int(c["kind"]).is_equal(EdgeCues.Kind.LUNGE)
	assert_float(c["bearing_deg"]).is_equal_approx(90.0, 0.01)
	_cues.clear()
	_lunge_at(Vector3(0.0, 0.0, 10.0)) ## behind
	assert_float(absf(_cues.cues()[0]["bearing_deg"])).is_equal_approx(180.0, 0.01)
	_cues.size = Vector2(1920.0, 1080.0)
	assert_float(_cues.edge_point(90.0).x).is_greater(1920.0 / 2.0) ## right edge
	assert_float(_cues.edge_point(0.0).y).is_less(1080.0 / 2.0) ## top edge


func test_cue_fades_in_150_ms_holds_and_fades_out_300_ms() -> void:
	_lunge_at(Vector3(5.0, 0.0, 0.0))
	assert_float(_cues.cues()[0]["alpha"]).is_equal_approx(0.0, 0.001)
	_cues.advance(EdgeCues.IN_S)
	assert_float(_cues.cues()[0]["alpha"]).is_equal_approx(1.0, 0.001)
	_cues.advance(_knobs.ability.lunge_windup_s - EdgeCues.IN_S + EdgeCues.OUT_S / 2.0)
	assert_float(_cues.cues()[0]["alpha"]).is_equal_approx(0.5, 0.01)
	_cues.advance(EdgeCues.OUT_S)
	assert_int(_cues.cues().size()).is_equal(0)


func test_transform_arc_inside_distortion_radius_only_and_setting_off_hides_cues() -> void:
	var r := _knobs.borrowed_face.distortion_radius_m
	_cues.on_sound(1, {"pos": Vector3(0.0, 0.0, -(r - 1.0)), "set": BorrowedFace.DISTORTION_SOUND})
	_cues.on_sound(1, {"pos": Vector3(0.0, 0.0, -(r + 1.0)), "set": BorrowedFace.DISTORTION_SOUND})
	_cues.on_sound(1, {"pos": Vector3(1.0, 0.0, 0.0), "set": &"footstep"})
	assert_int(_cues.cues().size()).is_equal(1)
	assert_int(_cues.cues()[0]["kind"]).is_equal(EdgeCues.Kind.TRANSFORM)
	_cues.clear()
	_cues.cues_enabled = false
	_lunge_at(Vector3(5.0, 0.0, 0.0))
	assert_int(_cues.cues().size()).is_equal(0)


# --- I28 flinch-off pulse ---

func test_flinch_off_major_scare_shows_the_pulse_toward_the_origin() -> void:
	_major_scare(Vector3(-3.0, 0.0, 0.0))
	assert_int(_cues.cues().size()).is_equal(1)
	assert_int(_cues.cues()[0]["kind"]).is_equal(EdgeCues.Kind.PULSE)
	assert_float(_cues.cues()[0]["bearing_deg"]).is_equal_approx(-90.0, 0.01)


func test_no_pulse_with_flinch_on_for_minor_or_inside_a_lunge_cue() -> void:
	_flinch_on = true
	_major_scare(Vector3(-3.0, 0.0, 0.0))
	assert_int(_cues.cues().size()).is_equal(0)
	_flinch_on = false
	_cues.on_scare(1, {"origin": Vector3.ONE, "intensity": ScareEntry.Intensity.MINOR})
	_cues.on_scare(1, {"origin": "bad", "intensity": ScareEntry.Intensity.MAJOR})
	assert_int(_cues.cues().size()).is_equal(0)
	_lunge_at(Vector3(5.0, 0.0, 0.0)) ## rule 14: no flinch inside a wind-up, so no substitute either
	_major_scare(Vector3(-3.0, 0.0, 0.0))
	assert_int(_cues.cues().size()).is_equal(1)


func test_server_view_offset_path_is_unchanged_with_flinch_off() -> void:
	var bus := EventBus.new(_knobs.core.max_flush_rounds)
	var offset := ViewOffset.new()
	offset.setup(null, bus, null, _knobs)
	bus.subscribe(&"ViewOffsetChanged", _on_offset_changed)
	offset.set_flinch_enabled(SURVIVOR, false)
	var f := EvFlinchRequested.new()
	f.player = SURVIVOR
	f.target = Vector2(0.3, 0.0)
	bus.emit(f)
	bus.flush()
	assert_int(_offset_records.size()).is_equal(0) ## the server drops it, as before this story
	assert_that(offset.offset_of(SURVIVOR)).is_equal(Vector2.ZERO)
	_major_scare(Vector3(-3.0, 0.0, 0.0)) ## the client shows the pulse from the projected scare alone
	assert_int(_cues.cues().size()).is_equal(1)
	offset.set_flinch_enabled(SURVIVOR, true)
	bus.emit(f)
	bus.flush()
	assert_int(_offset_records.size()).is_equal(1)


func _on_offset_changed(_e: ServerEvent) -> void:
	_offset_records.append(true)


# --- H11 taser count ---

func test_taser_count_follows_the_charges_entry_in_the_same_batch() -> void:
	var router := ClientEventRouter.new()
	var taser: TaserCount = auto_free(TaserCount.new())
	router.subscribe(EventBatch.CHARGES, taser.on_charges)
	assert_bool(taser.visible).is_false()
	router.on_packet(SERVER_PEER, EventBatch.build(5, 0, [], [], Vector3.ZERO, null, -1,
			[[EventBatch.CHARGES, {"charges": 3}]]))
	assert_bool(taser.visible).is_true()
	assert_int(taser.count).is_equal(3)
	assert_str(taser.text).contains("3")
	router.on_packet(SERVER_PEER, EventBatch.build(6, 0, [], [], Vector3.ZERO, null, -1,
			[[EventBatch.CHARGES, {"charges": 2}]]))
	assert_int(taser.count).is_equal(2)
	assert_str(taser.text).contains("2")
	taser.on_charges(7, {"charges": "x"})
	assert_int(taser.count).is_equal(2)


# --- H13 world progress: server provider ---

func _hold_of(actor: int) -> Dictionary:
	return _holds.get(actor, {})


func _item_of(net_id: int) -> Interactable:
	return _items.get(net_id)


func _players() -> Array:
	return [SURVIVOR, MONSTER]


func _get_activation() -> Dictionary:
	return _activation


func _get_tick() -> int:
	return _tick


func _provider() -> WorldProgress:
	var survivors: Array[int] = [SURVIVOR]
	return WorldProgress.new(_knobs, survivors, _players, _hold_of, _item_of, _get_activation, _get_tick)


func _point(net_id: int, duration_s: float) -> Interactable:
	var p := _Point.new()
	p.net_id = net_id
	p.point = Vector3(1.0, 0.0, 2.0)
	p.duration_s = duration_s
	_items[net_id] = p
	return p


func test_provider_sends_a_hold_on_start_and_its_end_to_survivors_only() -> void:
	var wp := _provider()
	_point(7, 2.0)
	_tick = 1
	_holds[SURVIVOR] = {"net_id": 7, "elapsed_ticks": 15, "fake": false}
	var e := wp.entries(SURVIVOR)
	assert_int(e.size()).is_equal(1)
	assert_str(String(e[0][0])).is_equal(String(EventBatch.PROGRESS))
	assert_float(e[0][1]["progress"]).is_equal_approx(15.0 / (2.0 * _knobs.net.sim_tick_hz), 0.0001)
	assert_float(e[0][1]["rate"]).is_equal_approx(0.5, 0.0001)
	assert_bool(e[0][1]["paused"]).is_false()
	assert_array(wp.entries(MONSTER)).is_empty()
	_tick = 2
	_holds[SURVIVOR]["elapsed_ticks"] = 16
	assert_array(wp.entries(SURVIVOR)).is_empty() ## unchanged rate: nothing resent
	assert_int(wp.entries(SURVIVOR, true).size()).is_equal(1) ## a rejoin gets it in full
	_tick = 3
	_holds.erase(SURVIVOR)
	e = wp.entries(SURVIVOR)
	assert_int(e.size()).is_equal(1)
	assert_bool(e[0][1]["end"]).is_true()


func test_provider_skips_fake_hiding_and_instant_holds() -> void:
	var wp := _provider()
	_point(7, 2.0)
	_point(8, 0.0)
	var hide := HidingHold.new()
	hide.net_id = 9
	hide.duration_s = 1.0
	_items[9] = hide
	_tick = 1
	_holds[MONSTER] = {"net_id": 7, "elapsed_ticks": 0, "fake": true}
	_holds[SURVIVOR] = {"net_id": 8, "elapsed_ticks": 0, "fake": false}
	assert_array(wp.entries(SURVIVOR)).is_empty()
	_tick = 2
	_holds[SURVIVOR] = {"net_id": 9, "elapsed_ticks": 0, "fake": false} ## hiding progress would reveal the spot
	assert_array(wp.entries(SURVIVOR)).is_empty()


func test_provider_activation_pauses_with_rate_zero() -> void:
	var wp := _provider()
	var hz := float(_knobs.net.sim_tick_hz)
	_tick = 1
	_activation = {"at": Vector3(4.0, 0.0, 4.0), "ticks": int(hz * 3.0), "held": true}
	var e := wp.entries(SURVIVOR)
	assert_int(e[0][1]["key"]).is_equal(WorldProgress.ACTIVATION_KEY)
	assert_float(e[0][1]["rate"]).is_greater(0.0)
	_tick = 2
	_activation["held"] = false
	e = wp.entries(SURVIVOR)
	assert_bool(e[0][1]["paused"]).is_true()
	assert_float(e[0][1]["rate"]).is_equal(0.0)
	assert_float(e[0][1]["progress"]).is_equal_approx(3.0 / _knobs.objectives.evac_activation_s, 0.0001)


# --- H13 world progress: client bars ---

func test_bars_show_percent_and_paused_from_server_progress() -> void:
	var now := [10.0]
	var bars: WorldProgressBars = auto_free(WorldProgressBars.new(_knobs, func() -> float: return now[0]))
	bars.on_progress(10, {"key": 7, "at": Vector3.ONE, "progress": 0.25, "rate": 0.5, "paused": false})
	now[0] = 10.0 + _knobs.net.sim_tick_hz * 0.5 ## half a second later: 0.25 + 0.25
	assert_float(bars.progress_of(7)).is_equal_approx(0.5, 0.0001)
	assert_str(bars.text_of(7)).contains("50%")
	assert_str(bars.text_of(7)).not_contains("Paused")
	bars.on_progress(12, {"key": WorldProgress.ACTIVATION_KEY, "at": Vector3.ONE, "progress": 0.4, "rate": 0.0,
		"paused": true})
	assert_str(bars.text_of(WorldProgress.ACTIVATION_KEY)).contains("40%")
	assert_str(bars.text_of(WorldProgress.ACTIVATION_KEY)).contains("Paused")
	assert_int(bars.keys().size()).is_equal(2)
	bars.on_progress(13, {"key": 7, "end": true})
	bars.on_progress(13, {"key": 9, "at": "bad"})
	assert_array(bars.keys()).is_equal([WorldProgress.ACTIVATION_KEY])
	now[0] = 1000.0
	assert_float(bars.progress_of(WorldProgress.ACTIVATION_KEY)).is_equal_approx(0.4, 0.0001)


## A concrete objective-like interactable (ObjectivePoint is abstract).
class _Point extends Interactable:
	func eligible(_actor: int) -> bool:
		return true

	func start_progress_s() -> float:
		return 0.0

	func on_complete(_actor: int) -> void:
		pass

	func on_cancel(_actor: int, _progress_s: float, _reason: StringName) -> void:
		pass
