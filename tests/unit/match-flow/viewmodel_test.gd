# First-person arms and held items (ASSET-011..014, design/assets/specs/characters-assets.md; art bible §5/§8).
# Viewmodel shows the survivor arms for a survivor look (and a disguise, which carries the copied look), none
# for the true form or an unknown body; tints the sleeve from the look; shows the taser only with cartridges,
# its window showing one cartridge per cartridge left; reaches while a hold bar shows.
extends GdUnitTestSuite

## Art bible §5 suit colours, in appearance id order 1-5.
const SUIT_HEX: Array[String] = ["#E6E1D3", "#E3B31C", "#2E63B8", "#C8581E", "#7B4FA0"]
const NO_HOLD := false
const STEP_S := 0.016

var _vm: Viewmodel


func before_test() -> void:
	_vm = auto_free(Viewmodel.new(BodyVisual.new()))
	add_child(_vm)


func _arms_material() -> ShaderMaterial:
	return (_vm.find_child(Viewmodel.ARMS_MESH, true, false) as MeshInstance3D).material_override as ShaderMaterial


func _cartridges_shown() -> int:
	return _vm.find_children("cartridge_*", "", true, false).filter(
			func(n: Node) -> bool: return (n as Node3D).is_visible_in_tree()).size()


func _pose() -> String:
	return String((_vm.find_child("AnimationPlayer", true, false) as AnimationPlayer).current_animation)


func test_shown_for_every_survivor_look_and_hidden_for_the_true_form_and_unknown_body() -> void:
	for id in [1, 2, 3, 4, 5]:
		_vm.update(id, 2, NO_HOLD, STEP_S)
		assert_bool(_vm.visible).override_failure_message("look %d" % id).is_true()
	for id in [CharacterDef.TRUE_FORM_APPEARANCE_ID, SnapshotCodec.NO_APPEARANCE, -1]:
		_vm.update(id, 2, NO_HOLD, STEP_S)
		assert_bool(_vm.visible).override_failure_message("id %d" % id).is_false()


func test_sleeve_tint_follows_the_look() -> void:
	for i in 5:
		_vm.update(i + 1, 2, NO_HOLD, STEP_S)
		var m := _arms_material()
		assert_object(m.get_shader_parameter(&"tint")).is_equal(Color(SUIT_HEX[i]))
		assert_float(m.get_shader_parameter(&"z_clip_scale")).is_equal(Viewmodel.Z_CLIP_SCALE)


func test_taser_only_with_cartridges_and_window_shows_the_count() -> void:
	_vm.update(2, 2, NO_HOLD, STEP_S)
	assert_bool(_vm.taser.is_visible_in_tree()).is_true()
	assert_int(_cartridges_shown()).is_equal(2)
	assert_str(_pose()).is_equal(String(Viewmodel.POSE_IDLE))
	_vm.update(2, 1, NO_HOLD, STEP_S)
	assert_int(_cartridges_shown()).is_equal(1)
	for none in [0, -1]: # spent, and the shapeshifter's client (never sent a count)
		_vm.update(2, none, NO_HOLD, STEP_S)
		assert_bool(_vm.taser.is_visible_in_tree()).is_false()
		assert_bool(_vm.flashlight.is_visible_in_tree()).is_true()
		assert_str(_pose()).is_equal(String(Viewmodel.POSE_LIGHT))


func test_reach_pose_while_a_hold_shows() -> void:
	_vm.update(3, 2, true, STEP_S)
	assert_str(_pose()).is_equal(String(Viewmodel.POSE_REACH))
	assert_bool(_vm.taser.is_visible_in_tree()).is_false()
	_vm.update(3, 2, NO_HOLD, STEP_S)
	assert_str(_pose()).is_equal(String(Viewmodel.POSE_IDLE))


func test_held_items_sit_in_the_hands() -> void:
	_vm.update(1, 2, NO_HOLD, STEP_S)
	assert_str(String(_vm.flashlight.get_parent().get(&"bone_name"))).is_equal("DEF-hand.L")
	assert_str(String(_vm.taser.get_parent().get(&"bone_name"))).is_equal("DEF-hand.R")


func test_no_viewmodel_geometry_casts_shadows_and_all_of_it_draws_over_walls() -> void:
	_vm.update(1, 2, NO_HOLD, STEP_S)
	for g: Node in _vm.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		assert_int(gi.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		if gi.material_override is StandardMaterial3D:
			assert_bool((gi.material_override as StandardMaterial3D).use_z_clip_scale).is_true()


func test_sway_stops_with_reduced_motion() -> void:
	_vm.update(1, 2, NO_HOLD, 0.7)
	assert_vector(_vm.position).is_not_equal(Vector3.ZERO)
	_vm.reduced_motion = true
	_vm.update(1, 2, NO_HOLD, 0.7)
	assert_vector(_vm.position).is_equal(Vector3.ZERO)


func test_remote_survivor_holds_the_flashlight_and_the_true_form_does_not() -> void:
	var bv := BodyVisual.new()
	var surv: Node3D = auto_free(bv.build(4))
	var lens := surv.find_child(BodyVisual.LENS, true, false)
	assert_object(lens).is_not_null()
	var at := lens.get_parent()
	while at != null and not at is BoneAttachment3D:
		at = at.get_parent()
	assert_str(String((at as BoneAttachment3D).bone_name)).is_equal("DEF-hand.L")
	var true_form: Node3D = auto_free(bv.build(CharacterDef.TRUE_FORM_APPEARANCE_ID))
	assert_object(true_form.find_child(BodyVisual.LENS, true, false)).is_null()
