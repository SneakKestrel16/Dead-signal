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
## --bot=stage (borrowed-face story 009) lines the other clients up STAGE_AHEAD_M in front of the shown
## client's spawn, the shapeshifter beside one survivor (its target) in the middle, and turns the shown client
## to them. With --disguise the shapeshifter then faces its target and requests that survivor's form until
## its own entry shows it (disguise.png 1 s later); with --stun the shown client fires its taser at the
## shapeshifter once it stands there (after the disguise when both are given; stagger.png 6 drawn frames
## into the stagger). Every DisguisePresenter cue of the shown client is printed.

const LINK_PORT_OFFSET := 100
const LINK_SEED := 11
const STAGE_AHEAD_M := 3.5
const STAGE_SPACING_M := 1.2
## The line's centre sits this far +X of the shown spawn: the spawn room's west floor edge is near x 0.
const STAGE_RIGHT_M := 1.0
const ARRIVE_M := 0.15
## Drawn frames between form-change requests while waiting for the observation to complete.
const REQUEST_EVERY := 15

var _args: Dictionary = {}
var _knobs: Knobs
var _map: MapData
var _clients: Array[RoundClient] = []
var _shown: RoundClient
var _link: UdpLink
var _target := Vector3.INF
var _press_frame := -1
var _lit := false
## client -> whether it was the shapeshifter when first spawned (a disguise reads as a survivor later)
var _was_monster: Dictionary[RoundClient, bool] = {}
var _home := Vector3.INF
var _disguised_frame := -1
var _aimed := 0
var _fired := false
var _stagger_frame := -1


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
	elif _args.get("bot", "") == "stage":
		_stage(c0)


## Shows the chosen client's camera and HUD only.
func _pick_view() -> void:
	var want: String = _args.get("view", "0")
	var pick: RoundClient = null
	for i in _clients.size():
		var c := _clients[i]
		if not c.is_spawned():
			continue ## the role reads from the own entry once spawned
		if want == str(i) or (want == "monster" and _role(c)) or (want == "survivor" and not _role(c)):
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
	print("SHOWING %s (%s)" % [pick.name, "monster" if _role(pick) else "survivor"])


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


## Whether `c` is the shapeshifter, fixed at its first spawned answer.
func _role(c: RoundClient) -> bool:
	if not _was_monster.has(c):
		_was_monster[c] = c.is_monster()
	return _was_monster[c]


func _stage(c0: RoundClient) -> void:
	if c0.disguise != null and not c0.disguise.cue.is_connected(_on_cue):
		c0.disguise.cue.connect(_on_cue)
	if _home == Vector3.INF:
		_home = c0.body.global_position
	var line: Array[RoundClient] = []
	var m: RoundClient = null
	for c in _clients:
		if c == c0:
			continue
		if not c.is_spawned():
			return
		if _role(c):
			m = c
		else:
			line.append(c)
	if m == null or line.is_empty():
		return
	var mi := mini(1, line.size())
	line.insert(mi, m)
	var target: RoundClient = line[mi + 1] if mi + 1 < line.size() else line[mi - 1]
	var arrived := true
	for j in line.size():
		var c := line[j]
		var slot := _home + Vector3(STAGE_RIGHT_M + (j - (line.size() - 1) / 2.0) * STAGE_SPACING_M, 0.0,
				-STAGE_AHEAD_M)
		var d := slot - c.body.global_position
		d.y = 0.0
		if d.length() > ARRIVE_M:
			arrived = false
			if Engine.get_frames_drawn() % 150 == 0:
				print("STAGE %s at %s -> %s" % [c.name, c.body.global_position, slot])
			c.scripted.yaw = atan2(-d.x, -d.z)
			c.scripted.move = Vector2(0, 1)
			continue
		c.scripted.move = Vector2.ZERO
		var face := (target if c == m else c0).body.global_position - c.body.global_position
		c.scripted.yaw = atan2(-face.x, -face.z)
	var mid := (m.body.global_position + target.body.global_position) / 2.0 - c0.body.global_position
	c0.scripted.yaw = atan2(-mid.x, -mid.z)
	c0.scripted.pitch = -0.15
	if not arrived and not _fired: # a stunned body may leave its slot; keep watching it
		return
	var frame := Engine.get_frames_drawn()
	if _args.has("disguise") and _disguised_frame < 0:
		var want: int = target.predictor.last_own.get("appearance", -1)
		if m.predictor.last_own.get("appearance", -1) == want:
			_disguised_frame = frame
			print("DISGUISED as appearance %d at frame %d" % [want, frame])
		elif frame % REQUEST_EVERY == 0:
			(m.multiplayer as SceneMultiplayer).send_bytes(
					BorrowedFace.request_packet(target.predictor.last_own.get("id", -1)), 1,
					MultiplayerPeer.TRANSFER_MODE_RELIABLE)
		return
	if _disguised_frame >= 0 and frame == _disguised_frame + 30:
		_print_drawn(c0)
		_shot("disguise")
	if not _args.has("stun") or (_disguised_frame >= 0 and frame < _disguised_frame + 45):
		return
	var eye := c0.body.global_position + Vector3.UP * _knobs.controller.eye_height_m
	var chest := m.body.global_position + Vector3.UP * _knobs.controller.capsule_height_m * 0.6
	var flat := Vector2(chest.x - eye.x, chest.z - eye.z)
	c0.scripted.yaw = atan2(-flat.x, -flat.y)
	c0.scripted.pitch = atan2(chest.y - eye.y, flat.length())
	_aimed += 1
	if _aimed == 10 and not _fired:
		_fired = true
		(c0.multiplayer as SceneMultiplayer).send_bytes(SurvivorDefense.fire_packet(), 1,
				MultiplayerPeer.TRANSFER_MODE_RELIABLE)
		print("FIRE at frame %d" % frame)
	for h: int in c0.remotes:
		if _stagger_frame < 0 and c0.disguise.stagger_weight(h) > 0.0:
			_stagger_frame = frame
			print("STAGGER on handle %d at frame %d" % [h, frame])
	if _stagger_frame >= 0 and frame == _stagger_frame + 6:
		_print_drawn(c0)
		_shot("stagger")


func _on_cue(sound: StringName, at: Vector3) -> void:
	print("CUE %s at %s frame %d" % [sound, at, Engine.get_frames_drawn()])


## Prints every drawn remote's handle, snapshot appearance and position (the shot's legend).
func _print_drawn(c: RoundClient) -> void:
	for h: int in c.remotes:
		var n := c.remotes[h]
		print("DRAWN handle %d appearance %d at %s visible %s stagger %.2f" % [h,
				c.puppets.state_of(h).get("appearance", -1), n.position, n.visible, c.disguise.stagger_weight(h)])
