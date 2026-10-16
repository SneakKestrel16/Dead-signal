# ObjectiveProps (survivor-objectives.md rules 5, 7, 10-20; research-facility.md Authored Candidate Points and
# Lighting States): client presentation of the objective props over the built level, fed fake hidden entities
# and ObjectiveProgressChanged payloads as a client receives them.
extends GdUnitTestSuite

const SEED := 12345
const D := SurvivorObjectives.DriveState
const F := SurvivorObjectives.FuseState

var _knobs: Knobs
var _map: MapData
var _root: Node3D
var _props: ObjectiveProps
var _holds: HoldService


func before_test() -> void:
	_knobs = Knobs.load_all()
	_map = MapData.load_map()
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	_root = MapGreybox.build(holder, _map)
	_props = auto_free(ObjectiveProps.new(_root, _map))
	add_child(_props)


func _first(type: StringName, skip := 0) -> int:
	for i in _map.markers.size():
		if _map.markers[i].type == type:
			if skip == 0:
				return i
			skip -= 1
	return -1


func _prop(i: int) -> Node3D:
	return _root.get_node(NodePath("Prop_%s" % _map.markers[i].id)) as Node3D


## A client-side hidden entity as HiddenSpawner._build makes it.
func _grant(i: int, objective: int) -> void:
	var e: Node3D = auto_free(Node3D.new())
	var m := _map.markers[i]
	e.set_meta(&"data", {"kind": m.type, "pos": m.position, "objective": objective, "n": 7})
	_props.on_spawned(e)


func _event(objective: int, state: int, extra := {}) -> void:
	var p := {"objective": objective, "state": state, "carrier": -1}
	p.merge(extra)
	_props.on_objective(0, p)


# --- 1: active candidates only --------------------------------------------------------------------------

func test_no_drive_or_fuse_prop_shows_before_any_grant() -> void:
	for i in _map.markers.size():
		if _map.markers[i].type in [&"drive", &"fuse"]:
			assert_bool(_prop(i).visible).override_failure_message(_map.markers[i].id).is_false()


func test_a_granted_point_shows_its_prop_and_no_other_candidate_does() -> void:
	var d := _first(&"drive", 1)
	var f := _first(&"fuse", 2)
	_grant(d, SurvivorObjectives.DRIVE_ID)
	_grant(f, SurvivorObjectives.FUSE_ID + 1)
	for i in _map.markers.size():
		if _map.markers[i].type in [&"drive", &"fuse"]:
			assert_bool(_prop(i).visible).override_failure_message(_map.markers[i].id).is_equal(i == d or i == f)


func test_fuse_boxes_and_terminals_stay_drawn() -> void:
	for i in _map.markers.size():
		if _map.markers[i].type in [&"fuse_box", &"terminal"]:
			assert_bool(_prop(i).visible).is_true()


func test_bad_spawn_data_is_ignored() -> void:
	var e: Node3D = auto_free(Node3D.new())
	e.set_meta(&"data", {"kind": &"drive", "pos": _map.markers[_first(&"drive")].position, "objective": "0"})
	_props.on_spawned(e)
	assert_bool(_prop(_first(&"drive")).visible).is_false()


func test_objective_ids_match_survivor_objectives_numbering() -> void:
	var holds := HoldService.new(_knobs, func() -> Array: return [], func(_a: int) -> Array: return [],
		func(_a: int) -> Vector3: return Vector3.ZERO, func(_a: int, _i: Interactable) -> bool: return true,
		func(_a: int) -> int: return -1)
	var obj := SurvivorObjectives.new(holds, _map)
	obj.rng.seed = SEED
	obj.setup(null, EventBus.new(_knobs.core.max_flush_rounds), StateRegistry.new(), _knobs)
	var ids := SurvivorObjectives.objective_ids(_map, obj.active())
	var base := {&"drive": SurvivorObjectives.DRIVE_ID, &"fuse": SurvivorObjectives.FUSE_ID,
		&"fuse_box": SurvivorObjectives.FUSE_BOX_ID}
	var checked := 0
	for item in holds._items:
		var p := item as ObjectivePoint
		for i in obj.active():
			var m := _map.markers[i]
			if base.has(m.type) and p.lock_key == StringName("%s_%s" % [m.type, m.id]):
				assert_int(ids[i]).is_equal(base[m.type] + p.index)
				checked += 1
	assert_int(checked).is_equal(6)
	assert_int(ids[obj.active()[0]]).is_equal(SurvivorObjectives.TERMINAL_ID)


