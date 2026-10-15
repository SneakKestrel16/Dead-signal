# Story survivor-defense/012 AC-3 (design/gdd/survivor-defense.md acceptance 20; ADR-0006): every
# Survivor Defense tuning knob is loaded from data. The module sources hold no numeric literal equal to a
# shipped DefenseKnobs value, and a knob changed in data changes behaviour.
extends GdUnitTestSuite

const SRC_DIR := "res://src/feature/survivor_defense/"
## Literals that equal a knob value but are not one: [file, line text]. Each needs its reason.
const NOT_KNOBS: Array = [
	["barricades.gd", "Vector3(c.x, c.y + c.w / 2.0, c.z)"], # half the capsule height (Doors' capsule format)
	["survivor_defense.gd", "const LIGHT_ON := 2"], # intent enum values, not tuning
	["survivor_defense.gd", "const LIGHT_OFF := 3"],
	["survivor_defense.gd", "range_m * 2.0 + 1.0"], # trace end point past the range, not a knob
]
## 0 and 1 are structural (indexes, increments, identity multipliers): a knob shipping at either is not
## told apart by a literal scan, so test_changed_knob_changes_behaviour covers those by behaviour.
const STRUCTURAL: Array[float] = [0.0, 1.0]

var _knobs: Knobs


func before_test() -> void:
	_knobs = Knobs.load_all()


## AC-3: no file of the module carries a literal equal to a DefenseKnobs value (allow-list aside).
func test_no_knob_literals_in_module() -> void:
	var found: Array[String] = []
	for f in DirAccess.get_files_at(SRC_DIR):
		if f.ends_with(".gd"):
			found.append_array(_knob_literals(f, FileAccess.get_file_as_string(SRC_DIR + f)))
	assert_array(found).override_failure_message("\n".join(found)).is_empty()


## AC-3 edge: the scan catches a knob value, and ignores comments and strings.
func test_knob_literal_scan_catches_literals() -> void:
	for line in ["var c := 2", "x = 30.0", "if t > 1.5:", "var r := 0.5"]:
		assert_array(_knob_literals("x.gd", line)).override_failure_message(line).is_not_empty()
	assert_array(_knob_literals("x.gd", "var x := -1 # 30.0 in a comment\nvar s := \"5\"")).is_empty()


## AC-3 edge: a knob changed in data changes behaviour (charges at setup, lock length after a hit).
func test_changed_knob_changes_behaviour() -> void:
	_knobs.defense = _knobs.defense.duplicate()
	_knobs.defense.stun_item_charges = 3
	_knobs.defense.stun_duration_s = 3.0
	var runner: TickRunner = auto_free(TickRunner.new())
	runner.boot(_knobs)
	var sd := SurvivorDefense.new()
	sd.set_roster([2] as Array[int], 1)
	sd.setup(runner, EventBus.new(_knobs.core.max_flush_rounds), StateRegistry.new(), _knobs)
	assert_int(sd.charges(2)).is_equal(3)
	sd.shock(2, 0)
	assert_bool(sd._locked_at(2, _knobs.ticks(3.0) - 1)).is_true()
	assert_bool(sd._locked_at(2, _knobs.ticks(3.0))).is_false()


## Numeric literals in `src` (comments and strings stripped) equal to any DefenseKnobs value, as
## "file: line", minus NOT_KNOBS.
func _knob_literals(file: String, src: String) -> Array[String]:
	var values: Array[float] = []
	for p in _knobs.defense.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var v := float(_knobs.defense.get(p.name))
			if not STRUCTURAL.has(v):
				values.append(v)
	var strip := RegEx.create_from_string("\"[^\"\\n]*\"|#[^\\n]*")
	var num := RegEx.create_from_string("(?<![\\w.])-?\\d+(\\.\\d+)?(e[-+]?\\d+)?")
	var found: Array[String] = []
	for line in src.split("\n"):
		var code := strip.sub(line, "", true)
		var allowed := false
		for a: Array in NOT_KNOBS:
			allowed = allowed or (a[0] == file and code.contains(a[1]))
		for m in num.search_all(code):
			if not allowed and values.has(float(m.get_string())):
				found.append("%s: %s" % [file, line.strip_edges()])
	return found
