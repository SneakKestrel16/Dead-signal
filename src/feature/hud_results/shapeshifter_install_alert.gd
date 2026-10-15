class_name ShapeshifterInstallAlert extends Control
## S6 install alert (design/ux/hud.md S6; survivor-objectives.md rule 16): a ring and label at each live
## alert's randomised centre, clamped to the screen edge like the ping markers (PingCalloutHud.place,
## ADR-0014 §7). Visible only while an alert lives; reads HudModel.install_alerts().
## Greybox colour; no art direction source yet.

const COLOUR := Color(1.0, 0.55, 0.1)
const RING_PX := 18.0
## Same as PingCalloutHud.MARKER_FONT: world marker labels are at least 20 px (BUG-0009).
const FONT_PX := 20

var _model: HudModel
var _camera: Camera3D


func _init(model: HudModel, camera: Camera3D) -> void:
	_model = model
	_camera = camera
	name = &"S6InstallAlert"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows the layer while an alert lives and a camera can place it, and redraws.
func refresh() -> void:
	visible = _camera != null and not _model.install_alerts().is_empty()
	if visible:
		queue_redraw()


func _draw() -> void:
	if _camera == null or not _camera.is_inside_tree():
		return
	var font := get_theme_default_font()
	var view := _camera.get_viewport().get_visible_rect().size
	for a in _model.install_alerts():
		var at: Vector2 = PingCalloutHud.place(_camera, a["centre"], view, PingCalloutHud.INSET_PX)[0]
		draw_arc(at, RING_PX, 0.0, TAU, 32, COLOUR, 3.0)
		var metres := roundi(_camera.global_position.distance_to(a["centre"]))
		draw_string(font, at + Vector2(-RING_PX * 2.0, RING_PX * 2.0), "%s %d m" % [tr("Install"), metres],
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, COLOUR)
