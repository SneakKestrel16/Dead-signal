"""Builds the character art (ASSET-001..010, design/assets/specs/characters-assets.md) in Blender.

Re-runnable, no manual steps:
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
      --python tools/art/build_characters.py [-- --true-options]

Source rig and animations: Quaternius "Universal Animation Library" (Standard), CC0 1.0, fetched from the
glTF mirror github.com/J-Ponzo/gltf-universal-animation-library into tools/art/.cache/ (gitignored). See
assets/art/CREDITS.md "## Characters".

Writes:
  assets/art/characters/survivors/char_survivor_body.glb    body LOD0-2 + 5 accessories + rig + animations
  assets/art/characters/survivors/char_survivor_body_{albedo,normal,orm}_1024.png
      albedo alpha = tint mask (1 = suit, tinted per look; 0 = gloves, boots, visor, hood)
  assets/art/characters/survivors/tex_survivor_stripe_mask_256.png   5 pattern rows (see _stripe_mask)
  assets/art/characters/shapeshifter/char_shapeshifter_true.glb   true form LOD0-2, same rig family

Downloaded files are untrusted data: only Blender's glTF importer reads them; nothing in the cache runs.
"""
import math
import os
import struct
import sys
import urllib.request
import zlib

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_anims  # noqa: E402  (authored clips, ASSET-008/010)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CACHE = os.path.join(ROOT, "tools", "art", ".cache", "ual")
SRC_GLTF = os.path.join(CACHE, "glTF", "AnimationLibrary_Godot_Standard.gltf")
MIRROR = "https://raw.githubusercontent.com/J-Ponzo/gltf-universal-animation-library/HEAD/"
OUT_SURV = os.path.join(ROOT, "assets", "art", "characters", "survivors")
OUT_TRUE = os.path.join(ROOT, "assets", "art", "characters", "shapeshifter")

## Animations kept (source names; BodyVisual maps gaits to them). The rest of the library is dropped.
KEEP_ANIMS = ["Idle_Loop", "Idle_Torch_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Crouch_Idle_Loop",
	"Crouch_Fwd_Loop", "Interact", "PickUp_Table", "Fixing_Kneeling", "Push_Loop", "Hit_Chest", "Hit_Head",
	"Death01", "Punch_Enter", "Punch_Cross", "Sword_Attack"]
## Authored on top of these by build_anims.py: survivor Downed, Crawl, Call_Help, Stand_Up, Seized, Hide_Enter,
## Hide_Exit; true form Lunge_Coil, Lunge_Dash, Lunge_Stumble, Takedown_Pin.
## Per-character triangle budgets (art bible §8 engine budgets).
LOD_TRIS = [15000, 7000, 3000]
ACCESSORY_MAX_TRIS = 2000
TEX = 1024
## Padded jumpsuit: smoothing passes over the suit, then the outward padding in metres.
SUIT_SMOOTH_STEPS = 10
SUIT_PAD_M = 0.03
MASK = 256

HAND = ("DEF-hand", "DEF-f_", "DEF-thumb")
FEET = ("DEF-foot", "DEF-toe")
HEAD = ("DEF-head", "DEF-neck")
ARM = ("DEF-upper_arm", "DEF-forearm") + HAND


def lin(srgb8):
	"""sRGB 0-255 -> linear 0-1."""
	c = srgb8 / 255.0
	return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


# Region attribute (vertex colour "region"): R = tint mask, G = linear albedo grey, B = roughness.
# Values inside art bible §6 (albedo sRGB 32-225, never pure black) except the suit base, which the
# look tint multiplies down (suit tint x base lands inside the range for all five looks).
SUIT = (1.0, lin(240), 0.8)
GLOVE = (0.0, lin(58), 0.7)
BOOT = (0.0, lin(44), 0.6)
HOOD = (0.0, lin(62), 0.85)
BELT = (0.0, lin(70), 0.55)
VISOR = (0.0, lin(34), 0.12)


def fetch():
	if os.path.exists(SRC_GLTF):
		return
	for rel in ["LICENSE", "README.md", "glTF/AnimationLibrary_Godot_Standard.bin",
			"glTF/AnimationLibrary_Godot_Standard.gltf"]:
		dst = os.path.join(CACHE, *rel.split("/"))
		os.makedirs(os.path.dirname(dst), exist_ok=True)
		urllib.request.urlretrieve(MIRROR + rel, dst)


def write_png(path, rgba):
	"""rgba: HxWx4 uint8, row 0 = top. Plain zlib writer (no PIL in Blender's Python)."""
	h, w = rgba.shape[:2]
	raw = b"".join(b"\x00" + rgba[y].tobytes() for y in range(h))
	def chunk(t, d):
		return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
	png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
	png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, "wb") as f:
		f.write(png)


def to_srgb(a):
	a = np.clip(a, 0.0, 1.0)
	return np.where(a <= 0.0031308, a * 12.92, 1.055 * np.power(a, 1 / 2.4) - 0.055)


# --- scene helpers -------------------------------------------------------------------------------

def load_source():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=SRC_GLTF)
	for o in list(bpy.data.objects):
		if o.type == "MESH" and o.parent is None:
			bpy.data.objects.remove(o)  # stray Icosphere in the source file
	for a in list(bpy.data.actions):
		if a.name not in KEEP_ANIMS:
			bpy.data.actions.remove(a)
	rig = bpy.data.objects["Rig"]
	body = bpy.data.objects["Mannequin"]
	return rig, body


def channelbag_fcurves(action):
	out = []
	for layer in action.layers:
		for strip in layer.strips:
			for cb in strip.channelbags:
				out.append((cb, list(cb.fcurves)))
	return out


def dominant_groups(obj):
	names = {g.index: g.name for g in obj.vertex_groups}
	dom = []
	for v in obj.data.vertices:
		best = max(v.groups, key=lambda g: g.weight, default=None)
		dom.append(names[best.group] if best else "")
	return dom


def tris(obj):
	return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def activate(obj):
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj


def skin_to(obj, rig, bone_weights):
	"""Parents `obj` to `rig` with an Armature modifier; bone_weights: list of (bone, vertex index list)."""
	for bone, idx in bone_weights:
		g = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
		g.add(idx, 1.0, "REPLACE")
	obj.parent = rig
	m = obj.modifiers.new("Armature", "ARMATURE")
	m.object = rig


def claim(bm, tag):
	"""Labels every vertex not labelled yet with `tag` (> 0) in the "part" int layer. Vertex order is no
	guide to which primitive made a vertex: bmesh reuses freed slots, so new vertices land between old ones."""
	layer = bm.verts.layers.int.get("part") or bm.verts.layers.int.new("part")
	for v in bm.verts:
		if v[layer] == 0:
			v[layer] = tag


