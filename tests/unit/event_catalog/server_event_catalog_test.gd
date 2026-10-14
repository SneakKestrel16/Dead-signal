# Story event-catalog-state-registry/001: ServerEvent base and the event catalog.
extends GdUnitTestSuite

const EVENTS_DIR := "res://src/foundation/events/"
const INDEX_PATH := "res://design/gdd/systems-index.md"

## Hard-coded on purpose: editing the systems-index table must fail this test deliberately.
const EXPECTED: Array[String] = [
	"RoundPhaseChanged", "RoundEnded", "SurvivorEscaped", "SurvivorHit", "SurvivorDowned",
	"SurvivorRescued", "SurvivorEliminated", "MonsterStunned", "PlayerShocked", "FormChanged",
	"ObjectiveProgressChanged", "ScareTriggered", "FlinchRequested", "ViewOffsetChanged",
	"AbilityUsed", "BarricadeBroken", "PlayerConnectionChanged",
]


## Returns "" when the sets match, else "missing: [...] extra: [...]".
func _diff_sets(expected: Array, actual: Array) -> String:
	var missing := expected.filter(func(x): return x not in actual)
	var extra := actual.filter(func(x): return x not in expected)
	if missing.is_empty() and extra.is_empty():
		return ""
	return "missing: %s extra: %s" % [missing, extra]


## Event scripts in the events directory, excluding the abstract base.
func _scripts() -> Array[GDScript]:
	var out: Array[GDScript] = []
	for f in DirAccess.get_files_at(EVENTS_DIR):
		if f.begins_with("ev_") and f.ends_with(".gd"):
			out.append(load(EVENTS_DIR + f))
	return out


## Table rows as {name, emitter}, parsed from systems-index.md.
func _table_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var in_table := false
	for line in FileAccess.get_file_as_string(INDEX_PATH).split("\n"):
		if line.begins_with("| Event | Emitted by |"):
			in_table = true
		elif line.begins_with("### Read-only replicated state"):
			break
		elif in_table and line.begins_with("| `"):
			var cells := line.split("|")
			rows.append({
				"name": cells[1].strip_edges().split("`")[1],
				"emitter": cells[2].strip_edges(),
			})
	return rows


## First line starting with prefix, trimmed of it; "" if none.
func _first_line_with(script: GDScript, prefix: String) -> String:
	for line in script.source_code.split("\n"):
		if line.begins_with(prefix):
			return line.trim_prefix(prefix).strip_edges()
	return ""


func test_type_values_equal_hardcoded_catalog() -> void:
	var types: Array = _scripts().map(func(s): return str(s.new().type()))
	assert_str(_diff_sets(EXPECTED, types)).is_empty()
	assert_int(types.size()).is_equal(EXPECTED.size())


func test_type_values_equal_systems_index_table() -> void:
	var rows := _table_rows()
	assert_int(rows.size()).is_greater_equal(15)
	var names: Array = rows.map(func(r): return r.name)
	var types: Array = _scripts().map(func(s): return str(s.new().type()))
	assert_str(_diff_sets(names, types)).is_empty()


func test_each_subclass_declares_type_and_project() -> void:
	for s in _scripts():
		var methods: Array = s.get_script_method_list().map(func(m): return m.name)
		assert_bool("type" in methods and "project" in methods).override_failure_message(
			"%s lacks type() or project()" % s.resource_path).is_true()


func test_each_header_names_the_tables_emitter() -> void:
	var emitters := {}
	for r in _table_rows():
		emitters[r.name] = r.emitter
	for s in _scripts():
		var name: String = s.new().type()
		assert_str(_first_line_with(s, "## Emitter:")).override_failure_message(
			"%s header emitter" % name).is_equal(emitters[name])


func test_project_returns_dictionary_for_every_subclass() -> void:
	for s in _scripts():
		var result: Variant = s.new().project(1, HandleTable.new())
		assert_bool(result is Dictionary).override_failure_message(s.resource_path).is_true()


func test_type_equals_class_name_without_ev_prefix() -> void:
	for s in _scripts():
		var cls: String = s.get_global_name()
		assert_str(cls).starts_with("Ev")
		assert_str(str(s.new().type())).is_equal(cls.trim_prefix("Ev"))


func test_diff_reports_sixteenth_event() -> void:
	assert_str(_diff_sets(EXPECTED, EXPECTED + ["Extra"])).contains("extra: [\"Extra\"]")


func test_diff_reports_missing_event() -> void:
	var fewer := EXPECTED.slice(1)
	assert_str(_diff_sets(EXPECTED, fewer)).contains("missing: [\"RoundPhaseChanged\"]")
