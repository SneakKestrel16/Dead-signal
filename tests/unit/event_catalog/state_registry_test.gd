# Story event-catalog-state-registry/003: StateRegistry, StateKeys and the getter-only view rule.
extends GdUnitTestSuite

const INDEX_PATH := "res://design/gdd/systems-index.md"
const SRC_DIR := "res://src/"
## Hard-coded on purpose: editing the systems-index state table or StateKeys must fail deliberately.
const EXPECTED_KEYS := 23


## Fixture owner: holds private state, hands out a view.
class Owner extends RefCounted:
	var _items: PackedStringArray = PackedStringArray(["a"])

	func replace_items(items: PackedStringArray) -> void:
		_items = items


## Fixture view: getters only; reads the owner's private state through a getter.
class GoodView extends RefCounted:
	var _owner: Owner

	func _init(o: Owner) -> void:
		_owner = o

	func get_items() -> PackedStringArray:
		return _owner._items

	func is_empty() -> bool:
		return _owner._items.is_empty()


## Fixture view that must be flagged: a public var, a setter method and a property setter.
class BadView extends RefCounted:
	var items: PackedStringArray = PackedStringArray()

	func set_items(v: PackedStringArray) -> void:
		items = v

	func add_item(s: String) -> void:
		items.append(s)


class OtherView extends RefCounted:
	pass


func _registry() -> StateRegistry:
	var r := StateRegistry.new()
	r.fail_hard = false
	return r


## Violations of the getter-only rule in `script`: public vars, set_* methods, non-getter public
## methods, and (when source is available) property setters. Empty when the view is clean.
func _view_violations(script: Script) -> PackedStringArray:
	var out := PackedStringArray()
	for p in script.get_script_property_list():
		var n: String = p.name
		if (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and not n.begins_with("_"):
			out.append("public var '%s'" % n)
	for m in script.get_script_method_list():
		var n: String = m.name
		if n.begins_with("_"):
			continue
		if n.begins_with("set_"):
			out.append("setter method '%s'" % n)
		elif not (n.begins_with("get_") or n.begins_with("is_") or n.begins_with("has_")):
			out.append("mutator/non-getter '%s'" % n)
	if script.source_code != "":
		var re := RegEx.create_from_string("(?m)^\\s*set\\s*[(=:]")
		if re.search(script.source_code) != null:
			out.append("property setter 'set('")
	return out


func test_view_returns_registered_view() -> void:
	var r := _registry()
	var v := GoodView.new(Owner.new())
	r.register_view(StateKeys.DOOR_STATE, &"FacilityMap", v)
	assert_object(r.view(StateKeys.DOOR_STATE, GoodView)).is_same(v)
	assert_array(r.violations).is_empty()


func test_view_with_wrong_class_records_violation_and_returns_null() -> void:
	var r := _registry()
	r.register_view(StateKeys.DOOR_STATE, &"FacilityMap", GoodView.new(Owner.new()))
	assert_object(r.view(StateKeys.DOOR_STATE, OtherView)).is_null()
	assert_int(r.violations.size()).is_equal(1)
	assert_str(r.violations[0]).contains("door_state")


func test_register_twice_records_violation_and_keeps_first() -> void:
	var r := _registry()
	var first := GoodView.new(Owner.new())
	r.register_view(StateKeys.DOOR_STATE, &"FacilityMap", first)
	r.register_view(StateKeys.DOOR_STATE, &"Imposter", GoodView.new(Owner.new()))
	assert_int(r.violations.size()).is_equal(1)
	assert_str(r.violations[0]).contains("door_state")
	assert_object(r.view(StateKeys.DOOR_STATE, GoodView)).is_same(first)


func test_unregistered_key_records_violation_naming_key() -> void:
	var r := _registry()
	assert_object(r.view(&"no_such_key", GoodView)).is_null()
	assert_int(r.violations.size()).is_equal(1)
	assert_str(r.violations[0]).contains("no_such_key")


func test_owner_replacing_collection_whole_is_seen_by_view() -> void:
	var r := _registry()
	var o := Owner.new()
	r.register_view(StateKeys.PLAYER_ROSTER, &"Lobby", GoodView.new(o))
	var v := r.view(StateKeys.PLAYER_ROSTER, GoodView) as GoodView
	assert_array(v.get_items()).contains_exactly(["a"])
	o.replace_items(PackedStringArray(["x", "y"]))
	assert_array(v.get_items()).contains_exactly(["x", "y"])


func test_clear_empties_registry_and_allows_reregistration() -> void:
	var r := _registry()
	r.register_view(StateKeys.DOOR_STATE, &"FacilityMap", GoodView.new(Owner.new()))
	r.clear()
	assert_object(r.view(StateKeys.DOOR_STATE, GoodView)).is_null()
	assert_int(r.violations.size()).is_equal(1)
	r.register_view(StateKeys.DOOR_STATE, &"FacilityMap", GoodView.new(Owner.new()))
	assert_int(r.violations.size()).is_equal(1)


## State-table rows: the "State" cell of each row between the table header and the next rule.
func _state_rows() -> Array[String]:
	var rows: Array[String] = []
	var in_table := false
	var in_section := false
	for line in FileAccess.get_file_as_string(INDEX_PATH).split("\n"):
		if line.begins_with("### Read-only replicated state"):
			in_section = true
		elif in_section and line.begins_with("| State | Owner |"):
			in_table = true
		elif in_table and line.begins_with("---"):
			break
		elif in_table and line.begins_with("| ") and not line.begins_with("|--"):
			rows.append(line.split("|")[1].strip_edges())
	return rows


func test_state_keys_has_one_unique_constant_per_table_row() -> void:
	var rows := _state_rows()
	var consts := (load("res://src/foundation/events/state_keys.gd") as GDScript).get_script_constant_map()
	assert_int(rows.size()).override_failure_message("state table rows").is_equal(EXPECTED_KEYS)
	assert_int(consts.size()).override_failure_message("StateKeys constants").is_equal(EXPECTED_KEYS)
	var values := {}
	for k in consts:
		var val: Variant = consts[k]
		assert_bool(val is StringName and str(val) == str(k).to_lower()).override_failure_message(
			"%s must be a snake_case StringName equal to its lowercased name" % k).is_true()
		values[val] = true
	assert_int(values.size()).override_failure_message("duplicate key values").is_equal(consts.size())


func test_reflection_checker_flags_bad_view() -> void:
	var found := _view_violations(BadView)
	assert_str(" ".join(found)).contains("public var 'items'")
	assert_str(" ".join(found)).contains("setter method 'set_items'")
	assert_str(" ".join(found)).contains("mutator/non-getter 'add_item'")


func test_reflection_checker_flags_property_setter_in_source() -> void:
	var s := GDScript.new()
	s.source_code = "extends RefCounted\nvar _x: int:\n\tset(v):\n\t\t_x = v\n"
	s.reload()
	assert_str(" ".join(_view_violations(s))).contains("property setter")


func test_reflection_checker_passes_good_view() -> void:
	assert_array(_view_violations(GoodView)).is_empty()


func _view_scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with("_view.gd"):
			out.append(dir + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_view_scripts(dir + d + "/"))
	return out


func test_no_real_view_declares_setter_or_public_writable_state() -> void:
	var paths := _view_scripts(SRC_DIR)
	var bad := PackedStringArray()
	for p in paths:
		for v in _view_violations(load(p) as Script):
			bad.append("%s: %s" % [p, v])
	assert_array(bad).override_failure_message(
		"view violations across %d *_view.gd file(s)" % paths.size()).is_empty()
