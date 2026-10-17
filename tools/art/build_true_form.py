"""Builds a new shapeshifter true form (option D, design/art/true-form-review.md) in Blender: a body grown along the
rig's own bones instead of the survivor mannequin with parts glued on.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
      --python tools/art/build_true_form.py [-- --ship]

Steps: the survivor rig (same clips as the shipped true form, arms stretched as build_characters.py does) ->
a skin-modifier body along the DEF bones, thin with knobbed joints -> skull, jaw, ribs, spine, shoulder blades,
claws and teeth as shapes -> one voxel-remeshed surface with flesh noise (the high mesh) -> decimated to the
15k/7k/3k budget, bone material where the high mesh's bone shapes are, normal map baked high -> low, automatic
weights to the rig. Art bible §5 limits: 2.4 m, over-long arms, narrow trunk, wet near-black, bone-white focal
points at albedo 190-220, no emissive eyes (no eyes at all).

Writes tools/art/review/true_d.glb (review, gitignored), or with --ship
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

VOXEL_M = 0.004
HEAD_SCALE = 1.3
NOISE_M = 0.0035  # flesh wrinkle depth
BAKE_PX = 1024
## Skin radius (m, source rig scale) at points along each DEF bone: (bone, [(t along bone, radius x, radius y)]).
## Joints wider than the shafts between them: knobbed, starved limbs.
LIMB_PROFILE = {
	"shoulder": [(0.6, 0.04, 0.035), (1.0, 0.036, 0.034)],
	"upper_arm": [(0.0, 0.034, 0.034), (0.5, 0.019, 0.02), (1.0, 0.03, 0.028)],
	"forearm": [(0.5, 0.016, 0.017), (1.0, 0.018, 0.014)],
	"hand": [(1.0, 0.026, 0.011)],
	"thigh": [(0.0, 0.05, 0.05), (0.5, 0.03, 0.032), (1.0, 0.036, 0.036)],
	"shin": [(0.5, 0.021, 0.023), (1.0, 0.02, 0.022)],
	"foot": [(1.0, 0.03, 0.022)],
	"toe": [(1.0, 0.022, 0.012)],
}
## Trunk centreline (z, radius x, radius y, y offset): narrow pelvis, starved waist, deep narrow chest.
TRUNK = [(0.93, 0.07, 0.05, 0.03), (1.02, 0.06, 0.045, 0.02), (1.12, 0.045, 0.04, 0.02),
	(1.25, 0.075, 0.06, 0.0), (1.38, 0.09, 0.07, 0.0), (1.47, 0.085, 0.06, 0.01), (1.52, 0.036, 0.034, 0.005),
	(1.58, 0.03, 0.03, -0.005)]
FINGERS = ("f_index", "f_middle", "f_ring", "f_pinky", "thumb")


def edit_rig(rig):
	"""The shipped true form's bone edits: arms stretched (bc.arm_shift), the rest as the survivor."""
	bc.activate(rig)
	bpy.ops.object.mode_set(mode="EDIT")
	for eb in rig.data.edit_bones:
		for attr in ("head", "tail"):
			p = getattr(eb, attr).copy()
			if eb.name.startswith(bc.ARM):
				s = 1 if p.x > 0 else -1
				p.x += s * bc.arm_shift(abs(p.x))
			setattr(eb, attr, p)
	bpy.ops.object.mode_set(mode="OBJECT")


def skin_body(rig):
	"""Skin-modifier tubes: the trunk centreline, then each limb and finger chain from its root on the trunk."""
	bm = bmesh.new()
	radii = []

	def vert(p, rx, ry):
		v = bm.verts.new(Vector(p))
		radii.append((rx, ry))
		return v

	trunk = [vert((0, y, z), rx, ry) for z, rx, ry, y in TRUNK]
	for a, b in zip(trunk, trunk[1:]):
		bm.edges.new((a, b))
	bones = rig.data.bones

	def chain(start, names, profile_of):
		prev = start
		for n in names:
			b = bones[n]
			for t, rx, ry in profile_of(n):
				v = vert(b.head_local.lerp(b.tail_local, t), rx, ry)
				bm.edges.new((prev, v))
				prev = v
		return prev

	def limb_profile(n):
		return LIMB_PROFILE[n.split("-")[1].split(".")[0]]

	for s in ("L", "R"):
		hand = chain(trunk[5], ["DEF-shoulder." + s, "DEF-upper_arm." + s, "DEF-forearm." + s, "DEF-hand." + s], limb_profile)
		for f in FINGERS:
			names = ["DEF-%s.0%d.%s" % (f, k, s) for k in (1, 2, 3)]
			chain(hand, names, lambda n: [(1.0, 0.0075, 0.0075)] if n.endswith("3." + s) else [(1.0, 0.009, 0.009)])
		chain(trunk[0], ["DEF-thigh." + s, "DEF-shin." + s, "DEF-foot." + s, "DEF-toe." + s], limb_profile)
	me = bpy.data.meshes.new("true_skin")
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new("true_skin", me)
	bpy.context.scene.collection.objects.link(o)
	m = o.modifiers.new("Skin", "SKIN")
	m.use_smooth_shade = True
	for i, (rx, ry) in enumerate(radii):
		o.data.skin_vertices[0].data[i].radius = (rx, ry)
	o.data.skin_vertices[0].data[0].use_root = True
	o.modifiers.new("Sub", "SUBSURF").levels = 2
	bc.activate(o)
	for mod in list(o.modifiers):
		bpy.ops.object.modifier_apply(modifier=mod.name)
	return o


