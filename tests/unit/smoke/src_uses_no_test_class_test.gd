# BUG-0017: the export preset excludes tests/, so a src/ script naming a class defined under tests/ does not
# compile in the shipped build (and the editor and test runs, which load tests/, hide it).
extends GdUnitTestSuite

const CLASS_NAME_RE := r"(?m)^class_name\s+(\w+)(\s+extends\s+[\w.\"]+)?\s*(#.*)?$" ## a whole line: not one inside a fixture string


func test_no_src_script_names_a_class_defined_under_tests() -> void:
	var re := RegEx.create_from_string(CLASS_NAME_RE)
	var test_classes: Array[String] = []
	for path in _scripts("res://tests"):
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			test_classes.append(m.get_string(1))
	assert_array(test_classes).contains(["TestMoveStep"]) ## the scan sees tests/helpers
	var uses: Array[String] = []
	for path in _scripts("res://src"):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code := lines[i].get_slice("#", 0) ## comments do not compile
			for c in test_classes:
				if RegEx.create_from_string(r"\b%s\b" % c).search(code) != null:
					uses.append("%s:%d %s" % [path, i + 1, c])
	assert_array(uses).is_empty()


## Every .gd file under `dir`, recursively.
func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
