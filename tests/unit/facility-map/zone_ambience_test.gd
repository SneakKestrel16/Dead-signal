# Story facility-map/012: zone ambience and B3 footstep masking (research-facility.md Audio Direction and
# B3 row; ADR-0013 §6 zone ambience, §7 server-side footstep masking; TR-facility-008).
# AC 1 (ambience per zone, crossfading at volume borders): ZoneAmbience driven with fake listener positions on
# the shipped map. The audible result is a retained recording item (sign-off), not automated here.
# AC 2 (B3 masked radius from data; a listener just outside it does not hear a walk audible elsewhere): the
# real Footsteps module with MapQueries' scale, projected per listener by the real EventBatch.
extends GdUnitTestSuite

const SOURCE := 1
const LISTENER := 2
const MONSTER := 5
## Listener positions in volumes of three zones and the link corridor (shipped map boxes).
const IN_A1 := Vector3(5.0, 0.0, 34.0)
const IN_HS1 := Vector3(15.0, 0.0, 38.0)
const IN_B1 := Vector3(30.0, 0.0, 20.0)
const IN_C3 := Vector3(50.0, 0.0, 32.0)
const IN_B3 := Vector3(30.0, 0.0, 32.0)
## A point in no volume (outside the map footprint).
const NOWHERE := Vector3(-5.0, 0.0, -5.0)

var _map: MapData
var _amb: ZoneAmbience
var _beds: Dictionary[StringName, AudioStream]


func before_test() -> void:
	_map = MapData.load_map()
	_beds = ZoneAmbience.placeholder_beds()
	_amb = ZoneAmbience.new(_map, _beds)
	add_child(_amb)


func after_test() -> void:
	_amb.free()


## The player holding `zone`'s bed, or null.
func _player_of(zone: StringName) -> AudioStreamPlayer:
	for p in _amb.players:
		if p.stream == _beds[zone]:
			return p
	return null


func _settle(at: Vector3) -> void:
	for i in 10:
		_amb.step(at, ZoneAmbience.CROSSFADE_S / 5.0)


func test_settled_bed_plays_at_the_shipped_bank_gain() -> void:
	# Arrange: the shipped bank's per-zone gain (designer trim 2026-10-19, tools/audio/export.py FAMILY_TRIM_DB)
	_amb.gain_db = ZoneAmbience.bank_gains(SoundBank.load_shipped())
	assert_float(_amb.gain_db.get(&"A", 0.0)).is_less(0.0)

	# Act
	_settle(IN_A1)

	# Assert: full fade weight (0 dB) plus the bed's gain
	assert_float(_player_of(&"A").volume_db).is_equal_approx(_amb.gain_db[&"A"], 0.001)


func test_every_zone_of_the_map_has_a_distinct_placeholder_bed_on_the_ambience_bus() -> void:
	var seen := {}
	for v in _map.volumes:
		assert_object(_beds.get(v.zone)).override_failure_message("no bed: zone %s" % v.zone).is_not_null()
		seen[_beds[v.zone]] = true
	assert_int(seen.size()).is_equal(4)
	assert_int(AudioServer.get_bus_index(ZoneAmbience.BUS)).is_greater(0)
	for p in _amb.players:
		assert_str(p.bus).is_equal(String(ZoneAmbience.BUS))


func test_each_zone_plays_its_own_bed_at_full_level_and_nothing_else() -> void:
	for at: Vector3 in [IN_A1, IN_B1, IN_C3, IN_HS1]:
		_settle(at)
		var zone := _amb.active_zone
		var p := _player_of(zone)
		assert_object(p).override_failure_message("bed of %s not loaded" % zone).is_not_null()
		assert_float(p.volume_db).is_equal_approx(0.0, 0.001)
		for q in _amb.players:
			if q != p:
				assert_bool(is_inf(q.volume_db) and q.volume_db < 0.0).override_failure_message(
						"other bed audible in %s" % zone).is_true()
	assert_str(_amb.active_zone).is_equal("link")
	assert_str(_amb.active_volume).is_equal("H-S1")


func test_crossing_a_volume_border_crossfades_the_two_beds_over_crossfade_s() -> void:
	_settle(IN_A1)
	assert_str(_amb.active_zone).is_equal("A")
	_amb.step(IN_HS1, ZoneAmbience.CROSSFADE_S / 2.0)
	var a := _player_of(&"A")
	var link := _player_of(&"link")
	assert_float(a.volume_db).is_equal_approx(linear_to_db(0.5), 0.01)
	assert_float(link.volume_db).is_equal_approx(linear_to_db(0.5), 0.01)
	_amb.step(IN_HS1, ZoneAmbience.CROSSFADE_S / 2.0)
	assert_float(link.volume_db).is_equal_approx(0.0, 0.001)
	assert_bool(is_inf(a.volume_db)).is_true()


