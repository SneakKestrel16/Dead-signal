# Story controller-interaction/003: the per-owner speed modifier set (first-person-controller.md rule 6,
# Formulas effective_speed: lock > root > lowest slow, never a product).
extends GdUnitTestSuite

const TRUE_FORM_SPRINT := 5.75 ## GDD effective_speed example: 5.0 × monster_sprint_mult 1.15
const EPS := 1e-6


func _mods() -> MovementModifiers:
	return MovementModifiers.new()


func test_one_slow_halves_a_true_form_sprint() -> void:
	var m := _mods()
	m.add(&"taser", MovementModifiers.Kind.SLOW, 0.5)
	assert_float(m.effective(TRUE_FORM_SPRINT)).is_equal_approx(2.875, EPS)


func test_two_slows_take_the_lowest_not_the_product() -> void:
	var m := _mods()
	m.add(&"taser", MovementModifiers.Kind.SLOW, 0.5)
	m.add(&"miss", MovementModifiers.Kind.SLOW, 0.7)
	assert_float(m.effective(TRUE_FORM_SPRINT)).is_equal_approx(2.875, EPS) # not 2.0125


func test_root_gives_zero() -> void:
	var m := _mods()
	m.add(&"windup", MovementModifiers.Kind.ROOT)
	assert_float(m.effective(TRUE_FORM_SPRINT)).is_equal(0.0)
	assert_bool(m.rooted).is_true()
	assert_bool(m.locked).is_false()


func test_lock_and_slow_give_zero_and_block_look() -> void:
	var m := _mods()
	m.add(&"taser", MovementModifiers.Kind.SLOW, 0.5)
	m.add(&"seized", MovementModifiers.Kind.LOCK)
	assert_float(m.effective(TRUE_FORM_SPRINT)).is_equal(0.0)
	assert_bool(m.locked).is_true()
	assert_float(m.effective_scale()).is_equal(0.0)


## AC2: the gait comes from the held input every tick, so removing the last modifier restores the
## full sprint target on the next tick with no re-press. (The body then reaches it within
## accel_time_s; movement_step_test covers that ramp after a root.)
func test_removing_the_last_modifier_restores_sprint_with_no_re_press() -> void:
	var k := Knobs.load_all()
	var state := MovementStep.MoveState.new()
	state.true_form = true
	var f := InputFrame.new()
	f.move = Vector2(0.0, 1.0)
	f.sprint = true
	state.modifiers.add(&"taser", MovementModifiers.Kind.SLOW, 0.5)
	var base := MovementStep.gait_speed(MovementStep.gait(f, state), state, k)
	assert_float(base).is_equal_approx(TRUE_FORM_SPRINT, EPS)
	assert_float(state.modifiers.effective(base)).is_equal_approx(2.875, EPS)
	state.modifiers.remove(&"taser")
	base = MovementStep.gait_speed(MovementStep.gait(f, state), state, k)
	assert_float(state.modifiers.effective(base)).is_equal_approx(TRUE_FORM_SPRINT, EPS)
	assert_float(state.modifiers.effective_scale()).is_equal(1.0)


func test_removing_one_owner_leaves_the_others() -> void:
	var m := _mods()
	m.add(&"a", MovementModifiers.Kind.ROOT)
	m.add(&"b", MovementModifiers.Kind.SLOW, 0.5)
	m.remove(&"a")
	assert_bool(m.rooted).is_false()
	assert_float(m.effective(TRUE_FORM_SPRINT)).is_equal_approx(2.875, EPS)


func test_removing_a_never_added_owner_changes_nothing() -> void:
	var m := _mods()
	m.add(&"a", MovementModifiers.Kind.SLOW, 0.5)
	m.remove(&"nobody")
	assert_float(m.effective(TRUE_FORM_SPRINT)).is_equal_approx(2.875, EPS)


## The GDD is silent on a repeat add; rule: an owner holds one entry, so a second add replaces it.
func test_same_owner_adding_twice_replaces_not_stacks() -> void:
	var m := _mods()
	m.add(&"taser", MovementModifiers.Kind.ROOT)
	m.add(&"taser", MovementModifiers.Kind.SLOW, 0.5)
	assert_bool(m.rooted).is_false()
	assert_float(m.effective(TRUE_FORM_SPRINT)).is_equal_approx(2.875, EPS)


## GDD Output Range: never negative or above the gait speed, because each slow is clamped to 0-1.
func test_slow_outside_0_1_is_clamped() -> void:
	var m := _mods()
	m.add(&"bad", MovementModifiers.Kind.SLOW, 1.5)
	assert_float(m.effective(TRUE_FORM_SPRINT)).is_equal_approx(TRUE_FORM_SPRINT, EPS)
	m.add(&"bad", MovementModifiers.Kind.SLOW, -0.5)
	assert_float(m.effective(TRUE_FORM_SPRINT)).is_equal(0.0)


func test_lock_and_root_together_give_zero_and_keep_both_flags() -> void:
	var m := _mods()
	m.add(&"seized", MovementModifiers.Kind.LOCK)
	m.add(&"rescue", MovementModifiers.Kind.ROOT)
	assert_bool(m.locked and m.rooted).is_true()
	m.remove(&"rescue")
	assert_bool(m.locked).is_true()
	assert_float(m.effective(TRUE_FORM_SPRINT)).is_equal(0.0)


func test_same_owner_replacing_a_slow_uses_the_new_value() -> void:
	var m := _mods()
	m.add(&"taser", MovementModifiers.Kind.SLOW, 0.5)
	m.add(&"taser", MovementModifiers.Kind.SLOW, 0.7)
	assert_float(m.effective(TRUE_FORM_SPRINT)).is_equal_approx(4.025, EPS)


## Code review 2026-10-14: clampf does not clean NaN, and minf carried it into the velocity.
func test_nan_slow_is_ignored() -> void:
	var m := _mods()
	m.add(&"bad", MovementModifiers.Kind.SLOW, NAN)
	assert_float(m.effective(TRUE_FORM_SPRINT)).is_equal_approx(TRUE_FORM_SPRINT, EPS)


## Code review 2026-10-14: set_from_scale wrote the derived fields but left the set, so a later
## add/remove rebuilt from the stale set and dropped the snapshot's slow.
func test_snapshot_scale_survives_a_later_add_or_remove() -> void:
	var m := _mods()
	m.set_from_scale(0.5)
	assert_float(m.effective(TRUE_FORM_SPRINT)).is_equal_approx(2.875, EPS)
	m.remove(&"nobody")
	m.add(&"x", MovementModifiers.Kind.SLOW, 0.8)
	assert_float(m.effective(TRUE_FORM_SPRINT)).is_equal_approx(2.875, EPS)
	m.set_from_scale(0.0)
	assert_bool(m.rooted).is_true()
	m.set_from_scale(1.0)
	assert_bool(m.rooted).is_false()
	assert_float(m.effective_scale()).is_equal(1.0)


## Code review 2026-10-14: a NaN or above-1 snapshot scale gave a NaN or faster-than-gait speed.
func test_snapshot_scale_is_clamped_and_nan_is_full_speed() -> void:
	var m := _mods()
	m.set_from_scale(5.0)
	assert_float(m.effective_scale()).is_equal(1.0)
	m.set_from_scale(NAN)
	assert_float(m.effective_scale()).is_equal(1.0)
