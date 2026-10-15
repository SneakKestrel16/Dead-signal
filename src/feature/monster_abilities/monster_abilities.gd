class_name MonsterAbilities extends RefCounted
## Monster Abilities: the shapeshifter's Predatory Lunge, False Signal and Blackout (Feature layer).
## Story monster-abilities/001 implements the request path and the Lunge state machine:
## design/gdd/monster-abilities.md rules 1-4 and "States and Transitions"; ADR-0002 (client sends a
## request and an aim point only, the server validates and owns cooldown and state), ADR-0005 (tick
## order slot MONSTER_ABILITIES), ADR-0006 (AbilityKnobs). Story 002 adds the wind-up root and the dash
## (rules 5-6, ADR-0007) as the "lunge" entry of the monster's MovementModifiers (set_modifiers). Story
## 003 adds the hit test (rules 7-8, ADR-0003 §3-6, set_hit_sources). Story 004 adds the resolution
## paths (rules 9-12, Edge Cases "Monster disconnects mid-lunge") and the miss slow as the "lunge_miss"
## modifier entry (ADR-0007). The False Signal and Blackout bodies (009-010) are not here yet.
## Server only. Timers count ticks of `net.sim_tick_hz`, never wall time.
## Collaborators are injected as Callables (ADR-0005 §6 dependency injection):
##   form() -> int            BorrowedFace.TRUE_FORM or the copied survivor (TransformView.get_form);
##                            unset = true form
##   transforming() -> bool   a transformation in progress (TransformView.get_transforming); unset = never
##   locked(player) -> bool   Stunned or under the shock lock (Survivor Defense rule 14,
##                            StateKeys.SHOCK_STUN_LOCK); unset = never locked
## Usage:
##   var ma := MonsterAbilities.new()
##   ma.set_monster(1)   # BEFORE start_round
##   ma.set_status_sources(view.get_form, view.get_transforming, locked)
##   ma.set_position_source(position_of)   # story 005: AbilityUsed position
##   ma.set_modifiers(server_movement.modifiers_of)
##   ma.set_hit_sources(lc, survivor_ids, downing.eligible, facing_of, sight)   # story 003
##   server.start_round({TickOrder.MONSTER_ABILITIES: ma}, knobs)
##   smp.peer_packet -> ma.request_ability(net.player_id_of(peer), bytes)

## The abilities a request can name.
enum Ability { LUNGE, FALSE_SIGNAL, BLACKOUT }
## Lunge states of "States and Transitions", in GDD order.
enum Lunge { READY, WIND_UP, ACTIVE, TAKEDOWN_COMMIT, RESOLVED, COOLDOWN }

## Explicit transition table: state -> the states it may move to.
const TRANSITIONS: Dictionary[int, Array] = {
	Lunge.READY: [Lunge.WIND_UP],
	Lunge.WIND_UP: [Lunge.ACTIVE, Lunge.RESOLVED],
	Lunge.ACTIVE: [Lunge.TAKEDOWN_COMMIT, Lunge.RESOLVED],
	Lunge.TAKEDOWN_COMMIT: [Lunge.RESOLVED],
	Lunge.RESOLVED: [Lunge.COOLDOWN],
	Lunge.COOLDOWN: [Lunge.READY],
}
## Size cap of a request packet; anything larger is not one (untrusted client bytes).
const REQUEST_CAP_BYTES := 64
## Request packet dictionary keys: only an ability id and an aim point cross the wire.
const ABILITY_KEY := "ability"
const AIM_KEY := "aim"
const REQUEST_FIELDS: Array[String] = [ABILITY_KEY, AIM_KEY]
## The owner of the Lunge's entry in the monster's MovementModifiers.
const MOD_OWNER := &"lunge"
## The owner of the miss slow's entry (rule 10); separate from MOD_OWNER, which every state change clears.
const MISS_SLOW_OWNER := &"lunge_miss"
## Float tolerance of the hit test's inclusive radius and cone bounds (geometry, not a tuning value).
const HIT_EPS := 1e-6

