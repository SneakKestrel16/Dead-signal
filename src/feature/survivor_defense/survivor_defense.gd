class_name SurvivorDefense extends RefCounted
## Survivor Defense: taser charges, the reuse delay and the item-use gate (Feature layer). Implements
## design/gdd/survivor-defense.md rules 1, 7, 8 (fire and reuse only), 13 and 29; story
## survivor-defense/001; ADR-0002 (clients send intent only), ADR-0005 (TickOrder.SURVIVOR_DEFENSE),
## ADR-0006 (DefenseKnobs). Later stories add the trace (002), the shock lock (003) and hiding (006).
## Server only. Timers count ticks of `net.sim_tick_hz`, never wall time. Clients send a fire intent
## and nothing else: the server owns every charge, so a client claim of a hit, a charge or a finished
## barricade has no entry point and changes nothing (rule 1).
## Usage:
##   var sd := SurvivorDefense.new()
##   sd.set_roster([2, 3, 4, 5], 1)        # survivor ids, monster id: BEFORE start_round
##   sd.set_locked(downing.action_locked)  # Seized / Downed gate (downing-and-rescue.md rule 4.2)
##   server.start_round({TickOrder.SURVIVOR_DEFENSE: sd}, knobs)
##   smp.peer_packet -> sd.request_intent(net.player_id_of(peer), bytes)

## Intent value: fire one cartridge (rule 8).
const FIRE := 1
## Story 002: trace result reasons (Game Feel's failure texture reads them later).
const SHOT_HIT := "hit"
const SHOT_MISSED := "missed"
const SHOT_BLOCKED := "blocked"
const SHOT_RANGE := "range"
## Float slack on the inclusive range and aim boundaries (float32 positions).
const TRACE_EPS := 1e-4
## Intent packet dictionary key.
const INTENT_KEY := "item"
## decode_intent's result for bytes that are not an intent.
const INVALID_INTENT := 0
## Size cap of an intent packet; anything larger is not one (untrusted client bytes).
const REQUEST_CAP_BYTES := 64

var _survivors: Array[int] = []
var _stun_item_charges: int = 0
var _reuse_ticks: int = 0
## player id -> bool, Downing.action_locked (Seized or Downed); invalid means never locked.
var _is_locked: Callable
## survivor -> cartridges left; absent (the monster, anyone else) has no items.
var _charges: Dictionary[int, int] = {}
## survivor -> first tick a fire is accepted again (rule 8 reuse delay); absent = no delay running.
var _ready_tick: Dictionary[int, int] = {}
var _monster: int = -1
## Story 002 trace sources (set_trace); _lc null means no trace runs.
var _lc: LagCompensation
var _eye_of: Callable
var _frame_of: Callable
var _blocked: Callable
var _use_delay_ticks: int = 0
var _range_m: float = 0.0
var _aim_tol_rad: float = 0.0
## Fired shots waiting out stun_use_delay_s: Vector2i(due tick, shooter), oldest first.
var _queued: Array[Vector2i] = []
## Shots resolved on the latest tick (see resolved_shots).
var _resolved: Array[Dictionary] = []
## Hidden survivors. Story 006's hide flow drives this through set_hidden.
var _hidden: Dictionary[int, bool] = {}
## player -> this tick's intent (the first one received since the last tick).
var _pending: Dictionary[int, int] = {}


## Getter-only view for StateKeys.HIDDEN_ITEM_USE readers. Holds the module weakly; after the module
## is freed it reads as no charges, not hidden.
class DefenseView extends RefCounted:
	var _sd: WeakRef

	func _init(sd: SurvivorDefense) -> void:
		_sd = weakref(sd)

	## Cartridges `player` has left.
	func charges(player: int) -> int:
		var sd := _sd.get_ref() as SurvivorDefense
		return sd.charges(player) if sd != null else 0

	## Whether `player` is hidden.
	func is_hidden(player: int) -> bool:
		var sd := _sd.get_ref() as SurvivorDefense
		return sd.is_hidden(player) if sd != null else false


## Injects the round's roster. Call before RoundServer.start_round (setup resets state from it).
## The monster has no items (rule 13); its id is kept only as a taser target (story 002).
func set_roster(survivors: Array[int], monster: int) -> void:
	_survivors = survivors.duplicate()
	_monster = monster


