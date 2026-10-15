extends Node3D
## Windowed client(s) of a round_host.gd round (story match-flow/011): the first-person greybox view.
##   <godot> --path <repo> res://tests/manual/round_view.tscn -- [--host=127.0.0.1] [--port=24690] [--count=1]
##       [--view=0|monster|survivor] [--latency-ms=0] [--bot=hold] [--light]
## --count joins N clients from this process (round_host waits for --players); the shown one is client
## --view (an index, or the first client that is / is not the shapeshifter once its own snapshot says so);
## the others stand still. Mouse look and WASD drive the shown client unless --bot is given.
## --latency-ms puts client 0 behind a UdpLink with that round trip (half each way) on port + 100.
## --bot=hold walks client 0 to the nearest hiding spot, aims at it and holds interact; it prints the drawn
## frame of the press and of the first frame the hold bar is visible (the CI-16 AC1 capture).
## --bot=look turns the shown client to face the nearest remote body it draws (the screenshots).
## --light turns the shown client's flashlight on once it has a body. Bots drive the shown client.
## --shots=<dir> saves press.png and bar.png (bot) and view.png at drawn frame --shot-at=N.

const LINK_PORT_OFFSET := 100
const LINK_SEED := 11

var _args: Dictionary = {}
var _knobs: Knobs
var _map: MapData
var _clients: Array[RoundClient] = []
var _shown: RoundClient
var _link: UdpLink
var _target := Vector3.INF
var _press_frame := -1
var _lit := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	_knobs = Knobs.load_all()
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	_map = MapData.load_map()
	MapGreybox.build(self, _map)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	sun.light_energy = 0.4
	add_child(sun)
	var host: String = _args.get("host", "127.0.0.1")
	var port := int(_args.get("port", "24690"))
	var latency := int(_args.get("latency-ms", "0"))
	for i in int(_args.get("count", "1")):
		var c := RoundClient.new(_knobs, TestMoveStep.apply, TestMoveStep.make_body, _map, true)
		c.name = "Client%d" % i
		add_child(c)
		var to := port
		if i == 0 and latency > 0:
			_link = UdpLink.new(LINK_SEED)
			_link.delay_s = latency / 2000.0
			to = port + LINK_PORT_OFFSET
			_link.start(to, port)
		c.join(host, to, "View%d" % i)
		c.scripted = InputFrame.new() # idle; the shown client drops it for LocalInput below
		_clients.append(c)
	print("ROUND VIEW %d clients -> %s:%d latency %d ms" % [_clients.size(), host, port, latency])


func _process(_delta: float) -> void:
	if _args.has("shot-at") and Engine.get_frames_drawn() == int(_args["shot-at"]):
		_shot("view")
	if _link != null:
		_link.pump(Time.get_ticks_msec() / 1000.0)
	_pick_view()
	var c0 := _shown
	if c0 == null or not c0.is_spawned():
		return
	if _args.has("light") and not _lit:
		_lit = true
		c0.toggle_flashlight()
	if c0.scripted == null and _args.has("bot"):
		c0.scripted = InputFrame.new()
	if _args.get("bot", "") == "hold":
		_bot(c0)
	elif _args.get("bot", "") == "look":
		_look(c0)


## Shows the chosen client's camera and HUD only.
func _pick_view() -> void:
	var want: String = _args.get("view", "0")
	var pick: RoundClient = null
	for i in _clients.size():
		var c := _clients[i]
		if not c.is_spawned():
			continue ## the role reads from the own entry once spawned
		if want == str(i) or (want == "monster" and c.is_monster()) or (want == "survivor" and not c.is_monster()):
			pick = c
			break
	if pick == null or pick == _shown:
		return
	_shown = pick
	for c in _clients:
		if c.hud != null:
			c.hud.visible = c == pick
	pick.camera.make_current()
	if not _args.has("bot"):
		pick.scripted = null
	print("SHOWING %s (%s)" % [pick.name, "monster" if pick.is_monster() else "survivor"])


func _bot(c: RoundClient) -> void:
	var feet := c.body.global_position
	if _target == Vector3.INF:
		var best := INF
		for t in _map.interactables():
			var m := t as MapMarker
			if m != null and m.type == &"hiding" and feet.distance_to(m.position) < best:
				best = feet.distance_to(m.position)
				_target = m.position
		print("BOT target %s from %s" % [_target, feet])
	var point := _target + Vector3.UP * _knobs.controller.capsule_height_m * 0.5
	var eye := feet + Vector3.UP * _knobs.controller.eye_height_m
	var flat := Vector2(point.x - eye.x, point.z - eye.z)
	c.scripted.yaw = atan2(-flat.x, -flat.y)
	c.scripted.pitch = atan2(point.y - eye.y, flat.length())
	var near := flat.length() < _knobs.objectives.interact_range_m * 0.6
	c.scripted.move = Vector2.ZERO if near else Vector2(0, 1)
	if near and _press_frame < 0 and c.body.velocity.length() < 0.05:
		c.scripted.interact = true
		_press_frame = Engine.get_frames_drawn()
		_shot("press")
		print("PRESS frame %d target %d" % [_press_frame, c.local_target(c.scripted.yaw, c.scripted.pitch)])
	elif _press_frame >= 0 and c.bar.visible and not has_meta(&"bar"):
		set_meta(&"bar", true)
		_shot("bar")
		var n := Engine.get_frames_drawn() - _press_frame
		print("BAR frame %d: %d drawn frames after the press" % [Engine.get_frames_drawn(), n])
	if _press_frame >= 0 and not has_meta(&"acked") and c.predictor.last_own.get("hold_net_id", -1) != -1:
		set_meta(&"acked", true)
		print("SERVER HOLD net id %d at frame %d (bar visible %s)" % [c.predictor.last_own.hold_net_id,
				Engine.get_frames_drawn(), c.bar.visible])


## Saves this frame once it is drawn (the viewport texture read in _process still holds the last frame).
func _shot(tag: String) -> void:
	if not _args.has("shots"):
		return
	var frame := Engine.get_frames_drawn()
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_args["shots"], tag]
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT %s of frame %d" % [path, frame])


func _look(c: RoundClient) -> void:
	var feet := c.body.global_position
	var best := INF
	for n: Node3D in c.remotes.values():
		if n.visible and feet.distance_to(n.position) < best:
			best = feet.distance_to(n.position)
			var d := n.position - feet
			c.scripted.yaw = atan2(-d.x, -d.z)
			c.scripted.pitch = -0.1
