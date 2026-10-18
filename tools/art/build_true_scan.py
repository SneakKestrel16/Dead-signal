"""Builds the shapeshifter true form from the TRELLIS image-to-3D mesh of the concept (design/art/true-form-review.md,
round 9) instead of growing it from primitives.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
      --python tools/art/build_true_scan.py [-- --ship]

Source: assets/art/characters/shapeshifter/source/true_scan.glb, TRELLIS image-large (MIT) run locally on
true-form-concept-01, seed 1, thin sheets stripped (tools/art/trellis/). It stands arms down, 1.8 m, facing -Y.

Steps: the survivor rig without the arm stretch (its joints already sit where the scan's do) -> each limb bone
aimed at the scan's joint (SCAN_JOINTS, read off front and side ortho renders on a 0.1 m grid) -> weights by
distance to the posed bones -> the scan unposed into the rig's rest pose (inverse of the blended bone matrices) ->
decimated to the 15k/7k/3k budget, normal and albedo (the scan's vertex colour) baked from the full scan -> same clips and
export as build_true_form.py. Height 2.4 m (art bible §5).

Writes tools/art/review/true_scan.glb (review, gitignored), or with --ship
assets/art/characters/shapeshifter/char_shapeshifter_true.glb.
"""
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_anims  # noqa: E402
import build_characters as bc  # noqa: E402
import build_true_form as tf  # noqa: E402

SCAN = os.path.join(bc.OUT_TRUE, "source", "true_scan.glb")
## Where each bone's tail sits in the scan (m, Z-up, the creature's left is +X, it faces -Y). Read off ortho renders
## of the scan on a 0.1 m grid by eye; the right side mirrors the left except the legs, which stand apart unevenly.
SCAN_JOINTS = {
	"DEF-upper_arm.L": (0.27, 0.02, 1.17), "DEF-forearm.L": (0.29, 0.0, 0.95), "DEF-hand.L": (0.27, -0.02, 0.78),
	"DEF-upper_arm.R": (-0.27, 0.02, 1.17), "DEF-forearm.R": (-0.29, 0.0, 0.95), "DEF-hand.R": (-0.27, -0.02, 0.78),
	"DEF-thigh.L": (0.12, -0.08, 0.57), "DEF-shin.L": (0.17, 0.0, 0.12),
	"DEF-thigh.R": (-0.14, -0.08, 0.57), "DEF-shin.R": (-0.2, 0.0, 0.12),
}
STRETCH = 2.5
## The strip hanging between the scan's thighs (a concept wisp): torn between the legs in any stride, so cut.
SCAN_CUT = ((-0.065, -0.2, 0.42), (0.03, 0.2, 0.85))
## Foot slab left between the scan's ankles: in the rest pose the legs stand at x +-0.09, so anything this close
## to the centre line below the knee is that slab (|x|, z).
REST_GAP = (0.025, 0.5)
NO_WEIGHT = ("DEF-f_", "DEF-thumb")  # the scan's claws are solid: they ride the hand
SKIN = ((40, 46, 46), 0.5, 0.25, 0.2)  # base colour replaced by the baked scan colour


def clear_pose(rig):
	for pb in rig.pose.bones:
		pb.matrix_basis = Matrix.Identity(4)
	bpy.context.view_layer.update()


def pose_to_scan(rig):
	"""Aim each listed bone's tail at its scan joint (damped track, applied, constraints removed)."""
	bc.activate(rig)
	bpy.ops.object.mode_set(mode="POSE")
	order = ["DEF-upper_arm", "DEF-forearm", "DEF-hand", "DEF-thigh", "DEF-shin"]
	for base in order:  # parents first, so a child aims from where its parent left it
		for s in ("L", "R"):
			n = "%s.%s" % (base, s)
			e = bpy.data.objects.new("aim_" + n, None)
			bpy.context.scene.collection.objects.link(e)
			e.location = rig.matrix_world @ Vector(SCAN_JOINTS[n])
			pb = rig.pose.bones[n]
			c = pb.constraints.new("DAMPED_TRACK")
			c.target = e
			bpy.context.view_layer.update()
			m = pb.matrix.copy()
			pb.constraints.remove(c)
			pb.matrix = m
			bpy.context.view_layer.update()
			bpy.data.objects.remove(e)
	bpy.ops.object.mode_set(mode="OBJECT")


