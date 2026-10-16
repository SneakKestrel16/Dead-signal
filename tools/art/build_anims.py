"""Authored animation clips for the survivor body and the true form (ASSET-008, ASSET-010,
design/assets/specs/characters-assets.md), keyed procedurally on the Quaternius UAL rig.

Imported by build_characters.py (add_survivor_clips / add_true_clips run on the freshly loaded rig before
export). Run on its own it renders the evidence contact sheets from the exported glbs, one png per clip:
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
      --python tools/art/build_anims.py
writes production/qa/evidence/character-anims/<glb>_<clip>.png (4 key poses left to right).

A pose = a base frame sampled from a library clip, then turns of whole bones about armature axes
(source rig: faces -Y, up +Z, left side +X), parents before children, then an optional root tip
(degrees about X: +90 lies face down, head forward; -90 on the back) and root offset in metres.
Axis cheat sheet (standing): X -deg raises a hanging limb forward, +deg bends the spine forward and swings
a hanging shin back; Y -deg lifts the left arm sideways, +deg the right; Z +deg turns to the left.
Clip names ending _Loop loop in Godot (the importer strips the suffix). Library clips reused for the
remaining rows are listed in assets/art/CREDITS.md "## Characters".
"""
import math
import os
import sys

import bpy
from mathutils import Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EVIDENCE = os.path.join(ROOT, "production", "qa", "evidence", "character-anims")
LOC_BONES = ("root", "DEF-hips")
L, R = ".L", ".R"


def _sample(rig, base, frame):
	rig.animation_data.action = bpy.data.actions[base]
	bpy.context.scene.frame_set(frame)
	return {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in rig.pose.bones}


def pose(rig, base, frame=0, turns=(), tip=0.0, offset=(0.0, 0.0, 0.0)):
	"""Pose dict {bone: (location, quaternion)}: `base` clip at `frame`, then `turns` [(bone, axis, deg)]."""
	start = _sample(rig, base, frame)
	rig.animation_data.action = None
	for pb in rig.pose.bones:
		pb.location, pb.rotation_quaternion = start[pb.name]
	bpy.context.view_layer.update()
	for bone, axis, deg in turns:
		pb = rig.pose.bones[bone]
		m = pb.matrix.copy()
		h = m.translation.copy()
		pb.matrix = Matrix.Translation(h) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-h) @ m
		bpy.context.view_layer.update()
	if tip or any(offset):
		pb = rig.pose.bones["root"]
		pb.matrix = Matrix.Translation(offset) @ Matrix.Rotation(math.radians(tip), 4, "X") @ pb.matrix
		bpy.context.view_layer.update()
	return {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in rig.pose.bones}


def clip(rig, name, keys, loc_bones=LOC_BONES):
	"""New action `name` keyed at [(frame, pose dict)]; quaternion signs kept continuous."""
	act = bpy.data.actions.new(name)
	act.use_fake_user = True
	rig.animation_data.action = act
	prev = {}
	for f, p in keys:
		for pb in rig.pose.bones:
			loc, q = p[pb.name]
			if pb.name in prev and prev[pb.name].dot(q) < 0.0:
				q = -q
			prev[pb.name] = q
			pb.rotation_quaternion = q
			pb.keyframe_insert("rotation_quaternion", frame=f)
			if pb.name in loc_bones:
				pb.location = loc
				pb.keyframe_insert("location", frame=f)
	rig.animation_data.action = None
	return act


def _side(turns, s):
	"""Mirrors [(bone-without-side, axis, deg)] onto side s (".L"/".R"): Y and Z turns flip on the right."""
	return [(b + s, a, d if s == L or a == "X" else -d) for b, a, d in turns]


# --- survivor (ASSET-008) -------------------------------------------------------------------------

def _prone(rig, arm_l, arm_r, leg_l, leg_r, spine=-12.0, head=-45.0, base="Idle_Loop"):
	"""Face down on the floor, propped on the forearms (Downed / crawl family). Limb lists per side."""
	turns = [("DEF-spine.002", "X", spine), ("DEF-neck", "X", head * 0.4), ("DEF-head", "X", head * 0.6)]
	turns += _side(arm_l, L) + _side(arm_r, R) + _side(leg_l, L) + _side(leg_r, R)
	return pose(rig, base, 0, turns, tip=88.0, offset=(0.0, 0.85, 0.16))


def _arm(up, fore, out=0.0):
	return [("DEF-upper_arm", "Y", -out), ("DEF-upper_arm", "X", -up), ("DEF-forearm", "X", -fore)]


