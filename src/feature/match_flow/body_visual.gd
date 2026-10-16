class_name BodyVisual extends RefCounted
## Character art for remote bodies (ASSET-001..010, design/assets/specs/characters-assets.md): the drawn
## body for a snapshot appearance id. 1-5: the shared survivor body (one mesh, one skeleton) with that
## look's accessory, suit tint and stripe row; 0: the shapeshifter's true form; anything else: the plain
## untinted survivor body with no accessory or stripe. A look is a function of the id alone and its material
## is shared per id, so a disguise draws exactly the survivor it copies (LB-6, art bible §5 copy rule).
## Animation: gait from the snapshot, moving or still from the drawn position's speed (inference: the
## remote entry carries no velocity; the ADR-0004 remote fields would have to grow to settle it).
## Client presentation only; decides nothing. Built nodes carry no script, meta or file path (AC-LB-31).
## Usage (RoundClient._draw_remotes): `visuals.show(h, mesh, appearance, gait, transforming, pos, now_ms)`

const SURVIVOR_SCENE := "res://assets/art/characters/survivors/char_survivor_body.glb"
const TRUE_FORM_SCENE := "res://assets/art/characters/shapeshifter/char_shapeshifter_true.glb"
const BODY_SHADER := "res://assets/art/characters/survivors/spatial_char_survivor_body.gdshader"
const TEX_DIR := "res://assets/art/characters/survivors/"
## Child name under the body's "Mesh" node.
const VISUAL := &"Visual"
## LOD mesh node names after build (renamed from the glb's char_* names, which name a role).
const LOD_NAMES: Array[StringName] = [&"body_lod0", &"body_lod1", &"body_lod2"]
const TRUE_LOD_NAMES: Array[StringName] = [&"true_lod0", &"true_lod1", &"true_lod2"]
const _GLB_LODS := ["char_survivor_body_lod%d", "char_shapeshifter_true_lod%d"]
## LOD0 under 6 m, LOD1 6-15 m, LOD2 beyond (art bible §5 Detail and LOD, inference: profiling settles it).
const LOD_END_M: Array[float] = [6.0, 15.0]
const NO_STRIPE := -1
## Art bible §5 identity kit, by appearance id: suit hex, accessory mesh, stripe mask row
## (tex_survivor_stripe_mask_256.png rows: bar, two bars, chevron, three dots, sleeve band).
const LOOKS := {
	1: [Color("#E6E1D3"), &"acc_c1_hardhat", 0],
	2: [Color("#E3B31C"), &"acc_c2_backpack", 1],
	3: [Color("#2E63B8"), &"acc_c3_hood", 2],
	4: [Color("#C8581E"), &"acc_c4_radio", 3],
	5: [Color("#7B4FA0"), &"acc_c5_clipboard", 4],
}
## Below this drawn speed a body plays its still animation (m/s; inference: above interpolation jitter).
const MOVING_MPS := 0.3
## Low-pass weight per update on the drawn speed, so one jittery frame does not flip idle/walk.
const SPEED_SMOOTHING := 0.25
const BLEND_S := 0.2
## The glb faces +Z (Blender -Y); a body's yaw 0 faces -Z.
const FACING_FIX := PI

var _scenes := {}
var _materials := {}
var _acc_material: StandardMaterial3D
## handle -> [visual Node3D, appearance, last pos, last ms, smoothed speed]
## ponytail: entries of departed handles stay until the handle is reused (bounded by MAX_BODIES).
var _shown := {}
## handle -> the greybox capsule Mesh detached from its "Mesh" node while the art shows.
var _capsules := {}


## [tint, accessory node name, stripe row] for `appearance`; the plain fallback for an unknown id.
static func look_of(appearance: int) -> Array:
	return LOOKS.get(appearance, [Color.WHITE, &"", NO_STRIPE])


## Animation name for a gait (MovementStep.Gait) at drawn `speed` m/s. Crawl uses the crouch walk until a
## crawl clip exists (the CC0 library's Standard set has none).
static func anim_for(gait: int, speed: float) -> StringName:
	var moving := speed >= MOVING_MPS
	match gait:
		MovementStep.Gait.CROUCH, MovementStep.Gait.CRAWL:
			return &"Crouch_Fwd" if moving or gait == MovementStep.Gait.CRAWL else &"Crouch_Idle"
		MovementStep.Gait.SPRINT:
			return &"Sprint" if moving else &"Idle"
	return &"Walk" if moving else &"Idle"


