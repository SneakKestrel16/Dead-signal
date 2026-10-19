# Story scare-events/008 (TR-scare-008, TR-scare-009; design/gdd/scare-events.md rules 16-18, 26; ADR-0013 §1,
# §4, §5). ScareAudio with fake inputs: the diegetic sound sits at the true origin on ScareSFX, a stinger plays
# only on a Major, one tick later, at stinger_max_db_rel over the bed reference, ducking writes only Ambience
# and ScareDuck, and the stinger and scare-master scales write only their own bus and never move timing.
extends GdUnitTestSuite

const ORIGIN := Vector3(4.0, 1.0, -7.0)
const DUCKED: Array[StringName] = [&"Ambience", &"ScareDuck"]
## Buses scare audio must never write (gameplay cues, callouts and the rest of the tree).
const NEVER: Array[StringName] = [&"Master", &"SFX", &"GameplayCues", &"GameplayCuesOccluded", &"WorldSFX",
	&"WorldSFXOccluded", &"Voice", &"ProximityVoice", &"UI", &"Music", &"ScareSFX"]

var _knobs: Knobs
var _catalogue: ScareCatalogue
## [bus, db] of every write, in order.
var _writes: Array = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_catalogue = ScareCatalogue.load_shipped()
	_writes = []


func _write(bus: StringName, db: float) -> void:
	_writes.append([bus, db])


func _audio() -> ScareAudio:
	var a: ScareAudio = auto_free(ScareAudio.new(_catalogue, _knobs, _write))
	add_child(a)
	return a


func _payload(id: StringName, intensity: int) -> Dictionary:
	return {"scare": id, "scope": ScareEntry.Scope.SHARED, "origin": ORIGIN, "intensity": intensity}


func _last(bus: StringName) -> float:
	for i in range(_writes.size() - 1, -1, -1):
		if _writes[i][0] == bus:
			return _writes[i][1]
	return NAN


func _tick_s() -> float:
	return 1.0 / _knobs.net.sim_tick_hz


func test_major_scare_plays_at_origin_then_stinger_one_tick_later_at_cap() -> void:
	var a := _audio()
	a.on_scare(1, _payload(&"door_burst", ScareEntry.Intensity.MAJOR))
	assert_int(a.diegetic().size()).is_equal(1)
	var p := a.diegetic()[0]
	assert_vector(p.global_position).is_equal(ORIGIN)
	assert_str(String(p.bus)).is_equal("ScareSFX")
	assert_float(p.max_distance).is_equal(_catalogue.entry(&"door_burst").audible_range_m)
	assert_int(a.stingers().size()).is_equal(0) # rule 17: never at the origin sound's tick
	a.advance(_tick_s() * 0.5)
	assert_int(a.stingers().size()).is_equal(0)
	a.advance(_tick_s() * 0.6)
	assert_int(a.stingers().size()).is_equal(1)
	var s := a.stingers()[0]
	assert_str(String(s.bus)).is_equal("Stinger")
	assert_float(s.volume_db).is_less_equal(_knobs.scare.stinger_max_db_rel)
	assert_float(s.volume_db).is_equal(_knobs.scare.stinger_max_db_rel)


func test_minor_scare_plays_origin_sound_and_no_stinger() -> void:
	var a := _audio()
	a.on_scare(1, _payload(&"slammed_door", ScareEntry.Intensity.MINOR))
	a.advance(1.0)
	assert_int(a.diegetic().size()).is_equal(1)
	assert_int(a.stingers().size()).is_equal(0)


func test_gated_major_delivered_as_minor_has_no_stinger() -> void:
	var a := _audio()
	a.on_scare(1, _payload(&"door_burst", ScareEntry.Intensity.MINOR))
	a.advance(1.0)
	assert_int(a.stingers().size()).is_equal(0)


func test_bad_or_unknown_payload_plays_nothing() -> void:
	var a := _audio()
	a.on_scare(1, {"scare": &"no_such", "origin": ORIGIN, "intensity": ScareEntry.Intensity.MAJOR})
	a.on_scare(1, {"scare": &"door_burst", "origin": "x", "intensity": ScareEntry.Intensity.MAJOR})
	a.advance(1.0)
	assert_int(a.diegetic().size()).is_equal(0)
	assert_int(a.stingers().size()).is_equal(0)


func test_gameplay_cue_ducks_only_ambience_and_scare_duck_then_releases() -> void:
	var a := _audio()
	a.on_scare(1, _payload(&"door_burst", ScareEntry.Intensity.MAJOR))
	_writes = []
	a.on_sound(2, {"pos": ORIGIN, "set": &"lunge_cue"})
	a.advance(_knobs.scare.duck_attack_s * 0.5)
	assert_float(_last(&"Ambience")).is_equal_approx(_knobs.scare.duck_db * 0.5, 0.01)
	a.advance(_knobs.scare.duck_attack_s * 0.5)
	for bus in DUCKED:
		assert_float(_last(bus)).is_equal_approx(_knobs.scare.duck_db, 0.001)
	a.advance(PlaceholderAudio.BEEP_S + _knobs.scare.duck_release_s + 0.01)
	for bus in DUCKED:
		assert_float(_last(bus)).is_equal_approx(0.0, 0.001)
	for w: Array in _writes:
		assert_bool(w[0] in DUCKED).override_failure_message("wrote %s" % w[0]).is_true()


func test_stun_events_hold_duck_for_release_time() -> void:
	var a := _audio()
	a.on_stun(1, {})
	a.advance(_knobs.scare.duck_attack_s + 0.001)
	a.advance(_knobs.scare.duck_release_s - _knobs.scare.duck_attack_s - 0.01)
	assert_float(a.duck_level_db()).is_equal_approx(_knobs.scare.duck_db, 0.001)
	a.advance(0.02 + _knobs.scare.duck_release_s)
	assert_float(a.duck_level_db()).is_equal_approx(0.0, 0.001)


func test_scales_write_only_their_bus_and_never_move_stinger_timing() -> void:
	var a := _audio()
	assert_float(_last(&"Stinger")).is_equal(0.0) # defaults: no settings store, full scale
	assert_float(_last(&"Scare")).is_equal(0.0)
	a.stinger_scale = 0.5
	a.scare_scale = 0.25
	assert_float(_last(&"Stinger")).is_equal_approx(linear_to_db(0.5), 0.0001)
	assert_float(_last(&"Scare")).is_equal_approx(linear_to_db(0.25), 0.0001)
	a.on_scare(1, _payload(&"door_burst", ScareEntry.Intensity.MAJOR))
	a.advance(_tick_s() * 0.5)
	assert_int(a.stingers().size()).is_equal(0)
	a.advance(_tick_s() * 0.6)
	assert_int(a.stingers().size()).is_equal(1)
	assert_float(a.stingers()[0].volume_db).is_equal(_knobs.scare.stinger_max_db_rel) # level is the bus's job
	a.on_sound(2, {"pos": ORIGIN, "set": &"lunge_cue"})
	a.advance(1.0)
	for w: Array in _writes:
		assert_bool(w[0] in NEVER).override_failure_message("wrote %s" % w[0]).is_false()


func test_a_recording_scare_emits_its_caption_and_a_door_burst_none() -> void:
	var a := _audio()
	var got: Array[String] = []
	a.captioned.connect(func(t: String) -> void: got.append(t))
	a.on_scare(1, _payload(&"recording_room", ScareEntry.Intensity.MINOR))
	a.on_scare(1, _payload(&"door_burst", ScareEntry.Intensity.MAJOR))
	assert_array(got).contains_exactly([ScareAudio.CAPTIONS[&"recording_room"]])
