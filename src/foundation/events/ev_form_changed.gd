## Emitter: Borrowed Face
## Shapeshifter form changed.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvFormChanged
extends ServerEvent

var player: int
## Form before the change (borrowed-face.md rule 9): BorrowedFace.TRUE_FORM or a survivor's player id.
var previous: int
## Form after the change, same encoding.
var form: int


func type() -> StringName:
	return &"FormChanged"


## The shapeshifter's own form only; never to survivors (ADR-0004 §5, Borrowed Face).
func project(peer: int, _handles: HandleTable, monster: int) -> Dictionary:
	if peer != monster or player != monster:
		return {}
	return {"form": form}
