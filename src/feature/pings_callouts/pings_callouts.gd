class_name PingsCallouts extends RefCounted
## Pings & Callouts, server side (design/gdd/pings-and-callouts.md rules 1, 5, 6, 7a, 15; story
## pings-and-callouts/001; ADR-0002 client intents validated on the server tick; ADR-0012 SightTest).
## A client sends a ping request (ping_packet); request_ping queues the first `ping_bucket_size` per player
## per tick; the PINGS_CALLOUTS slot validates each in arrival order: range and line of sight from the sender's
## eye, a valid target, then the per-player token bucket (a rejected ping spends nothing). Accepted pings are
## the tick's `accepted()` records; recipients (004) and marker lifetime (005) read or extend them. Callouts
## (003) have their own packet (callout_packet, CALLOUT_KEY beside PING_KEY); see request_callout. Server only.
## Story 002 (rules 14, 21-23; States and Transitions): can_send(player, kind, line) is the one sender-state
## gate for pings and callouts alike, reading life state, form, transforming and the shock lock.
## Usage:
##   pc.set_sources(eye_of, position_of, line_clear, identity_of, is_hidden, in_play)
##   pc.set_sender_sources(monster, match_flow.status_of, downing.life_state, bf.form, bf.transforming, sd.locked)
##   pc.set_map(map, point_height_m)
##   pc.request_ping(player, PingsCallouts.ping_packet(PingsCallouts.LOCATION, point))

## Ping kinds (rule 5). INVALID is decode_ping's result for bytes that are not a ping request.
const INVALID := 0
const LOCATION := 1
const ITEM := 2
const WARNING_POINT := 3
const WARNING_PLAYER := 4
## Send kind for a callout in can_send (not a ping kind: decode_ping never yields it).
const CALLOUT := 5
## Callout line ids the rules name (13, 14). The ids are ours: the GDD names lines by their text only.
const DRIVE_HERE := &"drive_here"
const FUSE_HERE := &"fuse_here"
const NEED_RESCUE := &"need_rescue"
const DANGER := &"danger"
## The authored callout lines (rule 9), from data (CalloutSet, res://data/callouts/callout_set.tres); [] when
## that set is invalid, which rejects every callout.
static var CALLOUT_LINES: Array[StringName] = CalloutSet.shipped_lines([DRIVE_HERE, FUSE_HERE, NEED_RESCUE, DANGER])
## The lines that may attach an item ping (rule 13).
const ITEM_LINES: Array[StringName] = [DRIVE_HERE, FUSE_HERE]
## The callouts a Downed survivor may send (rule 14); it may also ping.
const DOWNED_LINES: Array[StringName] = [NEED_RESCUE, DANGER]
## Packet dictionary keys: kind, world point (location and warning point), target (item: map interactable
## index = net id; warning player: player id). Unused fields are still present so the shape is fixed.
const PING_KEY := "ping"
const AT_KEY := "at"
const TARGET_KEY := "target"
## Size cap of a ping packet; anything larger is not one (untrusted client bytes).
const REQUEST_CAP_BYTES := 96
## Story 003: callout packet keys are CALLOUT_KEY (the line id) and TARGET_KEY (the attached item's map
## interactable index, -1 for none). Size cap of a callout packet (untrusted client bytes).
const CALLOUT_KEY := "callout"
const CALLOUT_CAP_BYTES := 96
## Marker types an item ping may name (rule 5). Not pingable: the monitor station; tasers are not map objects.
## Barricadable doors are named by DOOR_TYPE.
const PINGABLE_TYPES: Array[StringName] = [&"drive", &"fuse", &"fuse_box", &"terminal", &"hiding", &"switch"]
const DOOR_TYPE := &"door"
## Float tolerance on the token count (30 ticks of a 60-tick refill must reach exactly 0.5).
const TOKEN_EPS := 1e-6


