# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does one networked greybox round deliver "you can't be sure the person next to you is a person"?
# Date: 2026-10-13
class_name SlicePlayer
extends CharacterBody3D
## One player body. The owner moves it (owner-authoritative in the slice; production
## follows ADR-0002) under the locks, roots and slows the server sets in its state.
## Every peer renders its appearance from server state: a survivor's character,
## the shapeshifter's borrowed character, or its true form.

const SEND_HZ := 30.0
const CAPSULE_R := 0.3
const CAPSULE_H := 1.8

var game: Node
var peer_id := 0
var is_local := false
var yaw := 0.0
var pitch := 0.0
var crouching := false
var sprinting := false
var flashlight_on := true
## Test hooks: a bot steers with this instead of the keyboard.
var bot_move := Vector2.ZERO
var bot_sprint := false

var _head: Node3D
var _camera: Camera3D
var _light: SpotLight3D
var _visual: Node3D
var _shown_form := -99
var _carry_mesh: MeshInstance3D
var _hold_label: Label3D
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _target_pitch := 0.0
var _send_t := 0.0
var _step_acc := 0.0
var _last_pos := Vector3.ZERO
var _remote_moving := false
var _ghost := false
var _heartbeat: AudioStreamPlayer


func setup(g: Node, id: int, local: bool) -> void:
	game = g
	peer_id = id
	is_local = local
	name = str(id)
	collision_layer = MapBuilder.L_PLAYERS
	collision_mask = MapBuilder.L_WORLD | MapBuilder.L_GLASS | MapBuilder.L_DOORS
	floor_max_angle = deg_to_rad(40.5)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = CAPSULE_R
	cap.height = CAPSULE_H
	shape.shape = cap
	shape.position.y = CAPSULE_H / 2.0
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	_head = Node3D.new()
	_head.position.y = Knobs.f("eye_height_m")
	add_child(_head)
	_light = SpotLight3D.new()
	_light.spot_range = Knobs.f("flashlight_range_m")
	_light.spot_angle = Knobs.f("flashlight_angle_deg")
	_light.light_energy = 2.2
	_light.light_color = Color(1.0, 0.94, 0.82)
	_light.shadow_enabled = true
	_light.light_volumetric_fog_energy = 1.5
	_light.position = Vector3(0.18, -0.15, -0.2)
	_head.add_child(_light)
	if is_local:
		_camera = Camera3D.new()
		_camera.fov = 75.0
		_camera.near = 0.05
		_head.add_child(_camera)
		_camera.current = true
		_heartbeat = AudioStreamPlayer.new()
		_heartbeat.stream = Sfx.streams["heartbeat"]
		_heartbeat.volume_db = -4.0
		add_child(_heartbeat)
	_carry_mesh = MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.25, 0.18, 0.12)
	_carry_mesh.mesh = cm
	_carry_mesh.material_override = _emissive(Color(0.2, 1.0, 0.45), 2.0)
	_carry_mesh.position = Vector3(0, 1.25, 0.32)
	_carry_mesh.visible = false
	add_child(_carry_mesh)
	_hold_label = Label3D.new()
	_hold_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hold_label.position.y = 2.25
	_hold_label.font_size = 48
	_hold_label.pixel_size = 0.004
	_hold_label.modulate = Color(1, 1, 1, 0.9)
	_hold_label.no_depth_test = false
	add_child(_hold_label)


## Owner-side: place the body (spawn, or a test teleport from the server).
func force_pose(pos: Vector3, y: float) -> void:
	global_position = pos
	_target_pos = pos
	_last_pos = pos
	yaw = y
	_target_yaw = y
	velocity = Vector3.ZERO


func head_basis() -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)


func eye_position() -> Vector3:
	return global_position + Vector3(0, _head.position.y, 0)


func forward() -> Vector3:
	return -head_basis().z


## _input, not _unhandled_input: HUD controls under the captured cursor must never eat mouse look.
func _input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := 0.0025
		var dyaw: float = -event.screen_relative.x * sens
		var limit := _turn_limit_deg_s()
		if limit >= 0.0:
			dyaw = clampf(dyaw, -deg_to_rad(limit) / 60.0, deg_to_rad(limit) / 60.0)
		yaw += dyaw
		var lim := deg_to_rad(Knobs.f("pitch_limit_deg"))
		pitch = clampf(pitch - event.screen_relative.y * sens, -lim, lim)


func _turn_limit_deg_s() -> float:
	var s: Dictionary = game.pstate(peer_id)
	match game.lunge_phase(peer_id):
		"windup":
			return Knobs.f("lunge_windup_turn_deg_s")
		"dash":
			return Knobs.f("lunge_dash_turn_deg_s")
	if s.get("victim", 0) != 0:
		return 0.0
	return -1.0


