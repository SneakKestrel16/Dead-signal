class_name RoundLifecycle extends RefCounted
## Everything around the round clock (Feature layer). Implements design/gdd/match-flow.md rules 2, 3,
## 17 and 27 and the States table (Loading, Results, Cancelled); story match-flow/004; ADR-0005.
## Server only. Loading: the server waits for every roster player's "map loaded" report (client-to-server
## input, never an event) up to `load_timeout_s`; all loaded -> spawn at the Facility Map spawn points
## (survivors S1.. in roster order, the shapeshifter at one of M1-M3 on `rng`), MatchFlow.begin() and
## the clock runs; timeout -> Cancelled, over(false). Once MatchFlow emits RoundEnded every player's input
## is frozen and the clock stops; after `results_duration_s` of Results, over(true).
## Owns the round's MatchFlow and forwards both slots to it. Hooks are the composition root's:
##   spawn(player_id: int, position: Vector3)  place the player's body
##   freeze(player_id: int)                    stop applying gameplay intents (set_frozen, cancel a hold)
##   over(ended: bool)                         RoundServer.end_round(); RosterHandoff.end_round(ended)
##   remove(player_id: int) -> Vector3         take the body out of the world, return where it stood
##   watch(spectator: int, survivor: int)      ServerMovement.watch
## Story 005 (rule 19): while Running, a player's DISCONNECTED removes their body; a RECONNECTED inside
## grace spawns it again where it stood. Their Healthy/Downed state and down count are Downing's and are
## untouched by a disconnect; carried items are dropped by Survivor Objectives on the same event.
## Story 007 (rule 10, ADR-0004 §8): a survivor who is Eliminated or Escaped loses their body (`remove`,
## unless a disconnect already took it) and spectates: `watch` points them at the lowest-id survivor still
## inside and connected. When that survivor goes Out or drops, every spectator on them moves to the next;
## a reconnect does not pull them back. With nobody left to watch nothing switches; the round is ending.
## A spectator's own disconnect removes no body and its reconnect spawns none.
## A host that quits ends the process: over is never called, so no result is recorded (rule 19 of
## lobby-role-assignment.md; clients see NetAuthority.host_left).
## Usage:
##   var lc := RoundLifecycle.new(roster, MapData.load_map(), rng)
##   lc.spawn = _spawn; lc.freeze = _freeze; lc.over = _over
##   server.start_round({TickOrder.MATCH_FLOW_BEGIN: lc, TickOrder.MATCH_FLOW_RESOLVE: lc.resolve_step()}, knobs)
##   smp.peer_packet -> if RoundLifecycle.is_map_loaded_packet(b): lc.report_loaded(net.player_id_of(peer))

enum State { LOADING, RUNNING, RESULTS, OVER }

## Size cap of a "map loaded" packet; anything larger is not one (untrusted client bytes).
const MAP_LOADED_CAP_BYTES := 64

## Hook: Callable(player_id: int, position: Vector3), once per player when Loading ends.
var spawn: Callable
## Hook: Callable(player_id: int), once per player on the RoundEnded tick.
var freeze: Callable
## Hook: Callable(ended: bool), once: true after Results, false for Cancelled.
var over: Callable
## Hook: Callable(player_id: int) -> Vector3, on a disconnect while Running (the position is used for
## the respawn on reconnect) and when a survivor goes Out: removes the body and returns its position.
var remove: Callable
## Hook: Callable(spectator: int, survivor: int), each time a spectator's watched survivor changes.
var watch: Callable

var _roster: Roster
var _map: MapData
var _rng: RandomNumberGenerator
var _mf := MatchFlow.new()
var _mf_resolve: MatchFlow.ResolveStep
var _state := State.LOADING
var _loaded: Dictionary[int, bool] = {}
var _spawn_points: Dictionary[int, StringName] = {}
var _ticks := 0 ## ticks spent in the current Loading or Results state
var _load_timeout_ticks := 0
var _results_ticks := 0
## player id -> where their body stood when they disconnected; cleared on reconnect or grace expiry.
var _away: Dictionary[int, Vector3] = {}
## Out survivor -> the survivor they watch, -1 until somebody is watchable.
var _spectators: Dictionary[int, int] = {}


