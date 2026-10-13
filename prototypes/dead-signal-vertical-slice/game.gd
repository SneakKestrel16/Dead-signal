# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does one networked greybox round deliver "you can't be sure the person next to you is a person"?
# Date: 2026-10-13
extends Node3D
## One round. Every peer builds the same facility and player bodies. The host's
## server half owns every rule: holds, Lunge, takedown, stun lock, observation,
## transform, objectives, round clock and outcome. It mirrors its state to all
## peers (`st` per player, `world` for the round); clients render from it and
## send requests. All times in state are server times (`now()`).

const BROADCAST_HZ := 6.0
const OBSERVE_STEP := 0.1
const SIGHT_MASK := MapBuilder.L_WORLD | MapBuilder.L_DOORS
const SHOT_MASK := MapBuilder.L_WORLD | MapBuilder.L_GLASS | MapBuilder.L_DOORS

var map := MapBuilder.new()
var players_node: Node3D
var hud: Node
var st: Dictionary = {}
var world: Dictionary = {}
var started := false
var ended := false
var local_id := 0
var bodies: Dictionary = {}
var _offset := 0.0
var _loaded: Dictionary = {}
var _bcast_t := 0.0
var _obs_t := 0.0
var _dirty := false
var _rng := RandomNumberGenerator.new()
var _door_meshes: Array = []
var _drive_nodes: Array = []
var _terminal_label: Label3D
var _exit_light: OmniLight3D
var _local_hold := ""
var _scenario: Node


func _ready() -> void:
	local_id = Net.me()
	_rng.seed = Net.round_seed
	_environment()
	map.build(self)
	players_node = Node3D.new()
	players_node.name = "Players"
	add_child(players_node)
	var ids: Array = Net.players.keys()
	ids.sort()
	for id in ids:
		var p := SlicePlayer.new()
		p.setup(self, int(id), int(id) == local_id)
		players_node.add_child(p)
		p.force_pose(Vector3(5, 0, 30), 0.0)
		bodies[int(id)] = p
	hud = preload("res://hud.gd").new()
	hud.game = self
	add_child(hud)
	if Net.args.has("bot"):
		var bot := preload("res://bot.gd").new()
		bot.game = self
		add_child(bot)
	if Net.is_host() and Net.args.has("scenario"):
		_scenario = (preload("res://shots.gd") if Net.args["scenario"] == "shots" else preload("res://scenario.gd")).new()
		_scenario.game = self
		add_child(_scenario)
	if Net.is_host():
		multiplayer.peer_disconnected.connect(_on_peer_left)
		_loaded[1] = true
		get_tree().create_timer(60.0).timeout.connect(_start_if_waiting)
		_check_all_loaded()
	else:
		_client_loaded.rpc_id(1)
	if _can_capture():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------------ shared helpers

func _can_capture() -> bool:
	return not Net.args.has("bot") and not Net.args.has("nocapture") and DisplayServer.get_name() != "headless"


func now() -> float:
	return Time.get_ticks_msec() / 1000.0 + _offset


func pstate(id: int) -> Dictionary:
	return st.get(id, {})


func input_frozen() -> bool:
	return ended or not started


## "windup", "dash" or "" for a monster's current Lunge, from server times.
func lunge_phase(id: int) -> String:
	var s: Dictionary = pstate(id)
	if s.get("lunge_state", "") == "":
		return ""
	var t := now() - float(s.get("lunge_t0", 0.0))
	if t < Knobs.f("lunge_windup_s"):
		return "windup"
	if t < Knobs.f("lunge_windup_s") + Knobs.f("lunge_dash_s"):
		return "dash"
	return ""


## The form a body shows: survivor character, borrowed character, or -1 (true form).
## During a transform the old form shows until it completes.
func shown_form(id: int) -> int:
	var s: Dictionary = pstate(id)
	if s.is_empty():
		return int(Net.players.get(id, {}).get("character", -2))
	return int(s.get("form", -2))


func terminal_pos() -> Vector3:
	return map.points.get(world.get("terminal", "T1"), Vector3.ZERO)


func player_name(id: int) -> String:
	return String(Net.players.get(id, {}).get("name", "?"))


func survivors() -> Array:
	return st.keys().filter(func(id: int) -> bool: return st[id].role == "survivor")


func monster_id() -> int:
	for id in st:
		if st[id].role == "monster":
			return id
	return 0


# ------------------------------------------------------------------ round start

@rpc("any_peer", "reliable")
func _client_loaded() -> void:
	if not Net.is_host():
		return
	_loaded[multiplayer.get_remote_sender_id()] = true
	_check_all_loaded()


func _check_all_loaded() -> void:
	if started:
		return
	for id in Net.players:
		if not _loaded.has(id):
			return
	_start_round()


