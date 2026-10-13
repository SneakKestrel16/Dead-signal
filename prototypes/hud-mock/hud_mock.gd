# PROTOTYPE - throwaway greybox of design/ux/hud.md (survivor, holding, Investigation).
# Layout only: fonts, colours and icons are placeholders until the art bible.
extends Control

const REF_H := 1080.0
const MARGIN := 48.0

var _s: float = 1.0


func _ready() -> void:
	_s = get_viewport_rect().size.y / REF_H
	_label("Ana   ● Healthy\nBen   ◐ Wounded  ◆ drive\nCy    ✚ Downed\nDee   ● Healthy", 22, Vector2(MARGIN, MARGIN), HORIZONTAL_ALIGNMENT_LEFT, 0.0)
	_label("06:42\nINVESTIGATION", 30, Vector2(0, MARGIN), HORIZONTAL_ALIGNMENT_CENTER, 0.5)
	_label("Drives  1/2  (◆ Ben)\nFuses   0/2\nTerminal  Locked", 22, Vector2(-MARGIN, MARGIN), HORIZONTAL_ALIGNMENT_RIGHT, 1.0)
	_label("Hold E   Extract drive", 22, Vector2(0, 590), HORIZONTAL_ALIGNMENT_CENTER, 0.5)
	_label("Ben: Need rescue  ↗\nDee: Over here  ←\nAna: Fuse box  ↑", 28, Vector2(MARGIN, 860), HORIZONTAL_ALIGNMENT_LEFT, 0.0)
	_label("⚡ x2", 26, Vector2(-MARGIN, 990), HORIZONTAL_ALIGNMENT_RIGHT, 1.0)
	_label("◇ Ana  12 m", 20, Vector2(1300, 470), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	_label("✚ Cy  Downed  31 m", 20, Vector2(560, 500), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	_label("[Z8 edge cue: lunge]", 16, Vector2(MARGIN + 40, 520), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	queue_redraw()


func _label(text: String, ref_size: int, ref_pos: Vector2, align: HorizontalAlignment, anchor_x: float) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", int(ref_size * _s))
	l.add_theme_color_override("font_color", Color(0.9, 0.9, 0.88))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", int(6 * _s))
	add_child(l)
	var w := get_viewport_rect().size.x
	var size := l.get_minimum_size()
	var x: float
	if anchor_x < 0.0:
		x = ref_pos.x * _s
	elif anchor_x == 0.5:
		x = (w - size.x) * 0.5
	elif anchor_x == 1.0:
		x = w + ref_pos.x * _s - size.x
	else:
		x = ref_pos.x * _s
	l.position = Vector2(x, ref_pos.y * _s)


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.06, 0.07))
	draw_rect(Rect2(Vector2(0, vp.y * 0.62), Vector2(vp.x, vp.y * 0.38)), Color(0.09, 0.1, 0.11))
	var c := vp * 0.5
	draw_circle(c, 3.0 * _s, Color(0.95, 0.95, 0.95))
	# Hold ring at 60 % (P3).
	draw_arc(c, 26.0 * _s, -PI / 2, -PI / 2 + TAU * 0.6, 48, Color(0.95, 0.95, 0.9), 4.0 * _s)
	draw_arc(c, 26.0 * _s, -PI / 2 + TAU * 0.6, -PI / 2 + TAU, 32, Color(0.4, 0.4, 0.4), 2.0 * _s)
	# Lunge chevron on the left edge (P8).
	var y := 540.0 * _s
	var x := MARGIN * _s
	draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 28 * _s, y - 22 * _s), Vector2(x + 28 * _s, y + 22 * _s)]), Color(0.95, 0.95, 0.9))
	# Safe-margin guide (mock only).
	var r := Rect2(Vector2(MARGIN, MARGIN) * _s, get_viewport_rect().size - Vector2(MARGIN, MARGIN) * 2.0 * _s)
	draw_rect(r, Color(0.3, 0.6, 0.9, 0.35), false, 1.0)
