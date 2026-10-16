# Character art presenter (ASSET-001..010, design/assets/specs/characters-assets.md; art bible §5 identity
# kit; LB-6 copy rule). BodyVisual builds the drawn body for a snapshot appearance id: the shared survivor
# body with that look's accessory, tint and stripe row, or the true form for 0; unknown ids fall back to
# the untinted survivor body with no accessory or stripe.
extends GdUnitTestSuite

## Art bible §5 suit colours, in appearance id order 1-5.
const SUIT_HEX: Array[String] = ["#E6E1D3", "#E3B31C", "#2E63B8", "#C8581E", "#7B4FA0"]
const ACCESSORY: Array[StringName] = [&"acc_c1_hardhat", &"acc_c2_backpack", &"acc_c3_hood", &"acc_c4_radio",
	&"acc_c5_clipboard"]

var _bv: BodyVisual


func before_test() -> void:
	_bv = BodyVisual.new()


func _built(appearance: int) -> Node3D:
	return auto_free(_bv.build(appearance))


func _accessories(n: Node3D) -> Array[Node]:
	return n.find_children("acc_*", "MeshInstance3D", true, false)


func _body_material(n: Node3D) -> ShaderMaterial:
	return (n.find_child(BodyVisual.LOD_NAMES[0], true, false) as MeshInstance3D).material_override as ShaderMaterial


func test_appearances_1_to_5_build_their_accessory_tint_and_stripe() -> void:
	for i in 5:
		var n := _built(i + 1)
		var accs := _accessories(n)
		assert_int(accs.size()).override_failure_message("look %d accessories" % (i + 1)).is_equal(1)
		assert_str(String(accs[0].name)).is_equal(String(ACCESSORY[i]))
		var m := _body_material(n)
		assert_object(m.get_shader_parameter(&"tint")).is_equal(Color(SUIT_HEX[i]))
		assert_int(m.get_shader_parameter(&"stripe_row")).is_equal(i)


func test_appearance_0_builds_the_true_form_without_survivor_parts() -> void:
	var n := _built(CharacterDef.TRUE_FORM_APPEARANCE_ID)
	assert_object(n.find_child(BodyVisual.TRUE_LOD_NAMES[0], true, false)).is_not_null()
	assert_object(n.find_child(BodyVisual.LOD_NAMES[0], true, false)).is_null()
	assert_array(_accessories(n)).is_empty()


func test_two_builds_of_one_look_are_identical() -> void:
	for id in [1, 3, 5]:
		var a := _built(id)
		var b := _built(id)
		assert_str(String(_accessories(a)[0].name)).is_equal(String(_accessories(b)[0].name))
		assert_object(_body_material(a)).is_same(_body_material(b))
		var pa: Array = a.find_children("*", "", true, false).map(func(x: Node) -> String: return str(a.get_path_to(x)))
		var pb: Array = b.find_children("*", "", true, false).map(func(x: Node) -> String: return str(b.get_path_to(x)))
		assert_array(pa).is_equal(pb)


func test_unknown_appearance_falls_back_to_the_plain_body() -> void:
	for id in [SnapshotCodec.NO_APPEARANCE, 6, -1]:
		var n := _built(id)
		assert_array(_accessories(n)).is_empty()
		var m := _body_material(n)
		assert_int(m.get_shader_parameter(&"stripe_row")).is_equal(BodyVisual.NO_STRIPE)
		assert_object(m.get_shader_parameter(&"tint")).is_equal(Color.WHITE)


func test_built_body_carries_no_script_meta_or_file_path() -> void:
	for id in [0, 2]:
		var n := _built(id)
		var nodes: Array[Node] = [n]
		nodes.append_array(n.find_children("*", "", true, false))
		for x in nodes:
			assert_bool(x.get_script() == null).is_true()
			assert_array(x.get_meta_list()).is_empty()
			assert_str(x.scene_file_path).is_empty()


func test_gait_and_speed_pick_the_animation() -> void:
	var still := 0.0
	var moving := 2.0
	assert_str(String(BodyVisual.anim_for(MovementStep.Gait.WALK, still))).is_equal("Idle")
	assert_str(String(BodyVisual.anim_for(MovementStep.Gait.WALK, moving))).is_equal("Walk")
	assert_str(String(BodyVisual.anim_for(MovementStep.Gait.SPRINT, moving))).is_equal("Sprint")
	assert_str(String(BodyVisual.anim_for(MovementStep.Gait.SPRINT, still))).is_equal("Idle")
	assert_str(String(BodyVisual.anim_for(MovementStep.Gait.CROUCH, still))).is_equal("Crouch_Idle")
	assert_str(String(BodyVisual.anim_for(MovementStep.Gait.CROUCH, moving))).is_equal("Crouch_Fwd")
	assert_str(String(BodyVisual.anim_for(MovementStep.Gait.CRAWL, moving))).is_equal("Crouch_Fwd")


func test_show_rebuilds_on_appearance_change_and_hides_art_while_transforming() -> void:
	var mesh: MeshInstance3D = auto_free(MeshInstance3D.new())
	var capsule := CapsuleMesh.new()
	mesh.mesh = capsule
	_bv.show(4, mesh, 2, MovementStep.Gait.WALK, false, Vector3.ZERO, 0.0)
	var first := mesh.get_node(^"Visual") as Node3D
	assert_str(String(_accessories(first)[0].name)).is_equal(String(ACCESSORY[1]))
	assert_object(mesh.mesh).is_null()
	_bv.show(4, mesh, 2, MovementStep.Gait.WALK, false, Vector3(0.05, 0, 0), 16.0)
	assert_object(mesh.get_node(^"Visual")).is_same(first)
	assert_str(String((first.find_child("AnimationPlayer", true, false) as AnimationPlayer).current_animation)) \
			.is_equal("Walk")
	_bv.show(4, mesh, 0, MovementStep.Gait.WALK, true, Vector3(0.05, 0, 0), 32.0)
	var second := mesh.get_node(^"Visual") as Node3D
	assert_object(second.find_child(BodyVisual.TRUE_LOD_NAMES[0], true, false)).is_not_null()
	assert_bool(second.visible).is_false()
	assert_object(mesh.mesh).is_same(capsule)