# --- 2: carried, dropped, docked and installed items ------------------------------------------------------

func test_taking_the_drive_hides_its_marker_prop() -> void:
	var d := _first(&"drive")
	_grant(d, SurvivorObjectives.DRIVE_ID)
	_event(SurvivorObjectives.DRIVE_ID, D.CARRIED, {"carrier": 4})
	assert_bool(_prop(d).visible).is_false()
	assert_object(_props.item_of(SurvivorObjectives.DRIVE_ID)).is_null()


func test_taking_the_fuse_hides_its_marker_prop() -> void:
	var f := _first(&"fuse")
	_grant(f, SurvivorObjectives.FUSE_ID + 1)
	_event(SurvivorObjectives.FUSE_ID + 1, F.CARRIED, {"carrier": 4})
	assert_bool(_prop(f).visible).is_false()


func test_a_dropped_drive_lies_at_its_drop_point_with_the_cyan_glow() -> void:
	var at := Vector3(3.0, 0.0, -7.0)
	_event(SurvivorObjectives.DRIVE_ID, D.DROPPED, {"at": at})
	var n := _props.item_of(SurvivorObjectives.DRIVE_ID)
	assert_object(n).is_not_null()
	assert_vector(n.global_position).is_equal_approx(at, Vector3.ONE * 1e-3)
	var glow := n.get_node(^"Glow") as OmniLight3D
	assert_bool(glow.visible).is_true()
	assert_bool(glow.light_color.is_equal_approx(ObjectiveProps.CYAN)).is_true()
	_event(SurvivorObjectives.DRIVE_ID, D.CARRIED, {"carrier": 2})
	assert_object(_props.item_of(SurvivorObjectives.DRIVE_ID)).is_null()


func test_a_dropped_fuse_lies_at_its_drop_point() -> void:
	var at := Vector3(-1.0, 0.0, 2.0)
	_event(SurvivorObjectives.FUSE_ID, F.DROPPED, {"at": at})
	assert_vector(_props.item_of(SurvivorObjectives.FUSE_ID).global_position).is_equal_approx(at, Vector3.ONE * 1e-3)


func test_docked_drives_stand_in_the_active_terminal_without_glow() -> void:
	var t := _first(&"terminal", 1)
	_grant(t, SurvivorObjectives.TERMINAL_ID)
	_event(SurvivorObjectives.DRIVE_ID + 1, D.DOCKED)
	_event(SurvivorObjectives.DRIVE_ID, D.DOCKED)
	for o in [SurvivorObjectives.DRIVE_ID, SurvivorObjectives.DRIVE_ID + 1]:
		var n := _props.item_of(o)
		assert_object(n).is_not_null()
		assert_object(n.get_parent()).is_same(_prop(t))
		assert_bool((n.get_node(^"Glow") as Node3D).visible).is_false()
	assert_vector(_props.item_of(SurvivorObjectives.DRIVE_ID).position).is_not_equal(_props.item_of(SurvivorObjectives.DRIVE_ID + 1).position)


func test_an_installed_fuse_sits_in_its_own_box() -> void:
	var b0 := _first(&"fuse_box")
	var b1 := _first(&"fuse_box", 1)
	_grant(b0, SurvivorObjectives.FUSE_BOX_ID)
	_grant(b1, SurvivorObjectives.FUSE_BOX_ID + 1)
	_event(SurvivorObjectives.FUSE_BOX_ID + 1, F.INSTALLED)
	assert_object(_props.item_of(SurvivorObjectives.FUSE_BOX_ID + 1).get_parent()).is_same(_prop(b1))
	assert_object(_props.item_of(SurvivorObjectives.FUSE_BOX_ID)).is_null()


