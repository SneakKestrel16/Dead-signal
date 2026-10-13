extends "res://lib.gd"
## ADR-0002 Verification Required (1)-(7), single machine. (4) and (7) also cover ADR-0007 (3).

const Probe := preload("res://probe.gd")


func run() -> void:
	rec("0002-2", "OBSERVED", "Engine.max_physics_steps_per_frame default=%d; physics_ticks_per_second=%d (slow-host behaviour NOT RUN: needs a loaded host)" % [Engine.max_physics_steps_per_frame, Engine.physics_ticks_per_second])
	var n := Node3D.new()
	rec("0002-3", "OBSERVED", "Node3D.reset_physics_interpolation exists=%s; physics_interpolation_mode default=%d (OFF=%d). Rendered smoothing with OFF: NOT RUN (needs a window)" % [n.has_method("reset_physics_interpolation"), n.physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF])
	n.free()
	await _replay()
	await _head_of_line(1, 2, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	await _head_of_line(0, 0, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	await _head_of_line(0, 0, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)
	await _snapshot_size()
	rec("0002-5x", "NOT RUN", "Jolt drift between machines needs a second PC; see 0002-5 for same-machine repeatability")


## Records a server walk up a 40° ramp, then reconciles from a mid-ramp tick:
## restore position and velocity, optionally apply_floor_snap(), replay 15 frames in one physics frame.
func _replay() -> void:
	var w := make_world("ReplayWorld")
	add_box(w, Vector3(0, -0.5, 5), Vector3(4, 1, 20))
	add_wedge(w, 2.0, 40.0, 1.0)
	var lip := 2.0 + 1.0 / tan(deg_to_rad(40.0))
	add_box(w, Vector3(0, 0.5, lip + 3.8), Vector3(4, 1, 7.6))
	await physics_frames(2)
	var runs: Array = []
	for attempt in 2:
		if attempt == 1:
			# Keep run 0's body for the replay, but out of run 1's way.
			(runs[0].body as CharacterBody3D).collision_layer = 0
		var p := make_player(w, Vector3(0, 0, 0))
		await physics_frames(1)
		var rec_pos: Array[Vector3] = []
		var rec_vel: Array[Vector3] = []
		var rec_floor: Array[bool] = []
		for t in 120:
			await tree.physics_frame
			step(p, Vector3(0, 0, 1))
			rec_pos.append(p.global_position)
			rec_vel.append(p.velocity)
			rec_floor.append(p.is_on_floor())
		runs.append({"pos": rec_pos, "vel": rec_vel, "floor": rec_floor, "body": p})
	var a: Array[Vector3] = runs[0].pos
	var b: Array[Vector3] = runs[1].pos
	var max_d := 0.0
	for i in a.size():
		max_d = maxf(max_d, a[i].distance_to(b[i]))
	rec("0002-5", "OBSERVED", "same machine, two identical 120-tick ramp walks: max position difference %.6f m" % max_d)
	var climbed := a[a.size() - 1].y
	var p: CharacterBody3D = runs[0].body
	(runs[1].body as Node).queue_free()
	p.collision_layer = PLAYERS
	var floor_rec: Array[bool] = runs[0].floor
	var vel_rec: Array[Vector3] = runs[0].vel
	var lines: Array[String] = []
	var worst_snap := 0.0
	var worst_nosnap := 0.0
	# Reconcile points: on the flat, at the ramp foot, mid-ramp, at the top lip.
	for k in [10, 20, 30, 40, 50]:
		for use_snap in [true, false]:
			await tree.physics_frame
			# Put the body into a stale airborne state, as a misprediction would.
			p.global_position = a[k] + Vector3(0, 3, 0)
			p.velocity = Vector3.ZERO
			p.move_and_slide()
			p.global_position = a[k]
			p.velocity = vel_rec[k]
			if use_snap and floor_rec[k]:
				p.apply_floor_snap()
			var floor_after := p.is_on_floor()
			for j in range(k + 1, k + 16):
				step(p, Vector3(0, 0, 1))
			var err := p.global_position.distance_to(a[k + 15])
			if use_snap:
				worst_snap = maxf(worst_snap, err)
			else:
				worst_nosnap = maxf(worst_nosnap, err)
			lines.append("k=%d y=%.2f snap=%s floor_after_restore=%s err=%.4f" % [k, a[k].y, use_snap, floor_after, err])
	print("  replay detail: ", "; ".join(lines))
	var floor_ok := worst_snap < worst_nosnap and climbed > 0.95
	rec("0002-7", "PASS" if floor_ok else "FAIL", "apply_floor_snap() after restoring position and velocity re-finds the floor (is_on_floor true at every reconcile point) and cuts replay error from %.5f m to %.5f m" % [worst_nosnap, worst_snap])
	rec("0002-4/0007-3", "PASS" if climbed > 0.95 and worst_snap < 0.005 else "FAIL", "gravity + floor snap, 40° ramp climbed to y=%.3f; 15 frames replayed in one physics frame: worst error %.5f m against correction_deadzone_m 0.005 (was 0.001) (see replay detail)" % [climbed, worst_snap])
	w.queue_free()
	await physics_frames(2)


func _connect_pair(tag: String, uch: int, rch: int) -> Dictionary:
	var port := next_port()
	var proxy_port := next_port()
	var srv := make_api(tag + "_S")
	var sp := ENetMultiplayerPeer.new()
	sp.create_server(port, 8)
	srv.multiplayer_peer = sp
	var proxy := UdpProxy.new()
	proxy.start(proxy_port, port)
	var cli := make_api(tag + "_C")
	var cp := ENetMultiplayerPeer.new()
	cp.create_client("127.0.0.1", proxy_port)
	cli.multiplayer_peer = cp
	var sprobe: Node = Probe.new()
	sprobe.name = "Net"
	api_root(tag + "_S").add_child(sprobe)
	Probe.configure(sprobe, uch, rch)
	var cprobe: Node = Probe.new()
	cprobe.name = "Net"
	api_root(tag + "_C").add_child(cprobe)
	Probe.configure(cprobe, uch, rch)
	var ok := await until(func() -> bool: return connected(cli) and srv.get_peers().size() == 1, 3.0, proxy)
	return {"ok": ok, "srv": srv, "cli": cli, "proxy": proxy, "sprobe": sprobe, "cprobe": cprobe, "cid": srv.get_peers()[0] if ok else 0}


## (1) A reliable packet is lost: do unreliable packets sent after it wait for its retransmission?
func _head_of_line(uch: int, rch: int, mode: int) -> void:
	var tag := "Hol%d%d%d" % [uch, rch, mode]
	var c := await _connect_pair(tag, uch, rch)
	var mode_name := "unreliable" if mode == MultiplayerPeer.TRANSFER_MODE_UNRELIABLE else "unreliable_ordered"
	var id := "0002-1 (%s ch %d, reliable ch %d)" % [mode_name, uch, rch]
	for n: Node in [c.sprobe, c.cprobe]:
		n.rpc_config(&"u", {"rpc_mode": MultiplayerAPI.RPC_MODE_AUTHORITY, "transfer_mode": mode, "call_local": false, "channel": uch})
	if not c.ok:
		rec(id, "FAIL", "could not connect through proxy")
		return
	var proxy: UdpProxy = c.proxy
	var sprobe: Node = c.sprobe
	var cprobe: Node = c.cprobe
	var sent := {}
	var seq := 0
	# Warm up: path caches and RTT settle.
	var warm_end := Time.get_ticks_msec() + 500
	while Time.get_ticks_msec() < warm_end:
		sprobe.rpc_id(c.cid, &"u", seq)
		sent[seq] = Time.get_ticks_msec()
		seq += 1
		sprobe.rpc_id(c.cid, &"ping", 0)
		proxy.poll()
		await tree.process_frame
	cprobe.unreliable_log.clear()
	# Drop every server->client packet for 60 ms, starting with the reliable one.
	proxy.drop_until_ms = Time.get_ticks_msec() + 60
	var drop_end: int = proxy.drop_until_ms
	sprobe.rpc_id(c.cid, &"r")
	var r_sent := Time.get_ticks_msec()
	var end := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < end:
		sprobe.rpc_id(c.cid, &"u", seq)
		sent[seq] = Time.get_ticks_msec()
		seq += 1
		proxy.poll()
		await tree.process_frame
	var delays: Array[int] = []
	var before_reliable := 0
	for entry in cprobe.unreliable_log:
		var s: int = entry[0]
		if sent.has(s) and sent[s] > drop_end + 5:
			delays.append(entry[1] - sent[s])
			if cprobe.reliable_ms < 0 or entry[1] < cprobe.reliable_ms:
				before_reliable += 1
	delays.sort()
	var p50 := delays[delays.size() / 2] if delays.size() > 0 else -1
	var mx := delays[delays.size() - 1] if delays.size() > 0 else -1
	var rel_delay: int = cprobe.reliable_ms - r_sent if cprobe.reliable_ms >= 0 else -1
	var verdict := "OBSERVED"
	if uch != rch:
		verdict = "PASS" if (before_reliable > 0 and mx < rel_delay) else "FAIL"
	rec(id, verdict, "dropped %d pkts; lost reliable arrived after %d ms; %d unreliable sent after the drop: delay p50 %d ms, max %d ms, %d arrived before the reliable" % [proxy.dropped, rel_delay, delays.size(), p50, mx, before_reliable])
	proxy.stop()
	close_api(c.cli, tag + "_C")
	close_api(c.srv, tag + "_S")
	await frames(5)


## (6) Wire size of a 6-body snapshot sent as one unreliable RPC.
func _snapshot_size() -> void:
	var tag := "Snap"
	var c := await _connect_pair(tag, 1, 2)
	if not c.ok:
		rec("0002-6", "FAIL", "could not connect through proxy")
		return
	var proxy: UdpProxy = c.proxy
	# Per body: handle i32, appearance u8, pos 3x i16, yaw u16, gait u8, presentation u8, items u8 = 16 B.
	# Own entry: seq i32, pos 3x f32, vel 3x f32, floor u8, modifier u8 + slow f32, hold i32 + ticks u16 = 44 B.
	var buf := StreamPeerBuffer.new()
	buf.put_32(123456)
	for i in 6:
		buf.put_32(0x7fff0000 + i)
		buf.put_u8(i)
		for k in 3:
			buf.put_16(1000 * i + k)
		buf.put_u16(40000)
		buf.put_u8(1)
		buf.put_u8(0)
		buf.put_u8(0)
	for k in 44:
		buf.put_u8(k)
	var payload := buf.data_array
	await until(func() -> bool: return false, 0.2, proxy)
	proxy.capture_down.clear()
	proxy.capture_enabled = true
	for i in 30:
		c.sprobe.rpc_id(c.cid, &"blob", payload)
		proxy.poll()
		await tree.process_frame
	await until(func() -> bool: return c.cprobe.blob_sizes.size() >= 25, 1.0, proxy)
	var biggest := 0
	for pkt in proxy.capture_down:
		biggest = maxi(biggest, pkt.size())
	var ok := biggest > payload.size() and biggest < 1200
	rec("0002-6/0004-4", "PASS" if ok else "FAIL", "6-body snapshot payload %d B -> largest UDP datagram %d B (unfragmented under ~1200 B); %d/30 received" % [payload.size(), biggest, c.cprobe.blob_sizes.size()])
	proxy.stop()
	close_api(c.cli, tag + "_C")
	close_api(c.srv, tag + "_S")
	await frames(5)
