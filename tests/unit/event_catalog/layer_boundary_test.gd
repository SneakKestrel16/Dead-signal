# Story event-catalog-state-registry/006: layer boundary check (architecture.md System Layer Map,
# ADR-0005, TR-index-010). Dependencies point down: a script may name only classes and res:// paths of
# its own layer or a lower one. The layer of a script is its folder under src/; the class names of
# each layer are read from the `class_name` lines in that folder, never from a hand list.
# Rule for comments and strings: text after `#` is a comment and ignored (a doc line may say "Story 003
# adds X"); string contents count, because a res://src/feature/ path in a load() is a real reference.
# .tscn/.tres files under src/ are scanned for paths too (an ext_resource is a reference); a path
# counts with or without the trailing slash, and ../feature/x.gd from a sibling folder counts as well.
# Known limits: a `#` inside a string ends the scanned part of that line early; a path built at run
# time ("res://src/" + layer) or a uid:// reference is not seen.
extends GdUnitTestSuite

## Lowest first. A script in LAYERS[i] may reference LAYERS[0..i] only.
const LAYERS: PackedStringArray = ["foundation", "core", "feature", "presentation"]
const SRC := "res://src/"


## Upward references in `files` (res path -> source text). Returns "path: Name (layer)" entries, plus
## "path: class_name X declared twice" when one name is declared in two files.
## Files outside src/<layer>/ (e.g. src/main.gd, the composition root) are not checked.
static func upward_references(files: Dictionary) -> PackedStringArray:
	var class_re := RegEx.create_from_string("(?m)^\\s*(?:@\\w+\\s+)*class_name\\s+(\\w+)")
	var owner := {} ## class name -> layer index
	var out := PackedStringArray()
	for path: String in files:
		var layer := layer_of(path)
		if layer == -1 or not path.ends_with(".gd"):
			continue
		for m in class_re.search_all(files[path]):
			var name := m.get_string(1)
			if owner.has(name):
				out.append("%s: class_name %s declared twice" % [path, name])
			owner[name] = layer
	var word := RegEx.create_from_string("\\b[A-Z]\\w*\\b")
	for path: String in files:
		var layer := layer_of(path)
		if layer == -1:
			continue
		for line in String(files[path]).split("\n"):
			var code := line.split("#")[0]
			for m in word.search_all(code):
				var name := m.get_string()
				if owner.has(name) and owner[name] > layer:
					out.append("%s: %s (%s)" % [path, name, LAYERS[owner[name]]])
			for higher in range(layer + 1, LAYERS.size()):
				if code.contains(SRC + LAYERS[higher]) or code.contains("../" + LAYERS[higher] + "/"):
					out.append("%s: %s path" % [path, LAYERS[higher]])
	return out


## Index into LAYERS of a res://src/<layer>/... path, or -1.
static func layer_of(path: String) -> int:
	for i in LAYERS.size():
		if path.begins_with(SRC + LAYERS[i] + "/"):
			return i
	return -1


## Every .gd, .tscn and .tres file under src/, path -> text.
static func src_files() -> Dictionary:
	var files := {}
	var dirs := [SRC]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir + sub + "/")
		for f in DirAccess.get_files_at(dir):
			if f.get_extension() in ["gd", "tscn", "tres"]:
				files[dir + f] = FileAccess.get_file_as_string(dir + f)
	return files


func test_src_has_no_upward_reference() -> void:
	var files := src_files()
	assert_int(files.size()).is_greater(10) ## the walk reached the sources
	var layers_seen := {}
	for p: String in files:
		layers_seen[layer_of(p)] = true
	assert_bool(layers_seen.has(0) and layers_seen.has(1)).is_true() ## foundation and core both scanned
	assert_array(upward_references(files)).is_empty()


func test_fixture_with_an_upward_class_reference_fails_and_passes_without_it() -> void:
	var files := {
		"res://src/feature/stun.gd": "class_name StunLock extends RefCounted\n",
		"res://src/core/controller/body.gd": "class_name Body extends Node\nvar lock: StunLock\n",
	}
	assert_array(upward_references(files)).contains_exactly(["res://src/core/controller/body.gd: StunLock (feature)"])
	files["res://src/core/controller/body.gd"] = "class_name Body extends Node\nvar lock: Object\n"
	assert_array(upward_references(files)).is_empty()


