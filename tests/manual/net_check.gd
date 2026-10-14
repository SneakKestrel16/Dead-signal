extends Node3D
## Host/join harness for the two-PC cases in production/qa/test-cases/na-v-real-network-cases.md (NH-1).
## Every line it prints also shows on screen (the course is collision only and draws nothing). Arguments come after `--`
## (any role: --knob=section.field=value overrides one loaded knob, e.g. to show the DC-4 refusal):
##   <godot> --path <repo> res://tests/manual/net_check.tscn -- --role=host [--port=24690] [--local-player=0|1] [--build=0.1.0]
##   <godot> --path <repo> res://tests/manual/net_check.tscn -- --role=client --host=<ip or [ipv6]> [--port=24690]
##       [--name=<name>] [--count=N] [--raw=oversized|garbage] [--build=0.1.0] [--mode=idle|route|bots]
## Host keys: L cycles the stub lobby Waiting -> Countdown -> In Match. Client keys: R rejoins with the
## stored token (also done on server_disconnected).
## The session token stays in NetAuthority.local_token: never print it, log it or show it (NA-2).
## --mode=route runs TestMoveStep.ramp_route() (the host's --local-player=1 body runs it too when the
## first client joins); --mode=bots runs BOT_TICKS of TestMoveStep.random_route() per client. Both print
## the predictor totals at the end; the host prints the final server-side positions of every player.

const DEFAULT_BUILD := "0.1.0"
const HOST_ID := 100 ## the host's own player; NetAuthority hands out 0, 1, 2 ... to remote players
const WORLD_SIZE := 400.0
const BOT_TICKS := 1600 ## about 27 s at 60 Hz: the NA-6 AC1 sample
const SETTLE_TICKS := 120
const MAX_LINES := 40
const BOT_SEED := 77

var _args: Dictionary = {}
var _knobs: Knobs
var _version: String
var _label: Label
var _lines: PackedStringArray = []

# host
var _net: NetAuthority
var _lobby := StubLobby.new()
var _sm: ServerMovement
var _bodies: Dictionary = {}
var _host_route: Array = []
var _host_t := -1
var _last_drop_ms := -1

# client: Array of {net, root, name, rejoin, t0, route, t, body, predictor}
var _clients: Array[Dictionary] = []
var _mode := "idle"
var _rtt_timer := 0.0


## The stub lobby provider NetAuthority reads (the real lobby is not wired here).
class StubLobby extends RefCounted:
	const STATES: Array[StringName] = [&"waiting", &"countdown", &"in_match"]
	var index := 0
	var count := 0

	func state() -> StringName:
		return STATES[index]

	func player_count() -> int:
		return count


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(8, 8)
	add_child(_label)
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	_knobs = Knobs.load_all()
	# --knob=section.field=value overrides one loaded knob, to show the refusal (DC-4) without editing data.
	if _args.has("knob"):
		var kv: PackedStringArray = _args.knob.split("=", true, 1)
		var path := kv[0].split(".")
		var section: Resource = _knobs.get(path[0])
		section.set(path[1], str_to_var(kv[1]))
		_log("KNOB OVERRIDE %s" % _args.knob)
	if _args.get("role", "") != "host" and not _knobs.errors().is_empty():
		_log("REFUSED: %d knob problems" % _knobs.errors().size()) ## the host refuses in NetAuthority.host()
		return
	_version = _knobs.join_version(_args.get("build", DEFAULT_BUILD))
	_log("VERSION " + _version)
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	TestMoveStep.add_course(self, WORLD_SIZE)
	match _args.get("role", ""):
		"host":
			_start_host()
		"client":
			_start_clients()
		_:
			_log("usage: -- --role=host|client (see the header of tests/manual/net_check.gd)")


func _log(line: String) -> void:
	print(line)
	_lines.append(line)
	if _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	_label.text = "\n".join(_lines)


func _port() -> int:
	return int(_args.get("port", str(_knobs.net.port)))


func _spawn(player_id: int) -> Vector3:
	return Vector3(float(player_id) * 2.0, 0.0, -1.0)


# --- host --------------------------------------------------------------------

