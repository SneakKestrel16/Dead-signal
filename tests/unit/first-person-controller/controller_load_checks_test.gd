# Story controller-interaction/005: controller load-time checks (first-person-controller.md Formulas:
# Gait speed joint cap, catch_gap, interact_ray_max). Sections are built with .new() at the shipped
# values (TestControllerKnobs); each test moves one value off them.
extends GdUnitTestSuite

func _knobs() -> Knobs:
	var k := Knobs.new()
	k.net = NetKnobs.new()
	k.net.sim_tick_hz = 60
	k.net.interp_delay_ms = 50
	TestControllerKnobs.set_shipped(k)
	k.ability.max_rewind_ms = 180
	k.controller.hold_range_tolerance_m = 0.25
	return k


## Every error both validators report (controller section rules, then cross-section rules).
func _errors(k: Knobs) -> PackedStringArray:
	var errs := k.controller.validate_cross()
	errs.append_array(k.validate_cross())
	return errs


func test_shipped_values_pass_all_three_checks() -> void:
	assert_array(_errors(_knobs())).is_empty()


# --- AC1: joint sprint cap ------------------------------------------------------

func test_walk_4_5_with_sprint_1_25_fails_naming_the_joint_cap() -> void:
	var k := _knobs()
	k.controller.walk_speed = 4.5 ## 5.625 m/s
	var errs := k.controller.validate_cross()
	assert_int(errs.size()).is_equal(1)
	assert_str(errs[0]).contains("joint sprint cap").contains("max_survivor_sprint_mps")


func test_monster_sprint_mult_1_fails_naming_the_joint_cap() -> void:
	var k := _knobs()
	k.controller.monster_sprint_mult = 1.0
	var errs := k.controller.validate_cross()
	assert_int(errs.size()).is_equal(1)
	assert_str(errs[0]).contains("joint sprint cap").contains("monster_sprint_mult")


func test_4_0_times_1_35_on_the_cap_passes_within_epsilon() -> void:
	var k := _knobs()
	k.controller.sprint_mult = 1.35 ## 5.4 (float product 5.4000000000000004)
	assert_array(k.controller.validate_cross()).is_empty()
	k.controller.sprint_mult = 1.35 + 0.0001 / 4.0 + 1e-6 ## just past the 1e-4 m/s epsilon
	assert_int(k.controller.validate_cross().size()).is_equal(1)


# --- AC2: catch_gap -------------------------------------------------------------

func test_radius_0_35_at_sprint_5_4_fails_catch_gap() -> void:
	var k := _knobs()
	k.controller.sprint_mult = 1.35
	assert_array(k.validate_cross()).is_empty() ## r 0.3: catch_gap 0.64 >= 0.6
	k.controller.player_radius_m = 0.35 ## catch_gap 0.69 < 0.70
	var errs := k.validate_cross()
	assert_int(errs.size()).is_equal(1)
	assert_str(errs[0]).contains("catch_gap").contains("player_radius_m")


func test_catch_gap_exactly_on_the_limit_passes() -> void:
	var k := _knobs()
	k.ability.lunge_distance_m = 3.4
	k.ability.lunge_hit_radius_m = 1.0 ## catch_gap = 3.4 + 1.0 + 0.3 - 5.0 x 0.9 = 0.2: below 0.6, fails
	assert_int(k.validate_cross().size()).is_equal(1)
	k.ability.lunge_distance_m = 3.8 ## 3.8 + 1.0 + 0.3 - 4.5 = 0.6: exactly 2 x radius, passes
	assert_array(k.validate_cross()).is_empty()


# --- AC3: interaction ray reach -------------------------------------------------

func test_ray_short_of_standing_reach_fails() -> void:
	var k := _knobs()
	k.controller.interact_ray_max_m = 2.69 ## standing needs 2.0 + (1.6 - 0.9) = 2.7
	var errs := k.validate_cross()
	assert_int(errs.size()).is_equal(1)
	assert_str(errs[0]).contains("interact_ray_max_m").contains("standing")
	k.controller.interact_ray_max_m = 2.7 ## exactly on the limit
	assert_array(k.validate_cross()).is_empty()


func test_ray_short_of_crouched_reach_fails() -> void:
	var k := _knobs()
	k.controller.interact_ray_max_m = 2.7
	k.controller.eye_low_height_m = 1.0
	k.controller.capsule_low_height_m = 0.4 ## crouched: 2.0 + (1.0 - 0.2) = 2.8 > 2.7
	var errs := k.validate_cross()
	assert_int(errs.size()).is_equal(1)
	assert_str(errs[0]).contains("crouched")


func test_max_owner_range_is_read_from_every_owner_section() -> void:
	for owner: Array in [["objectives", "interact_range_m"], ["downing", "rescue_range_m"], ["ability", "backup_switch_range_m"]]:
		var k := _knobs()
		(k.get(owner[0]) as Resource).set(owner[1], 2.31) ## 2.31 + 0.7 = 3.01 > 3.0
		var errs := k.validate_cross()
		assert_int(errs.size()).override_failure_message("%s.%s" % owner).is_equal(1)
		assert_str(errs[0]).contains("interact_ray_max_m")


func test_shipped_knob_files_pass_every_check() -> void:
	var k := Knobs.load_all()
	assert_array(k.errors()).is_empty()
	assert_float(k.controller.eye_height_m).is_equal(TestControllerKnobs.EYE)
	assert_float(k.controller.eye_low_height_m).is_equal(TestControllerKnobs.EYE_LOW)
