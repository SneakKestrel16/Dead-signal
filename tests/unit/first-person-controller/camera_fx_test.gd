# Story controller-interaction/013: client-only camera effects (ADR-0015 §5, first-person-controller.md
# rule 7, TR-controller-010): shake, jitter and jolt on a CameraFx node between the head and the Camera3D.
extends GdUnitTestSuite

const EPS := 0.0001
const STEP := 1.0 / 60.0
## Effect sizes are the caller's data; any small values serve here.
const SHAKE_DEG := 2.0
const SHAKE_M := 0.02
const SHAKE_S := 0.3
const JOLT := Vector2(3.0, -1.5)
const JOLT_S := 0.2


func _fx() -> CameraFx:
	return auto_free(CameraFx.new(1)) as CameraFx


## Runs `seconds` of frames; returns the largest rotation angle (degrees) and offset (metres) seen.
func _run(fx: CameraFx, seconds: float) -> Vector2:
	var most := Vector2.ZERO
	for i in roundi(seconds / STEP):
		fx.advance(STEP)
		most.x = maxf(most.x, rad_to_deg(Quaternion.from_euler(fx.rotation).get_angle()))
		most.y = maxf(most.y, fx.position.length())
	return most


func test_shake_stays_within_its_size_and_ends_at_rest() -> void:
	var fx := _fx()
	fx.shake(SHAKE_DEG, SHAKE_M, SHAKE_S)
	var most := _run(fx, SHAKE_S)
	assert_float(most.x).is_greater(0.0)
	assert_float(most.x).is_less_equal(SHAKE_DEG * sqrt(3.0) + EPS)
	assert_float(most.y).is_less_equal(SHAKE_M * sqrt(3.0) + EPS)
	fx.advance(STEP)
	assert_vector(fx.rotation).is_equal(Vector3.ZERO)
	assert_vector(fx.position).is_equal(Vector3.ZERO)


func test_jolt_kicks_at_once_and_decays_to_rest() -> void:
	var fx := _fx()
	fx.jolt(JOLT, JOLT_S)
	fx.advance(0.0)
	assert_float(fx.rotation.y).is_equal_approx(deg_to_rad(JOLT.x), EPS)
	assert_float(fx.rotation.x).is_equal_approx(deg_to_rad(JOLT.y), EPS)
	fx.advance(JOLT_S * 0.5)
	assert_float(fx.rotation.y).is_equal_approx(deg_to_rad(JOLT.x) * 0.5, EPS)
	fx.advance(JOLT_S)
	assert_vector(fx.rotation).is_equal(Vector3.ZERO)


func test_jitter_holds_its_size_until_it_ends() -> void:
	var fx := _fx()
	fx.jitter(SHAKE_DEG, SHAKE_S)
	_run(fx, SHAKE_S * 0.8)
	var late := _run(fx, SHAKE_S * 0.1) ## no decay: still near full size close to the end
	assert_float(late.x).is_greater(SHAKE_DEG * 0.1)
	_run(fx, SHAKE_S)
	assert_vector(fx.rotation).is_equal(Vector3.ZERO)


## The camera-impact shake setting off scales every effect to zero.
func test_disabled_setting_shows_nothing() -> void:
	var fx := _fx()
	fx.enabled = false
	fx.shake(SHAKE_DEG, SHAKE_M, SHAKE_S)
	fx.jolt(JOLT, JOLT_S)
	fx.jitter(SHAKE_DEG, SHAKE_S)
	assert_vector(_run(fx, SHAKE_S)).is_equal(Vector2.ZERO)


## AC 1: the effect moves the camera, while the yaw and pitch the sampler sends stay what the mouse made
## them; CameraFx has interpolation off (ADR-0015 §5) and is a plain child between head and camera.
func test_effects_move_the_camera_but_never_the_sampled_view() -> void:
	var li: LocalInput = auto_free(LocalInput.new())
	li.yaw = 0.3
	li.pitch = -0.2
	var head: Node3D = auto_free(Node3D.new())
	var fx := _fx()
	var cam := Camera3D.new()
	head.add_child(fx)
	fx.add_child(cam)
	add_child(head)
	head.rotation = Vector3(li.pitch, li.yaw, 0.0)
	var aim := -head.global_basis.z
	fx.jolt(JOLT, JOLT_S)
	fx.shake(SHAKE_DEG, SHAKE_M, SHAKE_S)
	fx.advance(STEP)
	assert_float((-cam.global_basis.z).angle_to(aim)).is_greater(0.0)
	var f := li.sample()
	assert_float(f.yaw).is_equal(0.3)
	assert_float(f.pitch).is_equal(-0.2)
	assert_vector(-head.global_basis.z).is_equal_approx(aim, Vector3.ONE * EPS)
	assert_int(fx.physics_interpolation_mode).is_equal(Node.PHYSICS_INTERPOLATION_MODE_OFF)
