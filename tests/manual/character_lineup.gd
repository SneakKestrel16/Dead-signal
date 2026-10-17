extends Node3D
## Character art line-up (ASSET-001..010 evidence): BodyVisual's looks 1-5, a second look 3 (what a disguise
## copying C3 draws) and the true form (0), side by side in a dim room under one flashlight-like spot each.
##   <godot> --path <repo> --write-movie <tmp>.avi res://tests/manual/character_lineup.tscn -- [--shot=<png>]
##       [--anim=Idle] [--turn=0] [--dist=4.5] [--frame=60] [--dark]
## --turn rotates every body (degrees; 180 shows the backs), --dist is the camera distance (m), --anim the clip
## every body plays, --dark drops the ambient to near black (the flashlight spots alone). Saves --shot at drawn frame --frame, then quits. No input, no network.
## --true=<glb>,<glb>,... (true-form review, tools/art/build_characters.py --true-options): C3, the shipped true
## form, then one true form per glb instead of the line-up above.

const ORDER: Array[int] = [1, 2, 3, 3, 4, 5, 0]
const SPACING_M := 1.25

var _args := {}
var _frame := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var visuals := BodyVisual.new()
	var turn := deg_to_rad(float(_args.get("turn", "0")))
	var anim := StringName(_args.get("anim", "Idle"))
	var order := ORDER
	var glbs := [""]
	if _args.has("true"):
		order = [3, 0]
		for g in String(_args["true"]).split(","):
			order.append(0)
			glbs.append(g)
	for i in order.size():
		var x := (i - (order.size() - 1) / 2.0) * SPACING_M
		var k := i - (order.size() - glbs.size())
		visuals._scenes[BodyVisual.TRUE_FORM_SCENE] = load(glbs[k] if k > 0 else BodyVisual.TRUE_FORM_SCENE)
		var body := visuals.build(order[i])
		body.position = Vector3(x, 0, 0)
		body.rotation.y += turn + PI # yaw PI faces +Z, toward the camera
		add_child(body)
		(body.find_child("AnimationPlayer", true, false) as AnimationPlayer).play(anim)
		var spot := SpotLight3D.new()
		spot.position = Vector3(x, 1.6, 3.0)
		spot.look_at_from_position(spot.position, Vector3(x, 1.1, 0), Vector3.UP)
		spot.spot_angle = 22.0
		spot.light_energy = 6.0
		spot.light_color = Color("#F2E6C8") # Bone Flashlight (art bible §4)
		spot.shadow_enabled = true
		add_child(spot)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 8)
	floor_mi.mesh = plane
	add_child(floor_mi)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(14, 4, 0.2)
	wall.mesh = box
	wall.position = Vector3(0, 2, -2.5)
	add_child(wall)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.02, 0.025)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.25, 0.25, 0.3)
	env.environment.ambient_light_energy = 0.05 if _args.has("dark") else 0.6
	add_child(env)
	var cam := Camera3D.new()
	var dist := float(_args.get("dist", "4.5"))
	cam.position = Vector3(0, 1.4, dist)
	cam.fov = 2.0 * rad_to_deg(atan((order.size() * SPACING_M * 0.55) / dist)) * 0.6
	add_child(cam)
	cam.look_at(Vector3(0, 1.1, 0))
	cam.make_current()


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == int(_args.get("frame", "60")):
		if _args.has("shot"):
			get_viewport().get_texture().get_image().save_png(_args["shot"])
			print("SHOT ", _args["shot"])
		get_tree().quit()
