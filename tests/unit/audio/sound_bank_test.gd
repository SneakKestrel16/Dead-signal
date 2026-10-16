# Audio pass (design/game-brief.md "real sounds in place of the placeholders, and a mix"): the SoundBank
# (data/audio/sound_bank.tres, built by tools/audio/build_audio.py) covers every sound id the code requests,
# every entry plays on a bus of the layout, a disguise sounds exactly like the copied survivor (LB-6,
# borrowed-face.md rule 8), footsteps take the surface of their zone, an unknown id keeps the tone fallback,
# and the loudness table meets its targets with the stinger at most +6 dB over every bed (scare-events rule 26).
extends GdUnitTestSuite

const LOUDNESS := "res://production/qa/evidence/audio/loudness.md"
## Measured loudness may land under its target by the limiter, never far over it (dB).
const UNDER_TOLERANCE := 1.5
const OVER_TOLERANCE := 0.5
const GAITS: Array[StringName] = [&"walk", &"sprint", &"crouch", &"crawl"]
## Volumes of the shipped map in zone A (tile) and B (metal grate): see zone_ambience_test.gd.
const IN_A1 := Vector3(5.0, 0.0, 34.0)
const IN_B1 := Vector3(30.0, 0.0, 20.0)

var _bank: SoundBank


func before_test() -> void:
	_bank = SoundBank.load_shipped()


## Every sound id the client is asked to play, from the code's own constants and the shipped data.
func _requested() -> Array[StringName]:
	var ids: Array[StringName] = [BorrowedFace.DISTORTION_SOUND, MonsterAbilities.CUE_SOUND,
		MonsterAbilities.SCRAPE_SOUND, MonsterAbilities.HIT_SOUND, SurvivorObjectives.INSTALL_SOUND,
		HidingSpots.ENTER_SOUND, HidingSpots.EXIT_SOUND, HidingSpots.CUE_SOUND, PingCalloutHud.CLICK_SOUND,
		ShockPresenter.CRACKLE, ShockPresenter.FIZZ, DisguisePresenter.TRUE_FORM_CUE, ScareAudio.STINGER_ID]
	var appearances: Array[int] = [CharacterDef.TRUE_FORM_APPEARANCE_ID]
	# Each loaded resource is held in a local: iterating `load_x().array` directly leaks the script graph at
	# exit on 4.7.2 (docs/engine-reference/godot/gotchas.md).
	var callouts := CalloutSet.load_shipped()
	var scares := ScareCatalogue.load_shipped()
	var map := MapData.load_map()
	for c in CharacterDef.load_all():
		appearances.append(c.appearance_id)
		ids.append(StringName(String(c.voice_set) + DisguisePresenter.GRUNT_SUFFIX))
		for line in callouts.lines:
			ids.append(StringName("callout/%s/%s" % [c.voice_set, line]))
	for a in appearances:
		for g: StringName in Footsteps.GAIT_NAMES.values():
			ids.append(StringName("c%d.%s" % [a, g]))
	for e in scares.entries:
		ids.append(StringName("scare/" + e.scare_id))
	for v in map.volumes:
		ids.append(StringName("ambience/" + v.zone))
	return ids


func test_every_requested_id_resolves_to_a_stream_on_every_surface() -> void:
	var surfaces: Array[StringName] = [&""]
	surfaces.append_array(_bank.surface_of_zone.values())
	for id in _requested():
		for s in surfaces:
			var e := _bank.resolve(id, s)
			assert_object(e).override_failure_message("no bank entry for %s on '%s'" % [id, s]).is_not_null()
			if e != null:
				assert_object(e.stream).override_failure_message("no stream for %s" % id).is_not_null()


func test_every_entry_plays_on_a_bus_of_the_layout() -> void:
	assert_int(_bank.entries.size()).is_greater(0)
	for id: StringName in _bank.entries:
		var e := _bank.entries[id] as SoundBankEntry
		assert_int(AudioServer.get_bus_index(e.bus)) \
				.override_failure_message("%s on missing bus %s" % [id, e.bus]).is_greater_equal(0)
	assert_str(String(_bank.resolve(&"ambience/A").bus)).is_equal(String(ZoneAmbience.BUS))
	assert_str(String(_bank.resolve(ScareAudio.STINGER_ID).bus)).is_equal(String(ScareAudio.STINGER_BUS))
	assert_str(String(_bank.resolve(&"scare/door_burst").bus)).is_equal(String(ScareAudio.SFX_BUS))
	assert_str(String(_bank.resolve(&"callout/voice_c2/danger").bus)).is_equal(String(PingCalloutHud.VOICE_BUS))


