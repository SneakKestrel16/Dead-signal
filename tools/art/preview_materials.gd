extends SceneTree
## Renders one preview per assets/art/materials/mat_*.tres: a cube (triplanar
## materials) or a 0.7 m quad (UV-mapped), plus a sphere, in near-dark lit by a
## single warm-white spot (Bone Flashlight #F2E6C8, art bible §4). Windowed:
##   godot --path . --windowed --resolution 768x512 -s res://tools/art/preview_materials.gd
## Output: production/qa/evidence/environment-materials/NN-mat_*.png

const MAT := "res://assets/art/materials/"
const OUT := "res://production/qa/evidence/environment-materials/"
const SETTLE_FRAMES := 12

var _mats: PackedStringArray
var _idx := 0
var _frame := 0
var _cube := MeshInstance3D.new()
var _quad := MeshInstance3D.new()
var _sphere := MeshInstance3D.new()


func _initialize() -> void:
	for f in DirAccess.get_files_at(MAT):
		if f.ends_with(".tres"):
			_mats.append(f)
	var root := Node3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("14181a")  # Void Charcoal
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("14181a")
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 2.4)
	cam.fov = 40.0
	root.add_child(cam)
	var spot := SpotLight3D.new()
	spot.light_color = Color("f2e6c8")
	spot.spot_range = 14.0
	spot.spot_angle = 20.0  # ~40 degree cone
	spot.light_energy = 4.0  # matches the game flashlight (round_client.gd)
	spot.shadow_enabled = true
	spot.position = Vector3(0.1, -0.15, 2.3)
	root.add_child(spot)
	var wall := MeshInstance3D.new()  # concrete backdrop so alpha materials read
	var wm := PlaneMesh.new()
	wm.size = Vector2(8, 8)
	wm.orientation = PlaneMesh.FACE_Z
	wall.mesh = wm
	wall.position = Vector3(0, 0, -0.8)
	wall.material_override = load(MAT + "mat_concrete_a.tres")
	root.add_child(wall)
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.6
	_cube.mesh = box
	_cube.position = Vector3(-0.42, 0, 0)
	_cube.rotation_degrees = Vector3(25, 35, 0)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.7
	_quad.mesh = quad
	_quad.position = Vector3(-0.42, 0, 0)
	var sphere := SphereMesh.new()
	sphere.radius = 0.33
	sphere.height = 0.66
	_sphere.mesh = sphere
	_sphere.position = Vector3(0.42, 0, 0)
	for m in [_cube, _quad, _sphere]:
		root.add_child(m)
	get_root().add_child(root)
	DirAccess.make_dir_recursive_absolute(OUT)
	_show(0)


func _show(i: int) -> void:
	var m: BaseMaterial3D = load(MAT + _mats[i])
	_cube.visible = m.uv1_triplanar
	_quad.visible = not m.uv1_triplanar
	for mi: MeshInstance3D in [_cube, _quad, _sphere]:
		mi.material_override = m


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return false
	var img := get_root().get_texture().get_image()
	img.save_png("%s%02d-%s.png" % [OUT, _idx + 1, _mats[_idx].get_basename()])
	_idx += 1
	_frame = 0
	if _idx >= _mats.size():
		return true
	_show(_idx)
	return false
