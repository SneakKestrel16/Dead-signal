class_name OwnStateHud extends Control
## Own state on the survivor HUD (story hud-results/004; design/ux/hud.md H15, H16, HUD States by Gameplay
## Context, Information Hierarchy; interaction-patterns P11; ADR-0014 §6). A view: HudModel.hud_state() is the
## state; this widget decides nothing about life state and sends nothing.
## - H15 vignette (P11): Seized tight dark edges, Downed wide grey edges, shocked brief jittering edges; each
##   with its word above the crosshair. It fades in and out over TRANSITION_S, a cut with reduced motion,
##   which also stops the jitter. Never flashes.
## - H16 own bleed-out: in Z4 while Downed, the seconds left in the prompt's place, and a ring round the
##   crosshair filling with the rescue progress while someone rescues.
## - Z4 (hud.md Z4 rule and HUD States): Downed, Seized and spectating take Z4 from InteractionHud (no prompt
##   or ring); hidden leaves it the prompt "Leave" only. The crosshair rule is AlwaysOnHud's; ping and wheel
##   input stop while spectating in PingCalloutHud.can_act.
## - Spectating: "Spectating: [Name]" in Z2 under the clock. Roster, clock, objectives, feed and markers stay
##   as the other widgets draw them; the server streams the watched survivor's feed and markers.
## PLACEHOLDER look: plain edge bands, not P11's shader (a desaturating screen shader is the art pass's), and
## the fallback font. Reduced motion is a property until the Accessibility Options store sets it.
## Usage (client, rendering; sets model.own_id):
##   hud.add_child(OwnStateHud.new(hud_model, own_id, interaction))

## hud.md H15: the vignette transition takes 250 ms.
const TRANSITION_S := 0.25
## Layout, 1080p reference. Edge widths and colours are PLACEHOLDER (P11 names the treatments, no sizes).
const SEIZED_EDGE_PX := 140.0
const DOWNED_EDGE_PX := 260.0
const SHOCKED_EDGE_PX := 90.0
const SEIZED_COLOUR := Color(0.0, 0.0, 0.0, 0.85)
const DOWNED_COLOUR := Color(0.35, 0.35, 0.38, 0.8)
const SHOCKED_COLOUR := Color(0.3, 0.55, 1.0, 0.6) ## ShockPresenter.EDGE_COLOUR's hue
const BANDS := 48
## Shocked edge jitter amplitude and rate (P11 "brief edge jitter"; visual offset only). PLACEHOLDER.
const JITTER_PX := 6.0
const JITTER_HZ := 25.0
const WORD_ABOVE_PX := 90.0
const BLEED_BELOW_PX := 60.0 ## InteractionHud.PROMPT_BELOW_PX: the bleed-out takes the prompt's place
const RING_RADIUS_PX := 26.0 ## InteractionHud.RING_RADIUS_PX
const RING_WIDTH_PX := 5.0
## Below AlwaysOnHud's Z2 clock plate (clock, phase, activation lines at HUD scale 1).
const SPECTATE_TOP_PX := 230.0
const FONT_PX := 28 ## hud.md Accessibility: critical HUD text at least 20 px
const PLATE := Color(0, 0, 0, 0.6)

## Reduced motion (hud.md Accessibility): the vignette cuts and the jitter is off.
var reduced_motion := false

var _model: HudModel
var _interaction: InteractionHud
var _state := HudModel.STATE_NONE
var _edge := HudModel.STATE_NONE ## the vignette drawn (kept while it fades out)
var _alpha := 0.0
var _clock := 0.0


## `interaction`: the Z4 prompt widget this one takes Z4 from (null: none, e.g. a non-rendering test).
func _init(model: HudModel, own_id: int, interaction: InteractionHud = null) -> void:
	_model = model
	_model.own_id = own_id
	_interaction = interaction
	name = &"OwnStateHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Vignette opacity 0-1.
func vignette() -> float:
	return _alpha


## The state word shown with the vignette ("" when none).
func word() -> String:
	match _state:
		HudModel.STATE_DOWNED: return tr("Downed")
		HudModel.STATE_SEIZED: return tr("Seized")
		HudModel.STATE_SHOCKED: return tr("Shocked")
	return ""


## H16: own bleed-out seconds as drawn in Z4 ("" when not Downed or no ring is known).
func bleed_text() -> String:
	var left := _model.bleed_out_s()
	if _state != HudModel.STATE_DOWNED or left < 0.0:
		return ""
	return tr("%d s") % ceili(left)