def _leg(hip, knee, out=0.0):
	return [("DEF-thigh", "Y", -out), ("DEF-thigh", "X", -hip), ("DEF-shin", "X", knee)]


def add_survivor_clips(rig):
	"""Downed, crawl, Call for Help, stand-up, seized, hide enter/exit."""
	down = _prone(rig, _arm(150, 70, 20), _arm(150, 70, 20), _leg(0, 0, 8), _leg(0, 10, 12))
	down_b = _prone(rig, _arm(150, 70, 20), _arm(150, 70, 20), _leg(0, 0, 8), _leg(0, 10, 12), spine=-16.0)
	clip(rig, "Downed_Loop", [(0, down), (30, down_b), (60, down)])
	reach_l = _prone(rig, _arm(170, 20, 10), _arm(115, 95, 30), _leg(0, 0, 5), _leg(0, 25, 45))
	reach_r = _prone(rig, _arm(115, 95, 30), _arm(170, 20, 10), _leg(0, 25, 45), _leg(0, 0, 5))
	clip(rig, "Crawl_Loop", [(0, reach_l), (20, reach_r), (40, reach_l)])
	cry = _prone(rig, _arm(150, 70, 20), _arm(165, 10, 60), _leg(0, 0, 8), _leg(0, 10, 12), spine=-25.0, head=-70.0)
	cry_b = _prone(rig, _arm(150, 70, 20), _arm(165, 10, 30), _leg(0, 0, 8), _leg(0, 10, 12), spine=-25.0, head=-70.0)
	clip(rig, "Call_Help", [(0, down), (8, cry), (16, cry_b), (24, cry), (32, cry_b), (44, down)])
	kneel = pose(rig, "Fixing_Kneeling", 40)  # frame 0 still stands
	rise = pose(rig, "Crouch_Idle_Loop", 0)
	clip(rig, "Stand_Up", [(0, down), (14, kneel), (26, rise), (38, pose(rig, "Idle_Loop", 0))])
	# Seized / pinned: on the back under the attacker, arms pushing up, legs kicking.
	def pinned(a, b):
		turns = _side(_arm(80 + a, 40, 15), L) + _side(_arm(80 - a, 40, 15), R)
		turns += _side(_leg(45 + b, 70 + b), L) + _side(_leg(45 - b, 70 - b), R) + [("DEF-head", "X", 25)]
		return pose(rig, "Idle_Loop", 0, turns, tip=-86.0, offset=(0.0, -0.85, 0.13))
	clip(rig, "Seized_Loop", [(0, pinned(15, 15)), (8, pinned(-15, -15)), (16, pinned(15, 15))])
	stand = pose(rig, "Idle_Loop", 0)
	duck = pose(rig, "Crouch_Idle_Loop", 0, [("DEF-spine.001", "X", 20)])
	duck_turn = pose(rig, "Crouch_Idle_Loop", 0, [("DEF-spine.001", "X", 25)], offset=(0.0, 0.25, 0.0))
	clip(rig, "Hide_Enter", [(0, stand), (10, duck), (20, duck_turn)])
	clip(rig, "Hide_Exit", [(0, duck_turn), (10, duck), (20, stand)])


# --- true form (ASSET-010) ------------------------------------------------------------------------

def add_true_clips(rig):
	"""Lunge coil, dash, miss stumble, takedown pin. Rotations only below the hips (build_true_form)."""
	idle = pose(rig, "Idle_Loop", 0)
	coil_t = [("DEF-spine.001", "X", 12), ("DEF-spine.003", "X", 5), ("DEF-head", "X", -30)]
	coil_t += _side([("DEF-upper_arm", "Y", -30), ("DEF-upper_arm", "X", 15), ("DEF-forearm", "X", -60)], L)
	coil_t += _side([("DEF-upper_arm", "Y", -30), ("DEF-upper_arm", "X", 15), ("DEF-forearm", "X", -60)], R)
	coil = pose(rig, "Crouch_Idle_Loop", 0, coil_t)
	deep = pose(rig, "Crouch_Idle_Loop", 0, coil_t + _side([("DEF-forearm", "X", -25)], L)
		+ _side([("DEF-forearm", "X", -25)], R))
	# One-shot that ends in the held coil: wind-up is lunge_windup_s (0.4-1.0 s); 14 frames = 0.58 s.
	clip(rig, "Lunge_Coil", [(0, idle), (8, coil), (14, deep)])
	dash_t = [("DEF-spine.001", "X", 40), ("DEF-head", "X", -40)] + _side(_arm(95, 5, 10), L) \
		+ _side(_arm(95, 5, 10), R) + _side(_leg(55, 30), L) + _side(_leg(-35, 40), R)
	dash = pose(rig, "Idle_Loop", 0, dash_t, offset=(0.0, 0.0, -0.12))
	clip(rig, "Lunge_Dash", [(0, deep), (3, dash), (8, dash)])
	trip_t = [("DEF-spine.001", "X", 60), ("DEF-head", "X", -20)] + _side(_arm(30, 40, 30), L) \
		+ _side(_arm(60, 20, 10), R) + _side(_leg(70, 90), L) + _side(_leg(-20, 30), R)
	trip = pose(rig, "Crouch_Idle_Loop", 0, trip_t)
	clip(rig, "Lunge_Stumble", [(0, dash), (8, trip), (16, trip), (28, idle)])
	pin_t = [("DEF-spine.001", "X", 35), ("DEF-head", "X", -15)] + _side(_arm(45, 10, 25), L) \
		+ _side(_arm(45, 10, 25), R)
	pin_a = pose(rig, "Crouch_Idle_Loop", 0, pin_t)
	pin_b = pose(rig, "Crouch_Idle_Loop", 0, pin_t + [("DEF-spine.002", "X", 8)])
	clip(rig, "Takedown_Pin_Loop", [(0, pin_a), (10, pin_b), (20, pin_a)])


