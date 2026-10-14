class_name MapMarker extends Resource
## One authored point of the map: a spawn, hiding spot, light switch, camera, the monitor station or
## an objective candidate (research-facility.md "Placement overlay").
## Values come only from the map file (data/maps/).

@export var id: StringName
## One of MapData.MARKER_TYPES.
@export var type: StringName
## The MapVolume id that contains `position`.
@export var volume: StringName
## Floor-level position in metres (same axes as MapVolume.box).
@export var position: Vector3