def part_groups(obj, bones):
	"""(bone, vertex indices) per claim() tag; bones[k] is tag k + 1. Drops the "part" attribute."""
	vals = [a.value for a in obj.data.attributes["part"].data]
	obj.data.attributes.remove(obj.data.attributes["part"])
	return [(b, [i for i, t in enumerate(vals) if t == k + 1]) for k, b in enumerate(bones)]


def new_mesh_obj(name, bm):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(o)
	return o


def set_colours(obj, colour_of_face):
	"""Vertex colour COLOR_0 per face corner from colour_of_face(poly) -> linear (r, g, b)."""
	attr = obj.data.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
	for p in obj.data.polygons:
		c = colour_of_face(p)
		for li in p.loop_indices:
			attr.data[li].color = (c[0], c[1], c[2], 1.0)


def bm_box(bm, centre, size, rot_z=0.0, rot_x=0.0, rot_y=0.0, tag=0):
	r = bmesh.ops.create_cube(bm, size=1.0)
	vs = r["verts"]
	bmesh.ops.scale(bm, vec=Vector(size), verts=vs)
	for ang, axis in [(rot_x, "X"), (rot_y, "Y"), (rot_z, "Z")]:
		if ang:
			from mathutils import Matrix
			bmesh.ops.rotate(bm, verts=vs, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(ang, 3, axis))
	bmesh.ops.translate(bm, vec=Vector(centre), verts=vs)
	for f in {f for v in vs for f in v.link_faces}:
		f.material_index = tag
	bm.verts.index_update()  # new verts carry no valid index until this
	return vs


def bm_cyl(bm, centre, r1, r2, depth, segs=12, axis="Z", tag=0, angle=0.0):
	from mathutils import Matrix
	r = bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
	vs = r["verts"]
	if axis == "X":
		bmesh.ops.rotate(bm, verts=vs, cent=Vector(), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
	elif axis == "Y":
		bmesh.ops.rotate(bm, verts=vs, cent=Vector(), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
	if angle:
		bmesh.ops.rotate(bm, verts=vs, cent=Vector(), matrix=Matrix.Rotation(angle, 3, "Y"))
	bmesh.ops.translate(bm, vec=Vector(centre), verts=vs)
	for f in {f for v in vs for f in v.link_faces}:
		f.material_index = tag
	bm.verts.index_update()  # new verts carry no valid index until this
	return vs


def bm_sphere(bm, centre, radii, segs=16, rings=8, tag=0, keep=None):
	r = bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
	vs = r["verts"]
	if keep is not None:  # on the unit sphere, before scaling
		bmesh.ops.delete(bm, geom=[v for v in vs if not keep(v.co)], context="VERTS")
		vs = [v for v in vs if v.is_valid]
	for v in vs:
		v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))
	bmesh.ops.translate(bm, vec=Vector(centre), verts=vs)
	for f in {f for v in vs for f in v.link_faces}:
		f.material_index = tag
	bm.verts.index_update()  # new verts carry no valid index until this
	return vs


def group_bbox(obj, dom, prefixes):
	pts = [obj.data.vertices[i].co for i, g in enumerate(dom) if g.startswith(prefixes)]
	lo = Vector([min(p[k] for p in pts) for k in range(3)])
	hi = Vector([max(p[k] for p in pts) for k in range(3)])
	return lo, hi


def decimate_copy(src, name, target):
	o = src.copy()
	o.data = src.data.copy()
	o.name = name
	o.data.name = name
	bpy.context.scene.collection.objects.link(o)
	ratio = min(1.0, target / max(1, tris(src)))
	if ratio < 1.0:
		m = o.modifiers.new("Decimate", "DECIMATE")
		m.ratio = ratio * 0.98
		activate(o)
		# The Armature modifier stays; the decimate goes first so it applies on the rest shape.
		bpy.ops.object.modifier_move_to_index(modifier="Decimate", index=0)
		bpy.ops.object.modifier_apply(modifier="Decimate")
	triangulate(o)
	o.data.validate()
	return o


def triangulate(obj):
	bm = bmesh.new()
	bm.from_mesh(obj.data)
	bmesh.ops.triangulate(bm, faces=bm.faces)
	bm.to_mesh(obj.data)
	bm.free()


def export(path, objects):
	bpy.ops.object.select_all(action="DESELECT")
	for o in objects:
		o.select_set(True)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
		export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
		export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_apply=False,
		export_skins=True, export_morph=False, export_yup=True, export_image_format="NONE",
		export_materials="EXPORT")


# --- survivor --------------------------------------------------------------------------------------

def survivor_regions(body, dom):
	out = []
	for i, v in enumerate(body.data.vertices):
		g = dom[i]
		z = v.co.z
		if g.startswith(HAND):
			out.append(GLOVE)
		elif g.startswith(FEET) or (g.startswith("DEF-shin") and z < 0.2):
			out.append(BOOT)
		elif g.startswith(HEAD):
			out.append(HOOD)
		else:
			out.append(SUIT)
	return out


