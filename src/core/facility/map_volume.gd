class_name MapVolume extends Resource
## One lighting volume of the map: a room, or a segment of a corridor or the lab spine
## (research-facility.md "Lighting volumes"). Gameplay zones are analytic boxes from this data,
## never Area3D (ADR-0007 §9). Values come only from the map file (data/maps/).
## Usage: `for v in map.volumes: if v.contains(p): ...`

@export var id: StringName
## The room the volume belongs to (A2, H-N, H-S for segments; itself otherwise): the node name in
## the level doc's connectivity graph.
@export var room: StringName
## Zone A, B or C, or &"link" for the service corridors.
@export var zone: StringName
## Floor-level box in metres: x east from the west wall, z south from the north wall, y up.
@export var box: AABB
## Visibility set (research-facility.md "Visibility sets", ADR-0004 §4): volume id -> the door
## passage id that cuts it while closed or barricaded, or &"" when seen through an archway, open
## corridor or glass. The volume itself is implied. Facility-map story 005 authors the shipped table.
@export var sees: Dictionary[StringName, StringName] = {}
## Multiplier on the server's footstep send radius for steps inside this volume, in (0, 1]: loud machinery
## masks footsteps (ADR-0013 §7, research-facility.md B3 row). 1.0 everywhere but B3.
@export var footstep_radius_scale: float = 1.0


## True when `point` (x, z only) is inside the box; the east and south edges belong to the next volume.
func contains(point: Vector3) -> bool:
	return point.x >= box.position.x and point.x < box.end.x and point.z >= box.position.z and point.z < box.end.z
