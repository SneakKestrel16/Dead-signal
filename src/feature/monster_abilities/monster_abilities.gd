class_name MonsterAbilities extends RefCounted
## Monster Abilities: the shapeshifter's Predatory Lunge, False Signal and Blackout (Feature layer).
## Story monster-abilities/001 implements the request path and the Lunge state machine:
## design/gdd/monster-abilities.md rules 1-4 and "States and Transitions"; ADR-0002 (client sends a
## request and an aim point only, the server validates and owns cooldown and state), ADR-0005 (tick
## order slot MONSTER_ABILITIES), ADR-0006 (AbilityKnobs). Story 002 adds the wind-up root and the dash
## (rules 5-6, ADR-0007) as the "lunge" entry of the monster's MovementModifiers (set_modifiers). Story
## 003 adds the hit test (rules 7-8, ADR-0003 §3-6, set_hit_sources). Story 004 adds the resolution
## paths (rules 9-12, Edge Cases "Monster disconnects mid-lunge") and the miss slow as the "lunge_miss"
## modifier entry (ADR-0007). Story 010 adds the Blackout body (rules 17, 20, 21; ADR-0009): target
## validation through LightingView, the cooldown from activation, and AbilityUsed; FacilityLighting darkens
## the zone and the backup switch (BackupSwitch) restores it. Story 009 adds the False Signal body (rules
## 13-16, ADR-0004 §5-6, ADR-0013): a signal request (signal_packet), its validation, the cooldown from
## activation, and the fake as the same positional sound a real one sends (set_false_signal_sources).
## Server only. Timers count ticks of `net.sim_tick_hz`, never wall time.
## Collaborators are injected as Callables (ADR-0005 §6 dependency injection):
##   form() -> int            unused since story 012 (a Lunge is accepted in any form); kept in the
##                            signature so the composer and tests need no change
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
##   ma.set_blackout_sources(map_queries.volume_at, blackout_sight)   # story 010
##   ma.set_sound_sink(server_movement.emit_sound)   # story 007: lunge cue, scrape and hit sounds
##   ma.set_false_signal_sources(server_movement.emit_sound, snap, bf.observed, match_flow.status_of,
##       footstep_set_of, {SurvivorObjectives.INSTALL_SOUND: radius}, step_s, path_end)   # story 009
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
## Story 007 positional sound sets (Visual/Audio Requirements; ADR-0013 §2 catalog ids): the wind-up cue
## (rule 5), the miss scrape and the server-confirmed hit. All three go out at lunge_cue_radius_m.
## Inference: the GDD gives a radius for the cue only; the scrape and hit reuse it until a sound designer
## sets their own (a lunge_scrape/hit radius knob would settle it).
const CUE_SOUND := &"lunge_cue"
const SCRAPE_SOUND := &"lunge_scrape"
const HIT_SOUND := &"lunge_hit"

var _monster: int = -1
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
## Story 008 round stats (StateKeys.STATS_ABILITIES via AbilitiesRoundStatsView): the tick of each landed,
## missed and interrupted lunge this round; counts are their sizes. Cleared in setup.
var _landed_ticks: Array[int] = []
var _missed_ticks: Array[int] = []
var _interrupted_ticks: Array[int] = []
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
## Story 010 Blackout sources (set_blackout_sources) and knobs; unset _volume_at rejects every Blackout.
var _registry: StateRegistry
var _volume_at: Callable
var _blackout_sight: Callable
var _blackout_range: float = 0.0
var _blackout_cooldown_ticks: int = 0
## Accepted Blackouts this round (ADR-0011 `stats.abilities`; story 008's AbilitiesStatsView subclass reads it).
## Ticks (a list, not a counter: request_validation_test bars the literal 1, a knob value).
var _blackout_ticks: Array[int] = []

