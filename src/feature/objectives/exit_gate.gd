class_name ExitGate extends RefCounted
## Exit E's blocker (facility-map story 004; research-facility.md AC 10 and Technical Notes "Server
## authority"; ADR-0007 §5). The greybox builds the blocker closed; it opens only when the server
## reports TerminalState.ACTIVATED, the one-way exit state Survivor Objectives emits (rule 20). Exit E is
## no interactable (MapData.interactables), so no client interact can reach it. Nothing closes it again
## within a round: a new round instances a new level with the blocker closed.
## Usage:
##   server: `var gate := ExitGate.new(shape); gate.subscribe(bus)`
##   client: `gate.apply(entry)` for each ObjectiveProgressChanged entry received from the server

var _shape: CollisionShape3D


## `shape`: the exit's blocker shape in this peer's level (the doors-layer body whose `passage` meta is
## the exit passage id).
func _init(shape: CollisionShape3D) -> void:
	_shape = shape


## Server: open on the bus's ObjectiveProgressChanged(TERMINAL_ID, ACTIVATED).
func subscribe(bus: EventBus) -> void:
	bus.subscribe(&"ObjectiveProgressChanged", on_progress)


## Bus handler.
func on_progress(e: ServerEvent) -> void:
	var p := e as EvObjectiveProgressChanged
	_update(p.objective, p.state)


## Client: one replicated ObjectiveProgressChanged entry ({"objective": int, "state": int}). Untrusted
## bytes: a malformed entry is ignored, so it can never open the exit.
func apply(entry: Dictionary) -> void:
	var objective: Variant = entry.get("objective")
	var state: Variant = entry.get("state")
	if typeof(objective) == TYPE_INT and typeof(state) == TYPE_INT:
		_update(objective, state)


## True once the exit is open.
func is_open() -> bool:
	return _shape.disabled


func _update(objective: int, state: int) -> void:
	if objective == SurvivorObjectives.TERMINAL_ID and state == SurvivorObjectives.TerminalState.ACTIVATED:
		_shape.disabled = true
