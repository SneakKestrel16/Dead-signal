# Story pings-and-callouts/006 (design/gdd/pings-and-callouts.md rules 4, 10, 11, 14, 14a, 27; Formulas "Callout
# recipients"; TR-pings-004, TR-pings-002; ADR-0004 per-peer payloads): five RoundClients over real ENet in a
# composed greybox round. Straight-line distance from the origin decides who gets a callout, walls never; the
# monster's client gets only the smaller audio entry; a hidden sender and a fake carry no gesture; a spectator
# mirrors its watched survivor; every authored line reaches the other three survivors with voice off.
extends GdUnitTestSuite

const WAIT_S := 8.0
## How long a client that must receive nothing is watched after the others got it: 30 ticks at 60 Hz.
const QUIET_TICKS := 30
## A survivor's callout entry; nothing names the real/fake flag or the sender's player id.
const SURVIVOR_KEYS := ["line", "identity", "origin", "gesture", "voice"]
## The monster's audio entry: no feed text, name or direction field.
const MONSTER_KEYS := ["line", "voice", "origin"]

static var _next_port := 28940

var _knobs: Knobs
var _roots: Array[Node] = []
var _clients: Array[RoundClient] = []
var _c: RoundComposer
var _net: NetAuthority
var _map: MapData


class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	_clients = []


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
	var roster := Roster.lock(tokens, _info, "s-pc6", 1, _knobs, RotationQueue.new(), rng)
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


## Pins `player`'s server body at `at` (frozen: the greybox has floors per volume only, and a falling body
## would drift the straight-line distance the test is about).
func _place(player: int, at: Vector3) -> void:
	_c.sm.set_frozen(player, true)
	_c.bodies[player].global_position = at


## A wall (WORLD layer, as greybox floors) across the straight line from `a` to `b`, halfway.
func _wall_between(a: Vector3, b: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	wall.collision_mask = PhysicsLayers.NONE
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 6.0, 0.2)
	cs.shape = box
	wall.add_child(cs)
	_roots[0].add_child(wall)
	wall.global_position = (a + b) / 2.0 + Vector3.UP * 2.0


## Sends `line` from `sender`'s client with its callout limits cleared, so one test can send several lines
## without waiting out callout_global_cooldown_s (limits are story 003's, tested there).
func _call_out(sender: int, line: StringName) -> void:
	_c.pings._last_callout_any.erase(sender)
	_c.pings._last_callout.erase(sender)
	_client(sender).callouts.request(line)


func _got(players: Array, n: int) -> bool:
	return players.all(func(id: int) -> bool: return _client(id).callouts.received.size() == n)


func _counts() -> Array[int]:
	var out: Array[int] = []
	for c in _clients:
		out.append(c.callouts.received.size() + c.callouts.audio.size())
	return out


func test_range_decides_walls_do_not_and_the_monster_gets_audio_only() -> void:
	await _compose()
	var s: Array = _c.survivors
	var base: Vector3 = _c.bodies[s[0]].global_position
	_place(s[0], base)
	_place(s[1], base + Vector3(10.0, 0.0, 0.0))
	_place(s[2], base + Vector3(30.0, 0.0, 0.0))
	_place(s[3], base + Vector3(-50.0, 0.0, 0.0))
	_place(_c.monster, base + Vector3(0.0, 0.0, -38.0))
	_wall_between(base, base + Vector3(0.0, 0.0, -38.0))
	await _ticks(2)
	var up := Vector3.UP * _knobs.controller.eye_height_m
	assert_bool(_c._ping_clear(_c.monster, base + Vector3(0.0, 0.0, -38.0) + up, base + up, -1)).is_false()
	# "Danger" (callout_range_m 25): the sender and the survivor at 10 m; 30 m, 50 m and the monster at 38 m nothing.
	_call_out(s[0], PingsCallouts.DANGER)
	await _until(_got.bind([s[0], s[1]], 1), "the sender and the near survivor get Danger")
	await _ticks(QUIET_TICKS)
	assert_array(_counts()).is_equal(_expect({s[0]: 1, s[1]: 1}))
	var p: Dictionary = _client(s[1]).callouts.received[0]
	assert_array(p.keys()).contains_exactly_in_any_order(SURVIVOR_KEYS)
	assert_str(p["line"]).is_equal("danger")
	assert_int(p["identity"]).is_equal(_c.bf.appearance_of(s[0]))
	assert_vector(p["origin"]).is_equal(base)
	assert_bool(p["gesture"]).is_true()
	assert_str(p["voice"]).is_not_empty()
	# A Downed survivor's "Need rescue" (rescue_callout_range_m 40) through the wall: the monster at 38 m gets
	# the audio entry only; the survivor at 30 m gets the full one; 50 m nothing.
	_c.downing._life[s[0]] = Downing.LifeState.DOWNED
	_call_out(s[0], PingsCallouts.NEED_RESCUE)
	await _until(func() -> bool: return _client(_c.monster).callouts.audio.size() == 1 and _got([s[0], s[1], s[2]], 2) \
			or _got([s[2]], 1), "Need rescue reaches 40 m")
	await _ticks(QUIET_TICKS)
	assert_array(_counts()).is_equal(_expect({s[0]: 2, s[1]: 2, s[2]: 1, _c.monster: 1}))
	assert_array(_client(_c.monster).callouts.received).is_empty()
	var a: Dictionary = _client(_c.monster).callouts.audio[0]
	assert_array(a.keys()).contains_exactly_in_any_order(MONSTER_KEYS)
	assert_str(a["line"]).is_equal("need_rescue")
	assert_vector(a["origin"]).is_equal(base)
	assert_str(a["voice"]).is_equal(p["voice"])
	# A False Signal fake as s[1] at s[1]'s spot: the same entry shape, no gesture, and nothing says fake.
	var e := EvAbilityUsed.new()
	e.ability = MonsterAbilities.Ability.FALSE_SIGNAL
	e.detail = MonsterAbilities.SIGNAL_DETAILS[MonsterAbilities.SignalType.CALLOUT]
	e.survivor = s[1]
	e.line = PingsCallouts.DANGER
	e.target = base + Vector3(10.0, 0.0, 0.0)
	_c.server.bus.emit(e)
	await _until(func() -> bool: return _got([s[0], s[1]], 3) and _got([s[2]], 2), "the fake reaches 25 m of its point")
	var f: Dictionary = _client(s[2]).callouts.received[1]
	assert_array(f.keys()).contains_exactly_in_any_order(SURVIVOR_KEYS)
	assert_int(f["identity"]).is_equal(_c.bf.appearance_of(s[1]))
	assert_bool(f["gesture"]).is_false()