## One accepted ping. `identity` is the target player's displayed appearance id (BorrowedFace.appearance_of;
## CharacterDef.TRUE_FORM_APPEARANCE_ID reads as "Monster"), -1 when the ping targets no player.
class PingRecord extends RefCounted:
	var sender: int
	var kind: int
	## Location and warning point: the ping point. Item: the object's point. Warning player: the target's
	## position at ping time (rule 5: the marker never follows the player).
	var point: Vector3
	## Item: map interactable index. Warning player: the target player id. Otherwise -1.
	var target: int = -1
	## Item: the PINGABLE_TYPES entry or DOOR_TYPE; otherwise &"".
	var item_type: StringName = &""
	var identity: int = -1
	var tick: int

	## True for a warning ping on a monster in True Form (labelled "Monster", rule 5).
	func is_monster_label() -> bool:
		return kind == PingsCallouts.WARNING_PLAYER and identity == CharacterDef.TRUE_FORM_APPEARANCE_ID


## Story 003: one accepted callout, real or a False Signal fake. Server only: `fake` is never sent to a
## survivor client (rule 27); delivery is story 006's.
class CalloutRecord extends RefCounted:
	## The requesting player (a fake: the monster).
	var sender: int
	## The displayed appearance id whose voice and name it carries (a fake: the impersonated survivor's).
	var identity: int
	var line: StringName
	## The sender's position (a real callout) or the point False Signal chose (a fake).
	var origin: Vector3
	var fake: bool = false
	## The attached item ping (rules 13, 28), also in accepted(); null when none was accepted. Never on a fake.
	var ping: PingRecord
	var tick: int


var _range_m: float = 0.0
var _bucket_size: int = 0
## Ticks per token (ping_refill_s at the sim rate, unrounded).
var _refill_ticks: float = 1.0
## player id -> tokens and the tick they were last brought up to date. Keyed by player id, not connection,
## so a reconnect keeps both (GDD Formulas). Absent = never pinged = a full bucket.
var _tokens: Dictionary[int, float] = {}
var _stamp: Dictionary[int, int] = {}
## player id -> requests received since the last tick, oldest first.
var _pending: Dictionary[int, Array] = {}
var _accepted: Array[PingRecord] = []
## Story 004: the latest tick's rejected requests as [player, {kind, at, target}], in arrival order.
var _rejected: Array = []
var _eye_of: Callable
var _position_of: Callable
var _line_clear: Callable
var _identity_of: Callable
var _body_of: Callable
var _is_hidden: Callable
var _in_play: Callable
var _monster: int = -1
var _status_of: Callable
var _life_of: Callable
var _form: Callable
var _transforming: Callable
var _locked: Callable
## Map interactable index -> [point, type]; built by set_map.
var _items: Dictionary[int, Array] = {}
var _point_height_m: float = 0.0
## Story 003 callout limits in ticks (PingKnobs, unrounded) and per-player last accepted callout ticks
## (absent = minus infinity: the first callout is always accepted).
var _callout_cd_ticks: float = 0.0
var _repeat_block_ticks: float = 0.0
var _last_callout_any: Dictionary[int, int] = {}
## player id -> {line -> tick}.
var _last_callout: Dictionary[int, Dictionary] = {}
## player id -> this tick's first callout request; fakes taken from AbilityUsed since the last tick.
var _pending_callouts: Dictionary[int, Dictionary] = {}
var _pending_fakes: Array[CalloutRecord] = []
var _callouts: Array[CalloutRecord] = []


## Injects the world sources. `eye_of(player) -> Vector3` is the sender's eye (inference: the standing eye; the
## hidden peek view, rule 14a, is not built yet and would be wired here); `position_of(player) -> Vector3` a
## player's body position (Vector3.ZERO / unlive bodies are the composer's concern); `line_clear(sender, from,
## to, item_index) -> bool` is the server sight ray (`item_index` -1 for a point: a closed door leaf other than
## the item's own blocks); `identity_of(player) -> int` the displayed appearance id; `is_hidden(player) -> bool`;
## `in_play(player) -> bool` whether a warning ping may target `player` (not Eliminated or Escaped; unset =
## everyone may be targeted). Who may send is can_send's.
func set_sources(eye_of: Callable, position_of: Callable, line_clear: Callable, identity_of: Callable,
		is_hidden: Callable, in_play: Callable = Callable()) -> void:
	_eye_of = eye_of
	_position_of = position_of
	_line_clear = line_clear
	_identity_of = identity_of
	_is_hidden = is_hidden
	_in_play = in_play


