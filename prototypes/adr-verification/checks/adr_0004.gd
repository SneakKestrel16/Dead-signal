extends "res://lib.gd"
## ADR-0004 Verification Required (1), (2), (3), (5). (4) is shared with ADR-0002 (6).
## One server and two clients in one process, each on its own SceneMultiplayer subtree.

const Probe := preload("res://probe.gd")

var allowed := {}   # peer id -> bool, read by the visibility filter in (3)


func run() -> void:
	await _spawner()
	await _node_path()


func _build_tree(root_name: String) -> MultiplayerSpawner:
	var world := Node3D.new()
	world.name = "World"
	api_root(root_name).add_child(world)
	var ents := Node3D.new()
	ents.name = "Entities"
	world.add_child(ents)
	var sp := MultiplayerSpawner.new()
	sp.name = "Spawner"
	world.add_child(sp)
	sp.spawn_path = NodePath("../Entities")
	sp.spawn_function = _spawn_entity
	return sp


## ADR-0004 §7 spawn order: synchronizer public_visibility false before spawn() returns.
func _spawn_entity(data: Variant) -> Node:
	var n := Node3D.new()
	n.name = "E%d" % int(data.id)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:position"))
	sync.replication_config = cfg
	sync.root_path = NodePath("..")
	sync.public_visibility = data.public
	if data.filtered:
		sync.add_visibility_filter(func(peer: int) -> bool: return allowed.get(peer, false))
	n.add_child(sync)
	return n


func _received_bytes(api: SceneMultiplayer) -> int:
	var host := (api.multiplayer_peer as ENetMultiplayerPeer).host
	return int(host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA))


func _spawner() -> void:
	var port := next_port()
	var srv := make_api("Vis_S")
	var sp := ENetMultiplayerPeer.new()
	sp.create_server(port, 8)
	srv.multiplayer_peer = sp
	var s_spawner := _build_tree("Vis_S")
	var clients: Array[SceneMultiplayer] = []
	var spawned := {"Vis_A": [], "Vis_B": []}
	for n in ["Vis_A", "Vis_B"]:
		var api := make_api(n)
		var cp := ENetMultiplayerPeer.new()
		cp.create_client("127.0.0.1", port)
		api.multiplayer_peer = cp
		var csp := _build_tree(n)
		var seen: Array = spawned[n]
		csp.spawned.connect(func(node: Node) -> void: seen.append(node.name))
		clients.append(api)
	var ok := await until(func() -> bool: return connected(clients[0]) and connected(clients[1]) and srv.get_peers().size() == 2, 3.0)
	if not ok:
		rec("0004-1", "FAIL", "clients did not connect")
		return
	var a_id := clients[0].get_unique_id()
	var b_id := clients[1].get_unique_id()
	await frames(20)
	_received_bytes(clients[0])
	_received_bytes(clients[1])
	# Idle baseline over 1 s.
	await until(func() -> bool: return false, 1.0)
	var idle_a := _received_bytes(clients[0])
	var idle_b := _received_bytes(clients[1])
	# (1)/(2) Hidden entity: spawn, then grant A only, same frame.
	var e7: Node3D = s_spawner.spawn({"id": 7, "public": false, "filtered": false})
	(e7.get_node("Sync") as MultiplayerSynchronizer).set_visibility_for(a_id, true)
	var end := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < end:
		e7.position.x += 0.01
		await tree.process_frame
	var a_has := api_root("Vis_A").has_node("World/Entities/E7")
	var b_has := api_root("Vis_B").has_node("World/Entities/E7")
	var win_a := _received_bytes(clients[0])
	var win_b := _received_bytes(clients[1])
	var a_pos := 0.0
	if a_has:
		a_pos = (api_root("Vis_A").get_node("World/Entities/E7") as Node3D).position.x
	var leak_ok: bool = a_has and not b_has and spawned["Vis_B"].is_empty() and win_b <= idle_b * 1.5 + 200
	rec("0004-1", "PASS" if leak_ok else "FAIL", "hidden spawn granted to A only: A has node=%s (synced x=%.2f), B has node=%s, B spawned signals=%s; bytes received over 1 s idle A=%d B=%d, while E7 moves A=%d B=%d" % [a_has, a_pos, b_has, spawned["Vis_B"], idle_a, idle_b, win_a, win_b])
	rec("0004-2", "PASS" if a_has else "FAIL", "set_visibility_for(A) called right after spawn() in the same frame: A received the spawn=%s" % a_has)
	# (3) Filter timing: public entity behind a filter, A not allowed yet.
	allowed[a_id] = false
	allowed[b_id] = false
	var e8: Node3D = s_spawner.spawn({"id": 8, "public": true, "filtered": true})
	await frames(30)
	var a_early := api_root("Vis_A").has_node("World/Entities/E8")
	allowed[a_id] = true
	var t0 := Time.get_ticks_msec()
	var f := 0
	while not api_root("Vis_A").has_node("World/Entities/E8") and f < 600:
		await tree.process_frame
		f += 1
	var auto_ms := Time.get_ticks_msec() - t0
	var a_late := api_root("Vis_A").has_node("World/Entities/E8")
	var mode := (e8.get_node("Sync") as MultiplayerSynchronizer).visibility_update_mode
	rec("0004-3", "OBSERVED", "add_visibility_filter: filtered-out peer got node=%s after 30 frames; after the filter flips true with no update_visibility call (visibility_update_mode=%d), A got it=%s after %d frames / %d ms; B has E8=%s" % [a_early, mode, a_late, f, auto_ms, api_root("Vis_B").has_node("World/Entities/E8")])
	for i in 2:
		close_api(clients[i], ["Vis_A", "Vis_B"][i])
	close_api(srv, "Vis_S")
	await frames(5)