func _start_if_waiting() -> void:
	if not started:
		_start_round()


func _start_round() -> void:
	var t := now()
	var term := ["T1", "T2", "T3"][_rng.randi() % 3] as String
	var cands := ["d1", "d2", "d3", "d4", "d5", "d6"]
	if term == "T3":
		cands.erase("d6")
	var drives: Array = []
	for k in Knobs.i("drives_required"):
		var pick: String = cands[_rng.randi() % cands.size()]
		cands.erase(pick)
		drives.append({"point": pick, "state": "active", "pos": map.points[pick], "holder": 0})
	world = {
		"start": t, "phase": "infiltration", "terminal": term, "drives": drives,
		"docked": 0, "activating": false, "activation": 0.0, "activated": false,
		"exit_open": false, "doors": [], "outcome": "", "reason": "", "lock_t": 0.0, "extracted": 0,
	}
	for d in map.doors:
		world.doors.append(not d.exit)
	var spawns := ["S1", "S2", "S3", "S4", "S5"]
	var mspawn := ["M1", "M2", "M3"][_rng.randi() % 3] as String
	var poses := {}
	var n := 0
	for id in Net.players:
		var info: Dictionary = Net.players[id]
		var s := {
			"role": info.role, "character": info.character, "life": "healthy", "downs": 0,
			"bleed_until": 0.0, "stun_until": 0.0, "root_until": 0.0, "immune_until": 0.0,
			"shock_fx_until": 0.0, "taser": Knobs.i("stun_item_charges"), "taser_next": 0.0,
			"form": int(info.character), "transform_until": 0.0, "transform_to": -2, "form_cd_until": 0.0,
			"lunge_state": "", "lunge_t0": -100.0, "lunge_cd_until": 0.0, "miss_slow_until": 0.0,
			"commit_until": 0.0, "victim": 0, "seized_by": 0, "grace_until": 0.0,
			"carrying": 0, "hold_kind": "", "hold_target": "", "hold_p": 0.0, "hold_need": 0.0,
			"hold_fake": false, "rescue_p": 0.0, "unlocked": [], "observe": {},
		}
		st[int(id)] = s
		if info.role == "monster":
			s.form = -1
			poses[int(id)] = [map.points[mspawn], PI]
		else:
			poses[int(id)] = [map.points[spawns[n]] + Vector3(0, 0, 0), PI]
			n += 1
	_round_start.rpc(st, world, t, poses)


@rpc("authority", "call_local", "reliable")
func _round_start(s: Dictionary, w: Dictionary, server_t: float, poses: Dictionary) -> void:
	_offset = server_t - Time.get_ticks_msec() / 1000.0
	st = s
	world = w
	for id in poses:
		if bodies.has(int(id)):
			bodies[int(id)].force_pose(poses[id][0], poses[id][1])
	_build_objective_nodes()
	_apply_world()
	started = true
	hud.round_started()


## Test hook: the server moves a body; its owner applies the pose.
func teleport(id: int, pos: Vector3, y: float) -> void:
	_force.rpc(id, pos, y)


@rpc("authority", "call_local", "reliable")
func _force(id: int, pos: Vector3, y: float) -> void:
	if bodies.has(id):
		bodies[id].force_pose(pos, y)
		bodies[id].pitch = 0.0


# ------------------------------------------------------------------ state mirror

@rpc("authority", "reliable")
func _state(s: Dictionary, w: Dictionary, server_t: float) -> void:
	_offset = lerpf(_offset, server_t - Time.get_ticks_msec() / 1000.0, 0.2)
	st = s
	world = w
	_apply_world()


@rpc("authority", "call_local", "reliable")
func _fx(kind: String, pos: Vector3, a: int, b: int, text: String) -> void:
	match kind:
		"lunge_cue":
			Sfx.play_at(self, "lunge_cue", pos, Knobs.f("lunge_cue_radius_m"), 2.0)
		"hit":
			Sfx.play_at(self, "hit", pos, 25.0, 4.0)
		"miss":
			Sfx.play_at(self, "miss", pos, 15.0)
		"taser":
			Sfx.play_at(self, "taser", pos, 20.0)
			_beam(bodies[a].eye_position() if bodies.has(a) else pos, pos)
		"distortion":
			Sfx.play_at(self, "distortion", pos, Knobs.f("distortion_radius_m"), 2.0)
		"reveal":
			Sfx.play_at(self, "reveal", pos, Knobs.f("reveal_radius_m") * 2.0, 4.0)
		"door":
			Sfx.play_at(self, "door", pos, 15.0)
		"extract":
			Sfx.play_at(self, "extract", pos, 10.0)
		"downed":
			Sfx.play_at(self, "downed", pos, 30.0, 2.0)
		"alarm":
			Sfx.play_ui("alarm", -8.0)
		"face":
			if local_id == a:
				Sfx.play_ui("tick", -10.0)
	if text != "" and (b == 0 or b == local_id):
		hud.feed(text)


