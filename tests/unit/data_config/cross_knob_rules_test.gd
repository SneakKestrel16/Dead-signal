# Story data-config/003: cross-knob rules (per section and spanning sections).
extends GdUnitTestSuite

## Shipped values (data/knobs/*.tres) the rules are built around; each test moves one value off them.
const TOLERANCE_M := 0.25
const INTERACT_RANGE_M := 2.0
const MAX_REWIND_MS := 180
const INTERP_DELAY_MS := 50
const TICK_HZ := 60
const WINDUP_S := 0.6

const RULE_SOURCES: PackedStringArray = ["res://src/foundation/data_config/knobs.gd"]


## A Knobs holding only the sections Knobs.validate_cross reads, at the shipped values.
func _knobs() -> Knobs:
	var k := Knobs.new()
	k.controller = ControllerKnobs.new()
	k.controller.hold_range_tolerance_m = TOLERANCE_M
	k.objectives = ObjectivesKnobs.new()
	k.objectives.interact_range_m = INTERACT_RANGE_M
	k.ability = AbilityKnobs.new()
	k.ability.max_rewind_ms = MAX_REWIND_MS
	k.ability.lunge_windup_s = WINDUP_S
	k.net = NetKnobs.new()
	k.net.interp_delay_ms = INTERP_DELAY_MS
	k.net.sim_tick_hz = TICK_HZ
	return k


func _net() -> NetKnobs:
	var n := NetKnobs.new()
	n.starvation_low = 0.02
	n.starvation_high = 0.10
	n.correction_deadzone_m = 0.005
	n.correction_smooth_max_m = 1.0
	return n


func _scare(budget: Array) -> ScareKnobs:
	var s := ScareKnobs.new()
	s.phase_budget = PackedInt32Array(budget)
	return s


func test_shipped_values_pass_every_cross_rule() -> void:
	assert_array(_knobs().validate_cross()).is_empty()
	assert_array(_net().validate_cross()).is_empty()
	assert_array(_scare([2, 6, 4]).validate_cross()).is_empty()


func test_hold_tolerance_at_or_above_interact_range_is_named_error_citing_adr_0008() -> void:
	var k := _knobs()
	k.controller.hold_range_tolerance_m = INTERACT_RANGE_M ## equal is broken: the rule is strict
	var errs := k.validate_cross()
	assert_int(errs.size()).is_equal(1)
	assert_str(errs[0]).contains("controller.hold_range_tolerance_m").contains("ADR-0008")
	k.objectives.interact_range_m = INTERACT_RANGE_M + 0.001
	assert_array(k.validate_cross()).is_empty()


func test_rewind_not_covering_interpolation_plus_tick_is_named_error_citing_adr_0003() -> void:
	var k := _knobs()
	k.ability.max_rewind_ms = INTERP_DELAY_MS + 16 ## one tick at 60 Hz is 16.7 ms
	var errs := k.validate_cross()
	assert_int(errs.size()).is_equal(1)
	assert_str(errs[0]).contains("ability.max_rewind_ms").contains("net.interp_delay_ms").contains("ADR-0003")
	k.ability.max_rewind_ms = INTERP_DELAY_MS + 17 ## just above the boundary
	assert_array(k.validate_cross()).is_empty()


func test_reaction_reaching_windup_breaks_dodge_budget_citing_adr_0003() -> void:
	var k := _knobs()
	k.ability.lunge_windup_s = 0.43 ## 0.25 s + 180 ms: equal is broken
	var errs := k.validate_cross()
	assert_int(errs.size()).is_equal(1)
	assert_str(errs[0]).contains("dodge budget").contains("ability.lunge_windup_s").contains("ADR-0003")
	k.ability.lunge_windup_s = 0.44
	assert_array(k.validate_cross()).is_empty()


func test_two_broken_rules_give_two_errors() -> void:
	var k := _knobs()
	k.controller.hold_range_tolerance_m = 3.0
	k.ability.lunge_windup_s = 0.4
	assert_int(k.validate_cross().size()).is_equal(2)


func test_net_section_rules() -> void:
	var n := _net()
	n.starvation_low = n.starvation_high
	n.correction_deadzone_m = n.correction_smooth_max_m
	var errs := n.validate_cross()
	assert_int(errs.size()).is_equal(2)
	assert_str(errs[0]).contains("net.starvation_low").contains("ADR-0002")
	assert_str(errs[1]).contains("net.correction_deadzone_m").contains("ADR-0002")


func test_scare_phase_budget_needs_three_entries_each_0_to_12() -> void:
	assert_array(_scare([2, 6]).validate_cross()).contains_exactly(
		["scare.phase_budget has 2 entries, needs 3 (Low/Rising/Emergency, scare-events.md)"])
	assert_array(_scare([0, 12, 13]).validate_cross()).contains_exactly(
		["scare.phase_budget[2] = 13 outside range [0, 12] (scare-events.md)"])
	assert_array(_scare([0, 12, 0]).validate_cross()).is_empty()


## Reads the shipped files: errors() is the only way to check that an unset knob suppresses the cross
## rules that read it (ADR-0006 allows one file-loading test per suite).
func test_unset_knob_reports_unset_not_a_cross_error() -> void:
	var k := Knobs.load_all()
	assert_array(k.errors()).is_empty()
	# An unset int is a large negative sentinel, so the ADR-0003 rewind rule would fire on it if it ran
	# (a NaN float cannot show this: every comparison with NaN is false).
	k.ability.max_rewind_ms = KnobUnset.INT
	var errs := k.errors()
	assert_bool(errs.has("ability.max_rewind_ms unset")).is_true()
	for e in errs:
		assert_str(e).not_contains("ADR-0003")


func test_shipped_files_break_a_cross_rule_through_errors() -> void:
	var k := Knobs.load_all()
	k.ability.lunge_windup_s = 0.43
	assert_bool(" ".join(k.errors()).contains("dodge budget")).is_true()


## Every errs.append in a validate_cross body has a "# Source:" comment since the previous append.
func test_every_cross_check_has_a_source_comment() -> void:
	var paths := RULE_SOURCES.duplicate()
	for name in Knobs.SECTIONS:
		paths.append("res://src/foundation/data_config/%s_knobs.gd" % name)
	var checked := 0
	for path in paths:
		var src := FileAccess.get_file_as_string(path)
		var at := src.find("func validate_cross()")
		assert_int(at).override_failure_message("%s has no validate_cross" % path).is_not_equal(-1)
		var body := src.substr(at)
		var next := body.find("\nfunc ", 1)
		if next != -1:
			body = body.substr(0, next)
		var cited := false
		for line in body.split("\n"):
			var t := line.strip_edges()
			if t.begins_with("# Source:"):
				cited = true
			elif t.contains("errs.append("):
				assert_bool(cited).override_failure_message("%s: check without a source comment: %s" % [path, t]).is_true()
				cited = false
				checked += 1
	assert_int(checked).is_equal(7) ## 3 spanning + 2 net + 2 scare: a new check must update this
