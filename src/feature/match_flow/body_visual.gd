class_name BodyVisual extends RefCounted
## Character art for remote bodies (ASSET-001..010, design/assets/specs/characters-assets.md): the drawn
## body for a snapshot appearance id. 1-5: the shared survivor body (one mesh, one skeleton) with that
## look's accessory, suit tint and stripe row; 0: the shapeshifter's true form; anything else: the plain
## untinted survivor body with no accessory or stripe. A look is a function of the id alone and its material
## is shared per id, so a disguise draws exactly the survivor it copies (LB-6, art bible §5 copy rule).
## Animation: gait from the snapshot, moving or still from the drawn position's speed (inference: the
## remote entry carries no velocity; the ADR-0004 remote fields would have to grow to settle it). Over the
## gait, an action the client already knows: a shock or stun stagger (DisguisePresenter) and the lunge's
## coil, miss stumble and hit (LungePresenter.pose()); clips in tools/art/build_anims.py. True-form clips play
## only on the true form, so a disguise borrows the survivor set whole (Borrowed Face, ASSET-008).
## Client presentation only; decides nothing. Built nodes carry no script, meta or file path (AC-LB-31).
## Usage (RoundClient._draw_remotes): `visuals.show(h, mesh, appearance, gait, pos, now_ms, action)`

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
## Held flashlight (ASSET-012): in every survivor's left hand, a disguised shapeshifter's too (spec row).
const FLASHLIGHT_SCENE := "res://assets/art/props/prop_flashlight.glb"
## The flashlight's lens node; the remote light cone starts there.
const LENS := &"flashlight_lens"
const HAND_L := &"DEF-hand.L"
const HAND_R := &"DEF-hand.R"
## Grip centre in hand-bone space (Y along the hand, Z thumb side, X toward the left palm), inside the fist.
## Same numbers as tools/art/build_viewmodel.py GRIP, whose finger curl closes around it.
const GRIP := Vector3(0.035, 0.085, 0.0)
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
## Action of a shocked survivor or stunned true form (DisguisePresenter.stagger_weight > 0).
const STAGGER := &"stagger"
## LungePresenter.pose() -> true-form clip. Punch_Cross stands in for the lunge hit (CC0 library clip).
const LUNGE_CLIPS := {&"coil": &"Lunge_Coil", &"stumble": &"Lunge_Stumble", &"hit_stop": &"Punch_Cross"}
## Clips only the true form plays (char_shapeshifter_true.glb; ASSET-010).
const TRUE_FORM_CLIPS: Array[StringName] = [&"Lunge_Coil", &"Lunge_Dash", &"Lunge_Stumble", &"Punch_Cross",
	&"Hit_Head", &"Takedown_Pin"]
## Plain gait clips (anim_for's results).
const LOCOMOTION: Array[StringName] = [&"Idle", &"Walk", &"Sprint", &"Crouch_Idle", &"Crouch_Fwd", &"Crawl",
	&"Downed"]
## A one-shot that plays when the clip on the left gives way to locomotion: rescued (crawl gait ends) ->
## stand-up; the coil's end -> the dash (inference: the client sees no dash start; the coil lasts
## lunge_windup_s and the dash follows it, monster-abilities.md rule 5).
const FOLLOW := {&"Downed": &"Stand_Up", &"Crawl": &"Stand_Up", &"Lunge_Coil": &"Lunge_Dash"}

var _scenes := {}
var _materials := {}
var _acc_material: StandardMaterial3D
## handle -> [visual Node3D, appearance, last pos, last ms, smoothed speed, last clip]
## ponytail: entries of departed handles stay until the handle is reused (bounded by MAX_BODIES).
var _shown := {}


## [tint, accessory node name, stripe row] for `appearance`; the plain fallback for an unknown id.
static func look_of(appearance: int) -> Array:
	return LOOKS.get(appearance, [Color.WHITE, &"", NO_STRIPE])


## Animation name for a gait (MovementStep.Gait) at drawn `speed` m/s. Crawl is the Downed gait
## (MovementStep.gait): crawling when moving, the Downed pose when still. Unknown gaits walk or idle.
static func anim_for(gait: int, speed: float) -> StringName:
	var moving := speed >= MOVING_MPS
	match gait:
		MovementStep.Gait.CRAWL:
			return &"Crawl" if moving else &"Downed"
		MovementStep.Gait.CROUCH:
			return &"Crouch_Fwd" if moving else &"Crouch_Idle"
		MovementStep.Gait.SPRINT:
			return &"Sprint" if moving else &"Idle"
	return &"Walk" if moving else &"Idle"


