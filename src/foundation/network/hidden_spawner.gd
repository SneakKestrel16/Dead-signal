class_name HiddenSpawner extends Node
## Non-body hidden entities (ADR-0004 §7): undiscovered drive rooms and fuse spawns, single-client
## hallucinations, monster-only markers. Each is a node named by an opaque number (`E%d`) whose
## MultiplayerSynchronizer has public_visibility = false before spawn() returns; the server grants it per
## player in the same frame, through NetAuthority so a reconnect carries the grant to the new peer.
## The same node is added at the same fixed path on the server and on every client (it is named
## NODE_NAME, never after a player). Spawn data must carry no identity: no player or peer ID, handle,
## role or character name.
## Usage (server):
##   var e := hidden.spawn({"kind": &"fuse", "pos": p}, [player_id])   # granted to that player only
##   hidden.grant(e, other_player, true)    # later, e.g. on discovery
##   hidden.despawn(e)

## Fixed node name on the round root (ADR-0004 §7a: no node is named after a player).
const NODE_NAME := &"Hidden"

## Client: an entity arrived (the MultiplayerSpawner's spawned signal, re-raised).
signal spawned(node: Node3D)

var _net: NetAuthority
var _spawner: MultiplayerSpawner
var _entities: Node3D
var _rng := RandomNumberGenerator.new()
## Every number issued this round: never twice.
var _used: Dictionary[int, bool] = {}


func _init() -> void:
	name = NODE_NAME
	_entities = Node3D.new()
	_entities.name = &"Entities"
	add_child(_entities)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = &"Spawner"
	add_child(_spawner)
	_spawner.spawn_path = NodePath("../Entities")
	_spawner.spawn_function = _build
	_spawner.spawned.connect(func(n: Node) -> void: spawned.emit(n as Node3D))


## Server: grants go through `net` (by player ID). Clients do not call this.
func setup(net: NetAuthority) -> void:
	_net = net
	_rng.randomize()


## Server: spawns an entity from identity-free `data` (its "pos", a Vector3, places it) and grants it to
## `players` in the same frame. Returns the server node.
func spawn(data: Dictionary, players: Array[int]) -> Node3D:
	# A random number, not a shared counter: a counter would tell each grantee how many hidden
	# entities were spawned for others before its own (code review 2026-10-14).
	var n := 0
	while n == 0 or _used.has(n):
		n = _rng.randi()
	_used[n] = true
	var payload := data.duplicate()
	payload["n"] = n
	var node := _spawner.spawn(payload) as Node3D
	for pid in players:
		grant(node, pid, true)
	return node


## Server: lets `player_id` see `node` (or stop seeing it).
func grant(node: Node3D, player_id: int, visible: bool) -> void:
	_net.set_player_visibility(node.get_node(^"Sync") as MultiplayerSynchronizer, player_id, visible)


## Server: removes `node` on every peer it was granted to.
func despawn(node: Node3D) -> void:
	node.queue_free()


## Server: despawns every entity (round end, before the round root is freed; see despawn).
func clear() -> void:
	for n in _entities.get_children():
		despawn(n as Node3D)


## Server and client: the node for `data`, hidden until granted (ADR-0004 §7 spawn order).
func _build(data: Variant) -> Node:
	var d: Dictionary = data
	var n := Node3D.new()
	n.name = "E%d" % int(d.n)
	n.position = d.get("pos", Vector3.ZERO)
	n.set_meta(&"data", d)
	var sync := MultiplayerSynchronizer.new()
	sync.name = &"Sync"
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	sync.replication_config = config
	sync.public_visibility = false
	n.add_child(sync)
	sync.root_path = NodePath("..")
	return n
