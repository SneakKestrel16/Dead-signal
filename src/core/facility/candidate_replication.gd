class_name CandidateReplication extends RefCounted
## The replication channel for a round's active objective points, facility-map story 008
## (research-facility.md AC 4; survivor-objectives.md rules 5 and 7; ADR-0012 §5-6; ADR-0004 §7).
## Server only. Each active point is a HiddenSpawner entity carrying only its type and marker position.
## Fuse boxes and the terminal are granted to every player at round start; a drive room or fuse spawn is
## granted to the monster at round start and to the survivors only when discover() is called, so an
## undiscovered point never reaches a survivor peer (not its node, not its position).
## Who discovers what, and when, is Survivor Objectives' rule (SO-9, ADR-0012 §2-4): it calls discover().
## Usage (server):
##   var rep := CandidateReplication.new(hidden_spawner, map)
##   rep.start_round(CandidateSelection.pick(placements, round_rng), survivor_ids, monster_id)
##   rep.discover(marker_index)   # SO-9's sight test passed
##   rep.end_round()

## Marker types every survivor knows from round start (rule 7).
const ALWAYS_KNOWN: Array[StringName] = [CandidateSelection.FUSE_BOX, CandidateSelection.TERMINAL]

var _hidden: HiddenSpawner
var _map: MapData
var _survivors: Array[int] = []
## Marker index -> server entity, for each active point the survivors have not been granted yet.
var _undiscovered: Dictionary[int, Node3D] = {}
## Marker indices discovered this round.
var _discovered: Dictionary[int, bool] = {}


func _init(hidden: HiddenSpawner, map: MapData) -> void:
	_hidden = hidden
	_map = map


## Spawns `active` (indices into map.markers, from CandidateSelection.pick) before the first snapshot,
## granted per the rules above, and logs each point's position. Grants go by player ID, so a reconnect
## or a spectator on a survivor's ID keeps them (ADR-0004 §9).
func start_round(active: PackedInt32Array, survivors: Array[int], monster: int) -> void:
	_survivors = survivors.duplicate()
	for i in active:
		var m := _map.markers[i]
		var to: Array[int] = [monster]
		var known := m.type in ALWAYS_KNOWN
		if known:
			to.append_array(_survivors)
		var e := _hidden.spawn({"kind": m.type, "pos": m.position}, to)
		if not known:
			_undiscovered[i] = e
		print("objective point %s (%s) at %s" % [m.id, m.type, m.position])


## Grants the undiscovered point at marker `index` to every survivor. False when it is not an
## undiscovered active point (already discovered, always known, or not active).
func discover(index: int) -> bool:
	var e: Node3D = _undiscovered.get(index)
	if e == null:
		return false
	_undiscovered.erase(index)
	_discovered[index] = true
	for pid in _survivors:
		_hidden.grant(e, pid, true)
	return true


## True once discover(`index`) has granted that point this round.
func is_discovered(index: int) -> bool:
	return _discovered.has(index)


## Despawns every point on every peer and forgets the round.
func end_round() -> void:
	_hidden.clear()
	_undiscovered.clear()
	_discovered.clear()