func _apply_world() -> void:
	var doors: Array = world.get("doors", [])
	for k in mini(doors.size(), map.doors.size()):
		var d: Dictionary = map.doors[k]
		var open: bool = doors[k] or (d.exit and world.get("exit_open", false))
		var body: StaticBody3D = d.body
		body.get_child(0).disabled = open
		body.visible = not open
	var drives: Array = world.get("drives", [])
	for k in mini(drives.size(), _drive_nodes.size()):
		var dv: Dictionary = drives[k]
		var node: Node3D = _drive_nodes[k]
		var show: bool = dv.state in ["active", "dropped", "ejected"]
		node.visible = show
		if show:
			node.global_position = dv.pos + Vector3(0, 0.9 if dv.state == "active" else 0.15, 0)
	if _terminal_label:
		var txt := "TERMINAL\nDrives %d/2" % int(world.get("docked", 0))
		if world.get("activated", false):
			txt = "EVACUATION ACTIVE\nEXIT OPEN"
		elif world.get("activating", false):
			txt = "ACTIVATING\n%d s" % int(ceil(Knobs.f("evac_activation_s") - float(world.get("activation", 0.0))))
		elif int(world.get("docked", 0)) >= 2:
			txt = "ARMED\nhold E to start"
		_terminal_label.text = txt
	if _exit_light:
		_exit_light.light_color = Color(0.2, 1.0, 0.3) if world.get("exit_open", false) else Color(1.0, 0.1, 0.05)


func _build_objective_nodes() -> void:
	for dv in world.drives:
		var n := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.3, 0.2, 0.4)
		n.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 1.0, 0.45)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 1.0, 0.45)
		mat.emission_energy_multiplier = 3.0
		n.material_override = mat
		var l := OmniLight3D.new()
		l.light_color = Color(0.2, 1.0, 0.45)
		l.omni_range = 3.0
		l.light_energy = 0.45
		n.add_child(l)
		add_child(n)
		n.global_position = dv.pos + Vector3(0, 0.9, 0)
		var stand := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.6, 0.8, 0.6)
		stand.mesh = sm
		add_child(stand)
		stand.global_position = dv.pos + Vector3(0, 0.4, 0)
		_drive_nodes.append(n)
	var tp := terminal_pos()
	var term := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.0, 1.4, 0.5)
	term.mesh = tm
	add_child(term)
	term.global_position = tp + Vector3(0, 0.7, 0)
	_terminal_label = Label3D.new()
	_terminal_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_terminal_label.font_size = 40
	_terminal_label.pixel_size = 0.004
	_terminal_label.modulate = Color(0.4, 0.9, 1.0)
	add_child(_terminal_label)
	_terminal_label.global_position = tp + Vector3(0, 1.9, 0)
	var tl := OmniLight3D.new()
	tl.light_color = Color(0.3, 0.8, 1.0)
	tl.omni_range = 4.0
	tl.light_energy = 0.7
	add_child(tl)
	tl.global_position = tp + Vector3(0, 1.6, 0)
	_exit_light = OmniLight3D.new()
	_exit_light.omni_range = 5.0
	_exit_light.light_energy = 1.2
	add_child(_exit_light)
	_exit_light.global_position = map.points.get("exit", Vector3.ZERO) + Vector3(-1.5, 2.5, 0)


func _beam(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(a + Vector3(0, -0.2, 0))
	im.surface_add_vertex(b)
	im.surface_end()
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.5, 0.8, 1.0)
	mi.material_override = mat
	add_child(mi)
	get_tree().create_timer(0.25).timeout.connect(mi.queue_free)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.35)
	env.ambient_light_energy = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.8, 0.8, 0.85)
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ------------------------------------------------------------------ local requests (any peer)

func _process(_dt: float) -> void:
	if not started or ended:
		return
	if Input.is_action_just_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _can_capture():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	var me := bodies.get(local_id) as SlicePlayer
	if me == null:
		return
	if Input.is_action_just_pressed("flashlight"):
		me.flashlight_on = not me.flashlight_on
	if Input.is_action_just_pressed("fire"):
		request("fire", me.forward())
	if Input.is_action_just_pressed("true_form"):
		request("transform", -1)
	for k in 5:
		if Input.is_action_just_pressed("face_%d" % (k + 1)):
			request("transform", k)
	if Input.is_action_just_pressed("interact"):
		var tg := local_target()
		if tg.has("door"):
			request("door", tg.door)
		elif tg.has("target"):
			_local_hold = tg.target
			request("hold", tg.target)
	if Input.is_action_just_released("interact") and _local_hold != "":
		_local_hold = ""
		request("release", 0)


