# Story data-config/002: every GDD knob has a field; shipped files load clean.
# Integration (reads the GDD markdown and the shipped .tres; copies files under user://).
extends GdUnitTestSuite

const GDD_DIR := "res://design/gdd/"
const COPY_DIR := "user://knob_test_copy/"
const LOAD_CEILING_MS := 100.0 ## Guardrail is 10 ms per boot; the ceiling is generous to avoid flakiness.

## GDD file -> [section, table kind]. Kind "tuning" = the `## Tuning Knobs` table;
## "formulas_data_file" = `## Formulas` rows whose Source column starts with "data file"
## (first-person-controller.md has no Tuning Knobs table).
const GDD_SECTIONS := {
	"borrowed-face": ["borrowed_face", "tuning"],
	"downing-and-rescue": ["downing", "tuning"],
	"first-person-controller": ["controller", "formulas_data_file"],
	"lobby-role-assignment": ["lobby", "tuning"],
	"match-flow": ["match_flow", "tuning"],
	"monster-abilities": ["ability", "tuning"],
	"pings-and-callouts": ["ping", "tuning"],
	"scare-events": ["scare", "tuning"],
	"survivor-defense": ["defense", "tuning"],
	"survivor-objectives": ["objectives", "tuning"],
}

## Table first-cell entries that are not knob fields. Key "<gdd>:<cell text>"; value = why.
const NOT_A_KNOB := {
	"lobby-role-assignment:Display name length": "UI/validation limit 1-16 (ADR-0001 join check), not a tuning field",
	"lobby-role-assignment:reconnect_grace_s": "owned by match-flow.md; the field lives in MatchFlowKnobs (checked via match-flow)",
	"monster-abilities:false_signal_footstep_path_m": "'(derived)' and 'not a knob': walk_speed x duration",
	"first-person-controller:eye_height_m": "two values (standing 1.6 / crouched 1.0) with no agreed field names yet; NOT SOURCEABLE as one field",
	"first-person-controller:capsule_height_m": "two values (standing 1.8 / crouched 1.2) with no agreed field names yet; NOT SOURCEABLE as one field",
}

## ADR-only knobs (no GDD table): section -> field names.
const ADR_ONLY := {
	"net": ["sim_tick_hz", "starvation_window_s", "correction_deadzone_m", "correction_smooth_max_m",
			"correction_smooth_s", "interp_delay_ms", "max_extrapolation_ms", "history_ticks", "reject_close_delay_s"],
	"core": ["max_flush_rounds"],
	"facility": ["max_flashes_per_s"],
}


## Names of a section's saved script variables (its knob fields).
func _fields(section: Resource) -> PackedStringArray:
	var out := PackedStringArray()
	for prop in section.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_STORAGE:
			out.append(prop.name)
	return out


## Section instance by name, from a fresh Knobs loaded from the shipped files.
func _section(name: String) -> Resource:
	return Knobs.load_all().get(name)


## Table rows of one `## ` heading as arrays of trimmed cells; header and separator rows dropped.
func _rows(gdd: String, heading: String) -> Array:
	var rows := []
	var inside := false
	for line in FileAccess.get_file_as_string("%s%s.md" % [GDD_DIR, gdd]).split("\n"):
		if line.begins_with("## "):
			inside = line.begins_with("## " + heading)
			continue
		if not inside or not line.begins_with("|"):
			continue
		var cells := []
		for c in line.trim_prefix("|").trim_suffix("|").split("|"):
			cells.append(c.strip_edges())
		if cells[0].begins_with("---") or cells[0] in ["Parameter", "Knob", "Variable"]:
			continue
		rows.append(cells)
	return rows


## Knob names and original first cells for one GDD: Array of [cell, [names]].
func _gdd_cells(gdd: String) -> Array:
	var kind: String = GDD_SECTIONS[gdd][1]
	var out := []
	var paren := RegEx.create_from_string("\\(.*?\\)")
	var ident := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	var rows := _rows(gdd, "Tuning Knobs" if kind == "tuning" else "Formulas")
	for cells in rows:
		if kind == "formulas_data_file" and not cells[3].begins_with("data file"):
			continue
		var raw: String = cells[0]
		var cleaned := paren.sub(raw.replace("*", "").replace("`", ""), "", true)
		var names := []
		for part in cleaned.split("/"):
			var n := part.strip_edges()
			if not ident.search(n):
				names = [raw.replace("*", "").replace("`", "")] # whole cell is not a name; must be allowlisted
				break
			names.append(n)
		out.append([raw, names])
	return out


