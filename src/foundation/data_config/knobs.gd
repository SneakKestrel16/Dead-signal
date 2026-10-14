class_name Knobs extends RefCounted
## Typed knob sections plus loading, validation and unit conversion (ADR-0006).
## Plain object: the composition root creates it and injects it; never an autoload.
## Not thread-safe: load once at boot on the main thread, then treat as read-only.
## Usage: `var k := Knobs.load_all(); if k.errors().is_empty(): var hz := k.net.sim_tick_hz`
## ponytail: digest arrives in story 005.

const KNOB_DIR := "res://data/knobs/"
## Survivor reaction time before the rewind is added (monster-abilities.md Formulas, survivor_reaction_s:
## "0.25 s reaction + max_rewind_ms", designer decision 2026-10-11). A design target, not a tuning knob.
const SURVIVOR_REACTION_BASE_S := 0.25

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


## All load, range, unset and cross-knob errors across every section; [] = valid. A missing section is
## an error. Cross-knob rules run only over sections with no load, range or unset error, so an unset
## knob reports "unset" and nothing else.
func errors() -> PackedStringArray:
	var errs := PackedStringArray()
	var clean := true
	for name in SECTIONS:
		var section: Resource = get(name)
		if section == null:
			errs.append(_load_notes.get(name, "%s section missing" % name))
			clean = false
			continue
		var section_errs := KnobValidator.validate(name, section)
		errs.append_array(section_errs)
		if section_errs.is_empty():
			errs.append_array(section.validate_cross())
		else:
			clean = false
	if clean:
		errs.append_array(validate_cross())
	return errs


## Cross-knob rules that span sections; [] = valid. Assumes every section is loaded and set.
func validate_cross() -> PackedStringArray:
	var errs := PackedStringArray()
	# Source: ADR-0008 (hold continuation range is range_m + hold_range_tolerance_m) and ADR-0006 §4:
	# the tolerance must stay below the interaction range it extends.
	if controller.hold_range_tolerance_m >= objectives.interact_range_m:
		errs.append("controller.hold_range_tolerance_m (%s) must be below objectives.interact_range_m (%s) (ADR-0008)" % [controller.hold_range_tolerance_m, objectives.interact_range_m])
	# Source: ADR-0003 §7: full lag compensation reaches max_rewind_ms - interp_delay_ms - one tick of
	# RTT, so the rewind cap must exceed the interpolation delay plus one tick or no one is compensated.
	var tick_ms := 1000.0 / net.sim_tick_hz
	if ability.max_rewind_ms <= net.interp_delay_ms + tick_ms:
		errs.append("ability.max_rewind_ms (%d) must exceed net.interp_delay_ms (%d) + one tick (%.1f ms) (ADR-0003 §7)" % [ability.max_rewind_ms, net.interp_delay_ms, tick_ms])
	# Source: ADR-0003 §7 and monster-abilities.md Formulas (dodge window): a survivor who starts strafing
	# survivor_reaction_s = 0.25 s + max_rewind_ms after the cue must still dodge, so the strafe must
	# start before the dash does (cue to dash = lunge_windup_s). Inference: this is necessary, not
	# sufficient; the pursuit simulation (ADR-0003 verification 4: latest safe start 0.457 s at
	# windup 0.6) settles the real margin.
	var reaction_s := SURVIVOR_REACTION_BASE_S + ability.max_rewind_ms / 1000.0
	if reaction_s >= ability.lunge_windup_s:
		errs.append("dodge budget: 0.25 s + ability.max_rewind_ms (%.3f s) must be below ability.lunge_windup_s (%s) (ADR-0003 §7; a necessary condition only, the pursuit simulation sets the real margin)" % [reaction_s, ability.lunge_windup_s])
	return errs


## Converts GDD seconds to sim ticks: roundi(seconds * net.sim_tick_hz).
## Example: 0.5 s at 60 Hz -> 30; 0.0 -> 0. Requires a valid `net` section.
func ticks(seconds: float) -> int:
	return roundi(seconds * net.sim_tick_hz)
