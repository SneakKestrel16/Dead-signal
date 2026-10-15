class_name MatchDisplay extends RefCounted
## Client display state of the round for the HUD: phase, clock, outcome (story match-flow/009;
## design/gdd/match-flow.md AC "clients show the server's phase"; ADR-0005, ADR-0004 §5). Client only,
## and decides nothing: it applies what the server sends and has no path back to it.
## Not a StateRegistry view (those are getter-only `*_view.gd`): it holds received state and mutates.
## Phase, outcome, reason and results come only from the RoundPhaseChanged / RoundEnded entries of the
## server's event batches (NA-9). The clock is not a separate field on the wire: the batch that carries
## RoundPhaseChanged(Infiltration) is stamped with the server tick at which the round clock is 0 (rule 3),
## and every snapshot is stamped with the current server tick, so
##   elapsed_s = (snapshot tick - start tick) / net.sim_tick_hz
## which is MatchFlow's own tick count while the round runs; RoundEnded's batch tick stops it. Between
## snapshots advance() extrapolates by local time; each newer snapshot replaces that with the server
## value, so a skewed local clock never accumulates. Only packets from the server peer count.
## A client that reconnects mid-round missed the Infiltration batch: the server re-sends it, at its
## original tick, with the later phase changes and RoundEnded (ServerMovement.catch_up, story
## match-flow/007), so the same rules rebuild the clock.
## Usage (client composition root):
##   var view := MatchDisplay.new(knobs, multiplayer as SceneMultiplayer)
##   func _process(delta): view.advance(delta); hud.show(view.phase(), view.time_remaining_s())

const SERVER_PEER := 1

## Packets that failed to decode, and RoundPhaseChanged / RoundEnded entries with bad payloads.
var rejected: int = 0

var _smp: SceneMultiplayer
var _hz: int
var _round_duration_s: float
var _phase: int = -1
var _outcome: int = -1
var _reason: int = -1
var _results: Dictionary = {}
var _start_tick: int = -1 ## server tick of RoundPhaseChanged(Infiltration): elapsed 0
var _end_tick: int = -1 ## server tick of RoundEnded: the clock stops
var _server_tick: int = -1 ## newest snapshot tick
var _local_s: float = 0.0 ## local seconds since that snapshot (extrapolation)


## `smp`: listen on its peer_packet; null = call receive() by hand (tests).
func _init(knobs: Knobs, smp: SceneMultiplayer = null) -> void:
	_hz = knobs.net.sim_tick_hz
	_round_duration_s = knobs.match_flow.round_duration_s
	_smp = smp
	if _smp != null:
		_smp.peer_packet.connect(on_packet)


## Stops listening. Safe to call twice.
func close() -> void:
	if _smp != null and _smp.peer_packet.is_connected(on_packet):
		_smp.peer_packet.disconnect(on_packet)


## peer_packet handler: anything not from the server is ignored.
func on_packet(peer_id: int, bytes: PackedByteArray) -> void:
	if peer_id == SERVER_PEER:
		receive(bytes)


## Applies one packet the server sent: an event batch or a snapshot. Handle messages are PuppetMap's.
func receive(bytes: PackedByteArray) -> void:
	if HandleTable.is_message(bytes):
		return
	if EventBatch.is_message(bytes):
		var b := EventBatch.decode(bytes)
		if b.is_empty():
			rejected += 1
			return
		for entry: Array in b.entries:
			_apply(b.tick, entry[0], entry[1])
		return
	var snap := SnapshotCodec.decode(bytes)
	if snap.is_empty():
		rejected += 1
	elif snap.tick > _server_tick: # an older (reordered) unreliable snapshot never moves the clock back
		_server_tick = snap.tick
		_local_s = 0.0


## Local time passing between snapshots (per frame, seconds).
func advance(delta_s: float) -> void:
	_local_s += delta_s


## Current Phase (MatchFlow.Phase), -1 before the round begins.
func phase() -> int:
	return _phase


## True once the Infiltration batch fixed the clock's start.
func has_clock() -> bool:
	return _start_tick >= 0


## Seconds since the round clock started: the server's value at the newest snapshot, plus local time
## since it while the round runs; frozen at the RoundEnded tick.
func elapsed_s() -> float:
	if not has_clock() or _server_tick < 0:
		return 0.0
	if is_ended():
		return float(maxi(0, mini(_server_tick, _end_tick) - _start_tick)) / float(_hz)
	return float(maxi(0, _server_tick - _start_tick)) / float(_hz) + _local_s


## Seconds to the deadline (MatchFlow.time_remaining_at), the full round before the clock starts.
func time_remaining_s() -> float:
	return MatchFlow.time_remaining_at(elapsed_s(), _round_duration_s)


## Newest server tick heard of in a snapshot, -1 before any.
func server_tick() -> int:
	return _server_tick


## True once RoundEnded arrived.
func is_ended() -> bool:
	return _end_tick >= 0


## RoundEnded outcome (MatchFlow.Outcome), -1 before it.
func outcome() -> int:
	return _outcome


## RoundEnded reason (MatchFlow.Reason), -1 before it.
func reason() -> int:
	return _reason


## RoundEnded results payload (story match-flow/008), a copy.
func results() -> Dictionary:
	return _results.duplicate(true)


func _apply(tick: int, type: StringName, p: Dictionary) -> void:
	if type == &"RoundPhaseChanged":
		var ph: Variant = p.get("phase")
		if not ph is int or ph < 0 or ph >= MatchFlow.Phase.size():
			rejected += 1
			return
		if ph == MatchFlow.Phase.INFILTRATION: # rule 3: a new round's clock starts at this tick
			_start_tick = tick
			_end_tick = -1
			_server_tick = maxi(_server_tick, tick) # a catch-up's old tick never moves the clock back
			_local_s = 0.0
			_outcome = -1
			_reason = -1
			_results = {}
		_phase = ph
	elif type == &"RoundEnded":
		var o: Variant = p.get("outcome")
		var r: Variant = p.get("reason")
		var res: Variant = p.get("results")
		if not (o is int and o >= 0 and o < MatchFlow.Outcome.size() and r is int and r >= 0
				and r < MatchFlow.Reason.size() and res is Dictionary):
			rejected += 1
			return
		_outcome = o
		_reason = r
		_results = res
		_end_tick = tick
