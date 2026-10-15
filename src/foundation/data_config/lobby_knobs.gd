class_name LobbyKnobs extends Resource
## Lobby knobs. Owning source: design/gdd/lobby-role-assignment.md.
## Defaults are unset sentinels; values come only from res://data/knobs/lobby.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.lobby.min_players`

@export_range(4, 5) var min_players: int = KnobUnset.INT
@export_range(5, 6) var max_players: int = KnobUnset.INT
@export_range(3.0, 10.0) var lobby_countdown_s: float = NAN
## GDD "Display name length 1–16" (rule 3; Tuning Knobs gives no safe range). Field names chosen by
## lobby story 003; NetAuthority rejects a join whose sanitized name is outside them (bad_name).
## Range 1..16: lobby-role-assignment.md rule 3 and Tuning Knobs, display name length 1-16.
@export_range(1, 16) var name_min_chars: int = KnobUnset.INT
@export_range(1, 16) var name_max_chars: int = KnobUnset.INT


## Cross-knob rules within this section; [] = valid.
func validate_cross() -> PackedStringArray:
	var errs := PackedStringArray()
	# Source: lobby-role-assignment.md Overview and Tuning Knobs: the lobby holds min_players to
	# max_players, so the minimum cannot exceed the maximum.
	if min_players > max_players:
		errs.append("lobby.min_players (%d) must not exceed lobby.max_players (%d) (lobby-role-assignment.md Tuning Knobs)" % [min_players, max_players])
	# Source: lobby-role-assignment.md rule 3: a display name is name_min_chars to name_max_chars long,
	# at least 1 character.
	if name_min_chars < 1 or name_min_chars > name_max_chars:
		errs.append("lobby.name_min_chars (%d) must be >= 1 and <= lobby.name_max_chars (%d) (lobby-role-assignment.md rule 3)" % [name_min_chars, name_max_chars])
	return errs
