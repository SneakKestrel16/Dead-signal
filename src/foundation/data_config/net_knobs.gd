class_name NetKnobs extends Resource
## Net knobs. Owning source: ADR-0001/0002/0003 (no GDD); max_rewind_ms is owned by monster-abilities.md (AbilityKnobs).
## Defaults are unset sentinels; values come only from res://data/knobs/net.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.net.sim_tick_hz`
## NOT SOURCEABLE (no number in ADR-0001/0002/0003): input_queue_cap, max_seq_ahead, starvation_high, starvation_low,
## slack_ticks, port, max_clients, auth_timeout, payload size cap, ENet timeout. Add each when its number is decided.
## sim_tick_hz range 30..128 kept by designer decision 2026-10-13; ADR-0002 fixes only the value 60.

@export_range(30, 128) var sim_tick_hz: int = KnobUnset.INT
@export var starvation_window_s: float = NAN
@export var correction_deadzone_m: float = NAN
@export var correction_smooth_max_m: float = NAN
@export var correction_smooth_s: float = NAN
@export var interp_delay_ms: int = KnobUnset.INT
@export var max_extrapolation_ms: int = KnobUnset.INT
@export var history_ticks: int = KnobUnset.INT
@export var reject_close_delay_s: float = NAN


## Cross-knob rules arrive in story data-config/003; none yet.
func validate_cross() -> PackedStringArray:
	return []
