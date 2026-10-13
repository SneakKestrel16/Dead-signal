extends "res://lib.gd"
## ADR-0003 Verification Required (1) and (4). (2) and (3) need a real network.
## Pursuit model: monster-abilities.md Formulas (Lunge hit check, Governing model: steering pursuit)
## and first-person-controller.md Dodge window AC.

const WINDUP_S := 0.6
const DASH_S := 0.3
const DASH_M := 4.0
var WINDUP_TURN := 15.0
const DASH_TURN := 30.0
var HIT_RADIUS := 1.2
var CONE_DEG := 60.0
const BODY_R := 0.3
const START_DIST := 3.0


func run() -> void:
	var q := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.FORWARD)
	rec("0003-1", "OBSERVED", "PhysicsRayQueryParameters3D defaults: hit_from_inside=%s hit_back_faces=%s collide_with_areas=%s collide_with_bodies=%s collision_mask=%d" % [q.hit_from_inside, q.hit_back_faces, q.collide_with_areas, q.collide_with_bodies, q.collision_mask])
	rec("0003-2", "NOT RUN", "180 ms cap and 16-tick ring against measured rewind need a real network (spike deferred list)")
	rec("0003-3", "NOT RUN", "remote smoothness at 50 ms interpolation under loss and jitter needs a rendered client on a real network")
	_pursuit()


## Returns true when the lunge hits. strafe_dir is +1 or -1 (sideways), phase shifts the
## server tick grid against the cue (0..1 tick). step_s is the test interval.
func _lunge_hits(strafe_start: float, strafe_speed: float, accel_s: float, strafe_dir: float, phase: float, step_s: float) -> bool:
	var m := Vector2.ZERO
	var facing := 0.0   # radians, 0 = +Y (towards the survivor's start)
	var s := Vector2(0, START_DIST)
	var dt := 0.0005
	var t := 0.0
	var next_test := phase * step_s
	var dash_speed := DASH_M / DASH_S
	while t < WINDUP_S + DASH_S:
		# Survivor: perpendicular strafe with linear acceleration.
		var ts := t - strafe_start
		var v := 0.0
		if ts > 0.0:
			v = strafe_speed * minf(1.0, ts / accel_s) if accel_s > 0.0 else strafe_speed
		s.x += strafe_dir * v * dt
		# Monster: steer toward the survivor's current position within the phase's turn limit.
		var dashing := t >= WINDUP_S
		var max_turn := deg_to_rad(DASH_TURN if dashing else WINDUP_TURN) * dt
		var to_s := s - m
		var want := atan2(to_s.x, to_s.y)
		facing += clampf(wrapf(want - facing, -PI, PI), -max_turn, max_turn)
		var fwd := Vector2(sin(facing), cos(facing))
		if dashing:
			m += fwd * dash_speed * dt
			if t >= next_test:
				next_test += step_s
				var d := (s - m).length() - BODY_R
				var ang := rad_to_deg(absf(fwd.angle_to(s - m)))
				if d <= HIT_RADIUS and ang <= CONE_DEG / 2.0:
					return true
		elif t >= next_test:
			next_test += step_s
		t += dt
	return false


func _all_seeds_dodge(start: float, speed: float, accel_s: float, step_s: float) -> bool:
	for seed in 20:
		var dir := 1.0 if seed % 2 == 0 else -1.0
		var phase := float(seed / 2) / 10.0
		if _lunge_hits(start, speed, accel_s, dir, phase, step_s):
			return false
	return true


func _latest_safe(speed: float, accel_s: float, step_s: float) -> float:
	var lo := 0.0
	var hi := 0.9
	if not _all_seeds_dodge(lo, speed, accel_s, step_s):
		return -1.0
	for i in 20:
		var mid := (lo + hi) / 2.0
		if _all_seeds_dodge(mid, speed, accel_s, step_s):
			lo = mid
		else:
			hi = mid
	return lo


func _pursuit() -> void:
	var tick := 1.0 / 60.0
	var fine := 0.0005
	var walk_tick := _all_seeds_dodge(0.43, 4.0, 0.05, tick)
	var walk_fine := _all_seeds_dodge(0.43, 4.0, 0.05, fine)
	var crouch_hit := not _all_seeds_dodge(0.43, 2.0, 0.05, tick)
	var ok := walk_tick and walk_fine and crouch_hit
	rec("0003-4", "PASS" if ok else "FAIL", "steering pursuit, strafe from 0.43 s, accel 0.05 s, 20 seeds (side x tick phase): walk 4.0 dodges per-tick=%s per-0.5ms=%s; crouch 2.0 hit=%s" % [walk_tick, walk_fine, crouch_hit])
	var safe_005_tick := _latest_safe(4.0, 0.05, tick)
	var safe_005_fine := _latest_safe(4.0, 0.05, fine)
	var safe_0 := _latest_safe(4.0, 0.0, fine)
	var safe_01 := _latest_safe(4.0, 0.1, fine)
	rec("0003-4b", "OBSERVED", "latest safe strafe start at walk 4.0: accel 0 -> %.3f s; accel 0.05 -> %.3f s (0.5 ms test), %.3f s (60 Hz test); accel 0.1 -> %.3f s. Margin over 0.43 s at accel 0.05: %d ms" % [safe_0, safe_005_fine, safe_005_tick, safe_01, roundi((safe_005_fine - 0.43) * 1000.0)])
	var accel01 := _all_seeds_dodge(0.43, 4.0, 0.1, fine)
	var lo := 0.05
	var hi := 0.1
	for i in 14:
		var mid := (lo + hi) / 2.0
		if _all_seeds_dodge(0.43, 4.0, mid, fine):
			lo = mid
		else:
			hi = mid
	_ceilings()
	rec("0003-4c", "OBSERVED", "controller Open Question, strafe from 0.43 s: accel_time_s 0.1 dodges=%s; largest accel_time_s that still dodges over 20 seeds = %.4f s" % [accel01, lo])


## monster-abilities.md Open Question: safe-range ceilings at the 0.43 s strafe, accel 0.05,
## one knob at a time, others at their proposed values. Ceiling = largest value that still dodges.
func _ceilings() -> void:
	var fine := 0.0005
	var out: Array[String] = []
	for knob in [["WINDUP_TURN", 15.0, 90.0], ["HIT_RADIUS", 1.2, 3.0], ["CONE_DEG", 60.0, 180.0]]:
		var base: float = get(knob[0])
		var lo: float = knob[1]
		var hi: float = knob[2]
		for i in 16:
			var mid := (lo + hi) / 2.0
			set(knob[0], mid)
			if _all_seeds_dodge(0.43, 4.0, 0.05, fine):
				lo = mid
			else:
				hi = mid
		set(knob[0], base)
		out.append("%s %.2f" % [knob[0], lo])
	rec("0003-4d", "OBSERVED", "ceilings at strafe 0.43 s, accel 0.05, walk 4.0, r 0.3, 20 seeds (largest value that still dodges): " + ", ".join(out))
