class_name CameraFx extends Node3D
## Client-only camera reactions (ADR-0015 §5; first-person-controller.md rule 7, TR-controller-010; story
## controller-interaction/013): the scare camera reaction and the downing impact (shake), the shocked
## survivor's jitter and the stun or hit jolt (survivor-defense.md, downing-and-rescue.md presentation
## tables). It sits between the head and the Camera3D and only moves itself: the yaw and pitch LocalInput
## samples, and so the server view direction and every aim ray, never see it.
## Physics interpolation is off here (and must be on the head and Camera3D too): the node is written every
## rendered frame. Effect sizes and durations are the caller's data (presentation entries, ScareCatalog);
## the GDDs give durations (shake 300 ms, jolt 200 ms) but no amplitudes, so none live here.
## A new effect of a kind replaces the running one of that kind; the kinds add up.
## Usage:
##   var fx := CameraFx.new(); head.add_child(fx); fx.add_child(camera)
##   fx.enabled = settings.camera_impact_shake
##   fx.jolt(Vector2(3.0, -1.5), 0.2)   # yaw, pitch degrees; decays to rest over 0.2 s

## The player's camera-impact shake setting (accessibility-requirements.md Reduced motion): false scales
## every effect to zero.
var enabled := true

var _rng := RandomNumberGenerator.new()
## [size, seconds left, seconds total] per kind; the shake size is Vector2(rot_deg, pos_m).
var _shake: Array = [Vector2.ZERO, 0.0, 0.0]
var _jitter: Array = [0.0, 0.0, 0.0]
var _jolt: Array = [Vector2.ZERO, 0.0, 0.0]


## `seed_`: the noise seed (tests pass a fixed one; 0 = randomised).
func _init(seed_: int = 0) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if seed_ == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_


## Random rotation up to `rot_deg` per axis and offset up to `pos_m` per axis, fading to rest over
## `duration_s`.
func shake(rot_deg: float, pos_m: float, duration_s: float) -> void:
	_shake = [Vector2(rot_deg, pos_m), duration_s, duration_s]


## Random rotation up to `rot_deg` per axis at full size for `duration_s`, then rest.
func jitter(rot_deg: float, duration_s: float) -> void:
	_jitter = [rot_deg, duration_s, duration_s]


## A kick of `kick_deg` (x yaw, y pitch, degrees) at once, back to rest linearly over `duration_s`.
func jolt(kick_deg: Vector2, duration_s: float) -> void:
	_jolt = [kick_deg, duration_s, duration_s]


## Advances the effects by `delta` seconds and writes this node's rotation and position.
func advance(delta: float) -> void:
	var rot := Vector3.ZERO
	var pos := Vector3.ZERO
	var s := _left(_shake, delta)
	if s > 0.0:
		rot += _noise() * deg_to_rad(_shake[0].x) * s
		pos += _noise() * _shake[0].y * s
	if _left(_jitter, delta) > 0.0:
		rot += _noise() * deg_to_rad(_jitter[0])
	var j := _left(_jolt, delta)
	if j > 0.0:
		rot += Vector3(deg_to_rad(_jolt[0].y), deg_to_rad(_jolt[0].x), 0.0) * j
	rotation = rot if enabled else Vector3.ZERO
	position = pos if enabled else Vector3.ZERO


func _process(delta: float) -> void:
	advance(delta)


## Counts the effect down and returns the fraction of it left (0 when over or never started).
func _left(effect: Array, delta: float) -> float:
	effect[1] = maxf(effect[1] - delta, 0.0)
	return effect[1] / effect[2] if effect[2] > 0.0 else 0.0


func _noise() -> Vector3:
	return Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