func test_foundation_naming_a_core_class_fails() -> void:
	var files := {
		"res://src/core/controller/player_body.gd": "class_name PlayerBody extends CharacterBody3D\n",
		"res://src/foundation/network/sm.gd": "class_name Sm\nfunc f(b):\n\tif b is PlayerBody:\n\t\tpass\n",
	}
	assert_array(upward_references(files)).contains_exactly(["res://src/foundation/network/sm.gd: PlayerBody (core)"])


func test_upward_path_in_a_string_counts_and_a_comment_does_not() -> void:
	var files := {
		"res://src/core/a.gd": "class_name A\nvar s := load(\"res://src/presentation/hud.tscn\")\n",
		"res://src/foundation/b.gd": "class_name B\n## Feature code in res://src/feature/ reads this; FeatureThing\n",
		"res://src/feature/thing.gd": "class_name FeatureThing\n",
	}
	assert_array(upward_references(files)).contains_exactly(["res://src/core/a.gd: presentation path"])


func test_downward_and_same_layer_references_pass() -> void:
	var files := {
		"res://src/foundation/k.gd": "class_name Knobz\n",
		"res://src/core/c.gd": "class_name Ctl\nvar k: Knobz\n",
		"res://src/feature/f.gd": "class_name Feat\nvar c: Ctl\nvar k: Knobz\n",
		"res://src/presentation/p.gd": "class_name Pres\nvar f: Feat\n",
	}
	assert_array(upward_references(files)).is_empty()


func test_missing_layer_folders_still_check() -> void:
	# Feature and Presentation have no files yet: only foundation and core exist.
	var files := {"res://src/foundation/a.gd": "class_name Aa\n", "res://src/core/b.gd": "class_name Bb\nvar a: Aa\n"}
	assert_array(upward_references(files)).is_empty()


func test_indented_or_annotated_class_name_still_owns_its_layer() -> void:
	var files := {
		"res://src/feature/a.gd": "@abstract class_name Ab extends RefCounted\n",
		"res://src/feature/b.gd": "@tool\n  class_name Bc\n",
		"res://src/core/c.gd": "class_name Cc\nvar a: Ab\nvar b: Bc\n",
	}
	assert_array(upward_references(files)).contains_exactly_in_any_order(
		["res://src/core/c.gd: Ab (feature)", "res://src/core/c.gd: Bc (feature)"])


func test_scene_resource_path_and_relative_path_count() -> void:
	var files := {
		"res://src/core/x.tscn": "[ext_resource type=\"Script\" path=\"res://src/feature/stun.gd\" id=\"1\"]\n",
		"res://src/core/y.gd": "class_name Yy\nconst S := preload(\"../feature/stun.gd\")\n",
	}
	assert_array(upward_references(files)).contains_exactly_in_any_order(
		["res://src/core/x.tscn: feature path", "res://src/core/y.gd: feature path"])


func test_a_class_name_declared_in_two_layers_fails() -> void:
	var files := {"res://src/core/a.gd": "class_name Dup\n", "res://src/feature/b.gd": "class_name Dup\n"}
	var out := Array(upward_references(files))
	assert_bool(out.any(func(e: String) -> bool: return e.contains("class_name Dup declared twice"))).is_true()


func test_ci_workflow_runs_the_unit_tests() -> void:
	var wf := FileAccess.get_file_as_string("res://.github/workflows/tests.yml")
	assert_str(wf).contains("on:").contains("push:")
	assert_str(wf).contains("gdUnit4-action")
	## The `paths:` block lists tests/unit (this file lives there); a comment mentioning it does not count.
	var paths := RegEx.create_from_string("(?m)^\\s+paths:\\s*\\|?\\s*\\n((?:\\s+[^#\\s][^\\n]*\\n?)+)").search(wf)
	assert_bool(paths != null).is_true()
	assert_bool(Array(paths.get_string(1).split("\n")).any(func(l: String) -> bool: return l.strip_edges() == "tests/unit")).is_true()