## Story 011: `body_of(sender, handle) -> int` names the player whose body the sender's opaque handle shows
## (-1 for none). A client knows bodies only by handle (ADR-0004 §3), so a warning-player request carries
## one; unset, the request's target is taken as the player id (unit tests).
func set_body_resolver(body_of: Callable) -> void:
	_body_of = body_of


## Story 002: injects the sender-state sources can_send reads. `status_of(player) -> MatchFlow.Status`
## (Escaped, Eliminated); `life_of(player) -> Downing.LifeState` (Seized, Downed); `form() -> int` and
## `transforming() -> bool` are Borrowed Face's (form is the borrowed survivor's id or TRUE_FORM);
## `locked(player) -> bool` is StateKeys.SHOCK_STUN_LOCK (Survivor Defense: false for a hit inside the
## post-lock window, which adds no lock). Unset = no sender is gated.
func set_sender_sources(monster: int, status_of: Callable, life_of: Callable, form: Callable,
		transforming: Callable, locked: Callable) -> void:
	_monster = monster
	_status_of = status_of
	_life_of = life_of
	_form = form
	_transforming = transforming
	_locked = locked


## Rules 14, 21-23: whether `player`'s state lets it send a ping (`kind` a ping kind, `line` ignored) or a
## callout (`kind` CALLOUT, `line` one of CALLOUT_LINES). A pure read of the injected sources.
## Survivor: Healthy sends all; Downed pings and DOWNED_LINES; Seized, Eliminated, Escaped (or any status
## other than Healthy or Downed) nothing. Monster: nothing in true form or while transforming; disguised
## sends all unless the borrowed survivor is Eliminated or Escaped (its Downed, Seized or Hidden state never
## restricts the monster). Both: nothing under the shock lock.
## Inference: a Disconnected borrowed survivor does not block the monster (rule 21 names Eliminated and
## Escaped only); a designer ruling on disconnects would settle it.
func can_send(player: int, kind: int, line: StringName = &"") -> bool:
	var callout := kind == CALLOUT
	if not (callout and line in CALLOUT_LINES) and not (kind in [LOCATION, ITEM, WARNING_POINT, WARNING_PLAYER]):
		return false
	if not _status_of.is_valid():
		return true
	if _locked.call(player):
		return false
	if player == _monster:
		var borrowed: int = _form.call()
		return borrowed != BorrowedFace.TRUE_FORM and not _transforming.call() \
				and _status_of.call(borrowed) not in [MatchFlow.Status.ELIMINATED, MatchFlow.Status.ESCAPED]
	if _status_of.call(player) not in [MatchFlow.Status.HEALTHY, MatchFlow.Status.DOWNED]:
		return false
	match _life_of.call(player):
		Downing.LifeState.HEALTHY:
			return true
		Downing.LifeState.DOWNED:
			return not callout or line in DOWNED_LINES
	return false


## Injects the map's pingable interactables, indexed by net id (MapData.interactables order). `point_height_m`
## lifts a floor-level object to the point sight is traced to (InteractRules.point_height_m).
func set_map(map: MapData, point_height_m: float) -> void:
	_point_height_m = point_height_m
	_items = pingable_items(map, point_height_m)


## The map's pingable interactables: net id -> [point lifted by `point_height_m`, type]. The client's ping
## button uses the same set to choose an item ping over a location ping (story 008).
static func pingable_items(map: MapData, point_height_m: float) -> Dictionary[int, Array]:
	var items: Dictionary[int, Array] = {}
	var all := map.interactables()
	for i in all.size():
		var door := all[i] as MapPassage
		if door != null:
			if door.kind == MapPassage.BARRICADABLE:
				items[i] = [door.position + Vector3.UP * point_height_m, DOOR_TYPE]
			continue
		var m := all[i] as MapMarker
		if m != null and m.type in PINGABLE_TYPES:
			items[i] = [m.position + Vector3.UP * point_height_m, m.type]
	return items


