class_name EdgeCues extends Control
## H14 edge cue indicators (design/ux/hud.md H14, I28, I32; interaction-patterns P8; story hud-results/005):
## a mark on the screen edge toward a source, direction only. Three distinct shapes, not colour-coded:
## - lunge wind-up: sharp chevron, from the Lunge cue sound (MonsterAbilities.CUE_SOUND) for lunge_windup_s;
## - transform distortion: wavering arc, from BorrowedFace.DISTORTION_SOUND for transform_duration_s;
## - flinch-off pulse (ADR-0015 §4, scare-events.md rule 27): soft glow toward a Major scare's origin when
##   the camera flinch is off, for scare_max_control_loss_s (inference: the pulse lasts as long as the
##   flinch it replaces; no source gives its length). Client only: the server's ViewOffset path is not
##   touched; it already drops the flinch of a toggled-off player.
## Range: the sounds only reach clients inside their send radius; the cue checks the same radius against
## the listener again (lunge_cue_radius_m, distortion_radius_m) so nothing outside it ever shows.
## Inside a running lunge cue no pulse shows: the server never flinches there (rule 14).
## Fades 150 ms in, holds for the cue, 300 ms out (interaction-patterns animation table), opacity only.
## Deviation from ADR-0014 §6 (HudModel the only source): fed straight from the router like PingCalloutHud,
## because the cues hold no state another widget reads.
## Usage:
##   var cues := EdgeCues.new(knobs, camera.get_global_transform, func() -> bool: return flinch_enabled)
##   hud.add_child(cues); router.subscribe(EventBatch.SOUND, cues.on_sound)
##   router.subscribe(&"ScareTriggered", cues.on_scare)

enum Kind { LUNGE, TRANSFORM, PULSE }

## interaction-patterns.md animation table, Edge indicator: 150 ms in, 300 ms out.
const IN_S := 0.15
const OUT_S := 0.3
## GREYBOX layout (final art is out of scope): edge inset and mark size in pixels, wobble of the arc.
const INSET_PX := 56.0
const MARK_PX := 34.0
const WOBBLE_HZ := 9.0
const WOBBLE_PX := 4.0
const COLOUR := Color(1.0, 0.95, 0.9)

## hud.md Accessibility "Cue indicators (H14)" On/Off: off removes the lunge and transform visuals only.
var cues_enabled := true
## Reduced motion: the arc does not waver.
var reduced_motion := false

var _knobs: Knobs
var _listener: Callable
var _flinch_on: Callable
## {kind, at, total, left}; left counts down from total + OUT_S.
var _cues: Array[Dictionary] = []
var _time := 0.0


## `listener() -> Transform3D`: the own camera (bearing and range). `flinch_on() -> bool`: the flinch toggle.
func _init(knobs: Knobs, listener: Callable, flinch_on: Callable) -> void:
	_knobs = knobs
	_listener = listener
	_flinch_on = flinch_on
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## ClientEventRouter handler for EventBatch.SOUND: the lunge cue and the distortion; other sets ignored.
func on_sound(_tick: int, payload: Dictionary) -> void:
	var at: Variant = payload.get("pos")
	if not cues_enabled or not at is Vector3:
		return
	match payload.get("set"):
		MonsterAbilities.CUE_SOUND:
			_add(Kind.LUNGE, at, _knobs.ability.lunge_cue_radius_m, _knobs.ability.lunge_windup_s)
		BorrowedFace.DISTORTION_SOUND:
			_add(Kind.TRANSFORM, at, _knobs.borrowed_face.distortion_radius_m,
					_knobs.borrowed_face.transform_duration_s)


## ClientEventRouter handler for ScareTriggered: the substitute pulse for a flinch-off player.
func on_scare(_tick: int, payload: Dictionary) -> void:
	var at: Variant = payload.get("origin")
	if _flinch_on.call() or payload.get("intensity") != ScareEntry.Intensity.MAJOR or not at is Vector3:
		return
	for c in _cues:
		if c.kind == Kind.LUNGE and c.left > OUT_S:
			return
	_add(Kind.PULSE, at, INF, _knobs.scare.scare_max_control_loss_s)


## The cues showing now: {kind, bearing_deg (0 ahead, + right), alpha 0-1}.
func cues() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var from: Transform3D = _listener.call()
	for c in _cues:
		out.append({"kind": c.kind, "bearing_deg": TransformPresenter.bearing_deg(from, c.at), "alpha": _alpha(c)})
	return out


## Drops every cue (tests).
func clear() -> void:
	_cues.clear()
	queue_redraw()


## Advances the fades by `delta` seconds.
func advance(delta: float) -> void:
	_time += delta
	for c in _cues:
		c.left -= delta
	_cues = _cues.filter(func(c: Dictionary) -> bool: return c.left > 0.0)
	queue_redraw()


## The point on the inset screen edge at `bearing_deg` (0 = top centre, 90 = right).
func edge_point(bearing_deg: float) -> Vector2:
	var b := deg_to_rad(bearing_deg)
	var dir := Vector2(sin(b), -cos(b))
	var half := size / 2.0 - Vector2(INSET_PX, INSET_PX)
	var t := minf(half.x / maxf(absf(dir.x), 1e-4), half.y / maxf(absf(dir.y), 1e-4))
	return size / 2.0 + dir * t


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	for c in cues():
		var b := deg_to_rad(c.bearing_deg)
		var dir := Vector2(sin(b), -cos(b))
		var side := dir.orthogonal()
		var p := edge_point(c.bearing_deg)
		var col := Color(COLOUR, COLOUR.a * c.alpha)
		match c.kind:
			Kind.LUNGE:
				draw_polyline([p - dir * MARK_PX * 0.4 + side * MARK_PX, p + dir * MARK_PX * 0.6,
						p - dir * MARK_PX * 0.4 - side * MARK_PX], col, 7.0, true)
			Kind.TRANSFORM:
				var r := MARK_PX * 1.6 + (0.0 if reduced_motion else sin(_time * TAU * WOBBLE_HZ) * WOBBLE_PX)
				draw_arc(p - dir * MARK_PX * 1.2, r, dir.angle() - 0.7, dir.angle() + 0.7, 24, col, 5.0, true)
			Kind.PULSE:
				for i in 5:
					draw_circle(p, MARK_PX * (1.6 - i * 0.28), Color(col, col.a * 0.18))


func _add(kind: Kind, at: Vector3, radius_m: float, secs: float) -> void:
	var from: Transform3D = _listener.call()
	if from.origin.distance_to(at) > radius_m:
		return
	_cues.append({"kind": kind, "at": at, "total": secs, "left": secs + OUT_S})
	queue_redraw()


func _alpha(c: Dictionary) -> float:
	var e: float = c.total + OUT_S - c.left
	var a := smoothstep(0.0, 1.0, minf(e / IN_S, 1.0))
	if e > c.total:
		a *= smoothstep(0.0, 1.0, 1.0 - (e - c.total) / OUT_S)
	return a
