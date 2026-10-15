class_name ShapeshifterAim extends Control
## The shapeshifter's ability input and S7 placement preview (story monster-abilities/011; monster-abilities.md
## rules 1, 4, 13, 17; design/ux/hud.md S7; interaction pattern P14; ADR-0014 §1-3). The lunge action sends a
## Lunge request; holding False Signal or Blackout shows the preview where the view ray lands and releasing
## sends the request at that aim. The client sends intent only: cooldowns, form and validity are the server's
## (MonsterAbilities). The preview only stops a release it already knows the server would reject (off the
## floor, out of range); P14: an invalid preview is crossed out and releasing on it sends nothing.
## Instanced by mount() on the first shapeshifter state, like ShapeshifterHud, so a survivor client holds no
## S7 node and sends no ability request; every send also needs HudModel.is_shapeshifter() and an input context
## that allows actions (a context pushed while aiming drops the aim).
## False Signal sends Footsteps walking along the view's horizontal direction, in the first face of S1. Choosing
## the callout or interaction type is not built (no selector in the HUD spec yet; a controls pass settles it).
## Inference: bindings (lunge right mouse, false_signal R, blackout X) are placeholders a controls pass settles.
## Usage (client composition root):
##   ShapeshifterAim.mount(hud_layer, hud_model, camera, contexts, multiplayer, map, knobs)

enum Kind { NONE, FALSE_SIGNAL, BLACKOUT }

const LUNGE_ACTION := &"lunge"
const FALSE_SIGNAL_ACTION := &"false_signal"
const BLACKOUT_ACTION := &"blackout"
## Greybox colours and sizes; no art direction source yet.
const COLOUR := Color(0.75, 0.3, 1.0)
const INVALID_COLOUR := Color(0.9, 0.2, 0.2)
const POINT_PX := 14.0
const CROSS_PX := 18.0

## `() -> Dictionary` {feet, point, dir}: the monster's feet, where the view ray lands and the view direction,
## or {} with no view. Default: a ray from the camera; tests inject one.
var aim_of: Callable
## The ability being aimed (Kind.NONE when none).
var aiming := Kind.NONE

var _model: HudModel
var _camera: Camera3D
var _contexts: InputContextStack
var _send: Callable
var _map: MapData
var _queries: MapQueries
var _knobs: Knobs
var _preview: Dictionary = {}


## Instances a ShapeshifterAim under `layer` the first time `model` reports shapeshifter state. Requests go
## to the server (peer 1) over `smp`, reliable.
static func mount(layer: CanvasLayer, model: HudModel, camera: Camera3D, contexts: InputContextStack,
		smp: SceneMultiplayer, map: MapData, knobs: Knobs) -> void:
	# WeakRefs for the RefCounted collaborators: the model's own signal holding them closes a cycle that leaks the
	# client's multiplayer on every survivor client, where the signal never fires (seen in
	# shapeshifter_hud_absence_test).
	model.monster_state_changed.connect(_spawn.bind(layer, weakref(model), camera, weakref(contexts), weakref(smp), map,
			knobs), CONNECT_ONE_SHOT)


static func _spawn(layer: CanvasLayer, model: WeakRef, camera: Camera3D, contexts: WeakRef,
		smp: WeakRef, map: MapData, knobs: Knobs) -> void:
	if not is_instance_valid(layer) or model.get_ref() == null or contexts.get_ref() == null:
		return
	var m := smp.get_ref() as SceneMultiplayer
	var send := m.send_bytes.bind(1, MultiplayerPeer.TRANSFER_MODE_RELIABLE) if m != null else Callable()
	layer.add_child(ShapeshifterAim.new(model.get_ref(), camera, contexts.get_ref(), send, map, knobs))


## `send.call(bytes)` delivers a request to the server.
func _init(model: HudModel, camera: Camera3D, contexts: InputContextStack, send: Callable, map: MapData,
		knobs: Knobs) -> void:
	_model = model
	_camera = camera
	_contexts = contexts
	_send = send
	_map = map
	_queries = MapQueries.new(map)
	_knobs = knobs
	aim_of = _camera_aim
	name = &"S7PlacementPreview"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Sends a Lunge request in any form (rule 4: the server checks lock, cooldown and state; a disguise is revealed). False when not allowed to send.
func lunge() -> bool:
	return _request(MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))


## Starts aiming `kind` (P14 hold). Ignored when not allowed to send.
func begin(kind: Kind) -> void:
	aiming = kind if _may_send() else Kind.NONE
	_preview = {}


## Drops the aim at no cost (P14 cancel).
func cancel() -> void:
	aiming = Kind.NONE
	_preview = {}
	queue_redraw()


## Ends the aim and sends its request when the preview is valid. True when a request was sent.
func release() -> bool:
	var kind := aiming
	var p := preview() if kind != Kind.NONE else {}
	cancel()
	if kind == Kind.NONE or not p["valid"]:
		return false
	if kind == Kind.BLACKOUT:
		return _request(MonsterAbilities.request_packet(MonsterAbilities.Ability.BLACKOUT, p["aim"]))
	var faces := _model.faces()
	var survivor: int = faces[0]["survivor"] if not faces.is_empty() else -1
	return _request(MonsterAbilities.signal_packet(MonsterAbilities.SignalType.FOOTSTEPS, p["aim"], survivor, p["dir"]))


