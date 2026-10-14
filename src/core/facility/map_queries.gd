class_name MapQueries extends RefCounted
## Lookups over MapData (ADR-0007 §9-10). Analytic: reads the map data, never Area3D. The one physics
## query is interactable_on_ray's wall-and-glass ray (ADR-0007 §10); doors are tested analytically.
## Later stories add in_zone and capsule_overlaps_swing.
## Usage: `var q := MapQueries.new(map); var v := q.volume_at(position)`

## Door leaf thickness for the analytic door test (the greybox leaf, tools/level/greybox_from_map.gd).
const DOOR_LEAF_T := 0.1

## What interactable_on_ray needs besides the map. Build once per round with from_knobs().
class InteractRules extends RefCounted:
	var ray_max_m: float
	var pick_radius_m: float
	## Map positions are floor-level; the interaction point sits this far above (capsule centre height,
	## so range_m reads as floor distance). Inference: the map has no point height; the map file settles it.
	var point_height_m: float
	## Owner range_m by marker type; doors use door_range_m.
	var range_by_type: Dictionary = {}
	var door_range_m: float
	## Callable(net_id: int) -> bool: true while that door is closed or barricaded. Unset = all open.
	var door_closed: Callable

	## Owner ranges (first-person-controller.md interact_ray_max table): objectives.interact_range_m
	## for drives, fuses, fuse boxes, terminals, doors and hiding spots (Survivor Defense rule 28a uses
	## the same range), ability.backup_switch_range_m for switches. The monitor station's owner names no
	## range yet: objectives.interact_range_m (inference).
	static func from_knobs(knobs: Knobs, door_closed_: Callable = Callable()) -> InteractRules:
		var r := InteractRules.new()
		r.ray_max_m = knobs.controller.interact_ray_max_m
		r.pick_radius_m = knobs.controller.interact_pick_radius_m
		r.point_height_m = knobs.controller.capsule_height_m / 2.0
		var objective := knobs.objectives.interact_range_m
		r.range_by_type = {&"drive": objective, &"fuse": objective, &"fuse_box": objective,
			&"terminal": objective, &"hiding": objective, &"monitor": objective,
			&"switch": knobs.ability.backup_switch_range_m}
		r.door_range_m = objective
		r.door_closed = door_closed_
		return r

var _map: MapData
var _targets: Array[Resource] = []


func _init(map: MapData) -> void:
	_map = map


## The net id of the interactable the view ray targets, or -1 (ADR-0007 §10, ADR-0008 §2; GDD rule 12):
## the nearest one whose point lies within pick_radius_m of the ray, no farther along it than
## ray_max_m, and within its own range_m of `centre` (the capsule centre). Out-of-range ones are
## skipped and hide nothing behind them. A world or glass hit (one ray on `space`, `exclude` = the
## actor's own RID) or a closed door in front of the point blocks it. The server passes its own view
## direction (ViewState.server_dir), never a client-claimed one; the client prompt calls the same
## function with its predicted view. Equal distances along the ray: the lowest net id wins.
func interactable_on_ray(eye: Vector3, dir: Vector3, centre: Vector3, rules: InteractRules,
		space: PhysicsDirectSpaceState3D, exclude: Array[RID] = []) -> int:
	if _targets.is_empty():
		_targets = _map.interactables()
	dir = dir.normalized()
	var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * rules.ray_max_m, PhysicsLayers.PROJECTILE, exclude)
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	var block_t := eye.distance_to(hit.position) if not hit.is_empty() else INF
	var best := -1
	var best_t := INF
	for id in _targets.size():
		var door := _targets[id] as MapPassage
		var marker := _targets[id] as MapMarker
		var p := (door.position if door else marker.position) + Vector3.UP * rules.point_height_m
		var t := (p - eye).dot(dir)
		if t <= 0.0 or t > rules.ray_max_m or t >= block_t or t >= best_t:
			continue
		if p.distance_to(eye + dir * t) > rules.pick_radius_m:
			continue
		var range_m: float = rules.door_range_m if door else rules.range_by_type.get(marker.type, 0.0)
		if centre.distance_to(p) > range_m + 1e-6:
			continue
		if _door_blocks(eye, eye + dir * t, id, rules):
			continue
		best = id
		best_t = t
	return best


## A closed door's leaf (other than the target itself) crossing the segment eye -> point.
func _door_blocks(from: Vector3, to: Vector3, target_id: int, rules: InteractRules) -> bool:
	if not rules.door_closed.is_valid():
		return false
	for id in _targets.size():
		var p := _targets[id] as MapPassage
		if p == null or id == target_id or not rules.door_closed.call(id):
			continue
		if _leaf(p).intersects_segment(from, to):
			return true
	return false


## The door leaf box: the opening's width along the wall, DOOR_LEAF_T across, the swing box's height.
## The swing box's shorter horizontal side runs along the wall (ADR-0007 §8 sweep on both sides).
static func _leaf(p: MapPassage) -> AABB:
	var s := p.swing_box.size
	var along_x := s.x <= s.z
	var size := Vector3(p.width_m if along_x else DOOR_LEAF_T, s.y, DOOR_LEAF_T if along_x else p.width_m)
	return AABB(Vector3(p.position.x - size.x / 2.0, 0.0, p.position.z - size.z / 2.0), size)


## The volumes `volume_id` sees (its `sees` keys), minus those behind a door `door_closed` reports
## closed: Callable(passage_id: StringName) -> bool, unset = every door open (ADR-0004 §4). The
## volume itself is not listed (Relevance adds it). Unknown id: empty.
func visible_set(volume_id: StringName, door_closed: Callable = Callable()) -> PackedStringArray:
	var out := PackedStringArray()
	for v in _map.volumes:
		if v.id != volume_id:
			continue
		for seen: StringName in v.sees:
			var door: StringName = v.sees[seen]
			if door == &"" or not door_closed.is_valid() or not door_closed.call(door):
				out.append(seen)
	return out


## The id of the volume containing `point` (x, z only), or &"" outside every volume.
func volume_at(point: Vector3) -> StringName:
	for v in _map.volumes:
		if v.contains(point):
			return v.id
	return &""
