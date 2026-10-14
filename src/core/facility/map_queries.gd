class_name MapQueries extends RefCounted
## Lookups over MapData (ADR-0007 §9-10). Analytic: reads the map data, never physics or Area3D.
## Later stories add in_zone, interactable_on_ray and capsule_overlaps_swing.
## Usage: `var q := MapQueries.new(map); var v := q.volume_at(position)`

var _map: MapData


func _init(map: MapData) -> void:
	_map = map


## The id of the volume containing `point` (x, z only), or &"" outside every volume.
func volume_at(point: Vector3) -> StringName:
	for v in _map.volumes:
		if v.contains(point):
			return v.id
	return &""
