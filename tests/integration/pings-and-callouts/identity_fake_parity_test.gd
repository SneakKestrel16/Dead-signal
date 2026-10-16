# Story pings-and-callouts/007 (design/gdd/pings-and-callouts.md rules 1, 12, 21, 24, 26-28; TR-pings-006,
# TR-pings-009; ADR-0004 per-peer payloads): five RoundClients over real ENet in a composed greybox round.
# A disguised monster's ping and callout carry the borrowed survivor's displayed id; the copied survivor's
# client alone gets not_you (a ping only when the sender is within callout_range_m, a callout always); a
# False Signal fake reaches a survivor as the same bytes as the real callout apart from the gesture flag; the
# gesture flag is set on every in-range survivor with sight of a real speaker; no ping or callout touches
# objective, downing, stun or outcome state. Scare-events story 004 leans on the parity assertion.
extends GdUnitTestSuite

const WAIT_S := 8.0
## How long a client that must receive nothing more is watched: 30 ticks at 60 Hz.
const QUIET_TICKS := 30
## A survivor's callout entry; nothing names the real/fake flag or the sender's player id.
## West end of the H-S corridor (x 10-60, one room, no inner walls): the survivors and the monster stand on one
## line along +x, in the open and in sight of each other.
## The A1 spawn put it through A1's east wall once the level had walls (AD-249). Bodies placed off the map are frozen.
const OPEN_LINE := Vector3(12.0, 0.0, 38.0)
const SURVIVOR_KEYS := ["line", "identity", "origin", "gesture", "voice"]

static var _next_port := 28730

var _knobs: Knobs
var _roots: Array[Node] = []
var _clients: Array[RoundClient] = []
var _c: RoundComposer
var _net: NetAuthority
var _map: MapData
## Decoded event batches with a callout entry, as received by the watched client's peer.
var _raw: Array[Dictionary] = []


class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	_clients = []
	_raw = []


func after_test() -> void:
	if _c != null:
		_c.stop()
		_c = null
	for c in _clients:
		c.close()
	await get_tree().process_frame
	for r in _roots + _clients:
		if not is_instance_valid(r):
			continue
		var api := r.multiplayer as SceneMultiplayer
		if api != null and api.multiplayer_peer != null:
			api.multiplayer_peer.close()
			api.multiplayer_peer = null
		get_tree().set_multiplayer(null, r.get_path())
		r.free()
	_roots.clear()
	_clients.clear()


func _info(token: String) -> Dictionary:
	var pid := token.trim_prefix("t").to_int()
	return {"player_id": pid, "name": "P%d" % pid}


func _look(id: int) -> int:
	return 1 + id % 5


func _until(cond: Callable, what: String) -> void:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end and not cond.call():
		await get_tree().physics_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Hosts, joins five clients and composes a round on the greybox; returns once every own body has spawned.
