class_name RosterFeed extends RefCounted
## Server side of the H4 roster (story hud-results/011; design/ux/hud.md H4; ADR-0004 §5 per-peer projection).
## A ServerMovement.batch_extras provider: the round's survivors with their lobby display names (Roster, carried
## through RosterHandoff, lobby rule 14) as one EventBatch.ROSTER entry per survivor viewer, sent once after that
## player's map-loaded report (its client then has the router that takes it) and again in full on a rejoin.
## The shapeshifter gets nothing (hud.md open question: its Z1 is the face list). Information hiding: roles are
## public (lobby rule 11), so names reveal no identity; the entry keys survivors by player id, never by a body
## handle, so it says nothing about which body is whom (borrowed-face.md: identity is the body, not the player).
## Usage (RoundComposer):
##   roster_feed = RosterFeed.new(roster, survivors, lifecycle.loaded_ids)
##   sm.batch_extras.append(roster_feed.entries)

var _names: Dictionary = {}
var _loaded: Callable
var _sent: Dictionary[int, bool] = {}


## `loaded() -> Array[int]`: the players whose map-loaded report arrived (RoundLifecycle.loaded_ids).
func _init(roster: Roster, survivors: Array[int], loaded: Callable) -> void:
	for id in survivors:
		_names[id] = str(roster.entry(id).get("name", ""))
	_loaded = loaded


## ServerMovement.batch_extras provider: [[EventBatch.ROSTER, {survivors}]] for a survivor viewer the first time
## it is loaded, or on `full`; [] otherwise.
func entries(viewer: int, full: bool = false) -> Array:
	if not _names.has(viewer):
		return []
	if not full and (_sent.has(viewer) or not _loaded.call().has(viewer)):
		return []
	_sent[viewer] = true
	return [[EventBatch.ROSTER, {"survivors": _names.duplicate()}]]