def load_scan():
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=SCAN)
	o = [o for o in bpy.data.objects if o not in before and o.type == "MESH"][0]
	bc.activate(o)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	bpy.ops.object.mode_set(mode="EDIT")  # the glb arrives as a triangle soup (three vertices per face)
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.mesh.remove_doubles(threshold=1e-5)
	bpy.ops.mesh.select_all(action="DESELECT")
	bpy.ops.object.mode_set(mode="OBJECT")
	lo, hi = SCAN_CUT
	for v in o.data.vertices:
		v.select = all(lo[i] <= v.co[i] <= hi[i] for i in range(3))
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.delete(type="VERT")
	bpy.ops.object.mode_set(mode="OBJECT")
	o.name = o.data.name = "true_high"
	return o


def weight_and_unpose(o, rig):
	"""Weights by distance to the posed DEF bones (tf.bone_weights' rule, in numpy for the full scan), then each
	vertex taken back to rest through the inverse of its blended skinning matrix."""
	names = [b.name for b in rig.data.bones
		if b.use_deform and b.name.startswith("DEF-") and not b.name.startswith(NO_WEIGHT)]
	a = np.array([rig.pose.bones[n].head for n in names])
	d = np.array([rig.pose.bones[n].tail for n in names]) - a
	skin = np.array([rig.pose.bones[n].matrix @ rig.data.bones[n].matrix_local.inverted() for n in names])
	co = np.empty(len(o.data.vertices) * 3)
	o.data.vertices.foreach_get("co", co)
	co = co.reshape(-1, 3)
	rel = co[:, None, :] - a[None]
	t = np.clip((rel * d[None]).sum(2) / np.maximum((d * d).sum(1), 1e-9)[None], 0.0, 1.0)
	dist = np.linalg.norm(rel - t[..., None] * d[None], axis=2)
	near = np.argsort(dist, axis=1)[:, :2]
	nd = np.take_along_axis(dist, near, 1)
	w = 1.0 / np.maximum(nd, 1e-4) ** 4
	w[:, 1] *= nd[:, 1] <= nd[:, 0] * 1.5 + 0.004
	w /= w.sum(1, keepdims=True)
	blend = (skin[near] * w[..., None, None]).sum(1)
	h = np.concatenate([co, np.ones((len(co), 1))], 1)
	rest = np.linalg.solve(blend, h[..., None])[:, :3, 0]
	o.data.vertices.foreach_set("co", rest.ravel())
	o.data.update()
	side = np.array([{"L": 1, "R": -1}.get(n.rsplit(".", 1)[-1], 0) for n in names])[near[:, 0]]
	cut_stretched(o, co, rest, side)


def cut_stretched(o, posed, rest, side):
	"""Where the scan's hand touched the thigh the remesh welded them; unposed, the faces joining them stretch into
	curtains. Faces whose longest edge grew more than STRETCH times are cut, and faces joining a left limb to a right
	one (they tear in any stride), and the slab between the feet; the holes are capped, loose crumbs dropped."""
	bm = bmesh.new()
	bm.from_mesh(o.data)
	bm.verts.ensure_lookup_table()
	bad = []
	for f in bm.faces:
		vs = [v.index for v in f.verts]
		grow = max(np.linalg.norm(rest[a] - rest[b]) / max(np.linalg.norm(posed[a] - posed[b]), 1e-6)
			for a, b in zip(vs, vs[1:] + vs[:1]))
		gap = all(abs(rest[i][0]) < REST_GAP[0] and rest[i][2] < REST_GAP[1] for i in vs)
		if grow > STRETCH or {side[i] for i in vs} >= {1, -1} or gap:
			bad.append(f)
	bmesh.ops.delete(bm, geom=bad, context="FACES")
	bmesh.ops.holes_fill(bm, edges=bm.edges, sides=0)
	bmesh.ops.triangulate(bm, faces=bm.faces)
	big = max(len(c) for c in islands(bm))
	for c in islands(bm):
		if len(c) < big * 0.02:
			bmesh.ops.delete(bm, geom=c, context="VERTS")
	bm.to_mesh(o.data)
	bm.free()
	print("CUT", len(bad), "stretched faces")


def islands(bm):
	seen, out = set(), []
	for v in bm.verts:
		if v in seen:
			continue
		stack, part = [v], []
		seen.add(v)
		while stack:
			u = stack.pop()
			part.append(u)
			for e in u.link_edges:
				w = e.other_vert(u)
				if w not in seen:
					seen.add(w)
					stack.append(w)
		out.append(part)
	return out