func _physics_process(dt: float) -> void:
	if game == null or not game.started:
		return
	if is_local:
		_local_move(dt)
		_send_t += dt
		if _send_t >= 1.0 / SEND_HZ:
			_send_t = 0.0
			var flags := (1 if crouching else 0) | (2 if sprinting else 0) | (4 if flashlight_on else 0) | (8 if velocity.length() > 0.3 else 0)
			_pose.rpc(global_position, yaw, pitch, flags)
	else:
		global_position = global_position.lerp(_target_pos, minf(1.0, dt * 15.0))
		yaw = lerp_angle(yaw, _target_yaw, minf(1.0, dt * 15.0))
		pitch = lerpf(pitch, _target_pitch, minf(1.0, dt * 15.0))
	_update_visual(dt)
	_footsteps()


@rpc("any_peer", "unreliable_ordered")
func _pose(p: Vector3, y: float, pt: float, flags: int) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_target_pos = p
	_target_yaw = y
	_target_pitch = pt
	crouching = flags & 1 != 0
	sprinting = flags & 2 != 0
	flashlight_on = flags & 4 != 0
	_remote_moving = flags & 8 != 0


func _local_move(dt: float) -> void:
	var s: Dictionary = game.pstate(peer_id)
	var t: float = game.now()
	var life: String = s.get("life", "healthy")
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var input := bot_move
	var want_sprint := bot_sprint
	var want_crouch := false
	if captured and not game.input_frozen():
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		want_sprint = Input.is_action_pressed("sprint")
		want_crouch = Input.is_action_pressed("crouch")
	_ghost = life == "eliminated" or life == "escaped"
	if _ghost:
		collision_mask = 0
		var dir := head_basis() * Vector3(input.x, 0, input.y)
		velocity = dir * Knobs.f("walk_speed") * 1.5
		move_and_slide()
		return
	collision_mask = MapBuilder.L_WORLD | MapBuilder.L_GLASS | MapBuilder.L_DOORS
	var true_form: bool = s.get("role", "") == "monster" and int(s.get("form", -1)) == -1
	var mult := 1.0
	crouching = want_crouch and life == "healthy"
	sprinting = want_sprint and life == "healthy" and not crouching and input.y < -0.1
	if crouching:
		mult = Knobs.f("crouch_mult")
	elif sprinting:
		mult = Knobs.f("true_form_sprint_mult") if true_form else Knobs.f("sprint_mult")
	if life == "downed":
		mult = Knobs.f("crawl_mult")
	elif life == "seized":
		mult = 0.0
	if t < float(s.get("root_until", 0.0)) or s.get("victim", 0) != 0:
		mult = 0.0
	elif t < float(s.get("stun_until", 0.0)):
		mult *= Knobs.f("stun_slow_mult")
	if t < float(s.get("miss_slow_until", 0.0)):
		mult *= Knobs.f("miss_slow_multiplier")
	if s.get("hold_kind", "") != "":
		mult = 0.0
	var lp: String = game.lunge_phase(peer_id)
	var horizontal: Vector3
	if lp == "windup":
		horizontal = Vector3.ZERO
	elif lp == "dash":
		var fwd := Basis(Vector3.UP, yaw) * Vector3.FORWARD
		horizontal = fwd * Knobs.f("lunge_distance_m") / Knobs.f("lunge_dash_s")
	else:
		horizontal = Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y) * Knobs.f("walk_speed") * mult
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity.y -= 9.8 * dt
	else:
		velocity.y = -0.5
	move_and_slide()
	var eye := Knobs.f("eye_height_m")
	if life == "downed" or life == "seized":
		eye = Knobs.f("downed_eye_height_m")
	elif crouching:
		eye = Knobs.f("crouch_eye_height_m")
	_head.position.y = lerpf(_head.position.y, eye, minf(1.0, dt * 10.0))
	if _heartbeat:
		var hb := life == "downed" or life == "seized"
		if hb and not _heartbeat.playing:
			_heartbeat.play()
		elif not hb and _heartbeat.playing:
			_heartbeat.stop()


