class_name CalloutDelivery extends RefCounted
## Per-recipient callout delivery, server side (design/gdd/pings-and-callouts.md rules 10, 11, 12, 14a, 27;
## Formulas "Callout recipients"; story pings-and-callouts/006; ADR-0004 §5 per-peer projection). A
## ServerMovement batch_extras provider: each accepted callout of the tick reaches every in-play player whose
## body is within range(line) of the origin by straight-line distance (callout_range_m, or
## rescue_callout_range_m for "Need rescue"); walls never block delivery, they only attenuate the audio.
## A survivor gets [EventBatch.CALLOUT, {line, identity, origin, gesture, voice}]: `identity` the displayed
## appearance id (never a player id), `gesture` false for a hidden sender (rule 14a) and for a fake (rule 28).
## The monster gets the smaller [EventBatch.CALLOUT_AUDIO, {line, voice, origin}]: a different entry type, so
## no feed text, name or direction field can leak by being left filled (rule 11). The real/fake flag is never
## sent (rule 27). Story 007 (rule 28): a survivor whose own displayed id a callout carries, and which did not
## send it, gets `not_you: true` (real from a disguise or fake alike, so the mark tells impersonation, not
## which kind); nobody else does. A spectator's stream is projected as its watched survivor (ServerMovement), so it mirrors
## that survivor. An attached item ping is in PingsCallouts.accepted() and goes through PingDelivery.
## Usage (composition root; keep a reference, a Callable does not keep this alive):
##   callout_delivery = CalloutDelivery.new(pings, knobs, monster, _ping_in_play, _position, sd.is_hidden, _tick,
##       bf.appearance_of)
##   sm.batch_extras.append(callout_delivery.entries)

var _pings: PingsCallouts
var _monster: int
var _in_play: Callable
var _position_of: Callable
var _is_hidden: Callable
var _tick: Callable
var _identity_of: Callable
var _range_m: float
var _rescue_range_m: float
## appearance id -> voice set (CharacterDef.voice_set).
var _voices: Dictionary[int, StringName] = {}
## This tick's [record, gesture] pairs; rebuilt when the tick moves on.
var _out: Array = []
var _out_tick := -1


## `in_play(player) -> bool`: the monster, or a survivor Healthy or Downed (the living listeners).
## `position_of(player) -> Vector3`: the listener's server body position. `is_hidden(player) -> bool`.
## `tick() -> int`: the running tick. `identity_of(player) -> int`: displayed appearance id; unset = no
## "(not you)" mark. `cast`: the survivor characters (default: the shipped files).
func _init(pings: PingsCallouts, knobs: Knobs, monster: int, in_play: Callable, position_of: Callable,
		is_hidden: Callable, tick: Callable, identity_of: Callable = Callable(),
		cast: Array[CharacterDef] = CharacterDef.load_all()) -> void:
	_pings = pings
	_monster = monster
	_in_play = in_play
	_position_of = position_of
	_is_hidden = is_hidden
	_tick = tick
	_identity_of = identity_of
	_range_m = knobs.ping.callout_range_m
	_rescue_range_m = knobs.ping.rescue_callout_range_m
	for c in cast:
		if c != null:
			_voices[c.appearance_id] = c.voice_set


## This tick's callout entries for `player` (see the class doc). `full` (a rejoin) sends none: a callout is
## transient, not round state.
func entries(player: int, full: bool = false) -> Array:
	if full or not _in_play.call(player):
		return []
	_refresh()
	var out: Array = []
	var at: Vector3 = _position_of.call(player)
	for pair: Array in _out:
		var rec: PingsCallouts.CalloutRecord = pair[0]
		var range_m := _rescue_range_m if rec.line == PingsCallouts.NEED_RESCUE else _range_m
		if at.distance_to(rec.origin) > range_m:
			continue
		var voice: StringName = _voices.get(rec.identity, &"")
		if player == _monster:
			out.append([EventBatch.CALLOUT_AUDIO, {"line": rec.line, "voice": voice, "origin": rec.origin}])
		else:
			var p := {"line": rec.line, "identity": rec.identity, "origin": rec.origin, "gesture": pair[1],
				"voice": voice}
			if player != rec.sender and _identity_of.is_valid() and _identity_of.call(player) == rec.identity:
				p["not_you"] = true
			out.append([EventBatch.CALLOUT, p])
	return out


## Once per tick: takes this tick's records and judges each gesture (rule 12: a real callout from a body in
## the open). Inference: a hidden sender's body stands in its hiding spot, so `origin` (its body position) is
## the spot (rule 14a); a HidingSpots anchor point would settle it if the body is ever placed elsewhere.
func _refresh() -> void:
	var t: int = _tick.call()
	if t == _out_tick:
		return
	_out_tick = t
	_out = []
	for rec in _pings.callouts():
		if rec.tick == t:
			_out.append([rec, not rec.fake and not _is_hidden.call(rec.sender)])