## Sends one request to the server. Also the entry point for bots and tests.
func request(kind: String, arg: Variant) -> void:
	if Net.is_host():
		_handle(local_id, kind, arg)
	else:
		_rq.rpc_id(1, kind, arg)


@rpc("any_peer", "reliable")
func _rq(kind: String, arg: Variant) -> void:
	if Net.is_host():
		_handle(multiplayer.get_remote_sender_id(), kind, arg)


## What the local player's E would act on, for the prompt and the request.
func local_target() -> Dictionary:
	var me := bodies.get(local_id) as SlicePlayer
	var s := pstate(local_id)
	if me == null or s.is_empty() or s.life != "healthy":
		return {}
	return target_for(local_id, me.global_position, me.forward())


func target_for(id: int, pos: Vector3, fwd: Vector3) -> Dictionary:
	var s := pstate(id)
	var monster: bool = s.get("role", "") == "monster"
	if monster and int(s.form) == -1:
		return _door_target(pos, fwd)
	var best := {}
	var best_d := 1e9
	var r := Knobs.f("interact_range_m")
	for oid in st:
		var o: Dictionary = st[oid]
		if oid != id and o.role == "survivor" and o.life == "downed" and bodies.has(oid):
			var d: float = bodies[oid].global_position.distance_to(pos)
			if d <= Knobs.f("rescue_range_m") + 0.5 and d < best_d:
				best_d = d
				best = {"target": "rescue:%d" % oid, "text": "Rescue " + player_name(oid), "need": Knobs.f("rescue_duration_s")}
	var drives: Array = world.get("drives", [])
	for k in drives.size():
		var dv: Dictionary = drives[k]
		if not dv.state in ["active", "dropped", "ejected"]:
			continue
		var d := (dv.pos as Vector3).distance_to(pos)
		if d <= r and d < best_d:
			if int(s.carrying) >= Knobs.i("max_drives_carried") and not monster:
				continue
			best_d = d
			var extract: bool = dv.state == "active"
			best = {"target": "drive:%d" % k, "text": "Extract data drive" if extract else "Pick up data drive",
				"need": Knobs.f("drive_extract_s") if extract else Knobs.f("pickup_s")}
	var td := terminal_pos().distance_to(pos)
	if td <= r and td < best_d:
		if int(s.carrying) > 0 and int(world.docked) < 2:
			best = {"target": "term", "text": "Dock data drives", "need": Knobs.f("dock_s")}
		elif int(world.docked) >= 2 and not world.activating:
			best = {"target": "term", "text": "Start evacuation", "need": Knobs.f("activation_start_s")}
	if best.is_empty():
		return _door_target(pos, fwd)
	return best


func _door_target(pos: Vector3, fwd: Vector3) -> Dictionary:
	var best := {}
	var best_d := Knobs.f("door_range_m")
	var doors: Array = world.get("doors", [])
	for k in mini(doors.size(), map.doors.size()):
		var d: Dictionary = map.doors[k]
		if d.exit:
			continue
		var c: Vector3 = d.center
		var to := Vector3(c.x - pos.x, 0, c.z - pos.z)
		var dist := to.length()
		if dist < best_d and (dist < 0.8 or to.normalized().dot(Vector3(fwd.x, 0, fwd.z).normalized()) > 0.3):
			best_d = dist
			best = {"door": k, "text": "Close door" if doors[k] else "Open door"}
	return best


# ------------------------------------------------------------------ server: requests

func _handle(id: int, kind: String, arg: Variant) -> void:
	if not started or ended or not st.has(id):
		return
	match kind:
		"fire":
			if st[id].role == "monster":
				srv_lunge(id)
			else:
				srv_taser(id, arg)
		"transform":
			srv_transform(id, int(arg))
		"hold":
			srv_hold(id, String(arg))
		"release":
			_cancel_hold(id)
		"door":
			srv_door(id, int(arg))


func _locked(s: Dictionary, t: float) -> bool:
	return t < float(s.stun_until)


func srv_lunge(id: int) -> void:
	var s: Dictionary = st[id]
	var t := now()
	if int(s.form) != -1 or float(s.transform_until) > t or t < float(s.lunge_cd_until) or _locked(s, t) or int(s.victim) != 0 or s.lunge_state != "":
		return
	s.lunge_state = "windup"
	s.lunge_t0 = t
	s.lunge_cd_until = t + Knobs.f("lunge_cooldown_s")
	_cancel_hold(id)
	_dirty = true
	_fx.rpc("lunge_cue", bodies[id].global_position, id, 0, "")


