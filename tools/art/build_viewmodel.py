"""Builds the first-person arms and held items (ASSET-011..014, design/assets/specs/characters-assets.md;
art bible §5 shared-rig rule, §8 budgets) in Blender, and renders preview PNGs.

Re-runnable, no manual steps:
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
      --python tools/art/build_viewmodel.py

Source: the survivor body this project already ships (assets/art/characters/survivors/char_survivor_body.glb,
built by tools/art/build_characters.py from the CC0 Quaternius rig). The arms are cut from its LOD0, so they
keep its UVs and use its texture set and suit tint (art bible §8: FP arms use the same swappable material).
Run build_characters.py first if that glb is missing.

Writes:
  assets/art/characters/viewmodel/char_viewmodel_arms.glb   arms + rig, poses VM_Idle (flashlight + taser),
      VM_Idle_Light (flashlight only), VM_Reach (interact). Origin = the eye; faces -Z in Godot.
  assets/art/props/prop_flashlight.glb   grip at the origin, up +Y, beam -Z; child "flashlight_lens" at the lens
  assets/art/props/prop_taser.glb        grip at the origin; children "cartridge_0".."cartridge_{N-1}" (window)
  assets/art/props/prop_taser_dart.glb   wire end at the origin, tip toward -Z
  production/qa/evidence/viewmodel/*.png  Cycles previews, near-dark with a warm spot
Held-item placement in the hand is Viewmodel.grip() / BodyVisual (Godot); this script uses the same numbers.
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BODY_GLB = os.path.join(ROOT, "assets", "art", "characters", "survivors", "char_survivor_body.glb")
TEX_DIR = os.path.join(ROOT, "assets", "art", "characters", "survivors")
OUT_VM = os.path.join(ROOT, "assets", "art", "characters", "viewmodel")
OUT_PROPS = os.path.join(ROOT, "assets", "art", "props")
OUT_EVIDENCE = os.path.join(ROOT, "production", "qa", "evidence", "viewmodel")

## Art bible §8 engine budgets (inference there; profiling settles them).
ARMS_MAX_TRIS = 8000
PROP_MAX_TRIS = 1500
DART_MAX_TRIS = 200
## data/knobs/controller.tres eye_height_m: the camera sits on the body axis this high above the feet.
EYE = Vector((0.0, 0.0, 1.6))
## data/knobs/defense.tres stun_item_charges: cartridges modelled in the taser window.
CARTRIDGES = 2
## Grip centre in hand-bone space (Y along the hand, Z thumb side, X palm side on the left hand): between the
## palm and the finger roots, inside the fist. Same numbers as Viewmodel.GRIP (src/feature/match_flow).
GRIP = (0.035, 0.085, 0.0)

## T-pose |x| beyond which upper-arm faces are kept (shoulder 0.19, elbow 0.47 in the source rig).
UPPER_ARM_KEEP_X = 0.32
ARM = ("DEF-upper_arm", "DEF-forearm", "DEF-hand", "DEF-f_", "DEF-thumb")
FINGERS = ("f_index", "f_middle", "f_ring", "f_pinky")


def lin(srgb8):
	c = srgb8 / 255.0
	return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(hex_):
	return tuple(lin(int(hex_[i:i + 2], 16)) for i in (1, 3, 5))


# Prop palette (linear). Art bible §4: yellow/black hazard pairing; §6 albedo within sRGB 32-225.
YELLOW = rgb("#E3B31C")
BLACK = (lin(34), lin(34), lin(36))
RUBBER = (lin(46), lin(46), lin(48))
STEEL = (lin(120), lin(122), lin(126))
LENS = (lin(225), lin(220), lin(205))
CART = (lin(214), lin(205), lin(178))


def tris(obj):
	return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def activate(obj):
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj


def triangulate(obj):
	bm = bmesh.new()
	bm.from_mesh(obj.data)
	bmesh.ops.triangulate(bm, faces=bm.faces)
	bm.to_mesh(obj.data)
	bm.free()


def export(path, objects, animations):
	bpy.ops.object.select_all(action="DESELECT")
	for o in objects:
		o.select_set(True)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
		export_animations=animations, export_animation_mode="ACTIONS", export_force_sampling=True,
		export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_apply=False,
		export_skins=animations, export_morph=False, export_yup=True, export_image_format="NONE",
		export_materials="EXPORT")


# --- arms ----------------------------------------------------------------------------------------

def load_body():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	# BLENDER bone heuristic: the glb was written by Blender, so the bone frames round-trip unchanged and match
	# the Godot skeleton's (checked: DEF-hand.L axes agree in both).
	bpy.ops.import_scene.gltf(filepath=BODY_GLB, bone_heuristic="BLENDER")
	rig = bpy.data.objects["Rig"]
	body = bpy.data.objects["char_survivor_body_lod0"]
	for o in list(bpy.data.objects):
		if o not in (rig, body):
			bpy.data.objects.remove(o)
	for a in list(bpy.data.actions):
		bpy.data.actions.remove(a)
	if rig.animation_data:
		rig.animation_data.action = None
	return rig, body


def cut_arms(body):
	"""Keeps the faces whose every vertex is weighted mostly to an arm or hand bone."""
	names = {g.index: g.name for g in body.vertex_groups}
	keep = []
	for v in body.data.vertices:
		best = max(v.groups, key=lambda g: g.weight, default=None)
		g = names[best.group] if best is not None else ""
		# Only the elbow end of the upper arm ever shows under the camera; the rest goes to the triangle budget.
		keep.append(g.startswith(ARM) and (not g.startswith("DEF-upper_arm") or abs(v.co.x) > UPPER_ARM_KEEP_X))
	bm = bmesh.new()
	bm.from_mesh(body.data)
	bm.verts.ensure_lookup_table()
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if not all(keep[v.index] for v in f.verts)], context="FACES")
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
	bm.to_mesh(body.data)
	bm.free()
	body.name = body.data.name = "char_viewmodel_arms"


def hand_matrix(pos, fwd_down_deg, palm_down=False, side=1):
	"""Rig-space matrix of a hand bone: Y (along the hand) forward (-Y), tilted down; Z (thumb side) up, so a fist
	holds a pistol grip upright. palm_down: the open reaching hand, palm toward the floor."""
	t = math.radians(fwd_down_deg)
	y = Vector((0.0, -math.cos(t), -math.sin(t)))
	if palm_down:
		x = Vector((0.0, 0.0, -side))  # palm side is +X on the left hand, -X on the right
		z = x.cross(y)
	else:
		z = Vector((0.0, 0.0, 1.0))
		z = (z - y * z.dot(y)).normalized()
		x = y.cross(z)
	m = Matrix((x, y, z)).transposed().to_4x4()
	m.translation = pos
	return m


## Wrist targets relative to the eye (rig space: +X = the body's left, -Y forward, +Z up), degrees of downward
## tilt, finger curl (degrees per joint) and palm-down. None = that arm hangs out of view.
POSES = {
	"VM_Idle": {"L": ((0.17, -0.40, -0.13), 4, 72, False), "R": ((-0.16, -0.42, -0.13), 0, 72, False)},
	"VM_Idle_Light": {"L": ((0.14, -0.42, -0.12), 2, 72, False), "R": None},
	"VM_Reach": {"L": ((0.19, -0.36, -0.17), 10, 72, False), "R": ((-0.09, -0.44, -0.02), -25, 8, True)},
}
HANG = {"L": (0.26, 0.05, -0.85), "R": (-0.26, 0.05, -0.85)}


def setup_ik(rig):
	tgts = {}
	for s in ("L", "R"):
		e = bpy.data.objects.new("tgt_" + s, None)
		bpy.context.scene.collection.objects.link(e)
		p = bpy.data.objects.new("pole_" + s, None)
		bpy.context.scene.collection.objects.link(p)
		fa = rig.pose.bones["DEF-forearm." + s]
		ik = fa.constraints.new("IK")
		ik.target = e
		ik.pole_target = p
		ik.chain_count = 2
		ik.use_tail = True
		ik.use_stretch = False
		cr = rig.pose.bones["DEF-hand." + s].constraints.new("COPY_ROTATION")
		cr.target = e
		tgts[s] = (e, p, ik)
	return tgts


def curl(rig, side, deg):
	"""Rotates every finger joint toward the palm by `deg`, the thumb by part of it."""
	hand = rig.data.bones["DEF-hand." + side]
	palm = 1.0 if side == "L" else -1.0
	axis = hand.matrix_local.to_3x3() @ Vector((0.0, 1.0, 0.0)).cross(Vector((palm, 0.0, 0.0)))
	for pb in rig.pose.bones:
		n = pb.name
		if not n.endswith("." + side) or not n.startswith(("DEF-f_", "DEF-thumb")):
			continue
		a = deg * (0.8 if "thumb" in n else 1.0)
		if "thumb.01" in n:
			a = deg * 0.4
		local = (pb.bone.matrix_local.to_3x3().inverted() @ axis).normalized()
		pb.rotation_mode = "QUATERNION"
		pb.rotation_quaternion = Quaternion(local, math.radians(a))


def place(rig, tgts, side, spec):
	e, p, ik = tgts[side]
	sgn = 1.0 if side == "L" else -1.0
	if spec is None:
		pos = EYE + Vector(HANG[side])
		e.matrix_world = Matrix.Translation(pos) @ Matrix.Rotation(math.radians(-90 * sgn), 4, "Y") @ \
			Matrix.Rotation(math.radians(90), 4, "X")
		curl(rig, side, 20)
	else:
		off, tilt, crl, palm_down = spec
		e.matrix_world = hand_matrix(EYE + Vector(off), tilt, palm_down, sgn)
		curl(rig, side, crl)
	# Elbow down and out: try the pole angles and keep the one that bends that way.
	sh = rig.pose.bones["DEF-upper_arm." + side].head
	wr = e.matrix_world.translation
	p.location = (sh + wr) / 2 + Vector((0.25 * sgn, 0.15, -0.45))
	want = (p.location - (sh + wr) / 2).normalized()
	best = None
	for ang in range(-180, 180, 15):
		ik.pole_angle = math.radians(ang)
		bpy.context.view_layer.update()
		elbow = rig.pose.bones["DEF-forearm." + side].head
		score = (elbow - (sh + wr) / 2).normalized().dot(want)
		if best is None or score > best[0]:
			best = (score, ang)
	ik.pole_angle = math.radians(best[1])
	bpy.context.view_layer.update()


def bake_poses(rig):
	tgts = setup_ik(rig)
	activate(rig)
	bpy.ops.object.mode_set(mode="POSE")
	bpy.ops.pose.select_all(action="SELECT")
	actions = []
	for name, spec in POSES.items():
		for s in ("L", "R"):
			place(rig, tgts, s, spec[s])
		bpy.context.scene.frame_set(1)
		bpy.ops.nla.bake(frame_start=1, frame_end=2, only_selected=False, visual_keying=True,
			clear_constraints=False, use_current_action=False, bake_types={"POSE"})
		act = rig.animation_data.action
		act.name = name
		act.use_fake_user = True
		actions.append(act)
		rig.animation_data.action = None
	bpy.ops.object.mode_set(mode="OBJECT")
	for pb in rig.pose.bones:
		for c in list(pb.constraints):
			pb.constraints.remove(c)
	for s in ("L", "R"):
		bpy.data.objects.remove(tgts[s][0])
		bpy.data.objects.remove(tgts[s][1])
	return actions


def build_arms():
	rig, body = load_body()
	cut_arms(body)
	triangulate(body)
	if tris(body) > ARMS_MAX_TRIS:  # the source hands are dense; collapse evenly, as build_characters' LODs do
		m = body.modifiers.new("Decimate", "DECIMATE")
		m.ratio = ARMS_MAX_TRIS / tris(body) * 0.98
		activate(body)
		bpy.ops.object.modifier_move_to_index(modifier="Decimate", index=0)
		bpy.ops.object.modifier_apply(modifier="Decimate")
		triangulate(body)
	n = tris(body)
	assert n <= ARMS_MAX_TRIS, n
	actions = bake_poses(rig)
	# Origin at the eye, facing Godot -Z (Blender +Y after the turn): the node sits straight under the camera.
	rig.matrix_world = Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Translation(-EYE)
	for a in actions:
		rig.animation_data.action = a
	rig.animation_data.action = actions[0]
	export(os.path.join(OUT_VM, "char_viewmodel_arms.glb"), [rig, body], True)
	print("ARMS_TRIS", n)
	return rig, body, actions, n


# --- props (Blender: up +Z, forward +Y = Godot -Z; grip centre at the origin) --------------------

def part(bm, colour_idx, verts):
	for f in {f for v in verts for f in v.link_faces}:
		f.material_index = colour_idx
	bm.verts.index_update()


def cyl(bm, centre, r1, r2, depth, segs, axis, ci):
	r = bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
	vs = r["verts"]
	if axis == "Y":
		bmesh.ops.rotate(bm, verts=vs, cent=Vector(), matrix=Matrix.Rotation(-math.pi / 2, 3, "X"))
	elif axis == "X":
		bmesh.ops.rotate(bm, verts=vs, cent=Vector(), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
	bmesh.ops.translate(bm, vec=Vector(centre), verts=vs)
	part(bm, ci, vs)


def box(bm, centre, size, ci, rot_x=0.0):
	r = bmesh.ops.create_cube(bm, size=1.0)
	vs = r["verts"]
	bmesh.ops.scale(bm, vec=Vector(size), verts=vs)
	if rot_x:
		bmesh.ops.rotate(bm, verts=vs, cent=Vector(), matrix=Matrix.Rotation(rot_x, 3, "X"))
	bmesh.ops.translate(bm, vec=Vector(centre), verts=vs)
	part(bm, ci, vs)


def mesh_obj(name, bm, palette, material):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(o)
	attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
	for p in me.polygons:
		c = palette[p.material_index]
		for li in p.loop_indices:
			attr.data[li].color = (c[0], c[1], c[2], 1.0)
		p.material_index = 0
	me.materials.append(material)
	triangulate(o)
	return o


def prop_material(name):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	vc = nt.nodes.new("ShaderNodeVertexColor")
	vc.layer_name = "Col"
	bsdf = nt.nodes["Principled BSDF"]
	nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
	bsdf.inputs["Roughness"].default_value = 0.5
	return m


def build_flashlight():
	"""Chunky industrial lantern torch: rubber pistol grip, barrel over the fist, flared head (ASSET-012)."""
	mat = prop_material("mat_prop_flashlight")
	bm = bmesh.new()
	cyl(bm, (0, 0, -0.005), 0.018, 0.017, 0.105, 12, "Z", 0)  # rubber grip
	for z in (-0.04, -0.015, 0.01, 0.035):
		cyl(bm, (0, 0, z), 0.0195, 0.0195, 0.008, 12, "Z", 0)  # grip ribs
	box(bm, (0, -0.005, 0.058), (0.026, 0.05, 0.03), 1)  # neck
	cyl(bm, (0, 0.035, 0.078), 0.027, 0.027, 0.16, 16, "Y", 1)  # barrel
	cyl(bm, (0, 0.131, 0.078), 0.029, 0.043, 0.04, 20, "Y", 2)  # head flare
	cyl(bm, (0, 0.153, 0.078), 0.045, 0.045, 0.008, 20, "Y", 0)  # rubber bumper
	cyl(bm, (0, -0.045, 0.078), 0.024, 0.024, 0.01, 16, "Y", 0)  # tail cap
	box(bm, (0, 0.03, 0.107), (0.012, 0.022, 0.008), 3)  # switch
	body = mesh_obj("prop_flashlight", bm, [RUBBER, (lin(64), lin(64), lin(68)), STEEL, YELLOW], mat)
	bm = bmesh.new()
	cyl(bm, (0, 0, 0), 0.038, 0.038, 0.004, 20, "Y", 0)
	lens = mesh_obj("flashlight_lens", bm, [LENS], mat)
	lens.location = (0, 0.157, 0.078)
	lens.parent = body
	return [body, lens]


def build_taser():
	"""Blocky yellow/black stun gun; the cartridges sit in an open window on top, one object each (ASSET-013)."""
	mat = prop_material("mat_prop_taser")
	bm = bmesh.new()
	box(bm, (0, -0.006, -0.005), (0.03, 0.036, 0.11), 1, rot_x=math.radians(-12))  # grip
	box(bm, (0, -0.012, -0.03), (0.032, 0.04, 0.004), 0)  # grip band
	box(bm, (0, 0.045, 0.073), (0.038, 0.16, 0.05), 0)  # body
	box(bm, (0, 0.13, 0.073), (0.04, 0.012, 0.054), 1)  # black front plate
	box(bm, (0, 0.04, 0.045), (0.006, 0.04, 0.018), 1)  # trigger guard
	box(bm, (0, 0.032, 0.03), (0.022, 0.006, 0.026), 1)
	box(bm, (0, 0.03, 0.1), (0.03, 0.09, 0.006), 1)  # window frame on top
	box(bm, (0.017, 0.10, 0.073), (0.006, 0.04, 0.01), 1)  # side hazard bars
	box(bm, (-0.017, 0.10, 0.073), (0.006, 0.04, 0.01), 1)
	body = mesh_obj("prop_taser", bm, [YELLOW, BLACK], mat)
	out = [body]
	for i in range(CARTRIDGES):
		bm = bmesh.new()
		box(bm, (0, 0, 0), (0.022, 0.03, 0.012), 0)
		box(bm, (0, 0.016, 0), (0.016, 0.003, 0.008), 1)  # contact face
		c = mesh_obj("cartridge_%d" % i, bm, [CART, YELLOW], mat)
		c.location = (0, 0.005 + 0.038 * i, 0.105)
		c.parent = body
		out.append(c)
	return out


def build_dart():
	"""One probe: barbed steel tip, yellow body, two fins; the wire is VFX (ASSET-014)."""
	mat = prop_material("mat_prop_taser_dart")
	bm = bmesh.new()
	cyl(bm, (0, 0.01, 0), 0.0035, 0.0035, 0.02, 8, "Y", 0)
	cyl(bm, (0, 0.026, 0), 0.0035, 0.0, 0.012, 8, "Y", 1)
	box(bm, (0, 0.002, 0), (0.012, 0.006, 0.001), 0)
	box(bm, (0, 0.002, 0), (0.001, 0.006, 0.012), 0)
	return [mesh_obj("prop_taser_dart", bm, [YELLOW, STEEL], mat)]


def build_props():
	report = {}
	for name, fn, cap in (("prop_flashlight", build_flashlight, PROP_MAX_TRIS),
			("prop_taser", build_taser, PROP_MAX_TRIS), ("prop_taser_dart", build_dart, DART_MAX_TRIS)):
		objs = fn()
		n = sum(tris(o) for o in objs)
		assert n <= cap, (name, n)
		report[name] = n
		export(os.path.join(OUT_PROPS, name + ".glb"), objs, False)
	print("PROP_TRIS", report)
	return report


# --- previews ------------------------------------------------------------------------------------

def arms_material(tint_hex):
	m = bpy.data.materials.new("preview_arms")
	m.use_nodes = True
	nt = m.node_tree
	img = nt.nodes.new("ShaderNodeTexImage")
	img.image = bpy.data.images.load(os.path.join(TEX_DIR, "char_survivor_body_albedo_1024.png"))
	uv = nt.nodes.new("ShaderNodeUVMap")
	uv.uv_map = "UVMap"
	nt.links.new(uv.outputs["UV"], img.inputs["Vector"])
	mix = nt.nodes.new("ShaderNodeMix")
	mix.data_type = "RGBA"
	mix.blend_type = "MULTIPLY"
	mix.inputs["B"].default_value = (*rgb(tint_hex), 1.0)
	nt.links.new(img.outputs["Alpha"], mix.inputs["Factor"])
	nt.links.new(img.outputs["Color"], mix.inputs["A"])
	bsdf = nt.nodes["Principled BSDF"]
	nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
	bsdf.inputs["Roughness"].default_value = 0.8
	return m


def preview_scene():
	sc = bpy.context.scene
	sc.render.engine = "CYCLES"
	sc.cycles.device = "CPU"
	sc.cycles.samples = 48
	sc.render.resolution_x = 960
	sc.render.resolution_y = 540
	sc.view_settings.view_transform = "Standard"
	world = bpy.data.worlds.new("dark")
	world.use_nodes = True
	# VM_DEBUG=1: a bright world for checking shapes (not evidence).
	amb = 0.4 if os.environ.get("VM_DEBUG") else 0.002
	world.node_tree.nodes["Background"].inputs["Color"].default_value = (amb, amb, amb * 1.5, 1)
	sc.world = world
	wall = bpy.data.materials.new("wall")
	wall.use_nodes = True
	wall.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (lin(70), lin(72), lin(74), 1)
	bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 2.5, 0), rotation=(math.pi / 2, 0, 0))
	bpy.context.object.data.materials.append(wall)
	bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, -1.6))
	bpy.context.object.data.materials.append(wall)
	cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
	sc.collection.objects.link(cam)
	cam.data.sensor_fit = "VERTICAL"
	cam.data.angle = math.radians(75)  # Godot Camera3D default fov (vertical)
	cam.data.clip_start = 0.05
	cam.rotation_euler = (math.pi / 2, 0, 0)  # looks +Y
	sc.camera = cam
	# The own flashlight cone sits on the camera (RoundClient._cone); Bone Flashlight #F2E6C8 (art bible §4).
	ld = bpy.data.lights.new("torch", "SPOT")
	ld.color = rgb("#F2E6C8")
	ld.energy = 60
	ld.spot_size = math.radians(50)
	ld.spot_blend = 0.5
	ld.shadow_soft_size = 0.02
	lo = bpy.data.objects.new("torch", ld)
	sc.collection.objects.link(lo)
	lo.location = (0.05, 0.0, -0.05)
	lo.rotation_euler = (math.pi / 2, 0, 0)
	return cam


def render(path):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.context.scene.render.filepath = path
	bpy.ops.render.render(write_still=True)


def hand_world(rig, side):
	return rig.matrix_world @ rig.pose.bones["DEF-hand." + side].matrix


def grip_matrix(side):
	g = Vector(GRIP)
	if side == "R":
		g.x = -g.x
	return Matrix.Translation(g)


def previews(rig, body, actions):
	cam = preview_scene()
	props = {}
	for path in ("prop_flashlight", "prop_taser"):
		bpy.ops.import_scene.gltf(filepath=os.path.join(OUT_PROPS, path + ".glb"))
		props[path] = [o for o in bpy.context.selected_objects if o.parent is None][0]
	for o in bpy.data.objects:
		if o.type == "MESH" and o.data.color_attributes and o.name.startswith(("prop_", "cartridge", "flashlight")):
			for m in o.data.materials:
				if m and m.node_tree:
					bsdf = m.node_tree.nodes.get("Principled BSDF")
					vc = m.node_tree.nodes.new("ShaderNodeVertexColor")
					vc.layer_name = o.data.color_attributes[0].name
					m.node_tree.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
	shots = [("VM_Idle", "#E3B31C", True), ("VM_Idle_Light", "#2E63B8", False), ("VM_Reach", "#C8581E", False)]
	for act_name, tint, taser in shots:
		body.data.materials.clear()
		body.data.materials.append(arms_material(tint))
		rig.animation_data.action = bpy.data.actions[act_name]
		bpy.context.scene.frame_set(1)
		bpy.context.view_layer.update()
		props["prop_flashlight"].matrix_world = hand_world(rig, "L") @ grip_matrix("L")
		t = props["prop_taser"]
		t.hide_render = not taser
		t.matrix_world = hand_world(rig, "R") @ grip_matrix("R")
		for c in t.children:
			c.hide_render = not taser
		render(os.path.join(OUT_EVIDENCE, "viewmodel_%s.png" % act_name.lower()))
		lens = [c for c in props["prop_flashlight"].children if c.name.startswith("flashlight_lens")][0]
		p = lens.matrix_world.translation
		print("LENS_GODOT", act_name, (round(p.x, 3), round(p.z, 3), round(-p.y, 3)))  # Godot camera space
		if os.environ.get("VM_DEBUG"):  # side views of both hands for checking the grip
			keep = cam.matrix_world.copy()
			for side, x in (("L", -0.45), ("R", 0.45)):
				cam.matrix_world = Matrix.Translation((x, 0.35, -0.2)) @ Matrix.Rotation(math.radians(90), 4, "X") @ 					Matrix.Rotation(math.radians(-90 if x < 0 else 90), 4, "Y")
				render(os.path.join(os.environ["VM_DEBUG"], "side_%s_%s.png" % (act_name, side)))
			cam.matrix_world = keep
	# Prop close-ups: the arms hidden, each prop in front of the camera in the warm spot.
	rig.hide_render = body.hide_render = True
	for o in props.values():
		for x in [o] + list(o.children):
			x.hide_render = True
	dart = None
	bpy.ops.import_scene.gltf(filepath=os.path.join(OUT_PROPS, "prop_taser_dart.glb"))
	dart = bpy.context.selected_objects[0]
	for name, o, dist, scale in (("flashlight", props["prop_flashlight"], 0.42, 1.0),
			("taser", props["prop_taser"], 0.38, 1.0), ("dart", dart, 0.12, 1.0)):
		for x in [o] + list(o.children):
			x.hide_render = False
		o.matrix_world = Matrix.Translation((0.0, dist, -0.02)) @ Matrix.Rotation(math.radians(-60), 4, "Z") @ \
			Matrix.Rotation(math.radians(15), 4, "X")
		if name == "dart":
			cam.data.angle = math.radians(20)
		render(os.path.join(OUT_EVIDENCE, "prop_%s.png" % name))
		for x in [o] + list(o.children):
			x.hide_render = True


def main():
	props = build_props()
	rig, body, actions, n = build_arms()
	previews(rig, body, actions)
	print("DONE arms", n, "props", props)


if __name__ == "__main__":
	main()
