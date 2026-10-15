## Emitter: Survivor Defense
## A taser hit a survivor, or the disguised monster; carries no identity information.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvPlayerShocked
extends ServerEvent


## The shocked player. Server-only: never in a payload.
var player: int


func type() -> StringName:
	return &"PlayerShocked"


## `{body: handle}` only, the same shape for every case (survivor, disguised monster), and only if the
## body is relevant to the viewer; the shocked player gets `{own: true}` (ADR-0004 §5, survivor-defense
## packet-capture AC).
func project(peer: int, handles: HandleTable, _monster: int) -> Dictionary:
	if peer == player:
		return {"own": true}
	if not handles.has(peer, player):
		return {}
	return {"body": handles.handle_for(peer, player)}
