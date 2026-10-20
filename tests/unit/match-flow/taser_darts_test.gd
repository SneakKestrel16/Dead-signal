# Taser darts and wires (ASSET-014; survivor-defense.md rule 8): where each own dart stops, the lower dart's
# spread, and one shot's fly, hang and reel-in back to hidden.
extends GdUnitTestSuite

const EYE := Vector3(0.0, 1.6, 0.0)
const AIM := Vector3(0.0, 0.0, -1.0)
const RANGE_M := 5.0
const RADIUS_M := 0.3
const HEIGHT_M := 1.8


func _no_wall(_from: Vector3, _to: Vector3) -> Dictionary:
	return {}


func _wall_at_3m(_from: Vector3, _to: Vector3) -> Dictionary:
	return {"position": Vector3(0.0, 1.6, -3.0)}


func test_end_of_with_nothing_in_the_way_is_the_range_end() -> void:
	var bodies: Array[Vector4] = []
	var end := TaserDarts.end_of(EYE, AIM, RANGE_M, _no_wall, bodies, RADIUS_M)
	assert_vector(end).is_equal_approx(EYE + AIM * RANGE_M, Vector3.ONE * 0.001)


func test_end_of_stops_at_the_wall_hit() -> void:
	var bodies: Array[Vector4] = []
	var end := TaserDarts.end_of(EYE, AIM, RANGE_M, _wall_at_3m, bodies, RADIUS_M)
	assert_vector(end).is_equal_approx(Vector3(0.0, 1.6, -3.0), Vector3.ONE * 0.001)


func test_end_of_stops_at_a_body_in_front_of_the_wall() -> void:
	var bodies: Array[Vector4] = [Vector4(0.0, 0.0, -2.0, HEIGHT_M)]
	var end := TaserDarts.end_of(EYE, AIM, RANGE_M, _wall_at_3m, bodies, RADIUS_M)
	assert_float(end.z).is_between(-2.0 + RADIUS_M - 0.1, -2.0 + RADIUS_M)


func test_end_of_passes_over_a_body_under_the_aim() -> void:
	var bodies: Array[Vector4] = [Vector4(0.0, 0.0, -2.0, 1.0)] # a crouched capsule, top at 1.0 m
	var end := TaserDarts.end_of(EYE, AIM, RANGE_M, _wall_at_3m, bodies, RADIUS_M)
	assert_float(end.z).is_equal_approx(-3.0, 0.001)


func test_lower_dart_leaves_spread_deg_under_the_aim() -> void:
	var dir := TaserDarts.lower(AIM, Vector3.RIGHT)
	assert_float(rad_to_deg(dir.angle_to(AIM))).is_equal_approx(TaserDarts.SPREAD_DEG, 0.01)
	assert_float(dir.y).is_less(0.0)


func test_shot_flies_hangs_and_reels_back_to_hidden() -> void:
	var taser: Node3D = auto_free(Node3D.new())
	add_child(taser)
	var darts := TaserDarts.new(taser)
	taser.add_child(darts)
	var ends: Array[Vector3] = [Vector3(0.0, 0.0, -2.0), Vector3(0.0, -0.3, -2.0)]

	darts.fire(ends)
	darts._process(TaserDarts.HANG_S * 0.5) # past the 0.04 s flight, mid-hang
	var stuck := darts.get_child(0) as Node3D
	assert_bool(stuck.visible).is_true()
	assert_vector(stuck.global_position).is_equal_approx(ends[0], Vector3.ONE * 0.001)
	darts._process(TaserDarts.HANG_S + TaserDarts.REEL_S)

	assert_bool(darts.active()).is_false()
	assert_bool(stuck.visible).is_false()