## Clip for a body showing `appearance` with `gait` at `speed` and presentation `action` (STAGGER, a
## LungePresenter.pose() value or &""). Lunge actions apply to the true form only; unknown actions fall back
## to the gait clip.
static func clip_for(appearance: int, gait: int, speed: float, action: StringName) -> StringName:
	var true_form := appearance == CharacterDef.TRUE_FORM_APPEARANCE_ID
	if action == STAGGER:
		return &"Hit_Head" if true_form else &"Hit_Chest"
	if true_form and LUNGE_CLIPS.has(action):
		return LUNGE_CLIPS[action]
	return anim_for(gait, speed)


## Puts `item` (a prop glb: grip at its origin, up +Y, front -Z) in the fist of `skeleton`'s `bone` under a
## BoneAttachment3D. The prop's up runs along the thumb side and its front along the hand.
static func hold(skeleton: Skeleton3D, bone: StringName, item: Node3D) -> BoneAttachment3D:
	var at := BoneAttachment3D.new()
	at.bone_name = bone
	at.name = StringName("held_%s" % bone) # fixed: two builds of one look have the same node paths
	skeleton.add_child(at)
	item.scene_file_path = ""
	item.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), GRIP * Vector3(1.0 if bone == HAND_L else -1.0, 1, 1))
	at.add_child(item)
	return at


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
			mi.material_override = material(appearance)
	if not true_form:
		var keep: StringName = look_of(appearance)[1]
		for acc: Node in n.find_children("acc_*", "MeshInstance3D", true, false):
			if acc.name != keep:
				acc.get_parent().remove_child(acc)
				acc.free()
			else:
				(acc as MeshInstance3D).material_override = _accessory_material()
		var torch := _scene(FLASHLIGHT_SCENE).instantiate() as Node3D
		for mi: Node in torch.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = _accessory_material()
		hold(n.find_child("Skeleton3D", true, false) as Skeleton3D, HAND_L, torch)
	_play(n, &"Idle")
	return n


## Draws handle `h`'s art under its greybox `mesh` (RoundClient remote "Mesh"), whose capsule is detached:
## rebuilt when the appearance changes, animated from gait and drawn speed. The art also shows while
## transforming; TransformPresenter lays the warp over its meshes (ASSET-078).
func show(h: int, mesh: GeometryInstance3D, appearance: int, gait: int, pos: Vector3, now_ms: float,
		action: StringName = &"") -> void:
	var e: Array = _shown.get(h, [])
	if e.is_empty() or not is_instance_valid(e[0]) or (e[0] as Node).get_parent() != mesh or e[1] != appearance:
		if not e.is_empty() and is_instance_valid(e[0]):
			(e[0] as Node).get_parent().remove_child(e[0])
			(e[0] as Node).free()
		var v := build(appearance)
		mesh.add_child(v)
		v.position.y = -mesh.position.y # "Mesh" sits at half the capsule height; the art stands on the floor
		e = [v, appearance, pos, now_ms, 0.0, &"Idle"]
		_shown[h] = e
	var dt := (now_ms - (e[3] as float)) / 1000.0
	if dt > 0.0:
		var raw := ((pos - (e[2] as Vector3)) * Vector3(1, 0, 1)).length() / dt
		e[4] = lerpf(e[4], raw, SPEED_SMOOTHING) if e[4] > 0.0 else raw
		e[2] = pos
		e[3] = now_ms
	var node := e[0] as Node3D
	# The capsule mesh is detached rather than hidden (hiding "Mesh" would hide the art under it; a zero
	# render layer mask made Godot 4.7.2 log "indexing did not unpair geometries from light" at teardown).
	mesh.mesh = null
	var clip := clip_for(appearance, gait, e[4], action)
	var ap := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if LOCOMOTION.has(clip) and not FOLLOW.has(clip): # leaving Downed or the coil: follow it; let a follow-up finish
		if FOLLOW.has(e[5]):
			clip = FOLLOW[e[5]]
		elif FOLLOW.values().has(e[5]) and ap != null and ap.is_playing() and ap.current_animation == e[5]:
			clip = e[5]
	e[5] = clip
	_play(node, clip)
	# The remote light cone (RoundClient "Cone", a sibling of "Mesh") starts at the held flashlight's lens; it
	# keeps the body's yaw (no pitch is replicated). The lens is one pose update behind, a frame at most.
	var cone := mesh.get_parent().get_node_or_null(^"Cone") as Node3D if mesh.get_parent() != null else null
	var lens := node.find_child(LENS, true, false) as Node3D
	if cone != null and lens != null and lens.is_inside_tree():
		cone.global_position = lens.global_position


func _play(n: Node3D, anim: StringName) -> void:
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# assigned_animation, not current_animation: a finished one-shot (a held coil) must not restart.
	if ap != null and ap.assigned_animation != anim and ap.has_animation(anim):
		ap.play(anim, BLEND_S)


func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


## The body ShaderMaterial of `appearance`'s look (shared per look; the plain one for an unknown id).
func material(appearance: int) -> ShaderMaterial:
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
