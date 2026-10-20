class_name TaserDarts extends Node3D
## Taser darts and wires (ASSET-014, design/assets/specs/characters-assets.md: "a pair of small darts trailing
## thin bright wires to the target, which retract after the shot"; survivor-defense.md rule 8). On the own
## client's fire the pair leaves the taser's front, flies to where each dart's ray stops (end_of), hangs on its
## wires, then reels back into the taser. Presentation only, own client only: the server decides the hit with
## its aim tolerance, and other clients are sent nothing about a fire, so they draw no darts.
## A sibling of the taser, not its child: the taser hides once its last cartridge is spent, mid-flight.
## Usage (Viewmodel): `darts = TaserDarts.new(taser); add_child(darts)`, then `darts.fire(ends)`; it advances
## itself in _process.

const DART_SCENE := "res://assets/art/props/prop_taser_dart.glb"
## The taser's front plate in prop_taser.glb space (tools/art/build_viewmodel.py build_taser: front at -0.136 z,
## body centre 0.073 y); the top dart leaves above the bottom one.
const MUZZLES: Array[Vector3] = [Vector3(0.0, 0.085, -0.136), Vector3(0.0, 0.061, -0.136)]
## Inference (no GDD number): dart flight speed in m/s (real cartridge probes fly at about 50), then the hang and
## the reel-in in seconds. 0.1 + 0.6 + 0.25 s fits inside stun_item_reuse_s (1 s), so one shot shows at a time.
const SPEED_MPS := 50.0
const HANG_S := 0.6
const REEL_S := 0.25
## Inference: the lower dart leaves this many degrees under the aim, as a real cartridge's two probes spread.
const SPREAD_DEG := 8.0
const WIRE_COLOUR := Color(0.8, 0.9, 1.0)

## The held taser; the darts leave and return to its front.
var taser: Node3D
var _darts: Array[Node3D] = []
var _wire := ImmediateMesh.new()
var _wire_node := MeshInstance3D.new()
var _ends: Array[Vector3] = []
var _from: Array[Vector3] = []
## Seconds since the fire; < 0 = idle.
var _t := -1.0


func _init(held: Node3D) -> void:
	name = &"TaserDarts"
	taser = held
	var dart_material := StandardMaterial3D.new()
	dart_material.vertex_color_use_as_albedo = true
	dart_material.roughness = 0.4
	for i in MUZZLES.size():
		var d := (load(DART_SCENE) as PackedScene).instantiate() as Node3D
		d.top_level = true
		d.visible = false
		for g: Node in d.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).material_override = dart_material
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(d)
		_darts.append(d)
	var wire_material := StandardMaterial3D.new()
	wire_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wire_material.albedo_color = WIRE_COLOUR
	_wire_node.mesh = _wire
	_wire_node.material_override = wire_material
	_wire_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wire_node.top_level = true
	add_child(_wire_node)


## Where a dart fired from `eye` along `dir` stops: the first wall, glass or door from `ray` (Callable(from, to)
## -> Dictionary, PhysicsDirectSpaceState3D.intersect_ray's result), or the first of `bodies` (Vector4 feet x,
## y, z and capsule height; radius `radius_m`) it passes, at most `range_m` away.
static func end_of(eye: Vector3, dir: Vector3, range_m: float, ray: Callable, bodies: Array[Vector4],
		radius_m: float) -> Vector3:
	var end := eye + dir * range_m
	var hit: Dictionary = ray.call(eye, end)
	if not hit.is_empty():
		end = hit.position
	var length := eye.distance_to(end)
	var step := radius_m * 0.25
	var s := 0.0
	while s < length:
		var p := eye + dir * s
		for b in bodies:
			if Vector2(p.x - b.x, p.z - b.z).length() < radius_m and p.y >= b.y and p.y <= b.y + b.w:
				return p
		s += step
	return end


## The lower dart's direction: `dir` turned SPREAD_DEG down about the camera's `right` axis.
static func lower(dir: Vector3, right: Vector3) -> Vector3:
	return dir.rotated(right.normalized(), -deg_to_rad(SPREAD_DEG))


## Launches both darts toward `ends` (world points, top dart first); a shot still showing is replaced.
func fire(ends: Array[Vector3]) -> void:
	_ends = ends
	_from = []
	for i in _darts.size():
		_from.append(_muzzle(i))
		_darts[i].visible = true
		_darts[i].global_position = _from[i]
		if not _from[i].is_equal_approx(_ends[i]):
			_darts[i].look_at(_ends[i], _up(_from[i], _ends[i]))
	_t = 0.0


## Whether a shot is showing.
func active() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	_wire.clear_surfaces()
	var done := true
	_wire.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in _darts.size():
		var muzzle := _muzzle(i)
		var flight := _from[i].distance_to(_ends[i]) / SPEED_MPS
		var p: Vector3
		if _t < flight:
			p = _from[i].lerp(_ends[i], _t / flight)
		elif _t < flight + HANG_S:
			p = _ends[i]
		else:
			p = _ends[i].lerp(muzzle, minf((_t - flight - HANG_S) / REEL_S, 1.0))
		done = done and _t >= flight + HANG_S + REEL_S
		_darts[i].global_position = p
		_wire.surface_add_vertex(muzzle)
		_wire.surface_add_vertex(p)
	_wire.surface_end()
	if done:
		_t = -1.0
		_wire.clear_surfaces()
		for d in _darts:
			d.visible = false


func _muzzle(i: int) -> Vector3:
	return taser.global_transform * MUZZLES[i]


static func _up(from: Vector3, to: Vector3) -> Vector3:
	return Vector3.FORWARD if absf((to - from).normalized().y) > 0.99 else Vector3.UP
