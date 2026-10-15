class_name MatchFlowKnobs extends Resource
## MatchFlow knobs. Owning source: design/gdd/match-flow.md.
## Defaults are unset sentinels; values come only from res://data/knobs/match_flow.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.match_flow.round_duration_s`

@export_range(420.0, 720.0) var round_duration_s: float = NAN
@export_range(60.0, 180.0) var infiltration_end_s: float = NAN
@export_range(60.0, 180.0) var evacuation_window_s: float = NAN
@export_range(20.0, 90.0) var post_escape_window_s: float = NAN
@export_range(30.0, 120.0) var reconnect_grace_s: float = NAN
@export_range(30.0, 120.0) var load_timeout_s: float = NAN
@export_range(10.0, 45.0) var results_duration_s: float = NAN


## Cross-knob rules within this section; [] = valid. Rule: Infiltration must end before Evacuation
## starts (match-flow.md Formulas "Phase from elapsed time"; equality also fails). Unset (NaN) knobs
## compare false here; the unset check reports them.
func validate_cross() -> PackedStringArray:
	var errs := PackedStringArray()
	var evac_start_s := round_duration_s - evacuation_window_s
	# Source: design/gdd/match-flow.md Formulas "Phase from elapsed time" (evac_start_s = round_duration_s - evacuation_window_s).
	if infiltration_end_s >= evac_start_s:
		errs.append("match_flow.infiltration_end_s (%s) must be < round_duration_s - evacuation_window_s (%s)" % [infiltration_end_s, evac_start_s])
	return errs
