class_name PingDelivery extends RefCounted
## Per-recipient ping delivery, server side (design/gdd/pings-and-callouts.md rules 2, 7, 7a, 8; story
## pings-and-callouts/004; ADR-0004 §5 per-peer projection, ADR-0005). A ServerMovement batch_extras
## provider: each accepted ping of the tick goes as [EventBatch.PING, payload] to the sender, every living
## survivor, and the monster only when PingsCallouts.monster_sees it (judged once, at the accepting tick).
## A spectator's stream is projected as its watched survivor (ServerMovement), so it mirrors that survivor.
## Payload {kind, point, item, type, identity, from, handle}: `from` is the sender's displayed appearance id
## (never a player id, so a disguised sender reads as the survivor it wears); `handle` an opaque random id per
## (sender, displayed id) pair, so two bodies wearing one name stay apart (story 005) while one sender's
## disguises never share a handle; `identity` the warning target's displayed id; an item ping names the
## object only, so an occupied hiding spot carries no occupant (7a).
## Rejected requests are echoed to their sender's peer alone through `send_own`, in a batch of their own,
## so neither a spectator nor anyone else learns of a rejection (rule 7).
## Usage (composition root; keep a reference, a Callable does not keep this alive):
##   ping_delivery = PingDelivery.new(pings, monster, _ping_in_play, bf.appearance_of, _tick, _send_own)
##   sm.batch_extras.append(ping_delivery.entries)

var _pings: PingsCallouts
var _monster: int
var _in_play: Callable
var _identity_of: Callable
var _tick: Callable
var _send_own: Callable
## This tick's [record, monster receives it] pairs; rebuilt when the tick moves on.
var _out: Array = []
var _out_tick := -1
## Vector2i(sender, displayed id) -> its random handle.
var _handles: Dictionary[Vector2i, int] = {}
var _rng := RandomNumberGenerator.new()


## `in_play(player) -> bool`: the monster, or a survivor Healthy or Downed (Seized is Healthy here).
## `identity_of(player) -> int`: displayed appearance id. `tick() -> int`: the running tick.
## `send_own(player, bytes)`: sends reliable bytes to that player's own peer only.
func _init(pings: PingsCallouts, monster: int, in_play: Callable, identity_of: Callable, tick: Callable,
		send_own: Callable) -> void:
	_pings = pings
	_monster = monster
	_in_play = in_play
	_identity_of = identity_of
	_tick = tick
	_send_own = send_own
	_rng.randomize()


## This tick's ping entries for `player` (see the class doc). `full` (a rejoin) sends none: a ping is a
## transient marker, not round state.
func entries(player: int, full: bool = false) -> Array:
	if full:
		return []
	_refresh()
	var out: Array = []
	for pair: Array in _out:
		var rec: PingsCallouts.PingRecord = pair[0]
		if player != rec.sender and not (_in_play.call(player) and (player != _monster or pair[1])):
			continue
		var p := {"kind": rec.kind, "point": rec.point, "item": rec.target if rec.kind == PingsCallouts.ITEM else -1,
			"type": rec.item_type, "identity": rec.identity, "from": _identity_of.call(rec.sender)}
		p["handle"] = handle_of(rec.sender, p["from"])
		if player == rec.sender:
			p["own"] = true
		out.append([EventBatch.PING, p])
	return out


## The opaque marker handle of `sender` shown as displayed id `from`: random, stable for the pair, unique.
## Random rather than counted, so its value says nothing about who pinged first.
func handle_of(sender: int, from: int) -> int:
	var key := Vector2i(sender, from)
	if not _handles.has(key):
		var h: int = _rng.randi()
		while h in _handles.values():
			h = _rng.randi()
		_handles[key] = h
	return _handles[key]


## Once per tick: judges the monster's sight for this tick's records and sends this tick's rejections.
func _refresh() -> void:
	var t: int = _tick.call()
	if t == _out_tick:
		return
	_out_tick = t
	_out = []
	for rec in _pings.accepted():
		if rec.tick == t:
			_out.append([rec, _pings.monster_sees(rec)])
	for r: Array in _pings.rejected():
		var bytes := EventBatch.build(t, r[0], [], [], Vector3.ZERO, null, -1, [[EventBatch.PING_REJECTED, r[1]]])
		_send_own.call(r[0], bytes)