## The S7 preview of the current aim: {kind, valid, aim, dir, point, end, volume, on_floor}. False Signal: `point`
## is the snapped floor point when `on_floor` (MapQueries.floor_point, the server's snap; else the raw aim), `end`
## the footstep path's end along the horizontal `dir` (walk_speed x the whole ticks of false_signal_footstep_duration_s, as the server runs it;
## not cut at walls, as the server's path is not yet). Blackout: `volume` is the lighting volume at the aim.
## `valid` mirrors the server's range and floor checks (rules 13, 17); blackout_able, an already dark zone and
## cooldowns are left to the server. Inference: range from the camera's feet (camera minus eye height), which
## the server measures from the body position; they differ only by a camera offset (CameraFx).
func preview() -> Dictionary:
	var a: Dictionary = aim_of.call()
	var out := {"kind": aiming, "valid": false, "aim": Vector3.ZERO, "dir": Vector3.ZERO, "point": Vector3.ZERO,
		"end": Vector3.ZERO, "volume": &"",
		"on_floor": false}
	if a.is_empty() or aiming == Kind.NONE:
		return out
	var feet: Vector3 = a["feet"]
	var aim: Vector3 = a["point"]
	var d: Vector3 = a["dir"]
	var dir := Vector3(d.x, 0.0, d.z).normalized()
	out["aim"] = aim
	out["dir"] = dir
	out["point"] = aim
	var dist := feet.distance_to(aim)
	if aiming == Kind.FALSE_SIGNAL:
		var snapped: Variant = _queries.floor_point(aim)
		if snapped != null:
			out["point"] = snapped
			out["on_floor"] = true
			var length := _knobs.controller.walk_speed * _knobs.ticks(_knobs.ability.false_signal_footstep_duration_s) \
					/ _knobs.net.sim_tick_hz
			out["end"] = (snapped as Vector3) + dir * length
		out["valid"] = snapped != null and not dir.is_zero_approx() \
				and dist <= _knobs.ability.false_signal_range_m + MonsterAbilities.HIT_EPS
	else:
		var zone := _queries.volume_at(aim)
		out["volume"] = zone
		out["valid"] = zone != &"" and (zone == _queries.volume_at(feet)
				or dist <= _knobs.ability.blackout_range_m + MonsterAbilities.HIT_EPS)
	return out


func _may_send() -> bool:
	return _model.is_shapeshifter() and _contexts.allows_actions() and _send.is_valid()


func _request(bytes: PackedByteArray) -> bool:
	if not _may_send():
		return false
	_send.call(bytes)
	return true


func _camera_aim() -> Dictionary:
	if _camera == null or not _camera.is_inside_tree():
		return {}
	var from := _camera.global_position
	var dir := -_camera.global_basis.z
	# Twice the longer range: a ray that hits nothing ends well out of range, so the preview reads invalid.
	var to := from + dir * 2.0 * maxf(_knobs.ability.false_signal_range_m, _knobs.ability.blackout_range_m)
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	return {"feet": from - Vector3.UP * _knobs.controller.eye_height_m,
		"point": hit["position"] if not hit.is_empty() else to, "dir": dir}


func _process(_delta: float) -> void:
	if aiming != Kind.NONE and not _contexts.allows_actions():
		cancel() # ADR-0014 §1: a pushed context drops the aim
	if not _contexts.allows_actions():
		return
	if Input.is_action_just_pressed(LUNGE_ACTION):
		lunge()
	for pair: Array in [[FALSE_SIGNAL_ACTION, Kind.FALSE_SIGNAL], [BLACKOUT_ACTION, Kind.BLACKOUT]]:
		if Input.is_action_just_pressed(pair[0]):
			begin(pair[1])
		elif aiming == pair[1] and Input.is_action_just_released(pair[0]):
			release()
	if aiming != Kind.NONE:
		_preview = preview()
		queue_redraw()


func _draw() -> void:
	if aiming == Kind.NONE or _preview.is_empty() or _camera == null or not _camera.is_inside_tree():
		return
	var c := COLOUR if _preview["valid"] else INVALID_COLOUR
	if aiming == Kind.FALSE_SIGNAL:
		if _preview["on_floor"]:
			_line(_preview["point"], _preview["end"], c)
		_dot(_preview["point"], c)
	else:
		for v in _map.volumes:
			if v.id == _preview["volume"]:
				var b := v.box
				var y := b.position.y
				var corners := [Vector3(b.position.x, y, b.position.z), Vector3(b.end.x, y, b.position.z),
					Vector3(b.end.x, y, b.end.z), Vector3(b.position.x, y, b.end.z)]
				for i in 4:
					_line(corners[i], corners[(i + 1) % 4], c)
	if not _preview["valid"] and not _camera.is_position_behind(_preview["aim"]):
		var at := _camera.unproject_position(_preview["aim"])
		draw_line(at - Vector2.ONE * CROSS_PX, at + Vector2.ONE * CROSS_PX, c, 4.0)
		draw_line(at + Vector2(-CROSS_PX, CROSS_PX), at + Vector2(CROSS_PX, -CROSS_PX), c, 4.0)


func _dot(p: Vector3, c: Color) -> void:
	if not _camera.is_position_behind(p):
		draw_arc(_camera.unproject_position(p), POINT_PX, 0.0, TAU, 24, c, 3.0)


## A world segment, clipped at the camera's near plane (a Blackout volume the monster stands in has corners
## behind it).
func _line(a: Vector3, b: Vector3, c: Color) -> void:
	var eye := _camera.global_position
	var fwd := -_camera.global_basis.z
	var near := _camera.near * 2.0
	var da := (a - eye).dot(fwd) - near
	var db := (b - eye).dot(fwd) - near
	if da < 0.0 and db < 0.0:
		return
	if da < 0.0:
		a = a.lerp(b, da / (da - db))
	elif db < 0.0:
		b = b.lerp(a, db / (db - da))
	draw_line(_camera.unproject_position(a), _camera.unproject_position(b), c, 3.0)