def scan_material(o):
	"""The scan's vertex colour (TRELLIS decodes one per vertex from the concept) as base colour, for the bake."""
	m = bpy.data.materials.new("scan_colour")
	m.use_nodes = True
	nodes = m.node_tree.nodes
	attr = nodes.new("ShaderNodeVertexColor")
	attr.layer_name = o.data.color_attributes[0].name
	gamma = nodes.new("ShaderNodeGamma")  # TRELLIS colours are sRGB; glTF vertex colour is read as linear
	gamma.inputs["Gamma"].default_value = 2.2
	m.node_tree.links.new(attr.outputs["Color"], gamma.inputs["Color"])
	m.node_tree.links.new(gamma.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
	o.data.materials.clear()
	o.data.materials.append(m)


def bake_albedo(high, low, path):
	"""The scan colour onto the low mesh's UVs (laid out by tf.bake_normal, which must run first)."""
	img = bpy.data.images.new(os.path.splitext(os.path.basename(path))[0], tf.BAKE_PX, tf.BAKE_PX)
	mat = low.data.materials[0]
	nodes, links = mat.node_tree.nodes, mat.node_tree.links
	tex = nodes.new("ShaderNodeTexImage")
	tex.image = img
	nodes.active = tex
	bpy.ops.object.select_all(action="DESELECT")
	high.select_set(True)
	low.select_set(True)
	bpy.context.view_layer.objects.active = low
	bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_selected_to_active=True, cage_extrusion=0.012,
		max_ray_distance=0.03, margin=4)
	img.filepath_raw = path
	img.file_format = "PNG"
	img.save()
	links.new(tex.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])


def one_side(o):
	"""A vertex between the scan's feet splits evenly between both legs and strings out in any stride: it keeps
	only its heavier side."""
	names = [g.name for g in o.vertex_groups]
	for v in o.data.vertices:
		gs = sorted(v.groups, key=lambda g: -g.weight)
		keep = names[gs[0].group].rsplit(".", 1)[-1]
		for g in gs[1:]:
			if {keep, names[g.group].rsplit(".", 1)[-1]} == {"L", "R"}:
				o.vertex_groups[g.group].remove([v.index])
				gs[0].weight = 1.0


def build(out):
	rig, body = bc.load_source()
	for a in bpy.data.actions:  # as build_true_form.build: rotations below the hips only
		for cb, fcs in bc.channelbag_fcurves(a):
			for fc in fcs:
				if fc.data_path.endswith("location") and "DEF-hips" not in fc.data_path and '"root"' not in fc.data_path:
					cb.fcurves.remove(fc)
	build_anims.add_true_clips(rig)
	bpy.data.objects.remove(body)
	rig.animation_data.action = None
	assert rig.matrix_world == Matrix.Identity(4), rig.matrix_world  # bone space is world space below
	high = load_scan()
	clear_pose(rig)  # add_true_clips leaves its last clip's pose on the bones
	pose_to_scan(rig)
	weight_and_unpose(high, rig)
	clear_pose(rig)
	high.vertex_groups.clear()  # the low mesh is weighted afresh after decimation
	print("HIGH_FACES", len(high.data.polygons))
	scan_material(high)
	low = tf.low_mesh(high, bc.LOD_TRIS[0])
	low.data.materials.clear()
	low.data.materials.append(tf.material("mat_shapeshifter_skin", *SKIN))
	tf.bake_normal(high, low, os.path.splitext(out)[0] + "_normal_1024.png")
	bake_albedo(high, low, os.path.splitext(out)[0] + "_albedo_1024.png")
	bpy.data.objects.remove(high)
	bpy.ops.object.select_all(action="DESELECT")
	low.select_set(True)
	rig.select_set(True)
	bpy.context.view_layer.objects.active = rig
	bpy.ops.object.parent_set(type="ARMATURE")
	tf.bone_weights(low, rig)
	one_side(low)
	assert bc.tris(low) <= bc.LOD_TRIS[0], bc.tris(low)
	lods = [low] + [bc.decimate_copy(low, "char_shapeshifter_true_lod%d" % i, bc.LOD_TRIS[i]) for i in (1, 2)]
	h = max((rig.matrix_world @ v.co).z for v in low.data.vertices)
	rig.scale = (bc.TRUE_HEIGHT_M / h,) * 3
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


def main():
	bc.fetch()
	ship = "--ship" in sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else False
	out = os.path.join(bc.OUT_TRUE, "char_shapeshifter_true.glb") if ship \
		else os.path.join(bc.ROOT, "tools", "art", "review", "true_scan.glb")
	print("DONE", build(out))


if __name__ == "__main__":
	main()