## Story 009: False Signal signal types (rule 14), and their AbilityUsed `detail`.
enum SignalType { CALLOUT, FOOTSTEPS, INTERACTION }
const SIGNAL_DETAILS: Array[StringName] = [&"callout", &"footsteps", &"interaction"]
## Extra keys of a False Signal request: signal type, survivor (callout voice / footstep set), footstep
## direction, interaction sound set (a callout: the line id, pings-and-callouts/003).
const TYPE_KEY := "type"
const SURVIVOR_KEY := "survivor"
const DIR_KEY := "dir"
const SOUND_KEY := "sound"
const SIGNAL_FIELDS: Array[String] = [ABILITY_KEY, AIM_KEY, TYPE_KEY, SURVIVOR_KEY, DIR_KEY, SOUND_KEY]
## Size cap of a False Signal request (untrusted client bytes); room for a short sound set name.
const SIGNAL_CAP_BYTES := 192
## Story 009 sources (set_false_signal_sources); unset _snap rejects every False Signal.
var _emit_sound: Callable
## Story 007: send radius of the Lunge sounds (AbilityKnobs.lunge_cue_radius_m).
var _cue_radius: float = 0.0
var _snap: Callable
var _observed: Callable
var _status_of: Callable
var _footstep_set_of: Callable
var _interaction_radius: Dictionary[StringName, float] = {}
var _step_s: float = 0.0
var _path_end: Callable
## False Signal knobs (AbilityKnobs; walk speed and the walk footstep radius from ControllerKnobs).
var _signal_range: float = 0.0
var _signal_cooldown_ticks: int = 0
var _footstep_ticks: int = 0
var _step_ticks: int = 0
var _walk_speed: float = 0.0
var _walk_radius: float = 0.0
var _hz: float = 0.0
## Accepted False Signals this round, as accept ticks (see _blackout_ticks).
var _signal_ticks: Array[int] = []
## Running fake footsteps: start point, unit direction, path length, footstep set, first and end tick.
var _steps_from := Vector3.ZERO
var _steps_dir := Vector3.ZERO
var _steps_len: float = 0.0
var _steps_set: StringName = &""
var _steps_start: int = 0
var _steps_end: int = -1


## Injects the shapeshifter's player id. Call before RoundServer.start_round.
func set_monster(monster: int) -> void:
	_monster = monster


## Injects the position source for AbilityUsed (story 005; ServerMovement's body position).
func set_position_source(position_of: Callable) -> void:
	_position_of = position_of


## Story 007: injects the positional sound sink, `emit_sound(position, sound_set, radius_m)`
## (ServerMovement.emit_sound, no source: the monster's own client hears its cue too). Shared with
## set_false_signal_sources, which sets the same sink. Unset: the Lunge sends no sound.
func set_sound_sink(emit_sound: Callable) -> void:
	_emit_sound = emit_sound


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


## Story 010: injects the Blackout target sources (rule 17). `volume_at.call(point) -> StringName` is
## MapQueries.volume_at (&"" outside every lighting volume); `sight.call(monster, aim) -> bool` is true
## when the monster's eye sees `aim` (MapQueries.clear_sight in the composer; unset = always clear).
## Unset `volume_at`: every Blackout is rejected.
func set_blackout_sources(volume_at: Callable, sight: Callable = Callable()) -> void:
	_volume_at = volume_at
	_blackout_sight = sight