def pad_body(body, dom, regions):
	"""Padded jumpsuit: push the suit out along the normal, smoothed so region borders do not step."""
	bm = bmesh.new()
	bm.from_mesh(body.data)
	bm.verts.ensure_lookup_table()
	pad = np.array([SUIT_PAD_M if r is SUIT or r is BELT else 0.012 if r is BOOT else 0.006 if r is HOOD else 0.004
		for r in regions])
	for _ in range(6):
		nxt = pad.copy()
		for v in bm.verts:
			nb = [e.other_vert(v).index for e in v.link_edges]
			if nb:
				nxt[v.index] = 0.5 * pad[v.index] + 0.5 * pad[nb].mean()
		pad = nxt
	# Smooth away the source mannequin's muscle definition on the suit before padding it out.
	soft = [v for v in bm.verts if regions[v.index] is SUIT]
	for _ in range(SUIT_SMOOTH_STEPS):
		bmesh.ops.smooth_vert(bm, verts=soft, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
	bm.normal_update()
	for v in bm.verts:
		v.co += v.normal * pad[v.index]
	# Rounded bulk (art bible §3): a slightly fuller torso and thighs.
	for v in bm.verts:
		g = dom[v.index]
		if g.startswith(("DEF-spine", "DEF-hips")):
			v.co.x *= 1.06
			v.co.y = 0.01 + (v.co.y - 0.01) * 1.08
	bm.to_mesh(body.data)
	bm.free()


def add_visor(body, dom):
	lo, hi = group_bbox(body, dom, ("DEF-head",))
	cx = 0.0
	cz = lo.z + (hi.z - lo.z) * 0.52
	bm = bmesh.new()
	w = (hi.x - lo.x) * 0.46
	# Front half-shell of an ellipsoid, a wrap-around dark visor over the eyes.
	bm_sphere(bm, (cx, lo.y + 0.075, cz), (w, 0.085, 0.05), segs=24, rings=10, keep=lambda c: c.y < -0.3)
	vis = new_mesh_obj("visor_tmp", bm)
	n0 = len(body.data.vertices)
	nv = len(vis.data.vertices)
	activate(body)
	vis.select_set(True)
	bpy.ops.object.join()
	g = body.vertex_groups["DEF-head"]
	g.add(list(range(n0, n0 + nv)), 1.0, "REPLACE")
	return list(range(n0, n0 + nv))


def write_region_attr(body, regions):
	if "region" in body.data.color_attributes:
		body.data.color_attributes.remove(body.data.color_attributes["region"])
	attr = body.data.color_attributes.new("region", "FLOAT_COLOR", "POINT")
	for i, r in enumerate(regions):
		attr.data[i].color = (r[0], r[1], r[2], 1.0)


def stripe_uv(body, dom):
	"""UV1 (TEXCOORD_1) in Godot's v-down convention (glTF flips v): chest planar projection, u 0-1 across the
	stripe area and v 0-1 top to bottom; left upper-arm band, u around the arm and v 2-3 along it. Projections
	run past their areas (out of [0, 1] / [2, 3]) so a big triangle interpolates continuously instead of
	smearing a pattern: the source mesh is coarse on the chest. Elsewhere UV1 is far outside both."""
	me = body.data
	uv = me.uv_layers.new(name="UV_stripe")
	cx0, cx1, cz0, cz1 = -0.15, 0.15, 1.20, 1.38
	ax0, ax1 = 0.30, 0.38
	for p in me.polygons:
		for li in p.loop_indices:
			vi = me.loops[li].vertex_index
			co = me.vertices[vi].co
			g = dom[vi] if vi < len(dom) else ""
			n = me.vertices[vi].normal
			if g.startswith(("DEF-upper_arm.L", "DEF-shoulder.L")) and co.x > 0.22:
				ang = math.atan2(co.z - 1.441, co.y - 0.07)
				u = (ang + math.pi) / (2 * math.pi)
				v = -1.0 - (co.x - ax0) / (ax1 - ax0)  # Godot v = 1 - v: 2 + t
			elif n.y < -0.1 and abs(co.x) < 0.22 and 1.05 < co.z < 1.6 and not g.startswith(HEAD):
				u = (co.x - cx0) / (cx1 - cx0)
				v = (co.z - cz0) / (cz1 - cz0)  # Godot v = 1 - v: 0 at the top
			else:
				# Godot v 1.5: between the two areas, so an edge to either never crosses into the other.
				u, v = -5.0, -0.5
			uv.data[li].uv = (u, v)


def stripe_mask():
	"""256x256, 5 rows of 51 px (row r = pattern for look r+1, top to bottom). In each row the left 80% is
	the chest area, the right 20% the left sleeve band. Row = image v; chest-area v 0 = top of the band."""
	img = np.zeros((MASK, MASK), np.float32)
	rh = MASK / 5.0
	ys, xs = np.mgrid[0:MASK, 0:MASK]
	for r in range(5):
		top = r * rh
		ly = (ys - top) / rh  # 0 top .. 1 bottom inside the row
		inrow = (ly >= 0.0) & (ly < 1.0)
		cu = xs / (MASK * 0.8)  # chest local u
		chest = inrow & (cu < 1.0) & (cu > 0.0)
		sleeve = inrow & (xs >= MASK * 0.8)
		hx = (cu > 0.08) & (cu < 0.92)
		if r == 0:
			m = chest & hx & (ly > 0.38) & (ly < 0.62)
		elif r == 1:
			m = chest & hx & (((ly > 0.2) & (ly < 0.4)) | ((ly > 0.6) & (ly < 0.8)))
		elif r == 2:
			m = chest & (np.abs(ly - (0.25 + 1.0 * np.abs(cu - 0.5))) < 0.12) & (cu > 0.12) & (cu < 0.88)
		elif r == 3:
			m = np.zeros_like(chest)
			for dx in (0.25, 0.5, 0.75):
				m |= chest & (((cu - dx) * 0.8 * MASK) ** 2 + ((ly - 0.5) * rh) ** 2 < (rh * 0.2) ** 2)
		else:
			m = sleeve & (ly > 0.1) & (ly < 0.9)
		img[m] = 1.0
	out = np.zeros((MASK, MASK, 4), np.uint8)
	out[..., 0] = out[..., 1] = out[..., 2] = (img * 255).astype(np.uint8)
	out[..., 3] = 255
	write_png(os.path.join(OUT_SURV, "tex_survivor_stripe_mask_256.png"), out)


def bake_body(body):
	"""Bakes albedo(+tint mask in alpha), tangent normal (quilting seams) and ORM from the region attribute
	through Cycles EMIT/AO/NORMAL bakes into float images, then writes 8-bit PNGs."""
	me = body.data
	for u in list(me.uv_layers):
		if u.name != "UV_stripe":
			me.uv_layers.remove(u)
	uv0 = me.uv_layers.new(name="UV0")
	me.uv_layers.active = uv0
	# UV0 must be first (TEXCOORD_0): rebuild the stripe layer after it.
	st = [tuple(d.uv) for d in me.uv_layers["UV_stripe"].data]
	me.uv_layers.remove(me.uv_layers["UV_stripe"])
	uv1 = me.uv_layers.new(name="UV_stripe")
	for i, d in enumerate(uv1.data):
		d.uv = st[i]
	me.uv_layers.active = me.uv_layers["UV0"]
	activate(body)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
	bpy.ops.object.mode_set(mode="OBJECT")

	sc = bpy.context.scene
	sc.render.engine = "CYCLES"
	sc.cycles.device = "CPU"
	sc.cycles.samples = 16
	sc.render.bake.margin = 8

	mat = bpy.data.materials.new("bake")
	mat.use_nodes = True
	nt = mat.node_tree
	for n in list(nt.nodes):
		nt.nodes.remove(n)
	out = nt.nodes.new("ShaderNodeOutputMaterial")
	bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
	emit = nt.nodes.new("ShaderNodeEmission")
	attr = nt.nodes.new("ShaderNodeVertexColor")
	attr.layer_name = "region"
	sep = nt.nodes.new("ShaderNodeSeparateColor")
	nt.links.new(attr.outputs["Color"], sep.inputs["Color"])
	texco = nt.nodes.new("ShaderNodeTexCoord")
	# Quilted padding: horizontal seams every ~9 cm on the suit (Z bands in object space).
	wave = nt.nodes.new("ShaderNodeTexWave")
	wave.wave_type = "BANDS"
	wave.bands_direction = "Z"
	wave.inputs["Scale"].default_value = 3.5
	wave.inputs["Distortion"].default_value = 0.0
	nt.links.new(texco.outputs["Object"], wave.inputs["Vector"])
	seam = nt.nodes.new("ShaderNodeMath")
	seam.operation = "POWER"
	nt.links.new(wave.outputs["Fac"], seam.inputs[0])
	seam.inputs[1].default_value = 0.25
	seam_m = nt.nodes.new("ShaderNodeMath")
	seam_m.operation = "MULTIPLY"
	nt.links.new(seam.outputs[0], seam_m.inputs[0])
	nt.links.new(sep.outputs["Red"], seam_m.inputs[1])
	bump = nt.nodes.new("ShaderNodeBump")
	bump.inputs["Strength"].default_value = 0.6
	bump.inputs["Distance"].default_value = 0.004
	nt.links.new(seam_m.outputs[0], bump.inputs["Height"])
	nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
	# Baked wear: low-frequency noise darkening, shared by every look (art bible §5 copy rule).
	noise = nt.nodes.new("ShaderNodeTexNoise")
	noise.inputs["Scale"].default_value = 6.0
	nt.links.new(texco.outputs["Object"], noise.inputs["Vector"])
	wear = nt.nodes.new("ShaderNodeMapRange")
	nt.links.new(noise.outputs["Fac"], wear.inputs["Value"])
	wear.inputs["To Min"].default_value = 0.86
	wear.inputs["To Max"].default_value = 1.0
	grey = nt.nodes.new("ShaderNodeMath")
	grey.operation = "MULTIPLY"
	nt.links.new(sep.outputs["Green"], grey.inputs[0])
	nt.links.new(wear.outputs["Result"], grey.inputs[1])
	seam_dark = nt.nodes.new("ShaderNodeMapRange")
	nt.links.new(seam_m.outputs[0], seam_dark.inputs["Value"])
	seam_dark.inputs["To Min"].default_value = 0.85
	seam_dark.inputs["To Max"].default_value = 1.0
	grey2 = nt.nodes.new("ShaderNodeMath")
	grey2.operation = "MULTIPLY"
	nt.links.new(grey.outputs[0], grey2.inputs[0])
	nt.links.new(sep.outputs["Red"], seam_dark.inputs["From Min"])  # 0 off-suit: no darkening
	seam_dark.inputs["From Min"].default_value = 0.0
	nt.links.new(seam_dark.outputs["Result"], grey2.inputs[1])
	nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
	img_node = nt.nodes.new("ShaderNodeTexImage")
	nt.nodes.active = img_node
	me.materials.clear()
	me.materials.append(mat)

	def bake(kind, source, samples=16):
		img = bpy.data.images.new("bake_" + kind, TEX, TEX, float_buffer=True, alpha=False)
		img.colorspace_settings.name = "Non-Color"
		img_node.image = img
		sc.cycles.samples = samples
		if kind in ("AO", "NORMAL"):
			nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
			bpy.ops.object.bake(type=kind, normal_space="TANGENT", margin=8, use_clear=True)
		else:
			for l in list(emit.inputs["Color"].links):
				nt.links.remove(l)
			nt.links.new(source, emit.inputs["Color"])
			nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
			bpy.ops.object.bake(type="EMIT", margin=8, use_clear=True)
		a = np.empty(TEX * TEX * 4, np.float32)
		img.pixels.foreach_get(a)
		return a.reshape(TEX, TEX, 4)[::-1]  # Blender rows are bottom-up

	activate(body)
	alb = bake("EMIT", grey2.outputs[0])[..., 0]
	tint = bake("EMIT", sep.outputs["Red"])[..., 0]
	rough = bake("EMIT", sep.outputs["Blue"])[..., 0]
	ao = bake("AO", None, samples=48)[..., 0]
	nrm = bake("NORMAL", None, samples=4)
	rgba = np.zeros((TEX, TEX, 4), np.uint8)
	s = (to_srgb(alb) * 255 + 0.5).astype(np.uint8)
	rgba[..., 0] = rgba[..., 1] = rgba[..., 2] = s
	rgba[..., 3] = (np.clip(tint, 0, 1) * 255 + 0.5).astype(np.uint8)
	write_png(os.path.join(OUT_SURV, "char_survivor_body_albedo_1024.png"), rgba)
	n8 = np.zeros((TEX, TEX, 4), np.uint8)
	n8[..., :3] = (np.clip(nrm[..., :3], 0, 1) * 255 + 0.5).astype(np.uint8)
	n8[..., 3] = 255
	write_png(os.path.join(OUT_SURV, "char_survivor_body_normal_1024.png"), n8)
	orm = np.zeros((TEX, TEX, 4), np.uint8)
	orm[..., 0] = (np.clip(0.35 + 0.65 * ao, 0, 1) * 255 + 0.5).astype(np.uint8)
	orm[..., 1] = (np.clip(rough, 0, 1) * 255 + 0.5).astype(np.uint8)
	orm[..., 3] = 255
	write_png(os.path.join(OUT_SURV, "char_survivor_body_orm_1024.png"), orm)
	# The exported material is a placeholder: BodyVisual overrides it with the body shader + these PNGs.
	me.materials.clear()
	m = bpy.data.materials.new("mat_survivor_body")
	me.materials.append(m)
	me.color_attributes.remove(me.color_attributes["region"])


# Accessory palette, sRGB 0-255 (art bible §5 "Accessory palette" table records it). Rules, art bible §4/§5:
# never objective cyan or exit green (nor red, which is beacon-only), albedo 32-225 and at most ~35% saturation
# like the world, and the main colour at least ACC_VALUE_SEP away from its own suit in luma so the silhouette
# separates from the body under the flashlight and in amber/red zone light. Inference: the 60 threshold is not
# sourced; a capture of each look under the flashlight in Zone B and C light settles it.
ACC_VALUE_SEP = 60
P_DARK = (48, 48, 52)  # straps, radio body
P_METAL = (120, 122, 126)  # lamp, clip
P_PAPER = (210, 206, 196)
## accessory -> (suit hex of its look, main colour, other colours).
ACCESSORY_PALETTE = {
	"acc_c1_hardhat": ("E6E1D3", (90, 96, 102), [P_METAL]),  # slate hat on the lightest suit
	"acc_c2_backpack": ("E3B31C", (78, 74, 60), [P_DARK]),  # dark olive canvas on safety yellow
	"acc_c3_hood": ("2E63B8", (201, 193, 170), [(216, 208, 188)]),  # oatmeal hood, paler scarf on cobalt
	"acc_c4_radio": ("C8581E", (196, 189, 168), [P_DARK]),  # pale canvas strap, dark radio on rust
	"acc_c5_clipboard": ("7B4FA0", (180, 182, 178), [(185, 164, 126), P_PAPER, P_METAL]),  # grey pad, tan board
}
RESERVED_HEX = ("3FA9D6", "4FD18B", "B3342E")  # Signal Cyan, Exit Green, Security Red (art bible §4)


def luma(c):
	"""Rec. 709 luma of an sRGB 0-255 triple."""
	return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def check_accessory_palette():
	"""Fails the build when an accessory colour breaks the art bible §4/§5 rules above."""
	for name, (suit_hex, main, others) in ACCESSORY_PALETTE.items():
		suit = tuple(int(suit_hex[i:i + 2], 16) for i in (0, 2, 4))
		assert abs(luma(main) - luma(suit)) >= ACC_VALUE_SEP, (name, "main colour too close in value to its suit")
		for c in [main] + others:
			assert 32 <= min(c) and max(c) <= 225, (name, c, "albedo outside 32-225")
			assert (max(c) - min(c)) / max(c) <= 0.35, (name, c, "saturation over 35%")
			for h in RESERVED_HEX:
				r = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
				assert sum((a - b) ** 2 for a, b in zip(c, r)) ** 0.5 > 60, (name, c, "near reserved", h)


def P(c):
	"""sRGB triple -> linear vertex colour."""
	return tuple(lin(x) for x in c)


def _acc(name, i):
	"""Colour i of accessory `name`: 0 the main colour, then its others."""
	_suit, main, others = ACCESSORY_PALETTE[name]
	return P(([main] + others)[i])


def accessories(rig, body, dom):
	lo_h, hi_h = group_bbox(body, dom, ("DEF-head",))
	hc = Vector((0.0, (lo_h.y + hi_h.y) / 2, (lo_h.z + hi_h.z) / 2))
	hr = (hi_h.x - lo_h.x) / 2
	top = hi_h.z
	out = []

	# C1 hard hat with lamp (lamp not emissive).
	bm = bmesh.new()
	bm_sphere(bm, (hc.x, hc.y, top - 0.085), (hr * 1.18, hr * 1.25, 0.13), segs=20, rings=10, tag=0,
		keep=lambda c: c.z > -0.01)
	bm_cyl(bm, (hc.x, hc.y - 0.01, top - 0.085), hr * 1.45, hr * 1.45, 0.012, segs=24, tag=1)
	bm_box(bm, (hc.x, hc.y, top + 0.04), (0.035, hr * 2.2, 0.03), tag=0)
	bm_cyl(bm, (hc.x, lo_h.y - 0.03, top - 0.03), 0.028, 0.034, 0.05, segs=12, axis="Y", tag=2)
	o = new_mesh_obj("acc_c1_hardhat", bm)
	set_colours(o, lambda p: _acc(o.name, [0, 0, 1][p.material_index]))
	skin_to(o, rig, [("DEF-head", list(range(len(o.data.vertices))))])
	out.append(o)

	# C2 large square backpack (on the back, +Y is back in the source rig).
	lo_t, hi_t = group_bbox(body, dom, ("DEF-spine.002", "DEF-spine.003"))
	bm = bmesh.new()
	back = hi_t.y
	bm_box(bm, (0, back + 0.12, 1.22), (0.40, 0.22, 0.52), tag=0)
	bm_box(bm, (0, back + 0.245, 1.12), (0.30, 0.05, 0.22), tag=1)
	bm_box(bm, (0, back + 0.12, 1.50), (0.30, 0.16, 0.05), tag=1)
	for sx in (-0.11, 0.11):
		bm_box(bm, (sx, lo_t.y - 0.02, 1.30), (0.05, 0.02, 0.32), tag=1)
		bm_box(bm, (sx, (lo_t.y + back) / 2, 1.47), (0.05, back - lo_t.y + 0.04, 0.03), tag=1)
	o = new_mesh_obj("acc_c2_backpack", bm)
	set_colours(o, lambda p: _acc(o.name, p.material_index))
	skin_to(o, rig, [("DEF-spine.003", list(range(len(o.data.vertices))))])
	out.append(o)

	# C3 hood + scarf tail.
	bm = bmesh.new()
	hood = bm_sphere(bm, (hc.x, hc.y + 0.02, hc.z + 0.01), (hr * 1.35, hr * 1.45, (hi_h.z - lo_h.z) * 0.62),
		segs=20, rings=12, tag=0, keep=lambda c: not (c.y < -0.35 and c.z < 0.75))
	claim(bm, 1)
	bm_cyl(bm, (0, 0.0, 1.50), 0.11, 0.10, 0.07, segs=16, tag=1)
	claim(bm, 2)
	bm_box(bm, (0.06, 0.13, 1.30), (0.09, 0.02, 0.36), rot_y=0.15, tag=1)
	claim(bm, 3)
	o = new_mesh_obj("acc_c3_hood", bm)
	set_colours(o, lambda p: _acc(o.name, p.material_index))
	skin_to(o, rig, part_groups(o, ["DEF-head", "DEF-neck", "DEF-spine.003"]))
	out.append(o)

	# C4 cross-strap radio with short antenna: the strap crosses the back (right shoulder -> left hip) and
	# shows in front only over the right shoulder, so the chest stripe (three dots) stays clear; radio on
	# the left hip, antenna up beside the chest stripe area.
	bm = bmesh.new()
	front = lo_t.y
	bm_box(bm, (-0.145, front - 0.03, 1.40), (0.05, 0.02, 0.18), rot_y=0.12, tag=0)
	bm_box(bm, (-0.17, 0.07, 1.50), (0.06, back - front + 0.08, 0.02), tag=0)
	bm_box(bm, (0.0, back + 0.03, 1.22), (0.06, 0.02, 0.62), rot_y=0.62, tag=0)
	bm_box(bm, (0.19, front - 0.02, 1.02), (0.10, 0.07, 0.15), tag=1)
	bm_cyl(bm, (0.22, front - 0.02, 1.185), 0.008, 0.005, 0.18, segs=8, tag=2)
	bm_cyl(bm, (0.22, front - 0.02, 1.28), 0.014, 0.014, 0.02, segs=8, tag=2)
	o = new_mesh_obj("acc_c4_radio", bm)
	set_colours(o, lambda p: _acc(o.name, [0, 1, 1][p.material_index]))
	skin_to(o, rig, [("DEF-spine.003", list(range(len(o.data.vertices))))])
	out.append(o)

	# C5 shoulder pad (right) + clipboard (left hand).
	bm = bmesh.new()
	bm_sphere(bm, (-0.25, 0.07, 1.47), (0.12, 0.12, 0.08), segs=16, rings=8, tag=0, keep=lambda c: c.z > -0.2)
	claim(bm, 1)
	bm_box(bm, (0.83, 0.03, 1.36), (0.23, 0.012, 0.30), tag=1)
	bm_box(bm, (0.83, 0.022, 1.36), (0.21, 0.004, 0.27), tag=2)
	bm_box(bm, (0.83, 0.03, 1.50), (0.07, 0.03, 0.03), tag=3)
	claim(bm, 2)
	o = new_mesh_obj("acc_c5_clipboard", bm)
	set_colours(o, lambda p: _acc(o.name, [0, 1, 2, 3][p.material_index]))
	skin_to(o, rig, part_groups(o, ["DEF-upper_arm.R", "DEF-hand.L"]))
	out.append(o)

	m = bpy.data.materials.new("mat_survivor_accessory")
	for o in out:
		for poly in o.data.polygons:
			poly.material_index = 0  # tags only chose colours: one accessory slot (art bible §8)
		o.data.materials.append(m)
		triangulate(o)
		assert tris(o) <= ACCESSORY_MAX_TRIS, (o.name, tris(o))
	return out


def build_survivor():
	rig, body = load_source()
	build_anims.add_survivor_clips(rig)
	activate(body)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.mesh.remove_doubles(threshold=0.0001)
	bpy.ops.object.mode_set(mode="OBJECT")
	dom = dominant_groups(body)
	regions = survivor_regions(body, dom)
	pad_body(body, dom, regions)
	visor = add_visor(body, dom)
	dom = dominant_groups(body)
	regions = regions + [VISOR] * len(visor)
	write_region_attr(body, regions)
	stripe_uv(body, dom)
	accs = accessories(rig, body, dom)
	bake_body(body)
	triangulate(body)
	body.name = body.data.name = "char_survivor_body_lod0"
	assert tris(body) <= LOD_TRIS[0], tris(body)
	lods = [body] + [decimate_copy(body, "char_survivor_body_lod%d" % i, LOD_TRIS[i]) for i in (1, 2)]
	stripe_mask()
	export(os.path.join(OUT_SURV, "char_survivor_body.glb"), [rig] + lods + accs)
	report = {o.name: tris(o) for o in lods + accs}
	print("SURVIVOR_TRIS", report)
	return report


# --- shapeshifter true form ----------------------------------------------------------------------

TRUE_HEIGHT_M = 2.4
ARM_SCALE = (1.45, 1.5, 1.35)  # upper arm, forearm, hand+fingers (over-long arms, art bible §5)
TRUNK_X = 0.72


def arm_shift(ax):
	"""Extra distance along the T-pose arm (X) at |x| = ax in the source rig."""
	h_up, h_fore, h_hand = 0.192, 0.466, 0.739
	if ax <= h_up:
		return 0.0
	if ax <= h_fore:
		return (ax - h_up) * (ARM_SCALE[0] - 1)
	d1 = (h_fore - h_up) * (ARM_SCALE[0] - 1)
	if ax <= h_hand:
		return d1 + (ax - h_fore) * (ARM_SCALE[1] - 1)
	return d1 + (h_hand - h_fore) * (ARM_SCALE[1] - 1) + (ax - h_hand) * (ARM_SCALE[2] - 1)


## True-form options for the designer (review 2026-10-17: "the monster can be improved a lot"). Each keeps the art
## bible §5 limits (2.4 m, over-long arms, narrow trunk, wet near-black, bone-white focal points, no emissive eyes,
## same rig) and changes the silhouette: limb thinning (radius toward the bone, 1 = as shipped), the face pulled
## forward, and its bone parts (true_parts). "" is the shipped form.
TRUE_STYLES = {
	"": {"thin": 1.0, "snout": 1.0},
	"a": {"thin": 0.62, "snout": 1.0},  # ribcage: open bone cage, collarbones, long jaw teeth, spine knobs
	"b": {"thin": 0.55, "snout": 1.7},  # hunter: long skull with a bone cap, sickle claws, elbow spurs, spine spikes
	"c": {"thin": 0.7, "snout": 1.0},  # split maw: a vertical toothed slit down the face and a toothed chest maw
}
LIMBS = ("DEF-upper_arm", "DEF-forearm", "DEF-thigh", "DEF-shin")


def thin_limbs(me, dom, rig, f):
	"""Moves every limb vertex toward its bone's axis: radius * f (emaciated limbs, not a mannequin's)."""
	if f == 1.0:
		return
	for i, v in enumerate(me.vertices):
		if not dom[i].startswith(LIMBS) or dom[i] not in rig.data.bones:
			continue
		b = rig.data.bones[dom[i]]
		a, d = b.head_local, b.tail_local - b.head_local
		t = max(0.0, min(1.0, (v.co - a).dot(d) / d.length_squared))
		c = a + d * t
		v.co = c + (v.co - c) * f


def part(bm, bones, verts, bone):
	"""Bone material on the new primitive's faces, its vertices tagged for `bone`."""
	for fc in {f for v in verts for f in v.link_faces}:
		fc.material_index = 1
	bm.verts.index_update()
	bones.append(bone)
	claim(bm, len(bones))


def seg(bm, bones, a, b, r1, r2, bone, segs=6):
	"""A tapered bone-white rod from a (radius r1) to b (radius r2): ribs, claws, teeth, spikes."""
	a, b = Vector(a), Vector(b)
	d = b - a
	r = bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=d.length)
	bmesh.ops.rotate(bm, verts=r["verts"], cent=Vector(), matrix=d.normalized().to_track_quat("Z", "Y").to_matrix())
	bmesh.ops.translate(bm, vec=(a + b) / 2, verts=r["verts"])
	part(bm, bones, r["verts"], bone)