## Injected by RoundServer. Every player starts with a full bucket.
func setup(tick_runner: TickRunner, _bus: EventBus, _registry: StateRegistry, knobs: Knobs) -> void:
	_range_m = knobs.ping.ping_max_range_m
	_bucket_size = knobs.ping.ping_bucket_size
	_refill_ticks = knobs.ping.ping_refill_s * knobs.ticks(1.0)
	_tokens = {}
	_stamp = {}
	_pending = {}
	_accepted = []
	_setup_callouts(_bus, knobs)
	_rejected = []


## The bytes a client sends to request a ping of `kind` (`at` for LOCATION and WARNING_POINT, `target` for
## ITEM and WARNING_PLAYER).
static func ping_packet(kind: int, at: Vector3 = Vector3.ZERO, target: int = -1) -> PackedByteArray:
	return var_to_bytes({PING_KEY: kind, AT_KEY: at, TARGET_KEY: target})


## The request in untrusted `bytes` as {kind, at, target}, or {} when they are not exactly a well-formed ping
## (size cap, shape, known kind, finite point). Only the shape is checked; whether it may run is the tick's.
static func decode_ping(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > REQUEST_CAP_BYTES:
		return {}
	var d: Variant = bytes_to_var(bytes)
	if not (d is Dictionary and d.size() == 3 and d.get(PING_KEY) is int and d.get(AT_KEY) is Vector3
			and d.get(TARGET_KEY) is int):
		return {}
	var at: Vector3 = d[AT_KEY]
	if not (d[PING_KEY] in [LOCATION, ITEM, WARNING_POINT, WARNING_PLAYER]
			and is_finite(at.x) and is_finite(at.y) and is_finite(at.z)):
		return {}
	return {"kind": d[PING_KEY], "at": at, "target": d[TARGET_KEY]}


## Server entry for a client's bytes from `player` (the sender as the network layer identifies it, never a
## field of the bytes). Non-ping bytes are ignored. Per player per tick the first `ping_bucket_size` requests
## are kept for validation (the bucket could not accept more) and the next `ping_bucket_size` are kept only to
## be echoed as rejections (story 010); anything beyond is dropped, so a flood costs bounded memory.
## Inference: the echo bound reuses ping_bucket_size; an honest client never exceeds it, a designer knob would
## settle a different bound.
func request_ping(player: int, bytes: PackedByteArray) -> void:
	var req := decode_ping(bytes)
	if req.is_empty():
		return
	var q: Array = _pending.get_or_add(player, [])
	if q.size() < 2 * _bucket_size:
		q.append(req)


## PINGS_CALLOUTS slot: validates this tick's requests. The previous tick's accepted() records are dropped.
func server_tick(tick: int) -> void:
	_accepted = []
	_rejected = []
	for player: int in _pending:
		var q: Array = _pending[player]
		for i in q.size():
			var req: Dictionary = q[i]
			var rec := _validate(player, req, tick) if i < _bucket_size else null
			if rec != null and _take_token(player, tick):
				_accepted.append(rec)
			else:
				_rejected.append([player, req])
	_pending = {}
	_tick_callouts(tick)


## The pings accepted on the latest server_tick, in acceptance order.
func accepted() -> Array[PingRecord]:
	return _accepted


## `player`'s tokens as of `tick` (not stored; a fresh player has a full bucket).
func tokens_of(player: int, tick: int) -> float:
	if not _tokens.has(player):
		return float(_bucket_size)
	return minf(_bucket_size, _tokens[player] + (tick - _stamp[player]) / _refill_ticks)


## Rule 15 / Formulas: refill to `tick`, accept when at least one token, then spend it. A rejection spends
## nothing (the refill is kept, which is the same total).
func _take_token(player: int, tick: int) -> bool:
	var t := tokens_of(player, tick)
	_stamp[player] = tick
	if t < 1.0 - TOKEN_EPS:
		_tokens[player] = t
		return false
	_tokens[player] = maxf(t - 1.0, 0.0)
	return true


## Rule 6 minus the bucket: a record for a valid ping, else null.
func _validate(sender: int, req: Dictionary, tick: int) -> PingRecord:
	if not can_send(sender, req["kind"]):
		return null
	var rec := PingRecord.new()
	rec.sender = sender
	rec.kind = req["kind"]
	rec.tick = tick
	var eye: Vector3 = _eye_of.call(sender)
	var item := -1
	match rec.kind:
		LOCATION, WARNING_POINT:
			rec.point = req["at"]
		ITEM:
			item = req["target"]
			if not _items.has(item):
				return null
			rec.target = item
			rec.point = _items[item][0]
			rec.item_type = _items[item][1]
		WARNING_PLAYER:
			var target: int = _body_of.call(sender, req["target"]) if _body_of.is_valid() else req["target"]
			# A hidden survivor is never a valid target (rule 7a); one cannot ping itself.
			if target < 0 or target == sender or _is_hidden.call(target) or (_in_play.is_valid() and not _in_play.call(target)):
				return null
			rec.target = target
			rec.point = _position_of.call(target)
			rec.identity = _identity_of.call(target)
	# A player is seen at body height, not at the feet position the marker stores.
	var seen := rec.point + (Vector3.UP * _point_height_m if rec.kind == WARNING_PLAYER else Vector3.ZERO)
	if not _sees(sender, eye, seen, item):
		return null
	return rec


## Inference: no view cone for a ping (the GDD gives no ping field of view; the client picks what it looks at),
## so SightTest runs with a full circle and yaw 0, leaving range (ping_max_range_m) and the ray. A cone knob would settle it.
func _sees(sender: int, eye: Vector3, point: Vector3, item: int) -> bool:
	var clear := func(from: Vector3, to: Vector3) -> bool: return _line_clear.call(sender, from, to, item)
	return SightTest.sees(eye, 0.0, PackedVector3Array([point]), _range_m, 360.0, clear)


# --- Story 003: callouts ------------------------------------------------------------

func _setup_callouts(bus: EventBus, knobs: Knobs) -> void:
	_callout_cd_ticks = knobs.ping.callout_global_cooldown_s * knobs.ticks(1.0)
	_repeat_block_ticks = knobs.ping.callout_repeat_block_s * knobs.ticks(1.0)
	_last_callout_any = {}
	_last_callout = {}
	_pending_callouts = {}
	_pending_fakes = []
	_callouts = []
	if bus != null:
		bus.subscribe(&"AbilityUsed", _on_ability_used)


## The bytes a client sends to call out `line`, attaching item ping `item` (a map interactable index; only
## ITEM_LINES may attach, rule 13; -1 for none).
static func callout_packet(line: StringName, item: int = -1) -> PackedByteArray:
	return var_to_bytes({CALLOUT_KEY: line, TARGET_KEY: item})


## The request in untrusted `bytes` as {line, target}, or {} when they are not exactly a well-formed callout
## (size cap, shape, a line of the set, an attachment only on ITEM_LINES).
static func decode_callout(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > CALLOUT_CAP_BYTES:
		return {}
	var d: Variant = bytes_to_var(bytes)
	if not (d is Dictionary and d.size() == 2 and d.get(CALLOUT_KEY) is StringName and d.get(TARGET_KEY) is int):
		return {}
	var line: StringName = d[CALLOUT_KEY]
	var target: int = d[TARGET_KEY]
	if line not in CALLOUT_LINES or target < -1 or (target != -1 and line not in ITEM_LINES):
		return {}
	return {"line": line, "target": target}


## Server entry for a client's callout bytes from `player` (as the network layer identifies it). Non-callout
## bytes are ignored; only the first callout per player per tick is kept (a second would fail the global
## cooldown, callout_global_cooldown_s being longer than one tick).
func request_callout(player: int, bytes: PackedByteArray) -> void:
	var req := decode_callout(bytes)
	if not req.is_empty() and not _pending_callouts.has(player):
		_pending_callouts[player] = req


## The callouts accepted on the latest server_tick (real ones first, then fakes), for delivery (story 006).
func callouts() -> Array[CalloutRecord]:
	return _callouts


## Runs after the ping requests, so a ping and an attached ping in one tick spend from one bucket in that order.
func _tick_callouts(tick: int) -> void:
	_callouts = []
	for player: int in _pending_callouts:
		_accept_callout(player, _pending_callouts[player], tick)
	_pending_callouts = {}
	for rec in _pending_fakes:
		rec.tick = tick
		_callouts.append(rec)
	_pending_fakes = []


## Rules 13, 16 and Formulas "Callout acceptance": sender state (can_send), then the global cooldown and the
## line's repeat block. Only an accepted callout writes the timestamps; its attached item ping is then
## validated like any item ping and spends a token, and a rejected attachment leaves the callout standing.
func _accept_callout(player: int, req: Dictionary, tick: int) -> void:
	var line: StringName = req["line"]
	var lines: Dictionary = _last_callout.get_or_add(player, {})
	if not can_send(player, CALLOUT, line) \
			or (_last_callout_any.has(player) and tick - _last_callout_any[player] < _callout_cd_ticks - TOKEN_EPS) \
			or (lines.has(line) and tick - lines[line] < _repeat_block_ticks - TOKEN_EPS):
		return
	_last_callout_any[player] = tick
	lines[line] = tick
	var rec := CalloutRecord.new()
	rec.sender = player
	rec.identity = _identity_of.call(player)
	rec.line = line
	rec.origin = _position_of.call(player)
	rec.tick = tick
	if req["target"] != -1:
		var ping := _validate(player, {"kind": ITEM, "at": Vector3.ZERO, "target": req["target"]}, tick)
		if ping != null and _take_token(player, tick):
			rec.ping = ping
			_accepted.append(ping)
	_callouts.append(rec)


## Rules 17, 26-28: a False Signal callout (Monster Abilities validated the survivor and the point) becomes a
## fake record in the impersonated survivor's voice at the chosen point. It reads and writes no limit state
## and never attaches a ping. Inference: a line outside the set is dropped here, after Monster Abilities has
## spent the False Signal cooldown (it does not know the set); only a modified client sends one.
func _on_ability_used(e: ServerEvent) -> void:
	var a := e as EvAbilityUsed
	if a.ability != MonsterAbilities.Ability.FALSE_SIGNAL or a.line not in CALLOUT_LINES \
			or a.detail != MonsterAbilities.SIGNAL_DETAILS[MonsterAbilities.SignalType.CALLOUT]:
		return
	var rec := CalloutRecord.new()
	rec.sender = _monster
	rec.identity = _identity_of.call(a.survivor)
	rec.line = a.line
	rec.origin = a.target
	rec.fake = true
	_pending_fakes.append(rec)


## Story 004: the requests rejected on the latest server_tick as [player, {kind, at, target}], arrival order.
## Includes up to ping_bucket_size requests over the per-tick queue cap (request_ping); beyond that, dropped.
func rejected() -> Array:
	return _rejected


## Story 004 (rule 7): whether the monster receives `rec`: it sent it, it is the warning ping's own target, or
## an unobstructed server ray from its eye reaches the pinged point within ping_max_range_m, facing ignored.
## A player target is seen at body height, as in validation.
func monster_sees(rec: PingRecord) -> bool:
	if rec.sender == _monster or (rec.kind == WARNING_PLAYER and rec.target == _monster):
		return true
	var seen := rec.point + (Vector3.UP * _point_height_m if rec.kind == WARNING_PLAYER else Vector3.ZERO)
	return _sees(_monster, _eye_of.call(_monster), seen, rec.target if rec.kind == ITEM else -1)
