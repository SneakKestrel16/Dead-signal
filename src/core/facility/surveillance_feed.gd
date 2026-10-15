class_name SurveillanceFeed extends Node3D
## The C1 monitor's feed, client side (facility-map story 011; research-facility.md Surveillance; ADR-0009
## §8). One SubViewport sharing the main World3D (own_world_3d off) with a Camera3D at the viewed camera's
## authored transform: the camera marker's floor position, MOUNT_BELOW_CEILING_M under its volume's ceiling,
## facing the marker's yaw_deg. The feed draws the same remote bodies, lights and doors as the main view,
## so what it shows is what the server sent: a disguised shapeshifter appears as its disguise, and the
## lighting is whatever story 010 applied to those volumes. The viewport renders only while a camera is
## viewed (UPDATE_DISABLED otherwise), at knobs.facility.feed_resolution, with no positional shadows and a
## plain Environment so glow, SSAO, SSR and fog do not run twice. The image shows on a greybox screen at
## the monitor marker, on a render layer the feed camera culls. Decides nothing; the camera index comes
## from the server (Surveillance.camera_entries).
## Usage (client):
##   var feed := SurveillanceFeed.new(map, knobs)
##   add_child(feed); router.subscribe(EventBatch.CAMERA, feed.on_camera)

## Render layer (1-based) of the monitor screen; the feed camera does not draw it.
const SCREEN_LAYER := 20
## Inference (no mount height in the map file): cameras hang just under the ceiling of their volume
## (volume box height: 3 m, B1 6 m). A per-camera height in the map file would settle it.
const MOUNT_BELOW_CEILING_M := 0.3
## Greybox camera tilt and field of view. NOT SOURCEABLE: no camera spec yet; set so each feed shows its
## room's floor (evidence screenshots). The level art pass settles them.
const PITCH_DEG := -25.0
const FOV_DEG := 75.0
const ASPECT := 4.0 / 3.0
## Greybox screen: width in metres, centre height above the monitor marker. NOT SOURCEABLE (no monitor
## model yet); the C1 dressing pass replaces it.
const SCREEN_WIDTH_M := 1.2
const SCREEN_HEIGHT_M := 1.5

## The camera index shown (0 = c1), or Surveillance.OFF.
var current := Surveillance.OFF
var viewport: SubViewport
var camera: Camera3D
var screen: MeshInstance3D

var _cameras: Array[MapMarker] = []
var _ceilings: Dictionary[StringName, float] = {}


func _init(map: MapData, knobs: Knobs) -> void:
	for v in map.volumes:
		_ceilings[v.id] = v.box.end.y
	var monitor: MapMarker
	var room := AABB()
	for m in map.markers:
		if m.type == &"camera":
			_cameras.append(m)
		elif m.type == &"monitor":
			monitor = m
	for v in map.volumes:
		if monitor != null and v.id == monitor.volume:
			room = v.box
	viewport = SubViewport.new()
	viewport.size = Vector2i(roundi(knobs.facility.feed_resolution * ASPECT), knobs.facility.feed_resolution)
	viewport.own_world_3d = false
	viewport.positional_shadow_atlas_size = 0
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	camera = Camera3D.new()
	camera.fov = FOV_DEG
	camera.cull_mask = 0xFFFFF & ~(1 << (SCREEN_LAYER - 1))
	camera.environment = Environment.new()
	viewport.add_child(camera)
	screen = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(SCREEN_WIDTH_M, SCREEN_WIDTH_M / ASPECT)
	screen.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = viewport.get_texture()
	screen.material_override = mat
	screen.layers = 1 << (SCREEN_LAYER - 1)
	screen.visible = false
	add_child(screen)
	if monitor != null:
		# Faces the middle of the monitor's room (inference: the map has no monitor facing).
		screen.position = monitor.position + Vector3.UP * SCREEN_HEIGHT_M
		var to := room.get_center() - monitor.position
		screen.rotation.y = atan2(to.x, to.z)


func _ready() -> void:
	camera.current = true


## ClientEventRouter handler for EventBatch.CAMERA: {camera} 0..3, or -1 (off). Anything else is ignored.
func on_camera(_tick: int, payload: Dictionary) -> void:
	var n: Variant = payload.get("camera")
	if not n is int or n < Surveillance.OFF or n >= _cameras.size():
		return
	current = n
	if current == Surveillance.OFF:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		screen.visible = false
		return
	var m := _cameras[current]
	camera.position = Vector3(m.position.x, _ceilings.get(m.volume, 3.0) - MOUNT_BELOW_CEILING_M, m.position.z)
	camera.rotation = Vector3(deg_to_rad(PITCH_DEG), deg_to_rad(m.yaw_deg), 0.0)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen.visible = true
