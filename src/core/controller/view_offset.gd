class_name ViewOffset extends RefCounted
## The server-held flinch view offset per player (ADR-0015 §1-4; first-person-controller.md rules 7
## and 9; story controller-interaction/013). Scare Events asks with FlinchRequested; this is the only
## writer of a FlinchRecord. Each record goes reliably to the owner as ViewOffsetChanged; ViewState adds
## offset_for(frame) to the frame's yaw and pitch.
## A frame is evaluated with the record it was rendered with (`InputFrame.record_id`, last HISTORY kept)
## at its own `offset_tick`, clamped to the record's start and the current tick (ADR-0015 §2).
## Resets (round end, Downed, reconnect, toggle off here; Hidden and Seized through rebaseline(), wired
## by the round composer) are re-baselines: a zero record with rebaseline = true carrying the held
## offset, which the owner folds into its yaw and pitch. Frames still on the old record keep their view,
## so nothing snaps.
## Deviation from ADR-0015 §3, inference: no separate view epoch or per-epoch base. The record id
## already tells the server whether a frame was sampled before or after the owner's fold, so the epoch
## byte would carry nothing more. An ADR-0015 amendment or architecture review would settle it.
## Lunge wind-up (rule 7: never during one) comes in as `in_wind_up(player) -> bool`, composed from the
## LungeView and lunge_cue_radius_m by the round composer: the Controller does not depend on Monster
## Abilities.
## Usage:
##   var offset := ViewOffset.new(in_wind_up); offset.setup(runner, bus, registry, knobs)
##   var view := ViewState.new(server_movement, offset)

## Records kept per player for frames still in flight (ADR-0015 §2: last four).
const HISTORY := 4
## record_id is a byte on the wire.
const ID_MOD := 256

var _bus: EventBus
var _ramp_ticks: int
var _max_angle: float
var _in_wind_up: Callable
## player -> {records: Dictionary of int -> FlinchRecord, cur: int, enabled: bool}
var _players: Dictionary[int, Dictionary] = {}


func _init(in_wind_up: Callable = Callable()) -> void:
	_in_wind_up = in_wind_up


func setup(_runner: TickRunner, bus: EventBus, _registry: StateRegistry, knobs: Knobs) -> void:
	_bus = bus
	_ramp_ticks = roundi(knobs.scare.scare_max_control_loss_s * knobs.net.sim_tick_hz)
	_max_angle = deg_to_rad(knobs.scare.flinch_max_angle_deg)
	bus.subscribe(&"FlinchRequested", _on_flinch)
	bus.subscribe(&"AbilityUsed", _on_ability)
	bus.subscribe(&"SurvivorDowned", _on_downed)
	bus.subscribe(&"RoundEnded", _on_round_ended)
	bus.subscribe(&"PlayerConnectionChanged", _on_connection)


## The offset of the player's newest record at the current tick (radians, x yaw, y pitch).
func offset_of(player_id: int) -> Vector2:
	return FlinchRecord.offset_at(_current(player_id), float(_bus.tick))


## The offset to add to this frame's yaw and pitch: the frame's own record at the frame's tick. An
## unknown record id (evicted or forged) uses the newest record.
func offset_for(player_id: int, frame: InputFrame) -> Vector2:
	var p := _state(player_id)
	var r: FlinchRecord = p.records.get(frame.record_id, p.records[p.cur])
	var t := clampi(frame.offset_tick, r.start_tick, maxi(_bus.tick, r.start_tick))
	return FlinchRecord.offset_at(r, float(t))


## The player's accessibility flinch toggle (ADR-0015 §4). On until the client says otherwise
## (inference: the GDD states no default). Off re-baselines a held offset.
func set_flinch_enabled(player_id: int, on: bool) -> void:
	_state(player_id).enabled = on
	if not on:
		rebaseline(player_id)


## Resets the offset to 0 without moving the view (Hidden, Seized; the bus resets call it too).
## Nothing to do when no offset is held or ramping.
func rebaseline(player_id: int) -> void:
	var cur := _current(player_id)
	if cur.from == Vector2.ZERO and cur.target == Vector2.ZERO:
		return
	var r := FlinchRecord.new()
	r.rebaseline = true
	r.fold = offset_of(player_id)
	_write(player_id, r)


## Holds the current offset where it is (a lunge wind-up cancels a running flinch).
func freeze(player_id: int) -> void:
	var r := FlinchRecord.new()
	r.from = offset_of(player_id)
	r.target = r.from
	_write(player_id, r)


func _on_flinch(e: ServerEvent) -> void:
	var f := e as EvFlinchRequested
	if not _state(f.player).enabled or (_in_wind_up.is_valid() and _in_wind_up.call(f.player)):
		return
	var r := FlinchRecord.new()
	r.from = offset_of(f.player)
	# Replace, not stack: the target and the rotation from the held offset are both capped (rule 7).
	var wanted := f.target.limit_length(_max_angle)
	r.target = (r.from + (wanted - r.from).limit_length(_max_angle)).limit_length(_max_angle)
	r.ramp_ticks = _ramp_ticks
	_write(f.player, r)


## Any ability use: a player whose flinch is still ramping and who is in a lunge wind-up's cue radius
## is frozen where the ramp is.
func _on_ability(_e: ServerEvent) -> void:
	if not _in_wind_up.is_valid():
		return
	for pid: int in _players.keys():
		var cur := _current(pid)
		if _bus.tick < cur.start_tick + cur.ramp_ticks and _in_wind_up.call(pid):
			freeze(pid)


func _on_downed(e: ServerEvent) -> void:
	rebaseline((e as EvSurvivorDowned).survivor)


func _on_round_ended(_e: ServerEvent) -> void:
	for pid: int in _players.keys():
		rebaseline(pid)


## Reconnect: the server discards the offset and the client starts fresh on record 0, so both agree.
func _on_connection(e: ServerEvent) -> void:
	var c := e as EvPlayerConnectionChanged
	if c.status == EvPlayerConnectionChanged.RECONNECTED:
		_players.erase(c.player)


func _write(player_id: int, r: FlinchRecord) -> void:
	var p := _state(player_id)
	r.record_id = (p.cur + 1) % ID_MOD
	r.start_tick = _bus.tick
	p.records[r.record_id] = r
	p.records.erase(posmod(r.record_id - HISTORY, ID_MOD))
	p.cur = r.record_id
	var e := EvViewOffsetChanged.new()
	e.player = player_id
	e.record = r
	_bus.emit(e)


func _current(player_id: int) -> FlinchRecord:
	var p := _state(player_id)
	return p.records[p.cur]


func _state(player_id: int) -> Dictionary:
	if not _players.has(player_id):
		_players[player_id] = {"records": {0: FlinchRecord.new()}, "cur": 0, "enabled": true}
	return _players[player_id]
