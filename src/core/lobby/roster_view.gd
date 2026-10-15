class_name RosterView extends RefCounted
## Read-only view of the locked roster (StateKeys.PLAYER_ROSTER, ADR-0005 §3): getters only, no
## setters, no public fields; getters are named get_* (state_registry_test scans every *_view.gd). Roles are public (lobby-role-assignment.md rule 11).
## Usage: `var v := registry.view(StateKeys.PLAYER_ROSTER, RosterView) as RosterView`

var _roster: Roster


func _init(roster: Roster) -> void:
	_roster = roster


func get_session_id() -> String:
	return _roster.session_id()


func get_round_index() -> int:
	return _roster.round_index()


## Fixed for the round.
func get_player_count() -> int:
	return _roster.player_count()


## Player IDs in join order.
func get_player_ids() -> Array[int]:
	return _roster.player_ids()


func get_display_name(player_id: int) -> String:
	return _roster.entry(player_id).get("name", "")


## Roster.SHAPESHIFTER, Roster.SURVIVOR, or &"" when not on the roster.
func get_role(player_id: int) -> StringName:
	return _roster.entry(player_id).get("role", &"")


## The survivor's character id; &"" for the shapeshifter or a player not on the roster.
func get_character(player_id: int) -> StringName:
	return _roster.entry(player_id).get("character", &"")
