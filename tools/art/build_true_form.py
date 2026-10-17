"""Builds shapeshifter true-form concepts (design/art/true-form-review.md) in Blender: bodies grown along the rig's
own bones instead of the survivor mannequin with parts glued on.

  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
      --python tools/art/build_true_form.py [-- --concept=d|e|f|g | --all] [--ship]

Concepts (designer 2026-10-17: "do one for all three" of the creature directions):
  d  the first new body: starved, long eyeless skull, hanging jaw, ribs and spine under the skin
  e  failed experiment: a former staff member, pale clammy skin, a surgical halo bolted to the skull, an autopsy
     Y-incision held with staples, a dislocated hanging jaw
  f  mimic organism: wet black, a smooth head with a half-formed face pressed into it, a toothed seam down the
     chest, unfinished faces and a half-grown hand budding from the body
  g  something contained: stone-grey and craggy, a long skull with a bone antler crown, tall bone plates down the
     spine, long claws

Steps: the survivor rig (same clips as the shipped true form, arms stretched as build_characters.py does) ->
skin-modifier tubes along the DEF bones -> the concept's flesh, bone and metal shapes -> one voxel-remeshed surface
with flesh noise (the high mesh) -> decimated to the 15k/7k/3k budget, bone and metal material where those shapes
are, normal map baked high -> low, weights by distance to the DEF bones. Height 2.4 m (art bible §5).

Writes tools/art/review/true_<concept>.glb (review, gitignored), or with --ship (one concept)
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
BAKE_PX = 1024
NECK_TOP = Vector((0, 0, 1.58))
## Skin radius (m, source rig scale) at points along each DEF bone: (bone, [(t along bone, radius x, radius y)]).
## Joints wider than the shafts between them: knobbed, starved limbs. Each concept scales these.
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


def skin_body(rig, limb_k, trunk_k):
	"""Skin-modifier tubes: the trunk centreline, then each limb and finger chain from its root on the trunk."""
	bm = bmesh.new()
	radii = []

	def vert(p, rx, ry):
		v = bm.verts.new(Vector(p))
		radii.append((rx, ry))
		return v

	trunk = [vert((0, y, z), rx * trunk_k, ry * trunk_k) for z, rx, ry, y in TRUNK]
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
		return [(t, rx * limb_k, ry * limb_k) for t, rx, ry in LIMB_PROFILE[n.split("-")[1].split(".")[0]]]

	for s in ("L", "R"):
		hand = chain(trunk[5], ["DEF-shoulder." + s, "DEF-upper_arm." + s, "DEF-forearm." + s, "DEF-hand." + s],
			limb_profile)
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


# --- primitives -------------------------------------------------------------------------------------------------

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


def head(k):
	"""Head-shape helpers scaled by k about the top of the neck: point and radii."""
	def p(x):
		return NECK_TOP + (Vector(x) - NECK_TOP) * k

	def r(x):
		return Vector(x) * k
	return p, r


def ribs(bm, r=0.011, n=6):
	for s in (-1, 1):
		for k in range(n):  # pressing through the skin, round the side
			z = 1.44 - k * 0.045
			w = 0.085 - k * 0.002
			arc(bm, [Vector((s * w * math.sin(a), -w * 0.75 * math.cos(a), z - 0.02 * math.sin(a)))
				for a in (0.25, 0.8, 1.35, 1.9, 2.4)], r)


def vertebrae(bm, n=14, size=1.0):
	for k in range(n):
		z = 1.56 - k * 0.042
		ellipsoid(bm, (0, 0.05 + (0.012 if 1.2 < z < 1.48 else 0.0), z), Vector((0.016, 0.018, 0.014)) * size,
			segs=10, rings=6)


def blades(bm, size=1.0):
	for s in (-1, 1):
		ellipsoid(bm, (s * 0.095, 0.065, 1.4), Vector((0.055, 0.02, 0.075)) * size, Matrix.Rotation(s * 0.3, 3, "Z"))


def claws(bm, rig, finger, thumb, r=0.0085, toes=True):
	for s in ("L", "R"):
		for f in FINGERS:
			b = rig.data.bones["DEF-%s.03.%s" % (f, s)]
			d = (b.tail_local - b.head_local).normalized()
			rod(bm, b.tail_local - d * 0.012, b.tail_local + d * (thumb if f == "thumb" else finger), r, 0.0, segs=8)
		if toes:
			b = rig.data.bones["DEF-toe." + s]
			for dx in (-0.018, 0.0, 0.018):
				p = b.tail_local + Vector((dx, 0.004, 0.0))
				rod(bm, p + Vector((0, 0.01, 0.004)), p + Vector((dx * 0.6, -0.05, -0.008)), 0.008, 0.0, segs=6)


def teeth_row(bm, p, hk, n, half_w, y0, curve, z_top, z_tip, r, up=False):
	"""A row of n teeth across the face: x in +-half_w, y from y0 bending back by curve * |a|^1.6."""
	for k in range(n):
		a = (k - (n - 1) / 2) / ((n - 1) / 2)
		x, y = a * half_w, y0 + abs(a) ** 1.6 * curve
		top, tip = (z_tip, z_top) if up else (z_top, z_tip)
		rod(bm, p((x, y, top)), p((x * 1.05, y - 0.006, tip)), r * hk, 0.0, segs=6)


# --- concepts ---------------------------------------------------------------------------------------------------

def d_flesh(bm, rig):
	hk = 1.3
	p, r = head(hk)
	ellipsoid(bm, p((0, 0.015, 1.665)), r((0.07, 0.085, 0.085)))  # cranium
	ellipsoid(bm, p((0, -0.07, 1.635)), r((0.055, 0.12, 0.05)), Matrix.Rotation(0.25, 3, "X"))  # muzzle, no eyes
	ellipsoid(bm, p((0, -0.06, 1.575)), r((0.045, 0.1, 0.02)), Matrix.Rotation(-0.1, 3, "X"))  # jaw, open
	for s in (-1, 1):
		ellipsoid(bm, p((s * 0.035, -0.06, 1.68)), r((0.025, 0.06, 0.014)))  # brow ridges
	blades(bm)
	ribs(bm)
	vertebrae(bm)


def d_bone(bm, rig):
	p, _ = head(1.3)
	teeth_row(bm, p, 1.3, 11, 0.04, -0.17, 0.09, 1.6, 1.562, 0.0065)
	teeth_row(bm, p, 1.3, 11, 0.036, -0.158, 0.09, 1.597, 1.562, 0.006, up=True)
	claws(bm, rig, 0.09, 0.06)
	for k in range(6):  # spine tips between the shoulder blades
		z = 1.46 - k * 0.045
		rod(bm, (0, 0.05, z), (0, 0.105 - k * 0.004, z + 0.02), 0.012, 0.0, segs=8)


def e_flesh(bm, rig):
	"""Failed experiment: a human skull and face, the jaw torn loose and hanging, an autopsy Y-incision welt."""
	p, r = head(1.15)
	ellipsoid(bm, p((0, 0.005, 1.675)), r((0.074, 0.09, 0.095)))  # cranium, human
	ellipsoid(bm, p((0, -0.055, 1.635)), r((0.056, 0.05, 0.07)))  # face
	for s in (-1, 1):
		ellipsoid(bm, p((s * 0.045, -0.08, 1.63)), r((0.02, 0.015, 0.014)))  # cheekbones
		ellipsoid(bm, p((s * 0.028, -0.095, 1.665)), r((0.02, 0.01, 0.008)))  # brow over sunken sockets
	ellipsoid(bm, p((0, -0.075, 1.53)), r((0.038, 0.05, 0.05)), Matrix.Rotation(0.5, 3, "X"))  # jaw, hanging
	blades(bm, 0.9)
	ribs(bm, 0.008)
	vertebrae(bm, size=0.8)
	front = -0.07
	for s in (-1, 1):  # Y-incision: shoulders to sternum, then down the belly
		rod(bm, (s * 0.085, front + 0.01, 1.47), (0, front, 1.36), 0.006, 0.006)
	rod(bm, (0, front, 1.36), (0, front + 0.025, 1.06), 0.006, 0.006)


def e_bone(bm, rig):
	p, _ = head(1.15)
	teeth_row(bm, p, 1.15, 8, 0.03, -0.1, 0.035, 1.6, 1.585, 0.006)  # upper, human and blunt
	teeth_row(bm, p, 1.15, 8, 0.028, -0.112, 0.035, 1.52, 1.508, 0.006, up=True)  # lower, on the hanging jaw
	claws(bm, rig, 0.04, 0.03, r=0.007, toes=False)  # split fingertips


def e_metal(bm, rig):
	"""A surgical halo bolted to the skull, staples along the Y-incision."""
	p, _ = head(1.15)
	c = p((0, -0.005, 1.705))
	ring = [c + Vector((0.125 * math.cos(a), 0.135 * math.sin(a), 0)) for a in [i * math.pi / 10 for i in range(21)]]
	arc(bm, ring, 0.008)
	for a in (0.5, 1.4, 2.6, 3.7, 4.9, 5.8):  # pins into the skull, each with a clamp block
		o = c + Vector((0.125 * math.cos(a), 0.135 * math.sin(a), 0))
		rod(bm, o + (o - c) * 0.08, c + (o - c) * 0.55, 0.0055, 0.004)
		ellipsoid(bm, o, (0.012, 0.012, 0.014), segs=8, rings=6)
	for s in (-1, 1):  # posts down to the shoulders
		rod(bm, c + Vector((s * 0.1, 0.075, 0)), (s * 0.13, 0.05, 1.5), 0.006, 0.006)
	front = -0.07
	lines = [((s * 0.085, front + 0.01, 1.47), (0, front, 1.36)) for s in (-1, 1)]
	lines.append(((0, front, 1.36), (0, front + 0.025, 1.06)))
	for a, b in lines:
		a, b = Vector(a), Vector(b)
		d = (b - a)
		side = d.cross(Vector((0, 1, 0))).normalized() * 0.014
		for k in range(1, int(d.length / 0.022)):
			m = a + d * (k * 0.022 / d.length) + Vector((0, -0.007, 0))
			rod(bm, m - side, m + side, 0.0028, 0.0028, segs=5)


def f_flesh(bm, rig):
	"""Mimic organism: a smooth head with a half-formed face, chest-seam lips, budding faces and a half-grown hand."""
	p, r = head(1.2)
	ellipsoid(bm, p((0, -0.01, 1.675)), r((0.068, 0.095, 0.11)))  # head, no features
	ellipsoid(bm, p((0, -0.1, 1.665)), r((0.01, 0.014, 0.02)))  # the start of a nose
	for s in (-1, 1):
		ellipsoid(bm, p((s * 0.026, -0.094, 1.69)), r((0.02, 0.01, 0.007)))  # the start of a brow
		ellipsoid(bm, (s * 0.024, -0.075, 1.32), (0.018, 0.02, 0.12))  # lips of the chest seam
	blades(bm, 0.8)
	vertebrae(bm, size=0.7)
	for c, rad, nose in (((0.075, -0.035, 1.22), 0.034, (0.08, -0.068, 1.225)),  # budding faces
			((-0.06, 0.06, 1.45), 0.03, (-0.065, 0.088, 1.452)),
			((0.04, -0.03, 1.02), 0.026, (0.043, -0.055, 1.022))):
		ellipsoid(bm, c, (rad, rad * 0.8, rad * 1.15))
		ellipsoid(bm, nose, (0.006, 0.008, 0.01))
	base = Vector((-0.07, 0.0, 1.16))  # a half-grown hand reaching out of the side
	wrist = base + Vector((-0.07, -0.03, -0.06))
	rod(bm, base, wrist, 0.02, 0.012)
	for k, (dx, dz) in enumerate(((-0.01, -0.02), (-0.025, -0.012), (-0.03, 0.0), (-0.025, 0.012))):
		rod(bm, wrist, wrist + Vector((dx - 0.02, -0.02 + k * 0.004, dz - 0.03)), 0.006, 0.003, segs=6)


def f_bone(bm, rig):
	for k in range(14):  # teeth along the chest seam, both sides pointing in
		z = 1.42 - k * 0.0175
		for s in (-1, 1):
			rod(bm, (s * 0.02, -0.085, z), (s * 0.002, -0.088, z - 0.004), 0.0045, 0.0, segs=5)
	claws(bm, rig, 0.07, 0.05, toes=False)


def g_flesh(bm, rig):
	"""Something contained: a long skull swept back, a craggy hump, ribs and a heavy spine."""
	p, r = head(1.25)
	ellipsoid(bm, p((0, 0.045, 1.69)), r((0.062, 0.11, 0.078)), Matrix.Rotation(-0.25, 3, "X"))  # skull, swept back
	ellipsoid(bm, p((0, -0.085, 1.625)), r((0.045, 0.12, 0.042)), Matrix.Rotation(0.2, 3, "X"))  # long muzzle
	ellipsoid(bm, p((0, -0.07, 1.575)), r((0.04, 0.1, 0.018)), Matrix.Rotation(-0.12, 3, "X"))  # jaw
	ellipsoid(bm, (0, 0.06, 1.45), (0.1, 0.05, 0.09))  # hump between the shoulders
	blades(bm, 1.2)
	ribs(bm, 0.012)
	vertebrae(bm, size=1.3)


def g_bone(bm, rig):
	hk = 1.25
	p, _ = head(hk)
	teeth_row(bm, p, hk, 13, 0.036, -0.2, 0.12, 1.6, 1.565, 0.006)
	teeth_row(bm, p, hk, 13, 0.032, -0.185, 0.12, 1.592, 1.562, 0.0055, up=True)
	for s in (-1, 1):  # antler crown: two beams each side, swept back, with tines
		for k, (x0, rise, back) in enumerate(((0.028, 0.13, 0.1), (0.045, 0.09, 0.13))):
			a = p((s * x0, 0.03, 1.74))
			b = a + Vector((s * 0.05, back, rise))
			c = b + Vector((s * 0.03, back * 0.6, rise * 0.4))
			rod(bm, a, b, 0.017 - k * 0.003, 0.011, segs=8)
			rod(bm, b, c, 0.011, 0.0, segs=8)
			rod(bm, a.lerp(b, 0.55), a.lerp(b, 0.55) + Vector((s * 0.04, -0.02, 0.07)), 0.008, 0.0, segs=6)
	for k in range(8):  # tall plates down the spine, tallest over the shoulders
		z = 1.52 - k * 0.06
		h = 0.11 - abs(k - 1.5) * 0.012
		ellipsoid(bm, (0, 0.08 + h * 0.45, z + 0.01), (0.006, h * 0.5, 0.03), Matrix.Rotation(-0.35, 3, "X"),
			segs=10, rings=8)
	claws(bm, rig, 0.11, 0.07, r=0.009)


## Concept -> limb and trunk radius scale, flesh/bone/metal shape builders, skin (sRGB albedo, roughness, coat,
## coat roughness), flesh noise (scale m, depth m). The art bible §5 skin is near-black (sRGB 40-55); e and g step
## outside it on purpose (designer to decide).
CONCEPTS = {
	"d": dict(limb=1.0, trunk=1.0, flesh=d_flesh, bone=d_bone, metal=None,
		skin=((46, 44, 48), 0.4, 1.0, 0.08), noise=(0.035, 0.0035)),
	"e": dict(limb=1.2, trunk=1.08, flesh=e_flesh, bone=e_bone, metal=e_metal,
		skin=((122, 114, 108), 0.55, 0.5, 0.25), noise=(0.03, 0.0028)),
	"f": dict(limb=1.0, trunk=1.0, flesh=f_flesh, bone=f_bone, metal=None,
		skin=((34, 32, 38), 0.22, 1.0, 0.03), noise=(0.06, 0.0015)),
	"g": dict(limb=1.15, trunk=1.18, flesh=g_flesh, bone=g_bone, metal=None,
		skin=((66, 60, 54), 0.78, 0.15, 0.4), noise=(0.06, 0.006)),
}


# --- build ------------------------------------------------------------------------------------------------------

def obj_from(bm, name):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(o)
	return o


def shapes(fn, rig, name):
	bm = bmesh.new()
	if fn:
		fn(bm, rig)
	return obj_from(bm, name)


def copy(o):
	c = o.copy()
	c.data = o.data.copy()
	bpy.context.scene.collection.objects.link(c)
	return c


def high_mesh(parts, noise):
	"""One surface: every part voxel-remeshed, smoothed, then flesh noise along the normals."""
	bpy.ops.object.select_all(action="DESELECT")
	for o in parts:
		o.select_set(True)
	bpy.context.view_layer.objects.active = parts[0]
	bpy.ops.object.join()
	skin = parts[0]
	r = skin.modifiers.new("Remesh", "REMESH")
	r.mode = "VOXEL"
	r.voxel_size = VOXEL_M
	sm = skin.modifiers.new("Smooth", "CORRECTIVE_SMOOTH")
	sm.iterations = 4
	tex = bpy.data.textures.new("flesh", "CLOUDS")
	tex.noise_scale = noise[0]
	tex.noise_depth = 3
	d = skin.modifiers.new("Flesh", "DISPLACE")
	d.texture = tex
	d.texture_coords = "GLOBAL"
	d.strength = noise[1]
	d.mid_level = 0.5
	bc.activate(skin)
	for m in list(skin.modifiers):
		bpy.ops.object.modifier_apply(modifier=m.name)
	skin.name = skin.data.name = "true_high"
	return skin


def low_mesh(high, target):
	low = copy(high)
	low.name = low.data.name = "char_shapeshifter_true_lod0"
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
	img = bpy.data.images.new(os.path.splitext(os.path.basename(path))[0], BAKE_PX, BAKE_PX, float_buffer=False)
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


def material(name, rgb, rough, coat=0.0, coat_rough=0.1, metal=0.0):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	p = m.node_tree.nodes["Principled BSDF"]
	p.inputs["Base Color"].default_value = (bc.lin(rgb[0]), bc.lin(rgb[1]), bc.lin(rgb[2]), 1)
	p.inputs["Roughness"].default_value = rough
	p.inputs["Metallic"].default_value = metal
	p.inputs["Coat Weight"].default_value = coat
	p.inputs["Coat Roughness"].default_value = coat_rough
	return m


def materials(low, skin, refs):
	"""Skin, bone (art bible §5: albedo 190-220) and metal; a face takes the first ref shape it lies on."""
	low.data.materials.clear()
	low.data.materials.append(material("mat_shapeshifter_skin", *skin))
	low.data.materials.append(material("mat_shapeshifter_bone", (206, 198, 178), 0.55))
	low.data.materials.append(material("mat_shapeshifter_metal", (128, 128, 132), 0.4, metal=1.0))
	dg = bpy.context.evaluated_depsgraph_get()
	trees = [(i, BVHTree.FromObject(o, dg)) for i, o in refs if len(o.data.vertices)]
	for poly in low.data.polygons:
		poly.material_index = 0
		for i, t in trees:
			if t.find_nearest(poly.center, 0.0022)[0] is not None:
				poly.material_index = i
				break


def bone_weights(o, rig):
	"""Each vertex to its nearest deform bones by distance to the bone segment (two nearest, 1/d^4 blend).
	Blender's bone-heat weighting fails silently on this mesh (the arms stayed in the T-pose); the rig's deforming
	`root` bone is left out (it pulled skull vertices)."""
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


def build(concept, out):
	c = CONCEPTS[concept]
	rig, body = bc.load_source()
	for a in bpy.data.actions:  # as build_characters.build_true_form: rotations below the hips only
		for cb, fcs in bc.channelbag_fcurves(a):
			for fc in fcs:
				if fc.data_path.endswith("location") and "DEF-hips" not in fc.data_path and '"root"' not in fc.data_path:
					cb.fcurves.remove(fc)
	build_anims.add_true_clips(rig)
	bpy.data.objects.remove(body)
	edit_rig(rig)
	skin = skin_body(rig, c["limb"], c["trunk"])
	flesh = shapes(c["flesh"], rig, "true_flesh")
	bone = shapes(c["bone"], rig, "true_bone")
	metal = shapes(c["metal"], rig, "true_metal")
	refs = [(2, copy(metal)), (1, copy(bone))]
	high = high_mesh([skin, flesh, bone, metal], c["noise"])
	print("HIGH_FACES", len(high.data.polygons))
	low = low_mesh(high, bc.LOD_TRIS[0])
	materials(low, c["skin"], refs)
	bake_normal(high, low, os.path.splitext(out)[0] + "_normal_1024.png")
	for o in [high] + [o for _, o in refs]:
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
	os.makedirs(os.path.dirname(out), exist_ok=True)
	bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True,
		export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
		export_apply=False, export_skins=True, export_morph=False, export_yup=True,
		export_image_format="AUTO", export_materials="EXPORT")
	report = {o.name: bc.tris(o) for o in lods}
	print("TRUE_TRIS", concept, report)
	return report


def main():
	bc.fetch()
	args = {a.split("=")[0]: (a.split("=") + [""])[1] for a in sys.argv[sys.argv.index("--") + 1:]} \
		if "--" in sys.argv else {}
	todo = list(CONCEPTS) if "--all" in args else [args.get("--concept") or "d"]
	if "--ship" in args:
		assert len(todo) == 1, "--ship takes one concept"
		print("DONE", build(todo[0], os.path.join(bc.OUT_TRUE, "char_shapeshifter_true.glb")))
		return
	print("DONE", {k: build(k, os.path.join(bc.ROOT, "tools", "art", "review", "true_%s.glb" % k)) for k in todo})


if __name__ == "__main__":
	main()
