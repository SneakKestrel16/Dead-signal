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
## Hiding markers only (AD-200, survivor-defense story 013): the way the spot faces, in degrees about +Y
## with the controller's yaw convention (0 faces -Z, north; 90 faces -X, west). An eject lands in front
## of the spot along it. Camera markers (facility-map story 011): the way the camera looks, same convention.
## Unset (NAN) on a hiding or camera marker fails MapData.errors(); other types ignore it.
@export var yaw_deg: float = NAN
