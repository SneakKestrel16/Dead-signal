class_name ViewOffset extends RefCounted
## The server-held flinch view offset per player (ADR-0015 §1-4; first-person-controller.md rules 7
## and 9; story controller-interaction/013). Scare Events asks with FlinchRequested; this is the only
## writer of a FlinchRecord. Each record goes reliably to the owner as ViewOffsetChanged; ViewState adds
## offset_for(frame) to the frame's yaw and pitch.
## A frame is evaluated with the record it was rendered with (`InputFrame.record_id`, last HISTORY kept)
## at its own `offset_tick`, clamped to the record's start and the current tick (ADR-0015 §2).
## Resets (round end, Downed, reconnect, toggle off here; Hidden and Seized through rebaseline(), wired
## by the round composer) use the view-epoch handshake (ADR-0015 §3, AD-210): the server keeps the held
## offset as the old epoch's base, starts a new epoch and sends a zero record with rebaseline = true
## carrying that held offset as `fold`. The owner folds it into its yaw and pitch and stamps the new
## epoch. A frame still stamped with an old epoch gets that epoch's held offset (its own record up to the
## reset tick, the held offset after), so the server never zeroes an offset outside the handshake and
## nothing snaps. A frame stamped with an epoch the server does not know reads as the current epoch.
## Lunge wind-up (rule 7: never during one) comes in as `in_wind_up(player) -> bool`, composed from the
## LungeView and lunge_cue_radius_m by the round composer: the Controller does not depend on Monster
## Abilities.
## Usage:
##   var offset := ViewOffset.new(in_wind_up); offset.setup(runner, bus, registry, knobs)
##   var view := ViewState.new(server_movement, offset)

## Records kept per player for frames still in flight (ADR-0015 §2: last four).
const HISTORY := 4
## record_id and view_epoch are bytes on the wire.
const ID_MOD := 256

var _bus: EventBus
var _ramp_ticks: int
var _max_angle: float
var _in_wind_up: Callable
## player -> {records: Dictionary of int -> FlinchRecord, cur: int, enabled: bool, epoch: int,
## ended: Dictionary of old epoch -> {end: reset tick, held: Vector2}} (last HISTORY old epochs)
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


## The offset to add to this frame's yaw and pitch: the frame's epoch base plus its own record at the
## frame's tick (ADR-0015 §2-3). In the current epoch the base is zero and an unknown record id (evicted
## or forged, or another epoch's) uses the newest record. In an old epoch the frame's record is evaluated
## no later than that epoch's reset tick; without it the epoch's held offset is the answer.
func offset_for(player_id: int, frame: InputFrame) -> Vector2:
	var p := _state(player_id)
	var r: FlinchRecord = p.records.get(frame.record_id)
	var end := _bus.tick
	if frame.view_epoch != p.epoch and p.ended.has(frame.view_epoch):
		var old: Dictionary = p.ended[frame.view_epoch]
		if r == null or r.view_epoch != frame.view_epoch:
			return old.held
		end = old.end
	elif r == null or r.view_epoch != p.epoch:
		r = p.records[p.cur]
	var t := clampi(frame.offset_tick, r.start_tick, maxi(end, r.start_tick))
	return FlinchRecord.offset_at(r, float(t))


## The player's accessibility flinch toggle (ADR-0015 §4), from NetAuthority.flinch_enabled_changed;
## the round composer seeds it from NetAuthority at round start (off until the client has sent it). A
## ViewOffset used alone defaults to on (inference: the GDD states no default). Off re-baselines a held
## offset.
func set_flinch_enabled(player_id: int, on: bool) -> void:
	_state(player_id).enabled = on
	if not on:
		rebaseline(player_id)


## Resets the offset to 0 without moving the view (Hidden, Seized; the bus resets call it too): ends
## the epoch with the held offset as its base and starts the next. Nothing to do when no offset is held
## or ramping in the current epoch.
func rebaseline(player_id: int) -> void:
	var cur := _current(player_id)
	if cur.from == Vector2.ZERO and cur.target == Vector2.ZERO:
		return
	var p := _state(player_id)
	var held := offset_of(player_id)
	p.ended[p.epoch] = {"end": _bus.tick, "held": held}
	p.ended.erase(posmod(p.epoch - HISTORY, ID_MOD))
	p.epoch = (p.epoch + 1) % ID_MOD
	var r := FlinchRecord.new()
	r.rebaseline = true
	r.fold = held
	_write(player_id, r)


## Sends the player's current record again, unchanged (a spectator switched onto this player: ADR-0015
## §2 sends the record to the owner's spectators, and ServerMovement.watch() starts the spectator's stream
## with nothing). The owner already has it: the same record id is neither folded again nor reset.
func resend(player_id: int) -> void:
	_emit(player_id, _current(player_id))


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


## Reconnect: the rejoined client starts a fresh LocalInput on epoch 0 and record 0, and ServerMovement
## gives it a fresh input queue, so no old frame is in flight. The server restarts the player on epoch 0,
## record 0 too and sends that record as a re-baseline carrying the held offset, so a fresh client agrees
## on its first frame and a client that kept its LocalInput folds instead of snapping (inference: the
## client scene is not written yet; a fresh LocalInput per join is what round_client would settle). The
## flinch toggle is a session setting and survives.
func _on_connection(e: ServerEvent) -> void:
	var c := e as EvPlayerConnectionChanged
	if c.status != EvPlayerConnectionChanged.RECONNECTED or not _players.has(c.player):
		return
	var held := offset_of(c.player)
	var enabled: bool = _players[c.player].enabled
	_players.erase(c.player)
	var p := _state(c.player)
	p.enabled = enabled
	var r: FlinchRecord = p.records[0]
	r.rebaseline = true
	r.fold = held
	r.start_tick = _bus.tick
	_emit(c.player, r)


func _write(player_id: int, r: FlinchRecord) -> void:
	var p := _state(player_id)
	r.record_id = (p.cur + 1) % ID_MOD
	r.view_epoch = p.epoch
	r.start_tick = _bus.tick
	p.records[r.record_id] = r
	p.records.erase(posmod(r.record_id - HISTORY, ID_MOD))
	p.cur = r.record_id
	_emit(player_id, r)


func _emit(player_id: int, r: FlinchRecord) -> void:
	var e := EvViewOffsetChanged.new()
	e.player = player_id
	e.record = r
	_bus.emit(e)


func _current(player_id: int) -> FlinchRecord:
	var p := _state(player_id)
	return p.records[p.cur]


func _state(player_id: int) -> Dictionary:
	if not _players.has(player_id):
		_players[player_id] = {"records": {0: FlinchRecord.new()}, "cur": 0, "enabled": true, "epoch": 0,
			"ended": {}}
	return _players[player_id]