## A new body node for `appearance` (not in the tree), playing its idle.
func build(appearance: int) -> Node3D:
	var true_form := appearance == CharacterDef.TRUE_FORM_APPEARANCE_ID
	var n := _scene(TRUE_FORM_SCENE if true_form else SURVIVOR_SCENE).instantiate() as Node3D
	n.scene_file_path = ""
	n.name = VISUAL
	n.rotation.y = FACING_FIX
	var names := TRUE_LOD_NAMES if true_form else LOD_NAMES
	for i in names.size():
		var mi := n.find_child(_GLB_LODS[1 if true_form else 0] % i, true, false) as MeshInstance3D
		mi.name = names[i]
		mi.visibility_range_begin = 0.0 if i == 0 else LOD_END_M[i - 1]
		mi.visibility_range_end = LOD_END_M[i] if i < LOD_END_M.size() else 0.0
		if not true_form:
			mi.material_override = _material(appearance)
	if not true_form:
		var keep: StringName = look_of(appearance)[1]
		for acc: Node in n.find_children("acc_*", "MeshInstance3D", true, false):
			if acc.name != keep:
				acc.get_parent().remove_child(acc)
				acc.free()
			else:
				(acc as MeshInstance3D).material_override = _accessory_material()
	_play(n, &"Idle")
	return n


## Draws handle `h`'s art under its greybox `mesh` (RoundClient remote "Mesh"): rebuilt when the appearance
## changes, animated from gait and drawn speed. While transforming the greybox capsule shows instead (it
## carries TransformPresenter's warp overlay) and the art hides.
## ponytail: capsule stand-in during the warp; move the overlay onto the art meshes when the warp is reworked.
func show(h: int, mesh: GeometryInstance3D, appearance: int, gait: int, transforming: bool, pos: Vector3,
		now_ms: float) -> void:
	var e: Array = _shown.get(h, [])
	if e.is_empty() or not is_instance_valid(e[0]) or (e[0] as Node).get_parent() != mesh or e[1] != appearance:
		if not e.is_empty() and is_instance_valid(e[0]):
			(e[0] as Node).get_parent().remove_child(e[0])
			(e[0] as Node).free()
		var v := build(appearance)
		mesh.add_child(v)
		v.position.y = -mesh.position.y # "Mesh" sits at half the capsule height; the art stands on the floor
		e = [v, appearance, pos, now_ms, 0.0]
		_shown[h] = e
	var dt := (now_ms - (e[3] as float)) / 1000.0
	if dt > 0.0:
		var raw := ((pos - (e[2] as Vector3)) * Vector3(1, 0, 1)).length() / dt
		e[4] = lerpf(e[4], raw, SPEED_SMOOTHING) if e[4] > 0.0 else raw
		e[2] = pos
		e[3] = now_ms
	var node := e[0] as Node3D
	node.visible = not transforming
	# The capsule mesh is detached rather than hidden (hiding "Mesh" would hide the art under it; a zero
	# render layer mask made Godot 4.7.2 log "indexing did not unpair geometries from light" at teardown).
	if transforming and mesh.mesh == null:
		mesh.mesh = _capsules.get(h)
	elif not transforming and mesh.mesh != null:
		_capsules[h] = mesh.mesh
		mesh.mesh = null
	_play(node, anim_for(gait, e[4]))


func _play(n: Node3D, anim: StringName) -> void:
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null and ap.current_animation != anim and ap.has_animation(anim):
		ap.play(anim, BLEND_S)


func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


func _material(appearance: int) -> ShaderMaterial:
	var key: int = appearance if LOOKS.has(appearance) else -1
	if not _materials.has(key):
		var look := look_of(key)
		var m := ShaderMaterial.new()
		m.shader = load(BODY_SHADER)
		m.set_shader_parameter(&"albedo_tex", load(TEX_DIR + "char_survivor_body_albedo_1024.png"))
		m.set_shader_parameter(&"normal_tex", load(TEX_DIR + "char_survivor_body_normal_1024.png"))
		m.set_shader_parameter(&"orm_tex", load(TEX_DIR + "char_survivor_body_orm_1024.png"))
		m.set_shader_parameter(&"stripe_mask", load(TEX_DIR + "tex_survivor_stripe_mask_256.png"))
		m.set_shader_parameter(&"tint", look[0])
		m.set_shader_parameter(&"stripe_row", look[2])
		_materials[key] = m
	return _materials[key]


func _accessory_material() -> StandardMaterial3D:
	if _acc_material == null:
		_acc_material = StandardMaterial3D.new()
		_acc_material.vertex_color_use_as_albedo = true
		_acc_material.roughness = 0.75
	return _acc_material