func _compose() -> void:
	var server_root := Node3D.new()
	server_root.name = "Host"
	get_tree().root.add_child(server_root)
	_roots.append(server_root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), server_root.get_path())
	_map = MapData.load_map()
	MapGreybox.build(server_root, _map)
	_net = NetAuthority.new()
	_net.setup(_knobs, _knobs.join_version(RoundClient.VERSION_BUILD), FakeLobby.new())
	server_root.add_child(_net)
	_next_port += 1
	assert_int(_net.host(_next_port)).is_equal(OK)
	for i in 5:
		var c := RoundClient.new(_knobs, TestMoveStep.apply, TestMoveStep.make_body, _map, false)
		c.name = "C%d" % i
		get_tree().root.add_child(c)
		_clients.append(c)
		assert_int(c.join("127.0.0.1", _next_port, "P%d" % i)).is_equal(OK)
		c.scripted = InputFrame.new()
	await _until(func() -> bool: return _clients.all(func(c: RoundClient) -> bool: return c.is_ready()), "5 joined")
	var tokens := PackedStringArray()
	for c in _clients:
		tokens.append("t%d" % c.net.local_player_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var roster := Roster.lock(tokens, _info, "s-pc7", 1, _knobs, RotationQueue.new(), rng)
	_c = RoundComposer.new(_knobs, roster, _map, _net, server_root.multiplayer as SceneMultiplayer, server_root,
			TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _look)
	var server := RoundServer.new()
	server_root.add_child(server)
	assert_array(_c.start(server, rng)).is_empty()
	await _until(func() -> bool: return _clients.all(func(c: RoundClient) -> bool: return c.is_spawned()),
			"every own body spawned")


func _client(player: int) -> RoundClient:
	for c in _clients:
		if c.net.local_player_id == player:
			return c
	return null


## Pins `player`'s server body at `at` (frozen, so the distances the test is about do not drift).
func _place(player: int, at: Vector3) -> void:
	_c.sm.set_frozen(player, true)
	_c.bodies[player].global_position = at


## Puts the monster in `survivor`'s borrowed form (Borrowed Face's own path is its stories' to test).
func _disguise_as(survivor: int) -> void:
	_c.bf._form = survivor


func _pings_got(players: Array, n: int) -> bool:
	return players.all(func(id: int) -> bool: return _client(id).pings.received.size() == n)


func _calls_got(players: Array, n: int) -> bool:
	return players.all(func(id: int) -> bool: return _client(id).callouts.received.size() == n)


## Sends a location ping from `sender`'s client at a point 1 m beside and above its feet (clear of the floor),
## its bucket refilled first.
func _ping(sender: int) -> void:
	_c.pings._tokens.erase(sender)
	_client(sender).pings.request(PingsCallouts.LOCATION, _c.bodies[sender].global_position + Vector3(1.0, 1.0, 0.0))


## Sends `line` from `sender`'s client with its callout limits cleared (limits are story 003's).
func _call_out(sender: int, line: StringName) -> void:
	_c.pings._last_callout_any.erase(sender)
	_c.pings._last_callout.erase(sender)
	_client(sender).callouts.request(line)


## A False Signal fake callout as `survivor` at `at` (Monster Abilities validated it; its stories test that).
func _fake(survivor: int, line: StringName, at: Vector3) -> void:
	var e := EvAbilityUsed.new()
	e.ability = MonsterAbilities.Ability.FALSE_SIGNAL
	e.detail = MonsterAbilities.SIGNAL_DETAILS[MonsterAbilities.SignalType.CALLOUT]
	e.survivor = survivor
	e.line = line
	e.target = at
	_c.server.bus.emit(e)


## Objective, downing, stun and outcome state, read through the owners' getters.
func _state() -> String:
	var mf := _c.lifecycle.match_flow()
	var o := _c.objectives
	var out: Array = [mf.is_ended(), o._states, o._carriers, o._fuse_states, o._fuse_carriers, o._slots,
		o._terminal, o._active]
	for id: int in _c.survivors + [_c.monster]:
		out.append([id, mf.status_of(id), _c.downing.life_state(id), _c.downing.downs_taken(id),
			_c.downing.eligible(id), _c.sd.locked(id)])
	return var_to_str(out)


## peer_packet handler on the watched survivor's client: keeps each event batch carrying a callout.
func _on_raw(_peer: int, bytes: PackedByteArray) -> void:
	var b := EventBatch.decode(bytes)
	if not b.is_empty() and b["entries"].any(func(e: Array) -> bool: return e[0] == EventBatch.CALLOUT):
		_raw.append(b)


## A batch's callout entries with the fields the parity rule permits to differ (tick, gesture) blanked.
func _parity_bytes(b: Dictionary) -> PackedByteArray:
	var calls: Array = []
	for e: Array in b["entries"]:
		if e[0] == EventBatch.CALLOUT:
			var p: Dictionary = e[1].duplicate()
			p["gesture"] = false
			calls.append([e[0], p])
	return var_to_bytes([0, calls])


## Indices where two equal-length byte arrays differ.
func _diff(a: PackedByteArray, b: PackedByteArray) -> Array[int]:
	var out: Array[int] = []
	for i in a.size():
		if a[i] != b[i]:
			out.append(i)
	return out


## Every dictionary key anywhere in `v`, lower-cased.
func _keys(v: Variant, out: Array[String]) -> Array[String]:
	if v is Dictionary:
		for k: Variant in v:
			out.append(str(k).to_lower())
			_keys(v[k], out)
	elif v is Array:
		for x: Variant in v:
			_keys(x, out)
	return out


func test_ping_not_you_only_on_the_copied_survivor_and_only_within_callout_range() -> void:
	await _compose()
	var s: Array = _c.survivors
	var base := OPEN_LINE
	var near := _knobs.ping.callout_range_m - 5.0
	for i in s.size():
		_place(s[i], base + Vector3(3.0 * i, 0.0, 0.0))
	_place(_c.monster, base + Vector3(3.0 + near, 0.0, 0.0))
	_disguise_as(s[1])
	await _ticks(2)
	var borrowed: int = _c.bf.appearance_of(s[1])
	# Near the copied survivor: every living survivor sees the borrowed name; only s[1] gets the mark.
	_ping(_c.monster)
	await _until(_pings_got.bind(s, 1), "every survivor gets the disguised ping")
	for id: int in s:
		var p: Dictionary = _client(id).pings.received[0]
		assert_int(p["from"]).is_equal(borrowed)
		assert_bool(p.get("not_you", false)).override_failure_message("not_you on %d" % id).is_equal(id == s[1])
	# Beyond callout_range_m: the ping stays a usable lie, unmarked.
	_place(_c.monster, base + Vector3(3.0 + _knobs.ping.callout_range_m + 5.0, 0.0, 0.0))
	await _ticks(2)
	_ping(_c.monster)
	await _until(_pings_got.bind(s, 2), "every survivor gets the far disguised ping")
	for id: int in s:
		assert_bool(_client(id).pings.received[1].has("not_you")).is_false()
	# The real survivor's own ping, the monster wearing its face nearby: nobody is marked (the monster neither).
	_place(_c.monster, base + Vector3(3.0 + near, 0.0, 0.0))
	await _ticks(2)
	_ping(s[1])
	await _until(_pings_got.bind(s + [_c.monster], 3), "the real survivor's ping reaches all")
	for id: int in s + [_c.monster]:
		assert_bool(_client(id).pings.received[-1].has("not_you")).is_false()
	assert_int(_client(s[0]).pings.received[2]["from"]).is_equal(borrowed)
	# Rule 24: duplicate names are not merged; the handles keep the two bodies apart.
	assert_int(_client(s[0]).pings.received[2]["handle"]).is_not_equal(_client(s[0]).pings.received[0]["handle"])


func test_fake_callout_matches_real_except_gesture_and_changes_no_round_state() -> void:
	await _compose()
	var s: Array = _c.survivors
	var base := OPEN_LINE
	var speaker: int = s[1]
	var watcher: int = s[2]
	_place(s[0], base)
	_place(speaker, base + Vector3(5.0, 0.0, 0.0))
	_place(watcher, base + Vector3(10.0, 0.0, 0.0))
	_place(s[3], base + Vector3(-60.0, 0.0, 0.0))
	_place(_c.monster, base + Vector3(0.0, 0.0, 10.0))
	_disguise_as(speaker)
	await _ticks(2)
	(_client(watcher).multiplayer as SceneMultiplayer).peer_packet.connect(_on_raw)
	var before := _state()
	var at: Vector3 = _c.bodies[speaker].global_position
	# A client cannot name a sender: a callout packet with any extra field is not a callout.
	assert_dict(PingsCallouts.decode_callout(var_to_bytes({PingsCallouts.CALLOUT_KEY: PingsCallouts.DANGER,
		PingsCallouts.TARGET_KEY: -1, "identity": 1}))).is_empty()
	# Real callout from the speaker: the gesture flag reaches every survivor in range with sight of the speaker.
	_call_out(speaker, PingsCallouts.DANGER)
	var heard := [s[0], speaker, watcher]
	await _until(_calls_got.bind(heard, 1), "the real callout reaches the three near survivors")
	var up := Vector3.UP * _knobs.controller.eye_height_m
	for id: int in [s[0], watcher]:
		assert_bool(_c._ping_clear(id, _c.bodies[id].global_position + up, at + up, -1)).is_true()
		assert_bool(_client(id).callouts.received[0]["gesture"]).is_true()
	assert_bool(_client(speaker).callouts.received[0].has("not_you")).is_false()
	# The fake as the speaker at the speaker's own spot.
	_fake(speaker, PingsCallouts.DANGER, at)
	await _until(_calls_got.bind(heard, 2), "the fake reaches the three near survivors")
	await _until(func() -> bool: return _raw.size() == 2, "the watcher's peer got both batches")
	var real: Dictionary = _client(watcher).callouts.received[0]
	var fake: Dictionary = _client(watcher).callouts.received[1]
	# The capture scare-events/004 relies on: identical apart from the gesture.
	assert_array(fake.keys()).contains_exactly_in_any_order(SURVIVOR_KEYS)
	var flipped := real.duplicate()
	flipped["gesture"] = false
	assert_dict(fake).is_equal(flipped)
	assert_bool(fake["gesture"]).is_false()
	# Byte diff of the two entries: same size, differing only where flipping the gesture alone differs.
	var rb := var_to_bytes(real)
	var fb := var_to_bytes(fake)
	assert_int(fb.size()).is_equal(rb.size())
	assert_array(_diff(rb, fb)).is_not_empty().is_equal(_diff(rb, var_to_bytes(flipped)))
	# The batches on the wire: equal once tick and gesture are blanked, and no real/fake or sender field anywhere.
	assert_bool(_parity_bytes(_raw[0]) == _parity_bytes(_raw[1])).is_true()
	for b in _raw:
		for k in _keys(b, []):
			assert_bool(k.contains("fake") or k.contains("real") or k.contains("sender")) \
					.override_failure_message("key " + k).is_false()
	# The impersonated survivor alone sees the mark on the fake.
	for id: int in heard:
		assert_bool(_client(id).callouts.received[1].get("not_you", false)).is_equal(id == speaker)
	# A disguised monster's real callout: the borrowed name and voice to the near survivors, the mark on the
	# copied survivor, nothing to the far one.
	_call_out(_c.monster, &"follow_me")
	await _until(_calls_got.bind(heard, 3), "the disguised callout reaches the near survivors")
	for id: int in heard:
		var p: Dictionary = _client(id).callouts.received[2]
		assert_int(p["identity"]).is_equal(_c.bf.appearance_of(speaker))
		assert_str(p["voice"]).is_equal(real["voice"])
		assert_bool(p.get("not_you", false)).is_equal(id == speaker)
	await _ticks(QUIET_TICKS)
	assert_int(_client(s[3]).callouts.received.size()).is_equal(0)
	# No ping or callout touched objective, downing, stun or outcome state.
	_ping(s[0])
	await _until(_pings_got.bind([s[0]], 1), "a ping lands")
	await _ticks(2)
	assert_str(_state()).is_equal(before)
