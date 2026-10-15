class_name ObjectiveDisplay extends RefCounted
## Client objective state for the HUD checklist (story survivor-objectives/010; design/gdd/
## survivor-objectives.md rules 10, 27; ADR-0004 §5, §9): drive and fuse states, carriers (player IDs; the
## client's roster gives the names), dropped positions, docked and installed counts, terminal state.
## Client only, and decides nothing: it applies the server's ObjectiveProgressChanged entries and has no
## path back. Not a StateRegistry view (those are getter-only `*_view.gd`): it holds received state.
## Points it never heard of read as their start state (Secured, Unfound, Locked). Install alerts (rule 16,
## shapeshifter only) are counted, not kept: drawing the circle is the HUD's (ADR-0014, Proposed).
## Usage (client composition root):
##   var objectives := ObjectiveDisplay.new(multiplayer as SceneMultiplayer)
##   hud.show_drive(i, objectives.drive_state(i), roster.name_of(objectives.drive_carrier(i)))

const SERVER_PEER := 1
const TYPE := &"ObjectiveProgressChanged"
## Every objective state enum has this many values (DriveState, FuseState, TerminalState).
const STATE_COUNT := 5

## Event batches that failed to decode, and objective entries with bad payloads.
var rejected: int = 0
## Objective entries applied, install alerts included.
var received: int = 0
## Install alerts received.
var alerts: int = 0

var _smp: SceneMultiplayer
## objective id -> newest state / carrier / dropped position.
var _states: Dictionary[int, int] = {}
var _carriers: Dictionary[int, int] = {}
var _at: Dictionary[int, Vector3] = {}
var _powered := false


## `smp`: listen on its peer_packet; null = call receive() by hand (tests).
func _init(smp: SceneMultiplayer = null) -> void:
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


## Applies one packet the server sent; only event batches matter here.
func receive(bytes: PackedByteArray) -> void:
	if not EventBatch.is_message(bytes):
		return
	var b := EventBatch.decode(bytes)
	if b.is_empty():
		rejected += 1
		return
	for entry: Array in b.entries:
		if entry[0] == TYPE:
			_apply(entry[1])


## State of drive `index` (SurvivorObjectives.DriveState).
func drive_state(index: int) -> int:
	return _states.get(SurvivorObjectives.DRIVE_ID + index, SurvivorObjectives.DriveState.SECURED)


## Player ID carrying drive `index`, -1 if nobody.
func drive_carrier(index: int) -> int:
	return _carriers.get(SurvivorObjectives.DRIVE_ID + index, -1)


## State of fuse `index` (SurvivorObjectives.FuseState).
func fuse_state(index: int) -> int:
	return _states.get(SurvivorObjectives.FUSE_ID + index, SurvivorObjectives.FuseState.UNFOUND)


## Player ID carrying fuse `index`, -1 if nobody.
func fuse_carrier(index: int) -> int:
	return _carriers.get(SurvivorObjectives.FUSE_ID + index, -1)


## Where drive (DRIVE_ID + i) or fuse (FUSE_ID + i) `objective` last dropped; Vector3.INF if never.
func dropped_at(objective: int) -> Vector3:
	return _at.get(objective, Vector3.INF)


## Drives docked at the terminal.
func docked_count() -> int:
	var n := 0
	for i in SurvivorObjectives.FUSE_ID - SurvivorObjectives.DRIVE_ID:
		if _states.get(SurvivorObjectives.DRIVE_ID + i, -1) == SurvivorObjectives.DriveState.DOCKED:
			n += 1
	return n


## Fuse boxes filled.
func installed_count() -> int:
	var n := 0
	for i in SurvivorObjectives.TERMINAL_ID - SurvivorObjectives.FUSE_BOX_ID:
		if _states.get(SurvivorObjectives.FUSE_BOX_ID + i, -1) == SurvivorObjectives.FuseState.INSTALLED:
			n += 1
	return n


## Terminal state (SurvivorObjectives.TerminalState), never POWERED.
func terminal_state() -> int:
	return _states.get(SurvivorObjectives.TERMINAL_ID, SurvivorObjectives.TerminalState.LOCKED)


## True once the server reported power restored (rule 17).
func power_restored() -> bool:
	return _powered


func _apply(p: Dictionary) -> void:
	if p.has("centre"):
		if not (p["centre"] is Vector3 and p.get("radius_m") is float and p.get("duration_s") is float):
			rejected += 1
			return
		alerts += 1
		received += 1
		return
	var o: Variant = p.get("objective")
	var s: Variant = p.get("state")
	var c: Variant = p.get("carrier")
	var at: Variant = p.get("at", Vector3.ZERO)
	if not (o is int and o >= SurvivorObjectives.DRIVE_ID and o <= SurvivorObjectives.TERMINAL_ID
			and s is int and s >= 0 and s < STATE_COUNT and c is int and at is Vector3 and at.is_finite()):
		rejected += 1
		return
	received += 1
	if o == SurvivorObjectives.TERMINAL_ID and s == SurvivorObjectives.TerminalState.POWERED:
		_powered = true
		return
	_states[o] = s
	_carriers[o] = c
	if p.has("at"):
		_at[o] = at
