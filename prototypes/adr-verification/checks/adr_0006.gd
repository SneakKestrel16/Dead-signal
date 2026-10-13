extends "res://lib.gd"
## ADR-0006 Verification Required (1)-(5). Files are written under user://, not res://.

const SECTION := preload("res://fixtures/knob_section.gd")
const PATH := "user://knob_section_test.tres"
const TYPO_PATH := "user://knob_section_typo.tres"


func run() -> void:
	# (1) Range hints from @export_range.
	var inst: Resource = SECTION.new()
	var hints := {}
	for prop in inst.get_property_list():
		if prop.name in ["stun_duration_s", "stun_item_charges", "extra_s"]:
			hints[prop.name] = [prop.hint, prop.hint_string]
	var parsed_ok: bool = true
	for k in ["stun_duration_s", "stun_item_charges"]:
		var parts: PackedStringArray = (hints[k][1] as String).split(",")
		parsed_ok = parsed_ok and hints[k][0] == PROPERTY_HINT_RANGE and parts.size() >= 2
	var p0: PackedStringArray = (hints["stun_duration_s"][1] as String).split(",")
	parsed_ok = parsed_ok and float(p0[0]) == 1.0 and float(p0[1]) == 4.0
	rec("0006-1", "PASS" if parsed_ok else "FAIL", "PROPERTY_HINT_RANGE=%d; hints: %s" % [PROPERTY_HINT_RANGE, hints])
	# (3) NAN default omitted from .tres and reported unset after load.
	inst.stun_duration_s = 2.0
	inst.stun_item_charges = 2
	var save_err := ResourceSaver.save(inst, PATH)
	var text := FileAccess.get_file_as_string(PATH)
	var a: Resource = ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var omitted: bool = not text.contains("extra_s")
	var ok3: bool = save_err == OK and a != null and is_nan(a.extra_s) and a.stun_duration_s == 2.0
	rec("0006-3", "PASS" if ok3 else "FAIL", "field left at NAN default: omitted from .tres=%s (written as `extra_s = nan` otherwise), NAN after load=%s; set field round-trips=%s. Exported binary .res + .remap path load: NOT RUN (needs an export)" % [omitted, is_nan(a.extra_s) if a else "?", a.stun_duration_s == 2.0 if a else "?"])
	# (2) CACHE_MODE_IGNORE gives independent instances.
	var b: Resource = ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	a.stun_duration_s = 3.5
	var ok2: bool = a != b and b.stun_duration_s == 2.0
	rec("0006-2", "PASS" if ok2 else "FAIL", "two CACHE_MODE_IGNORE loads distinct=%s; mutating one leaves the other at %s" % [a != b, b.stun_duration_s])
	# (4) Digest repeatability within this run; run.sh compares two runs.
	var d1 := _digest(b)
	var d2 := _digest(ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE))
	rec("0006-4", "PASS" if d1 == d2 else "FAIL", "SHA-256 over var_to_bytes of sorted (name, value) pairs, two loads equal=%s DIGEST=%s (cross-run: run.sh; cross-machine: NOT RUN)" % [d1 == d2, d1])
	# (5) Misspelled key in the file.
	var typo_text := text.replace("stun_duration_s", "stun_duraton_s")
	var f := FileAccess.open(TYPO_PATH, FileAccess.WRITE)
	f.store_string(typo_text)
	f.close()
	var t: Resource = ResourceLoader.load(TYPO_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var ok5: bool = t != null and is_nan(t.stun_duration_s)
	rec("0006-5", "PASS" if ok5 else "FAIL", "misspelled key: loaded=%s, real field unset (NAN)=%s" % [t != null, is_nan(t.stun_duration_s) if t else "?"])


func _digest(r: Resource) -> String:
	var pairs := []
	var names := []
	for prop in r.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(prop.name)
	names.sort()
	for n in names:
		pairs.append([n, r.get(n)])
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes(pairs))
	return ctx.finish().hex_encode()