def ellipsoid(bm, centre, radii, rot=None, segs=24, rings=14):
	r = bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
	for v in r["verts"]:
		c = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))
		v.co = (rot @ c if rot else c) + Vector(centre)


def rod(bm, a, b, r1, r2, segs=8):
	a, b = Vector(a), Vector(b)
	d = b - a
	r = bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=d.length)
	bmesh.ops.rotate(bm, verts=r["verts"], cent=Vector(), matrix=d.normalized().to_track_quat("Z", "Y").to_matrix())
	bmesh.ops.translate(bm, vec=(a + b) / 2, verts=r["verts"])


def arc(bm, pts, r):
	for a, b in zip(pts, pts[1:]):
		rod(bm, a, b, r, r)


def flesh_shapes(rig):
	"""Shapes fused into the skin by the remesh: skull, jaw, ribs pressing through, shoulder blades, spine."""
	bm = bmesh.new()
	tilt = Matrix.Rotation(0.25, 3, "X")
	hk = HEAD_SCALE
	o = Vector((0, 0, 1.58))

	def hd(p):  # head shapes scaled about the top of the neck
		return o + (Vector(p) - o) * hk
	ellipsoid(bm, hd((0, 0.015, 1.665)), Vector((0.07, 0.085, 0.085)) * hk)  # cranium
	ellipsoid(bm, hd((0, -0.07, 1.635)), Vector((0.055, 0.12, 0.05)) * hk, tilt)  # long muzzle, no eyes
	ellipsoid(bm, hd((0, -0.06, 1.575)), Vector((0.045, 0.1, 0.02)) * hk, Matrix.Rotation(-0.1, 3, "X"))  # jaw, open
	for s in (-1, 1):
		ellipsoid(bm, hd((s * 0.035, -0.06, 1.68)), Vector((0.025, 0.06, 0.014)) * hk)  # brow ridges, no eyes
		ellipsoid(bm, (s * 0.095, 0.065, 1.4), (0.055, 0.02, 0.075), Matrix.Rotation(s * 0.3, 3, "Z"))  # blades
		for k in range(6):  # ribs pressing through the skin, round the side
			z = 1.44 - k * 0.045
			w = 0.085 - k * 0.002
			pts = [Vector((s * w * math.sin(a), -w * 0.75 * math.cos(a) + 0.0, z - 0.02 * math.sin(a)))
				for a in (0.25, 0.8, 1.35, 1.9, 2.4)]
			arc(bm, pts, 0.011)
	for k in range(14):  # vertebrae down the back
		z = 1.56 - k * 0.042
		ellipsoid(bm, (0, 0.05 + (0.012 if 1.2 < z < 1.48 else 0.0), z), (0.016, 0.018, 0.014), segs=10, rings=6)
	return bm


def bone_shapes(rig):
	"""Bone-white parts: teeth, claws, the exposed spine tips. Also used to colour the low mesh."""
	bm = bmesh.new()
	o, hk = Vector((0, 0, 1.58)), HEAD_SCALE
	for k in range(11):  # upper teeth along the muzzle, lower teeth along the jaw
		a = (k - 5) / 5.0
		x, y = a * 0.04, -0.17 + abs(a) ** 1.6 * 0.09
		for p0, p1, r in (((x, y, 1.6), (x * 1.05, y - 0.006, 1.562), 0.0065),
				((x * 0.9, y + 0.012, 1.562), (x * 0.95, y + 0.006, 1.597), 0.006)):
			rod(bm, o + (Vector(p0) - o) * hk, o + (Vector(p1) - o) * hk, r * hk, 0.0, segs=6)
	for s in ("L", "R"):
		for f in FINGERS:
			b = rig.data.bones["DEF-%s.03.%s" % (f, s)]
			d = (b.tail_local - b.head_local).normalized()
			rod(bm, b.tail_local - d * 0.012, b.tail_local + d * (0.06 if f == "thumb" else 0.09), 0.0085, 0.0, segs=8)
	for s in ("L", "R"):  # toe claws
		b = rig.data.bones["DEF-toe." + s]
		for dx in (-0.018, 0.0, 0.018):
			p = b.tail_local + Vector((dx, 0.004, 0.0))
			rod(bm, p + Vector((0, 0.01, 0.004)), p + Vector((dx * 0.6, -0.05, -0.008)), 0.008, 0.0, segs=6)
	for k in range(6):  # spine tips breaking the skin between the shoulder blades
		z = 1.46 - k * 0.045
		rod(bm, (0, 0.05, z), (0, 0.105 - k * 0.004, z + 0.02), 0.012, 0.0, segs=8)
	return bm