func test_turning_back_mid_fade_reverses_the_same_players_without_a_jump() -> void:
	_settle(IN_A1)
	_amb.step(IN_HS1, ZoneAmbience.CROSSFADE_S * 0.25)
	var a := _player_of(&"A")
	_amb.step(IN_A1, ZoneAmbience.CROSSFADE_S * 0.25)
	assert_object(_player_of(&"A")).is_same(a)
	assert_float(a.volume_db).is_equal_approx(0.0, 0.001) ## 0.75 back up to 1.0, never restarted from silence


func test_listener_outside_every_volume_keeps_the_last_bed() -> void:
	_settle(IN_C3)
	_settle(NOWHERE)
	assert_str(_amb.active_zone).is_equal("C")
	assert_float(_player_of(&"C").volume_db).is_equal_approx(0.0, 0.001)


func test_parked_listener_below_the_map_starts_no_bed() -> void:
	_settle(Vector3(1.0, -1000.0, 1.0)) ## x, z inside H-N1, as RoundClient parks the own body before spawn
	assert_str(_amb.active_zone).is_empty()
	for p in _amb.players:
		assert_bool(p.playing).is_false()


func test_overlay_names_the_active_zone_volume_and_bus() -> void:
	_settle(IN_B1)
	var text := _amb.debug_text()
	assert_str(text).contains("zone B").contains("volume B1").contains("bus Ambience")


# --- AC 2: B3 footstep masking (server send radius, ADR-0013 §7) ---

func test_only_b3_masks_footsteps_and_its_scale_is_below_one() -> void:
	var q := MapQueries.new(_map)
	for v in _map.volumes:
		var at := v.box.get_center()
		if v.id == &"B3":
			assert_float(q.footstep_radius_scale_at(at)).is_greater(0.0).is_less(1.0)
		else:
			assert_float(q.footstep_radius_scale_at(at)).override_failure_message(v.id).is_equal(1.0)
	assert_float(q.footstep_radius_scale_at(NOWHERE)).is_equal(1.0)


func test_map_with_a_scale_outside_zero_to_one_is_rejected() -> void:
	_map.volumes[0].footstep_radius_scale = 0.0
	assert_array(Array(_map.errors())).contains(["volume %s: footstep_radius_scale outside (0, 1]" % _map.volumes[0].id])


func test_listener_just_outside_the_masked_radius_hears_a_walk_in_b3_only_elsewhere() -> void:
	var knobs := Knobs.load_all()
	var q := MapQueries.new(_map)
	var sounds: Array[EventBatch.Sound] = []
	var emit := func(pos: Vector3, set_: StringName, radius: float, source: int) -> void:
		var s := EventBatch.Sound.new()
		s.position = pos
		s.sound_set = set_
		s.radius_m = radius
		s.source = source
		sounds.append(s)
	var steps := Footsteps.new(func(_p: int) -> MovementStep.Gait: return MovementStep.Gait.WALK,
			func(p: int) -> int: return p, emit)
	steps.radius_scale_at = q.footstep_radius_scale_at
	steps.setup(null, null, null, knobs)
	var body := CharacterBody3D.new()
	add_child(body)
	body.velocity = Vector3(knobs.controller.walk_speed, 0, 0)
	steps.add_player(SOURCE, body)
	var walk := knobs.controller.footstep_radius_walk_m
	var masked := walk * q.footstep_radius_scale_at(IN_B3)
	var outside := (masked + walk) / 2.0 ## past the masked radius, inside the unmasked one
	for at: Vector3 in [IN_B3, IN_B1]:
		body.global_position = at
		sounds.clear()
		for t in knobs.net.sim_tick_hz:
			steps.server_tick(t)
		assert_array(sounds).is_not_empty()
		var one: Array[EventBatch.Sound] = [sounds[0]]
		var heard := _heard(sounds[0].position + Vector3(0, 0, outside), one)
		if at == IN_B3:
			assert_float(sounds[0].radius_m).is_equal_approx(masked, 0.0001)
			assert_int(heard).override_failure_message("B3 walk heard at %.2f m" % outside).is_equal(0)
			assert_int(_heard(sounds[0].position + Vector3(0, 0, masked * 0.9), one)).is_equal(1)
		else:
			assert_float(sounds[0].radius_m).is_equal(walk)
			assert_int(heard).override_failure_message("B1 walk not heard at %.2f m" % outside).is_equal(1)
	body.free()


## Sounds the batch for LISTENER at `at` would carry.
func _heard(at: Vector3, sounds: Array[EventBatch.Sound]) -> int:
	var none: Array[ServerEvent] = []
	var bytes := EventBatch.build(1, LISTENER, none, sounds, at, HandleTable.new(), MONSTER)
	if bytes.is_empty():
		return 0
	return EventBatch.decode(bytes).entries.filter(func(e: Array) -> bool: return e[0] == EventBatch.SOUND).size()
