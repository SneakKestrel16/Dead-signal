"""Builds the interactable and hero props (ASSET-052..064, design/assets/specs/research-facility-assets.md) in Blender.

Re-runnable, no manual steps, no downloads (every prop is procedural from primitives):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
      --python tools/art/build_props.py

Writes assets/art/props/prop_*.glb (no embedded images) and one preview per prop to
production/qa/evidence/props/prop_*.png: near-dark, one warm-white spot standing in for the flashlight.

Conventions (MapGreybox places them, src/core/facility/map_greybox.gd):
  - origin on the floor under the marker point; front faces Blender +Y, which is Godot -Z, the way
    MapMarker.yaw_deg 0 faces;
  - material names are Godot material names. `steel` is remapped on import to the shared
    assets/art/materials/mat_steel_plate_a.tres (the .glb.import _subresources); the rest are flat
    StandardMaterial3D from the glb. Cyan #3FA9D6 only on objective props, exit green #4FD18B only on the exit
    (art bible §4/§6 hard rule; check_palette() below fails the build otherwise).
"""
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "art", "props")
EVIDENCE = os.path.join(ROOT, "production", "qa", "evidence", "props")
TILE = os.path.join(ROOT, "assets", "art", "environment", "tileable")

CYAN = "3FA9D6"
EXIT_GREEN = "4FD18B"

## name -> (albedo sRGB hex, roughness, metallic, emission strength). Emission uses the albedo colour.
## Albedo values follow art bible §4 (interactables 140-200, props 70-160, never below 32 or above 225).
MATS = {
	"steel": ("6E7476", 0.55, 0.6, 0.0),  # remapped to mat_steel_plate_a.tres on import; flat stand-in here
	"paint": ("A9A79E", 0.6, 0.15, 0.0),  # light utility paint for interactable bodies (~168)
	"dark": ("3C4042", 0.5, 0.6, 0.0),  # handles, vents, hoods, brackets
	"rubber": ("2C2E2E", 0.9, 0.0, 0.0),
	"cyan_lit": (CYAN, 0.4, 0.0, 3.0),  # objective: drive edge bar, fuse rings, terminal dock
	"cyan_dim": (CYAN, 0.4, 0.0, 0.6),  # fuse box indicator bar (the state-driven glow is not wired yet)
	"screen": ("3A4044", 0.2, 0.0, 0.35),  # terminal and CRT faces: dim neutral, never cyan or green
	"amber": ("D98A2B", 0.4, 0.0, 0.8),  # pilot lights (dim amber, §6)
	"red_led": ("B3342E", 0.4, 0.0, 0.6),
	"warning": ("B89A3E", 0.6, 0.1, 0.0),  # desaturated yellow warning plates (no text)
	"exit_paint": (EXIT_GREEN, 0.5, 0.0, 0.0),
	"exit_lit": (EXIT_GREEN, 0.3, 0.0, 4.0),
	"core_glow": ("E0D6BA", 0.3, 0.0, 8.0),  # Bone Flashlight warm white, value-clamped albedo
}
## Material -> props allowed to use it (§6: the objective colours stay on objectives).
RESERVED = {"cyan_lit": {"prop_data_drive", "prop_fuse", "prop_terminal"}, "cyan_dim": {"prop_fuse_box"},
	"exit_paint": {"prop_exit_door"}, "exit_lit": {"prop_exit_lamp"}}
## Triangle budgets (spec ASSET-052..064 and the brief: small <= 1.5k, hero <= 8k).
BUDGET = {"prop_data_drive": 800, "prop_fuse": 600, "prop_fuse_box": 1500, "prop_terminal": 8000,
	"prop_exit_door": 8000, "prop_exit_lamp": 300, "prop_hide_cabinet": 1500, "prop_hide_locker": 1500,
	"prop_light_switch": 300, "prop_camera": 800, "prop_monitor_wall": 8000, "prop_core": 8000,
	"prop_breaker_wall": 8000}