## H16: rescue ring fill 0-1 (0 when nobody rescues).
func rescue_fill() -> float:
	return _model.rescue_fill() if _state == HudModel.STATE_DOWNED else 0.0


## The Z2 spectating label ("" when not spectating).
func spectating_text() -> String:
	if _state != HudModel.STATE_SPECTATING:
		return ""
	var w := _model.watched()
	if w < 0:
		return tr("Spectating")
	var n := _model.name_of(w)
	return tr("Spectating: %s") % (n if n != "" else tr("Survivor %d") % w)


## The shocked edges' offset now (zero when not shocked or with reduced motion).
func jitter() -> Vector2:
	if _edge != HudModel.STATE_SHOCKED or reduced_motion or _alpha <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(_clock * TAU * JITTER_HZ), cos(_clock * TAU * JITTER_HZ * 0.7)) * JITTER_PX


## Reads the state, runs the transition and sets Z4. Called every frame.
func step(delta: float) -> void:
	_clock += delta
	_state = _model.hud_state()
	var vignetted := _state in [HudModel.STATE_DOWNED, HudModel.STATE_SEIZED, HudModel.STATE_SHOCKED]
	if vignetted and _state != _edge:
		_edge = _state
		_alpha = 0.0 if not reduced_motion else 1.0
	var target := 1.0 if vignetted else 0.0
	_alpha = target if reduced_motion else move_toward(_alpha, target, delta / TRANSITION_S)
	if _alpha <= 0.0 and not vignetted:
		_edge = HudModel.STATE_NONE
	if _interaction != null:
		_interaction.z4_taken = _state in [HudModel.STATE_DOWNED, HudModel.STATE_SEIZED, HudModel.STATE_SPECTATING]
		_interaction.only_prompt = {"text": "Leave", "hold": true} if _state == HudModel.STATE_HIDDEN else {}
	queue_redraw()


## Drawn first in its layer: the edges never cover the other widgets' text (hud.md Accessibility contrast).
func _ready() -> void:
	get_parent().move_child.call_deferred(self, 0)


func _process(delta: float) -> void:
	step(delta)


func _draw() -> void:
	if _alpha > 0.0:
		match _edge:
			HudModel.STATE_SEIZED: _edges(SEIZED_EDGE_PX, SEIZED_COLOUR, Vector2.ZERO)
			HudModel.STATE_DOWNED: _edges(DOWNED_EDGE_PX, DOWNED_COLOUR, Vector2.ZERO)
			HudModel.STATE_SHOCKED: _edges(SHOCKED_EDGE_PX, SHOCKED_COLOUR, jitter())
	var c := size / 2.0
	var w := word()
	if w != "":
		_text(c - Vector2(0, WORD_ABOVE_PX), w, maxf(_alpha, 0.0))
	var b := bleed_text()
	if b != "":
		_text(c + Vector2(0, BLEED_BELOW_PX), b, 1.0)
		var fill := rescue_fill()
		if fill > 0.0:
			draw_arc(c, RING_RADIUS_PX, 0.0, TAU, 48, Color(0, 0, 0, 0.6), RING_WIDTH_PX + 2.0)
			draw_arc(c, RING_RADIUS_PX, -PI / 2.0, -PI / 2.0 + TAU * fill, 48, Color.WHITE, RING_WIDTH_PX)
	var s := spectating_text()
	if s != "":
		_text(Vector2(c.x, SPECTATE_TOP_PX), s, 1.0)


## Edge bands, opaque at the screen edge and clear `width` inside it, scaled by the transition.
func _edges(width: float, colour: Color, offset: Vector2) -> void:
	var r := Rect2(offset, size)
	var band := width / BANDS
	for i in BANDS:
		var col := colour
		col.a *= _alpha * (1.0 - float(i) / BANDS)
		var inset := band * i
		var inner := r.grow(-inset)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, band)), col)
		draw_rect(Rect2(inner.position.x, inner.end.y - band, inner.size.x, band), col)
		draw_rect(Rect2(inner.position.x, inner.position.y + band, band, inner.size.y - 2.0 * band), col)
		draw_rect(Rect2(inner.end.x - band, inner.position.y + band, band, inner.size.y - 2.0 * band), col)


func _text(at: Vector2, t: String, alpha: float) -> void:
	var font := get_theme_default_font()
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x
	draw_rect(Rect2(at.x - w / 2.0 - 10, at.y - FONT_PX - 4, w + 20, FONT_PX + 14), Color(PLATE, PLATE.a * alpha))
	draw_string(font, Vector2(at.x - w / 2.0, at.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, Color(1, 1, 1, alpha))