## Runs in the MATCH_FLOW_RESOLVE slot; forwards to RoundLifecycle._on_resolve. Holds the lifecycle
## weakly (the BEGIN registration keeps it alive for the round).
class ResolveStep extends RefCounted:
	var _lc: WeakRef

	func _init(lc: RoundLifecycle) -> void:
		_lc = weakref(lc)

	func setup(_runner: TickRunner, _bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		pass

	func server_tick(tick: int) -> void:
		var lc := _lc.get_ref() as RoundLifecycle
		if lc != null:
			lc._on_resolve(tick)


## `roster`: the locked roster of this round. `map`: spawn markers. `rng`: picks the shapeshifter spawn.
func _init(roster: Roster, map: MapData, rng: RandomNumberGenerator) -> void:
	_roster = roster
	_map = map
	_rng = rng
	_mf_resolve = _mf.resolve_step()


## The bytes a client sends the server (reliable) once its map is loaded.
static func map_loaded_packet() -> PackedByteArray:
	return var_to_bytes({"map_loaded": true})


## True when untrusted `bytes` are a "map loaded" report.
static func is_map_loaded_packet(bytes: PackedByteArray) -> bool:
	if bytes.size() > MAP_LOADED_CAP_BYTES:
		return false
	var d: Variant = bytes_to_var(bytes)
	return d is Dictionary and d.size() == 1 and d.get("map_loaded") == true


## Injected by RoundServer. Sets up the round's MatchFlow with the roster's survivors.
func setup(tick_runner: TickRunner, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
	_load_timeout_ticks = knobs.ticks(knobs.match_flow.load_timeout_s)
	_results_ticks = knobs.ticks(knobs.match_flow.results_duration_s)
	_mf.survivor_ids.assign(_roster.player_ids().filter(
		func(id: int) -> bool: return _roster.entry(id).role == Roster.SURVIVOR))
	for id in _roster.player_ids():
		if _roster.entry(id).role == Roster.SHAPESHIFTER:
			_mf.shapeshifter_id = id
	_mf.setup(tick_runner, bus, registry, knobs)
	bus.subscribe(&"PlayerConnectionChanged", _on_connection)
	bus.subscribe(&"SurvivorEliminated", _on_eliminated)
	bus.subscribe(&"SurvivorEscaped", _on_escaped)


## The module to register at TickOrder.MATCH_FLOW_RESOLVE.
func resolve_step() -> ResolveStep:
	return ResolveStep.new(self)


## Server: `player_id` reported its map loaded. Ignored outside Loading, for a player not on the
## roster, and when repeated.
func report_loaded(player_id: int) -> void:
	if _state == State.LOADING and not _roster.entry(player_id).is_empty():
		_loaded[player_id] = true


## MATCH_FLOW_BEGIN slot. Loading: a report seen by the tick that reaches load_timeout_s still counts
## ("up to load_timeout_s", rule 2). Running: the MatchFlow clock.
func server_tick(tick: int) -> void:
	match _state:
		State.LOADING:
			_ticks += 1
			if _loaded.size() == _roster.player_count():
				_start()
			elif _ticks >= _load_timeout_ticks:
				_finish(false)
		State.RUNNING:
			_mf.server_tick(tick)


## Current lifecycle state.
func state() -> State:
	return _state


## This round's MatchFlow (clock, phase, win check).
func match_flow() -> MatchFlow:
	return _mf


## The survivor `spectator` watches, -1 when it is not a spectator or nobody is watchable yet. Pings &
## Callouts reads it to refuse an Out player's ping (rule 10).
func watched_by(spectator: int) -> int:
	return _spectators.get(spectator, -1)


## Player IDs that reported loaded, ascending.
func loaded_ids() -> Array[int]:
	var out: Array[int] = []
	out.assign(_loaded.keys())
	out.sort()
	return out


## Player ID -> spawn marker id; empty until the loading barrier opens.
func spawn_points() -> Dictionary[int, StringName]:
	return _spawn_points.duplicate()


func _on_resolve(tick: int) -> void:
	if _state == State.RUNNING:
		_mf_resolve.server_tick(tick)
		if _mf.is_ended():
			_state = State.RESULTS
			_ticks = 0
			for id in _roster.player_ids():
				if freeze.is_valid():
					freeze.call(id)
	elif _state == State.RESULTS:
		_ticks += 1
		if _ticks >= _results_ticks:
			_finish(true)


## Subscribed after MatchFlow, so its grace timer has seen the event first.
func _on_connection(e: ServerEvent) -> void:
	var c := e as EvPlayerConnectionChanged
	match c.status:
		EvPlayerConnectionChanged.DISCONNECTED:
			if _state == State.RUNNING and remove.is_valid() and not _spectators.has(c.player):
				_away[c.player] = remove.call(c.player)
		EvPlayerConnectionChanged.RECONNECTED:
			if _away.has(c.player) and spawn.is_valid():
				spawn.call(c.player, _away[c.player])
			_away.erase(c.player)
		EvPlayerConnectionChanged.GRACE_EXPIRED:
			_away.erase(c.player)
	_retarget()


## Subscribed after MatchFlow, so its status is already Eliminated / Escaped.
func _on_eliminated(e: ServerEvent) -> void:
	_go_out((e as EvSurvivorEliminated).survivor)


func _on_escaped(e: ServerEvent) -> void:
	_go_out((e as EvSurvivorEscaped).survivor)


## A disconnected survivor has no body to remove, and must not get one back on reconnect.
func _go_out(id: int) -> void:
	if _spectators.has(id) or not _mf.survivor_ids.has(id):
		return
	if _away.has(id):
		_away.erase(id)
	elif remove.is_valid():
		remove.call(id)
	_spectators[id] = -1
	_retarget()


func _watchable(id: int) -> bool:
	var s := _mf.status_of(id)
	return (s == MatchFlow.Status.HEALTHY or s == MatchFlow.Status.DOWNED) and not _mf.in_grace(id)


## Moves every spectator whose survivor is not watchable to the lowest-id watchable survivor.
func _retarget() -> void:
	var ids := _mf.survivor_ids.duplicate()
	ids.sort()
	var target := -1
	for id in ids:
		if _watchable(id):
			target = id
			break
	if target == -1:
		return
	for sp: int in _spectators:
		var cur := _spectators[sp]
		if cur != -1 and _watchable(cur):
			continue
		_spectators[sp] = target
		if watch.is_valid():
			watch.call(sp, target)


func _start() -> void:
	_state = State.RUNNING
	var survivor_marks: Array[MapMarker] = []
	var monster_marks: Array[MapMarker] = []
	for m in _map.markers:
		if m.type == &"survivor_spawn":
			survivor_marks.append(m)
		elif m.type == &"monster_spawn":
			monster_marks.append(m)
	# String compare: StringName's < orders by pointer, not text.
	var by_id := func(a: MapMarker, b: MapMarker) -> bool: return String(a.id) < String(b.id)
	survivor_marks.sort_custom(by_id)
	monster_marks.sort_custom(by_id)
	var next := 0
	for id in _roster.player_ids():
		var m: MapMarker
		if _roster.entry(id).role == Roster.SHAPESHIFTER:
			m = monster_marks[_rng.randi_range(0, monster_marks.size() - 1)]
		else:
			m = survivor_marks[next]
			next += 1
		_spawn_points[id] = m.id
		if spawn.is_valid():
			spawn.call(id, m.position)
	_mf.begin()


func _finish(ended: bool) -> void:
	_state = State.OVER
	if over.is_valid():
		over.call(ended)
