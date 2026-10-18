"""Builds the dressing sets and light fixture meshes (ASSET-067..076, design/assets/specs/research-facility-assets.md).

Re-runnable, no manual steps, no downloads (every mesh is procedural from primitives; helpers from build_props.py):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
      --python tools/art/build_dressing.py

Writes assets/art/props/dressing/prop_*.glb and one near-dark preview per item (one warm-white spot standing in
for the flashlight) to production/qa/evidence/dressing/. MapDressing places them from data/art/dressing_layout.tres.

Conventions as build_props.py: origin on the floor (fixtures: on the ceiling, hanging down -Z), front Blender +Y
(Godot -Z). `steel` and `rack` are remapped on import to the shared mat_steel_plate_a / mat_server_rack_a
(.glb.import _subresources); the rest are flat StandardMaterial3D. No cyan #3FA9D6 or exit green #4FD18B (§6
hard rule: check_palette fails the build); decor emissives dim amber or faint red only.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_props as bp  # noqa: E402  (main() is guarded)

OUT = os.path.join(bp.ROOT, "assets", "art", "props", "dressing")
bp.EVIDENCE = os.path.join(bp.ROOT, "production", "qa", "evidence", "dressing")

bp.MATS.update({
	"rack": ("4A4E50", 0.5, 0.5, 0.0),  # remapped to mat_server_rack_a.tres (dim amber LED dots in the albedo)
	"epoxy": ("3A3D3C", 0.35, 0.0, 0.0),  # lab bench top
	"laminate": ("8C8270", 0.6, 0.0, 0.0),  # desk top
	"fridge": ("BEBDB4", 0.45, 0.1, 0.0),  # specimen fridge enamel (190, under the 225 cap)
	"glass_dark": ("2A3032", 0.15, 0.0, 0.0),
	"screen_dead": ("33383A", 0.2, 0.0, 0.0),  # dead monitors: no emission
	"log_amber": ("D98A2B", 0.4, 0.0, 0.5),  # security log screen text lines, dim amber (§6)
	"binder_red": ("7A3A30", 0.7, 0.0, 0.0),
	"binder_olive": ("6A6A3E", 0.7, 0.0, 0.0),
	"binder_grey": ("5A6268", 0.7, 0.0, 0.0),
	"card": ("8A7458", 0.85, 0.0, 0.0),  # file boxes
	"fabric": ("4A4644", 0.9, 0.0, 0.0),  # chair seat
	"cable": ("2E3032", 0.7, 0.0, 0.0),
	"cable_amber": ("8A5A2A", 0.7, 0.0, 0.0),
	"pipe": ("6A6E66", 0.5, 0.4, 0.0),
	"lens_off": ("B8BAB2", 0.3, 0.0, 0.0),  # unlit diffusers: the lights are the presenter's, not emissive meshes
	"lens_amber": ("B07028", 0.3, 0.0, 0.0),
	"lens_red": ("8E2C28", 0.3, 0.0, 0.0),
	"strip_red": ("B3342E", 0.4, 0.0, 0.6),  # emergency strip: faint, always on (ASSET-073)
	"extinguisher": ("8A2E28", 0.45, 0.1, 0.0),  # muted, under Security Red's saturation (§4)
	"cork": ("8A6A48", 0.9, 0.0, 0.0),
	"paper": ("C8C2B2", 0.85, 0.0, 0.0),  # 200, under the 225 cap
	"wood": ("7A6448", 0.8, 0.0, 0.0),  # crate slats
	"drum_blue": ("3E5266", 0.5, 0.4, 0.0),  # desaturated: never Signal Cyan
	"drum_rust": ("6A4A34", 0.7, 0.3, 0.0),
	"cardboard": ("8E7656", 0.9, 0.0, 0.0),
})
bp.BUDGET.clear()
TRI_MAX = 1500  # every dressing item (spec ASSET-067..069); fixtures 300 (ASSET-070)
FIXTURE_MAX = 300
FORBIDDEN = {bp.CYAN, bp.EXIT_GREEN}


def box(p, size, loc, mat, bevel=0.0, rot=(0, 0, 0)):
	return bp.box(p, size, loc, mat, bevel, rot)


def cyl(p, r, depth, loc, mat, verts=12, rot=(0, 0, 0), bevel=0.0):
	return bp.cyl(p, r, depth, loc, mat, verts, rot, bevel)


# --- ASSET-067 lab ---------------------------------------------------------------------------------------

def lab_bench():
	"""2 m lab bench, 0.92 m (under the 1.0 m near-door cap): epoxy top over a steel cupboard base."""
	p = []
	box(p, (2.0, 0.75, 0.04), (0, 0, 0.9), "epoxy", 0.008)
	box(p, (1.94, 0.62, 0.8), (0, -0.04, 0.48), "steel", 0.01)
	box(p, (1.94, 0.58, 0.08), (0, -0.06, 0.04), "rubber")  # kick plate, set back
	for i in range(4):  # cupboard doors and handles on the front
		x = -0.72 + i * 0.48
		box(p, (0.44, 0.015, 0.7), (x, 0.28, 0.48), "steel", 0.004)
		box(p, (0.1, 0.02, 0.015), (x, 0.295, 0.78), "dark")
	box(p, (0.3, 0.2, 0.06), (0.7, -0.2, 0.95), "dark", 0.01)  # gas tap block, top under 1.0 m
	return p


def lab_desk():
	"""Abandoned 1.4 m desk on a drawer pedestal."""
	p = []
	box(p, (1.4, 0.7, 0.035), (0, 0, 0.73), "laminate", 0.006)
	box(p, (0.42, 0.62, 0.7), (0.47, 0, 0.36), "steel", 0.008)
	for z in (0.2, 0.42, 0.62):  # drawers, the middle one left open
		dy = 0.12 if z == 0.42 else 0.0
		box(p, (0.38, 0.015, 0.18), (0.47, 0.31 + dy, z), "steel", 0.003)
		box(p, (0.12, 0.02, 0.02), (0.47, 0.325 + dy, z + 0.04), "dark")
	for x in (-0.66,):
		for y in (-0.3, 0.3):
			box(p, (0.04, 0.04, 0.71), (x, y, 0.355), "dark")
	box(p, (0.04, 0.6, 0.04), (-0.66, 0, 0.12), "dark")
	box(p, (1.1, 0.02, 0.3), (-0.1, -0.33, 0.55), "steel")  # modesty panel
	return p


def lab_chair():
	"""Office chair: five-star base, gas column, seat and back."""
	p = []
	for i in range(5):
		a = i * 2 * math.pi / 5
		box(p, (0.3, 0.05, 0.04), (0.15 * math.cos(a), 0.15 * math.sin(a), 0.07), "dark", rot=(0, 0, a))
		cyl(p, 0.03, 0.04, (0.29 * math.cos(a), 0.29 * math.sin(a), 0.03), "rubber", 6, rot=(math.pi / 2, 0, a))
	cyl(p, 0.03, 0.36, (0, 0, 0.27), "dark", 8)
	box(p, (0.48, 0.46, 0.08), (0, 0, 0.47), "fabric", 0.02)
	box(p, (0.04, 0.06, 0.3), (0, -0.25, 0.58), "dark")
	box(p, (0.44, 0.06, 0.34), (0, -0.27, 0.79), "fabric", 0.02, rot=(math.radians(-8), 0, 0))  # top under 1.0 m
	return p


def lab_fridge():
	"""Sealed specimen fridge: white enamel, dark glass door, compressor grille on top, taped X seal. Wider and
	shorter than the hiding cabinet and locker (no vent slits, no step), so it does not read as a hide."""
	p = []
	box(p, (0.8, 0.7, 1.6), (0, 0, 0.8 + 0.06), "fridge", 0.02)
	box(p, (0.8, 0.66, 0.06), (0, 0, 0.03), "dark")  # plinth
	box(p, (0.6, 0.02, 1.0), (0, 0.355, 0.95), "glass_dark")
	box(p, (0.04, 0.05, 0.6), (0.33, 0.37, 0.95), "dark")  # handle
	box(p, (0.8, 0.5, 0.16), (0, -0.05, 1.74), "dark", 0.01)  # compressor housing
	for x in (-0.25, -0.12, 0.0, 0.12, 0.25):
		box(p, (0.03, 0.02, 0.1), (x, 0.205, 1.74), "rubber")
	for s in (1, -1):  # the X of seal tape over the door
		box(p, (0.06, 0.01, 1.25), (0, 0.375, 0.95), "warning", rot=(0, s * math.radians(28), 0))
	box(p, (0.82, 0.02, 0.08), (0, 0.36, 1.48), "warning")  # hazard band
	return p


def lab_monitor():
	"""Dead CRT monitor with a short neck: a deep box, not a wide hooded screen (§3 terminal silhouette)."""
	p = []
	box(p, (0.42, 0.38, 0.34), (0, -0.04, 0.24), "paint", 0.02)
	box(p, (0.3, 0.2, 0.26), (0, -0.28, 0.24), "paint", 0.02)  # tube back
	box(p, (0.33, 0.02, 0.25), (0, 0.155, 0.25), "screen_dead", 0.01)
	box(p, (0.22, 0.2, 0.05), (0, 0, 0.025), "dark")
	box(p, (0.08, 0.08, 0.05), (0, 0, 0.07), "dark")
	return p


def lab_binders():
	"""Three binders leaning in a row."""
	p = []
	for i, m in enumerate(("binder_red", "binder_olive", "binder_grey")):
		box(p, (0.06, 0.28, 0.31), (-0.08 + i * 0.07, 0, 0.155), m, 0.004, rot=(0, math.radians(6 * i), 0))
	return p


# --- ASSET-068 server, power, cooling --------------------------------------------------------------------

def _rack(p, x, w):
	box(p, (w - 0.02, 1.0, 2.2), (x, 0, 1.1), "rack", 0.01)
	box(p, (w - 0.08, 0.02, 1.9), (x, 0.505, 1.1), "rack")  # face panel (LED dots from the rack tileable)
	box(p, (w, 1.0, 0.06), (x, 0, 2.17), "dark")
	box(p, (w, 0.96, 0.08), (x, 0, 0.04), "dark")
	box(p, (0.03, 0.04, 0.4), (x + w / 2 - 0.07, 0.52, 1.2), "dark")  # handle


def server_rack():
	p = []
	_rack(p, 0, 0.6)
	return p


def _rack_row(length, n):
	def build():
		p = []
		w = length / n
		for i in range(n):
			_rack(p, -length / 2 + w * (i + 0.5), w)
		return p
	return build


def server_cable_bundle():
	"""Floor cable bundle: five loose curves (the §3 organic-curve exception), 2.4 m, under 0.15 m high."""
	p = []
	for i in range(5):
		cu = bpy.data.curves.new("cable", "CURVE")
		cu.dimensions = "3D"
		cu.bevel_depth = 0.018 + 0.006 * (i % 2)
		cu.bevel_resolution = 1
		cu.resolution_u = 3
		sp = cu.splines.new("BEZIER")
		sp.bezier_points.add(3)
		for k, bpnt in enumerate(sp.bezier_points):
			x = -1.2 + k * 0.8
			y = -0.12 + i * 0.06 + 0.07 * math.sin(k * 1.7 + i)
			bpnt.co = (x, y, 0.03 + 0.03 * ((i + k) % 2))
			bpnt.handle_left_type = bpnt.handle_right_type = "AUTO"
		o = bpy.data.objects.new("cable", cu)
		bpy.context.collection.objects.link(o)
		bpy.context.view_layer.objects.active = o
		bpy.ops.object.select_all(action="DESELECT")
		o.select_set(True)
		bpy.ops.object.convert(target="MESH")
		o = bpy.context.active_object
		o.data.materials.clear()
		p.append(bp._finish(o, "cable_amber" if i == 2 else "cable", 0.0))
	return p


def cooling_pipes():
	"""Wall-mounted pipe run, 3 m: three pipes at 2.2-2.6 m on brackets, back on the wall (origin at the wall foot)."""
	p = []
	for k, (z, r) in enumerate(((2.25, 0.07), (2.45, 0.05), (2.62, 0.04))):
		cyl(p, r, 3.0, (0, 0.12 + 0.02 * k, z), "pipe", 10, rot=(0, math.pi / 2, 0))
	for x in (-1.2, 0.0, 1.2):
		box(p, (0.05, 0.22, 0.5), (x, 0.11, 2.42), "dark")
		cyl(p, 0.09, 0.06, (x, 0.12, 2.25), "dark", 10, rot=(0, math.pi / 2, 0))  # flange
	return p


def cooling_pump():
	"""B3 pump on a skid: motor box, volute and a riser pipe to the ceiling."""
	p = []
	box(p, (1.4, 0.8, 0.12), (0, 0, 0.06), "dark")
	box(p, (0.6, 0.5, 0.5), (-0.35, 0, 0.42), "paint", 0.03)  # motor
	for z in (0.26, 0.34, 0.42, 0.5, 0.58):  # cooling fins, flat plates (no rings)
		box(p, (0.62, 0.54, 0.015), (-0.35, 0, z), "dark")
	box(p, (0.5, 0.6, 0.56), (0.35, 0, 0.42), "pipe", 0.08)  # volute block
	cyl(p, 0.1, 2.3, (0.35, 0, 1.85), "pipe", 10)  # riser to the ceiling
	box(p, (0.3, 0.3, 0.06), (0.35, 0, 0.73), "dark")
	cyl(p, 0.08, 0.5, (0.85, 0, 0.4), "pipe", 10, rot=(0, math.pi / 2, 0))  # outlet
	return p


def cooling_fan():
	"""Industrial fan unit: square housing with a grille face and blades."""
	p = []
	box(p, (1.0, 0.6, 1.2), (0, 0, 0.62), "steel", 0.02)
	box(p, (1.0, 0.56, 0.04), (0, 0, 0.02), "dark")
	box(p, (0.84, 0.02, 0.84), (0, 0.305, 0.66), "dark")  # recess
	for a in range(4):
		box(p, (0.36, 0.02, 0.12), (0, 0.31, 0.66), "pipe", rot=(0, math.radians(20 + a * 90), 0))
	for z in (0.3, 0.42, 0.54, 0.66, 0.78, 0.9, 1.02):  # grille bars across the face
		box(p, (0.84, 0.02, 0.015), (0, 0.325, z), "dark")
	return p


# --- ASSET-069 security ----------------------------------------------------------------------------------

def security_gate_arm():
	"""Checkpoint gate arm, left raised (70 deg) so it never spans the walkway; striped arm."""
	p = []
	box(p, (0.35, 0.35, 1.0), (0, 0, 0.5), "paint", 0.02)
	box(p, (0.4, 0.4, 0.05), (0, 0, 1.025), "dark")
	a = math.radians(70)
	for i in range(6):
		r = 0.15 + i * 0.32 + 0.16
		box(p, (0.32, 0.06, 0.08), (r * math.cos(a) + 0.1, 0.22, 0.95 + r * math.sin(a)),
			"warning" if i % 2 else "paint", rot=(0, -a, 0))
	cyl(p, 0.07, 0.1, (0.0, 0.2, 0.92), "dark", 10, rot=(math.pi / 2, 0, 0))
	return p


def security_log_screen():
	"""Security log screen on a small console: a CRT with dim amber log lines (no legible text)."""
	p = []
	box(p, (0.8, 0.6, 0.75), (0, 0, 0.375), "steel", 0.01)
	box(p, (0.84, 0.64, 0.03), (0, 0, 0.765), "dark")
	box(p, (0.42, 0.36, 0.34), (0, -0.05, 0.95), "paint", 0.02)
	box(p, (0.34, 0.02, 0.26), (0, 0.135, 0.95), "screen_dead")
	for i in range(5):
		box(p, (0.12 + 0.03 * (i % 3), 0.01, 0.015), (-0.08 + 0.015 * (i % 3), 0.147, 1.04 - i * 0.04), "log_amber")
	box(p, (0.4, 0.15, 0.03), (0, 0.2, 0.795), "rubber")  # keyboard
	return p


def security_shelving():
	"""Records shelving, 1.8 m, five shelves with file boxes baked in."""
	p = []
	for x in (-0.88, 0.88):
		for y in (-0.22, 0.22):
			box(p, (0.04, 0.04, 2.1), (x, y, 1.05), "dark")
	for k in range(5):
		z = 0.1 + k * 0.45
		box(p, (1.8, 0.5, 0.025), (0, 0, z), "steel")
		if k < 4:
			for i in range(4 - (k % 2)):
				box(p, (0.36, 0.4, 0.28), (-0.62 + i * 0.42, 0.02, z + 0.155), "card", 0.01)
	return p


def security_file_boxes():
	"""Stack of three file boxes."""
	p = []
	box(p, (0.45, 0.35, 0.3), (-0.24, 0, 0.15), "card", 0.01)
	box(p, (0.45, 0.35, 0.3), (0.24, 0.02, 0.15), "card", 0.01, rot=(0, 0, math.radians(4)))
	box(p, (0.45, 0.35, 0.3), (0.0, -0.01, 0.45), "card", 0.01, rot=(0, 0, math.radians(-7)))
	for x in (-0.24, 0.24):
		box(p, (0.12, 0.01, 0.05), (x, 0.18, 0.22), "dark")
	return p


# --- ASSET-070..076 fixtures (origin on the ceiling, hanging down) ----------------------------------------

def light_panel():
	"""ASSET-070 lab panel troffer 1.2 x 0.3 m, unlit diffuser."""
	p = []
	box(p, (1.24, 0.34, 0.05), (0, 0, -0.025), "dark")
	box(p, (1.16, 0.26, 0.02), (0, 0, -0.055), "lens_off")
	return p


def light_cage():
	"""ASSET-072 caged bulkhead light (zones B and C): base plate, dome, three wire bars."""
	p = []
	cyl(p, 0.14, 0.04, (0, 0, -0.02), "dark", 10)
	cyl(p, 0.1, 0.12, (0, 0, -0.1), "lens_off", 10)
	for a in range(3):
		box(p, (0.24, 0.015, 0.015), (0, 0, -0.16), "dark", rot=(0, 0, a * math.pi / 3))
	for a in range(4):
		ang = a * math.pi / 2
		box(p, (0.015, 0.015, 0.16), (0.115 * math.cos(ang), 0.115 * math.sin(ang), -0.09), "dark")
	return p


def emergency_strip():
	"""ASSET-073 floor strip (origin on the floor): faint red, always on."""
	p = []
	box(p, (0.6, 0.08, 0.012), (0, 0, 0.006), "dark")
	box(p, (0.54, 0.04, 0.006), (0, 0, 0.014), "strip_red")
	return p


def _beacon(p, lens):
	cyl(p, 0.11, 0.05, (0, 0, -0.025), "dark", 12)
	cyl(p, 0.08, 0.16, (0, 0, -0.13), lens, 12)
	cyl(p, 0.06, 0.03, (0, 0, -0.225), "dark", 12)


def beacon():
	"""ASSET-074 amber evacuation beacon (lit by the presenter only in Evacuation)."""
	p = []
	_beacon(p, "lens_amber")
	return p


def beacon_red():
	"""ASSET-075 C4 red beacon with the triangle cap, its shape backup (§4)."""
	p = []
	_beacon(p, "lens_red")
	bp.prism(p, [(-0.14, -0.05), (0.14, -0.05), (0.0, 0.03)], 0.02, -0.01, "warning")
	for o in p[-1:]:  # the triangle hangs in the X-Z plane beside the lens, facing +Y
		o.location = (0, 0.12, -0.08)
	return p


def strobe():
	"""ASSET-076 alarm strobe: small box with a clear lens (the light is ScareVisuals')."""
	p = []
	box(p, (0.16, 0.1, 0.05), (0, 0, -0.025), "binder_red")
	box(p, (0.12, 0.07, 0.06), (0, 0, -0.08), "lens_off", 0.01)
	return p


# --- facility detail pass (designer 2026-10-17): clutter, placed by MapClutter -----------------------------
# Wall items: origin at the foot of the wall face, back on the wall (Blender y 0), front +Y.

def clutter_extinguisher():
	"""Fire extinguisher on a wall bracket, sign plate above (blank: §6 no text)."""
	p = []
	cyl(p, 0.075, 0.5, (0, 0.11, 1.0), "extinguisher", 12, bevel=0.01)
	cyl(p, 0.05, 0.06, (0, 0.11, 1.28), "dark", 10)
	box(p, (0.03, 0.12, 0.03), (0.03, 0.11, 1.33), "dark")  # handle
	cyl(p, 0.012, 0.3, (-0.07, 0.17, 1.15), "rubber", 6, rot=(0, math.radians(15), 0))  # hose
	box(p, (0.14, 0.04, 0.3), (0, 0.02, 1.05), "dark")  # bracket
	box(p, (0.2, 0.01, 0.2), (0, 0.005, 1.55), "extinguisher")  # marker plate
	return p


def clutter_junction_box():
	"""Grey electrical box with a conduit running up the wall (top under the 2.2 m pipe band)."""
	p = []
	box(p, (0.36, 0.14, 0.46), (0, 0.07, 1.4), "paint", 0.01)
	box(p, (0.32, 0.01, 0.42), (0, 0.145, 1.4), "steel", 0.004)
	box(p, (0.06, 0.02, 0.03), (0.12, 0.155, 1.4), "dark")  # latch
	box(p, (0.12, 0.012, 0.08), (0, 0.15, 1.56), "warning")  # hazard plate
	cyl(p, 0.022, 0.55, (0.1, 0.04, 1.9), "pipe", 8)
	cyl(p, 0.022, 0.55, (-0.1, 0.04, 1.9), "pipe", 8)
	return p


def clutter_vent():
	"""Low wall vent grille."""
	p = []
	box(p, (0.6, 0.03, 0.3), (0, 0.015, 0.35), "dark", 0.006)
	for i in range(6):
		box(p, (0.54, 0.03, 0.02), (0, 0.035, 0.24 + i * 0.044), "steel", rot=(math.radians(-30), 0, 0))
	return p


def clutter_notice_board():
	"""Cork board with pinned sheets, some hanging loose."""
	p = []
	box(p, (0.9, 0.03, 0.6), (0, 0.015, 1.5), "cork", 0.005)
	box(p, (0.94, 0.035, 0.03), (0, 0.018, 1.815), "dark")
	box(p, (0.94, 0.035, 0.03), (0, 0.018, 1.185), "dark")
	for x, z, r in ((-0.28, 1.58, 4), (-0.02, 1.62, -6), (0.25, 1.55, 9), (-0.15, 1.36, -3), (0.15, 1.34, 22)):
		box(p, (0.2, 0.005, 0.27), (x, 0.034, z), "paper", rot=(0, math.radians(r), 0))
	return p


# Floor clutter: origin on the floor, back toward the room corner (-X, -Y).

def clutter_crates():
	"""Two slatted crates and a third on top, skewed."""
	p = []
	def crate(x, y, z, s, yaw):
		box(p, (s, s, s), (x, y, z + s / 2), "wood", 0.01, rot=(0, 0, yaw))
		for k in (-1, 1):  # corner battens
			box(p, (s + 0.02, 0.05, 0.05), (x, y + k * s * 0.4, z + s * 0.92), "dark", rot=(0, 0, yaw))
			box(p, (s + 0.02, 0.05, 0.05), (x, y + k * s * 0.4, z + s * 0.08), "dark", rot=(0, 0, yaw))
	crate(0.35, 0.35, 0, 0.6, 0.0)
	crate(1.0, 0.33, 0, 0.55, 0.12)
	crate(0.4, 0.38, 0.6, 0.5, -0.2)
	return p


def clutter_drums():
	"""Two steel drums and one on its side."""
	p = []
	for x, y, mat in ((0.33, 0.33, "drum_blue"), (0.33, 0.95, "drum_rust")):
		cyl(p, 0.29, 0.88, (x, y, 0.44), mat, 16, bevel=0.01)
		for z in (0.29, 0.59):
			cyl(p, 0.3, 0.025, (x, y, z), "dark", 16)
		cyl(p, 0.04, 0.02, (x + 0.15, y, 0.89), "dark", 8)
	cyl(p, 0.29, 0.88, (1.05, 0.4, 0.29), "drum_blue", 16, rot=(0, math.pi / 2, 0.4), bevel=0.01)
	return p


def clutter_boxes():
	"""Archive boxes stacked unevenly, one open and spilling paper."""
	p = []
	for x, y, z, yaw in ((0.25, 0.22, 0, 0.0), (0.68, 0.24, 0, 0.1), (0.3, 0.25, 0.3, -0.15), (0.28, 0.62, 0, 0.3)):
		box(p, (0.42, 0.32, 0.3), (x, y, z + 0.15), "cardboard", 0.008, rot=(0, 0, yaw))
		box(p, (0.44, 0.34, 0.03), (x, y, z + 0.3), "cardboard", 0.005, rot=(0, 0, yaw))  # lid
	for x, y, r in ((0.8, 0.7, 20), (0.95, 0.55, -35), (0.65, 0.95, 60)):
		box(p, (0.21, 0.3, 0.004), (x, y, 0.004), "paper", rot=(0, 0, math.radians(r)))
	return p


SETS = {
	"lab": {"prop_lab_bench": lab_bench, "prop_lab_desk": lab_desk, "prop_lab_chair": lab_chair,
		"prop_lab_fridge": lab_fridge, "prop_lab_monitor": lab_monitor, "prop_lab_binders": lab_binders},
	"server": {"prop_server_rack": server_rack, "prop_server_rack_row_w5": _rack_row(5.0, 8),
		"prop_server_rack_row_w4": _rack_row(4.0, 6), "prop_server_cable_bundle": server_cable_bundle,
		"prop_cooling_pipes": cooling_pipes, "prop_cooling_pump": cooling_pump, "prop_cooling_fan": cooling_fan},
	"security": {"prop_security_gate_arm": security_gate_arm, "prop_security_log_screen": security_log_screen,
		"prop_security_shelving": security_shelving, "prop_security_file_boxes": security_file_boxes},
	"clutter": {"prop_clutter_extinguisher": clutter_extinguisher, "prop_clutter_junction_box": clutter_junction_box,
		"prop_clutter_vent": clutter_vent, "prop_clutter_notice_board": clutter_notice_board,
		"prop_clutter_crates": clutter_crates, "prop_clutter_drums": clutter_drums, "prop_clutter_boxes": clutter_boxes},
	"fixtures": {"prop_light_panel": light_panel, "prop_light_cage": light_cage,
		"prop_emergency_strip": emergency_strip, "prop_beacon": beacon, "prop_beacon_red": beacon_red,
		"prop_strobe": strobe},
}


def check_palette(name, o):
	for m in o.data.materials:
		assert bp.MATS[m.name][0].upper() not in FORBIDDEN, "%s uses reserved colour %s" % (name, m.name)


def main():
	os.makedirs(OUT, exist_ok=True)
	os.makedirs(bp.EVIDENCE, exist_ok=True)
	built = {}
	for set_name, items in SETS.items():
		cap = FIXTURE_MAX if set_name == "fixtures" else TRI_MAX
		for name, fn in items.items():
			bp.clear()
			o = bp.join(name, fn())
			n = bp.tris(o)
			assert n <= cap, "%s: %d tris over %d" % (name, n, cap)
			check_palette(name, o)
			bp.export(o, os.path.join(OUT, name + ".glb"))
			built[name] = n
			print("DRESSING %s %d tris" % (name, n))
	bp.preview_materials()
	for set_name, items in SETS.items():  # one preview per item, prefixed with its set
		for name, fn in items.items():
			bp.clear()
			o = bp.join(name, fn())
			if set_name == "fixtures":
				o.location.z = 2.0 if name != "prop_emergency_strip" else 0.0  # hung at a ceiling seen from below
			bpy.context.view_layer.update()
			bp.render("%s_%s" % (set_name, name), o)
	print("BUILT", built)


main()