## Story 009: injects the False Signal sources (rules 13-15). `emit_sound(position, sound_set, radius_m)` is
## ServerMovement.emit_sound, the send real sounds use (no source: every listener in range gets it);
## `snap(point) -> Variant` is the nearest walkable floor point, or null inside a wall or off the
## facility (unset: every False Signal is rejected); `observed(survivor) -> bool` is BorrowedFace.observed;
## `status_of(survivor) -> int` is MatchFlow.status_of (unset: every survivor in play);
## `footstep_set_of(survivor) -> StringName` is the catalog id of that survivor's walk footsteps, the same
## one their real footsteps send (&"" for a non-survivor); `interaction_radius` maps each imitable
## interaction sound set to the radius its real sound is sent with; `step_s` is the real walk footstep
## interval; `path_end(from, to) -> Vector3` cuts the footstep path at the first wall or the facility edge
## and ends it on walkable floor (unset: a straight path).
## Inference: no real footstep emitter or walk cadence knob exists yet, so the composer passes the cadence
## its real footsteps use; a Controller cadence knob would settle it.
func set_false_signal_sources(emit_sound: Callable, snap: Callable, observed: Callable, status_of: Callable,
		footstep_set_of: Callable, interaction_radius: Dictionary[StringName, float], step_s: float,
		path_end: Callable = Callable()) -> void:
	_emit_sound = emit_sound
	_snap = snap
	_observed = observed
	_status_of = status_of
	_footstep_set_of = footstep_set_of
	_interaction_radius = interaction_radius.duplicate()
	_step_s = step_s
	_path_end = path_end


## False Signals accepted this round (results payload, ADR-0011 `stats.abilities`).
func falsesignals_used() -> int:
	return _signal_ticks.size()


## The bytes the shapeshifter's client sends for a False Signal of `type` aimed at `aim`. `survivor` is
## the impersonated voice (CALLOUT) or footstep set (FOOTSTEPS); `dir` the footstep direction; `sound`
## the interaction sound set (INTERACTION) or the callout line id (CALLOUT, PingsCallouts.CALLOUT_LINES).
static func signal_packet(type: SignalType, aim: Vector3, survivor: int = -1, dir: Vector3 = Vector3.ZERO,
		sound: StringName = &"") -> PackedByteArray:
	return var_to_bytes({ABILITY_KEY: Ability.FALSE_SIGNAL, AIM_KEY: aim, TYPE_KEY: type,
		SURVIVOR_KEY: survivor, DIR_KEY: dir, SOUND_KEY: sound})


