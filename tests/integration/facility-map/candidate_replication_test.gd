# Story facility-map/008: candidate replication and discovery agreement (research-facility.md AC 4;
# survivor-objectives.md rules 5 and 7; ADR-0012 §5-6; ADR-0004 §7). One server and five clients over
# real ENet on 127.0.0.1 (one monster, four survivors), each on its own SceneMultiplayer subtree. One
# survivor connects through a UDP proxy that records every datagram the server sends it, so "holds no
# data for an undiscovered point" is checked on the raw bytes. Discovery itself is SO-9's rule: here the
# server calls CandidateReplication.discover() directly, the hook SO-9 will call.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const SEED := 10080
const ROUNDS := 10
const SURVIVORS := 4

static var _next_port := 28400

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


## Forwards UDP between one client and the server, recording what the server sends down.
class UdpProxy extends RefCounted:
	var down: Array[PackedByteArray] = []
	var _front := PacketPeerUDP.new()
	var _back := PacketPeerUDP.new()
	var _client_ip := ""
	var _client_port := 0

	func start(listen_port: int, server_port: int) -> void:
		_front.bind(listen_port, "127.0.0.1")
		_back.connect_to_host("127.0.0.1", server_port)

	func pump() -> void:
		while _front.get_available_packet_count() > 0:
			var p := _front.get_packet()
			_client_ip = _front.get_packet_ip()
			_client_port = _front.get_packet_port()
			_back.put_packet(p)
		while _back.get_available_packet_count() > 0:
			var p := _back.get_packet()
			down.append(p)
			if _client_port != 0:
				_front.set_dest_address(_client_ip, _client_port)
				_front.put_packet(p)

	func stop() -> void:
		_front.close()
		_back.close()


class Client extends RefCounted:
	var root: Node
	var net: NetAuthority
	var hidden: HiddenSpawner
	var proxy: UdpProxy


var _knobs: Knobs
var _port: int
var _roots: Array[Node] = []
var _proxy: UdpProxy
var _server: NetAuthority
var _server_hidden: HiddenSpawner
var _map: MapData


func before_test() -> void:
	_knobs = Knobs.load_all()
	_map = MapData.load_map()
	_next_port += 2
	_port = _next_port
	var root := _root()
	_server = NetAuthority.new()
	_server.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	root.add_child(_server)
	_server_hidden = HiddenSpawner.new()
	root.add_child(_server_hidden)
	_server_hidden.setup(_server)
	assert_int(_server.host(_port)).is_equal(OK)


func after_test() -> void:
	_server_hidden.clear()
	for i in 5:
		_poll()
		await get_tree().process_frame
	if _proxy != null:
		_proxy.stop()
		_proxy = null
	for r in _roots:
		for n in r.get_children():
			if n is NetAuthority:
				n.close()
		var api := r.multiplayer as SceneMultiplayer
		if api.multiplayer_peer != null:
			api.multiplayer_peer.close()
		api.multiplayer_peer = null
		get_tree().set_multiplayer(null, r.get_path())
		r.free()
	_roots.clear()


# --- rig ---------------------------------------------------------------------------

func _root() -> Node:
	var n := Node.new()
	n.name = "Cr%d" % _roots.size()
	get_tree().root.add_child(n)
	get_tree().set_multiplayer(SceneMultiplayer.new(), n.get_path())
	_roots.append(n)
	return n


func _poll() -> void:
	if _proxy != null:
		_proxy.pump()
	for r in _roots:
		(r.multiplayer as SceneMultiplayer).poll()


func _until(cond: Callable, what: String) -> void:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end:
		_poll()
		if cond.call():
			return
		await get_tree().process_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()


func _join(display_name: String, proxied := false) -> Client:
	var c := Client.new()
	c.root = _root()
	c.net = NetAuthority.new()
	c.net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	c.root.add_child(c.net)
	c.hidden = HiddenSpawner.new()
	c.root.add_child(c.hidden)
	var port := _port
	if proxied:
		_proxy = UdpProxy.new()
		c.proxy = _proxy
		port = _port + 1
		_proxy.start(port, _port)
	assert_int(c.net.join("127.0.0.1", port, display_name)).is_equal(OK)
	await _until(func() -> bool: return c.net.local_player_id != -1, display_name + " joined")
	return c