func srv_taser(id: int, dir: Variant) -> void:
	var s: Dictionary = st[id]
	var t := now()
	if s.life != "healthy" or int(s.taser) <= 0 or t < float(s.taser_next) or _locked(s, t):
		return
	s.taser = int(s.taser) - 1
	s.taser_next = t + Knobs.f("stun_item_reuse_s")
	_dirty = true
	var aim: Vector3 = (dir as Vector3).normalized() if dir is Vector3 else bodies[id].forward()
	get_tree().create_timer(Knobs.f("stun_use_delay_s")).timeout.connect(func() -> void: _taser_trace(id, aim))


func _taser_trace(id: int, aim: Vector3) -> void:
	if ended:
		return
	var origin: Vector3 = bodies[id].eye_position()
	var best := 0
	var best_d := Knobs.f("stun_range_m")
	var tol := deg_to_rad(Knobs.f("stun_aim_tolerance_deg"))
	for oid in st:
		var o: Dictionary = st[oid]
		if oid == id or not o.life in ["healthy"]:
			continue
		var chest: Vector3 = bodies[oid].global_position + Vector3(0, 1.2, 0)
		var to := chest - origin
		var d := to.length()
		if d > best_d:
			continue
		var ang := aim.angle_to(to)
		var perp := d * sin(ang)
		if ang > tol and perp > 0.35:
			continue
		if not _clear(origin, chest, SHOT_MASK):
			continue
		best = oid
		best_d = d
	var hit_pos := origin + aim * Knobs.f("stun_range_m")
	if best != 0:
		hit_pos = bodies[best].global_position + Vector3(0, 1.2, 0)
		_apply_lock(best)
	_fx.rpc("taser", hit_pos, id, 0, "")


## Stun or shock: one lock for all, no refresh, post-lock window (Survivor Defense rules 10-14).
func _apply_lock(id: int) -> void:
	var s: Dictionary = st[id]
	var t := now()
	s.shock_fx_until = t + 0.6
	_cancel_hold(id)
	_dirty = true
	if t < float(s.stun_until) or t < float(s.immune_until):
		return
	s.stun_until = t + Knobs.f("stun_duration_s")
	s.root_until = t + Knobs.f("stun_root_s")
	s.immune_until = float(s.stun_until) + Knobs.f("stun_immunity_s")
	if s.role == "monster":
		s.lunge_state = ""
		s.transform_until = 0.0
		if int(s.victim) != 0:
			var v: Dictionary = st[int(s.victim)]
			v.life = "healthy"
			v.seized_by = 0
			v.grace_until = t + Knobs.f("post_release_grace_s")
			s.victim = 0
			s.commit_until = 0.0


func srv_transform(id: int, form: int) -> void:
	var s: Dictionary = st[id]
	var t := now()
	if s.role != "monster" or form == int(s.form) or float(s.transform_until) > t or t < float(s.form_cd_until):
		return
	if _locked(s, t) or s.lunge_state != "" or int(s.victim) != 0:
		return
	if form != -1 and not form in s.unlocked:
		return
	s.transform_to = form
	s.transform_until = t + Knobs.f("transform_duration_s")
	_cancel_hold(id)
	_dirty = true
	_fx.rpc("distortion", bodies[id].global_position, id, 0, "")


func srv_door(id: int, k: int) -> void:
	var s: Dictionary = st[id]
	var t := now()
	if k < 0 or k >= map.doors.size() or map.doors[k].exit or s.life != "healthy" or _locked(s, t):
		return
	var d: Dictionary = map.doors[k]
	if bodies[id].global_position.distance_to(d.center) > Knobs.f("door_range_m") + 1.0:
		return
	if world.doors[k]:
		var box := AABB(d.center - d.size / 2.0, d.size).grow(SlicePlayer.CAPSULE_R)
		for oid in bodies:
			if st[oid].life in ["eliminated", "escaped"]:
				continue
			var p: Vector3 = bodies[oid].global_position + Vector3(0, 1.0, 0)
			if box.has_point(p):
				return
	world.doors[k] = not world.doors[k]
	_dirty = true
	_fx.rpc("door", d.center, id, 0, "")


func srv_hold(id: int, target: String) -> void:
	var s: Dictionary = st[id]
	var t := now()
	if s.life != "healthy" or _locked(s, t) or s.hold_kind != "" or int(s.victim) != 0:
		return
	var monster: bool = s.role == "monster"
	if monster and int(s.form) == -1:
		return
	var tg := target_for(id, bodies[id].global_position, bodies[id].forward())
	if tg.get("target", "") != target:
		return
	s.hold_kind = target
	s.hold_target = target
	s.hold_p = 0.0
	s.hold_need = float(tg.need)
	s.hold_fake = monster
	if target.begins_with("rescue:"):
		s.hold_p = float(st[int(target.split(":")[1])].rescue_p)
	_dirty = true