def lin(hexs):
	c = [int(hexs[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
	return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


def material(name):
	m = bpy.data.materials.get(name)
	if m:
		return m
	hexs, rough, metal, emit = MATS[name]
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	p = m.node_tree.nodes["Principled BSDF"]
	p.inputs["Base Color"].default_value = lin(hexs)
	p.inputs["Roughness"].default_value = rough
	p.inputs["Metallic"].default_value = metal
	if emit > 0:
		p.inputs["Emission Color"].default_value = lin(hexs)
		p.inputs["Emission Strength"].default_value = emit
	return m


def _finish(o, mat, bevel):
	o.data.materials.append(material(mat))
	if bevel > 0:
		b = o.modifiers.new("bevel", "BEVEL")
		b.width = bevel
		b.segments = 1
		b.limit_method = "ANGLE"
	return o


def box(parts, size, loc, mat, bevel=0.0, rot=(0, 0, 0)):
	"""Box of `size` (x, y, z) centred at `loc`."""
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
	o = bpy.context.active_object
	o.scale = size
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	parts.append(_finish(o, mat, bevel))
	return o


def cyl(parts, r, depth, loc, mat, verts=12, rot=(0, 0, 0), bevel=0.0):
	"""Cylinder along local Z (rotate with `rot`)."""
	bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
	o = bpy.context.active_object
	parts.append(_finish(o, mat, bevel))
	return o


def prism(parts, pts, depth, y, mat):
	"""Flat outline `pts` [(x, z)] in the XZ plane, extruded `depth` along +Y from y."""
	me = bpy.data.meshes.new("prism")
	bm = bmesh.new()
	vs = [bm.verts.new((x, y, z)) for x, z in pts]
	f = bm.faces.new(vs)
	r = bmesh.ops.extrude_face_region(bm, geom=[f])
	for v in r["geom"]:
		if isinstance(v, bmesh.types.BMVert):
			v.co.y += depth
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new("prism", me)
	bpy.context.collection.objects.link(o)
	parts.append(_finish(o, mat, 0.0))
	return o


def chevron(parts, cx, cz, w, h, t, y, depth, mat, down=True):
	"""A V (down=True) or ^ chevron of width w, height h, stroke t, centred at (cx, cz)."""
	s = 1 if down else -1  # the tip sits at cz - s * h / 2
	hw, hh = w / 2, h / 2
	pts = [(cx - hw, cz + s * hh), (cx - hw + t, cz + s * hh), (cx, cz - s * hh + s * t * 1.4),
		(cx + hw - t, cz + s * hh), (cx + hw, cz + s * hh), (cx, cz - s * hh)]
	return prism(parts, pts, depth, y, mat)


def join(name, parts):
	bpy.ops.object.select_all(action="DESELECT")
	for o in parts:
		bpy.context.view_layer.objects.active = o
		for m in list(o.modifiers):
			bpy.ops.object.modifier_apply(modifier=m.name)
	for o in parts:
		o.select_set(True)
	bpy.context.view_layer.objects.active = parts[0]
	bpy.ops.object.join()
	o = bpy.context.active_object
	o.name = name
	o.data.name = name
	bpy.ops.object.shade_flat()
	return o


def tris(o):
	return sum(len(p.vertices) - 2 for p in o.data.polygons)


def check_palette(name, o):
	for m in o.data.materials:
		allowed = RESERVED.get(m.name)
		assert allowed is None or name in allowed, "%s uses reserved %s" % (name, m.name)


# --- props (front = +Y, origin on the floor) ------------------------------------------------------------

def data_drive():
	"""Flat slab with a lit cyan edge bar along its front (ASSET-054)."""
	p = []
	box(p, (0.26, 0.16, 0.035), (0, 0, 0.0175), "paint", 0.006)
	box(p, (0.22, 0.012, 0.014), (0, 0.083, 0.0175), "cyan_lit")
	box(p, (0.012, 0.13, 0.014), (-0.133, 0, 0.0175), "cyan_lit")
	for x in (-0.06, 0.0, 0.06):  # grip ribs on top
		box(p, (0.03, 0.12, 0.006), (x, -0.005, 0.038), "rubber")
	box(p, (0.05, 0.02, 0.016), (0.09, -0.085, 0.0175), "dark")  # connector
	return p


def fuse():
	"""Upright cylinder with two cyan rings (ASSET-056)."""
	p = []
	cyl(p, 0.045, 0.24, (0, 0, 0.12 + 0.03), "paint", 16)
	for z in (0.03, 0.27):  # end caps
		cyl(p, 0.05, 0.03, (0, 0, z), "dark", 16, bevel=0.005)
	for z in (0.11, 0.19):
		cyl(p, 0.054, 0.022, (0, 0, z), "cyan_lit", 16)
	cyl(p, 0.012, 0.03, (0, 0, 0.3), "dark", 8)  # contact pin
	return p


def fuse_box():
	"""Tall thin panel on feet with a vertical indicator bar and the fuse socket (ASSET-057)."""
	p = []
	box(p, (0.7, 0.26, 1.8), (0, 0, 0.1 + 0.9), "paint", 0.02)
	for x in (-0.28, 0.28):
		box(p, (0.08, 0.22, 0.1), (x, 0, 0.05), "dark")
	box(p, (0.62, 0.02, 1.0), (0.04, 0.135, 1.05), "paint", 0.008)  # door
	box(p, (0.07, 0.03, 1.3), (-0.27, 0.14, 1.05), "cyan_dim")  # the indicator bar
	cyl(p, 0.075, 0.05, (0.12, 0.155, 1.25), "dark", 16, rot=(math.pi / 2, 0, 0))  # socket collar
	cyl(p, 0.052, 0.052, (0.12, 0.165, 1.25), "rubber", 16, rot=(math.pi / 2, 0, 0))
	box(p, (0.03, 0.04, 0.16), (0.3, 0.155, 0.9), "dark")  # latch
	box(p, (0.74, 0.3, 0.06), (0, 0, 1.93), "dark", 0.01)  # cap
	for z in (0.35, 0.45, 0.55):  # vent slits
		box(p, (0.4, 0.01, 0.025), (0.04, 0.146, z), "dark")
	return p


def terminal():
	"""Hero: wide screen under a top hood, a console with drive dock slots (ASSET-058)."""
	p = []
	box(p, (1.5, 0.55, 0.85), (0, -0.05, 0.425), "paint", 0.02)  # pedestal
	box(p, (1.6, 0.06, 0.08), (0, 0.24, 0.04), "rubber")  # kick plate
	box(p, (1.56, 0.62, 0.06), (0, 0.0, 0.88), "dark", 0.01)  # console top
	for i, x in enumerate((-0.4, 0.0, 0.4)):  # three drive dock slots, cyan framed
		box(p, (0.3, 0.2, 0.03), (x, 0.12, 0.92), "cyan_lit", 0.004)
		box(p, (0.27, 0.05, 0.04), (x, 0.12, 0.925), "rubber")
	for x in (-0.68, 0.68):  # side cheeks carrying the hood
		box(p, (0.08, 0.5, 1.15), (x, -0.12, 1.45), "paint", 0.015)
	box(p, (1.3, 0.12, 0.72), (0, -0.2, 1.36), "dark", 0.015)  # screen housing
	box(p, (1.2, 0.02, 0.6), (0, -0.135, 1.36), "screen")  # the wide screen
	box(p, (1.6, 0.66, 0.06), (0, -0.04, 2.04), "paint", 0.02, rot=(math.radians(-8), 0, 0))  # hood
	box(p, (1.6, 0.05, 0.14), (0, 0.28, 1.97), "dark", 0.01)  # hood lip
	box(p, (1.36, 0.16, 0.08), (0, -0.2, 0.96), "dark")  # screen foot
	for x in (-0.55, 0.55):  # cable conduits behind
		cyl(p, 0.035, 2.0, (x, -0.34, 1.0), "dark", 8)
	for i in range(6):  # keypad
		box(p, (0.05, 0.04, 0.015), (0.58 + (i % 2) * 0.07 - 0.04, 0.05 + (i // 2) * 0.06, 0.915), "rubber")
	return p


def exit_door():
	"""Hero: the chevron frame around the exit opening (ASSET-059). Opening 4 m wide (along X here), 2 m high;
	the door leaf is the level scene's (BUG-0018). Fits under the 3 m ceiling."""
	p = []
	ow, oh, d = 4.0, 2.0, 0.4
	for s in (-1, 1):
		x = s * (ow / 2 + 0.17)
		box(p, (0.34, d, oh + 0.45), (x, 0, (oh + 0.45) / 2), "dark", 0.02)  # jamb
		for i in range(5):  # chevron stripes up each jamb, pointing up
			chevron(p, x, 0.3 + i * 0.42, 0.26, 0.16, 0.06, d / 2, 0.012, "exit_paint", down=False)
	box(p, (ow + 0.68, d, 0.45), (0, 0, oh + 0.225), "dark", 0.02)  # lintel
	for i in range(5):  # chevrons across the lintel, pointing down at the door
		chevron(p, -1.2 + i * 0.6, oh + 0.225, 0.36, 0.22, 0.07, d / 2, 0.012, "exit_paint", down=True)
	box(p, (ow + 0.5, d * 0.6, 0.06), (0, 0, 0.03), "rubber")  # threshold
	box(p, (0.5, 0.18, 0.22), (0, 0.06, oh + 0.62), "dark", 0.01)  # lamp housing (lens: prop_exit_lamp)
	box(p, (0.08, 0.1, 0.2), (0, -0.02, oh + 0.45 + 0.08), "dark")  # lamp bracket
	return p


def exit_lamp():
	"""The Exit Green lens of the exit fixture, shown only while the exit is open (DoorBlockers)."""
	p = []
	box(p, (0.42, 0.04, 0.14), (0, 0.17, 2.62), "exit_lit", 0.01)
	return p


def hide_cabinet():
	"""Tall steel lab cabinet, double doors with peep vent slits (ASSET-052)."""
	p = []
	box(p, (0.95, 0.5, 1.85), (0, 0, 0.05 + 0.925), "steel", 0.015)
	box(p, (0.9, 0.46, 0.05), (0, 0, 0.025), "dark")  # plinth
	for s in (-1, 1):
		box(p, (0.455, 0.02, 1.75), (s * 0.235, 0.255, 0.98), "steel", 0.006)  # door
		box(p, (0.02, 0.04, 0.22), (s * 0.03, 0.28, 1.05), "dark")  # handle
		for z in (1.5, 1.56, 1.62, 1.68):  # vent slits at eye height
			box(p, (0.3, 0.012, 0.02), (s * 0.235, 0.266, z), "dark")
	box(p, (1.0, 0.54, 0.04), (0, 0, 1.92), "dark", 0.008)  # top lip
	return p


def hide_locker():
	"""Full-height single storage locker, louvres top and bottom, hasp (ASSET-053)."""
	p = []
	box(p, (0.62, 0.52, 1.95), (0, 0, 0.08 + 0.975), "steel", 0.012)
	box(p, (0.58, 0.48, 0.08), (0, 0, 0.04), "dark")  # base
	box(p, (0.56, 0.02, 1.86), (0, 0.265, 1.05), "steel", 0.006)  # door
	for z in list(range(6)):
		zz = 1.55 + z * 0.05
		box(p, (0.36, 0.03, 0.018), (0, 0.28, zz), "dark", rot=(math.radians(30), 0, 0))
		box(p, (0.36, 0.03, 0.018), (0, 0.28, 0.25 + z * 0.05), "dark", rot=(math.radians(30), 0, 0))
	box(p, (0.04, 0.05, 0.3), (0.22, 0.29, 1.05), "dark")  # handle
	box(p, (0.06, 0.03, 0.08), (0.22, 0.3, 0.86), "dark")  # hasp
	box(p, (0.14, 0.012, 0.06), (0, 0.276, 1.35), "warning")  # blank number plate
	return p


def light_switch():
	"""Chunky lever in a box on a stand, with a dim amber pilot light (ASSET-063)."""
	p = []
	box(p, (0.3, 0.3, 0.03), (0, 0, 0.015), "dark")  # foot plate
	cyl(p, 0.035, 1.05, (0, 0, 0.55), "dark", 8)  # stand
	box(p, (0.3, 0.18, 0.38), (0, 0, 1.25), "paint")  # box
	box(p, (0.06, 0.06, 0.22), (0.05, 0.12, 1.25), "dark", rot=(math.radians(-25), 0, 0))  # lever
	box(p, (0.16, 0.07, 0.07), (0.05, 0.16, 1.36), "rubber")  # handle
	cyl(p, 0.025, 0.03, (-0.09, 0.1, 1.38), "amber", 6, rot=(math.pi / 2, 0, 0))  # pilot light
	return p


def camera():
	"""Ceiling camera (ASSET-064): origin at the housing pivot, the bracket rising 0.3 m to the ceiling."""
	p = []
	box(p, (0.16, 0.16, 0.02), (0, 0, 0.29), "dark")  # ceiling plate
	cyl(p, 0.02, 0.28, (0, 0, 0.15), "dark", 6)  # drop rod
	box(p, (0.13, 0.32, 0.13), (0, 0.04, 0), "paint", 0.01)  # housing
	box(p, (0.16, 0.36, 0.015), (0, 0.06, 0.075), "dark")  # sun hood
	cyl(p, 0.04, 0.03, (0, 0.21, 0), "dark", 10, rot=(math.pi / 2, 0, 0))  # lens ring
	cyl(p, 0.03, 0.01, (0, 0.225, 0), "screen", 10, rot=(math.pi / 2, 0, 0))  # glass
	cyl(p, 0.008, 0.01, (0.045, 0.2, 0.045), "red_led", 6, rot=(math.pi / 2, 0, 0))
	return p


def monitor_wall():
	"""Hero: C1 bank of CRTs around the live feed and a console (ASSET-061). The live feed is SurveillanceFeed's
	1.2 x 0.9 m screen 1.5 m above the marker facing the room (surveillance_feed.gd): this leaves its frame
	open just behind that plane (y < 0)."""
	p = []
	box(p, (3.3, 0.5, 1.75), (0, -0.3, 0.9 + 0.875), "dark", 0.02)  # wall bank carcass
	box(p, (1.36, 0.04, 1.06), (0, -0.05, 1.5), "rubber", 0.01)  # feed bezel backing
	for x, z in ((-1.05, 1.2), (-1.05, 1.75), (1.05, 1.2), (1.05, 1.75), (-0.6, 2.35), (0.0, 2.35), (0.6, 2.35),
			(-1.35, 2.35), (1.35, 2.35)):
		w = 0.55 if abs(x) > 1 else 0.5
		box(p, (w, 0.12, 0.44), (x, -0.08, z), "paint", 0.02)  # CRT bezel
		box(p, (w - 0.1, 0.02, 0.34), (x, -0.015, z), "screen")  # dim static face
	box(p, (2.8, 0.75, 0.06), (0, 0.5, 0.75), "paint", 0.01)  # desk top
	box(p, (2.7, 0.65, 0.7), (0, 0.45, 0.36), "dark", 0.01)  # desk body
	box(p, (2.4, 0.3, 0.12), (0, 0.32, 0.84), "dark", 0.01, rot=(math.radians(15), 0, 0))  # sloped control strip
	for i in range(8):  # switches on the strip
		box(p, (0.08, 0.05, 0.03), (-0.9 + i * 0.26, 0.34, 0.91), "rubber")
	box(p, (0.5, 0.18, 0.03), (0.6, 0.62, 0.795), "rubber")  # keyboard
	return p


def core():
	"""Hero: The Core (ASSET-060), B1's double-height light column filling the 2.5 x 6 x 2.5 m LOS blocker."""
	p = []
	box(p, (2.5, 2.5, 0.4), (0, 0, 0.2), "dark", 0.03)  # plinth
	box(p, (2.3, 2.3, 0.35), (0, 0, 5.825), "dark", 0.03)  # crown
	cyl(p, 0.75, 5.3, (0, 0, 3.05), "core_glow", 24)  # the light column
	for x in (-1.0, 1.0):
		for y in (-1.0, 1.0):
			box(p, (0.22, 0.22, 5.3), (x, y, 3.05), "paint", 0.02)  # corner posts
	for z in (1.4, 2.7, 4.0, 5.2):  # bands, broken so the glow reads through
		for r in range(4):
			a = r * math.pi / 2
			box(p, (2.0, 0.1, 0.14), (math.cos(a) * 1.0, math.sin(a) * 1.0, z), "dark", rot=(0, 0, a + math.pi / 2))
	for r in range(8):  # cable runs up the column (§3 organic exception)
		a = r * math.pi / 4 + math.pi / 8
		cyl(p, 0.05, 5.2, (math.cos(a) * 0.86, math.sin(a) * 0.86, 3.0), "rubber", 6)
	return p


def breaker_wall():
	"""Hero: B2 breaker wall (ASSET-055) filling the 5 x 2.5 x 0.4 m LOS blocker; front faces +Y."""
	p = []
	box(p, (5.0, 0.4, 2.5), (0, 0, 1.25), "steel", 0.02)
	for c in range(8):
		for r in range(3):
			x, z = -2.1 + c * 0.6, 0.75 + r * 0.6
			box(p, (0.5, 0.06, 0.5), (x, 0.22, z), "paint", 0.01)  # breaker
			box(p, (0.06, 0.05, 0.14), (x, 0.27, z + 0.04), "dark")  # handle
			box(p, (0.03, 0.02, 0.03), (x + 0.17, 0.255, z + 0.17), "amber")  # pilot light
	for x in (-1.8, 0.0, 1.8):
		box(p, (0.6, 0.02, 0.18), (x, 0.205, 2.35), "warning")  # warning plates
	box(p, (5.1, 0.5, 0.1), (0, 0, 2.55), "dark")  # cable tray
	for i in range(6):
		cyl(p, 0.04, 0.6, (-2.0 + i * 0.8, 0.12, 2.85), "rubber", 6)  # conduits to the ceiling
	return p


PROPS = {"prop_data_drive": data_drive, "prop_fuse": fuse, "prop_fuse_box": fuse_box, "prop_terminal": terminal,
	"prop_exit_door": exit_door, "prop_exit_lamp": exit_lamp, "prop_hide_cabinet": hide_cabinet,
	"prop_hide_locker": hide_locker, "prop_light_switch": light_switch, "prop_camera": camera,
	"prop_monitor_wall": monitor_wall, "prop_core": core, "prop_breaker_wall": breaker_wall}


def clear():
	for o in list(bpy.data.objects):
		bpy.data.objects.remove(o, do_unlink=True)


def export(o, path):
	bpy.ops.object.select_all(action="DESELECT")
	o.select_set(True)
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
		export_image_format="NONE", export_materials="EXPORT", export_animations=False)


def preview_materials():
	"""Steel gets its tileable box-projected for the preview only (export already done, images never shipped)."""
	m = bpy.data.materials["steel"]
	nt = m.node_tree
	tex = nt.nodes.new("ShaderNodeTexImage")
	tex.image = bpy.data.images.load(os.path.join(TILE, "tex_steel_plate_a_albedo_1024.png"))
	tex.projection = "BOX"
	tex.projection_blend = 0.2
	coord = nt.nodes.new("ShaderNodeTexCoord")
	mapping = nt.nodes.new("ShaderNodeMapping")
	mapping.inputs["Scale"].default_value = (0.25, 0.25, 0.25)
	nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
	nt.links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
	nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])


def render(name, o, extra=None):
	sc = bpy.context.scene
	sc.render.engine = "CYCLES"
	sc.cycles.samples = 48
	sc.cycles.use_denoising = True
	sc.render.resolution_x = sc.render.resolution_y = 640
	sc.view_settings.view_transform = "Standard"
	world = sc.world or bpy.data.worlds.new("w")
	sc.world = world
	world.use_nodes = True
	world.node_tree.nodes["Background"].inputs["Color"].default_value = lin("14181A")
	world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.15
	bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
	floor = bpy.context.active_object
	fm = bpy.data.materials.get("preview_floor") or bpy.data.materials.new("preview_floor")
	fm.use_nodes = True
	fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin("4A4D4C")
	floor.data.materials.append(fm)
	lo, hi = [Vector(o.bound_box[0]), Vector(o.bound_box[6])]
	for e in extra or []:
		lo = Vector(map(min, lo, Vector(e.bound_box[0]) + e.location))
		hi = Vector(map(max, hi, Vector(e.bound_box[6]) + e.location))
	centre = (lo + hi) / 2 + o.location
	size = max((hi - lo).length, 0.3)
	# Eye at 1.6 m where the prop allows, from the front-right, the flashlight held at the eye.
	eye = centre + Vector((0.55, 1.6, 0.45)).normalized() * size * 1.5
	eye.z = max(eye.z, min(1.6, centre.z + size))
	bpy.ops.object.camera_add(location=eye)
	cam = bpy.context.active_object
	cam.rotation_euler = (centre - eye).to_track_quat("-Z", "Y").to_euler()
	cam.data.lens = 40
	sc.camera = cam
	bpy.ops.object.light_add(type="SPOT", location=eye + Vector((0.15, 0, -0.2)))
	spot = bpy.context.active_object
	spot.data.color = lin("F2E6C8")[:3]
	spot.data.energy = 60 * max(1.0, size) ** 2
	spot.data.spot_size = math.radians(40)
	spot.data.spot_blend = 0.4
	spot.rotation_euler = (centre - spot.location).to_track_quat("-Z", "Y").to_euler()
	sc.render.filepath = os.path.join(EVIDENCE, name + ".png")
	bpy.ops.render.render(write_still=True)
	for x in (floor, cam, spot):
		bpy.data.objects.remove(x, do_unlink=True)


def main():
	os.makedirs(OUT, exist_ok=True)
	os.makedirs(EVIDENCE, exist_ok=True)
	built = {}
	for name, fn in PROPS.items():
		clear()
		o = join(name, fn())
		n = tris(o)
		assert n <= BUDGET[name], "%s: %d tris over %d" % (name, n, BUDGET[name])
		check_palette(name, o)
		export(o, os.path.join(OUT, name + ".glb"))
		built[name] = n
		print("PROP %s %d tris" % (name, n))
	preview_materials()
	for name, fn in PROPS.items():
		if name == "prop_exit_lamp":
			continue
		clear()
		o = join(name, fn())
		extra = []
		if name == "prop_exit_door":
			extra.append(join("prop_exit_lamp", exit_lamp()))
		if name == "prop_camera":
			o.location.z = 2.2
		render(name, o, extra)
	print("BUILT", built)


main()
