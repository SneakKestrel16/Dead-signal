"""Builds the shapeshifter true form, the failed experiment (art bible §5, design/art/true-form-review.md), from a
MakeHuman base mesh instead of script primitives: real human anatomy, starved and stretched.

  BLENDER_USER_RESOURCES=tools/art/.cache/blender_user \
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
      --python tools/art/build_experiment.py [-- --ship]

Needs MPFB 2.0.18 (MakeHuman for Blender, GPL-3.0 code; the meshes it makes are CC0) installed into the
project-local Blender profile tools/art/.cache/blender_user (gitignored), from extensions.blender.org:
  sha256 c075b3e9b94b8e5556a5f03f4653602d02ea306de08126e8f55ed6dee28a2dad, add-on-mpfb-v2.0.18.zip
  blender --factory-startup --command extension install-file -r user_default --enable <zip>
  (with BLENDER_USER_RESOURCES set as above, so the user's own Blender is untouched)

Steps: the survivor rig with the shipped true form's clips and stretched arms (build_characters.py) -> a MakeHuman
male, starved (muscle and weight 0, MAKEHUMAN_TARGETS: torn-loose jaw, hollow cheeks, sunken eyes, long neck and
arms) with MPFB's game_engine rig and weights -> each vertex carried from the MakeHuman rest (A-pose) onto our rig's
rest (T-pose) by its own bone weights (BONE_MAP), the weights renamed onto our DEF bones -> the experiment's
hardware (surgical halo bolted to the skull, staples along an autopsy Y-incision) and teeth -> a normal map of
wrinkled skin baked from a subdivided, displaced copy onto the MakeHuman UVs -> decimated to the 15k/7k/3k budget.

Writes tools/art/review/true_e2.glb (review, gitignored), or with --ship
assets/art/characters/shapeshifter/char_shapeshifter_true.glb.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_anims  # noqa: E402
import build_characters as bc  # noqa: E402
import build_true_form as tf  # noqa: E402

MPFB = "bl_ext.user_default.mpfb"
BAKE_PX = 1024
## MakeHuman macros: an adult male starved to nothing, as tall as the base mesh goes.
MACROS = dict(gender=1.0, age=0.62, muscle=0.0, weight=0.0, height=1.0, proportions=0.3)
## (folder, target, weight) from MPFB's data/targets; sided targets load both l- and r-.
MAKEHUMAN_TARGETS = [
	("chin", "chin-jaw-drop-incr", 1.0), ("chin", "chin-height-incr", 0.6), ("chin", "chin-prognathism-decr", 0.4),
	("neck", "measure-neck-height-incr", 1.0), ("neck", "measure-neck-circ-decr", 1.0),
	("torso", "measure-waist-circ-decr", 0.5), ("torso", "torso-scale-horiz-decr", 0.5),
	("stomach", "stomach-pregnant-decr", 1.0), ("cheek", "cheek-volume-decr", 1.0), ("cheek", "cheek-bones-incr", 1.0),
	("eyes", "eye-push1-in", 1.0), ("eyes", "eye-push2-in", 1.0), ("eyes", "eye-bag-incr", 1.0),
	("arms", "measure-upperarm-circ-decr", 1.0), ("arms", "lowerarm-fat-decr", 1.0), ("arms", "upperarm-fat-decr", 1.0),
	("hands", "hand-fingers-length-incr", 1.0), ("hands", "hand-fingers-diameter-decr", 1.0),
	("legs", "measure-thigh-circ-decr", 1.0), ("legs", "measure-calf-circ-decr", 1.0), ("legs", "upperleg-fat-decr", 1.0),
	("head", "head-age-incr", 1.0), ("head", "head-fat-decr", 1.0),
]
## MPFB game_engine bone -> our DEF bone. Fingers and sides are added in bone_map().
BONE_MAP = {"pelvis": "DEF-hips", "spine_01": "DEF-spine.001", "spine_02": "DEF-spine.002",
	"spine_03": "DEF-spine.003", "neck_01": "DEF-neck", "head": "DEF-head"}
SIDED = {"clavicle": "shoulder", "upperarm": "upper_arm", "lowerarm": "forearm", "hand": "hand", "thigh": "thigh",
	"calf": "shin", "foot": "foot", "ball": "toe"}
ARM_K = 1.3  # arms past the shoulder joint, longer than any survivor's (art bible §5)
FINGER = {"index": "f_index", "middle": "f_middle", "ring": "f_ring", "pinky": "f_pinky", "thumb": "thumb"}
SKIN = ((122, 114, 108), 0.45, 0.6, 0.2)  # art bible §5: pale clammy grey, wet sheen
WRINKLE = (0.012, 0.0012)  # displace noise scale and depth (m, MakeHuman scale) for the baked skin
JAW_DEG = 26  # the dislocated jaw hangs open this far about the hinge under the ears (art bible §5)
HALO_GAP = 0.028  # ring clearance off the skull (m)
MOUTH = ((40, 12, 14), 0.8)  # the dark inside of the open mouth


def bone_map():
	m = dict(BONE_MAP)
	for s, S in (("l", "L"), ("r", "R")):
		for a, b in SIDED.items():
			m["%s_%s" % (a, s)] = "DEF-%s.%s" % (b, S)
		for a, b in FINGER.items():
			for k in (1, 2, 3):
				m["%s_0%d_%s" % (a, k, s)] = "DEF-%s.0%d.%s" % (b, k, S)
	return m


def make_human():
	bpy.ops.preferences.addon_enable(module=MPFB)
	hs = sys.modules[MPFB + ".services.humanservice"].HumanService
	ts = sys.modules[MPFB + ".services.targetservice"].TargetService
	macro = ts.get_default_macro_info_dict()
	macro.update(MACROS)
	h = hs.create_human(macro_detail_dict=macro, mask_helpers=False)
	tdir = os.path.join(os.path.dirname(sys.modules[MPFB].__file__), "data", "targets")
	for folder, name, w in MAKEHUMAN_TARGETS:
		found = [p for p in ("", "l-", "r-") if os.path.exists(os.path.join(tdir, folder, p + name + ".target.gz"))]
		assert found, name
		for p in found:
			ts.load_target(h, os.path.join(tdir, folder, p + name + ".target.gz"), weight=w, name=p + name)
	ts.bake_targets(h)
	mrig = hs.add_builtin_rig(h, "game_engine")
	body = h.vertex_groups["body"].index
	bm = bmesh.new()
	bm.from_mesh(h.data)
	keep = {v.index for v in h.data.vertices if any(g.group == body for g in v.groups)}
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context="VERTS")
	bm.to_mesh(h.data)
	bm.free()
	h.modifiers.clear()
	h.parent = None
	return h, mrig


def t_pose(h, mrig, rig):
	"""Poses MakeHuman's rig so every mapped bone points along ours (A-pose arms up into our T-pose), parents first,
	and applies it with volume-preserving skinning. Rotating the arms by blending vertex positions instead left a
	web of skin from the jaw to the arms."""
	bmap = bone_map()
	h.parent = None
	m = h.modifiers.new("Pose", "ARMATURE")
	m.object = mrig
	m.use_deform_preserve_volume = True
	bc.activate(mrig)
	bpy.ops.object.mode_set(mode="POSE")
	order = [b for b in mrig.data.bones if b.name in bmap]
	order.sort(key=lambda b: len(b.parent_recursive))
	for b in order:
		pb = mrig.pose.bones[b.name]
		bpy.context.view_layer.update()
		cur = pb.matrix.copy()
		t = rig.data.bones[bmap[b.name]]
		want = (t.tail_local - t.head_local).normalized()
		rd = cur.col[1].xyz.normalized().rotation_difference(want).to_matrix()
		new = (rd @ cur.to_3x3()).to_4x4()
		new.translation = cur.translation
		pb.matrix = new
	bpy.context.view_layer.update()
	bpy.ops.object.mode_set(mode="OBJECT")
	bc.activate(h)
	bpy.ops.object.modifier_apply(modifier="Pose")
	bc.activate(mrig)
	bpy.ops.object.mode_set(mode="POSE")
	bpy.ops.pose.armature_apply(selected=False)  # the posed rig becomes its rest, matching the mesh
	bpy.ops.object.mode_set(mode="OBJECT")


def fit_rig(h, mrig, rig):
	"""Our rig's joints moved onto MakeHuman's (now T-posed, same directions as ours, so the bone rolls and the
	clips' rotations still fit), the hips' animated translation scaled to the new hip height, the arms stretched
	(ARM_K, mesh and bones), and the weights renamed onto our DEF bones. Fitting the mesh to our rig's proportions
	instead hunched the shoulders up to the jaw (ours sit 11 cm under the head, MakeHuman's 18 cm)."""
	bmap = bone_map()
	src = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in mrig.data.bones}
	f = src["pelvis"][0].z / rig.data.bones["DEF-hips"].head_local.z
	for act in bpy.data.actions:
		for cb, fcs in bc.channelbag_fcurves(act):
			for fc in fcs:
				if fc.data_path.endswith("location"):
					for kp in fc.keyframe_points:
						kp.co.y *= f
						kp.handle_left.y *= f
						kp.handle_right.y *= f
	x0 = src["upperarm_l"][0].x  # the shoulder joint: everything further out is the arm

	def stretch(p):
		if abs(p.x) > x0:
			p = p.copy()
			p.x += math.copysign((abs(p.x) - x0) * (ARM_K - 1), p.x)
		return p
	bc.activate(rig)
	bpy.ops.object.mode_set(mode="EDIT")
	ebs = rig.data.edit_bones
	inv = {d: s_ for s_, d in bmap.items()}
	for eb in sorted(ebs, key=lambda e: len(e.parent_recursive)):
		if eb.name in inv:
			hd_, tl_ = src[inv[eb.name]]
			eb.use_connect = False
			eb.head, eb.tail = stretch(hd_), stretch(tl_)
		elif eb.name == "root":
			eb.tail = eb.head + (eb.tail - eb.head) * f
	bpy.ops.object.mode_set(mode="OBJECT")
	for v in h.data.vertices:
		v.co = stretch(v.co)
	for g in list(h.vertex_groups):
		if g.name in bmap:
			g.name = bmap[g.name]
		elif not g.name.startswith("DEF-"):
			h.vertex_groups.remove(g)
	bpy.data.objects.remove(mrig)


def smooth(t):
	t = min(1.0, max(0.0, t))
	return t * t * (3 - 2 * t)


def open_jaw(h):
	"""Hangs the jaw open by moving the mesh (the rig has no jaw bone): everything under the lip line and in front
	of the hinge turns down about the hinge, fading out at the mouth corners and towards the ears so the cheeks
	stretch. The lip line comes from MakeHuman's own "lips" group, the hinge from its "ears". Returns the mouth
	(corners, lip line, hinge, rotation) for the teeth and the inside of the mouth."""
	def members(name):
		gi = h.vertex_groups[name].index
		return [v for v in h.data.vertices if any(g.group == gi for g in v.groups)]
	lips = [v.co.copy() for v in members("lips")]
	ears = [v.co.copy() for v in members("ears")]
	corner = max(abs(c.x) for c in lips)
	line = sum((c.z for c in lips if abs(c.x) > corner * 0.85), 0.0) / len([c for c in lips if abs(c.x) > corner * 0.85])
	front = min(c.y for c in lips)
	hinge = Vector((0.0, sum(c.y for c in ears) / len(ears), sum(c.z for c in ears) / len(ears) - 0.03))
	rot = Matrix.Rotation(math.radians(JAW_DEG), 3, "X")
	head = h.vertex_groups["head"].index
	for v in h.data.vertices:
		hw = next((g.weight for g in v.groups if g.group == head), 0.0)
		if hw == 0.0 or v.co.z > line + 0.004:
			continue
		band = 0.002 if abs(v.co.x) < corner * 0.9 else 0.002 + (abs(v.co.x) - corner * 0.9) * 0.6
		w = hw * smooth((line - v.co.z) / band) * smooth((hinge.y - v.co.y) / 0.05)
		if w > 0:
			v.co = v.co.lerp(hinge + rot @ (v.co - hinge), w)
	return dict(corner=corner, line=line, front=front, hinge=hinge, rot=rot)


def surface(bvh, origin, direction):
	hit = bvh.ray_cast(Vector(origin), Vector(direction).normalized(), 1.0)
	return hit[0]


def hardware(h, rig, mouth):
	"""The experiment's metal and teeth as separate parts, each weighted to the bone it rides."""
	dg = bpy.context.evaluated_depsgraph_get()
	bvh = BVHTree.FromObject(h, dg)
	hb = rig.data.bones["DEF-head"]
	verts = [v.co for v in h.data.vertices if h.vertex_groups["DEF-head"].index in [g.group for g in v.groups]]
	lo = Vector([min(c[i] for c in verts) for i in range(3)])
	hi = Vector([max(c[i] for c in verts) for i in range(3)])
	metal, bone = bmesh.new(), bmesh.new()
	parts = []
	# halo: a ring a finger's width off the skull at the brow, pins into the bone, clamps on the ring
	z = lo.z + (hi.z - lo.z) * 0.74
	axis = Vector((hb.head_local.x, (lo.y + hi.y) / 2, z))
	ring, hits = [], []
	for i in range(24):
		a = i * math.pi / 12
		d = Vector((math.cos(a), math.sin(a), 0))
		p = surface(bvh, axis + d * 0.4, -d) or axis + d * 0.09
		hits.append(p)
		ring.append(p + d * HALO_GAP)
	tf.arc(metal, ring + ring[:1], 0.005)
	for i in (2, 6, 10, 14, 18, 22):
		tf.rod(metal, ring[i], hits[i].lerp(axis, 0.04), 0.004, 0.0025)
		tf.ellipsoid(metal, ring[i], (0.011, 0.011, 0.014), segs=8, rings=6)
	c = axis
	parts.append(("halo", metal, "DEF-head", 2))
	posts = bmesh.new()
	for s in (-1, 1):
		top = ring[0 if s > 0 else 12] + Vector((0, 0.01, 0))
		sh = rig.data.bones["DEF-shoulder.%s" % ("L" if s > 0 else "R")]
		tf.rod(posts, top, sh.head_local.lerp(sh.tail_local, 0.55) + Vector((0, 0.03, 0.03)), 0.004, 0.004)
	parts.append(("posts", posts, "DEF-spine.003", 2))
	# staples along a Y-incision on the chest, found on the skin by rays from the front
	staples = bmesh.new()
	chest = rig.data.bones["DEF-spine.003"]
	top_z = rig.data.bones["DEF-neck"].head_local.z - 0.05  # from the collarbones down to the sternum's foot
	mid_z, low_z = chest.head_local.z, rig.data.bones["DEF-hips"].head_local.z + 0.06
	lines = [((s * 0.12, top_z), (0.0, mid_z)) for s in (-1, 1)] + [((0.0, mid_z), (0.0, low_z))]
	cut = bmesh.new()
	for (x0, z0), (x1, z1) in lines:
		n = max(2, int(math.hypot(x1 - x0, z1 - z0) / 0.022))
		prev = None
		for k in range(0, n + 1):
			t = k / n
			x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
			p = surface(bvh, (x, -0.5, z), (0, 1, 0))
			if p is None:
				continue
			q = p + Vector((0, -0.0015, 0))
			if prev is not None:
				tf.rod(cut, prev, q, 0.0028, 0.0028, segs=5)
			prev = q
			if k in (0, n):
				continue
			along = Vector((x1 - x0, 0, z1 - z0)).normalized()
			side = along.cross(Vector((0, 1, 0))).normalized() * 0.016
			top = p + Vector((0, -0.005, 0))
			tf.rod(staples, top - side, top + side, 0.003, 0.003, segs=5)
			for e in (-1, 1):
				tf.rod(staples, top + side * e, p + side * e + Vector((0, 0.003, 0)), 0.003, 0.002, segs=5)
	parts.append(("incision", cut, "DEF-spine.003", 3))
	parts.append(("staples", staples, "DEF-spine.003", 2))
	# teeth: uneven rows just inside the lips, the lower one turned down with the jaw; the dark inside behind
	cx, line, y0 = mouth["corner"] * 0.8, mouth["line"], mouth["front"]
	hinge, rot = mouth["hinge"], mouth["rot"]
	for k in range(10):
		u = (k - 4.5) / 4.5
		x, y = u * cx, y0 + 0.006 + u * u * 0.02
		ln = 0.012 + (0.008 if k % 3 == 1 else 0.0)
		tf.rod(bone, (x, y, line + 0.006), (x, y + 0.001, line + 0.006 - ln), 0.0034, 0.0007, segs=5)
		lo_t = [Vector((x, y + 0.002, line - 0.006)), Vector((x, y + 0.003, line - 0.006 + ln * 0.8))]
		tf.rod(bone, *[hinge + rot @ (q - hinge) for q in lo_t], 0.0032, 0.0007, segs=5)
	parts.append(("teeth", bone, "DEF-head", 1))
	cave = bmesh.new()
	mid = Vector((0, y0 + 0.035, line - 0.012))
	tf.ellipsoid(cave, mid, (cx * 1.1, 0.03, 0.03), segs=12, rings=8)
	parts.append(("mouth", cave, "DEF-head", 3))
	objs = []
	for name, b, bname, mat in parts:
		o = tf.obj_from(b, "part_" + name)
		o.vertex_groups.new(name=bname).add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
		for p in o.data.polygons:
			p.material_index = mat
		objs.append(o)
	return objs


def build(out):
	rig, body = bc.load_source()
	for a in bpy.data.actions:  # as build_characters.build_true_form: rotations below the hips only
		for cb, fcs in bc.channelbag_fcurves(a):
			for fc in fcs:
				if fc.data_path.endswith("location") and "DEF-hips" not in fc.data_path and '"root"' not in fc.data_path:
					cb.fcurves.remove(fc)
	build_anims.add_true_clips(rig)
	bpy.data.objects.remove(body)
	h, mrig = make_human()
	t_pose(h, mrig, rig)
	mouth = open_jaw(h)
	fit_rig(h, mrig, rig)
	h.data.materials.clear()
	for args in (("mat_shapeshifter_skin",) + SKIN, ("mat_shapeshifter_bone", (206, 198, 178), 0.55),
			("mat_shapeshifter_metal", (128, 128, 132), 0.35, 0.0, 0.1, 1.0), ("mat_shapeshifter_mouth",) + MOUTH):
		h.data.materials.append(tf.material(*args))
	for p in h.data.polygons:
		p.material_index = 0
	parts = hardware(h, rig, mouth)
	# high: subdivided skin with wrinkle noise, for the bake only
	high = tf.copy(h)
	high.modifiers.new("Sub", "SUBSURF").levels = 2
	tex = bpy.data.textures.new("wrinkle", "CLOUDS")
	tex.noise_scale = WRINKLE[0]
	tex.noise_depth = 4
	d = high.modifiers.new("Wrinkle", "DISPLACE")
	d.texture, d.texture_coords, d.strength, d.mid_level = tex, "GLOBAL", WRINKLE[1], 0.5
	bc.activate(high)
	for m in list(high.modifiers):
		bpy.ops.object.modifier_apply(modifier=m.name)
	# low: the skin decimated to what the budget leaves after the hardware, then joined with it
	bc.triangulate(h)
	for o in parts:
		bc.triangulate(o)
	room = bc.LOD_TRIS[0] - sum(bc.tris(o) for o in parts)
	if bc.tris(h) > room:
		m = h.modifiers.new("Dec", "DECIMATE")
		m.ratio = room / bc.tris(h) * 0.98
		bc.activate(h)
		bpy.ops.object.modifier_apply(modifier="Dec")
		bc.triangulate(h)
	bpy.ops.object.select_all(action="DESELECT")
	for o in parts:
		o.data.materials.clear()
		for m in h.data.materials:
			o.data.materials.append(m)
		o.select_set(True)
	h.select_set(True)
	bpy.context.view_layer.objects.active = h
	bpy.ops.object.join()
	h.name = h.data.name = "char_shapeshifter_true_lod0"
	bake(high, h, os.path.splitext(out)[0] + "_normal_1024.png")
	bpy.data.objects.remove(high)
	h.parent = rig
	arm = h.modifiers.new("Armature", "ARMATURE")
	arm.object = rig
	assert bc.tris(h) <= bc.LOD_TRIS[0], bc.tris(h)
	lods = [h] + [bc.decimate_copy(h, "char_shapeshifter_true_lod%d" % i, bc.LOD_TRIS[i]) for i in (1, 2)]
	top = max((rig.matrix_world @ v.co).z for v in h.data.vertices)
	rig.scale = (bc.TRUE_HEIGHT_M / top,) * 3
	bpy.ops.object.select_all(action="DESELECT")
	for o in [rig] + lods:
		o.select_set(True)
	os.makedirs(os.path.dirname(out), exist_ok=True)
	bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True,
		export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
		export_apply=False, export_skins=True, export_morph=False, export_yup=True,
		export_image_format="AUTO", export_materials="EXPORT")
	report = {o.name: bc.tris(o) for o in lods}
	print("TRUE_TRIS", report)
	return report


