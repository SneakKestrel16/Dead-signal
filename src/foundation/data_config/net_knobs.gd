class_name NetKnobs extends Resource
## Net knobs. Owning source: ADR-0001/0002/0003 (no GDD); max_rewind_ms is owned by monster-abilities.md (AbilityKnobs).
## Defaults are unset sentinels; values come only from res://data/knobs/net.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.net.sim_tick_hz`
## sim_tick_hz range 30..128 kept by designer decision 2026-10-13; ADR-0002 fixes only the value 60.

@export_range(30, 128) var sim_tick_hz: int = KnobUnset.INT
@export var starvation_window_s: float = NAN
@export var correction_deadzone_m: float = NAN
@export var correction_smooth_max_m: float = NAN
@export var correction_smooth_s: float = NAN
## Range 0..200 ms: inference, ADR-0003 §1 gives only the value 50; a netcode playtest settles it.
@export_range(0, 200) var interp_delay_ms: int = KnobUnset.INT
## Range 0..200 ms: inference, ADR-0003 §1 gives only the value 50; a netcode playtest settles it.
@export_range(0, 200) var max_extrapolation_ms: int = KnobUnset.INT
## Range 1..120 ticks: inference, ADR-0003 §4 gives only the value 16; the longest max_rewind_ms settles the floor.
@export_range(1, 120) var history_ticks: int = KnobUnset.INT
## ADR-0003 §3 rtt_bound slack: extra ticks a claimed view lag may exceed (T - ack_snapshot_tick) + interp + 2.
## Value 1 and range 0..10: inference (story network-authority/007), the ADR names the knob but no number; it
## absorbs the client's tick-estimate error. Clamp counts in LagCompensation.records on a real network settle it.
@export_range(0, 10) var slack_ticks: int = KnobUnset.INT
@export var reject_close_delay_s: float = NAN
## Join knobs (story network-authority/001): inference, AD-63, no ADR/GDD number.
## ENet listen port for a hosted game.
## Range 1..65535: UDP port numbers (protocol fact; port 0 means "any").
@export_range(1, 65535) var port: int = KnobUnset.INT
## Extra ENet slots above max_players so a reconnect can arrive while its stale peer still exists.
## Range 0..8: inference, no ADR/GDD number; a reconnect test with several stale peers settles it.
@export_range(0, 8) var max_clients_headroom: int = KnobUnset.INT
## Seconds a peer may stay unauthenticated before SceneMultiplayer drops it.
@export var auth_timeout_s: float = NAN
## Largest auth payload the server will decode, in bytes; larger is bad_payload.
## Range 64..65535 bytes: inference (floor fits an auth record, ceiling is one UDP datagram); the auth record size settles it.
@export_range(64, 65535) var auth_payload_cap_bytes: int = KnobUnset.INT
## ENet dead-peer timeout (story network-authority/003), ENetPacketPeer.set_timeout(limit, min_ms, max_ms) on
## both sides. ADR-0001 verification (1) measured 32, 1000, 2000 at 3.0 s on loopback (the default took 5.8 s),
## but BUG-0012: ENet checks a timeout only when a retransmit fires, and the retransmit timeout doubles from
## rtt + 4 * rtt_variance (rto0), so "limit" is reached after about limit * rto0 * 2 and the check lands
## up to 2x past min. Under frame jitter (rto0 65 ms) 32 detected in 3.7-4.3 s. 8, 750, 2000 caps it at
## about 2 * min + rto0 from the first unacknowledged ping (loopback 1.0-1.5 s). Inference: real-network timing is NOT RUN (NA-V NAV-14 settles it).
## Ranges: inference, only the values 32 / 1000 / 2000 are sourced (ADR-0001 verification 1); NAV-14 settles them.
@export_range(1, 128) var enet_timeout_limit: int = KnobUnset.INT
@export_range(100, 30000) var enet_timeout_min_ms: int = KnobUnset.INT
@export_range(100, 60000) var enet_timeout_max_ms: int = KnobUnset.INT
## Input queue knobs (story network-authority/005): inference, AD-61, no ADR/GDD number.
## Hard cap on queued input frames per player; the oldest is dropped.
## Range 1..64: inference, ADR-0002 §4 gives no number (about 15 unacked at 250 ms RTT); a lag playtest settles it.
@export_range(1, 64) var input_queue_cap: int = KnobUnset.INT
## A packet whose seq is more than this beyond the last consumed seq is dropped whole.
## Range 1..120: inference, ADR-0002 §3 gives no number; a lag playtest settles it.
@export_range(1, 120) var max_seq_ahead: int = KnobUnset.INT
## Starved-tick fraction over starvation_window_s above which the target depth rises to 2.
## Range 0..1: a fraction by definition.
@export_range(0.0, 1.0) var starvation_high: float = NAN
## Starved-tick fraction below which the target depth falls back to 1.
## Range 0..1: a fraction by definition.
@export_range(0.0, 1.0) var starvation_low: float = NAN
## Story network-authority/006: inference, no ADR/GDD number (ADR-0002 rule 7 gives the method, not the values).
## Largest input packet (var_to_bytes) the server decodes, in bytes; larger is dropped before decoding.
## Range 64..65535 bytes: inference (floor fits a 3-frame packet, ceiling is one UDP datagram); the InputFrame wire size settles it.
@export_range(64, 65535) var input_packet_cap_bytes: int = KnobUnset.INT
## TickEstimator: fraction of the gap closed per snapshot when a sample is above / below the offset.
## Range 0..1: an EMA weight by definition.
@export_range(0.0, 1.0) var tick_estimate_rise_alpha: float = NAN
@export_range(0.0, 1.0) var tick_estimate_fall_alpha: float = NAN
## Story network-authority/008: ADR-0004 §4 numbers.
## A body this close to a viewer is relevant whatever the visibility sets say.
@export var relevance_near_m: float = NAN
## A body stays relevant this long after it stops qualifying.
@export var relevance_linger_s: float = NAN


## Cross-knob rules within this section; [] = valid. Knobs.errors() runs it only when every field is set.
func validate_cross() -> PackedStringArray:
	var errs := PackedStringArray()
	# Source: ADR-0002 rule 4 (Adaptation): the target depth rises above starvation_high and falls
	# below starvation_low, so low must sit under high or the depth flips every window.
	if starvation_low >= starvation_high:
		errs.append("net.starvation_low (%s) must be below net.starvation_high (%s) (ADR-0002 rule 4)" % [starvation_low, starvation_high])
	# Source: ADR-0002 rule 6: corrections beyond the deadzone and under smooth_max are smoothed, so the
	# deadzone must be below smooth_max or no correction is ever smoothed.
	if correction_deadzone_m >= correction_smooth_max_m:
		errs.append("net.correction_deadzone_m (%s) must be below net.correction_smooth_max_m (%s) (ADR-0002 rule 6)" % [correction_deadzone_m, correction_smooth_max_m])
	# Source: ADR-0001 §6 (ENetPacketPeer.set_timeout from data): ENet's timeoutMinimum is the floor and
	# timeoutMaximum the ceiling of one timeout window, so min above max leaves the window undefined.
	if enet_timeout_min_ms > enet_timeout_max_ms:
		errs.append("net.enet_timeout_min_ms (%s) must not exceed net.enet_timeout_max_ms (%s) (ADR-0001 §6)" % [enet_timeout_min_ms, enet_timeout_max_ms])
	return errs