## (5) The first RPC to a node carries its path: does the node name appear in the datagrams?
func _node_path() -> void:
	var port := next_port()
	var proxy_port := next_port()
	var srv := make_api("Path_S")
	var sp := ENetMultiplayerPeer.new()
	sp.create_server(port, 8)
	srv.multiplayer_peer = sp
	var proxy := UdpProxy.new()
	proxy.start(proxy_port, port)
	var cli := make_api("Path_C")
	var cp := ENetMultiplayerPeer.new()
	cp.create_client("127.0.0.1", proxy_port)
	cli.multiplayer_peer = cp
	var names := ["Player_4242", "Net"]
	var probes := {}
	for nm in names:
		for side in ["Path_S", "Path_C"]:
			var p: Node = Probe.new()
			p.name = nm
			api_root(side).add_child(p)
			Probe.configure(p, 1, 2)
			if side == "Path_S":
				probes[nm] = p
	var ok := await until(func() -> bool: return connected(cli) and srv.get_peers().size() == 1, 3.0, proxy)
	if not ok:
		rec("0004-5", "FAIL", "could not connect through proxy")
		return
	var cid: int = srv.get_peers()[0]
	var found := {}
	for nm in names:
		proxy.capture_down.clear()
		proxy.capture_enabled = true
		(probes[nm] as Node).rpc_id(cid, &"ping", 99)
		await until(func() -> bool: return false, 0.3, proxy)
		proxy.capture_enabled = false
		var needle: PackedByteArray = (nm as String).to_utf8_buffer()
		var hit := false
		for pkt in proxy.capture_down:
			if _contains(pkt, needle):
				hit = true
		found[nm] = hit
	var id_bytes := false
	proxy.capture_down.clear()
	proxy.capture_enabled = true
	(probes["Net"] as Node).rpc_id(cid, &"ping", 99)
	await until(func() -> bool: return false, 0.3, proxy)
	for pkt in proxy.capture_down:
		if _contains(pkt, "4242".to_utf8_buffer()):
			id_bytes = true
	var premise: bool = bool(found["Player_4242"])
	rec("0004-5", "OBSERVED" if premise else "FAIL", "first RPC to a node named Player_4242: name in datagrams=%s (premise of ADR-0004 §7a %s); fixed-name node Net: name sent=%s, later RPCs contain '4242'=%s" % [found["Player_4242"], "confirmed" if premise else "NOT confirmed", found["Net"], id_bytes])
	proxy.stop()
	close_api(cli, "Path_C")
	close_api(srv, "Path_S")
	await frames(5)


func _contains(hay: PackedByteArray, needle: PackedByteArray) -> bool:
	var n := needle.size()
	for i in hay.size() - n + 1:
		if hay.slice(i, i + n) == needle:
			return true
	return false
