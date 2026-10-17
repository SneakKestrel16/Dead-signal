"""Builds the shapeshifter true form after the designer's concept (design/art/reference/true-form-concept-01.webp):
a near-black, stringy, long-limbed body with a pale domed head that is nothing but a mouth of needle teeth, small
red eyes, tendrils off the skull and back, shredded strips trailing off the limbs, long claws.

  BLENDER_USER_RESOURCES=tools/art/.cache/blender_user \
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
      --python tools/art/build_creature.py [-- --ship]

Body: build_experiment's MakeHuman pipeline (same MPFB setup, see its docstring) with a lean, sinewy macro and the
human head cut away. Head: ellipsoids voxel-remeshed into one surface (dome, snout, hanging lower jaw, neck sleeve
over the cut). Both bake a normal map and a painted base colour from subdivided, sculpted copies.

Writes tools/art/review/true_creature.glb (review, gitignored), or with --ship
assets/art/characters/shapeshifter/char_shapeshifter_true.glb.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_anims  # noqa: E402
import build_characters as bc  # noqa: E402
import build_experiment as ex  # noqa: E402
import build_true_form as tf  # noqa: E402

## MakeHuman body: lean and sinewy rather than starved (the concept's limbs are stringy muscle, not bone).
MACROS = dict(gender=1.0, age=0.5, muscle=0.8, weight=0.0, height=1.0, proportions=0.7)
MAKEHUMAN_TARGETS = [
	("torso", "measure-waist-circ-decr", 0.6), ("stomach", "stomach-pregnant-decr", 1.0),
	("arms", "measure-upperarm-circ-decr", 0.6), ("arms", "lowerarm-fat-decr", 1.0), ("arms", "upperarm-fat-decr", 1.0),
	("hands", "hand-fingers-length-incr", 1.0), ("hands", "hand-fingers-diameter-decr", 1.0),
	("legs", "measure-thigh-circ-decr", 0.6), ("legs", "measure-calf-circ-decr", 0.6), ("legs", "upperleg-fat-decr", 1.0),
]
## (name, sRGB, roughness, clearcoat): wet near-black skin (art bible §5 sRGB 40-55), the pale head, dark claws.
MATS = [("mat_shapeshifter_skin", (46, 50, 56), 0.55, 0.15), ("mat_shapeshifter_head", (170, 182, 174), 0.45, 0.5),
	("mat_shapeshifter_claw", (52, 48, 46), 0.4, 0.3), ("mat_shapeshifter_tooth", (214, 202, 172), 0.5, 0.2),
	("mat_shapeshifter_gum", (118, 22, 26), 0.35, 0.6), ("mat_shapeshifter_eye", (176, 18, 16), 0.15, 1.0)]
## Painted colours (sRGB): body dark with grey-green on the upper body; head pale, greyer in the creases; red raw.
PAINT = dict(dark=(26, 29, 34), sheen=(54, 62, 66), pale=(184, 196, 186), grey=(124, 136, 132), raw=(112, 18, 24))
JAW_DEG = 40  # the lower jaw hangs open this far about its hinge
NECK_CUT_M = 0.06
HEAD_TRIS = 2600
FIBRE = (0.0024, 90.0, 10.0)  # sinew displacement depth (m), across-fibre and along-fibre noise frequency (1/m)


def smooth(t):
	return ex.smooth(t)


def part(name, bm, mat, groups):
	"""A bmesh as an object with one material and fixed weights {bone: weight}."""
	o = tf.obj_from(bm, "part_" + name)
	o.data.materials.append(mat)
	ids = list(range(len(o.data.vertices)))
	for g, w in groups.items():
		o.vertex_groups.new(name=g).add(ids, w, "REPLACE")
	return o


def tendril(bm, p0, d0, length, r0, r1=0.0012, sag=0.6, wiggle=0.15, segs=5, seed=0.0):
	"""A tapered curling tube: starts along d0, sags under its own weight, wavers sideways."""
	d0 = Vector(d0).normalized()
	side = d0.cross(Vector((0, 0, 1)))
	side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
	pts = []
	for i in range(segs + 1):
		t = i / segs
		s = length * t
		pts.append(Vector(p0) + d0 * s + Vector((0, 0, -sag * s * s)) + side * math.sin(t * 5 + seed) * wiggle * s)
	for i in range(segs):
		t0, t1 = i / segs, (i + 1) / segs
		tf.rod(bm, pts[i], pts[i + 1], r0 + (r1 - r0) * t0, r0 + (r1 - r0) * t1, segs=5)


def cut_head(h, rig):
	"""Cuts MakeHuman's head off: flat NECK_CUT_M under the head joint, and the old chin's underside (head-weighted,
	hanging lower) with it; only within 20 cm of the middle, or it clips the T-posed fingertips. Returns the cut's bounds: centre, half-widths across and front to back,
	lowest and highest z."""
	top = rig.data.bones["DEF-head"].head_local
	gi = h.vertex_groups["DEF-head"].index
	bm = bmesh.new()
	bm.from_mesh(h.data)
	dl = bm.verts.layers.deform.active
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if abs(v.co.x) < 0.2 and
		(v.co.z > top.z - NECK_CUT_M or v[dl].get(gi, 0.0) >= 0.5)], context="VERTS")
	ring = [v.co.copy() for v in bm.verts if v.is_boundary]
	bm.to_mesh(h.data)
	bm.free()
	c = sum(ring, Vector()) / len(ring)
	return c, max(abs(v.x - c.x) for v in ring), max(abs(v.y - c.y) for v in ring), min(v.z for v in ring), 		max(v.z for v in ring)


def head_frame(rig):
	hb = rig.data.bones["DEF-head"]
	up = (hb.tail_local - hb.head_local).normalized()
	fwd = Vector((0, -1, 0))
	fwd = (fwd - up * fwd.dot(up)).normalized()
	right = fwd.cross(up)

	def P(a, b, c):
		return hb.head_local + right * a + fwd * b + up * c
	return P, up, fwd, right


## The head as metaball ellipsoids, (a, b, c) centre in the head frame (right, forward, up from the top of the neck)
## and semi-axes (m); "jaw" ones turn down with the lower jaw. Metaballs blend into one smooth skull.
HEAD_BLOBS = [
	("dome", (0, -0.03, 0.15), (0.088, 0.15, 0.1)),
	("crest", (0, -0.14, 0.18), (0.06, 0.09, 0.065)),
	("brow", (0, 0.08, 0.11), (0.078, 0.11, 0.07)),
	("snout", (0, 0.15, 0.05), (0.06, 0.1, 0.052)),
	("cheek", (0.045, 0.07, 0.035), (0.032, 0.06, 0.035)),
	("cheek", (-0.045, 0.07, 0.035), (0.032, 0.06, 0.035)),
	("neck", (0, -0.005, -0.03), None),
	("jaw", (0, 0.13, -0.03), (0.052, 0.11, 0.03)),
	("jaw", (0, 0.04, -0.025), (0.05, 0.06, 0.04)),
]
META_K = 0.574  # a metaball ellipsoid's surface sits at this fraction of its size (measured, stiffness 2)


def build_head(rig, cut, mats):
	"""The pale head (high, low with UVs) and its parts: teeth, mouth strands, tongue, eyes, skull tendrils."""
	P, up, fwd, right = head_frame(rig)
	frame = Matrix((right, fwd, up)).transposed()  # local (a, b, c) -> world direction
	hinge = P(0, 0.02, 0.0)
	jaw = Matrix.Rotation(math.radians(JAW_DEG), 3, -right)  # front of the jaw swings down

	def turn(p):
		return hinge + jaw @ (Vector(p) - hinge)
	c, hx, hy, z0, z1 = cut
	bm = bmesh.new()
	for jaw_part in (False, True):  # two metaballs, or the open mouth fills in
		mb = bpy.data.metaballs.new("head")
		mb.resolution = 0.004
		for name, ctr, axes in HEAD_BLOBS:
			if (name == "jaw") != jaw_part:
				continue
			if axes is None:  # the sleeve over the neck's cut, down past its lowest point
				axes, centre = (hx + 0.008, hy + 0.01, 0.085), Vector((c.x, c.y, z1 - 0.005))
			else:
				centre = P(*ctr)
			el = mb.elements.new(type="ELLIPSOID")
			rot = frame
			if name == "jaw":
				centre, rot = turn(centre), jaw @ frame
			el.co, el.radius = centre, 0.1
			el.rotation = rot.to_quaternion()
			el.size_x, el.size_y, el.size_z = (x / (0.1 * META_K) for x in axes)
		mo = bpy.data.objects.new("head_meta", mb)
		bpy.context.scene.collection.objects.link(mo)
		me = bpy.data.meshes.new_from_object(mo.evaluated_get(bpy.context.evaluated_depsgraph_get()))
		bm.from_mesh(me)
		bpy.data.objects.remove(mo)
		bpy.data.meshes.remove(me)
	high = tf.obj_from(bm, "head_high")
	high.modifiers.new("Smooth", "CORRECTIVE_SMOOTH").iterations = 4
	bc.activate(high)
	bpy.ops.object.modifier_apply(modifier="Smooth")
	for v in high.data.vertices:  # skin folds and pits on the skull
		v.co += v.normal * (noise.noise(v.co * 40) * 0.0015 + noise.noise(v.co * 160) * 0.0004)
	bvh = BVHTree.FromObject(high, bpy.context.evaluated_depsgraph_get())
	low = tf.low_mesh(high, HEAD_TRIS)
	low.name = low.data.name = "head_low"
	low.data.materials.clear()
	low.data.materials.append(mats["mat_shapeshifter_head"])
	bc.activate(low)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
	bpy.ops.object.mode_set(mode="OBJECT")

	def hit(origin, d):
		return ex.surface(bvh, origin, d)
	# teeth: needles on both jaws, found by rays from inside the open mouth; longest at the front
	teeth, strands, roots = bmesh.new(), bmesh.new(), []
	for k in range(22):
		a = (k - 10.5) / 10.5
		th = a * 1.5
		x, b = 0.04 * math.sin(th), 0.08 + 0.12 * math.cos(th)
		inside = P(x, b, -0.01).lerp(turn(P(x, b, -0.01)), 0.5)
		ln = 0.03 + 0.03 * (1 - abs(a)) + (0.015 if k % 3 == 0 else 0.0)
		for d in (up, jaw @ -up):
			root = hit(inside, d)
			if root is None:
				continue
			root = root - d * 0.003
			tip = root - d * ln + fwd * 0.005
			tf.rod(teeth, root, tip, 0.0045, 0.0, segs=5)
			roots.append(root)
	for s in (-1, 1):  # strands of skin stretched across the corners of the mouth
		for b in (0.04, 0.06, 0.08):
			tf.rod(strands, P(s * 0.044, b, 0.008), turn(P(s * 0.04, b, -0.018)), 0.0028, 0.0018, segs=5)
	tongue = bmesh.new()
	tendril(tongue, P(0, 0.06, -0.012), fwd * 0.7 - up * 0.3, 0.32, 0.012, 0.003, sag=2.2, wiggle=0.3, segs=7, seed=1.0)
	eyes = bmesh.new()
	for s in (-1, 1):
		e = hit(P(s * 0.3, 0.115, 0.085), right * -s)
		if e is not None:
			tf.ellipsoid(eyes, e + right * s * 0.003, (0.01, 0.01, 0.008), segs=8, rings=5)
	spikes, red = bmesh.new(), bmesh.new()
	skull = P(0, -0.04, 0.14)
	for k in range(24):  # spread over the back half of the skull, sweeping back like a mane
		row, col = divmod(k, 6)
		phi = (col - 2.5) / 2.5 * 1.25 + 0.15 * (row % 2)
		el = 0.15 + 0.3 * row
		out = right * math.sin(phi) * math.cos(el) - fwd * math.cos(phi) * math.cos(el) + up * math.sin(el)
		root = hit(skull + out * 0.5, -out) or skull + out * 0.1
		d = out * 0.6 - fwd * 0.7 + up * 0.25
		tendril(red if k % 7 == 3 else spikes, root - out * 0.004, d, 0.26 + 0.06 * ((k * 7) % 5), 0.011, sag=1.2,
			wiggle=0.18, segs=6, seed=k)
	head_w = {"DEF-head": 1.0}
	parts = [part("teeth", teeth, mats["mat_shapeshifter_tooth"], head_w),
		part("strands", strands, mats["mat_shapeshifter_gum"], head_w),
		part("tongue", tongue, mats["mat_shapeshifter_gum"], head_w),
		part("eyes", eyes, mats["mat_shapeshifter_eye"], head_w),
		part("head_spikes", spikes, mats["mat_shapeshifter_claw"], head_w),
		part("head_red", red, mats["mat_shapeshifter_gum"], head_w)]
	# the head blends into the neck over the sleeve
	hz = rig.data.bones["DEF-head"].head_local.z
	gh, gn = low.vertex_groups.new(name="DEF-head"), low.vertex_groups.new(name="DEF-neck")
	for v in low.data.vertices:
		w = smooth((v.co.z - (hz - 0.07)) / 0.06)
		gh.add([v.index], w, "REPLACE")
		gn.add([v.index], 1 - w, "REPLACE")
	return high, low, parts, roots


def body_parts(h, rig, mats):
	"""Claws, back tendrils and shredded strips trailing down the forearms and shins."""
	dg = bpy.context.evaluated_depsgraph_get()
	bvh = BVHTree.FromObject(h, dg)
	out = []
	cl = bmesh.new()
	tf.claws(cl, rig, 0.11, 0.08, r=0.0065)
	out.append(part("claws", cl, mats["mat_shapeshifter_claw"], {"DEF-hips": 0.0}))
	weight_claws(out[-1], rig)
	back = bmesh.new()
	sp = rig.data.bones["DEF-spine.003"]
	sp2 = rig.data.bones["DEF-spine.002"]
	for k in range(16):  # a mass of tendrils off the shoulders and upper back, longest high up
		s = 1 if k % 2 else -1
		row, col = divmod(k // 2, 2)
		o = sp2.head_local.lerp(sp.tail_local, 0.95 - 0.22 * row) + Vector((s * (0.04 + 0.06 * col), 0, 0))
		p = ex.surface(bvh, o + Vector((0, 0.4, 0)), (0, -1, 0)) or o
		tendril(back, p, (s * (0.3 + 0.3 * col), 1.0, 0.7 - 0.25 * row), 0.42 - 0.06 * row + 0.05 * (k % 3), 0.013,
			sag=1.3, wiggle=0.2, segs=6, seed=k)
	out.append(part("back_tendrils", back, mats["mat_shapeshifter_claw"], {"DEF-spine.003": 1.0}))
	for bone in ("upper_arm", "forearm", "thigh", "shin"):
		for S in ("L", "R"):
			b = rig.data.bones["DEF-%s.%s" % (bone, S)]
			d = (b.tail_local - b.head_local).normalized()
			strips = bmesh.new()
			for k, (t, ang) in enumerate(((0.25, 0.5), (0.45, 2.1), (0.6, 3.6), (0.75, 5.2), (0.9, 1.3))):
				c = b.head_local.lerp(b.tail_local, t)
				side = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).normalized()
				out_d = (Matrix.Rotation(ang, 3, d) @ side).normalized()
				p = ex.surface(bvh, c + out_d * 0.3, -out_d) or c
				tendril(strips, p, d * 0.9 + out_d * 0.45, 0.14 + 0.06 * (k % 3), 0.014, sag=0.0, wiggle=0.25, segs=4,
					seed=k)
			out.append(part("strips_%s_%s" % (bone, S), strips, mats["mat_shapeshifter_claw"], {b.name: 1.0}))
	return out


def weight_claws(o, rig):
	"""Each claw vertex to its nearest finger or toe tip bone."""
	tips = [b for b in rig.data.bones if b.name.startswith("DEF-") and (".03." in b.name or b.name.startswith("DEF-toe"))]
	for g in list(o.vertex_groups):
		o.vertex_groups.remove(g)
	groups = {b.name: o.vertex_groups.new(name=b.name) for b in tips}
	for v in o.data.vertices:
		b = min(tips, key=lambda b: (b.tail_local - v.co).length)
		groups[b.name].add([v.index], 1.0, "REPLACE")


def sculpt_body(high, rig):
	"""Sinew: noise stretched along the limbs (arms run along x in the T-pose, legs and trunk along z)."""
	x0 = rig.data.bones["DEF-upper_arm.L"].head_local.x
	depth, across, along = FIBRE
	for v in high.data.vertices:
		x, y, z = v.co
		q = Vector((x * along, y * across, z * across)) if abs(x) > x0 else Vector((x * across, y * across, z * along))
		v.co += v.normal * depth * (noise.noise(q) + 0.35 * noise.noise(q * 2.7))
	# the concept's starved-muscle torso: ribs slanting down the flanks, abs and the line between them in front
	z1, z2, z3 = (rig.data.bones["DEF-spine.%03d" % i].head_local.z for i in (1, 2, 3))
	ys = rig.data.bones["DEF-spine.002"].head_local.y
	for v in high.data.vertices:
		x, y, z = v.co
		if abs(x) > x0 or y > ys + 0.03:
			continue
		g = 0.0
		ax = abs(x)
		if ax < 0.1 and z1 - 0.02 < z < z3 - 0.02:  # abs: a centre line and three crossings
			g += math.exp(-(x / 0.007) ** 2)
			g += sum(math.exp(-((z - zk) / 0.007) ** 2) for zk in (z1 + 0.05, z2, z2 + 0.08)) * smooth((0.1 - ax) / 0.03)
		if 0.06 < ax < 0.17 and z2 - 0.04 < z < z3 + 0.08:  # ribs
			g += (0.5 + 0.5 * math.cos(2 * math.pi * (z + 0.4 * ax) / 0.034)) ** 6 * smooth((ax - 0.06) / 0.03)
		v.co -= v.normal * 0.0075 * g


def emit_paint(high, a, b, masks, scale=6.0):
	"""Emission shader for an EMIT bake: two colours mottled by noise, mask channels from the "mask" colour
	attribute painting PAINT colours over them (masks: [(channel, colour key)]), creases darkened by local AO."""
	m = bpy.data.materials.new("paint")
	m.use_nodes = True
	nt = m.node_tree
	nt.nodes.clear()
	n, ln = nt.nodes.new, nt.links.new

	def rgb(key):
		c = PAINT[key]
		return (bc.lin(c[0]), bc.lin(c[1]), bc.lin(c[2]), 1)

	def mix(fac, x, y, blend="MIX"):
		mx = n("ShaderNodeMix")
		mx.data_type, mx.blend_type = "RGBA", blend
		for slot, val in ((0, fac), (6, x), (7, y)):
			if isinstance(val, (tuple, float)):
				mx.inputs[slot].default_value = val
			else:
				ln(val, mx.inputs[slot])
		return mx.outputs[2]

	co = n("ShaderNodeTexCoord").outputs["Object"]
	t = n("ShaderNodeTexNoise")
	t.inputs["Scale"].default_value = scale
	t.inputs["Detail"].default_value = 6
	ln(co, t.inputs["Vector"])
	rm = n("ShaderNodeMapRange")
	rm.inputs[1].default_value, rm.inputs[2].default_value = 0.35, 0.65
	ln(t.outputs["Fac"], rm.inputs[0])
	col = mix(rm.outputs[0], rgb(a), rgb(b))
	at = n("ShaderNodeAttribute")
	at.attribute_name = "mask"
	sep = n("ShaderNodeSeparateColor")
	ln(at.outputs["Color"], sep.inputs[0])
	for ch, key in masks:
		col = mix(sep.outputs[ch], col, rgb(key))
	ao = n("ShaderNodeAmbientOcclusion")
	ao.only_local, ao.samples = True, 16
	ao.inputs["Distance"].default_value = 0.04
	sh = n("ShaderNodeMapRange")
	sh.inputs[3].default_value = 0.35
	ln(ao.outputs["AO"], sh.inputs[0])
	col = mix(1.0, col, sh.outputs[0], "MULTIPLY")
	em = n("ShaderNodeEmission")
	ln(col, em.inputs["Color"])
	ln(em.outputs[0], n("ShaderNodeOutputMaterial").inputs["Surface"])
	high.data.materials.clear()
	high.data.materials.append(m)


def mask(high, fn):
	attr = high.data.color_attributes.new("mask", "FLOAT_COLOR", "POINT")
	for i, v in enumerate(high.data.vertices):
		attr.data[i].color = fn(v.co, v.normal) + (1.0,)


def build(out):
	ex.MACROS, ex.MAKEHUMAN_TARGETS = MACROS, MAKEHUMAN_TARGETS
	rig, body = bc.load_source()
	for a in bpy.data.actions:  # as build_characters.build_true_form: rotations below the hips only
		for cb, fcs in bc.channelbag_fcurves(a):
			for fc in fcs:
				if fc.data_path.endswith("location") and "DEF-hips" not in fc.data_path and '"root"' not in fc.data_path:
					cb.fcurves.remove(fc)
			for fc in list(fcs):  # open hands: the concept's fingers hang long and splayed, not in fists
				if any('"DEF-%s.' % f in fc.data_path for f in tf.FINGERS):
					cb.fcurves.remove(fc)
	build_anims.add_true_clips(rig)
	bpy.data.objects.remove(body)
	h, mrig, _eyes = ex.make_human()
	ex.t_pose(h, mrig, rig, [])
	ex.fit_rig(h, mrig, rig)
	cut = cut_head(h, rig)
	mats = {name: tf.material(name, rgb, rough, coat) for name, rgb, rough, coat in MATS}
	h.data.materials.clear()
	h.data.materials.append(mats["mat_shapeshifter_skin"])
	head_high, head, head_parts, roots = build_head(rig, cut, mats)
	parts = head_parts + body_parts(h, rig, mats)
	base = os.path.splitext(out)[0]
	# head: normal and colour from its high copy (pale, greyer in the creases, raw red round the teeth roots)
	ex.bake(head_high, head, base + "_head_normal_1024.png", "NORMAL")
	P, up, fwd, right = head_frame(rig)
	mouth_c = P(0, 0.09, 0.0)

	def head_mask(co, nrm):
		root = min((co - r).length for r in roots)
		inner = smooth(1 - (co - mouth_c).length / 0.06)
		neck = smooth((hz0 + 0.03 - co.z) / 0.07) * smooth((0.06 - fwd.dot(co - hz_pt)) / 0.04)
		return (0.0, max(smooth(1 - root / 0.016), inner), neck)
	hz_pt = rig.data.bones["DEF-head"].head_local
	hz0 = hz_pt.z
	mask(head_high, head_mask)
	emit_paint(head_high, "pale", "grey", [(1, "raw"), (2, "dark")], scale=9.0)
	ex.bake(head_high, head, base + "_head_albedo_1024.png", "EMIT")
	bpy.data.objects.remove(head_high)
	# body: sinew in the normal map; grey-green over the shoulders and chest, a raw red streak down the sternum
	high = tf.copy(h)
	high.modifiers.new("Sub", "SUBSURF").levels = 2
	bc.activate(high)
	bpy.ops.object.modifier_apply(modifier="Sub")
	sculpt_body(high, rig)
	bc.triangulate(h)
	for o in parts + [head]:
		bc.triangulate(o)
	room = bc.LOD_TRIS[0] - sum(bc.tris(o) for o in parts + [head])
	m = h.modifiers.new("Dec", "DECIMATE")
	m.ratio = room / bc.tris(h) * 0.98
	bc.activate(h)
	bpy.ops.object.modifier_apply(modifier="Dec")
	bc.triangulate(h)
	ex.bake(high, h, base + "_normal_1024.png", "NORMAL")
	zn, zh = rig.data.bones["DEF-neck"].head_local.z, rig.data.bones["DEF-hips"].head_local.z
	ys = rig.data.bones["DEF-spine.003"].head_local.y

	def body_mask(co, nrm):
		upper = 0.45 * smooth((co.z - zh) / (zn - zh) * 1.4 - 0.4) * (0.5 + 0.5 * smooth(-nrm.y * 2))
		streak = smooth(1 - abs(co.x) / 0.012) * smooth((co.z - (zn - 0.35)) / 0.05) * (co.y < ys)
		return (upper, streak, 0.0)
	mask(high, body_mask)
	emit_paint(high, "dark", "dark", [(0, "sheen"), (1, "raw")], scale=5.0)
	ex.bake(high, h, base + "_albedo_1024.png", "EMIT")
	bpy.data.objects.remove(high)
	bpy.ops.object.select_all(action="DESELECT")
	for o in parts + [head]:
		o.select_set(True)
	h.select_set(True)
	bpy.context.view_layer.objects.active = h
	bpy.ops.object.join()
	h.name = h.data.name = "char_shapeshifter_true_lod0"
	h.parent = rig
	h.modifiers.new("Armature", "ARMATURE").object = rig
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


def main():
	bc.fetch()
	out = os.path.join(bc.OUT_TRUE, "char_shapeshifter_true.glb") if "--ship" in sys.argv else \
		os.path.join(bc.ROOT, "tools", "art", "review", "true_creature.glb")
	print("DONE", build(out))


if __name__ == "__main__":
	main()
