# Story facility-map/010: client lighting presentation (research-facility.md Lighting States, Precedence,
# AC 9; ADR-0009 §6). Records in, fixture groups out: a Blackout darkens its one volume except the emergency
# strips, Evacuation lights the beacons (steady under reduced flash), overlays light their own fixtures,
# and every light stays inside its own volume.
extends GdUnitTestSuite

const DARK := &"C4"
const NEIGHBOUR := &"C2"
const ZONE_A := &"A3"
const ZONE_B := &"B2"
const NO_BEACON := &"A3"

var _map: MapData
var _presets: LightingPresets
var _p: LightingPresenter


func before_test() -> void:
	_map = MapData.load_map()
	_presets = LightingPresets.load_shipped()
	_p = auto_free(LightingPresenter.new(_map, _presets))
	add_child(_p)


func _record(volume: StringName, base: int, overlays: int = 0, dark_until: int = 0) -> Dictionary:
	return {"volume": volume, "base": base, "overlays": overlays, "dark_until": dark_until}


func _shown(volume: StringName, group: String) -> bool:
	return (_p.get_node(NodePath("%s/%s" % [volume, group])) as Node3D).visible


func _energy(volume: StringName, group: String) -> float:
	return (_p.get_node(NodePath("%s/%s" % [volume, group])).get_child(0) as Light3D).light_energy


func test_every_light_stays_inside_its_volume() -> void:
	var count := 0
	for v in _map.volumes:
		for light: Light3D in _p.get_node(NodePath(String(v.id))).find_children("*", "Light3D", true, false):
			var p := light.global_position
			var r: float = light.get(&"omni_range") if light is OmniLight3D else 0.0
			if light is SpotLight3D:
				# A downward cone reaches the floor at height * tan(angle) from its foot.
				r = p.y * tan(deg_to_rad((light as SpotLight3D).spot_angle))
				if (light.get_parent() as Node3D).name == &"beacon":
					r = (light as SpotLight3D).spot_range
			assert_bool(p.x - r >= v.box.position.x - 0.01 and p.x + r <= v.box.end.x + 0.01
					and p.z - r >= v.box.position.z - 0.01 and p.z + r <= v.box.end.z + 0.01) \
					.override_failure_message("%s light %s reaches outside its box" % [v.id, light.name]).is_true()
			count += 1
	assert_int(count).is_greater(_map.volumes.size())


func test_round_start_is_low_power_with_zone_b_dimmest() -> void:
	assert_bool(_shown(ZONE_A, "overhead")).is_true()
	assert_float(_energy(ZONE_B, "overhead")).is_less(_energy(ZONE_A, "overhead"))
	assert_bool(_shown(ZONE_A, "beacon")).is_false()


func test_blackout_darkens_one_volume_except_emergency_strips() -> void:
	_p.on_lighting(10, _record(DARK, FacilityLighting.Base.EVACUATION, FacilityLighting.OVERLAY_EXIT_OPEN, 200))
	_p.on_lighting(10, _record(NEIGHBOUR, FacilityLighting.Base.EVACUATION))
	for g in ["overhead", "beacon", "beacon_steady", "fuse_indicator", "terminal_alarm", "exit_light"]:
		assert_bool(_shown(DARK, g)).override_failure_message(g).is_false()
	assert_bool(_shown(DARK, "emergency_strip")).is_true()
	assert_bool(_shown(NEIGHBOUR, "overhead")).is_true()
	assert_bool(_shown(NEIGHBOUR, "beacon")).is_true()


func test_blackout_end_restores_the_current_state() -> void:
	_p.on_lighting(10, _record(DARK, FacilityLighting.Base.LOW_POWER, 0, 200))
	_p.on_lighting(200, _record(DARK, FacilityLighting.Base.POWER_RESTORED))
	assert_bool(_shown(DARK, "overhead")).is_true()
	assert_float(_energy(DARK, "overhead")).is_equal(_presets.overhead_energy[FacilityLighting.Base.POWER_RESTORED])


func test_evacuation_beacons_use_the_steady_variant_under_reduced_flash() -> void:
	_p.on_lighting(10, _record(NEIGHBOUR, FacilityLighting.Base.EVACUATION))
	_p.on_lighting(10, _record(NO_BEACON, FacilityLighting.Base.EVACUATION))
	assert_bool(_shown(NEIGHBOUR, "beacon")).is_true()
	assert_bool(_shown(NEIGHBOUR, "beacon_steady")).is_false()
	assert_bool(_shown(NO_BEACON, "beacon")).is_false()
	_p.reduced_flash = true
	assert_bool(_shown(NEIGHBOUR, "beacon")).is_false()
	assert_bool(_shown(NEIGHBOUR, "beacon_steady")).is_true()


func test_reduced_flash_alarm_holds_steady() -> void:
	_p.reduced_flash = true
	_p.on_lighting(10, _record(DARK, FacilityLighting.Base.EVACUATION, FacilityLighting.OVERLAY_TERMINAL_ACTIVATING))
	var before := _energy(DARK, "terminal_alarm")
	_p._process(0.37)
	assert_float(_energy(DARK, "terminal_alarm")).is_equal(before)


func test_overlays_light_their_own_fixtures_only() -> void:
	_p.on_lighting(10, _record(DARK, FacilityLighting.Base.LOW_POWER, FacilityLighting.OVERLAY_FUSE_INSTALLED))
	assert_bool(_shown(DARK, "fuse_indicator")).is_true()
	assert_bool(_shown(DARK, "terminal_alarm")).is_false()
	assert_bool(_shown(DARK, "exit_light")).is_false()
	assert_bool(_shown(NEIGHBOUR, "fuse_indicator")).is_false()


func test_malformed_records_are_ignored() -> void:
	var before := _energy(DARK, "overhead")
	_p.on_lighting(10, _record(&"nowhere", FacilityLighting.Base.EVACUATION))
	_p.on_lighting(10, {"volume": DARK, "base": 9, "overlays": 0, "dark_until": 0})
	_p.on_lighting(10, {"volume": DARK, "base": "x", "overlays": 0, "dark_until": 0})
	_p.on_lighting(10, {"volume": DARK})
	assert_bool(_shown(DARK, "beacon")).is_false()
	assert_float(_energy(DARK, "overhead")).is_equal(before)
