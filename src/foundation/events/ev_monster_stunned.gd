## Emitter: Survivor Defense
## Stun applied; cancels lunge, takedown commit or transformation.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvMonsterStunned
extends ServerEvent

var monster: int


## True while the monster is in its true form; a disguised stun is never sent to survivors.
var true_form: bool


func type() -> StringName:
	return &"MonsterStunned"


## Shapeshifter: its own stun. Survivors: only while in true form, by that viewer's handle, and only
## while the body is relevant to them (ADR-0004 §5).
func project(peer: int, handles: HandleTable, monster_id: int) -> Dictionary:
	if peer == monster_id: ## the role table's shapeshifter; `monster` is the stunned body
		return {"own": true}
	if not true_form or not handles.has(peer, monster):
		return {}
	return {"body": handles.handle_for(peer, monster)}
