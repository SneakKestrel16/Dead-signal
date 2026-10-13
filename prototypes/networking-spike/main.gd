extends Node
# Throwaway networking spike. Modes:
#   move: server-authoritative movement, client prediction + reconciliation,
#         bandwidth and server tick cost, lag-compensated rewind check.
#   vis:  MultiplayerSynchronizer per-peer visibility (spawn + property sync).
#   auth: SceneMultiplayer auth_callback join validation, lobby cap, token reconnect.
# Latency, jitter and loss are simulated in-process: every send is delayed by the
# sender (one-way lat_ms, plus up to jitter_ms for unreliable sends) and unreliable
# sends are dropped with probability `loss`.

const PORT := 24680
const VERSION := "spike-1"
const ROOM_HALF := 10.0
const WALK := 4.0
const SPRINT_MULT := 1.25
const RADIUS := 0.3
const HEIGHT := 1.8
const MAX_PLAYERS := 6
const REWIND_CAP_MS := 150.0

var role := "server"
var mode := "move"
var tick_hz := 60
var lat_ms := 0.0
var jitter_ms := 0.0
var loss := 0.0
var duration := 20.0
var expected := 6
var seed_v := 1
var token := ""
var version := VERSION
var interp_ms := 100.0
var tag := "run"
var leave_after := -1.0
var host_addr := "127.0.0.1"
var use_upnp := false
var wait_s := 0.0
var upnp: UPNP
var upnp_info := {}

var rng := RandomNumberGenerator.new()
var outbox: Array = []
var started := false
var finished := false
var start_usec := 0
var tick := 0

# server
var players := {}
var stats := {}
var counts := {}
var client_summaries: Array = []
var send_us_total := 0
var token_slot := {}
var token_peer := {}
var peer_token := {}
var auth_log: Array = []
var vis_peers: Array = []
var vis_log: Array = []
var spawner: MultiplayerSpawner

# client
var my_slot := -1
var body: CharacterBody3D
var seq := 0
var pending: Array = []
var sent_hist: Array = []
var latest_state = null
var last_state_tick := -1
var last_state_usec := 0
var snapshots: Array = []
var bot_dir := Vector2.ZERO
var bot_sprint := false
var bot_next_change := 0.0
var next_lunge := 1.0
var next_ping := 0.5
var c_start_usec := 0
var c_done := false
var cstats := {}
var ccounts := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		var k := kv[0]
		var v: String = kv[1] if kv.size() > 1 else "1"
		match k:
			"role": role = v
			"mode": mode = v
			"tick": tick_hz = int(v)
			"lat": lat_ms = float(v)
			"jitter": jitter_ms = float(v)
			"loss": loss = float(v)
			"duration": duration = float(v)
			"expected": expected = int(v)
			"seed": seed_v = int(v)
			"token": token = v
			"version": version = v
			"interp": interp_ms = float(v)
			"tag": tag = v
			"leave_after": leave_after = float(v)
			"host": host_addr = v
			"upnp": use_upnp = v != "0"
			"wait": wait_s = float(v)
	rng.seed = seed_v
	Engine.physics_ticks_per_second = tick_hz
	Engine.max_fps = 500
	_build_world()
	if mode == "vis":
		_setup_vis_nodes()
	var smp := multiplayer as SceneMultiplayer
	if mode == "auth":
		smp.auth_callback = _on_auth
		if role == "client":
			multiplayer.peer_authenticating.connect(_on_peer_authenticating)
	var peer := ENetMultiplayerPeer.new()
	if role == "server":
		var err := peer.create_server(PORT, 16)
		if err != OK:
			print("SERVER create_server failed: %d" % err)
			get_tree().quit(1)
			return
		if use_upnp:
			_upnp_open()
		print("SERVER LAN addresses: %s" % ", ".join(Array(IP.get_local_addresses()).filter(func(a): return "." in a and not a.begins_with("127.") and not a.begins_with("169.254."))))
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		print("SERVER up tag=%s mode=%s tick=%d lat=%s jitter=%s loss=%s physics=%s" % [
			tag, mode, tick_hz, lat_ms, jitter_ms, loss,
			ProjectSettings.get_setting("physics/3d/physics_engine")])
		if mode == "auth" or mode == "vis":
			get_tree().create_timer(duration).timeout.connect(_finish)
	else:
		peer.create_client(host_addr, PORT)
		multiplayer.multiplayer_peer = peer
		multiplayer.connected_to_server.connect(func(): _log_c("connected"))
		multiplayer.connection_failed.connect(func(): _log_c("connection_failed"); _quit_soon())
		multiplayer.server_disconnected.connect(func(): _log_c("server_disconnected"); _quit_soon())
		if leave_after > 0.0:
			get_tree().create_timer(leave_after).timeout.connect(_leave)
		if mode != "move":
			get_tree().create_timer(duration).timeout.connect(_quit_soon)
	get_tree().create_timer(duration + 40.0 + wait_s).timeout.connect(func(): print("HARD TIMEOUT"); get_tree().quit(2))


