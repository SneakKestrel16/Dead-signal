# Story network-authority/006: client server-tick estimate (ADR-0002 rule 7).
extends GdUnitTestSuite

var _knobs: Knobs


func before_test() -> void:
	_knobs = Knobs.load_all()


func _estimator() -> TickEstimator:
	return TickEstimator.new(_knobs.net.tick_estimate_rise_alpha, _knobs.net.tick_estimate_fall_alpha)


func test_no_estimate_until_first_snapshot() -> void:
	var e := _estimator()
	assert_bool(e.has_estimate()).is_false()
	e.observe(100, 106.0)
	assert_bool(e.has_estimate()).is_true()
	assert_float(e.estimated_server_tick(106.0)).is_equal(100.0)


func test_constant_delay_gives_constant_offset() -> void:
	var e := _estimator()
	for t in range(10, 200):
		e.observe(t, float(t) + 5.0)
	assert_float(e.offset_ticks()).is_equal_approx(5.0, 0.0001)


func test_delay_burst_barely_moves_the_estimate() -> void:
	var e := _estimator()
	for t in range(10, 100):
		e.observe(t, float(t) + 5.0)
	for t in range(100, 105): ## five snapshots arrive 10 ticks late
		e.observe(t, float(t) + 15.0)
	assert_float(e.offset_ticks()).is_less(5.0 + 10.0 * 5.0 * _knobs.net.tick_estimate_rise_alpha + 0.01)


func test_faster_path_pulls_the_estimate_down_quickly() -> void:
	var e := _estimator()
	for t in range(10, 100):
		e.observe(t, float(t) + 8.0)
	for t in range(100, 106): ## the path gets 4 ticks faster
		e.observe(t, float(t) + 4.0)
	assert_float(e.offset_ticks()).is_less(4.2)
