class_name BorrowedFace extends RefCounted
## Borrowed Face: the shapeshifter's disguise (Core layer). Story borrowed-face/001 implements the
## observation accumulator: design/gdd/borrowed-face.md rules 1-3 and Formulas "Observation
## accumulation"; ADR-0005 (tick order slot BORROWED_FACE), ADR-0007 §5 (sight rays on SIGHT, doors
## analytic), ADR-0006 (BorrowedFaceKnobs). Later stories add form, transform and cooldown.
## Server only. Observation counts ticks of `net.sim_tick_hz`, never wall time, and never decays.
## Collaborators are injected as Callables (ADR-0005 §6 dependency injection):
##   eye_of(player) -> Vector3                  the shapeshifter's eye position
##   yaw_of(player) -> float                    its look yaw (ViewState.yaw_of; 0 faces -Z)
##   body_points_of(player) -> PackedVector3Array  [head, chest, pelvis]; empty = no body in the world
##   sight(eye, point) -> bool                  line of sight (MapQueries.clear_sight on the server)
##   locked(player) -> bool                     Stunned or under the shock lock (Survivor Defense rule
##                                              14). Stub until Survivor Defense publishes
##                                              StateKeys.SHOCK_STUN_LOCK; unset = never locked
## Usage:
##   var bf := BorrowedFace.new()
##   bf.set_roster([2, 3, 4, 5], 1)   # BEFORE start_round
##   bf.set_sight_sources(eye_of, view.yaw_of, body_points_of, sight, locked)
##   server.start_round({TickOrder.BORROWED_FACE: bf}, knobs)
##   bf.observed(2)

## Index of the chest point in body_points_of: the cone is measured to it (rule 2).
const CHEST := 1
## Float tolerance so a survivor exactly on observe_range_m counts.
const RANGE_EPS_M := 1e-6

var _survivors: Array[int] = []
var _monster: int = -1
var _eye_of: Callable
var _yaw_of: Callable
var _body_points_of: Callable
var _sight: Callable
var _locked: Callable
var _hz: int = 0
var _observe_ticks: int = 0
var _range_m: float = 0.0
var _half_fov: float = 0.0
## survivor -> valid observation ticks this round (rule 1: obs_time in ticks)
var _obs: Dictionary[int, int] = {}


## Injects the round's roster. Call before RoundServer.start_round (setup resets state from it).
func set_roster(survivors: Array[int], monster: int) -> void:
	_survivors = survivors.duplicate()
	_monster = monster


## Injects the sight collaborators (see the class comment). Unset ones observe nothing, except
## `locked`, which unset means never locked.
func set_sight_sources(eye_of: Callable, yaw_of: Callable, body_points_of: Callable, sight: Callable,
		locked: Callable = Callable()) -> void:
	_eye_of = eye_of
	_yaw_of = yaw_of
	_body_points_of = body_points_of
	_sight = sight
	_locked = locked


## Injected by RoundServer. Reads knobs and resets every survivor's observation to 0 (rule 1).
func setup(_tick_runner: TickRunner, _bus: EventBus, _registry: StateRegistry, knobs: Knobs) -> void:
	_hz = knobs.net.sim_tick_hz
	_observe_ticks = knobs.ticks(knobs.borrowed_face.observe_time_s)
	_range_m = knobs.borrowed_face.observe_range_m
	_half_fov = deg_to_rad(knobs.borrowed_face.observe_fov_deg / 2.0)
	_obs = {}
	for s in _survivors:
		_obs[s] = 0


## BORROWED_FACE slot: one tick of valid observation for each unobserved survivor meeting every
## rule 2 condition. Survivor Defense (slot 200) runs first, so a stun landing this tick blocks it.
func server_tick(_tick: int) -> void:
	if not (_eye_of.is_valid() and _yaw_of.is_valid() and _body_points_of.is_valid() and _sight.is_valid()):
		return
	if _locked.is_valid() and _locked.call(_monster):
		return
	var eye: Vector3 = _eye_of.call(_monster)
	var look := ViewState.direction(_yaw_of.call(_monster), 0.0)
	for s in _survivors:
		if _obs[s] < _observe_ticks and _observable(eye, look, _body_points_of.call(s)):
			_obs[s] += 1


## Rule 3: true once `survivor` has `observe_time_s` of valid observation this round.
func observed(survivor: int) -> bool:
	return _obs.get(survivor, 0) >= _observe_ticks and _observe_ticks > 0


## Seconds of valid observation on `survivor` this round, capped at observe_time_s (for the HUD).
func observation_s(survivor: int) -> float:
	return float(_obs.get(survivor, 0)) / _hz if _hz > 0 else 0.0


## Rule 2 range, cone and line of sight. Range is measured eye to chest (inference: the GDD says
## "dist(monster_eye, survivor)" without naming a point; a designer ruling settles it). The cone is
## horizontal to the chest; a chest straight above or below the eye has angle 0 and counts.
func _observable(eye: Vector3, look: Vector3, points: PackedVector3Array) -> bool:
	if points.size() <= CHEST:
		return false
	var chest := points[CHEST]
	if eye.distance_to(chest) > _range_m + RANGE_EPS_M:
		return false
	var flat := Vector3(chest.x - eye.x, 0.0, chest.z - eye.z)
	if look.angle_to(flat) > _half_fov:
		return false
	for p in points:
		if _sight.call(eye, p):
			return true
	return false