func _cancel_hold(id: int) -> void:
	var s: Dictionary = st[id]
	if s.hold_kind == "":
		return
	s.hold_kind = ""
	s.hold_target = ""
	s.hold_p = 0.0
	_dirty = true


# ------------------------------------------------------------------ server: tick

func _physics_process(dt: float) -> void:
	if not Net.is_host() or not started or ended:
		return
	var t := now()
	var el := t - float(world.start)
	_tick_phase(el)
	for id in st:
		_tick_player(id, t, dt)
	_tick_terminal(dt)
	_obs_t += dt
	if _obs_t >= OBSERVE_STEP:
		_observe(_obs_t)
		_obs_t = 0.0
	_check_outcome(t, el)
	_bcast_t += dt
	if _dirty and _bcast_t >= 0.05 or _bcast_t >= 1.0 / BROADCAST_HZ:
		_bcast_t = 0.0
		_dirty = false
		_state.rpc(st, world, t)
		_apply_world()


func _tick_phase(el: float) -> void:
	var ph: String = world.phase
	var nxt := ph
	if el >= Knobs.f("round_duration_s") - Knobs.f("evacuation_window_s") or int(world.docked) >= 2:
		nxt = "evacuation"
	elif el >= Knobs.f("infiltration_end_s"):
		nxt = "investigation"
	if nxt != ph and not (ph == "evacuation"):
		world.phase = nxt
		_dirty = true
		_fx.rpc("alarm" if nxt == "evacuation" else "none", Vector3.ZERO, 0, 0, "Phase: " + nxt.capitalize())


func _tick_player(id: int, t: float, dt: float) -> void:
	var s: Dictionary = st[id]
	var body: SlicePlayer = bodies[id]
	if s.role == "monster":
		if s.lunge_state != "":
			var since := t - float(s.lunge_t0)
			var w := Knobs.f("lunge_windup_s")
			var dash := Knobs.f("lunge_dash_s")
			if since >= w:
				var v := _lunge_hit(id)
				if v != 0:
					_start_takedown(id, v)
				elif since >= w + dash + 0.15:
					s.lunge_state = ""
					s.miss_slow_until = t + Knobs.f("miss_slow_s")
					_dirty = true
					_fx.rpc("miss", body.global_position, id, 0, "")
		if int(s.victim) != 0 and t >= float(s.commit_until):
			_complete_takedown(id)
		if float(s.transform_until) > 0.0 and t >= float(s.transform_until):
			var was := int(s.form)
			s.form = int(s.transform_to)
			s.transform_until = 0.0
			s.form_cd_until = t + Knobs.f("form_change_cooldown_s")
			_dirty = true
			if int(s.form) == -1 and was != -1:
				_fx.rpc("reveal", body.global_position, id, 0, "")
	else:
		if s.life == "downed":
			if t >= float(s.bleed_until):
				_eliminate(id, "%s bled out" % player_name(id))
			elif not _being_rescued(id):
				s.rescue_p = maxf(0.0, float(s.rescue_p) - Knobs.f("rescue_decay_rate") * dt)
		if s.life == "healthy" and world.exit_open and map.exit_area.has_point(body.global_position + Vector3(0, 0.5, 0)):
			_escape(id)
	if s.hold_kind != "":
		_tick_hold(id, t, dt)


func _lunge_hit(id: int) -> int:
	var m: SlicePlayer = bodies[id]
	var fwd := Basis(Vector3.UP, m.yaw) * Vector3.FORWARD
	var half := deg_to_rad(Knobs.f("lunge_cone_deg")) / 2.0
	var t := now()
	for vid in st:
		var v: Dictionary = st[vid]
		if v.role != "survivor" or v.life != "healthy" or t < float(v.grace_until):
			continue
		var to: Vector3 = bodies[vid].global_position - m.global_position
		to.y = 0.0
		if to.length() > Knobs.f("lunge_hit_radius_m"):
			continue
		if to.length() > 0.3 and fwd.angle_to(to.normalized()) > half:
			continue
		if not _clear(m.global_position + Vector3(0, 1.0, 0), bodies[vid].global_position + Vector3(0, 1.0, 0), SIGHT_MASK):
			continue
		return vid
	return 0


func _start_takedown(mid: int, vid: int) -> void:
	var s: Dictionary = st[mid]
	var v: Dictionary = st[vid]
	var t := now()
	s.lunge_state = ""
	s.victim = vid
	s.commit_until = t + Knobs.f("takedown_commit_s")
	v.life = "seized"
	v.seized_by = mid
	_cancel_hold(vid)
	_dirty = true
	_fx.rpc("hit", bodies[vid].global_position, mid, 0, "")


