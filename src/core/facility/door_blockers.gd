class_name DoorBlockers extends RefCounted
## The door blockers of one world (ADR-0007 §5; BUG-0018): one StaticBody3D per door on the doors layer, its
## shape enabled and its leaf mesh drawn exactly while the door is closed, and the exit's, closed until Exit
## Open. The server's Doors module and the client's replicated door state (EventBatch.DOORS, on_doors) both
## drive them, so server movement and client prediction (PlayerBody masks include DOORS) collide with the
## same doors. A barricaded door also shows planks (on_barricade; placeholder until ASSET-049). Shape changes
## are made directly (ADR-0007 §5: never set_deferred outside physics callbacks); a disabled shape is seen by
## later queries in the same physics frame (ADR-0007 Verification 7).
## Several clients sharing one level (tests/manual/round_view.gd) may each hold one: they apply the same state.
## Usage:
##   var blockers := DoorBlockers.new(level_root, map)   # any ancestor of the Door_<id> bodies, meta &"passage"
##   blockers.apply(door_states)                          # server: Array[bool] by net id, true = closed
##   router.subscribe(EventBatch.DOORS, blockers.on_doors)            # client
##   router.subscribe(EventBatch.BARRICADE, blockers.on_barricade)    # client

const PLANKS := &"Planks"
## Plank boxes on a barricaded leaf: heights from the leaf's centre (m), plank height and the depth each side
## adds over the leaf (m). Placeholder look, no source: the door models (ASSET-048/049) replace it.
const PLANK_Y := [-0.45, 0.35]
const PLANK_H := 0.18
const PLANK_PROUD := 0.04

## net id -> the door's blocker body. Plain Object refs: the level owns the nodes.
var _bodies: Dictionary[int, StaticBody3D] = {}
var _exit: StaticBody3D
var _door_count := 0


## Finds the blockers under `root` (any depth): StaticBody3D with meta &"passage" naming a door of `map`
## (tools/level/greybox_from_map.gd), the shape its first child, the leaf its optional "Mesh" child. Keyed by
## the door's net id; the exit's kept apart (it is no interactable).
func _init(root: Node, map: MapData) -> void:
	var ids := {}
	var exit_id := &""
	var targets := map.interactables()
	for i in targets.size():
		if targets[i] is MapPassage:
			ids[(targets[i] as MapPassage).id] = i
	_door_count = ids.size()
	for p in map.passages:
		if p.kind == MapPassage.EXIT:
			exit_id = p.id
	for n in root.find_children("*", "StaticBody3D", true, false):
		var passage: StringName = n.get_meta(&"passage", &"")
		if ids.has(passage):
			_bodies[ids[passage]] = n
		elif passage != &"" and passage == exit_id:
			_exit = n


## Enables and draws each blocker exactly while `closed[net_id]` is true.
func apply(closed: Array[bool]) -> void:
	for id: int in _bodies:
		if id < closed.size():
			_set_closed(_bodies[id], closed[id])


## Opens the exit's blocker (`open`) or closes it.
func set_exit_open(open: bool) -> void:
	_set_closed(_exit, not open)


## Shows door `net_id`'s planks while `barricaded`. Builds them on first use, under the door body, so a
## second DoorBlockers on the same level finds them.
func set_barricaded(net_id: int, barricaded: bool) -> void:
	var body: StaticBody3D = _bodies.get(net_id)
	if body == null or not is_instance_valid(body):
		return
	var planks := body.get_node_or_null(NodePath(PLANKS)) as Node3D
	if planks == null:
		if not barricaded:
			return
		planks = _planks(body)
	planks.visible = barricaded


## ClientEventRouter handler for EventBatch.DOORS: {closed: Array of bool, one per door, exit: bool}.
## Server bytes, still validated: anything else is ignored whole.
func on_doors(_tick: int, payload: Dictionary) -> void:
	var closed: Variant = payload.get("closed")
	var exit: Variant = payload.get("exit")
	if not (closed is Array and exit is bool) or (closed as Array).size() != _door_count:
		return
	var states: Array[bool] = []
	for c: Variant in closed:
		if not c is bool:
			return
		states.append(c)
	apply(states)
	set_exit_open(exit)


## ClientEventRouter handler for EventBatch.BARRICADE: {door, barricaded, lockout_end}; malformed is ignored.
func on_barricade(_tick: int, payload: Dictionary) -> void:
	var door: Variant = payload.get("door")
	var on: Variant = payload.get("barricaded")
	if door is int and on is bool:
		set_barricaded(door, on)


static func _set_closed(body: StaticBody3D, closed: bool) -> void:
	if body == null or not is_instance_valid(body):
		return
	(body.get_child(0) as CollisionShape3D).disabled = not closed
	var leaf := body.get_node_or_null(^"Mesh") as Node3D
	if leaf != null:
		leaf.visible = closed
	var lit := body.get_node_or_null(^"Lit") as Node3D ## the exit's Exit Green lens (MapGreybox)
	if lit != null:
		lit.visible = not closed


static func _planks(body: StaticBody3D) -> Node3D:
	var leaf := ((body.get_child(0) as CollisionShape3D).shape as BoxShape3D).size
	var mat := (load(MapGreybox.SURFACES) as SurfaceMaterials).barricade
	var planks := Node3D.new()
	planks.name = PLANKS
	body.add_child(planks)
	for y: float in PLANK_Y:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(leaf.x + (PLANK_PROUD * 2.0 if leaf.x < leaf.z else 0.0), PLANK_H,
				leaf.z + (PLANK_PROUD * 2.0 if leaf.z <= leaf.x else 0.0))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position.y = y
		planks.add_child(mi)
	return planks