def bake(high, low, path):
	"""Wrinkled-skin normal map from the high copy onto the low mesh's own MakeHuman UVs (Cycles, CPU)."""
	img = bpy.data.images.new(os.path.splitext(os.path.basename(path))[0], BAKE_PX, BAKE_PX, float_buffer=False)
	img.colorspace_settings.name = "Non-Color"
	for mat in low.data.materials:
		n = mat.node_tree.nodes.new("ShaderNodeTexImage")
		n.image = img
		mat.node_tree.nodes.active = n
	sc = bpy.context.scene
	sc.render.engine = "CYCLES"
	sc.cycles.device = "CPU"
	sc.cycles.samples = 1
	bpy.ops.object.select_all(action="DESELECT")
	high.select_set(True)
	low.select_set(True)
	bpy.context.view_layer.objects.active = low
	bpy.ops.object.bake(type="NORMAL", use_selected_to_active=True, cage_extrusion=0.006, max_ray_distance=0.02,
		margin=4)
	img.filepath_raw = path
	img.file_format = "PNG"
	img.save()
	mat = low.data.materials[0]  # the skin only: metal and bone stay smooth
	nodes, links = mat.node_tree.nodes, mat.node_tree.links
	nm = nodes.new("ShaderNodeNormalMap")
	links.new(nodes.active.outputs["Color"], nm.inputs["Color"])
	links.new(nm.outputs["Normal"], nodes["Principled BSDF"].inputs["Normal"])
	for m in low.data.materials[1:]:
		m.node_tree.nodes.remove(m.node_tree.nodes.active)


def main():
	bc.fetch()
	ship = "--ship" in sys.argv
	out = os.path.join(bc.OUT_TRUE, "char_shapeshifter_true.glb") if ship else \
		os.path.join(bc.ROOT, "tools", "art", "review", "true_e2.glb")
	print("DONE", build(out))


if __name__ == "__main__":
	main()
