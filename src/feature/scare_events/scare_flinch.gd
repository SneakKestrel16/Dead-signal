class_name ScareFlinch extends RefCounted
## Major scares ask for the camera flinch (story scare-events/005; design/gdd/scare-events.md rules 13-14,
## ADR-0015 §1). Every ScareTriggered delivered as Major emits one FlinchRequested for its recipient with the
## offset that turns the view toward the scare's origin. ViewOffset is the only writer of the offset: it drops
## the request for a toggled-off player or one within lunge_cue_radius_m of a lunge in wind-up or Active
## (rule 14, so the ambush lunge scare never flinches), caps it at flinch_max_angle_deg and ramps it over
## scare_max_control_loss_s. A Major reduced to Minor by gating (story 002) arrives as Minor and asks nothing.
## Usage: `var flinch := ScareFlinch.new(view, offset, body_points_of); flinch.setup(server.bus)`

var _bus: EventBus
var _view: ViewState
var _offset: ViewOffset
var _points: Callable


## `points(player) -> PackedVector3Array` [head (the eye), chest, pelvis]; empty for no body in the world.
func _init(view: ViewState, offset: ViewOffset, points: Callable) -> void:
	_view = view
	_offset = offset
	_points = points


func setup(bus: EventBus) -> void:
	_bus = bus
	bus.subscribe(&"ScareTriggered", _on_scare)


## The total view offset (x yaw, y pitch, radians) that points `view_yaw`/`view_pitch` (the current view,
## offset `held` included) at `to` from `eye`.
static func target_toward(eye: Vector3, to: Vector3, view_yaw: float, view_pitch: float, held: Vector2) -> Vector2:
	var d := to - eye
	if d.is_zero_approx():
		return held
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	return held + Vector2(wrapf(yaw - view_yaw, -PI, PI), pitch - view_pitch)


func _on_scare(e: ServerEvent) -> void:
	var s := e as EvScareTriggered
	if s.intensity != ScareEntry.Intensity.MAJOR:
		return
	var p := _points.call(s.recipient) as PackedVector3Array
	if p.is_empty():
		return
	var f := EvFlinchRequested.new()
	f.player = s.recipient
	f.target = target_toward(p[0], s.origin, _view.yaw_of(s.recipient), _view.pitch_of(s.recipient),
			_offset.offset_of(s.recipient))
	_bus.emit(f)