func _complete_takedown(mid: int) -> void:
	var s: Dictionary = st[mid]
	var vid := int(s.victim)
	s.victim = 0
	s.commit_until = 0.0
	if not st.has(vid):
		return
	var v: Dictionary = st[vid]
	v.seized_by = 0
	v.downs = int(v.downs) + 1
	_drop_drives(vid)
	if int(v.downs) >= Knobs.i("downs_to_eliminate"):
		_eliminate(vid, "%s was taken" % player_name(vid))
		return
	v.life = "downed"
	v.bleed_until = now() + Knobs.f("bleedout_s")
	v.rescue_p = 0.0
	_dirty = true
	_fx.rpc("downed", bodies[vid].global_position, vid, 0, "%s is down" % player_name(vid))


func _eliminate(id: int, msg: String) -> void:
	var s: Dictionary = st[id]
	s.life = "eliminated"
	_drop_drives(id)
	_cancel_hold(id)
	_dirty = true
	_fx.rpc("downed", bodies[id].global_position, id, 0, msg)


func _escape(id: int) -> void:
	var s: Dictionary = st[id]
	s.life = "escaped"
	for dv in world.drives:
		if dv.state == "carried" and int(dv.holder) == id:
			dv.state = "extracted"
			world.extracted = int(world.extracted) + 1
	s.carrying = 0
	_dirty = true
	_fx.rpc("extract", bodies[id].global_position, id, 0, "%s escaped" % player_name(id))
	if int(world.extracted) >= Knobs.i("drives_required") and world.outcome == "":
		world.outcome = "survivors"
		world.reason = "The evidence escaped"
		world.lock_t = now()
		_fx.rpc("none", Vector3.ZERO, 0, 0, "Both drives are out — survivors win when the rest escape")


func _drop_drives(id: int) -> void:
	for dv in world.drives:
		if dv.state == "carried" and int(dv.holder) == id:
			dv.state = "dropped"
			dv.pos = bodies[id].global_position
			dv.holder = 0
	st[id].carrying = 0


func _being_rescued(vid: int) -> bool:
	for id in st:
		if st[id].hold_kind == "rescue:%d" % vid:
			return true
	return false


func _tick_hold(id: int, t: float, dt: float) -> void:
	var s: Dictionary = st[id]
	var body: SlicePlayer = bodies[id]
	var target: String = s.hold_kind
	if s.life != "healthy" or _locked(s, t):
		_cancel_hold(id)
		return
	var anchor := Vector3.ZERO
	var r := Knobs.f("interact_range_m") + 0.75
	if target.begins_with("drive:"):
		var dv: Dictionary = world.drives[int(target.split(":")[1])]
		if not dv.state in ["active", "dropped", "ejected"]:
			_cancel_hold(id)
			return
		anchor = dv.pos
	elif target == "term":
		anchor = terminal_pos()
	elif target.begins_with("rescue:"):
		var vid := int(target.split(":")[1])
		if st[vid].life != "downed":
			_cancel_hold(id)
			return
		anchor = bodies[vid].global_position
		r = Knobs.f("rescue_range_m") + 0.75
	if body.global_position.distance_to(anchor) > r:
		_cancel_hold(id)
		return
	if s.hold_fake:
		return
	s.hold_p = float(s.hold_p) + dt
	if target.begins_with("rescue:"):
		st[int(target.split(":")[1])].rescue_p = s.hold_p
	if float(s.hold_p) >= float(s.hold_need):
		_complete_hold(id, target)
		_cancel_hold(id)
	elif int(s.hold_p * 4.0) != int((s.hold_p - dt) * 4.0):
		_dirty = true


func _complete_hold(id: int, target: String) -> void:
	var s: Dictionary = st[id]
	var pos: Vector3 = bodies[id].global_position
	_dirty = true
	if target.begins_with("drive:"):
		var dv: Dictionary = world.drives[int(target.split(":")[1])]
		var first: bool = dv.state == "active"
		dv.state = "carried"
		dv.holder = id
		s.carrying = int(s.carrying) + 1
		_fx.rpc("extract", pos, id, 0, ("%s recovered a data drive" if first else "%s picked up a data drive") % player_name(id))
	elif target == "term":
		if int(s.carrying) > 0 and int(world.docked) < 2:
			for dv in world.drives:
				if dv.state == "carried" and int(dv.holder) == id:
					dv.state = "docked"
					dv.holder = 0
					world.docked = int(world.docked) + 1
			s.carrying = 0
			_fx.rpc("extract", pos, id, 0, "Drives docked: %d/2" % int(world.docked))
		elif int(world.docked) >= 2 and not world.activating:
			world.activating = true
			_fx.rpc("alarm", pos, id, 0, "Evacuation activation started — hold the terminal area")
	elif target.begins_with("rescue:"):
		var vid := int(target.split(":")[1])
		var v: Dictionary = st[vid]
		v.life = "healthy"
		v.rescue_p = 0.0
		v.grace_until = now() + Knobs.f("post_rescue_grace_s")
		_fx.rpc("extract", pos, id, 0, "%s rescued %s" % [player_name(id), player_name(vid)])


