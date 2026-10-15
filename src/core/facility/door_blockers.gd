class_name DoorBlockers extends RefCounted
## The door blockers of one world (ADR-0007 §5): one StaticBody3D per door on the doors layer, its shape
## enabled exactly while the door is closed. The server's Doors module and the client's replicated door
## state both drive them through apply(), so server movement (MOVE_SERVER) and client prediction
## (MOVE_PREDICT) collide with the same doors. Shape changes are made directly (ADR-0007 §5: never
## set_deferred outside physics callbacks); a disabled shape is seen by later queries in the same physics
## frame (ADR-0007 Verification 7).
## Usage:
##   var blockers := DoorBlockers.new(level_root, map)   # greybox Door_<id> bodies, meta &"passage"
##   blockers.apply(door_states)                          # Array[bool] by net id, true = closed

## net id -> the blocker's CollisionShape3D. Plain Object refs: the level owns the nodes.
var _shapes: Dictionary[int, CollisionShape3D] = {}


## Finds the blockers among `root`'s children: StaticBody3D with meta &"passage" naming a door of
## `map` (tools/level/greybox_from_map.gd), the shape its first child. Keyed by the door's net id.
func _init(root: Node, map: MapData) -> void:
	var ids := {}
	var targets := map.interactables()
	for i in targets.size():
		if targets[i] is MapPassage:
			ids[(targets[i] as MapPassage).id] = i
	for n in root.get_children():
		if n is StaticBody3D and ids.has(n.get_meta(&"passage", &"")):
			_shapes[ids[n.get_meta(&"passage")]] = n.get_child(0) as CollisionShape3D


## Enables each blocker exactly while `closed[net_id]` is true.
func apply(closed: Array[bool]) -> void:
	for id: int in _shapes:
		if is_instance_valid(_shapes[id]) and id < closed.size():
			_shapes[id].disabled = not closed[id]