func _start_host() -> void:
	_net = NetAuthority.new()
	_net.setup(_knobs, _version, _lobby)
	# ponytail: true for every token within grace of the latest drop; NA-3 (story 003) supplies the real one.
	_net.known_token_in_grace = func(_token: String) -> bool:
		return _last_drop_ms >= 0 and Time.get_ticks_msec() - _last_drop_ms < _knobs.match_flow.reconnect_grace_s * 1000.0
	add_child(_net)
	_net.player_joined.connect(_on_joined)
	_net.player_rejoined.connect(func(pid: int, peer: int) -> void: _log("player_rejoined %d %d" % [pid, peer]))
	_net.player_dropped.connect(_on_dropped)
	_net.join_refused.connect(func(r: StringName) -> void: _log("sent reject " + r))
	_net.host_failed.connect(func(e: Error) -> void: _log("HOST_FAILED " + error_string(e)))
	_net.fail_hard = false
	_net.host_refused.connect(func(errs: PackedStringArray) -> void:
		_log("REFUSED TO HOST: %d knob errors" % errs.size())
		for e in errs:
			_log("  " + e))
	if _net.host(_port()) != OK:
		return
	var runner := TickRunner.new()
	runner.fail_hard = false
	runner.boot(_knobs)
	add_child(runner)
	_sm = ServerMovement.new(_knobs, _net, multiplayer as SceneMultiplayer, TestMoveStep.apply, TestMoveStep.WORLD)
	_sm.attach(runner)
	if _args.get("local-player", "0") == "1":
		# Created up front: a body created on the tick it first moves takes a different first step (NA-6 AC3).
		_bodies[HOST_ID] = TestMoveStep.make_body(self, _spawn(0))
		_sm.add_player(HOST_ID, _bodies[HOST_ID], true)
		_lobby.count = 1
	_log("HOSTING port %d, lobby %s" % [_port(), _lobby.state()])


func _on_joined(pid: int) -> void:
	_log("player_joined %d %d" % [pid, _net.peer_id_of(pid)])
	_lobby.count += 1
	_bodies[pid] = TestMoveStep.make_body(self, _spawn(pid))
	_sm.add_player(pid, _bodies[pid])
	if _bodies.has(HOST_ID) and _host_t < 0:
		_host_route = TestMoveStep.ramp_route()
		_host_t = 0


func _on_dropped(pid: int) -> void:
	_log("player_dropped %d" % pid)
	_last_drop_ms = Time.get_ticks_msec()
	_lobby.count -= 1
	_sm.remove_player(pid)
	_bodies[pid].queue_free()
	_bodies.erase(pid)


func _host_physics() -> void:
	if _host_t < 0:
		return
	if _host_t < _host_route.size():
		var f := _frame(_host_route[_host_t])
		f.seq = _host_t + 1
		_sm.push_local(HOST_ID, f)
	elif _host_t == _host_route.size() + SETTLE_TICKS:
		for pid: int in _bodies:
			var p: Vector3 = _bodies[pid].global_position
			_log("FINAL %s %.5f %.5f %.5f ack=%d" % ["host" if pid == HOST_ID else str(pid), p.x, p.y, p.z, _sm.ack_seq_of(pid)])
	_host_t += 1


# --- client ------------------------------------------------------------------

func _start_clients() -> void:
	var host: String = _args.get("host", "127.0.0.1").trim_prefix("[").trim_suffix("]")
	_mode = _args.get("mode", "idle")
	var count := int(_args.get("count", "1"))
	for i in count:
		var root := Node.new()
		root.name = "Client%d" % i
		add_child(root)
		get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
		if _args.has("raw"):
			_raw_join(root, host, i)
			continue
		var base: String = _args.get("name", "Tester")
		var c := {"root": root, "name": base if count == 1 else "%s%d" % [base, i], "rejoin": false, "t": -1}
		c["net"] = NetAuthority.new()
		c.net.setup(_knobs, _version, StubLobby.new())
		root.add_child(c.net)
		c.net.join_rejected.connect(_on_rejected.bind(c))
		c.net.host_left.connect(func() -> void: _log("c%d HOST_LEFT" % i))
		root.multiplayer.connected_to_server.connect(_on_connected.bind(c))
		root.multiplayer.server_disconnected.connect(func() -> void:
			_log("c%d server_disconnected" % i)
			if c.net.local_player_id >= 0: ## admitted once; a rejected join is not retried
				_rejoin.call_deferred(c))
		root.multiplayer.connection_failed.connect(func() -> void: _log("c%d connection_failed" % i))
		_clients.append(c)
		_join(c, host, "")


