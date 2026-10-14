## Emitter: Survivor Defense
## A taser hit a survivor, or the disguised monster; carries no identity information.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvPlayerShocked
extends ServerEvent


func type() -> StringName:
	return &"PlayerShocked"


func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {"shocked": true}  # no identity data; {} would mean "not sent"
