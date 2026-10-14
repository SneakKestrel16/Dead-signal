extends Node3D
## Manual check for controller story 006 (needs a person; cannot run headless):
## 1. Run this scene: `godot res://tests/manual/mouse_look_check.tscn`. Note the mouse travel that
##    turns the view 90° from the red pillar to the green one.
## 2. Press F11 to halve the window (or drag it to half size), repeat: the same travel turns 90°.
## 3. Alt-tab away and back: the mouse is captured again without a click.
## The label shows yaw and pitch in degrees and the window size. Esc releases the mouse.

var _input: LocalInput
var _camera: Camera3D
var _label: Label


func _ready() -> void:
	_input = LocalInput.new()
	add_child(_input)
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 1.6, 0)
	add_child(_camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	add_child(light)
	_pillar(Vector3(0, 1, -6), Color.RED) ## yaw 0
	_pillar(Vector3(-6, 1, 0), Color.GREEN) ## yaw +90 (turned left) ...
	_pillar(Vector3(6, 1, 0), Color.BLUE) ## ... or -90 (turned right)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE ## a STOP filter would eat captured motion (gotchas.md)
	add_child(_label)


func _pillar(pos: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	m.mesh = BoxMesh.new()
	m.mesh.size = Vector3(0.5, 2, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	m.position = pos
	add_child(m)


func _process(_delta: float) -> void:
	_camera.basis = Basis(Vector3.UP, _input.yaw) * Basis(Vector3.RIGHT, _input.pitch)
	_label.text = "yaw %.1f°  pitch %.1f°  window %s" % [rad_to_deg(_input.yaw), rad_to_deg(_input.pitch), get_window().size]


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif key != null and key.pressed and key.physical_keycode == KEY_F11:
		get_window().size = get_window().size / 2