func test_disguise_sounds_exactly_like_the_copied_survivor_and_true_form_only_in_true_form() -> void:
	var cast := CharacterDef.load_all()
	var disguise: DisguisePresenter = auto_free(DisguisePresenter.new({}, func(_h: int) -> Dictionary: return {},
			Knobs.load_all(), cast))
	var true_steps := _bank.resolve(&"c0.walk", &"tile")
	var true_cry := _bank.resolve(disguise.cue_of(CharacterDef.TRUE_FORM_APPEARANCE_ID))
	for c in cast:
		var steps := _bank.resolve(StringName("c%d.walk" % c.appearance_id), &"tile")
		# the shapeshifter copying c sends c's appearance: the same ids, so the same stream, pitch and gain
		assert_object(steps).is_not_same(true_steps)
		assert_object(steps.stream).is_not_same(true_steps.stream)
		var grunt := _bank.resolve(disguise.cue_of(c.appearance_id))
		assert_str(String(disguise.cue_of(c.appearance_id))).is_equal(String(c.voice_set) + ".shocked_grunt")
		assert_object(grunt.stream).is_not_same(true_cry.stream)
		var callout := _bank.resolve(StringName("callout/%s/danger" % c.voice_set))
		for other in cast:
			if other != c:
				assert_object(callout.stream).is_not_same(
						_bank.resolve(StringName("callout/%s/danger" % other.voice_set)).stream)
	# survivors share a surface file at their own pitch, so each set is told apart
	var pitches := {}
	for c in cast:
		pitches[_bank.resolve(StringName("c%d.walk" % c.appearance_id), &"tile").pitch_scale] = true
	assert_int(pitches.size()).is_equal(cast.size())


func test_gait_sets_the_footstep_gain() -> void:
	assert_float(_bank.extra_db(&"c3.sprint")).is_greater(_bank.extra_db(&"c3.walk"))
	assert_float(_bank.extra_db(&"c3.crouch")).is_less(_bank.extra_db(&"c3.walk"))
	assert_float(_bank.extra_db(&"scare/door_burst")).is_equal(0.0)


func test_footsteps_take_the_surface_of_their_zone_and_unknown_ids_keep_the_beep() -> void:
	var a: PlaceholderAudio = auto_free(PlaceholderAudio.new(_bank, MapData.load_map()))
	assert_str(String(a.surface_at(IN_A1))).is_equal("tile")
	assert_str(String(a.surface_at(IN_B1))).is_equal("metal")
	a.play_at(&"c2.sprint", IN_B1)
	a.play_at(&"no_such_sound", IN_A1, &"Voice")
	var step := a.get_child(0) as AudioStreamPlayer3D
	var metal := _bank.resolve(&"c2@metal")
	assert_object(step.stream).is_same(metal.stream)
	assert_float(step.pitch_scale).is_equal_approx(metal.pitch_scale, 0.0001)
	assert_float(step.volume_db).is_equal_approx(metal.volume_db + _bank.extra_db(&"c2.sprint"), 0.0001)
	assert_str(String(step.bus)).is_equal(String(metal.bus))
	var beep := a.get_child(1) as AudioStreamPlayer3D
	assert_object(beep.stream).is_instanceof(AudioStreamWAV)
	assert_str(String(beep.bus)).is_equal("Voice")
	assert_object(_bank.resolve(&"no_such_sound")).is_null()


func test_presenter_owned_sets_play_once() -> void:
	var a: PlaceholderAudio = auto_free(PlaceholderAudio.new(_bank))
	for s: StringName in [BorrowedFace.DISTORTION_SOUND, MonsterAbilities.CUE_SOUND, MonsterAbilities.HIT_SOUND]:
		a.on_sound(1, {"pos": Vector3.ZERO, "set": s})
	assert_int(a.get_child_count()).is_equal(0)


func test_loudness_table_meets_targets_and_stinger_stays_within_6_db_of_every_bed() -> void:
	var text := FileAccess.get_file_as_string(LOUDNESS)
	assert_str(text).is_not_empty()
	var files := 0
	var beds := 0
	for line in text.split("\n"):
		var cells := line.split("|")
		if line.begins_with("| `assets/audio/"):
			files += 1
			var target := cells[4].to_float()
			var measured := cells[5].to_float()
			assert_float(measured).override_failure_message(line) \
					.is_between(target - UNDER_TOLERANCE, target + OVER_TOLERANCE)
			assert_float(cells[6].to_float()).override_failure_message(line).is_less_equal(-0.9)
		elif line.begins_with("| amb_"):
			beds += 1
			var over := cells[2].to_float() * -1.0 + cells[4].to_float()
			assert_float(over).override_failure_message(line).is_less_equal(6.0)
	assert_int(beds).is_equal(4)
	var paths := {}
	for id: StringName in _bank.entries:
		paths[(_bank.entries[id] as SoundBankEntry).stream.resource_path] = true
	assert_int(files).is_equal(paths.size())