func test_a_carrier_holds_its_items_in_the_right_hand_and_drops_them() -> void:
	var visuals := BodyVisual.new()
	var mesh: Node3D = auto_free(Node3D.new())
	add_child(mesh)
	mesh.add_child(visuals.build(3))
	var sk := mesh.find_child("Skeleton3D", true, false) as Skeleton3D
	_props.hold_items(mesh, false, false)
	assert_object(sk.get_node_or_null(NodePath(("held_%s" % BodyVisual.HAND_R).validate_node_name()))).is_null()
	_props.hold_items(mesh, true, false)
	var hand := sk.get_node(NodePath(("held_%s" % BodyVisual.HAND_R).validate_node_name())) as BoneAttachment3D
	assert_str(hand.bone_name).is_equal(BodyVisual.HAND_R)
	assert_bool((hand.get_node(^"Drive") as Node3D).visible).is_true()
	assert_bool((hand.get_node(^"Fuse") as Node3D).visible).is_false()
	_props.hold_items(mesh, false, true)
	assert_bool((hand.get_node(^"Drive") as Node3D).visible).is_false()
	assert_bool((hand.get_node(^"Fuse") as Node3D).visible).is_true()
	_props.hold_items(mesh, false, false)
	assert_bool((hand.get_node(^"Fuse") as Node3D).visible).is_false()
	## AC-LB-31 / ADR-0004: what hangs on a remote body names nothing (no script, meta or file path)
	for n: Node in [hand] + hand.find_children("*", "", true, false):
		assert_str(n.scene_file_path).override_failure_message(n.name).is_empty()
		assert_object(n.get_script()).is_null()
		assert_array(n.get_meta_list()).is_empty()


func test_server_carry_flags_follow_the_carriers_and_never_the_monster() -> void:
	var holds := HoldService.new(_knobs, func() -> Array: return [], func(_a: int) -> Array: return [],
		func(_a: int) -> Vector3: return Vector3.ZERO, func(_a: int, _i: Interactable) -> bool: return true,
		func(_a: int) -> int: return -1)
	var obj := SurvivorObjectives.new(holds, _map)
	obj.rng.seed = SEED
	obj.setup(null, EventBus.new(_knobs.core.max_flush_rounds), StateRegistry.new(), _knobs)
	obj._complete(0, 2)
	obj._pick_up(1, 3)
	assert_bool(obj.carries_drive(2)).is_true()
	assert_bool(obj.carries_fuse(2)).is_false()
	assert_bool(obj.carries_fuse(3)).is_true()
	assert_bool(obj.carries_drive(9)).is_false() ## the shapeshifter is never a carrier
	assert_bool(obj.drop(2, SurvivorObjectives.DRIVE_ID)).is_true()
	assert_bool(obj.carries_drive(2)).is_false()


# --- 3: state-driven glows ------------------------------------------------------------------------------

func _terminal_event(state: int) -> void:
	_event(SurvivorObjectives.TERMINAL_ID, state)


func test_fuse_box_indicator_dark_inactive_dim_active_lit_installed() -> void:
	var b0 := _first(&"fuse_box")
	var b1 := _first(&"fuse_box", 1)
	assert_float(_props.glow_energy(b0, &"cyan_dim")).is_equal(0.0)
	_grant(b0, SurvivorObjectives.FUSE_BOX_ID)
	assert_float(_props.glow_energy(b0, &"cyan_dim")).is_equal_approx(ObjectiveProps.INDICATOR_ACTIVE, 1e-4)
	assert_float(_props.glow_energy(b1, &"cyan_dim")).is_equal(0.0)
	_event(SurvivorObjectives.FUSE_BOX_ID, F.INSTALLED)
	assert_float(_props.glow_energy(b0, &"cyan_dim")).is_equal_approx(ObjectiveProps.INDICATOR_INSTALLED, 1e-4)