# --- evidence ---------------------------------------------------------------------------------------

SHEETS = {
	"char_survivor_body": ("survivors", ["Downed", "Crawl", "Call_Help", "Stand_Up", "Seized", "Hide_Enter",
		"Hide_Exit", "Death01", "Hit_Chest", "Fixing_Kneeling", "Push", "Interact"]),
	"char_shapeshifter_true": ("shapeshifter", ["Lunge_Coil", "Lunge_Dash", "Lunge_Stumble", "Takedown_Pin",
		"Punch_Cross", "Hit_Head"]),
}
CELL = 256


def render_sheets():
	import numpy as np
	sys.path.insert(0, os.path.dirname(__file__))
	from build_characters import write_png
	for glb, (folder, clips) in SHEETS.items():
		bpy.ops.wm.read_factory_settings(use_empty=True)
		bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "art", "characters", folder, glb + ".glb"))
		rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
		for o in bpy.data.objects:  # LOD0 only
			if o.type == "MESH" and ("lod1" in o.name or "lod2" in o.name or o.name.startswith("acc_")):
				o.hide_render = True
		sc = bpy.context.scene
		sc.render.engine = "BLENDER_WORKBENCH"
		sc.display.shading.light = "STUDIO"
		sc.display.shading.color_type = "SINGLE"
		sc.render.resolution_x = sc.render.resolution_y = CELL
		cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
		sc.collection.objects.link(cam)
		sc.camera = cam
		cam.data.type = "ORTHO"
		cam.data.ortho_scale = 3.4
		# Near side view from the left of a body facing glTF +Z (Blender -Y after import).
		cam.location = (5.6, -1.2, 2.6)
		cam.rotation_euler = (math.radians(70), 0.0, math.radians(78))
		floor = bpy.data.objects.new("floor", bpy.data.meshes.new("floor"))
		floor.data.from_pydata([(-3, -3, 0), (3, -3, 0), (3, 3, 0), (-3, 3, 0)], [], [(0, 1, 2, 3)])
		sc.collection.objects.link(floor)
		path = os.path.join(EVIDENCE, "_tmp.png")
		for name in clips:
			act = next(a for a in bpy.data.actions if a.name.split("_Loop")[0] == name
				or a.name.startswith(name + "_Loop") or a.name == name)
			rig.animation_data.action = act
			f0, f1 = act.frame_range
			sheet = np.zeros((CELL, CELL * 4, 4), np.uint8)
			for k in range(4):
				sc.frame_set(int(round(f0 + (f1 - f0) * k / 3.0)))
				sc.render.filepath = path
				bpy.ops.render.render(write_still=True)
				img = bpy.data.images.load(path)
				px = np.array(img.pixels[:], np.float32).reshape(CELL, CELL, 4)[::-1]
				bpy.data.images.remove(img)
				sheet[:, k * CELL:(k + 1) * CELL] = (np.clip(px, 0, 1) * 255 + 0.5).astype(np.uint8)
			sheet[..., 3] = 255
			write_png(os.path.join(EVIDENCE, "%s_%s.png" % (glb, name)), sheet)
			print("SHEET", glb, name, act.name, f0, f1)
		os.remove(path)


if __name__ == "__main__":
	render_sheets()
