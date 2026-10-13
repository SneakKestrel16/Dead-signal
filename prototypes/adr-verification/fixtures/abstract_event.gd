@abstract
class_name FixtureEvent extends RefCounted
## ADR-0005 shape: @abstract on its own line, fields, a concrete method, abstract methods.

var tick: int


func describe() -> String:
	return "event %d" % tick


@abstract func project(peer: int) -> Dictionary
@abstract func on_cancel(actor: int) -> void