func test_terminal_screen_follows_power_and_terminal_state() -> void:
	var t := _first(&"terminal", 1)
	var other := _first(&"terminal")
	_grant(t, SurvivorObjectives.TERMINAL_ID)
	assert_str(_props.screen_state(t)).is_equal("dark")
	assert_float(_props.glow_energy(t, &"screen")).is_equal(0.0)
	_terminal_event(SurvivorObjectives.TerminalState.POWERED)
	assert_str(_props.screen_state(t)).is_equal("locked")
	_terminal_event(SurvivorObjectives.TerminalState.ARMED)
	assert_str(_props.screen_state(t)).is_equal("armed")
	_terminal_event(SurvivorObjectives.TerminalState.ACTIVATING)
	assert_str(_props.screen_state(t)).is_equal("activating")
	_props.on_progress(0, {"key": WorldProgress.ACTIVATION_KEY, "paused": true})
	assert_str(_props.screen_state(t)).is_equal("paused")
	assert_float(_props.glow_energy(t, &"screen")).is_equal_approx(ObjectiveProps.SCREEN[&"paused"][1], 1e-4)
	_props.on_progress(0, {"key": WorldProgress.ACTIVATION_KEY, "paused": false})
	_terminal_event(SurvivorObjectives.TerminalState.ACTIVATED)
	assert_str(_props.screen_state(t)).is_equal("activated")
	assert_float(_props.glow_energy(t, &"screen")).is_equal_approx(ObjectiveProps.SCREEN[&"activated"][1], 1e-4)
	assert_str(_props.screen_state(other)).is_equal("dark")
	assert_float(_props.glow_energy(other, &"screen")).is_equal(0.0)


func test_countdown_pulses_and_holds_steady_with_reduced_motion() -> void:
	var t := _first(&"terminal")
	_grant(t, SurvivorObjectives.TERMINAL_ID)
	_terminal_event(SurvivorObjectives.TerminalState.ACTIVATING)
	var seen := {}
	for i in 8:
		_props.advance(0.125)
		seen[snappedf(_props.glow_energy(t, &"screen"), 0.01)] = true
	assert_int(seen.size()).is_greater(2)
	_props.reduced_motion = true
	_terminal_event(SurvivorObjectives.TerminalState.ACTIVATING)
	for i in 8:
		_props.advance(0.125)
		assert_float(_props.glow_energy(t, &"screen")).is_equal_approx(ObjectiveProps.SCREEN[&"activating"][1], 1e-4)


func test_core_pulses_once_per_install_softer_with_reduced_flash() -> void:
	var base := _props.core_energy()
	assert_float(base).is_greater(0.0)
	_event(SurvivorObjectives.FUSE_BOX_ID, F.INSTALLED)
	_props.advance(0.0)
	assert_float(_props.core_energy()).is_equal_approx(base * ObjectiveProps.CORE_PULSE_PEAK, 1e-3)
	_props.advance(ObjectiveProps.CORE_PULSE_S)
	assert_float(_props.core_energy()).is_equal_approx(base, 1e-3)
	_event(SurvivorObjectives.FUSE_BOX_ID, F.INSTALLED) ## a repeat (catch-up) is no new install
	_props.advance(0.0)
	assert_float(_props.core_energy()).is_equal_approx(base, 1e-3)
	_props.reduced_flash = true
	_event(SurvivorObjectives.FUSE_BOX_ID + 1, F.INSTALLED)
	_props.advance(0.0)
	assert_float(_props.core_energy()).is_equal_approx(base * ObjectiveProps.CORE_PULSE_REDUCED_PEAK, 1e-3)


## VFX ASSET-082: brief sparks at the fuse box's socket when its fuse goes in, once per install.
func test_fuse_install_sparks_at_its_box_socket() -> void:
	var b1 := _first(&"fuse_box", 1)
	_grant(b1, SurvivorObjectives.FUSE_BOX_ID + 1)
	assert_bool(_props.install_sparks().emitting).is_false()
	_event(SurvivorObjectives.FUSE_BOX_ID + 1, F.INSTALLED)
	assert_bool(_props.install_sparks().emitting).is_true()
	assert_vector(_props.install_sparks().position).is_equal_approx(
			_prop(b1).global_transform * ObjectiveProps.SOCKET, Vector3.ONE * 1e-4)


func test_no_sparks_without_an_install() -> void:
	var b0 := _first(&"fuse_box")
	_grant(b0, SurvivorObjectives.FUSE_BOX_ID)
	_event(SurvivorObjectives.FUSE_ID, F.DROPPED, {"at": Vector3(1, 0, 1)})
	assert_bool(_props.install_sparks().emitting).is_false()

