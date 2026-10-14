# Story controller-interaction/001: player body, capsules and collision layers (ADR-0007 §1, §2, §5).
# Integration: real Jolt bodies in the test tree, moved with move_and_slide inside the physics frame.
extends GdUnitTestSuite

const WALK_MPS := 4.0 ## controller walk_speed; the bodies here are pushed at walk pace
const WALK_TICKS := 60
const DOORWAY_M := 0.9
const LOW_CEILING_Y := 1.5 ## above the 1.2 m low capsule, below the 1.8 m standing one
## ADR-0007 §6: two players closing head-on may overlap by up to one tick of motion until the next step.
const HEAD_ON_OVERLAP_M := 0.15

var _knobs: Knobs
var _world: Node3D


func before_test() -> void:
	_knobs = Knobs.load_all()
	_world = Node3D.new()
	add_child(_world)
	_box(Vector3(0, -0.5, 0), Vector3(40, 1, 40)) ## floor


func after_test() -> void:
	_world.free()


func _box(center: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = PhysicsLayers.WORLD
	b.collision_mask = PhysicsLayers.NONE
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	cs.shape.size = size
	b.add_child(cs)
	_world.add_child(b)
	b.global_position = center


func _body(pos: Vector3, mask := PhysicsLayers.MOVE_SERVER) -> PlayerBody:
	var b := PlayerBody.new()
	b.setup(_knobs, mask)
	_world.add_child(b)
	b.global_position = pos
	return b


## Moves every body at its velocity for `ticks` physics frames (gravity off: the floor is flat).
func _walk(bodies: Array, velocities: Array, ticks: int) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame ## bodies are in the broadphase before the first step
	for t in ticks:
		await get_tree().physics_frame
		for i in bodies.size():
			bodies[i].velocity = velocities[i]
			bodies[i].move_and_slide()


func test_every_form_has_radius_030_and_heights_18_and_12_with_no_shared_shape() -> void:
	var shapes := {}
	for form in ["survivor", "disguised", "true_form", "downed"]:
		var b := _body(Vector3.ZERO)
		assert_float(b.capsule().radius).is_equal_approx(0.30, 0.0001)
		assert_float(b.capsule().height).is_equal_approx(1.8, 0.0001)
		shapes[b.capsule().get_instance_id()] = form
		if form == "downed":
			b.set_downed(true)
		else:
			assert_bool(b.set_low(true)).is_true() ## crouched
		assert_float(b.capsule().radius).is_equal_approx(0.30, 0.0001)
		assert_float(b.capsule().height).is_equal_approx(1.2, 0.0001)
		var cs: CollisionShape3D = b.get_child(0)
		assert_float(cs.position.y).is_equal_approx(0.6, 0.0001) ## shape at y = height / 2
		shapes[b.capsule().get_instance_id()] = form
	assert_int(shapes.size()).is_equal(8) ## 4 bodies x 2 capsules, none shared


func test_capsule_sizes_come_from_controller_knobs() -> void:
	_knobs.controller.player_radius_m = 0.33
	_knobs.controller.capsule_height_m = 1.75
	_knobs.controller.capsule_low_height_m = 1.1
	var b := _body(Vector3.ZERO)
	assert_float(b.capsule().radius).is_equal_approx(0.33, 0.0001)
	assert_float(b.capsule().height).is_equal_approx(1.75, 0.0001)
	b.set_low(true)
	assert_float(b.capsule().height).is_equal_approx(1.1, 0.0001)


func test_two_upright_players_walking_into_each_other_do_not_pass() -> void:
	var a := _body(Vector3(-1.5, 0, 0))
	var b := _body(Vector3(1.5, 0, 0))
	await _walk([a, b], [Vector3(WALK_MPS, 0, 0), Vector3(-WALK_MPS, 0, 0)], WALK_TICKS)
	assert_float(a.global_position.x).is_less(b.global_position.x)
	assert_float(b.global_position.x - a.global_position.x).is_greater(2.0 * 0.30 - HEAD_ON_OVERLAP_M)


func test_upright_player_walks_through_downed_survivor_in_a_09m_doorway() -> void:
	# Two walls leave a 0.9 m gap at x = 0, across z = 0.
	_box(Vector3(-(DOORWAY_M / 2.0 + 2.0), 1.5, 0), Vector3(4, 3, 0.2))
	_box(Vector3(DOORWAY_M / 2.0 + 2.0, 1.5, 0), Vector3(4, 3, 0.2))
	var downed := _body(Vector3(0, 0, 0))
	downed.set_downed(true)
	var walker := _body(Vector3(0, 0, -2))
	await _walk([walker], [Vector3(0, 0, WALK_MPS)], WALK_TICKS)
	assert_float(walker.global_position.z).is_greater(1.5) ## through the doorway and past the body
	# Control: the same body upright blocks the doorway.
	downed.set_downed(false)
	walker.global_position = Vector3(0, 0, -2)
	await _walk([walker], [Vector3(0, 0, WALK_MPS)], WALK_TICKS)
	assert_float(walker.global_position.z).is_less(-0.3)


func test_going_down_on_the_tick_of_a_collision_lets_the_other_pass_next() -> void:
	var a := _body(Vector3(0, 0, 0))
	var b := _body(Vector3(0, 0, -1.5))
	await _walk([b], [Vector3(0, 0, WALK_MPS)], 20) ## pressed against a
	assert_float(b.global_position.z).is_less(-0.45)
	a.set_downed(true) ## same tick as the contact
	await _walk([b], [Vector3(0, 0, WALK_MPS)], 30)
	assert_float(b.global_position.z).is_greater(0.5)


func test_out_body_has_no_collision_and_no_movement() -> void:
	var smp := SceneMultiplayer.new()
	var net := NetAuthority.new()
	net.setup(_knobs, "test", null)
	var runner := TickRunner.new()
	runner.fail_hard = false
	var saved_hz := Engine.physics_ticks_per_second
	runner.boot(_knobs)
	var sm := ServerMovement.new(_knobs, net, smp, TestMoveStep.apply, PhysicsLayers.WORLD)
	sm.attach(runner)
	var out := _body(Vector3(0, 0, 0))
	sm.add_player(0, out, true)
	out.set_out()
	sm.set_frozen(0, true)
	assert_int(out.collision_layer).is_equal(PhysicsLayers.NONE)
	assert_int(out.collision_mask).is_equal(PhysicsLayers.NONE)
	assert_bool((out.get_child(0) as CollisionShape3D).disabled).is_true()
	var walker := _body(Vector3(0, 0, -1.5))
	for t in WALK_TICKS:
		var f := InputFrame.new()
		f.seq = t + 1
		f.move = Vector2(0, 1)
		sm.push_local(0, f)
		await get_tree().physics_frame
		runner.step()
		walker.velocity = Vector3(0, 0, WALK_MPS)
		walker.move_and_slide()
	assert_vector(out.global_position).is_equal(Vector3.ZERO) ## input arrived, nothing moved
	assert_float(walker.global_position.z).is_greater(1.5) ## walked through the Out body
	sm.detach()
	runner.free()
	net.free()
	Engine.physics_ticks_per_second = saved_hz


func test_standing_under_a_low_ceiling_stays_low() -> void:
	_box(Vector3(0, LOW_CEILING_Y + 0.5, 0), Vector3(4, 1, 4))
	var b := _body(Vector3(0, 0, 0))
	b.set_low(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(b.set_low(false)).is_false()
	assert_float(b.capsule().height).is_equal_approx(1.2, 0.0001)
	b.global_position = Vector3(10, 0, 0) ## out from under it
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(b.set_low(false)).is_true()
	assert_float(b.capsule().height).is_equal_approx(1.8, 0.0001)


func test_project_selects_jolt() -> void:
	assert_str(String(ProjectSettings.get_setting("physics/3d/physics_engine"))).is_equal("Jolt Physics")


# --- inline layer numbers ----------------------------------------------------

## Lines of `src` that set a layer or mask from a number instead of PhysicsLayers: an assignment to
## collision_layer / collision_mask whose right side holds a digit, or any set_collision_* call.
static func literal_mask_lines(src: String) -> PackedStringArray:
	var assign := RegEx.create_from_string("(collision_layer|collision_mask)\\s*[|&]?=\\s*(.*)$")
	var digit := RegEx.create_from_string("\\b\\d+\\b")
	var out := PackedStringArray()
	for line in src.split("\n"):
		var code := line.split("#")[0]
		if code.contains("set_collision_layer") or code.contains("set_collision_mask"):
			out.append(line.strip_edges())
			continue
		var m := assign.search(code)
		if m != null and digit.search(m.get_string(2)) != null:
			out.append(line.strip_edges())
	return out


func test_scanner_catches_a_literal_and_passes_physics_layers() -> void:
	var fixture := "\n".join([
		"\tbody.collision_mask = 1 << 3",
		"\tq.collision_layer = 8",
		"\tbody.set_collision_layer_value(4, true)",
		"\tbody.collision_mask = PhysicsLayers.MOVE_SERVER",
		"\tbody.collision_layer = PhysicsLayers.NONE # was 0",
		"\tq.collision_mask = _mask & ~PhysicsLayers.PLAYERS",
	])
	assert_array(literal_mask_lines(fixture)).contains_exactly([
		"body.collision_mask = 1 << 3", "q.collision_layer = 8", "body.set_collision_layer_value(4, true)"])


func test_no_script_under_src_sets_a_layer_or_mask_from_a_literal() -> void:
	var bad := PackedStringArray()
	var scanned := 0
	var dirs := ["res://src/"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir + sub + "/")
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				scanned += 1
				for line in literal_mask_lines(FileAccess.get_file_as_string(dir + f)):
					bad.append("%s%s: %s" % [dir, f, line])
	assert_int(scanned).is_greater(10) ## the walk really reached the sources
	assert_array(bad).is_empty()
