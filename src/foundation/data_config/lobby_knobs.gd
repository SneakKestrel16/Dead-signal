class_name LobbyKnobs extends Resource
## Lobby knobs. Owning source: design/gdd/lobby-role-assignment.md.
## Defaults are unset sentinels; values come only from res://data/knobs/lobby.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.lobby.min_players`

@export_range(4, 5) var min_players: int = KnobUnset.INT
@export_range(5, 6) var max_players: int = KnobUnset.INT
@export_range(3.0, 10.0) var lobby_countdown_s: float = NAN


## Cross-knob rules arrive in story data-config/003; none yet.
func validate_cross() -> PackedStringArray:
	return []