## Story 002: injects the taser trace sources (ADR-0003 §6). `lc` gives the rewind and the rewound
## capsules; `eye_of.call(player) -> Vector3` is the shooter's current eye point (never rewound, §5);
## `frame_of.call(player) -> InputFrame` gives the view yaw and pitch (ServerMovement.frame_of);
## `blocked.call(from, to) -> bool` is true when a wall, glass (PROJECTILE mask) or a closed door leaf
## lies between (unset = nothing blocks). Unset `lc`: fires spend cartridges but trace nothing.
func set_trace(lc: LagCompensation, eye_of: Callable, frame_of: Callable, blocked: Callable = Callable()) -> void:
	_lc = lc
	_eye_of = eye_of
	_frame_of = frame_of
	_blocked = blocked


## Injects the Seized/Downed gate: `source.call(player_id) -> bool` (Downing.action_locked).
## Unset, nobody is locked.
func set_locked(source: Callable) -> void:
	_is_locked = source


## Marks `player` hidden (`on` true) or not. Story 006's hide flow drives this; nothing else should.
func set_hidden(player: int, on: bool) -> void:
	if on:
		_hidden[player] = true
	else:
		_hidden.erase(player)


## Injected by RoundServer. Every survivor starts with `stun_item_charges` cartridges (rules 7, 29),
## no reuse delay, not hidden. Publishes the HIDDEN_ITEM_USE view and subscribes to SurvivorEliminated.
func setup(_tick_runner: TickRunner, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
	_stun_item_charges = knobs.defense.stun_item_charges
	_reuse_ticks = knobs.ticks(knobs.defense.stun_item_reuse_s)
	_charges = {}
	_ready_tick = {}
	_hidden = {}
	_pending = {}
	_queued = []
	_resolved = []
	_use_delay_ticks = knobs.ticks(knobs.defense.stun_use_delay_s)
	_range_m = knobs.defense.stun_range_m
	_aim_tol_rad = deg_to_rad(knobs.defense.stun_aim_tolerance_deg)
	for s in _survivors:
		_charges[s] = _stun_item_charges
	registry.register_view(StateKeys.HIDDEN_ITEM_USE, &"SurvivorDefense", DefenseView.new(self))
	bus.subscribe(&"SurvivorEliminated", _on_eliminated)


## The bytes a survivor's client sends to fire its taser.
static func fire_packet() -> PackedByteArray:
	return var_to_bytes({INTENT_KEY: FIRE})


## The intent in untrusted `bytes`, or INVALID_INTENT when they are not exactly a known intent. Only
## the shape is checked; whether it may run is decided in server_tick.
static func decode_intent(bytes: PackedByteArray) -> int:
	if bytes.is_empty() or bytes.size() > REQUEST_CAP_BYTES:
		return INVALID_INTENT
	var d: Variant = bytes_to_var(bytes)
	if not (d is Dictionary and d.size() == 1 and d.get(INTENT_KEY) is int and d[INTENT_KEY] == FIRE):
		return INVALID_INTENT
	return d[INTENT_KEY]


## Server entry for a client's intent from `player` (the sender as the network layer identifies it,
## never a field of the bytes). Only the first intent of a tick is kept; it is validated at the
## SURVIVOR_DEFENSE step.
func request_intent(player: int, bytes: PackedByteArray) -> void:
	if _pending.has(player):
		return
	var intent := decode_intent(bytes)
	if intent != INVALID_INTENT:
		_pending[player] = intent


## SURVIVOR_DEFENSE slot: validates this tick's fire intents (rules 8, 13). A survivor downed on this
## tick was Seized until Downing's slot (500) and so is already refused here.
func server_tick(tick: int) -> void:
	for p: int in _pending:
		if can_fire(p, tick):
			_charges[p] -= 1
			_ready_tick[p] = tick + _reuse_ticks
			if _lc != null:
				_queued.append(Vector2i(tick + _use_delay_ticks, p))
	_pending = {}
	_resolve_shots(tick)


## Rules 7, 8, 13: `player` is a survivor with a cartridge left, outside the reuse delay, not Seized,
## Downed or hidden on `tick`.
func can_fire(player: int, tick: int) -> bool:
	return _charges.get(player, 0) > 0 and tick >= _ready_tick.get(player, 0) and not is_hidden(player) \
		and not (_is_locked.is_valid() and _is_locked.call(player))


## Cartridges `player` has left (0 for the monster or any id not in the roster).
func charges(player: int) -> int:
	return _charges.get(player, 0)


## Whether `player` is hidden.
func is_hidden(player: int) -> bool:
	return _hidden.has(player)


## Rule 13: charges are lost on elimination.
func _on_eliminated(e: ServerEvent) -> void:
	var s := (e as EvSurvivorEliminated).survivor
	if _charges.has(s):
		_charges[s] = 0


## Story 002: the shots traced on the latest tick, each {shooter, tick, hit (player id or -1),
## reason (SHOT_*)}. Stories 003 and 004 act on them; this story applies nothing.
func resolved_shots() -> Array[Dictionary]:
	return _resolved


## Rule 8 trace, pure: the nearest target in `targets` (LagCompensation.targets_at capsules) whose
## nearest axis point to the ray lies within `range_m` of `origin` and inside the aim tolerance (the
## ray passes within the capsule radius, or the angle to that point is at most `tol_rad`; both bounds
## inclusive). `skip.call(id)` true = not a body (Seized, Downed, hidden: current tick, ADR-0003 §5).
## `blocked.call(origin, point)` true = geometry stops the dart. Returns {hit: id or -1, reason: SHOT_*}.
## Range is measured to the capsule axis, not its surface: inference from the GDD's "5 m" and the AC
## "5.1 m hits nothing"; a designer ruling on surface vs centre distance would settle it.
static func trace(origin: Vector3, dir: Vector3, range_m: float, tol_rad: float, targets: Array,
		skip: Callable, blocked: Callable = Callable()) -> Dictionary:
	var d := dir.normalized()
	var far := origin + d * (range_m * 2.0 + 1.0)
	var best := INF
	var best_point := Vector3.ZERO
	var best_id := -1
	var beyond := false
	for t: Dictionary in targets:
		if skip.is_valid() and skip.call(t.id):
			continue
		var r: float = t.radius
		var pos: Vector3 = t.pos
		var lo := Vector3(pos.x, pos.y + r, pos.z)
		var hi := Vector3(pos.x, maxf(pos.y + r, pos.y + t.height - r), pos.z)
		var p := Geometry3D.get_closest_points_between_segments(origin, far, lo, hi)
		var to: Vector3 = p[1] - origin
		if not (p[0].distance_to(p[1]) <= r or d.angle_to(to) <= tol_rad + TRACE_EPS):
			continue
		var dist := to.length()
		if dist > range_m + TRACE_EPS:
			beyond = true
		elif dist < best:
			best = dist
			best_point = p[1]
			best_id = t.id
	if best_id == -1:
		return {"hit": -1, "reason": SHOT_RANGE if beyond else SHOT_MISSED}
	if blocked.is_valid() and blocked.call(origin, best_point):
		return {"hit": -1, "reason": SHOT_BLOCKED}
	return {"hit": best_id, "reason": SHOT_HIT}


## Traces every queued shot due on `tick` against target positions rewound to the shooter's view tick,
## capped at max_rewind_ms (rule 8, ADR-0003 §3: the lunge's path).
func _resolve_shots(tick: int) -> void:
	_resolved = []
	while not _queued.is_empty() and _queued[0].x <= tick:
		var shooter: int = _queued.pop_front().y
		var ids: Array[int] = []
		for id: int in _survivors + [_monster]:
			if id != shooter and id != -1:
				ids.append(id)
		var targets := _lc.targets_at(tick, _lc.rewind_ticks(shooter, tick), ids)
		var f: InputFrame = _frame_of.call(shooter)
		var r := trace(_eye_of.call(shooter), ViewState.direction(f.yaw, f.pitch), _range_m, _aim_tol_rad,
			targets, _not_a_body, _blocked)
		r["shooter"] = shooter
		r["tick"] = tick
		_resolved.append(r)


## Rule 8: Seized and Downed survivors are not bodies for the shot; nor are hidden ones (story 006).
## Survivors only: the monster mid-takedown is action-locked too, and is exactly whom a rescuer shoots.
func _not_a_body(player: int) -> bool:
	return _survivors.has(player) and (is_hidden(player) or (_is_locked.is_valid() and _is_locked.call(player)))
