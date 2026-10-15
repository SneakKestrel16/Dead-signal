class_name ViewState extends RefCounted
## The server's copy of each player's view direction (ADR-0002 §3, ADR-0007 §11). It is the yaw and
## pitch of the input frame the player's movement used this tick plus the flinch view offset
## (ViewOffset, ADR-0015; story 013), and nothing else: no gameplay state (root, slow, lock, Downed,
## Seized, Transforming, Holding) turns it, and client camera effects (shake, jitter, jolt) never reach
## it. Every aim (taser, ping, interaction ray) reads server_dir(). The Hidden peek view belongs to the
## Survivor Defense epic.
## Usage: `var view := ViewState.new(server_movement, view_offset); var dir := view.server_dir(player_id)`

## Pitch limit, the same clamp InputQueue applies to every received frame (ADR-0002 §3).
const PITCH_LIMIT := deg_to_rad(InputQueue.PITCH_LIMIT_DEG)

var _movement: ServerMovement
var _offset: ViewOffset


## `offset` null: no flinch offset (tests and tools that need the input view only).
func _init(movement: ServerMovement, offset: ViewOffset = null) -> void:
	_movement = movement
	_offset = offset


## Yaw in radians, wrapped to [-PI, PI). 0 faces -Z.
func yaw_of(player_id: int) -> float:
	var f := _movement.frame_of(player_id)
	return wrapf(f.yaw + _offset_for(player_id, f).x, -PI, PI)


## Pitch in radians, clamped to ±85° after the offset is added (ADR-0015 §3). Positive looks up.
func pitch_of(player_id: int) -> float:
	var f := _movement.frame_of(player_id)
	return clampf(f.pitch + _offset_for(player_id, f).y, -PITCH_LIMIT, PITCH_LIMIT)


## Unit view direction in world space.
func server_dir(player_id: int) -> Vector3:
	return direction(yaw_of(player_id), pitch_of(player_id))


## Unit direction for a yaw and pitch (radians): yaw about +Y, then pitch about the local +X.
static func direction(yaw: float, pitch: float) -> Vector3:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3.FORWARD


func _offset_for(player_id: int, f: InputFrame) -> Vector2:
	return Vector2.ZERO if _offset == null else _offset.offset_for(player_id, f)