## Expected per-client totals in _clients order: `n` maps player id -> count, others 0.
func _expect(n: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for c in _clients:
		out.append(n.get(c.net.local_player_id, 0))
	return out


func test_every_line_reaches_survivors_hidden_sender_has_no_gesture_and_spectator_mirrors() -> void:
	await _compose()
	var s: Array = _c.survivors
	var base: Vector3 = _c.bodies[s[0]].global_position
	for i in s.size():
		_place(s[i], base + Vector3(3.0 * i, 0.0, 0.0))
	_place(_c.monster, base + Vector3(0.0, 0.0, -100.0))
	await _ticks(2)
	# Rule 4 with proximity voice off: each line (objective found and location: Drive/Fuse here; rescue: Need
	# rescue; danger: Danger; distrust: That wasn't me; regroup: Follow me, I'm with you, Wait) reaches the other 3.
	var lines := PingsCallouts.CALLOUT_LINES
	assert_int(lines.size()).is_equal(8)
	for i in lines.size():
		_call_out(s[0], lines[i])
		await _until(_got.bind(s, i + 1), "every survivor gets " + lines[i])
		for id: int in s:
			assert_str(_client(id).callouts.received[i]["line"]).is_equal(lines[i])
	# Hidden sender (rule 14a): plays from the spot, no gesture.
	_c.hs.hide_completed(s[1], 0)
	assert_bool(_c.sd.is_hidden(s[1])).is_true()
	_call_out(s[1], PingsCallouts.DANGER)
	await _until(_got.bind(s, 9), "every survivor gets the hidden callout")
	var h: Dictionary = _client(s[0]).callouts.received[8]
	assert_bool(h["gesture"]).is_false()
	assert_vector(h["origin"]).is_equal(_c.bodies[s[1]].global_position)
	# Spectator: receives exactly what its watched survivor receives.
	var dead: int = s[3]
	var ev := EvSurvivorEliminated.new()
	ev.survivor = dead
	_c.server.bus.emit(ev)
	await _until(func() -> bool: return _c.lifecycle.watched_by(dead) != -1, "the eliminated survivor spectates")
	var watched := _c.lifecycle.watched_by(dead)
	var others := s.filter(func(id: int) -> bool: return id != dead and id != watched)
	var sender: int = others[0]
	var near: int = others[1]
	_place(watched, base + Vector3(0.0, 0.0, 80.0))
	await _ticks(2)
	var before := _client(dead).callouts.received.size()
	_call_out(sender, &"wait") # out of the watched survivor's range
	await _until(_got.bind([near], 10), "a near survivor gets Wait")
	await _ticks(QUIET_TICKS)
	assert_int(_client(dead).callouts.received.size()).is_equal(before)
	_place(watched, base)
	await _ticks(2)
	_call_out(sender, &"follow_me")
	await _until(_got.bind([dead], before + 1), "the spectator mirrors its watched survivor")
	assert_dict(_client(dead).callouts.received[-1]).is_equal(_client(watched).callouts.received[-1])
