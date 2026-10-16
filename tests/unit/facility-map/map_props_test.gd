# ASSET-052..064 props (research-facility-assets.md): MapGreybox draws a prop scene from SurfaceMaterials.props
# at every interactable and camera marker instead of a post, at the marker's position and yaw, and the props
# add no collision (interaction and sight use MapQueries and the level's own bodies, never a prop).
extends GdUnitTestSuite

const EPS := 1e-3

var _map: MapData
var _mats: SurfaceMaterials
var _root: Node3D


func before_test() -> void:
	_map = MapData.load_map()
	_mats = load(MapGreybox.SURFACES) as SurfaceMaterials
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	_root = MapGreybox.build(holder, _map)


func _prop(m: MapMarker) -> Node3D:
	return _root.get_node_or_null(NodePath("Prop_%s" % m.id)) as Node3D


func test_every_interactable_marker_type_resolves_to_a_prop_scene() -> void:
	for m in _map.markers:
		if m.type in MapData.INTERACTABLE_TYPES or m.type == &"camera":
			assert_object(_mats.prop_of(m)).override_failure_message("no prop for %s (%s)" % [m.id, m.type]).is_not_null()


func test_hiding_spots_h4_to_h6_are_lockers_the_rest_cabinets() -> void:
	for m in _map.markers:
		if m.type == &"hiding":
			var want := "prop_hide_locker" if m.id in [&"h4", &"h5", &"h6"] else "prop_hide_cabinet"
			assert_str(_mats.prop_of(m).resource_path).contains(want)


func test_props_stand_at_their_markers_with_the_marker_yaw() -> void:
	var n := 0
	for m in _map.markers:
		if _mats.prop_of(m) == null:
			continue
		var p := _prop(m)
		assert_object(p).override_failure_message("prop %s not placed" % m.id).is_not_null()
		assert_float(Vector2(p.position.x - m.position.x, p.position.z - m.position.z).length()).is_less(EPS)
		if not is_nan(m.yaw_deg):
			assert_float(absf(angle_difference(p.rotation.y, deg_to_rad(m.yaw_deg)))).is_less(EPS)
		if m.type != &"camera":
			assert_float(p.position.y).is_equal_approx(m.position.y, EPS)
		n += 1
	assert_int(n).is_greater(30)


func test_unset_yaw_faces_the_middle_of_the_markers_volume() -> void:
	for m in _map.markers:
		if _mats.prop_of(m) == null or not is_nan(m.yaw_deg):
			continue
		var centre := Vector3.ZERO
		for v in _map.volumes:
			if v.id == m.volume:
				centre = v.box.get_center()
		var to := Vector3(centre.x - m.position.x, 0.0, centre.z - m.position.z)
		if to.length() < EPS:
			continue ## a marker at its volume's middle has no way to face
		to = to.normalized()
		var forward := -_prop(m).basis.z
		assert_float(Vector3(forward.x, 0.0, forward.z).normalized().dot(to)).is_greater(0.999)


func test_cameras_hang_under_their_ceiling_off_the_feed_layer() -> void:
	for m in _map.markers:
		if m.type == &"camera":
			var top := 0.0
			for v in _map.volumes:
				if v.id == m.volume:
					top = v.box.end.y
			assert_float(_prop(m).position.y).is_equal_approx(top - SurveillanceFeed.MOUNT_BELOW_CEILING_M, EPS)
			## on the feed's hidden layer: the feed camera sits inside the housing and must not film it
			for vi: VisualInstance3D in _prop(m).find_children("*", "VisualInstance3D", true, false):
				assert_int(vi.layers).is_equal(1 << (SurveillanceFeed.SCREEN_LAYER - 1))


func test_no_post_left_where_a_prop_stands() -> void:
	for m in _map.markers:
		if _mats.prop_of(m) == null:
			continue
		for c in _root.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh \
					and ((c as MeshInstance3D).mesh as BoxMesh).size == MapGreybox.POST:
				var at := (c as Node3D).position
				assert_bool(Vector2(at.x - m.position.x, at.z - m.position.z).length() < EPS and at.y > 0.0) \
						.override_failure_message("post left at %s" % m.id).is_false()


func test_props_add_no_collision() -> void:
	var props := _root.find_children("Prop_*", "Node3D", true, false)
	assert_int(props.size()).is_greater(30)
	for p in props:
		assert_array(p.find_children("*", "CollisionObject3D", true, false)).is_empty()
		assert_array(p.find_children("*", "CollisionShape3D", true, false)).is_empty()


func test_exit_frame_stands_at_the_exit_and_its_lamp_lights_only_while_open() -> void:
	var exit: MapPassage
	for p in _map.passages:
		if p.kind == MapPassage.EXIT:
			exit = p
	var frame := _root.get_node(NodePath("Prop_%s" % exit.id)) as Node3D
	assert_float(frame.global_position.distance_to(exit.position)).is_less(EPS)
	var body := _root.find_child("Door_%s" % exit.id, true, false) as StaticBody3D
	var lit := body.get_node(^"Lit") as Node3D
	assert_float(lit.global_position.distance_to(exit.position)).is_less(EPS)
	assert_bool(lit.visible).is_false()
	var blockers := DoorBlockers.new(_root, _map)
	blockers.set_exit_open(true)
	assert_bool(lit.visible).is_true()
	blockers.set_exit_open(false)
	assert_bool(lit.visible).is_false()


func test_core_and_breaker_wall_dress_their_blockers() -> void:
	for blocker in [&"BlockerCore", &"BlockerBreakerWall"]:
		var body := _root.find_child(String(blocker), true, false) as StaticBody3D
		assert_bool((body.get_node(^"Mesh") as MeshInstance3D).visible).is_false()
		var dressing := body.get_node(^"Prop") as Node3D
		var half := ((body.get_node(^"Shape") as CollisionShape3D).shape as BoxShape3D).size.y / 2.0
		assert_float(dressing.global_position.y).is_equal_approx(body.global_position.y - half, EPS)
		assert_array(dressing.find_children("*", "CollisionObject3D", true, false)).is_empty()


func test_no_greybox_post_at_any_door() -> void:
	var tall := Vector3(0.2, 2.0, 0.2) ## the old orange door post (BUG-0018 drew leaves instead)
	for c in _root.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			assert_bool(((c as MeshInstance3D).mesh as BoxMesh).size.is_equal_approx(tall)) 					.override_failure_message("door post left at %s" % (c as Node3D).position).is_false()
