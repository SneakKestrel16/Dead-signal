class_name NetKnobs extends Resource
## Net knobs. Owning source: ADR-0001/0002/0003 (no GDD); max_rewind_ms is owned by monster-abilities.md (AbilityKnobs).
## Defaults are unset sentinels; values come only from res://data/knobs/net.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.net.sim_tick_hz`
## NOT SOURCEABLE (no number in ADR-0001/0002/0003): slack_ticks,
## ENet timeout. Add it when its number is decided.
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
## Join knobs (story network-authority/001): inference, AD-63, no ADR/GDD number.
## ENet listen port for a hosted game.
@export var port: int = KnobUnset.INT
## Extra ENet slots above max_players so a reconnect can arrive while its stale peer still exists.
@export var max_clients_headroom: int = KnobUnset.INT
## Seconds a peer may stay unauthenticated before SceneMultiplayer drops it.
@export var auth_timeout_s: float = NAN
## Largest auth payload the server will decode, in bytes; larger is bad_payload.
@export var auth_payload_cap_bytes: int = KnobUnset.INT
## Input queue knobs (story network-authority/005): inference, AD-61, no ADR/GDD number.
## Hard cap on queued input frames per player; the oldest is dropped.
@export var input_queue_cap: int = KnobUnset.INT
## A packet whose seq is more than this beyond the last consumed seq is dropped whole.
@export var max_seq_ahead: int = KnobUnset.INT
## Starved-tick fraction over starvation_window_s above which the target depth rises to 2.
@export var starvation_high: float = NAN
## Starved-tick fraction below which the target depth falls back to 1.
@export var starvation_low: float = NAN
## Story network-authority/006: inference, no ADR/GDD number (ADR-0002 rule 7 gives the method, not the values).
## Largest input packet (var_to_bytes) the server decodes, in bytes; larger is dropped before decoding.
@export var input_packet_cap_bytes: int = KnobUnset.INT
## TickEstimator: fraction of the gap closed per snapshot when a sample is above / below the offset.
@export var tick_estimate_rise_alpha: float = NAN
@export var tick_estimate_fall_alpha: float = NAN


## Cross-knob rules arrive in story data-config/003; none yet.
func validate_cross() -> PackedStringArray:
	return []