## The False Signal request in untrusted `bytes`, or {} when they are not one. Only checks the shape.
static func decode_signal(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > SIGNAL_CAP_BYTES:
		return {}
	var d: Variant = bytes_to_var(bytes)
	if not (d is Dictionary and d.size() == SIGNAL_FIELDS.size()):
		return {}
	if not (d.get(ABILITY_KEY) is int and d.get(AIM_KEY) is Vector3 and d.get(TYPE_KEY) is int
			and d.get(SURVIVOR_KEY) is int and d.get(DIR_KEY) is Vector3 and d.get(SOUND_KEY) is StringName):
		return {}
	var aim: Vector3 = d[AIM_KEY]
	var dir: Vector3 = d[DIR_KEY]
	if d[ABILITY_KEY] != Ability.FALSE_SIGNAL or not SignalType.values().has(d[TYPE_KEY]) \
			or not aim.is_finite() or not dir.is_finite():
		return {}
	var out := {}
	for k: String in SIGNAL_FIELDS:
		out[k] = d[k]
	return out


## Rules 13-14: the snapped floor point of the False Signal `req`, or null when it is rejected. The aim
## point must be within false_signal_range_m of the monster (inclusive) and snap to walkable floor; a
## callout must name an observed survivor who is not Eliminated or Escaped; footsteps need a survivor's
## footstep set and a horizontal direction; an interaction sound must be one a real interaction sends.
## Inference: the range is measured to the requested aim point, before snapping.
func false_signal_point(req: Dictionary) -> Variant:
	if not _snap.is_valid() or not req.has(TYPE_KEY):
		return null
	var at: Vector3 = _position_of.call(_monster) if _position_of.is_valid() else Vector3.ZERO
	if at.distance_to(req[AIM_KEY]) > _signal_range + HIT_EPS:
		return null
	var s: int = req[SURVIVOR_KEY]
	match req[TYPE_KEY]:
		SignalType.CALLOUT:
			if not (_observed.is_valid() and _observed.call(s)):
				return null
			if _status_of.is_valid() and _status_of.call(s) in [MatchFlow.Status.ELIMINATED, MatchFlow.Status.ESCAPED]:
				return null
		SignalType.FOOTSTEPS:
			var d: Vector3 = req[DIR_KEY]
			if not _footstep_set_of.is_valid() or _footstep_set_of.call(s) == &"" or Vector2(d.x, d.z).is_zero_approx():
				return null
		SignalType.INTERACTION:
			if not _interaction_radius.has(req[SOUND_KEY]):
				return null
	return _snap.call(req[AIM_KEY])

func blackouts_used() -> int:
	return _blackout_ticks.size()


## The shapeshifter's player id (-1 before set_monster).
func monster() -> int:
	return _monster


## Injects the status collaborators (see the class comment).
func set_status_sources(_form: Callable, transforming: Callable, locked: Callable = Callable()) -> void:
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
	if _pending.is_empty():
		_pending = decode_signal(bytes)


## Injected by RoundServer. Reads knobs and puts every ability Ready with no cooldown. Subscribes to
## SurvivorHit (Active -> Takedown Commit), the commit's end (SurvivorDowned, SurvivorEliminated) and
## MonsterStunned (interrupt) and PlayerConnectionChanged (disconnect). Publishes the Lunge state as StateKeys.LUNGE_STATE (story 005).
func setup(_tick_runner: TickRunner, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
	_bus = bus
	registry.register_view(StateKeys.LUNGE_STATE, &"MonsterAbilities", LungeView.new(self))
	registry.register_view(StateKeys.STATS_ABILITIES, &"MonsterAbilities", AbilitiesRoundStatsView.new(self))
	_landed_ticks.clear()
	_missed_ticks.clear()
	_interrupted_ticks.clear()
	_windup_ticks = knobs.ticks(knobs.ability.lunge_windup_s)
	_dash_ticks = knobs.ticks(knobs.ability.lunge_dash_s)
	_lunge_cooldown_ticks = knobs.ticks(knobs.ability.lunge_cooldown_s)
	_windup_turn = deg_to_rad(knobs.ability.lunge_windup_turn_deg_s)
	_dash_turn = deg_to_rad(knobs.ability.lunge_dash_turn_deg_s)
	_hit_radius = knobs.ability.lunge_hit_radius_m
	_cue_radius = knobs.ability.lunge_cue_radius_m
	_cone = deg_to_rad(knobs.ability.lunge_cone_deg)
	_miss_slow_mult = knobs.ability.miss_slow_multiplier
	_miss_slow_ticks = knobs.ticks(knobs.ability.miss_slow_s)
	_miss_slow_end = -1
	_registry = registry
	_blackout_range = knobs.ability.blackout_range_m
	_blackout_cooldown_ticks = knobs.ticks(knobs.ability.blackout_cooldown_s)
	_blackout_ticks = []
	_signal_range = knobs.ability.false_signal_range_m
	_signal_cooldown_ticks = knobs.ticks(knobs.ability.false_signal_cooldown_s)
	_footstep_ticks = knobs.ticks(knobs.ability.false_signal_footstep_duration_s)
	_step_ticks = knobs.ticks(_step_s)
	_walk_speed = knobs.controller.walk_speed
	_walk_radius = knobs.controller.footstep_radius_walk_m
	_hz = knobs.net.sim_tick_hz
	_signal_ticks = []
	_steps_end = -1
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
		_missed_ticks.append(tick)
		# Rule 12: a stun landing this tick (not flushed yet; see _try_hit) interrupts it: no slow.
		if not (_locked.is_valid() and _locked.call(_monster)):
			_start_miss_slow(tick)
			_emit(_monster_at(), SCRAPE_SOUND, _cue_radius) ## story 007: the miss scrape and stumble
	_step_footsteps(tick)
	var req := _pending
	_pending = {}
	if req.is_empty() or not can_activate(req[ABILITY_KEY], tick):
		return ## rule 1: a rejection has no effect and costs no cooldown
	if req[ABILITY_KEY] == Ability.LUNGE:
		_set_lunge(Lunge.WIND_UP, tick)
		_phase_end_tick = tick + _windup_ticks
		# Story 007, rule 5: the cue goes out from the Lunge state (AbilityUsed is never replicated), so it
		# reaches every client in range lunge_windup_s before the dash.
		_emit(_monster_at(), CUE_SOUND, _cue_radius)
		_emit_used(Ability.LUNGE, req[AIM_KEY])
	elif req[ABILITY_KEY] == Ability.BLACKOUT and blackout_target_ok(req[AIM_KEY]):
		_ready_tick[Ability.BLACKOUT] = tick + _blackout_cooldown_ticks ## rule 21: from activation
		_blackout_ticks.append(tick)
		_emit_used(Ability.BLACKOUT, req[AIM_KEY]) ## FacilityLighting darkens volume_at(aim) at flush
	elif req[ABILITY_KEY] == Ability.FALSE_SIGNAL:
		var point: Variant = false_signal_point(req)
		if point == null:
			return
		_ready_tick[Ability.FALSE_SIGNAL] = tick + _signal_cooldown_ticks ## rule 16: from activation
		_signal_ticks.append(tick)
		_start_signal(req, point, tick)
		_emit_used(Ability.FALSE_SIGNAL, point, SIGNAL_DETAILS[req[TYPE_KEY]], req[SURVIVOR_KEY],
			req[SOUND_KEY] if req[TYPE_KEY] == SignalType.CALLOUT else &"")


## Rule 15: the fake goes out as the positional sound the real one sends (ADR-0004 §6: position and set
## only). A callout is only AbilityUsed: Pings & Callouts owns its voice line and feed line (story note).
## An interaction sound is a sound only, so no objective state changes.
func _start_signal(req: Dictionary, point: Vector3, tick: int) -> void:
	if req[TYPE_KEY] == SignalType.INTERACTION:
		_emit(point, req[SOUND_KEY], _interaction_radius[req[SOUND_KEY]])
	elif req[TYPE_KEY] == SignalType.FOOTSTEPS:
		var d: Vector3 = req[DIR_KEY]
		_steps_dir = Vector3(d.x, 0.0, d.z).normalized()
		_steps_from = point
		var end: Vector3 = point + _steps_dir * _walk_speed * _footstep_ticks / _hz
		if _path_end.is_valid():
			end = _path_end.call(point, end)
		_steps_len = point.distance_to(end)
		_steps_set = _footstep_set_of.call(req[SURVIVOR_KEY])
		_steps_start = tick
		# Rule 14 and Edge Cases: the steps stop at the path end (a wall cuts them short).
		_steps_end = tick + mini(_footstep_ticks, ceili(_steps_len / _walk_speed * _hz - HIT_EPS)) if _walk_speed > 0.0 else tick
		_step_footsteps(tick)


## Rule 14: one walk footstep every step_s while the fake runs, at its current point along the path at
## walk_speed, sent at the walk radius around that point (rule 15). The activation tick sends the first.
## Inference: Facility Map footstep masking (ADR-0013 §7) is not applied; the real footstep sender, which
## does not exist yet, should apply it to both.
func _step_footsteps(tick: int) -> void:
	if _steps_end < 0:
		return
	if tick >= _steps_end and tick > _steps_start:
		_steps_end = -1
		return
	var n := tick - _steps_start
	if n == 0 or (_step_ticks > 0 and n % _step_ticks == 0):
		_emit(_steps_from + _steps_dir * minf(_walk_speed * n / _hz, _steps_len), _steps_set, _walk_radius)


func _monster_at() -> Vector3:
	return _position_of.call(_monster) if _position_of.is_valid() else Vector3.ZERO


func _emit(position: Vector3, sound_set: StringName, radius_m: float) -> void:
	if _emit_sound.is_valid():
		_emit_sound.call(position, sound_set, radius_m)


## Rules 17 and 20: the lighting volume at `aim` may be blacked out now. It must exist, be blackout_able
## and not already dark (LightingView, ADR-0009 §4), and be the monster's own volume or have `aim` within
## blackout_range_m of the monster with line of sight. Bounds are inclusive. Inference: range is the
## straight distance from the monster's position to the aim point; a ruling on "zone within 15 m"
## (nearest edge vs aim point) would settle it.
func blackout_target_ok(aim: Vector3) -> bool:
	if not _volume_at.is_valid():
		return false
	var zone: StringName = _volume_at.call(aim)
	if zone == &"":
		return false
	var lighting := _registry.view(StateKeys.BLACKOUT_ABLE, LightingView) as LightingView
	if lighting == null or not lighting.is_blackout_able(zone) or lighting.is_dark(zone):
		return false
	var at: Vector3 = _position_of.call(_monster) if _position_of.is_valid() else Vector3.ZERO
	if _volume_at.call(at) == zone:
		return true
	if at.distance_to(aim) > _blackout_range + HIT_EPS:
		return false
	return not _blackout_sight.is_valid() or _blackout_sight.call(_monster, aim)


## Rules 2 and 4: whether `ability` may activate now. Lunge needs Ready, in any form (story 012, designer
## decision 2026-10-15: a disguised lunge reveals true form through Borrowed Face's AbilityUsed); no ability while
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
		return _lunge == Lunge.READY
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
		_landed_ticks.append(e.tick)
		_emit((e as EvSurvivorHit).position, HIT_SOUND, _cue_radius) ## story 007: server-confirmed hit
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
		_count_interrupt(e.tick)
		_resolve(e.tick)
	_end_miss_slow()


## Edge Cases "Monster disconnects mid-lunge": the wind-up or dash ends with no hit and no slow. A commit
## also resolves here, as Downing cancels it on the same event. Inference: a hit landing on the disconnect
## tick is already emitted (the event is flushed after this slot), so it becomes a commit Downing cancels;
## a connected-state source read in _try_hit would settle it if the GDD wants no SurvivorHit at all.
func _on_connection_changed(e: ServerEvent) -> void:
	var c := e as EvPlayerConnectionChanged
	if c.player == _monster and c.status == EvPlayerConnectionChanged.DISCONNECTED and attacking():
		_count_interrupt(e.tick)
		_resolve(e.tick)


## Story 008: a wind-up or dash ended by a stun or a disconnect is interrupted; a stun during the takedown
## commit cancels a lunge that already hit (counted landed). Inference: the GDD's telemetry names
## hit/miss/interrupted only, so a disconnect counts as interrupted; a results-screen ruling would settle it.
func _count_interrupt(tick: int) -> void:
	if _lunge != Lunge.TAKEDOWN_COMMIT:
		_interrupted_ticks.append(tick)


## Lunges that hit a survivor this round (story 008).
func lunges_landed() -> int:
	return _landed_ticks.size()


## Lunges whose dash ended with no hit this round (story 008).
func lunges_missed() -> int:
	return _missed_ticks.size()


## Lunges stopped in wind-up or dash by a stun or disconnect this round (story 008).
func lunges_interrupted() -> int:
	return _interrupted_ticks.size()


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
## Story 009: a False Signal also carries its signal type as `detail` and the impersonated `survivor`; a
## callout its `line` (pings-and-callouts/003, which validates it).
func _emit_used(ability: Ability, target: Vector3, detail: StringName = &"", survivor: int = -1,
		line: StringName = &"") -> void:
	var e := EvAbilityUsed.new()
	e.ability = ability
	e.detail = detail
	e.survivor = survivor
	e.line = line
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
