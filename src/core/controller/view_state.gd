class_name ViewState extends RefCounted
## The server's copy of each player's view direction (ADR-0002 §3, ADR-0007 §11). It is the yaw and
## pitch of the input frame the player's movement used this tick, and nothing else: no gameplay state
## (root, slow, lock, Downed, Seized, Transforming, Holding) turns it. Every aim (taser, ping,
## interaction ray) reads server_dir(); the flinch offset (story 013) adds to it later. The Hidden peek
## view belongs to the Survivor Defense epic.
## Usage: `var view := ViewState.new(server_movement); var dir := view.server_dir(player_id)`

## Pitch limit, the same clamp InputQueue applies to every received frame (ADR-0002 §3).
const PITCH_LIMIT := deg_to_rad(InputQueue.PITCH_LIMIT_DEG)

var _movement: ServerMovement


func _init(movement: ServerMovement) -> void:
	_movement = movement


## Yaw in radians, wrapped to [-PI, PI). 0 faces -Z.
func yaw_of(player_id: int) -> float:
	return wrapf(_movement.frame_of(player_id).yaw, -PI, PI)


## Pitch in radians, clamped to ±85°. Positive looks up.
func pitch_of(player_id: int) -> float:
	return clampf(_movement.frame_of(player_id).pitch, -PITCH_LIMIT, PITCH_LIMIT)


## Unit view direction in world space.
func server_dir(player_id: int) -> Vector3:
	return direction(yaw_of(player_id), pitch_of(player_id))


## Unit direction for a yaw and pitch (radians): yaw about +Y, then pitch about the local +X.
static func direction(yaw: float, pitch: float) -> Vector3:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3.FORWARD
