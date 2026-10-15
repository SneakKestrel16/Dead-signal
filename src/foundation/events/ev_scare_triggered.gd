## Emitter: Scare Events
## A scare; carries scare_id, scope, origin and intensity to its recipient (scare-events.md rule 1).
## `source` and `player` are server-only (rule 1a): used for gating and telemetry, never projected.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvScareTriggered
extends ServerEvent

var scare_id: StringName = &""
var scope: int
## ScareEntry.Source value; server-only.
var source: int = -1
## Player whose action caused it (Monster or Survivor source), -1 for RoundScript; server-only.
var player: int = -1
var origin: Vector3
## ScareEntry.Intensity value as delivered (a gated Major may arrive as Minor, story 002).
var intensity: int
var recipient: int


func type() -> StringName:
	return &"ScareTriggered"


## A shared scare emits one event per recipient. Recipients only; `source` and `player` stripped (ADR-0004 §5).
## The key `scare` is the one ScarePresenter looks the entry up by.
func project(peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	if peer != recipient:
		return {}
	return {"scare": scare_id, "scope": scope, "origin": origin, "intensity": intensity}
