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


## True when `point` (x, z only) is inside the box; the east and south edges belong to the next volume.
func contains(point: Vector3) -> bool:
	return point.x >= box.position.x and point.x < box.end.x and point.z >= box.position.z and point.z < box.end.z