func _update_visual(_dt: float) -> void:
	var s: Dictionary = game.pstate(peer_id)
	var t: float = game.now()
	_head.rotation = Vector3(pitch, yaw, 0)
	_visual.rotation.y = yaw
	var life: String = s.get("life", "healthy")
	var form: int = game.shown_form(peer_id)
	if form != _shown_form:
		_build_appearance(form)
		_shown_form = form
	var hide_body := is_local or life == "eliminated" or life == "escaped"
	_visual.visible = not hide_body
	# Transform warp: flicker and wobble while changing form (Borrowed Face rule: subtle body warp).
	if float(s.get("transform_until", 0.0)) > t and not hide_body:
		_visual.scale = Vector3(1.0 + 0.08 * sin(t * 40.0), 1.0 + 0.05 * sin(t * 31.0), 1.0)
		_visual.visible = fmod(t, 0.16) > 0.04
	elif life == "downed" or life == "seized":
		_visual.scale = Vector3.ONE
		_visual.rotation.x = -PI / 2.0 * (1.0 if life == "downed" else 0.35)
		_visual.position.y = 0.3 if life == "downed" else 0.0
	else:
		_visual.rotation.x = 0.0
		_visual.position.y = 0.0
		_visual.scale = Vector3(1, 0.68 if crouching else 1.0, 1)
	# Shock stagger: identical for a shocked survivor and a stunned disguised monster (Survivor Defense rule 11).
	if float(s.get("shock_fx_until", 0.0)) > t and not hide_body:
		_visual.position.x = randf_range(-0.06, 0.06)
	else:
		_visual.position.x = 0.0
	var can_light := life == "healthy" and form >= 0
	_light.visible = flashlight_on and can_light and life != "eliminated"
	_carry_mesh.visible = int(s.get("carrying", 0)) > 0 and not hide_body
	var hk: String = s.get("hold_kind", "")
	if hk != "" and not is_local:
		var p: float = clampf(float(s.get("hold_p", 0.0)) / maxf(0.01, float(s.get("hold_need", 1.0))), 0.0, 1.0)
		var n := int(round(p * 10.0))
		_hold_label.text = "▮".repeat(n) + "▯".repeat(10 - n)
		_hold_label.visible = true
	else:
		_hold_label.visible = false


func _footsteps() -> void:
	var moved := global_position - _last_pos
	moved.y = 0.0
	_last_pos = global_position
	if _ghost or moved.length() > 3.0:
		return
	_step_acc += moved.length()
	if _step_acc < Knobs.f("stride_m"):
		return
	_step_acc = 0.0
	var s: Dictionary = game.pstate(peer_id)
	if s.get("life", "healthy") in ["eliminated", "escaped"]:
		return
	var radius := Knobs.f("footstep_walk_m")
	var db := -8.0
	if crouching:
		radius = Knobs.f("footstep_crouch_m")
		db = -18.0
	elif sprinting:
		radius = Knobs.f("footstep_sprint_m")
		db = -2.0
	var heavy: bool = game.shown_form(peer_id) == -1
	Sfx.play_at(game, "step_heavy" if heavy else "step", global_position + Vector3(0, 0.1, 0), radius, db)


func _build_appearance(form: int) -> void:
	for c in _visual.get_children():
		c.queue_free()
	if form == -1:
		_true_form()
		return
	if form < 0 or form >= Net.CHARACTERS.size():
		return
	var ch: Dictionary = Net.CHARACTERS[form]
	var col: Color = ch.color
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = CAPSULE_R
	cap.height = CAPSULE_H - 0.1
	body.mesh = cap
	body.material_override = _flat(col)
	body.position.y = (CAPSULE_H - 0.1) / 2.0
	_visual.add_child(body)
	var visor := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.36, 0.1, 0.12)
	visor.mesh = vm
	visor.material_override = _flat(Color(0.05, 0.05, 0.07))
	visor.position = Vector3(0, 1.55, -0.26)
	_visual.add_child(visor)
	var hat := MeshInstance3D.new()
	match String(ch.hat):
		"box":
			var m := BoxMesh.new()
			m.size = Vector3(0.42, 0.18, 0.42)
			hat.mesh = m
			hat.position.y = 1.85
		"cone":
			var m := CylinderMesh.new()
			m.top_radius = 0.0
			m.bottom_radius = 0.28
			m.height = 0.4
			hat.mesh = m
			hat.position.y = 1.95
		"ball":
			var m := SphereMesh.new()
			m.radius = 0.22
			m.height = 0.44
			hat.mesh = m
			hat.position.y = 1.85
		"pack":
			var m := BoxMesh.new()
			m.size = Vector3(0.45, 0.6, 0.25)
			hat.mesh = m
			hat.position = Vector3(0, 1.15, 0.35)
		"tall":
			var m := CylinderMesh.new()
			m.top_radius = 0.16
			m.bottom_radius = 0.16
			m.height = 0.5
			hat.mesh = m
			hat.position.y = 2.0
	hat.material_override = _flat(col.darkened(0.35))
	_visual.add_child(hat)


func _true_form() -> void:
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.26
	cap.height = 2.25
	body.mesh = cap
	body.material_override = _flat(Color(0.04, 0.04, 0.05))
	body.position.y = 1.12
	_visual.add_child(body)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.045
		em.height = 0.09
		eye.mesh = em
		eye.material_override = _emissive(Color(1.0, 0.1, 0.05), 6.0)
		eye.position = Vector3(0.09 * side, 1.95, -0.22)
		_visual.add_child(eye)
		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.08, 1.3, 0.08)
		arm.mesh = am
		arm.material_override = _flat(Color(0.06, 0.05, 0.06))
		arm.position = Vector3(0.34 * side, 1.0, -0.1)
		arm.rotation.x = 0.35
		_visual.add_child(arm)


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


func _emissive(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m
