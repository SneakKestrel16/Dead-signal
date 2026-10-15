# Story scare-events/001: the scare catalogue data and the server Scare module (scare-events.md rules 1-3, 8;
# ADR-0005). The catalogue loads from a .tres and rejects incomplete entries; ScareTriggered carries id, scope,
# origin and intensity, its source and player stay server-side, and only ScareEvents emits it.
extends GdUnitTestSuite

const S1 := 2
const S2 := 3
const MONSTER := 1
const SRC := "res://src/"

var _knobs: Knobs
var _bus: EventBus
var _scares: ScareEvents


func before_test() -> void:
	_knobs = Knobs.load_all()
	_bus = EventBus.new(_knobs.core.max_flush_rounds)
	_scares = ScareEvents.new(ScareCatalogue.load_shipped())
	_scares.setup(null, _bus, null, _knobs)


func _entry(patch: Dictionary = {}) -> ScareEntry:
	var e := ScareEntry.new()
	e.scare_id = &"t"
	e.category = ScareEntry.Category.ENVIRONMENT
	e.source = ScareEntry.Source.SURVIVOR
	e.scope = ScareEntry.Scope.SHARED
	e.intensity = ScareEntry.Intensity.MINOR
	for k: String in patch:
		e.set(k, patch[k])
	return e


func _events() -> Array[ServerEvent]:
	_bus.flush()
	return _bus.take_tick_events()


func test_shipped_catalogue_loads_valid_with_the_gdd_scares() -> void:
	var c := ScareCatalogue.load_shipped()
	assert_object(c).is_not_null()
	assert_array(c.errors()).is_empty()
	for id in [&"transformation_reveal", &"door_burst", &"ambush_lunge", &"blackout", &"slammed_door",
			&"glass_break", &"surveillance_image"]:
		assert_object(c.entry(id)).is_not_null()
	assert_object(c.entry(&"false_signal")).is_null()
	assert_int(c.entry(&"surveillance_image").scope).is_equal(ScareEntry.Scope.SINGLE_CLIENT)
	assert_int(c.entry(&"slammed_door").source).is_equal(ScareEntry.Source.ROUND_SCRIPT)
	assert_int(c.entry(&"slammed_door").anchors.size()).is_equal(6)
	assert_int(c.entry(&"glass_break").anchors.size()).is_equal(3)
	assert_dict(c.presenter_catalog()).contains_keys([&"door_burst"])


func test_entry_missing_id_source_scope_or_intensity_is_a_load_problem() -> void:
	assert_array(_entry().errors()).is_empty()
	for patch: Dictionary in [{"scare_id": &""}, {"source": -1}, {"scope": -1}, {"intensity": -1}]:
		assert_array(_entry(patch).errors()).is_not_empty()
	var c := ScareCatalogue.new()
	c.entries.assign([_entry(), _entry({"scope": -1})])
	assert_array(c.errors()).is_not_empty()
	c.entries.assign([_entry(), _entry()])
	assert_array(c.errors()).is_not_empty() # duplicate id


func test_round_script_entry_needs_phases_and_zones() -> void:
	assert_array(_entry({"source": ScareEntry.Source.ROUND_SCRIPT}).errors()).is_not_empty()


func test_fire_emits_id_scope_origin_intensity_source_and_player_to_each_recipient() -> void:
	assert_bool(_scares.fire(&"door_burst", Vector3(1, 2, 3), [S1, S2], ScareEntry.Source.MONSTER, MONSTER)).is_true()
	var evs := _events()
	assert_int(evs.size()).is_equal(2)
	var e := evs[0] as EvScareTriggered
	assert_str(e.scare_id).is_equal("door_burst")
	assert_int(e.scope).is_equal(ScareEntry.Scope.SHARED)
	assert_int(e.intensity).is_equal(ScareEntry.Intensity.MAJOR)
	assert_vector(e.origin).is_equal(Vector3(1, 2, 3))
	assert_int(e.source).is_equal(ScareEntry.Source.MONSTER)
	assert_int(e.player).is_equal(MONSTER)
	assert_int((evs[1] as EvScareTriggered).recipient).is_equal(S2)


func test_fire_refuses_a_monster_or_survivor_source_without_a_player_and_a_wrong_source() -> void:
	assert_bool(_scares.fire(&"door_burst", Vector3.ZERO, [S1], ScareEntry.Source.MONSTER)).is_false()
	assert_bool(_scares.fire(&"alarm_fuse", Vector3.ZERO, [S1], ScareEntry.Source.SURVIVOR)).is_false()
	assert_bool(_scares.fire(&"door_burst", Vector3.ZERO, [S1], ScareEntry.Source.SURVIVOR, S1)).is_false()
	assert_bool(_scares.fire(&"nope", Vector3.ZERO, [S1], ScareEntry.Source.MONSTER, MONSTER)).is_false()
	assert_bool(_scares.fire(&"slammed_door", Vector3.ZERO, [S1], ScareEntry.Source.ROUND_SCRIPT)).is_true()
	assert_int(_events().size()).is_equal(1)


func test_single_client_scare_needs_exactly_one_recipient() -> void:
	assert_bool(_scares.fire(&"surveillance_image", Vector3.ZERO, [S1, S2], ScareEntry.Source.SURVIVOR, S1)).is_false()
	assert_bool(_scares.fire(&"surveillance_image", Vector3.ZERO, [S1], ScareEntry.Source.SURVIVOR, S1)).is_true()


func test_projection_carries_the_scare_and_no_source_or_player_identity() -> void:
	var e := EvScareTriggered.new()
	e.scare_id = &"door_burst"
	e.scope = ScareEntry.Scope.SHARED
	e.intensity = ScareEntry.Intensity.MAJOR
	e.origin = Vector3(4, 0, 5)
	e.source = ScareEntry.Source.MONSTER
	e.player = MONSTER
	e.recipient = S1
	var p := e.project(S1, HandleTable.new(), MONSTER)
	assert_array(p.keys()).contains_exactly_in_any_order(["scare", "scope", "origin", "intensity"])
	assert_vector(p["origin"]).is_equal(Vector3(4, 0, 5))
	assert_dict(e.project(S2, HandleTable.new(), MONSTER)).is_empty()
	assert_dict(e.project(MONSTER, HandleTable.new(), MONSTER)).is_empty()


func test_only_the_scare_module_emits_scare_triggered_and_it_has_no_timer() -> void:
	var offenders: Array[String] = []
	var stack: Array[String] = [SRC]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for d in DirAccess.get_directories_at(dir):
			stack.append(dir + d + "/")
		for f in DirAccess.get_files_at(dir):
			var path: String = dir + f
			if f.ends_with(".gd") and FileAccess.get_file_as_string(path).contains("EvScareTriggered.new"):
				offenders.append(path)
	assert_array(offenders).contains_exactly([SRC + "feature/scare_events/scare_events.gd"])
	# server_tick fires nothing by itself.
	for t in 100:
		_scares.server_tick(t)
	assert_int(_events().size()).is_equal(0)
