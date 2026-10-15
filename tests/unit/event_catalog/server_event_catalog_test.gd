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
			var s: GDScript = load(EVENTS_DIR + f)
			assert_object(s).override_failure_message("%s failed to load" % f).is_not_null()
			if s != null:
				out.append(s)
	# Guards every loop below against passing vacuously on an empty or moved directory.
	assert_int(out.size()).override_failure_message("event scripts found").is_equal(EXPECTED.size())
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
			if cells.size() < 3 or cells[1].split("`").size() < 2:
				continue
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
	var unique := {}
	for t in types:
		unique[t] = true
	assert_int(unique.size()).override_failure_message("duplicate type()").is_equal(types.size())


func test_type_values_equal_systems_index_table() -> void:
	var rows := _table_rows()
	assert_int(rows.size()).is_equal(EXPECTED.size())
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
		var event_name: String = s.new().type()
		assert_bool(emitters.has(event_name)).override_failure_message(
			"%s has no table row" % event_name).is_true()
		assert_str(_first_line_with(s, "## Emitter:")).override_failure_message(
			"%s header emitter" % event_name).is_equal(emitters.get(event_name, "<no row>"))


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


## AC3: every override restates the parent's return type (4.7 typed-return rule).
func test_each_override_restates_return_types() -> void:
	for s in _scripts():
		var src := s.source_code
		assert_bool(src.contains("func type() -> StringName:")).override_failure_message(
			"%s type() return type" % s.resource_path).is_true()
		# SR-1 review: match project() itself; any other function returning Dictionary passed before.
		var re := RegEx.create_from_string("func project[(][^)]*[)] -> Dictionary:")
		assert_bool(re.search(src) != null).override_failure_message(
			"%s project() return type" % s.resource_path).is_true()


## AC3: the base is abstract, so `ServerEvent.new()` is a parse error (checked at authoring;
## a runtime test cannot express a parse error). Here: the annotation sits on its own line.
func test_server_event_is_abstract() -> void:
	var src: String = (load(EVENTS_DIR + "server_event.gd") as GDScript).source_code
	assert_bool(src.contains("@abstract
class_name ServerEvent")).is_true()


func test_scare_triggered_reaches_only_its_recipient() -> void:
	var e := EvScareTriggered.new()
	e.recipient = 3
	assert_dict(e.project(3, HandleTable.new())).is_not_empty()
	assert_dict(e.project(4, HandleTable.new())).is_empty()


func test_round_ended_projection_does_not_share_results() -> void:
	var e := EvRoundEnded.new()
	e.results = {"a": 1}
	var d: Dictionary = e.project(1, HandleTable.new())
	d.results["a"] = 2
	assert_int(e.results["a"]).is_equal(1)


## SR-1 review 2026-10-14: these returned their fields for every peer, so the first NA-9 batch would
## have sent AbilityUsed and SurvivorHit to survivors (ADR-0004 §5: never sent) and another player's
## flinch to everyone. They fail closed, like FormChanged, until NA-9 knows each peer's role.
func test_secret_and_owner_only_events_reach_no_peer_yet() -> void:
	for e: ServerEvent in [EvAbilityUsed.new(), EvSurvivorHit.new(), EvFlinchRequested.new(), EvViewOffsetChanged.new()]:
		for peer in [1, 2, 3]:
			assert_dict(e.project(peer, HandleTable.new())).override_failure_message(str(e.type())).is_empty()
