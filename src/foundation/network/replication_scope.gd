class_name ReplicationScope extends RefCounted
## Relevance plus per-viewer handles: which bodies each viewer's snapshot carries, and under which
## handle (ADR-0004 §3-4). ServerMovement asks bodies_for() for every viewer in the snapshot phase
## and flushes handles.take() before the snapshot. A body leaving relevance (linger expired) is
## retired, so it re-enters under a fresh handle; a short gap bridged by linger keeps it.
## Usage: `var seen := scope.bodies_for(tick, viewer, positions)  # body player ID -> handle`

var relevance: Relevance
var handles: HandleTable


## `rng` seeds the handle table (tests); the default is randomized.
func _init(knobs: Knobs, rng: RandomNumberGenerator = null) -> void:
	relevance = Relevance.new(knobs)
	handles = HandleTable.new(rng)


## Body player ID -> the viewer's handle, for every body relevant to `viewer` at `tick`, in handle
## order: join order would let a client link a re-introduced body to its old place (code review
## 2026-10-14). Issues handles for newly relevant bodies and retires the ones no longer relevant.
func bodies_for(tick: int, viewer: int, positions: Dictionary) -> Dictionary:
	var by_body := {}
	for body: int in relevance.update(tick, viewer, positions):
		by_body[body] = handles.handle_for(viewer, body)
	for body: int in handles.bodies_of(viewer):
		if not by_body.has(body):
			handles.retire(viewer, body)
	var order: Array = by_body.keys()
	order.sort_custom(func(x: int, y: int) -> bool: return by_body[x] < by_body[y])
	var seen := {}
	for body: int in order:
		seen[body] = by_body[body]
	return seen


## A form change or transformation start of `body` (Borrowed Face): for every viewer it is only
## lingering for, the linger ends and the handle is retired now; viewers that see it keep the handle.
func form_changed(body: int) -> void:
	for viewer: int in relevance.viewers():
		if relevance.is_lingering(viewer, body):
			relevance.end_linger(viewer, body)
			handles.retire(viewer, body)


## Forgets the viewer's handles and relevance: its client discarded its puppet map (reconnect,
## spectator switch; ADR-0004 §8-9). The next send re-introduces every relevant body.
func reset_viewer(viewer: int) -> void:
	relevance.reset_viewer(viewer)
	handles.reset_viewer(viewer)


## A player left the round: forget it as a viewer and as a body. Viewers holding its handle retire
## it on their next send.
func remove_player(player_id: int) -> void:
	reset_viewer(player_id)
	relevance.forget_body(player_id)
