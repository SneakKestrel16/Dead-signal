## Base of every catalog event (ADR-0005). Server-side only; clients never emit events.
## Never construct by class name (parse error); build a concrete Ev<EventName> instead.
## Example: var e := EvPlayerShocked.new(); e.tick = 12; e.project(peer, handles)
@abstract
class_name ServerEvent
extends RefCounted

## Server tick the event was emitted on.
var tick: int = 0
## Server time in seconds at emission.
var server_time: float = 0.0


## Catalog name, equal to the systems-index.md event name.
@abstract func type() -> StringName


## Payload the given peer may see, or {} when that peer receives nothing.
@abstract func project(peer: int, handles: HandleTable) -> Dictionary