def obj_from(bm, name):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(o)
	return o


def high_mesh(skin, flesh, bone):
	"""One surface: skin + flesh + bone shapes voxel-remeshed, smoothed, then flesh noise along the normals."""
	bpy.ops.object.select_all(action="DESELECT")
	for o in (skin, flesh, bone):
		o.select_set(True)
	bpy.context.view_layer.objects.active = skin
	bpy.ops.object.join()
	r = skin.modifiers.new("Remesh", "REMESH")
	r.mode = "VOXEL"
	r.voxel_size = VOXEL_M
	sm = skin.modifiers.new("Smooth", "CORRECTIVE_SMOOTH")
	sm.iterations = 4
	tex = bpy.data.textures.new("flesh", "CLOUDS")
	tex.noise_scale = 0.035
	tex.noise_depth = 3
	d = skin.modifiers.new("Flesh", "DISPLACE")
	d.texture = tex
	d.texture_coords = "GLOBAL"
	d.strength = NOISE_M
	d.mid_level = 0.5
	bc.activate(skin)
	for m in list(skin.modifiers):
		bpy.ops.object.modifier_apply(modifier=m.name)
	skin.name = skin.data.name = "true_high"
	return skin


def low_mesh(high, target):
	low = high.copy()
	low.data = high.data.copy()
	low.name = low.data.name = "char_shapeshifter_true_lod0"
	bpy.context.scene.collection.objects.link(low)
	bc.triangulate(low)  # the ratio counts faces: triangles, so the budget holds
	m = low.modifiers.new("Dec", "DECIMATE")
	m.ratio = target / max(1, len(low.data.polygons)) * 0.98
	bc.activate(low)
	bpy.ops.object.modifier_apply(modifier="Dec")
	bc.triangulate(low)
	return low


def bake_normal(high, low, path):
	"""Tangent-space normal map of the high mesh onto the low one's smart-projected UVs (Cycles, CPU)."""
	bc.activate(low)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
	bpy.ops.object.mode_set(mode="OBJECT")
	img = bpy.data.images.new("true_normal", BAKE_PX, BAKE_PX, float_buffer=False)
	img.colorspace_settings.name = "Non-Color"
	for mat in low.data.materials:
		n = mat.node_tree.nodes.new("ShaderNodeTexImage")
		n.image = img
		mat.node_tree.nodes.active = n
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = 1
	bpy.ops.object.select_all(action="DESELECT")
	high.select_set(True)
	low.select_set(True)
	bpy.context.view_layer.objects.active = low
	bpy.ops.object.bake(type="NORMAL", use_selected_to_active=True, cage_extrusion=0.012, max_ray_distance=0.03,
		margin=4)
	img.filepath_raw = path
	img.file_format = "PNG"
	img.save()
	for mat in low.data.materials:  # the bake target node becomes the normal map input
		nodes, links = mat.node_tree.nodes, mat.node_tree.links
		tex = nodes.active
		nm = nodes.new("ShaderNodeNormalMap")
		links.new(tex.outputs["Color"], nm.inputs["Color"])
		links.new(nm.outputs["Normal"], nodes["Principled BSDF"].inputs["Normal"])
	return img


