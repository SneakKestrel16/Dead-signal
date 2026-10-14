class_name Knobs extends RefCounted
## Typed knob sections plus loading, validation and unit conversion (ADR-0006).
## Plain object: the composition root creates it and injects it; never an autoload.
## Not thread-safe: load once at boot on the main thread, then treat as read-only.
## Usage: `var k := Knobs.load_all(); if k.errors().is_empty(): var hz := k.net.sim_tick_hz`

const KNOB_DIR := "res://data/knobs/"
## Hex characters of the digest in the join version (ADR-0006 §7).
const DIGEST_SUFFIX_LEN := 8
## Survivor reaction time before the rewind is added (monster-abilities.md Formulas, survivor_reaction_s:
## "0.25 s reaction + max_rewind_ms", designer decision 2026-10-11). A design target, not a tuning knob.
const SURVIVOR_REACTION_BASE_S := 0.25
## Float tolerance for the metre limits below, so a value exactly on a limit passes.
const CROSS_EPS_M := 1e-6

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
	# Source: first-person-controller.md Formulas, catch_gap and the Gait speed joint cap: at survivor
	# sprint v_s = walk_speed x sprint_mult, catch_gap = lunge_distance_m + lunge_hit_radius_m +
	# player_radius_m - v_s x (lunge_windup_s + lunge_dash_s) must be >= 2 x player_radius_m, or an
	# open-ground chase is lunge-proof.
	var c := controller
	var r := c.player_radius_m
	var v_s := c.walk_speed * c.sprint_mult
	var catch_gap := ability.lunge_distance_m + ability.lunge_hit_radius_m + r - v_s * (ability.lunge_windup_s + ability.lunge_dash_s)
	if catch_gap < 2.0 * r - CROSS_EPS_M:
		errs.append("catch_gap (%.3f m at sprint %.3f m/s) must be >= 2 x controller.player_radius_m (%.3f m) (first-person-controller.md catch_gap)" % [catch_gap, v_s, 2.0 * r])
	# Source: first-person-controller.md Formulas, interact_ray_max: interact_ray_max_m >= max owner range_m
	# + (eye_height_m - capsule_height_m / 2), for the standing and the crouched posture. Owner ranges:
	# objectives.interact_range_m, downing.rescue_range_m, ability.backup_switch_range_m.
	var max_range := maxf(objectives.interact_range_m, maxf(downing.rescue_range_m, ability.backup_switch_range_m))
	errs.append_array(_ray_reach_errors("standing", max_range, c.eye_height_m, c.capsule_height_m))
	# Source: first-person-controller.md interact_ray_max, "for either posture": the crouched eye and capsule.
	errs.append_array(_ray_reach_errors("crouched", max_range, c.eye_low_height_m, c.capsule_low_height_m))
	return errs


## The interact_ray_max rule for one posture (validate_cross cites the source).
func _ray_reach_errors(posture: String, max_range: float, eye: float, capsule: float) -> PackedStringArray:
	var need := max_range + (eye - capsule / 2.0)
	if controller.interact_ray_max_m < need - CROSS_EPS_M:
		return PackedStringArray(["controller.interact_ray_max_m (%s) must be >= max owner range_m (%s) + eye height above capsule centre, %s (%.3f m) (first-person-controller.md interact_ray_max)" % [controller.interact_ray_max_m, max_range, posture, need]])
	return PackedStringArray()


## SHA-256 hex over var_to_bytes([section, field, value]) of every saved script variable, sections and
## fields in sorted name order (ADR-0006 §7). Values, never file bytes, so formatting and key order in
## the .tres do not matter. Requires every section loaded.
## Example: `Knobs.load_all().digest()` -> "3f1c..." (64 hex characters).
func digest() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var names := SECTIONS.duplicate()
	names.sort()
	for section_name in names:
		var section: Resource = get(section_name)
		var fields := PackedStringArray()
		for prop in section.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_STORAGE:
				fields.append(prop.name)
		fields.sort()
		for field in fields:
			var value: Variant = section.get(field)
			if value is float and value == 0.0:
				value = 0.0 ## -0.0 compares equal but serializes differently
			ctx.update(var_to_bytes([section_name, field, value]))
	return ctx.finish().hex_encode()


## The auth version string (ADR-0001 §3 as amended by ADR-0006 §7): "<build_version>+<digest 8 hex>",
## so a client whose knobs differ from the host's is rejected with version_mismatch.
## Example: `knobs.join_version("0.1.0")` -> "0.1.0+3f1c09ab".
func join_version(build_version: String) -> String:
	return "%s+%s" % [build_version, digest().left(DIGEST_SUFFIX_LEN)]


## Converts GDD seconds to sim ticks: roundi(seconds * net.sim_tick_hz).
## Example: 0.5 s at 60 Hz -> 30; 0.0 -> 0. Requires a valid `net` section.
func ticks(seconds: float) -> int:
	return roundi(seconds * net.sim_tick_hz)