func test_gdd_knob_tables_every_name_has_field_in_owning_section() -> void:
	var missing := PackedStringArray()
	var checked := 0
	for gdd in GDD_SECTIONS:
		var section_name: String = GDD_SECTIONS[gdd][0]
		var fields := _fields(_section(section_name))
		var cells := _gdd_cells(gdd)
		assert_int(cells.size()).override_failure_message("no knob rows parsed from %s" % gdd).is_greater(0)
		for entry in cells:
			for n in entry[1]:
				if NOT_A_KNOB.has("%s:%s" % [gdd, n]):
					continue
				checked += 1
				if n not in fields:
					missing.append("%s: %s not in %s" % [gdd, n, section_name])
	assert_array(missing).is_empty()
	assert_int(checked).is_greater(100)


func test_allowlist_entries_all_match_a_parsed_row() -> void:
	# Guards the allowlist itself: a stale entry would silently hide a missing field.
	var seen := {}
	for gdd in GDD_SECTIONS:
		for entry in _gdd_cells(gdd):
			for n in entry[1]:
				seen["%s:%s" % [gdd, n]] = true
	for key in NOT_A_KNOB:
		assert_bool(seen.has(key)).override_failure_message("stale allowlist entry " + key).is_true()


func test_adr_only_knobs_have_field_in_net_core_facility() -> void:
	for section_name in ADR_ONLY:
		var fields := _fields(_section(section_name))
		for n in ADR_ONLY[section_name]:
			assert_bool(n in fields).override_failure_message("%s missing %s" % [section_name, n]).is_true()


func test_proposed_knobs_still_have_a_field() -> void:
	var proposed := 0
	for gdd in ["downing-and-rescue", "match-flow", "survivor-objectives"]:
		var fields := _fields(_section(GDD_SECTIONS[gdd][0]))
		for entry in _gdd_cells(gdd):
			if not "proposed" in entry[0] and gdd != "downing-and-rescue":
				continue
			for n in entry[1]:
				proposed += 1
				assert_bool(n in fields).override_failure_message("%s proposed knob %s has no field" % [gdd, n]).is_true()
	assert_int(proposed).is_greater(10)
	# Spot check by name: a "(proposed)" row from match-flow.md ships as a loaded value.
	assert_float(Knobs.load_all().match_flow.post_escape_window_s).is_equal(45.0)


func test_load_all_shipped_files_reports_no_errors_within_time_ceiling() -> void:
	var t0 := Time.get_ticks_usec()
	var k := Knobs.load_all()
	var errs := k.errors()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("KNOB_LOAD_VALIDATE_MS=%.3f" % ms)
	assert_array(errs).is_empty()
	assert_float(ms).is_less(LOAD_CEILING_MS)


func test_load_all_loads_every_section_from_res_data_knobs_only() -> void:
	var k := Knobs.load_all()
	assert_int(k.loaded_paths.size()).is_equal(Knobs.SECTIONS.size())
	for p in k.loaded_paths:
		assert_bool(p.begins_with("res://data/knobs/")).override_failure_message("loaded " + p).is_true()


func test_load_all_override_dir_refused_in_release_builds_is_debug_only() -> void:
	# This suite runs in a debug build, where the test hook works; in release the same call must refuse.
	assert_bool(OS.is_debug_build()).is_true()
	var k := Knobs.load_all("user://nowhere/")
	assert_bool(k.errors().is_empty()).is_false()
	assert_array(k.loaded_paths).is_empty()


func test_load_all_misspelled_key_loads_and_reports_real_field_unset() -> void:
	# Arrange: copy every shipped file to user://, misspelling one key in defense.tres.
	DirAccess.make_dir_recursive_absolute(COPY_DIR)
	for name in Knobs.SECTIONS:
		var text := FileAccess.get_file_as_string("res://data/knobs/%s.tres" % name)
		if name == "defense":
			assert_str(text).contains("stun_duration_s = ")
			text = text.replace("stun_duration_s = ", "stun_duratoin_s = ")
		var f := FileAccess.open("%s%s.tres" % [COPY_DIR, name], FileAccess.WRITE)
		f.store_string(text)
		f.close()
	# Act
	var k := Knobs.load_all(COPY_DIR)
	var errs := k.errors()
	# Cleanup
	for name in Knobs.SECTIONS:
		DirAccess.remove_absolute("%s%s.tres" % [COPY_DIR, name])
	DirAccess.remove_absolute(COPY_DIR)
	# Assert
	assert_array(errs).contains_exactly(["defense.stun_duration_s unset"])
