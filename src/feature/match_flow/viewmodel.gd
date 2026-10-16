class_name Viewmodel extends Node3D
## First-person arms and held items (ASSET-011..014, design/assets/specs/characters-assets.md; art bible §5,
## §8): the survivor arms cut from the shared body (tools/art/build_viewmodel.py), the sleeve tinted to the
## local player's own look, the flashlight in the left hand and the taser in the right. A child of the local
## Camera3D, origin at the eye. Client presentation only; decides nothing.
## Shown for any survivor look, a disguise included (the own snapshot carries the copied look); hidden in the
## true form and before the first own snapshot. Inference: borrowed-face.md and monster-abilities.md do not
## say what the shapeshifter sees of itself; a true-form arms asset would settle it.
## The taser shows only with cartridges left (DefenseDisplay.charges(); -1 on the shapeshifter's client), its
## top window holding one cartridge per cartridge left. While a hold bar shows the right hand reaches.
## Drawn over walls with Z_CLIP_SCALE (Godot 4.7.2 BaseMaterial3D use_z_clip_scale; no second viewport), and
## casts no shadow, so the camera's own flashlight cone is not blocked by the arms.
## Usage (RoundClient): `viewmodel.update(own_appearance, defense.charges(), bar.visible, delta)` per frame.

const ARMS_SCENE := "res://assets/art/characters/viewmodel/char_viewmodel_arms.glb"
const ARMS_SHADER := "res://assets/art/characters/viewmodel/spatial_char_viewmodel_arms.gdshader"
const TASER_SCENE := "res://assets/art/props/prop_taser.glb"
const ARMS_MESH := &"char_viewmodel_arms"
## Poses baked by tools/art/build_viewmodel.py.
const POSE_IDLE := &"VM_Idle"
const POSE_LIGHT := &"VM_Idle_Light"
const POSE_REACH := &"VM_Reach"
const BLEND_S := 0.15
## Depth scale toward the near plane. Inference: a wall 0.3 m away (reverse-Z depth 0.17 at the 0.05 m near
## plane) still loses to arms at 0.6 m (0.9 after scaling); in-engine playtesting settles the value.
const Z_CLIP_SCALE := 0.15
## Idle sway: amplitude (m) and frequency (Hz). Inference: a breathing-rate drift, tuned by eye.
const SWAY_M := 0.006
const SWAY_HZ := 0.3

## Accessibility reduced motion (hud.md): no sway.
var reduced_motion := false
## The held items (children of hand BoneAttachment3Ds).
var flashlight: Node3D
var taser: Node3D

var _visuals: BodyVisual
var _arms: Node3D
var _player: AnimationPlayer
var _cartridges: Array[Node3D] = []
var _materials := {}
var _prop_material: StandardMaterial3D
var _look := -2
var _t := 0.0


## `visuals` supplies the look's body material (its textures and tint), shared with the remote bodies.
func _init(visuals: BodyVisual) -> void:
	_visuals = visuals
	name = &"Viewmodel"
	_arms = (load(ARMS_SCENE) as PackedScene).instantiate() as Node3D
	_arms.scene_file_path = ""
	add_child(_arms)
	_player = _arms.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skeleton := _arms.find_child("Skeleton3D", true, false) as Skeleton3D
	flashlight = (load(BodyVisual.FLASHLIGHT_SCENE) as PackedScene).instantiate() as Node3D
	BodyVisual.hold(skeleton, BodyVisual.HAND_L, flashlight)
	taser = (load(TASER_SCENE) as PackedScene).instantiate() as Node3D
	BodyVisual.hold(skeleton, BodyVisual.HAND_R, taser)
	for c: Node in taser.find_children("cartridge_*", "", true, false):
		_cartridges.append(c as Node3D)
	_cartridges.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.name) < String(b.name))
	for g: Node in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if g.name != ARMS_MESH:
			(g as GeometryInstance3D).material_override = _props_material()


## Whether the arms show for own appearance `appearance` (snapshot byte; -1 before the first own snapshot).
static func is_shown(appearance: int) -> bool:
	return appearance > 0 and appearance != SnapshotCodec.NO_APPEARANCE


## The pose for `charges` cartridges left and a hold in progress.
static func pose_for(charges: int, reaching: bool) -> StringName:
	if reaching:
		return POSE_REACH
	return POSE_IDLE if charges > 0 else POSE_LIGHT


## Applies the own look, cartridge count and hold state; advances the sway by `delta` seconds.
func update(appearance: int, charges: int, reaching: bool, delta: float) -> void:
	visible = is_shown(appearance)
	if not visible:
		return
	if appearance != _look:
		_look = appearance
		(_arms.find_child(ARMS_MESH, true, false) as MeshInstance3D).material_override = _arms_material(appearance)
	taser.visible = charges > 0 and not reaching
	for i in _cartridges.size():
		_cartridges[i].visible = i < charges
	var pose := pose_for(charges, reaching)
	if _player.current_animation != pose:
		_player.play(pose, BLEND_S)
	_t += delta
	var w := TAU * SWAY_HZ * _t
	position = Vector3.ZERO if reduced_motion else Vector3(sin(w), 0.5 * sin(2.0 * w), 0.0) * SWAY_M


func _arms_material(appearance: int) -> ShaderMaterial:
	if not _materials.has(appearance):
		var m := _visuals.material(appearance).duplicate() as ShaderMaterial
		m.shader = load(ARMS_SHADER)
		m.set_shader_parameter(&"z_clip_scale", Z_CLIP_SCALE)
		_materials[appearance] = m
	return _materials[appearance]


## Vertex-coloured, moderate specular (art bible §4: held items catch the flashlight), drawn over walls.
func _props_material() -> StandardMaterial3D:
	if _prop_material == null:
		_prop_material = StandardMaterial3D.new()
		_prop_material.vertex_color_use_as_albedo = true
		_prop_material.roughness = 0.5
		_prop_material.use_z_clip_scale = true
		_prop_material.z_clip_scale = Z_CLIP_SCALE
	return _prop_material