func _tick_terminal(dt: float) -> void:
	if not world.activating or world.activated:
		return
	var tp := terminal_pos()
	var held := false
	for id in st:
		var s: Dictionary = st[id]
		if s.role == "survivor" and s.life == "healthy" and bodies[id].global_position.distance_to(tp) <= Knobs.f("terminal_zone_radius_m"):
			held = true
	if not held:
		return
	var before := int(world.activation)
	world.activation = float(world.activation) + dt
	if int(world.activation) != before:
		_dirty = true
	if float(world.activation) >= Knobs.f("evac_activation_s"):
		world.activated = true
		world.exit_open = true
		var k := 0
		for dv in world.drives:
			if dv.state == "docked":
				dv.state = "ejected"
				dv.pos = tp + Vector3(0.8 * (k * 2 - 1), 0, 0.8)
				k += 1
		_dirty = true
		_fx.rpc("alarm", tp, 0, 0, "Evacuation active: drives ejected, EXIT OPEN (C4 east)")


## Borrowed Face observation: survivors in the shapeshifter's view, in range, in sight.
func _observe(dt: float) -> void:
	var mid := monster_id()
	if mid == 0:
		return
	var s: Dictionary = st[mid]
	var m: SlicePlayer = bodies[mid]
	var eye := m.eye_position()
	var fwd := m.forward()
	var half := deg_to_rad(Knobs.f("observe_fov_deg")) / 2.0
	for vid in st:
		var v: Dictionary = st[vid]
		if v.role != "survivor" or v.life in ["eliminated", "escaped"]:
			continue
		var ch := int(v.character)
		if ch in s.unlocked:
			continue
		var chest: Vector3 = bodies[vid].global_position + Vector3(0, 1.2, 0)
		var to := chest - eye
		if to.length() > Knobs.f("observe_range_m") or fwd.angle_to(to) > half:
			continue
		if not _clear(eye, chest, SIGHT_MASK):
			continue
		var key := str(ch)
		s.observe[key] = float(s.observe.get(key, 0.0)) + dt
		if float(s.observe[key]) >= Knobs.f("observe_time_s"):
			s.unlocked.append(ch)
			_fx.rpc("face", Vector3.ZERO, mid, mid, "Face unlocked: " + String(Net.CHARACTERS[ch].name))
		_dirty = true


func _clear(a: Vector3, b: Vector3, mask: int) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, mask)
	q.hit_back_faces = false
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _check_outcome(t: float, el: float) -> void:
	var alive := 0
	var escaped := 0
	for id in survivors():
		var life: String = st[id].life
		if life in ["healthy", "downed", "seized"]:
			alive += 1
		elif life == "escaped":
			escaped += 1
	if world.outcome == "survivors":
		if alive == 0 or t >= float(world.lock_t) + Knobs.f("post_escape_window_s") or el >= Knobs.f("round_duration_s"):
			_end_round("survivors", world.reason)
		return
	if alive == 0:
		_end_round("monster", "All survivors eliminated" if escaped == 0 else "The evidence was lost")
	elif el >= Knobs.f("round_duration_s"):
		_end_round("monster", "The evacuation deadline passed")


func _on_peer_left(id: int) -> void:
	if not st.has(id) or ended:
		return
	if st[id].role == "monster":
		_end_round("none", "The shapeshifter left — no contest")
		return
	_eliminate(id, "%s: connection lost" % player_name(id))


func _end_round(outcome: String, reason: String) -> void:
	if ended:
		return
	var rows: Array = []
	for id in st:
		var s: Dictionary = st[id]
		rows.append({"name": player_name(id), "role": s.role, "character": int(s.character),
			"life": s.life, "downs": int(s.downs)})
	var res := {"outcome": outcome, "reason": reason, "rows": rows,
		"elapsed": now() - float(world.start), "extracted": int(world.extracted)}
	_round_end.rpc(res)


@rpc("authority", "call_local", "reliable")
func _round_end(res: Dictionary) -> void:
	ended = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var mine: String = String(Net.players.get(local_id, {}).get("role", ""))
	var won: bool = (res.outcome == "survivors" and mine == "survivor") or (res.outcome == "monster" and mine == "monster")
	res["headline"] = ("%s win — %s" % ["Survivors" if res.outcome == "survivors" else ("Shapeshifter" if res.outcome == "monster" else "Nobody"), res.reason])
	Net.last_results = res
	print("ROUND_END ", JSON.stringify(res))
	hud.show_results(res, won)
	if Net.is_host():
		get_tree().create_timer(Knobs.f("results_duration_s")).timeout.connect(Net.return_to_lobby)