# ---------------------------------------------------------------- world

func _build_world() -> void:
	var w := StaticBody3D.new()
	add_child(w)
	_add_box(w, Vector3(0, -0.5, 0), Vector3(ROOM_HALF * 2, 1, ROOM_HALF * 2))
	_add_box(w, Vector3(ROOM_HALF + 0.5, 1, 0), Vector3(1, 2, ROOM_HALF * 2))
	_add_box(w, Vector3(-ROOM_HALF - 0.5, 1, 0), Vector3(1, 2, ROOM_HALF * 2))
	_add_box(w, Vector3(0, 1, ROOM_HALF + 0.5), Vector3(ROOM_HALF * 2, 2, 1))
	_add_box(w, Vector3(0, 1, -ROOM_HALF - 0.5), Vector3(ROOM_HALF * 2, 2, 1))
	_add_box(w, Vector3(0, 1, 0), Vector3(2, 2, 2))
	_add_box(w, Vector3(5, 1, 5), Vector3(1, 2, 3))


func _add_box(parent: Node, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	parent.add_child(cs)


func _make_body(pos: Vector3) -> CharacterBody3D:
	var b := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var c := CapsuleShape3D.new()
	c.radius = RADIUS
	c.height = HEIGHT
	cs.shape = c
	b.add_child(cs)
	b.collision_layer = 2
	b.collision_mask = 1
	add_child(b)
	b.global_position = pos
	return b


func _spawn_pos(slot: int) -> Vector3:
	var ang := TAU * slot / 6.0
	return Vector3(cos(ang) * 6.0, HEIGHT / 2.0, sin(ang) * 6.0)


func _step(b: CharacterBody3D, dir: Vector2, sprint: bool) -> void:
	var spd := WALK * (SPRINT_MULT if sprint else 1.0)
	b.velocity = Vector3(dir.x, 0.0, dir.y) * spd
	b.move_and_slide()
	b.global_position.y = HEIGHT / 2.0


# ---------------------------------------------------------------- simulated network

func _later(c: Callable, unreliable: bool) -> void:
	if unreliable and loss > 0.0 and rng.randf() < loss:
		_count("dropped_sim")
		return
	var d := lat_ms + (rng.randf() * jitter_ms if unreliable else 0.0)
	outbox.append([Time.get_ticks_usec() + int(d * 1000.0), c])


func _process(_dt: float) -> void:
	if outbox.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var keep: Array = []
	for e in outbox:
		if e[0] <= t0:
			(e[1] as Callable).call()
		else:
			keep.append(e)
	outbox = keep
	if role == "server" and started:
		send_us_total += Time.get_ticks_usec() - t0


# ---------------------------------------------------------------- stats

func _add_stat(n: String, v: float) -> void:
	var d := stats if role == "server" else cstats
	if not d.has(n):
		d[n] = []
	d[n].append(v)


func _count(n: String, by: int = 1) -> void:
	var d := counts if role == "server" else ccounts
	d[n] = d.get(n, 0) + by


func _pct(a: Array, p: float) -> float:
	if a.is_empty():
		return -1.0
	var s := a.duplicate()
	s.sort()
	return snappedf(float(s[int(round(p * (s.size() - 1)))]), 0.0001)


func _summ(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		var a: Array = d[k]
		var total := 0.0
		for x in a:
			total += x
		out[k] = {"n": a.size(), "mean": snappedf(total / maxf(1, a.size()), 0.0001),
			"p50": _pct(a, 0.5), "p95": _pct(a, 0.95), "p99": _pct(a, 0.99), "max": _pct(a, 1.0)}
	return out


func _log_c(msg: String) -> void:
	print("CLIENT[%s token=%s] %s" % [tag, token, msg])


func _quit_soon() -> void:
	get_tree().create_timer(0.5).timeout.connect(func(): get_tree().quit())


func _leave() -> void:
	_log_c("leaving (closing peer)")
	multiplayer.multiplayer_peer.close()
	_quit_soon()


# ---------------------------------------------------------------- server: connections

func _on_peer_connected(id: int) -> void:
	if mode == "move":
		var slot := players.size()
		players[id] = {"slot": slot, "body": _make_body(_spawn_pos(slot)), "inq": {},
			"last_seq": 0, "last_dir": Vector2.ZERO, "last_sprint": false,
			"got_any": false, "hist": []}
		_later(func(): s2c_welcome.rpc_id(id, slot, tick_hz), false)
		if players.size() >= expected and not started:
			get_tree().create_timer(0.5).timeout.connect(_begin)
	elif mode == "vis":
		vis_peers.append(id)
		if vis_peers.size() == 2:
			_vis_run()
	elif mode == "auth":
		auth_log.append({"t": _now_s(), "event": "connected", "peer": id, "token": peer_token.get(id, "?")})


func _on_peer_disconnected(id: int) -> void:
	if mode == "move" and players.has(id):
		players[id].gone = true
	if mode == "auth":
		var tok: String = peer_token.get(id, "")
		if tok != "" and token_peer.get(tok, -1) == id:
			token_peer.erase(tok)
		auth_log.append({"t": _now_s(), "event": "disconnected", "peer": id, "token": tok})


func _now_s() -> float:
	return snappedf(Time.get_ticks_msec() / 1000.0, 0.01)


# ---------------------------------------------------------------- move mode

func _begin() -> void:
	if started:
		return
	started = true
	start_usec = Time.get_ticks_usec()
	var host := (multiplayer.multiplayer_peer as ENetMultiplayerPeer).host
	host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
	host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
	host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS)
	for id in players:
		_later(func(): s2c_start.rpc_id(id), false)
	get_tree().create_timer(duration + 3.0).timeout.connect(_finish_after_summaries)
	print("SERVER begin with %d clients" % players.size())


func _physics_process(_dt: float) -> void:
	if mode == "vis" and role == "server" and spawner != null:
		var n := get_node_or_null("Spawned/Secret") as Node3D
		if n:
			n.position.x += 0.01
		return
	if mode != "move":
		return
	if role == "server":
		if started and not finished and (Time.get_ticks_usec() - start_usec) / 1000000.0 < duration:
			_server_tick()
	elif my_slot >= 0 and c_start_usec > 0 and not c_done:
		_client_tick()


func _server_tick() -> void:
	var t0 := Time.get_ticks_usec()
	tick += 1
	for id in players:
		var p: Dictionary = players[id]
		if p.get("gone", false):
			continue
		var inq: Dictionary = p.inq
		var budget := 2 if inq.size() > 3 else 1
		for i in budget:
			var nxt: int = p.last_seq + 1
			if inq.has(nxt):
				var inp: Array = inq[nxt]
				inq.erase(nxt)
				p.last_dir = inp[0]
				p.last_sprint = inp[1]
			elif i == 0 and p.got_any:
				_count("starved")
			else:
				break
			p.last_seq = nxt
			_step(p.body, p.last_dir, p.last_sprint)
		var hist: Array = p.hist
		hist.append([tick, p.body.global_position])
		if hist.size() > tick_hz * 2:
			hist.pop_front()
	var slots := PackedInt32Array()
	var poss := PackedVector3Array()
	var yaws := PackedFloat32Array()
	var gaits := PackedByteArray()
	for id in players:
		var p: Dictionary = players[id]
		slots.append(p.slot)
		poss.append(p.body.global_position)
		yaws.append(atan2(p.last_dir.x, p.last_dir.y))
		gaits.append(1 if p.last_sprint else 0)
	_add_stat("tick_us", float(Time.get_ticks_usec() - t0))
	for id in players:
		if players[id].get("gone", false):
			continue
		var ack: int = players[id].last_seq
		var tk := tick
		_later(func(): s2c_state.rpc_id(id, tk, ack, slots, poss, yaws, gaits), true)


@rpc("authority", "reliable")
func s2c_welcome(slot: int, hz: int) -> void:
	my_slot = slot
	tick_hz = hz
	Engine.physics_ticks_per_second = hz
	body = _make_body(_spawn_pos(slot))


@rpc("authority", "reliable")
func s2c_start() -> void:
	c_start_usec = Time.get_ticks_usec()


@rpc("any_peer", "unreliable")
func c2s_input(seqs: PackedInt32Array, dirs: PackedVector2Array, sprints: PackedByteArray) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	p.got_any = true
	var inq: Dictionary = p.inq
	if seqs.size() > 0 and seqs[seqs.size() - 1] <= p.last_seq:
		_count("late_packets")
	for i in seqs.size():
		var s := seqs[i]
		if s <= p.last_seq or inq.has(s):
			continue
		inq[s] = [dirs[i], sprints[i] == 1]


@rpc("authority", "unreliable")
func s2c_state(tk: int, ack: int, slots: PackedInt32Array, poss: PackedVector3Array,
		_yaws: PackedFloat32Array, _gaits: PackedByteArray) -> void:
	_count("states")
	if tk <= last_state_tick:
		_count("stale_states")
		return
	last_state_tick = tk
	last_state_usec = Time.get_ticks_usec()
	latest_state = [tk, ack, slots, poss]
	var snap := {}
	for i in slots.size():
		snap[slots[i]] = poss[i]
	snapshots.append([tk, snap])
	if snapshots.size() > 128:
		snapshots.pop_front()


func _client_elapsed() -> float:
	return (Time.get_ticks_usec() - c_start_usec) / 1000000.0


func _client_tick() -> void:
	if latest_state != null:
		_reconcile(latest_state)
		latest_state = null
	var el := _client_elapsed()
	_bot_think(el)
	seq += 1
	_step(body, bot_dir, bot_sprint)
	pending.append([seq, bot_dir, bot_sprint, body.global_position])
	sent_hist.append([seq, bot_dir, bot_sprint])
	if sent_hist.size() > 3:
		sent_hist.pop_front()
	var seqs := PackedInt32Array()
	var dirs := PackedVector2Array()
	var sprs := PackedByteArray()
	for e in sent_hist:
		seqs.append(e[0])
		dirs.append(e[1])
		sprs.append(1 if e[2] else 0)
	_later(func(): c2s_input.rpc_id(1, seqs, dirs, sprs), true)
	if el >= next_ping:
		next_ping = el + 1.0
		var t := Time.get_ticks_usec()
		_later(func(): c2s_ping.rpc_id(1, t), false)
	if snapshots.size() > 8:
		# Render check every tick: would a remote player be interpolated, or held/extrapolated?
		var rt := _est_server_tick() - interp_ms / 1000.0 * tick_hz
		for sl in snapshots[-1][1]:
			if sl != my_slot:
				_count("render_ticks")
				if _interp(snapshots, sl, rt) == null:
					_count("render_holds")
				break
	if el >= next_lunge and snapshots.size() > 8:
		next_lunge = el + rng.randf_range(0.4, 0.8)
		_lunge_probe()
	if el >= duration:
		c_done = true
		_send_summary()


func _bot_think(el: float) -> void:
	var pos := body.global_position
	if el >= bot_next_change:
		bot_next_change = el + rng.randf_range(0.4, 1.5)
		var a := rng.randf() * TAU
		bot_dir = Vector2(cos(a), sin(a))
		bot_sprint = rng.randf() < 0.5
	if absf(pos.x) > ROOM_HALF - 1.5 or absf(pos.z) > ROOM_HALF - 1.5:
		bot_dir = Vector2(-pos.x, -pos.z).normalized()


func _reconcile(st: Array) -> void:
	var ack: int = st[1]
	var slots: PackedInt32Array = st[2]
	var poss: PackedVector3Array = st[3]
	var idx := slots.find(my_slot)
	if idx < 0:
		return
	var server_pos := poss[idx]
	while not pending.is_empty() and pending[0][0] < ack:
		pending.pop_front()
	if pending.is_empty() or pending[0][0] != ack:
		return
	var err: float = (pending[0][3] as Vector3).distance_to(server_pos)
	_add_stat("pred_err", err)
	pending.pop_front()
	if err < 0.001:
		return
	_count("corrections")
	var before := body.global_position
	body.global_position = server_pos
	for e in pending:
		_step(body, e[1], e[2])
		e[3] = body.global_position
	_add_stat("snap", before.distance_to(body.global_position))


func _est_server_tick() -> float:
	return last_state_tick + (Time.get_ticks_usec() - last_state_usec) / 1000000.0 * tick_hz


func _interp(buf: Array, slot: int, rt: float):
	# buf entries: [tick, {slot: pos}] (client) ; returns Vector3 or null
	for i in range(buf.size() - 1, 0, -1):
		var a: Array = buf[i - 1]
		var b: Array = buf[i]
		if a[0] <= rt and rt <= b[0] and a[1].has(slot) and b[1].has(slot):
			var f: float = 0.0 if b[0] == a[0] else (rt - a[0]) / float(b[0] - a[0])
			return (a[1][slot] as Vector3).lerp(b[1][slot], f)
	return null


func _interp_hist(hist: Array, rt: float):
	for i in range(hist.size() - 1, 0, -1):
		var a: Array = hist[i - 1]
		var b: Array = hist[i]
		if a[0] <= rt and rt <= b[0]:
			var f: float = 0.0 if b[0] == a[0] else (rt - a[0]) / float(b[0] - a[0])
			return (a[1] as Vector3).lerp(b[1], f)
	return null


func _lunge_probe() -> void:
	var rt := _est_server_tick() - interp_ms / 1000.0 * tick_hz
	var others: Array = snapshots[-1][1].keys().filter(func(s): return s != my_slot)
	if others.is_empty():
		return
	var target: int = others[rng.randi() % others.size()]
	var seen = _interp(snapshots, target, rt)
	if seen == null:
		_count("probe_no_interp")
		return
	_later(func(): c2s_lunge.rpc_id(1, target, rt, seen), false)


@rpc("any_peer", "reliable")
func c2s_lunge(target: int, rt: float, seen: Vector3) -> void:
	var tp = null
	for id in players:
		if players[id].slot == target:
			tp = players[id]
	if tp == null:
		return
	var rew = _interp_hist(tp.hist, rt)
	if rew == null:
		_count("rewind_out_of_history")
		return
	_add_stat("rewind_err_m", (rew as Vector3).distance_to(seen))
	_add_stat("norewind_err_m", (tp.body.global_position as Vector3).distance_to(seen))
	var back_ms := (tick - rt) / tick_hz * 1000.0
	_add_stat("rewind_ms", back_ms)
	if back_ms > REWIND_CAP_MS:
		_count("rewind_over_150ms")
	var capped_rt := maxf(rt, tick - REWIND_CAP_MS / 1000.0 * tick_hz)
	var rew_c = _interp_hist(tp.hist, capped_rt)
	if rew_c != null:
		_add_stat("capped150_err_m", (rew_c as Vector3).distance_to(seen))


@rpc("any_peer", "reliable")
func c2s_ping(t: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	_later(func(): s2c_pong.rpc_id(id, t), false)


@rpc("authority", "reliable")
func s2c_pong(t: int) -> void:
	_add_stat("rtt_ms", (Time.get_ticks_usec() - t) / 1000.0)


func _send_summary() -> void:
	var payload := JSON.stringify({"slot": my_slot, "stats": cstats, "counts": ccounts})
	_later(func(): c2s_summary.rpc_id(1, payload), false)
	_log_c("done slot=%d pred_err_p95=%s corrections=%s" % [
		my_slot, _pct(cstats.get("pred_err", []), 0.95), ccounts.get("corrections", 0)])
	# Long runs make summaries of several hundred KB; a slow uplink needs time to deliver.
	# The server closing first ends this sooner (server_disconnected).
	get_tree().create_timer(lat_ms / 1000.0 + 30.0).timeout.connect(func(): get_tree().quit())


@rpc("any_peer", "reliable")
func c2s_summary(payload: String) -> void:
	client_summaries.append(JSON.parse_string(payload))


func _finish_after_summaries() -> void:
	for i in 30:
		if client_summaries.size() >= players.size():
			break
		await get_tree().create_timer(1.0).timeout
	_finish()


# ---------------------------------------------------------------- vis mode

func _setup_vis_nodes() -> void:
	var holder := Node.new()
	holder.name = "Spawned"
	add_child(holder)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.spawn_path = NodePath("../Spawned")
	spawner.spawn_function = _spawn_secret


func _spawn_secret(data: Variant) -> Node:
	var n := Node3D.new()
	n.name = "Secret"
	n.position = data
	var cfg := SceneReplicationConfig.new()
	var path := NodePath(".:position")
	cfg.add_property(path)
	cfg.property_set_spawn(path, true)
	cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var s := MultiplayerSynchronizer.new()
	s.name = "Sync"
	s.replication_config = cfg
	s.public_visibility = false
	n.add_child(s)
	return n


func _vis_run() -> void:
	var a: int = vis_peers[0]
	var b: int = vis_peers[1]
	print("SERVER vis A=%d B=%d" % [a, b])
	spawner.spawn(Vector3(1, 2, 3))
	var s := get_node("Spawned/Secret/Sync") as MultiplayerSynchronizer
	s.set_visibility_for(a, true)
	s.update_visibility()
	await get_tree().create_timer(2.0).timeout
	_vis_ask(1, "A visible only")
	await get_tree().create_timer(1.0).timeout
	s.set_visibility_for(b, true)
	s.update_visibility()
	await get_tree().create_timer(2.0).timeout
	_vis_ask(2, "A and B visible")
	await get_tree().create_timer(1.0).timeout
	s.set_visibility_for(a, false)
	s.update_visibility()
	await get_tree().create_timer(2.0).timeout
	_vis_ask(3, "B visible only (A revoked)")
	await get_tree().create_timer(1.5).timeout
	_finish()


func _vis_ask(phase: int, label: String) -> void:
	var n := get_node_or_null("Spawned/Secret") as Node3D
	vis_log.append({"phase": phase, "label": label, "server_x": snappedf(n.position.x, 0.01)})
	for id in vis_peers:
		var who := "A" if id == vis_peers[0] else "B"
		s2c_vis_ask.rpc_id(id, phase, who)


@rpc("authority", "reliable")
func s2c_vis_ask(phase: int, who: String) -> void:
	var n := get_node_or_null("Spawned/Secret") as Node3D
	var x := snappedf(n.position.x, 0.01) if n else -1.0
	c2s_vis_report.rpc_id(1, phase, who, n != null, x)


@rpc("any_peer", "reliable")
func c2s_vis_report(phase: int, who: String, has_node: bool, x: float) -> void:
	vis_log.append({"phase": phase, "peer": who, "has_node": has_node, "client_x": x})


# ---------------------------------------------------------------- auth mode

func _on_peer_authenticating(_id: int) -> void:
	var smp := multiplayer as SceneMultiplayer
	smp.send_auth(1, var_to_bytes({"version": version, "token": token}))
	smp.complete_auth(1)


func _on_auth(id: int, data: PackedByteArray) -> void:
	var smp := multiplayer as SceneMultiplayer
	if role == "client":
		_log_c("auth_reply %s" % str(bytes_to_var(data)))
		return
	var info = bytes_to_var(data)
	var reason := ""
	var slot := -1
	if typeof(info) != TYPE_DICTIONARY:
		reason = "bad_payload"
	elif info.get("version", "") != VERSION:
		reason = "version_mismatch (client %s, host %s)" % [info.get("version", ""), VERSION]
	else:
		var tok: String = info.get("token", "")
		if token_peer.has(tok):
			reason = "token_in_use"
		elif token_slot.has(tok):
			slot = token_slot[tok]
		elif token_peer.size() >= MAX_PLAYERS:
			reason = "lobby_full"
		else:
			slot = token_slot.size()
			token_slot[tok] = slot
		if reason == "":
			if token_peer.size() >= MAX_PLAYERS:
				reason = "lobby_full"
				slot = -1
	if reason != "":
		auth_log.append({"t": _now_s(), "event": "rejected", "peer": id, "reason": reason})
		smp.send_auth(id, var_to_bytes({"ok": false, "reason": reason}))
		get_tree().create_timer(0.2).timeout.connect(func(): multiplayer.multiplayer_peer.disconnect_peer(id))
		return
	var tk: String = info.token
	var reconnect := auth_log.any(func(e): return e.get("token", "") == tk and e.event == "disconnected")
	token_peer[tk] = id
	peer_token[id] = tk
	auth_log.append({"t": _now_s(), "event": "reconnected" if reconnect else "accepted",
		"peer": id, "token": tk, "slot": slot})
	smp.send_auth(id, var_to_bytes({"ok": true, "slot": slot}))
	smp.complete_auth(id)


# ---------------------------------------------------------------- results

func _finish() -> void:
	if finished:
		return
	finished = true
	var out := {"tag": tag, "mode": mode, "tick_hz": tick_hz, "lat_ms_one_way": lat_ms,
		"jitter_ms": jitter_ms, "loss": loss,
		"physics_engine": ProjectSettings.get_setting("physics/3d/physics_engine"),
		"engine": Engine.get_version_info().string}
	if mode == "move":
		# Rates use the window the server actually ticked and sent states in.
		var secs := float(tick) / tick_hz
		var host := (multiplayer.multiplayer_peer as ENetMultiplayerPeer).host
		var sent := host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
		var recv := host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
		var pkts := host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS)
		var n := maxi(1, players.size())
		out["players"] = players.size()
		out["seconds"] = snappedf(secs, 0.01)
		out["server_ticks_per_s"] = snappedf(tick / secs, 0.1)
		out["host_upload_kbps_per_client"] = snappedf(sent * 8.0 / 1000.0 / secs / n, 0.1)
		out["host_upload_kbps_total"] = snappedf(sent * 8.0 / 1000.0 / secs, 0.1)
		out["host_download_kbps_per_client"] = snappedf(recv * 8.0 / 1000.0 / secs / n, 0.1)
		out["host_packets_per_s"] = snappedf(pkts / secs, 0.1)
		out["send_us_per_tick"] = snappedf(float(send_us_total) / maxf(1, tick), 0.1)
		out["server"] = _summ(stats)
		out["server_counts"] = counts
		var merged := {}
		var mcounts := {}
		for cs in client_summaries:
			if cs == null:
				continue
			for k in cs.stats:
				if not merged.has(k):
					merged[k] = []
				merged[k].append_array(cs.stats[k])
			for k in cs.counts:
				mcounts[k] = mcounts.get(k, 0) + int(cs.counts[k])
		out["clients_reported"] = client_summaries.size()
		out["clients"] = _summ(merged)
		out["client_counts"] = mcounts
	elif mode == "vis":
		out["vis"] = vis_log
	elif mode == "auth":
		out["auth"] = auth_log
	if use_upnp:
		out["upnp"] = upnp_info
		if upnp and upnp_info.get("mapped", false):
			upnp.delete_port_mapping(PORT, "UDP")
	var txt := JSON.stringify(out, "  ")
	print("RESULT " + JSON.stringify(out))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://results"))
	var f := FileAccess.open("res://results/%s.json" % tag, FileAccess.WRITE)
	if f:
		f.store_string(txt + "\n")
		f.close()
	get_tree().create_timer(0.5).timeout.connect(func(): get_tree().quit())


# ---------------------------------------------------------------- reachability (two-network tests)

## Asks the router to forward PORT (UDP) to this PC. Records whether that worked and
## the router's external IP: a 10.x, 172.16-31.x, 192.168.x or 100.64-127.x external
## IP means a second NAT (CGNAT) in front, so no forward from here reaches the host.
func _upnp_open() -> void:
	upnp = UPNP.new()
	var d := upnp.discover()
	var gw := upnp.get_gateway()
	upnp_info = {"discover": d, "gateway": gw != null and gw.is_valid_gateway(), "mapped": false}
	if upnp_info.gateway:
		upnp_info["map_result"] = upnp.add_port_mapping(PORT, PORT, "dead-signal-spike", "UDP", 3600)
		upnp_info["mapped"] = upnp_info.map_result == UPNP.UPNP_RESULT_SUCCESS
		var ext := upnp.query_external_address()
		upnp_info["external_ip"] = ext
		var o := ext.split(".")
		upnp_info["external_ip_is_private"] = o.size() == 4 and (o[0] == "10" or (o[0] == "172" and int(o[1]) >= 16 and int(o[1]) <= 31) or (o[0] == "192" and o[1] == "168") or (o[0] == "100" and int(o[1]) >= 64 and int(o[1]) <= 127))
	print("SERVER UPnP %s" % JSON.stringify(upnp_info))
