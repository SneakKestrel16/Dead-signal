class_name Knobs extends RefCounted
## Typed knob sections plus loading, validation and unit conversion (ADR-0006).
## Plain object: the composition root creates it and injects it; never an autoload.
## Not thread-safe: load once at boot on the main thread, then treat as read-only.
## Usage: `var k := Knobs.load_all(); if k.errors().is_empty(): var hz := k.net.sim_tick_hz`
## ponytail: digest and cross rules arrive in stories 003-005.

const KNOB_DIR := "res://data/knobs/"

## Fixed section list (never enumerate the folder: an export turns .tres into .remap entries).
## Section name -> file `<name>.tres` in KNOB_DIR; the field on Knobs has the same name.
const SECTIONS: PackedStringArray = [
	"controller", "lobby", "match_flow", "objectives", "downing", "defense", "borrowed_face",
	"ability", "ping", "scare", "net", "core", "facility",
]

var controller: ControllerKnobs
var lobby: LobbyKnobs
var match_flow: MatchFlowKnobs
var objectives: ObjectivesKnobs
var downing: DowningKnobs
var defense: DefenseKnobs
var borrowed_face: BorrowedFaceKnobs
var ability: AbilityKnobs
var ping: PingKnobs
var scare: ScareKnobs
var net: NetKnobs
var core: CoreKnobs
var facility: FacilityKnobs

## Paths that load_all actually opened (so tests can assert they are all under KNOB_DIR).
var loaded_paths: PackedStringArray = []
## Why a section is null after load_all: section name -> message.
var _load_notes: Dictionary = {}


## Loads every section from KNOB_DIR; collect problems with errors(), never trust a Knobs with errors.
## `dir` is a test hook: anything outside KNOB_DIR is refused outside the editor binary
## (a debug export template must not load user:// resources: they can embed scripts, ADR-0006 §3).
## Example: `var k := Knobs.load_all()` ; tests: `Knobs.load_all("user://knob_copy/")`.
static func load_all(dir: String = KNOB_DIR) -> Knobs:
	var k := Knobs.new()
	if dir != KNOB_DIR and not OS.has_feature("editor"):
		for name in SECTIONS:
			k._load_notes[name] = "%s: knob directory override refused outside the editor" % name
		return k
	for name in SECTIONS:
		var path := "%s%s.tres" % [dir, name]
		if not ResourceLoader.exists(path):
			k._load_notes[name] = "%s: file %s missing" % [name, path]
			continue
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null or not _is_section(name, res):
			k._load_notes[name] = "%s: file %s failed to load or is the wrong type" % [name, path]
			continue
		k.loaded_paths.append(path)
		k.set(name, res)
	return k


## True when `res` is the section class that belongs to `name` (e.g. "match_flow" -> MatchFlowKnobs).
static func _is_section(name: String, res: Resource) -> bool:
	var script: Script = res.get_script()
	return script != null and script.get_global_name() == name.to_pascal_case() + "Knobs"


## All load, range and unset errors across every section; [] = valid. A missing section is an error.
func errors() -> PackedStringArray:
	var errs := PackedStringArray()
	for name in SECTIONS:
		var section: Resource = get(name)
		if section == null:
			errs.append(_load_notes.get(name, "%s section missing" % name))
		else:
			errs.append_array(KnobValidator.validate(name, section))
	return errs


## Converts GDD seconds to sim ticks: roundi(seconds * net.sim_tick_hz).
## Example: 0.5 s at 60 Hz -> 30; 0.0 -> 0. Requires a valid `net` section.
func ticks(seconds: float) -> int:
	return roundi(seconds * net.sim_tick_hz)
