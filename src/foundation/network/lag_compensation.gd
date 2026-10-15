class_name LagCompensation extends RefCounted
## Every server hit test goes through here (ADR-0003 §3-6); lunge and taser share it.
## rewind_ticks() turns the attacker's reported view tick into a rewind, clamped by max_rewind_ms and by
## the RTT bound the server measures from the frame's ack_snapshot_tick; targets_at() reads the rewound
## target capsules from RewindHistory; capsule_hits_segment() and ray_first_hit() are pure analytic tests.
## Only target positions are rewound: the caller's `skip` (Seized, Downed, hidden, grace) and door state
## are read at the current tick. No physics body is moved and no shape query is made.
## Walls and doors are the callers' (intersect_ray with PhysicsLayers.SIGHT / PROJECTILE, door boxes).
## Every clamp, rejected view tick and out-of-history sample is logged (first MAX_RECORDED entries kept,
## record_count keeps counting).
## Usage:
##   var lc := LagCompensation.new(knobs, sm.history, sm.frame_of)
##   var targets := lc.targets_at(tick, lc.rewind_ticks(monster, tick), survivor_ids)
##   var hit := LagCompensation.ray_first_hit(chest, aim, range_m, targets, is_seized_or_downed)

const MAX_RECORDED := 32
## ADR-0003 §3: the "+ 2" ticks of the rtt_bound formula (snapshot send and input consume phases).
const BOUND_FIXED_TICKS := 2.0
const EPS := 1e-9

## Logged cases, oldest first: {kind: "clamped" | "bad_view_tick" | "out_of_history", tick, ...};
## clamped and bad_view_tick carry attacker, requested and applied; out_of_history carries player.
var records: Array[Dictionary] = []
## Total logged cases (records stops growing at MAX_RECORDED).
var record_count: int = 0

var _history: RewindHistory
var _frame_of: Callable
var _cap_ticks: float
var _interp_ticks: float
var _slack_ticks: float


## `frame_of` is Callable(player_id) -> InputFrame, the attacker's frame this tick (ServerMovement.frame_of).
func _init(knobs: Knobs, history: RewindHistory, frame_of: Callable) -> void:
	_history = history
	_frame_of = frame_of
	var hz := float(knobs.net.sim_tick_hz)
	_cap_ticks = knobs.ability.max_rewind_ms * hz / 1000.0
	_interp_ticks = knobs.net.interp_delay_ms * hz / 1000.0
	_slack_ticks = knobs.net.slack_ticks


## Rewind in ticks for `attacker_id`'s hit test on server tick `tick` (ADR-0003 §3):
## clamp(tick - view_tick, 0, min(cap, (tick - ack_snapshot_tick) + interp + 2 + slack)).
## A non-finite or future view_tick (or a future ack) gives 0 and a log entry; a clamp is logged.
func rewind_ticks(attacker_id: int, tick: int) -> float:
	var f: InputFrame = _frame_of.call(attacker_id)
	var view := f.view_tick
	if not is_finite(view) or view > tick or f.ack_snapshot_tick > tick:
		_log({"kind": "bad_view_tick", "tick": tick, "attacker": attacker_id, "requested": view, "applied": 0.0})
		return 0.0
	var lag := tick - view
	var bound := (tick - f.ack_snapshot_tick) + _interp_ticks + BOUND_FIXED_TICKS + _slack_ticks
	var applied := clampf(lag, 0.0, minf(_cap_ticks, bound))
	if applied < lag:
		_log({"kind": "clamped", "tick": tick, "attacker": attacker_id, "requested": lag, "applied": applied})
	return applied


## The capsules of `player_ids` at `tick - rewind`, each a RewindHistory sample plus "id". A player out
## of history is taken at `tick` (its current position, pushed this tick) and logged.
func targets_at(tick: int, rewind: float, player_ids: Array[int]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pid in player_ids:
		var s := _history.sample(pid, tick - rewind)
		if not s.ok:
			_log({"kind": "out_of_history", "tick": tick, "player": pid, "rewind": rewind})
			s = _history.sample(pid, tick)
			if not s.ok:
				continue ## no record at all this tick: nothing to hit
		s["id"] = pid
		out.append(s)
	return out


## True when segment a-b comes within the target capsule's radius (+ `extra`, an aim tolerance). The
## capsule stands on target.pos: axis from y + radius to y + height - radius (half-length height / 2 -
## radius, centred at half height); a capsule shorter than 2 radius is a sphere.
static func capsule_hits_segment(a: Vector3, b: Vector3, target: Dictionary, extra: float = 0.0) -> bool:
	var axis := _axis(target)
	var p := Geometry3D.get_closest_points_between_segments(a, b, axis[0], axis[1])
	var r: float = target.radius + extra
	return p[0].distance_squared_to(p[1]) < r * r


## The nearest target capsule along the ray (origin, dir, max_dist), skipping targets for which
## skip.call(id) is true (current-tick eligibility). {hit: true, id, distance, point} or {hit: false}.
## Rays must start outside every capsule (ADR-0003 §6: at the eye or chest point, never inside a collider).
static func ray_first_hit(origin: Vector3, dir: Vector3, max_dist: float, targets: Array, skip: Callable) -> Dictionary:
	var d := dir.normalized()
	var best := INF
	var best_id := -1
	for t: Dictionary in targets:
		if skip.call(t.id):
			continue
		var axis := _axis(t)
		var dist := _ray_capsule(origin, d, axis[0], axis[1], t.radius)
		if dist <= max_dist and dist < best:
			best = dist
			best_id = t.id
	if best_id == -1:
		return {"hit": false}
	return {"hit": true, "id": best_id, "distance": best, "point": origin + d * best}


static func _axis(t: Dictionary) -> PackedVector3Array:
	var pos: Vector3 = t.pos
	var r: float = t.radius
	var lo := pos.y + r
	return PackedVector3Array([Vector3(pos.x, lo, pos.z), Vector3(pos.x, maxf(lo, pos.y + t.height - r), pos.z)])


## Entry distance of a unit ray into the capsule (segment pa-pb, radius r), INF when missed or the origin
## is inside. The capsule is the union of its two end spheres and the finite cylinder between them.
static func _ray_capsule(ro: Vector3, rd: Vector3, pa: Vector3, pb: Vector3, r: float) -> float:
	var best := minf(_ray_sphere(ro, rd, pa, r), _ray_sphere(ro, rd, pb, r))
	var ba := pb - pa
	var baba := ba.dot(ba)
	var bard := ba.dot(rd)
	var a := baba - bard * bard
	if baba < EPS or a < EPS:
		return best ## a sphere, or a ray parallel to the axis: only the caps can be entered
	var oa := ro - pa
	var baoa := ba.dot(oa)
	var b := baba * rd.dot(oa) - baoa * bard
	var c := baba * oa.dot(oa) - baoa * baoa - r * r * baba
	var h := b * b - a * c
	if h < 0.0:
		return best
	var t := (-b - sqrt(h)) / a
	var y := baoa + t * bard
	if t >= 0.0 and y > 0.0 and y < baba:
		best = minf(best, t)
	return best


static func _ray_sphere(ro: Vector3, rd: Vector3, centre: Vector3, r: float) -> float:
	var oc := ro - centre
	var b := oc.dot(rd)
	var h := b * b - (oc.dot(oc) - r * r)
	if h < 0.0:
		return INF
	var t := -b - sqrt(h)
	return t if t >= 0.0 else INF


func _log(entry: Dictionary) -> void:
	record_count += 1
	if records.size() < MAX_RECORDED:
		records.append(entry)