var _monster: int = -1
var _form: Callable
var _transforming: Callable
var _locked: Callable
var _windup_ticks: int = 0
var _dash_ticks: int = 0
var _lunge_cooldown_ticks: int = 0
var _lunge: Lunge = Lunge.READY
## Tick on which the running wind-up or dash ends.
var _phase_end_tick: int = 0
## Ability -> first tick it may be accepted again (rule 3: independent per ability). 0 = ready.
var _ready_tick: Dictionary[int, int] = {}
## The first decoded request since the last tick ({} = none): one request per tick.
var _pending: Dictionary = {}
## player id -> MovementModifiers (ServerMovement.modifiers_of); unset = the Lunge moves nothing.
var _modifiers_of: Callable
## Wind-up and dash turn caps (rad/s) and the dash speed (m/s), from AbilityKnobs in setup.
var _windup_turn: float = 0.0
var _dash_turn: float = 0.0
var _dash_speed: float = 0.0
## Callable(state: Lunge, tick: int) run on every Lunge transition (telemetry, tests); unset = nothing.
var on_lunge_state: Callable
## Story 005: position_of(player) -> Vector3, the monster's server position for AbilityUsed; unset = origin.
var _position_of: Callable
var _bus: EventBus
## Story 003 hit sources (set_hit_sources); _lc null means no hit test runs.
var _lc: LagCompensation
var _survivors: Array[int] = []
var _eligible: Callable
var _facing_of: Callable
var _sight: Callable
## lunge_hit_radius_m and lunge_cone_deg (full cone, rad), from AbilityKnobs in setup.
var _hit_radius: float = 0.0
var _cone: float = 0.0
## Rule 10: miss_slow_multiplier and miss_slow_s in ticks, from AbilityKnobs in setup.
var _miss_slow_mult: float = 0.0
var _miss_slow_ticks: int = 0
## Tick the running miss slow ends; -1 = none.
var _miss_slow_end: int = -1


## Injects the shapeshifter's player id. Call before RoundServer.start_round.
func set_monster(monster: int) -> void:
	_monster = monster


## Injects the position source for AbilityUsed (story 005; ServerMovement's body position).
func set_position_source(position_of: Callable) -> void:
	_position_of = position_of


## Story 003: injects the hit test sources (rule 7, ADR-0003 §3-6). `lc` gives the rewind and the
## rewound capsules, and the monster's current chest (the attack point: body centre at chest height);
## `survivors` are the targets; `eligible.call(player) -> bool` is Downing.eligible (Healthy, not hidden,
## no grace, not Seized; current tick, never rewound; unset = every survivor); `facing_of.call(player)
## -> Vector3` is the monster's current facing (only its horizontal part is used); `sight.call(from, to)
## -> bool` is true when nothing blocks (MapQueries.clear_sight with InteractRules.door_closed; current
## door state; unset = always clear). Unset `lc`: the dash never hits.
func set_hit_sources(lc: LagCompensation, survivors: Array[int], eligible: Callable, facing_of: Callable,
		sight: Callable = Callable()) -> void:
	_lc = lc
	_survivors = survivors.duplicate()
	_eligible = eligible
	_facing_of = facing_of
	_sight = sight


## The shapeshifter's player id (-1 before set_monster).
func monster() -> int:
	return _monster


## Injects the status collaborators (see the class comment).
func set_status_sources(form: Callable, transforming: Callable, locked: Callable = Callable()) -> void:
	_form = form
	_transforming = transforming
	_locked = locked


## The bytes the shapeshifter's client sends to request `ability` at `aim` (ignored by Lunge).
static func request_packet(ability: Ability, aim: Vector3 = Vector3.ZERO) -> PackedByteArray:
	return var_to_bytes({ABILITY_KEY: ability, AIM_KEY: aim})