## What a client shows: "kind@position" for every entity it holds, sorted.
func _shown(c: Client) -> PackedStringArray:
	var out := PackedStringArray()
	for n: Node3D in c.hidden.get_node(^"Entities").get_children():
		out.append(_key(n.get_meta(&"data").kind, n.position))
	out.sort()
	return out


func _key(kind: StringName, pos: Vector3) -> String:
	return "%s@%s" % [kind, pos]


## The server's view of what `markers` (indices) should look like on a client, sorted.
func _expected(markers: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for i: int in markers:
		out.append(_key(_map.markers[i].type, _map.markers[i].position))
	out.sort()
	return out


func _all_show(clients: Array, markers: Array) -> bool:
	var want := _expected(markers)
	return clients.all(func(c: Client) -> bool: return _shown(c) == want)


func _pos_bytes(p: Vector3) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(12)
	b.encode_float(0, p.x)
	b.encode_float(4, p.y)
	b.encode_float(8, p.z)
	return b


func _contains(hay: PackedByteArray, needle: PackedByteArray) -> bool:
	var n := needle.size()
	for i in hay.size() - n + 1:
		if hay[i] == needle[0] and hay.slice(i, i + n) == needle:
			return true
	return false


func _captured_since(from: int) -> PackedByteArray:
	var all := PackedByteArray()
	for i in range(from, _proxy.down.size()):
		all.append_array(_proxy.down[i])
	return all


# --- AC1 + AC2 -----------------------------------------------------------------------

## Ten seeded rounds. From round start every client shows the active fuse boxes and terminal and the
## monster shows all seven points, each at its marker (the logged) position. A drive room or fuse spawn
## reaches survivors only once discovered, then on all four at its position; until then the proxied
## survivor's capture holds neither its position bytes nor its node.
func test_ten_rounds_known_points_from_start_hidden_points_only_after_discovery() -> void:
	var monster := await _join("Monster")
	var survivors: Array = []
	survivors.append(await _join("Sv0", true))
	for i in range(1, SURVIVORS):
		survivors.append(await _join("Sv%d" % i))
	var everyone: Array = [monster] + survivors
	var survivor_ids: Array[int] = []
	for c: Client in survivors:
		survivor_ids.append(c.net.local_player_id)
	var placements := CandidateSelection.valid_placements(_map)
	var rep := CandidateReplication.new(_server_hidden, _map)
	for r in ROUNDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + r
		var active := CandidateSelection.pick(placements, rng)
		var known: Array = []
		var hidden: Array = []
		for i in active:
			(known if _map.markers[i].type in [&"fuse_box", &"terminal"] else hidden).append(i)
		assert_int(known.size()).is_equal(3)
		assert_int(hidden.size()).is_equal(4)
		var from := _proxy.down.size()
		rep.start_round(active, survivor_ids, monster.net.local_player_id)
		await _until(func() -> bool: return _all_show([monster], Array(active)) and _all_show(survivors, known),
				"round %d start" % r)
		for i: int in hidden:
			assert_bool(rep.is_discovered(i)).is_false()
		# First discovery. Its arrival on a peer orders after that peer's round-start spawns (one reliable
		# channel), so the survivors' state now is settled: the other three are absent.
		assert_bool(rep.discover(hidden[0])).is_true()
		assert_bool(rep.discover(hidden[0])).is_false() ## permanent for the round; once
		assert_bool(rep.is_discovered(hidden[0])).is_true()
		await _until(func() -> bool: return _all_show(survivors, known + [hidden[0]]), "round %d first discovery" % r)
		var seen := _captured_since(from)
		assert_bool(_contains(seen, _pos_bytes(_map.markers[hidden[0]].position))).is_true() ## the scan sees positions
		for i: int in hidden.slice(1):
			assert_bool(_contains(seen, _pos_bytes(_map.markers[i].position))) \
					.override_failure_message("round %d: undiscovered %s reached a survivor" % [r, _map.markers[i].id]).is_false()
		for i: int in hidden.slice(1):
			rep.discover(i)
		await _until(func() -> bool: return _all_show(everyone, Array(active)), "round %d all discovered" % r)
		rep.end_round()
		await _until(func() -> bool: return _all_show(everyone, []), "round %d cleared" % r)
		assert_bool(rep.is_discovered(hidden[0])).is_false()