def spine_bone(z):
	return "DEF-spine.003" if z > 1.3 else ("DEF-spine.002" if z > 1.15 else "DEF-spine.001")


def true_parts(style, bm, bones, rig, me, dom, lo_h, hi_h):
	"""Bone parts of option `style` (TRUE_STYLES). Coordinates are the source rig's (m, -Y front, Z up).
	Returns the body's polygon indices to draw in bone (set after the material slots are reset)."""
	cap = []
	spine = [v.co for i, v in enumerate(me.vertices) if dom[i].startswith("DEF-spine.00")]
	front = min(c.y for c in spine)
	back = max(c.y for c in spine)
	fy = lo_h.y
	mid_z = (lo_h.z + hi_h.z) / 2

	def tips(length, r):
		for side in ("L", "R"):
			for f in ("f_index", "f_middle", "f_ring", "f_pinky", "thumb"):
				b = rig.data.bones["DEF-%s.03.%s" % (f, side)]
				d = (b.tail_local - b.head_local).normalized()
				seg(bm, bones, b.tail_local - d * 0.01, b.tail_local + d * length, r, 0.0, b.name)

	if style == "a":
		for k in range(8):  # an open cage: each rib round the side and back, the lowest ones shorter
			z = 1.47 - k * 0.042
			w = 0.15 - k * 0.006
			for s in (-1, 1):
				seg(bm, bones, (s * 0.02, front - 0.02, z), (s * w, front + 0.02, z - 0.02), 0.011, 0.008, spine_bone(z))
				seg(bm, bones, (s * w, front + 0.02, z - 0.02), (s * (w - 0.01), back - 0.03, z - 0.04), 0.008,
					0.006, spine_bone(z))
		seg(bm, bones, (0, front - 0.022, 1.50), (0, front - 0.018, 1.18), 0.014, 0.008, "DEF-spine.003")
		for s in (-1, 1):  # collarbones
			seg(bm, bones, (s * 0.03, front - 0.01, 1.53), (s * 0.21, front + 0.02, 1.57), 0.012, 0.01,
				"DEF-spine.003")
		for k in range(12):  # spine knobs
			z = 1.56 - k * 0.05
			seg(bm, bones, (0, back - 0.01, z), (0, back + 0.035, z - 0.01), 0.016, 0.004, spine_bone(z))
		for k in range(10):  # long teeth, upper and lower
			x = (k - 4.5) * 0.017
			y = fy + 0.008 + abs(x) * 0.7
			seg(bm, bones, (x, y - 0.006, mid_z + 0.01), (x, y - 0.016, mid_z - 0.075), 0.009, 0.0, "DEF-head", segs=5)
			seg(bm, bones, (x, y - 0.006, mid_z - 0.12), (x, y - 0.016, mid_z - 0.045), 0.008, 0.0, "DEF-head", segs=5)
		tips(0.1, 0.01)
	elif style == "b":
		cap = [poly.index for poly in me.polygons  # the bone cap over the long skull
			if dom[me.loops[poly.loop_start].vertex_index].startswith("DEF-head") and poly.center.z > mid_z + 0.02]
		for k in range(8):  # two tooth rows along the snout
			y = fy + 0.01 + k * 0.022
			for s in (-1, 1):
				x = s * (0.028 + k * 0.006)
				seg(bm, bones, (x, y, mid_z - 0.02), (x * 1.1, y, mid_z - 0.07), 0.006, 0.0, "DEF-head", segs=5)
		tips(0.22, 0.014)  # sickle claws
		for side, s in (("L", 1), ("R", -1)):
			b = rig.data.bones["DEF-forearm.%s" % side]  # elbow spurs, pointing back
			e = b.head_local
			seg(bm, bones, e, e + Vector((s * 0.02, 0.16, 0.03)), 0.02, 0.0, b.name)
			seg(bm, bones, (s * 0.17, back - 0.04, 1.50), (s * 0.24, back + 0.14, 1.62), 0.022, 0.0,
				"DEF-spine.003")  # shoulder spikes
		for k in range(10):  # spine spikes, longest between the shoulders
			z = 1.55 - k * 0.055
			ln = 0.16 - k * 0.012
			seg(bm, bones, (0, back - 0.01, z), (0, back + ln, z + ln * 0.5), 0.018, 0.0, spine_bone(z))
	elif style == "c":
		for k in range(9):  # the face split top to bottom, teeth on both lips pointing in
			z = lo_h.z + 0.02 + k * (hi_h.z - lo_h.z - 0.04) / 8
			for s in (-1, 1):
				seg(bm, bones, (s * 0.04, fy + 0.004, z), (s * 0.006, fy - 0.004, z - 0.006), 0.006, 0.0,
					"DEF-head", segs=5)
		for k in range(7):  # the chest maw: rib-teeth closing over the sternum
			z = 1.46 - k * 0.045
			for s in (-1, 1):
				seg(bm, bones, (s * 0.13, front + 0.01, z), (s * 0.012, front - 0.03, z - 0.02), 0.012, 0.0,
					spine_bone(z))
		for s in (-1, 1):  # bone plates over the shoulders
			r = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=1.0)
			for v in r["verts"]:
				v.co = Vector((v.co.x * 0.08 + s * 0.15, v.co.y * 0.08 + (front + back) / 2, v.co.z * 0.04 + 1.5))
			part(bm, bones, r["verts"], "DEF-spine.003")
		for k in range(8):
			z = 1.55 - k * 0.06
			seg(bm, bones, (0, back - 0.01, z), (0, back + 0.05, z), 0.014, 0.0, spine_bone(z))
		tips(0.13, 0.011)
	return cap