## The request in untrusted `bytes` as {ability, aim}, or {} when they are not one. Only checks the
## shape; whether the ability may activate is decided in server_tick.
static func decode_request(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > REQUEST_CAP_BYTES:
		return {}
	var d: Variant = bytes_to_var(bytes)
	if not (d is Dictionary and d.size() == REQUEST_FIELDS.size() and d.get(ABILITY_KEY) is int and d.get(AIM_KEY) is Vector3):
		return {}
	var aim: Vector3 = d[AIM_KEY]
	if not Ability.values().has(d[ABILITY_KEY]) or not aim.is_finite():
		return {}
	return {ABILITY_KEY: d[ABILITY_KEY], AIM_KEY: aim}


## Server entry for a client's ability request from `player` (the sender as the network layer
## identifies it, never a field of the bytes). Ignored unless it is the shapeshifter and the bytes
## decode; only the first request of a tick is kept, and it is validated at the MONSTER_ABILITIES step.
func request_ability(player: int, bytes: PackedByteArray) -> void:
	if player != _monster or not _pending.is_empty():
		return
	_pending = decode_request(bytes)


## Injected by RoundServer. Reads knobs and puts every ability Ready with no cooldown. Subscribes to
## SurvivorHit (Active -> Takedown Commit), the commit's end (SurvivorDowned, SurvivorEliminated) and
## MonsterStunned (interrupt) and PlayerConnectionChanged (disconnect). Publishes the Lunge state as StateKeys.LUNGE_STATE (story 005).
func setup(_tick_runner: TickRunner, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
	_bus = bus
	registry.register_view(StateKeys.LUNGE_STATE, &"MonsterAbilities", LungeView.new(self))
	_windup_ticks = knobs.ticks(knobs.ability.lunge_windup_s)
	_dash_ticks = knobs.ticks(knobs.ability.lunge_dash_s)
	_lunge_cooldown_ticks = knobs.ticks(knobs.ability.lunge_cooldown_s)
	_windup_turn = deg_to_rad(knobs.ability.lunge_windup_turn_deg_s)
	_dash_turn = deg_to_rad(knobs.ability.lunge_dash_turn_deg_s)
	_hit_radius = knobs.ability.lunge_hit_radius_m
	_cone = deg_to_rad(knobs.ability.lunge_cone_deg)
	_miss_slow_mult = knobs.ability.miss_slow_multiplier
	_miss_slow_ticks = knobs.ticks(knobs.ability.miss_slow_s)
	_miss_slow_end = -1
	# Rule 6: lunge_distance_m over exactly the dash's whole ticks, so tick quantisation of lunge_dash_s
	# changes the speed, never the distance.
	# A dash of 0 ticks moves nothing.
	_dash_speed = 0.0 if _dash_ticks == 0 else knobs.ability.lunge_distance_m * knobs.net.sim_tick_hz / _dash_ticks
	_lunge = Lunge.READY
	_pending = {}
	_ready_tick = {}
	for a: int in Ability.values():
		_ready_tick[a] = 0
	bus.subscribe(&"SurvivorHit", _on_survivor_hit)
	bus.subscribe(&"SurvivorDowned", _on_commit_end)
	bus.subscribe(&"SurvivorEliminated", _on_commit_end)
	bus.subscribe(&"MonsterStunned", _on_monster_stunned)
	bus.subscribe(&"PlayerConnectionChanged", _on_connection_changed)


## MONSTER_ABILITIES slot: the miss slow's end, timed Lunge transitions due this tick, the hit test on every Active tick
## (the first and the last included), then this tick's request. A lunge resolving or a cooldown ending
## this tick frees the request on the same tick.
func server_tick(tick: int) -> void:
	if _miss_slow_end >= 0 and tick >= _miss_slow_end:
		_end_miss_slow()
	if _lunge == Lunge.WIND_UP and tick >= _phase_end_tick:
		_set_lunge(Lunge.ACTIVE, tick)
		_phase_end_tick = tick + _dash_ticks
	elif _lunge == Lunge.COOLDOWN and tick >= _ready_tick[Ability.LUNGE]:
		_set_lunge(Lunge.READY, tick)
	# A hit moves the Lunge to Takedown Commit when SurvivorHit is flushed at the end of this tick.
	if _lunge == Lunge.ACTIVE and not _try_hit(tick) and (tick >= _phase_end_tick or _dash_blocked()):
		_resolve(tick) ## dash end with no hit, or stopped by an obstacle (rule 6): a miss
		# Rule 12: a stun landing this tick (not flushed yet; see _try_hit) interrupts it: no slow.
		if not (_locked.is_valid() and _locked.call(_monster)):
			_start_miss_slow(tick)
	var req := _pending
	_pending = {}
	if req.is_empty() or not can_activate(req[ABILITY_KEY], tick):
		return ## rule 1: a rejection has no effect and costs no cooldown
	if req[ABILITY_KEY] == Ability.LUNGE:
		_set_lunge(Lunge.WIND_UP, tick)
		_phase_end_tick = tick + _windup_ticks
		_emit_used(Ability.LUNGE, req[AIM_KEY])
	# False Signal and Blackout bodies (and their cooldown start) arrive in stories 009-010.


## Rules 2 and 4: whether `ability` may activate now. Lunge needs Ready and true form; no ability while
## Stunned, shock-locked, Transforming, or in Lunge wind-up, Active or takedown commit. Cooldowns are
## per ability (rule 3).
func can_activate(ability: Ability, tick: int) -> bool:
	if tick < _ready_tick[ability] or attacking():
		return false
	if _locked.is_valid() and _locked.call(_monster):
		return false
	if _transforming.is_valid() and _transforming.call():
		return false
	if ability == Ability.LUNGE:
		return _lunge == Lunge.READY and (not _form.is_valid() or _form.call() == BorrowedFace.TRUE_FORM)
	return true


## True in Lunge wind-up, Active or takedown commit (rule 2; Borrowed Face rule 7 reads it).
func attacking() -> bool:
	return _lunge == Lunge.WIND_UP or _lunge == Lunge.ACTIVE or _lunge == Lunge.TAKEDOWN_COMMIT


## Injects the movement modifier sets: `source.call(player_id) -> MovementModifiers`, null for a
## player with no body (ServerMovement.modifiers_of in the composer). Unset, the Lunge moves nothing.
func set_modifiers(source: Callable) -> void:
	_modifiers_of = source


## Current Lunge state.
func lunge_state() -> Lunge:
	return _lunge


## First tick `ability` may be accepted again; 0 = no cooldown has run this round.
func ready_tick(ability: Ability) -> int:
	return _ready_tick[ability]


## Rules 7-8, pure: the closest target in `targets` (LagCompensation.targets_at capsules plus "id" and
## "chest") with `eligible.call(id)`, its capsule surface within `radius_m` of `attack`, inside the cone
## `cone_rad` wide centred on `forward`, and `sight.call(attack, chest)` clear. Bounds are
## inclusive. Equal distances go to the lower player id. Returns {hit: id or -1, pos: that target's pos}.
## Inference: the cone is horizontal and measured to the nearest point of the capsule axis (the body
## centre line), as the Formulas' steering check treats it; a designer ruling on body edge vs centre
## would settle it.
## Example: `hit_test(Vector3(0, 1.5, 0), Vector3.FORWARD, 1.2, PI / 3, targets, downing.eligible)`
static func hit_test(attack: Vector3, forward: Vector3, radius_m: float, cone_rad: float, targets: Array,
		eligible: Callable, sight: Callable = Callable()) -> Dictionary:
	var fwd := Vector2(forward.x, forward.z)
	var best := INF
	var best_id := -1
	var best_pos := Vector3.ZERO
	for t: Dictionary in targets:
		if eligible.is_valid() and not eligible.call(t.id):
			continue
		var r: float = t.radius
		var pos: Vector3 = t.pos
		var lo := Vector3(pos.x, pos.y + r, pos.z)
		var hi := Vector3(pos.x, maxf(pos.y + r, pos.y + t.height - r), pos.z)
		var near := Geometry3D.get_closest_point_to_segment(attack, lo, hi)
		var dist := attack.distance_to(near) - r
		if dist > radius_m + HIT_EPS:
			continue
		var to := Vector2(near.x - attack.x, near.z - attack.z)
		var off := absf(fwd.angle_to(to))
		if not to.is_zero_approx() and off + off > cone_rad + HIT_EPS: ## off-axis angle within half the cone
			continue
		if sight.is_valid() and not sight.call(attack, t.chest):
			continue
		if dist < best or (dist == best and t.id < best_id):
			best = dist
			best_id = t.id
			best_pos = pos
	return {"hit": best_id, "pos": best_pos}


## Rule 7 on server tick `tick`: survivor positions rewound to the monster's view (capped at
## max_rewind_ms, ADR-0003 §3); the attack point, facing, eligibility, doors and the stun are current.
## A stun since wind-up has already resolved the lunge (_on_monster_stunned); one landing this tick is
## not flushed yet, so the locked source (Stunned or shock-locked) is checked here too. Emits SurvivorHit
## once and returns true on a hit. Clamps and out-of-history samples are logged by LagCompensation.
func _try_hit(tick: int) -> bool:
	if _lc == null or (_locked.is_valid() and _locked.call(_monster)):
		return false
	var me_id: Array[int] = [_monster]
	var me := _lc.targets_at(tick, 0.0, me_id)
	if me.is_empty():
		return false
	var attack: Vector3 = me[0].chest
	var forward: Vector3 = _facing_of.call(_monster) if _facing_of.is_valid() else Vector3.FORWARD
	var targets := _lc.targets_at(tick, _lc.rewind_ticks(_monster, tick), _survivors)
	var r := hit_test(attack, forward, _hit_radius, _cone, targets, _eligible, _sight)
	if r.hit == -1:
		return false
	var e := EvSurvivorHit.new()
	e.monster = _monster
	e.survivor = r.hit
	e.position = r.pos
	_bus.emit(e)
	return true


## Resolved, then immediately Cooldown; the cooldown runs from resolution (rule 9) on every path: miss,
## commit end, stun, disconnect. Only the miss path adds the slow (server_tick).
func _resolve(tick: int) -> void:
	_set_lunge(Lunge.RESOLVED, tick)
	_ready_tick[Ability.LUNGE] = tick + _lunge_cooldown_ticks
	_set_lunge(Lunge.COOLDOWN, tick)


func _set_lunge(state: Lunge, tick: int) -> void:
	if not TRANSITIONS[_lunge].has(state):
		push_error("MonsterAbilities: illegal Lunge transition %d -> %d" % [_lunge, state])
		return
	_lunge = state
	_apply_lunge_modifiers(state)
	if on_lunge_state.is_valid():
		on_lunge_state.call(state, tick)


## Rule 8: a hit ends the dash and starts Downing's takedown commit.
func _on_survivor_hit(e: ServerEvent) -> void:
	if _lunge == Lunge.ACTIVE:
		_set_lunge(Lunge.TAKEDOWN_COMMIT, e.tick)


## Rule 9: the commit completes with SurvivorDowned or SurvivorEliminated. Inference: one shapeshifter,
## so any such event during the commit is this commit's end (neither event names the monster); an
## elimination outside a commit (bleed-out) arrives while not in Takedown Commit and is ignored.
func _on_commit_end(e: ServerEvent) -> void:
	if _lunge == Lunge.TAKEDOWN_COMMIT:
		_resolve(e.tick)


## Rule 12 and "States and Transitions": a stun in wind-up or Active interrupts the lunge, and in the
## takedown commit cancels it (Downing cancels the commit on the same event); either way it resolves.
## Rule 12 "the stun replaces the miss slow": a stun also ends a running miss slow (a stun landing on
## the dash's last tick after this module's slot resolved the miss is flushed only now).
func _on_monster_stunned(e: ServerEvent) -> void:
	if (e as EvMonsterStunned).monster != _monster:
		return
	if attacking():
		_resolve(e.tick)
	_end_miss_slow()


## Edge Cases "Monster disconnects mid-lunge": the wind-up or dash ends with no hit and no slow. A commit
## also resolves here, as Downing cancels it on the same event. Inference: a hit landing on the disconnect
## tick is already emitted (the event is flushed after this slot), so it becomes a commit Downing cancels;
## a connected-state source read in _try_hit would settle it if the GDD wants no SurvivorHit at all.
func _on_connection_changed(e: ServerEvent) -> void:
	var c := e as EvPlayerConnectionChanged
	if c.player == _monster and c.status == EvPlayerConnectionChanged.DISCONNECTED and attacking():
		_resolve(e.tick)


## Rule 10: the monster moves at miss_slow_multiplier for miss_slow_s from the miss's resolution tick.
func _start_miss_slow(tick: int) -> void:
	var mods := _monster_mods()
	if mods == null or _miss_slow_ticks <= 0:
		return
	mods.add(MISS_SLOW_OWNER, MovementModifiers.Kind.SLOW, _miss_slow_mult)
	_miss_slow_end = tick + _miss_slow_ticks


func _end_miss_slow() -> void:
	_miss_slow_end = -1
	var mods := _monster_mods()
	if mods != null:
		mods.remove(MISS_SLOW_OWNER)


## Rule 3a (story 005): one AbilityUsed per accepted activation, at Lunge wind-up start. Server-internal:
## its project() is empty (ADR-0004 §5). Inference: Lunge has no aimed target, so `target` carries the
## request's aim point; the GDD's "target point or zone" for Lunge (facing-based?) would settle it.
func _emit_used(ability: Ability, target: Vector3) -> void:
	var e := EvAbilityUsed.new()
	e.ability = ability
	e.position = _position_of.call(_monster) if _position_of.is_valid() else Vector3.ZERO
	e.target = target
	_bus.emit(e)


## Rules 5-6 as the monster's "lunge" modifier: wind-up roots and caps the turn; Active forces the dash
## and caps its steering; any other state removes the entry.
func _apply_lunge_modifiers(state: Lunge) -> void:
	var mods := _monster_mods()
	if mods == null:
		return
	mods.remove(MOD_OWNER)
	if state == Lunge.WIND_UP:
		mods.add(MOD_OWNER, MovementModifiers.Kind.ROOT)
		mods.set_turn_cap(MOD_OWNER, _windup_turn)
	elif state == Lunge.ACTIVE:
		mods.set_turn_cap(MOD_OWNER, _dash_turn)
		mods.set_dash(MOD_OWNER, _dash_speed)


func _dash_blocked() -> bool:
	var mods := _monster_mods()
	return mods != null and mods.dash_blocked


func _monster_mods() -> MovementModifiers:
	return _modifiers_of.call(_monster) as MovementModifiers if _modifiers_of.is_valid() else null
