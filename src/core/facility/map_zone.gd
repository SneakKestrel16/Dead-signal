class_name MapZone extends Resource
## One authored gameplay zone of the map: the exit volume, a terminal zone or a spawn room
## (ADR-0007 §9; research-facility.md Technical Notes, TR-facility-009). An analytic floor box, never
## Area3D. Values come only from the map file (data/maps/). Queries go through MapQueries.zone_at / in_zone.
## The shipped boxes are inference; the level doc gives no zone sizes, and the level designer settles them:
## - exit Z-E: 2 m deep past C4's east wall, as wide as exit E's 4 m opening;
## - terminal zones Z-T1..3: 8 x 8 m centred on the terminal marker (objectives.terminal_zone_radius_m
##   4.0 as a half-width), clipped to the terminal's room;
## - spawn rooms: the box of the room holding the spawn markers (A1; C3, C5, B2 for M1-M3).

const EXIT := &"exit"
## The other kinds equal the marker type the zone covers (MapData.MARKER_TYPES).
const TERMINAL := &"terminal"
const SURVIVOR_SPAWN := &"survivor_spawn"
const MONSTER_SPAWN := &"monster_spawn"
const KINDS: Array[StringName] = [EXIT, TERMINAL, SURVIVOR_SPAWN, MONSTER_SPAWN]

@export var id: StringName
## One of KINDS.
@export var kind: StringName
## Floor-level box in metres, same axes as MapVolume.box.
@export var box: AABB


## True when `point` (x, z only) is inside the box; the east and south edges are outside, as in
## MapVolume.contains.
func contains(point: Vector3) -> bool:
	return point.x >= box.position.x and point.x < box.end.x and point.z >= box.position.z and point.z < box.end.z