func _join(c: Dictionary, host: String, token: String) -> void:
	c["host"] = host
	c["t0"] = Time.get_ticks_msec()
	var err: Error = c.net.join(host, _port(), c.name, token)
	if err != OK:
		_log("JOIN_FAILED " + error_string(err))


func _rejoin(c: Dictionary) -> void:
	var token: String = c.net.local_token
	c.net.close()
	c.rejoin = true
	_join(c, c.host, token)


func _on_connected(c: Dictionary) -> void:
	var pid: int = c.net.local_player_id
	_log("%s %d" % ["REJOIN" if c.rejoin else "PLAYER_ID", pid])
	if _mode == "idle" or c.has("predictor"):
		return
	var idx := _clients.find(c)
	c["route"] = TestMoveStep.ramp_route() if _mode == "route" else TestMoveStep.random_route(BOT_SEED + idx, BOT_TICKS)
	c["body"] = TestMoveStep.make_body(c.root, _spawn(pid))
	var visual := Node3D.new()
	c.body.add_child(visual)
	c["predictor"] = OwnerPredictor.new(_knobs, c.body, visual, TestMoveStep.apply, c.root.multiplayer as SceneMultiplayer)
	c.t = 0


func _on_rejected(reason: StringName, c: Dictionary) -> void:
	var details: Dictionary = c.net.last_reject_details.duplicate()
	details.erase("ok")
	details.erase("reason")
	_log("REJECT %s %s after %d ms" % [reason, details, Time.get_ticks_msec() - c.t0])


## A bare SceneMultiplayer client that sends a bad auth payload and prints the server's reason.
func _raw_join(root: Node, host: String, i: int) -> void:
	var api := root.multiplayer as SceneMultiplayer
	var payload := PackedByteArray()
	if _args.raw == "oversized":
		payload.resize(_knobs.net.auth_payload_cap_bytes + 1)
	else:
		payload = var_to_bytes([1, 2, 3])
	api.auth_callback = func(_id: int, data: PackedByteArray) -> void:
		var d: Variant = bytes_to_var(data) if data.size() <= _knobs.net.auth_payload_cap_bytes else null
		_log("c%d REJECT %s" % [i, d.get("reason", "?") if d is Dictionary else "<unreadable reply>"])
	api.peer_authenticating.connect(func(id: int) -> void: api.send_auth(id, payload))
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(host, _port())
	api.multiplayer_peer = peer


func _client_physics(delta: float) -> void:
	for c in _clients:
		if c.t < 0:
			continue
		var p: OwnerPredictor = c.predictor
		if c.t < c.route.size():
			p.predict(_frame(c.route[c.t]))
		else:
			p.apply_pending()
		p.advance_visual(delta)
		if c.t == c.route.size() + SETTLE_TICKS:
			var mags := p.correction_magnitudes.duplicate()
			mags.sort()
			var p95: float = mags[maxi(0, ceili(0.95 * mags.size()) - 1)] if not mags.is_empty() else 0.0
			var pos: Vector3 = c.body.global_position
			_log("DONE pid=%d states=%d corrections=%d snaps=%d p95=%.4f m max=%.4f m pos=%.5f %.5f %.5f" % [
				c.net.local_player_id, p.states_received, p.corrections, p.snaps, p95,
				mags.max() if not mags.is_empty() else 0.0, pos.x, pos.y, pos.z])
		c.t += 1


func _rtt_print() -> void:
	for i in _clients.size():
		var enet := (_clients[i].root.multiplayer as SceneMultiplayer).multiplayer_peer as ENetMultiplayerPeer
		if enet == null or enet.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			continue
		var server := enet.get_peer(1)
		if server != null:
			_log("c%d RTT %d ms" % [i, int(server.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))])


# --- loop --------------------------------------------------------------------

func _frame(r: Array) -> InputFrame:
	var f := InputFrame.new()
	f.move = r[0]
	f.yaw = r[1]
	return f


func _physics_process(delta: float) -> void:
	if _net != null and _sm != null:
		_host_physics()
	_client_physics(delta)


func _process(delta: float) -> void:
	_rtt_timer += delta
	if _rtt_timer >= 1.0:
		_rtt_timer = 0.0
		_rtt_print()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_L and _net != null:
		_lobby.index = (_lobby.index + 1) % StubLobby.STATES.size()
		_log("LOBBY " + _lobby.state())
	elif key.keycode == KEY_R:
		for c in _clients:
			_rejoin(c)
