extends "res://lib.gd"
## ADR-0001 Verification Required (1)-(6), single machine.


func run() -> void:
	_defaults()
	_random_bytes()
	await _bind()
	await _reject_reason(0.0)
	await _reject_reason(0.2)
	await _auth_timeout()
	await _peer_timeout(true)
	await _peer_timeout(false)


func _defaults() -> void:
	var smp := SceneMultiplayer.new()
	rec("0001-3", "OBSERVED", "SceneMultiplayer.server_relay default=%s (ADR sets false regardless)" % smp.server_relay)
	rec("0001-2a", "OBSERVED", "SceneMultiplayer.auth_timeout default=%s s" % smp.auth_timeout)


func _random_bytes() -> void:
	var c := Crypto.new()
	var a := c.generate_random_bytes(16)
	var b := c.generate_random_bytes(16)
	var ok := a.size() == 16 and b.size() == 16 and a != b
	rec("0001-4", "PASS" if ok else "FAIL", "generate_random_bytes(16): sizes %d/%d, distinct=%s, hex=%s" % [a.size(), b.size(), a != b, a.hex_encode()])


## (5) create_server with the default bind address: reachable over IPv4 and IPv6 loopback?
func _bind() -> void:
	var port := next_port()
	var srv := make_api("Bind_S")
	var sp := ENetMultiplayerPeer.new()
	var err := sp.create_server(port, 8)
	srv.multiplayer_peer = sp
	var c4 := make_api("Bind_C4")
	var p4 := ENetMultiplayerPeer.new()
	var e4 := p4.create_client("127.0.0.1", port)
	c4.multiplayer_peer = p4
	var c6 := make_api("Bind_C6")
	var p6 := ENetMultiplayerPeer.new()
	var e6 := p6.create_client("::1", port)
	c6.multiplayer_peer = p6
	await until(func() -> bool: return connected(c4) and connected(c6), 3.0)
	rec("0001-5", "OBSERVED", "create_server(err=%d) default bind: IPv4 127.0.0.1 connected=%s (create_client err=%d); IPv6 ::1 connected=%s (create_client err=%d)" % [err, connected(c4), e4, connected(c6), e6])
	close_api(c4, "Bind_C4")
	close_api(c6, "Bind_C6")
	close_api(srv, "Bind_S")
	await frames(5)


## (6) Does the reject reason survive send_auth followed by disconnect_peer after delay_s?
func _reject_reason(delay_s: float) -> void:
	var port := next_port()
	var got: Array[String] = []
	var srv := make_api("Rej_S")
	srv.auth_callback = func(id: int, _data: PackedByteArray) -> void:
		srv.send_auth(id, "reject:lobby_full".to_utf8_buffer())
		if delay_s > 0.0:
			await tree.create_timer(delay_s).timeout
		srv.disconnect_peer(id)
	var sp := ENetMultiplayerPeer.new()
	sp.create_server(port, 8)
	srv.multiplayer_peer = sp
	var cli := make_api("Rej_C")
	cli.auth_callback = func(_id: int, data: PackedByteArray) -> void:
		got.append(data.get_string_from_utf8())
	cli.peer_authenticating.connect(func(id: int) -> void:
		cli.send_auth(id, "hello".to_utf8_buffer()))
	var cp := ENetMultiplayerPeer.new()
	cp.create_client("127.0.0.1", port)
	cli.multiplayer_peer = cp
	await until(func() -> bool: return got.size() > 0, 3.0)
	var ok := got.size() > 0 and got[0] == "reject:lobby_full"
	if delay_s == 0.0:
		rec("0001-6a", "OBSERVED", "back-to-back send_auth + disconnect_peer: reason received=%s %s" % [ok, got])
	else:
		rec("0001-6b", "PASS" if ok else "FAIL", "disconnect_peer %.1f s after send_auth (ADR reject_close_delay_s): reason received=%s %s" % [delay_s, ok, got])
	close_api(cli, "Rej_C")
	close_api(srv, "Rej_S")
	await frames(5)


## (2) auth_timeout scope: a client that never sends auth is dropped after auth_timeout.
func _auth_timeout() -> void:
	var port := next_port()
	var failed_at := [-1]
	var srv := make_api("Tmo_S")
	srv.auth_timeout = 1.0
	srv.auth_callback = func(_id: int, _data: PackedByteArray) -> void:
		pass
	srv.peer_authentication_failed.connect(func(_id: int) -> void:
		failed_at[0] = Time.get_ticks_msec())
	var sp := ENetMultiplayerPeer.new()
	sp.create_server(port, 8)
	srv.multiplayer_peer = sp
	var cli := make_api("Tmo_C")
	cli.auth_callback = func(_id: int, _data: PackedByteArray) -> void:
		pass
	var cp := ENetMultiplayerPeer.new()
	cp.create_client("127.0.0.1", port)
	var t0 := Time.get_ticks_msec()
	cli.multiplayer_peer = cp
	await until(func() -> bool: return failed_at[0] >= 0, 5.0)
	var dt: int = failed_at[0] - t0 if failed_at[0] >= 0 else -1
	var ok := dt >= 900 and dt <= 2000
	rec("0001-2b", "PASS" if ok else "FAIL", "auth_timeout=1.0: silent client failed auth after %d ms (peer_authentication_failed); client status now %d" % [dt, cp.get_connection_status()])
	close_api(cli, "Tmo_C")
	close_api(srv, "Tmo_S")
	await frames(5)


## (1) ENet dead-peer detection: the client vanishes without notice (ENetPacketPeer.reset).
func _peer_timeout(custom: bool) -> void:
	var port := next_port()
	var tag := "Pt%s" % ("C" if custom else "D")
	var gone_at := [-1]
	var srv := make_api(tag + "_S")
	var sp := ENetMultiplayerPeer.new()
	sp.create_server(port, 8)
	srv.multiplayer_peer = sp
	srv.peer_connected.connect(func(id: int) -> void:
		if custom:
			sp.get_peer(id).set_timeout(32, 1000, 2000))
	srv.peer_disconnected.connect(func(_id: int) -> void:
		gone_at[0] = Time.get_ticks_msec())
	var cli := make_api(tag + "_C")
	var cp := ENetMultiplayerPeer.new()
	cp.create_client("127.0.0.1", port)
	cli.multiplayer_peer = cp
	await until(func() -> bool: return connected(cli) and srv.get_peers().size() == 1, 3.0)
	await frames(10)
	cp.get_peer(1).reset()
	var t0 := Time.get_ticks_msec()
	await until(func() -> bool: return gone_at[0] >= 0, 45.0)
	var dt: int = gone_at[0] - t0 if gone_at[0] >= 0 else -1
	if custom:
		# Bound: timeout_max 2000 ms plus ENet's ping interval and frame slack.
		var ok := dt >= 900 and dt <= 4000
		rec("0001-1b", "PASS" if ok else "FAIL", "set_timeout(32, 1000, 2000): vanished peer reported after %d ms" % dt)
	else:
		rec("0001-1a", "OBSERVED", "default ENet timeout: vanished peer reported after %d ms (-1 = not within 45 s)" % dt)
	close_api(cli, tag + "_C")
	close_api(srv, tag + "_S")
	await frames(5)
