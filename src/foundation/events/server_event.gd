## Base of every catalog event (ADR-0005). Server-side only; clients never emit events.
## Never construct by class name (parse error); build a concrete Ev<EventName> instead.
## Example: var e := EvPlayerShocked.new(); e.tick = 12; e.project(peer, handles, monster)
@abstract
class_name ServerEvent
extends RefCounted

## Server tick the event was emitted on.
var tick: int = 0
## Server time in seconds at emission.
var server_time: float = 0.0


## Catalog name, equal to the systems-index.md event name.
@abstract func type() -> StringName


## Payload viewer `peer` (a player ID) may see, or {} when it receives nothing. Bodies are named by
## that viewer's `handles`, never by player ID; `monster` is the shapeshifter's player ID (roles are
## public, lobby-role-assignment.md rule 11), so the ADR-0004 §5 table can project by role.
## Signature amended by NA-9 (AD-107): ADR-0005 had project(peer, handles).
@abstract func project(peer: int, handles: HandleTable, monster: int) -> Dictionary
