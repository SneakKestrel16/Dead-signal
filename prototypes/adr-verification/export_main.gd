extends Node
## ADR-0006 (3), export half: in an exported build, load a knob file by its res:// path.
## Writes export_result.txt next to the executable, then quits.


func _ready() -> void:
	var path := "res://data/knobs/defense.tres"
	var r: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var lines: Array[String] = []
	lines.append("exported=%s" % OS.has_feature("template"))
	lines.append("loaded=%s" % (r != null))
	if r:
		lines.append("stun_duration_s=%s stun_item_charges=%s extra_s_is_nan=%s" % [r.stun_duration_s, r.stun_item_charges, is_nan(r.extra_s)])
	lines.append("tres_in_pack=%s remap_in_pack=%s" % [FileAccess.file_exists(path), FileAccess.file_exists(path + ".remap")])
	var ok: bool = r != null and r.stun_duration_s == 2.0 and r.stun_item_charges == 2 and is_nan(r.extra_s)
	lines.append("RESULT 0006-3x %s" % ("PASS" if ok else "FAIL"))
	var f := FileAccess.open(OS.get_executable_path().get_base_dir().path_join("export_result.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	get_tree().quit()
