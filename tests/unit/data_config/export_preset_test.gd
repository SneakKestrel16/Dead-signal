# TD-004 / EX-1: the committed export preset must ship the knob files and write under the ignored build dir.
extends GdUnitTestSuite

const PRESETS := "res://export_presets.cfg"
const PRESET_NAME := "Dead Signal Windows"
const IGNORED_BUILD_DIR := "build/"
const GITIGNORE := "res://.gitignore"


## The section of the preset named PRESET_NAME as a Dictionary of key -> value, {} if absent.
func _preset() -> Dictionary:
	var cfg := ConfigFile.new()
	assert_int(cfg.load(PRESETS)).is_equal(OK)
	for section in cfg.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options") \
				and cfg.get_value(section, "name", "") == PRESET_NAME:
			var d := {}
			for key in cfg.get_section_keys(section):
				d[key] = cfg.get_value(section, key)
			return d
	return {}


func test_preset_exists_for_windows_desktop() -> void:
	var p := _preset()
	assert_bool(p.is_empty()).is_false()
	assert_str(p.get("platform", "")).is_equal("Windows Desktop")


func test_include_filter_covers_every_knob_file() -> void:
	var p := _preset()
	var patterns: PackedStringArray = String(p.get("include_filter", "")).split(",", false)
	for name in Knobs.SECTIONS:
		var path := "data/knobs/%s.tres" % name
		var hit := false
		for pat in patterns:
			hit = hit or path.matchn(pat.strip_edges())
		assert_bool(hit).override_failure_message("include_filter misses " + path).is_true()


func test_export_path_is_inside_the_ignored_build_dir() -> void:
	var path: String = _preset().get("export_path", "")
	assert_bool(path.begins_with(IGNORED_BUILD_DIR)).is_true()
	var ignore := FileAccess.get_file_as_string(GITIGNORE).replace("\r", "").split("\n")
	assert_bool(ignore.size() > 1).override_failure_message(".gitignore unreadable").is_true()
	assert_bool(IGNORED_BUILD_DIR in ignore).is_true()


## The first export shipped addons/gdUnit4 inside the pck (EX-1 export check, 2026-10-14).
func test_exclude_filter_keeps_tests_and_the_test_addon_out() -> void:
	var patterns: PackedStringArray = String(_preset().get("exclude_filter", "")).split(",", false)
	for path in ["tests/unit/x_test.gd", "addons/gdUnit4/plugin.gd"]:
		var hit := false
		for pat in patterns:
			hit = hit or path.matchn(pat.strip_edges())
		assert_bool(hit).override_failure_message("exclude_filter misses " + path).is_true()


func test_preset_holds_no_credentials() -> void:
	var text := FileAccess.get_file_as_string(PRESETS).to_lower()
	for word in ["password", "keystore", "api_key", "secret"]:
		assert_bool(word in text).override_failure_message("export_presets.cfg mentions " + word).is_false()