def materials(low, bone_obj):
	skin = bpy.data.materials.new("mat_shapeshifter_skin")
	skin.use_nodes = True
	p = skin.node_tree.nodes["Principled BSDF"]
	p.inputs["Base Color"].default_value = (bc.lin(46), bc.lin(44), bc.lin(48), 1)  # sRGB 40-55 (art bible §5)
	p.inputs["Roughness"].default_value = 0.4
	p.inputs["Coat Weight"].default_value = 1.0
	p.inputs["Coat Roughness"].default_value = 0.08
	bone = bpy.data.materials.new("mat_shapeshifter_bone")
	bone.use_nodes = True
	p = bone.node_tree.nodes["Principled BSDF"]
	p.inputs["Base Color"].default_value = (bc.lin(206), bc.lin(198), bc.lin(178), 1)  # 190-220 (art bible §5)
	p.inputs["Roughness"].default_value = 0.55
	low.data.materials.clear()
	low.data.materials.append(skin)
	low.data.materials.append(bone)
	tree = BVHTree.FromObject(bone_obj, bpy.context.evaluated_depsgraph_get())
	for poly in low.data.polygons:
		hit = tree.find_nearest(poly.center, 0.0022)
		poly.material_index = 1 if hit[0] is not None else 0


def bone_weights(o, rig):
	"""Each vertex to its nearest deform bones by distance to the bone segment (two nearest, 1/d^4 blend).
	Blender's bone-heat weighting fails silently on this mesh (the arms stayed in the T-pose)."""
	segs = [(b.name, b.head_local.copy(), b.tail_local.copy()) for b in rig.data.bones
		if b.use_deform and b.name.startswith("DEF-")]
	groups = {n: o.vertex_groups.new(name=n) for n, _, _ in segs}
	for v in o.data.vertices:
		ds = []
		for n, a, b in segs:
			d = b - a
			t = max(0.0, min(1.0, (v.co - a).dot(d) / max(d.length_squared, 1e-9)))
			ds.append(((v.co - (a + d * t)).length, n))
		ds.sort()
		near = [(d, n) for d, n in ds[:2] if d <= ds[0][0] * 1.5 + 0.004]
		ws = [1.0 / max(d, 1e-4) ** 4 for d, _ in near]
		for (d, n), w in zip(near, ws):
			groups[n].add([v.index], w / sum(ws), "REPLACE")
	m = o.modifiers.get("Armature") or o.modifiers.new("Armature", "ARMATURE")
	m.object = rig


def build(out):
	rig, body = bc.load_source()
	for a in bpy.data.actions:  # as build_characters.build_true_form: rotations below the hips only
		for cb, fcs in bc.channelbag_fcurves(a):
			for fc in fcs:
				if fc.data_path.endswith("location") and "DEF-hips" not in fc.data_path and '"root"' not in fc.data_path:
					cb.fcurves.remove(fc)
	build_anims.add_true_clips(rig)
	bpy.data.objects.remove(body)
	edit_rig(rig)
	skin = skin_body(rig)
	flesh = obj_from(flesh_shapes(rig), "true_flesh")
	bone = obj_from(bone_shapes(rig), "true_bone")
	bone_ref = bone.copy()
	bone_ref.data = bone.data.copy()
	bpy.context.scene.collection.objects.link(bone_ref)
	high = high_mesh(skin, flesh, bone)
	print("HIGH_TRIS", len(high.data.polygons))
	low = low_mesh(high, bc.LOD_TRIS[0])
	materials(low, bone_ref)
	tex_dir = os.path.dirname(out)
	bake_normal(high, low, os.path.join(tex_dir, "char_shapeshifter_true_normal_1024.png"))
	for o in (high, bone_ref):
		bpy.data.objects.remove(o)
	bpy.ops.object.select_all(action="DESELECT")
	low.select_set(True)
	rig.select_set(True)
	bpy.context.view_layer.objects.active = rig
	bpy.ops.object.parent_set(type="ARMATURE")
	bone_weights(low, rig)
	assert bc.tris(low) <= bc.LOD_TRIS[0], bc.tris(low)
	lods = [low] + [bc.decimate_copy(low, "char_shapeshifter_true_lod%d" % i, bc.LOD_TRIS[i]) for i in (1, 2)]
	h = max((rig.matrix_world @ v.co).z for v in low.data.vertices)
	rig.scale = (bc.TRUE_HEIGHT_M / h,) * 3
	bpy.ops.object.select_all(action="DESELECT")
	for o in [rig] + lods:
		o.select_set(True)
	os.makedirs(tex_dir, exist_ok=True)
	bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True,
		export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
		export_apply=False, export_skins=True, export_morph=False, export_yup=True,
		export_image_format="AUTO", export_materials="EXPORT")
	report = {o.name: bc.tris(o) for o in lods}
	print("TRUE_TRIS", report)
	return report


def main():
	bc.fetch()
	ship = "--ship" in sys.argv
	out = os.path.join(bc.OUT_TRUE if ship else os.path.join(bc.ROOT, "tools", "art", "review"),
		"char_shapeshifter_true.glb" if ship else "true_d.glb")
	print("DONE", build(out))


if __name__ == "__main__":
	main()