def build_true_form(style="", out=None):
	rig, body = load_source()
	# Animations keep only rotations below the hips, so the stretched rest lengths survive playback.
	for a in bpy.data.actions:
		for cb, fcs in channelbag_fcurves(a):
			for fc in fcs:
				if fc.data_path.endswith("location") and "DEF-hips" not in fc.data_path and '"root"' not in fc.data_path:
					cb.fcurves.remove(fc)
	build_anims.add_true_clips(rig)
	activate(body)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.mesh.remove_doubles(threshold=0.0001)
	bpy.ops.object.mode_set(mode="OBJECT")
	dom = dominant_groups(body)
	me = body.data
	opt = TRUE_STYLES[style]
	thin_limbs(me, dom, rig, opt["thin"])
	for i, v in enumerate(me.vertices):
		g = dom[i]
		if g.startswith(HEAD) and opt["snout"] != 1.0 and v.co.z > 1.6 and v.co.y < 0.0:
			v.co.y *= opt["snout"]  # the face (-Y) pulled forward into a long skull
		if g.startswith(ARM) or (g.startswith("DEF-shoulder") and abs(v.co.x) > 0.19):
			s = 1 if v.co.x > 0 else -1
			v.co.x += s * arm_shift(abs(v.co.x))
			if g.startswith(HAND):
				v.co.y *= 0.8
		elif g.startswith(("DEF-spine", "DEF-hips")):
			v.co.x *= TRUNK_X
			v.co.y = 0.01 + (v.co.y - 0.01) * 0.85
		elif g.startswith(HEAD):
			v.co.z = 1.57 + (v.co.z - 1.57) * 1.15
			v.co.y = -0.0 + v.co.y * 1.15
		elif g.startswith(("DEF-thigh", "DEF-shin")):
			v.co.x *= 0.9
	activate(rig)
	bpy.ops.object.mode_set(mode="EDIT")
	for eb in rig.data.edit_bones:
		for attr in ("head", "tail"):
			p = getattr(eb, attr).copy()
			if eb.name.startswith(ARM):
				s = 1 if p.x > 0 else -1
				p.x += s * arm_shift(abs(p.x))
			setattr(eb, attr, p)
	bpy.ops.object.mode_set(mode="OBJECT")

	lo_h, hi_h = group_bbox(body, dom, ("DEF-head",))
	bm = bmesh.new()
	bones = []
	cap = []
	if style:
		cap = true_parts(style, bm, bones, rig, me, dom, lo_h, hi_h)
	else:
		# Ribs: six bone-white arcs on the chest front (asymmetric: the left side has one more).
		front = min(v.co.y for i, v in enumerate(me.vertices) if dom[i].startswith("DEF-spine.00"))
		for k in range(6):
			z = 1.40 - k * 0.05
			for s in (-1, 1):
				if s < 0 and k == 5:
					continue
				bm_cyl(bm, (s * 0.05, front - 0.005, z), 0.008, 0.006, 0.11 - k * 0.006, segs=6, axis="X",
					tag=1, angle=s * 0.35)
				bones.append("DEF-spine.003" if z > 1.3 else "DEF-spine.002")
				claim(bm, len(bones))
		bm.verts.index_update()
		# Claws: a long cone past every finger tip and the thumb.
		def tip(name):
			b = rig.data.bones[name]
			return b.tail_local, (b.tail_local - b.head_local).normalized()
		from mathutils import Matrix
		for side in ("L", "R"):
			for f in ("f_index", "f_middle", "f_ring", "f_pinky", "thumb"):
				name = "DEF-%s.03.%s" % (f, side)
				p, d = tip(name)
				r = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.011, radius2=0.0, depth=0.09)
				q = d.to_track_quat("Z", "Y").to_matrix()
				bmesh.ops.rotate(bm, verts=r["verts"], cent=Vector(), matrix=q)
				bmesh.ops.translate(bm, vec=p + d * 0.04, verts=r["verts"])
				for fc in {f for v in r["verts"] for f in v.link_faces}:
					fc.material_index = 1
				bm.verts.index_update()
				bones.append(name)
				claim(bm, len(bones))
		# Teeth: a ring of downward cones across the lower face; spikes along the back, one shoulder only.
		fy = lo_h.y
		mz = lo_h.z + (hi_h.z - lo_h.z) * 0.3
		for k in range(9):
			x = (k - 4) * 0.018
			y = fy + 0.012 + abs(x) * 0.6
			r = bmesh.ops.create_cone(bm, cap_ends=True, segments=5, radius1=0.006, radius2=0.0, depth=0.035)
			bmesh.ops.rotate(bm, verts=r["verts"], cent=Vector(), matrix=Matrix.Rotation(math.pi, 3, "X"))
			bmesh.ops.translate(bm, vec=Vector((x, y, mz)), verts=r["verts"])
			for fc in {f for v in r["verts"] for f in v.link_faces}:
				fc.material_index = 1
			bm.verts.index_update()
			bones.append("DEF-head")
			claim(bm, len(bones))
		back = max(v.co.y for i, v in enumerate(me.vertices) if dom[i].startswith("DEF-spine.00"))
		for k, (x, z, ln) in enumerate([(0.0, 1.42, 0.10), (0.0, 1.30, 0.08), (0.0, 1.18, 0.07), (0.12, 1.45, 0.14),
				(0.16, 1.47, 0.11)]):
			r = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.016, radius2=0.0, depth=ln)
			bmesh.ops.rotate(bm, verts=r["verts"], cent=Vector(), matrix=Matrix.Rotation(-math.pi / 2 + 0.5, 3, "X"))
			bmesh.ops.translate(bm, vec=Vector((x, back + ln * 0.35, z)), verts=r["verts"])
			for fc in {f for v in r["verts"] for f in v.link_faces}:
				fc.material_index = 1
			bm.verts.index_update()
			bones.append("DEF-spine.003")
			claim(bm, len(bones))
	extra = new_mesh_obj("true_bones_tmp", bm)
	for name, idx in part_groups(extra, bones):
		g = extra.vertex_groups.get(name) or extra.vertex_groups.new(name=name)
		g.add(idx, 1.0, "REPLACE")

	skin = bpy.data.materials.new("mat_shapeshifter_skin")
	skin.use_nodes = True
	p = skin.node_tree.nodes["Principled BSDF"]
	p.inputs["Base Color"].default_value = (lin(46), lin(44), lin(48), 1)  # sRGB 40-55 (art bible §5)
	p.inputs["Roughness"].default_value = 0.35
	p.inputs["Coat Weight"].default_value = 1.0
	p.inputs["Coat Roughness"].default_value = 0.06
	bone = bpy.data.materials.new("mat_shapeshifter_bone")
	bone.use_nodes = True
	p = bone.node_tree.nodes["Principled BSDF"]
	p.inputs["Base Color"].default_value = (lin(212), lin(204), lin(186), 1)  # 190-220 (art bible §5)
	p.inputs["Roughness"].default_value = 0.5
	me.materials.clear()
	me.materials.append(skin)
	me.materials.append(bone)
	for poly in me.polygons:
		poly.material_index = 0
	for i in cap:
		me.polygons[i].material_index = 1
	extra.data.materials.append(skin)
	extra.data.materials.append(bone)
	for u in list(me.uv_layers)[1:]:
		me.uv_layers.remove(u)
	extra.data.uv_layers.new(name=me.uv_layers[0].name)
	activate(body)
	extra.select_set(True)
	bpy.ops.object.join()
	triangulate(body)
	body.name = body.data.name = "char_shapeshifter_true_lod0"
	assert tris(body) <= LOD_TRIS[0], tris(body)
	lods = [body] + [decimate_copy(body, "char_shapeshifter_true_lod%d" % i, LOD_TRIS[i]) for i in (1, 2)]
	# Height: the source rig stands 1.83 m; the whole rig scales to TRUE_HEIGHT_M (node scale, so the
	# hips' animated translation scales with it).
	h = max((rig.matrix_world @ v.co).z for v in me.vertices)
	rig.scale = (TRUE_HEIGHT_M / h,) * 3
	export(out or os.path.join(OUT_TRUE, "char_shapeshifter_true.glb"), [rig] + lods)
	report = {o.name: tris(o) for o in lods}
	print("TRUE_TRIS", report)
	return report


def main():
	if "--true-options" in sys.argv:  # review builds, nothing shipped: tools/art/review/true_<style>.glb
		fetch()
		print("DONE", {k: build_true_form(k, os.path.join(ROOT, "tools", "art", "review", "true_%s.glb" % k))
			for k in TRUE_STYLES if k})
		return
	check_accessory_palette()
	fetch()
	a = build_survivor()
	b = build_true_form()
	print("DONE", a, b)


if __name__ == "__main__":
	main()
