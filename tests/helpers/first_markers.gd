class_name FirstMarkers extends RefCounted
## Test placement: the first authored markers of each objective type (the pre-story-008 layout), for
## suites that place actors at known points. Set on SurvivorObjectives.placement before setup.
## Not rule-6 checked: tests only. Usage: `obj.placement = FirstMarkers.of(map)`.

static func of(map: MapData) -> PackedInt32Array:
	var counts := {&"terminal": 1, &"fuse_box": SurvivorObjectives.ACTIVE_FUSE_BOXES,
		&"drive": SurvivorObjectives.ACTIVE_DRIVES, &"fuse": SurvivorObjectives.ACTIVE_FUSES}
	var out := PackedInt32Array()
	for type: StringName in counts:
		var n := 0
		for i in map.markers.size():
			if map.markers[i].type == type and n < counts[type]:
				out.append(i)
				n += 1
	return out
