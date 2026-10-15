class_name InteractionHud extends Control
## Z4 centre and Z5 label (story hud-results/003; design/ux/hud.md H7-H9 and the Z4 rule; interaction-patterns
## P2, P3, P10, P18; ADR-0014 §6, §8). A view: it decides nothing and sends nothing.
## - Prompt (H7): "Hold E  Extract drive" below the crosshair while the local target query finds a target;
##   "Press" for an instant one. The glyph follows the last-used device (InputGlyphs).
## - Ring (H8): drawn round the crosshair from PredictedHoldBar's value (predicted, replaced by the server
##   echo there). When the bar ends, a cancel breaks the ring into segments for RING_END_S (shape, not colour)
##   and its cause shows in the label; a completion shows the full ring for RING_END_S.
## - Label (H9/Z5): a refused Start shows "Not now" for REJECT_S; one label at a time, the newest wins. Story 011:
##   the server's reason (EventBatch.HOLD_END, on_hold_end) replaces "Not now" / "Interrupted" with its text.
##   The bar's end (unreliable snapshot) and the reason (reliable batch) arrive in either order: a reason that
##   finds a generic hold label showing replaces it, otherwise it waits REJECT_S for the bar's end.
## - Z4 holds one of prompt, ring, bleed-out or transforming bar: `z4_taken` (set by the bleed-out and transform
##   widgets) hides prompt and ring. While actions are masked (callout wheel, overlays) nothing here shows.
## PLACEHOLDER look: plain shapes and the fallback font; the HUD art pass replaces the drawing, not the states.
## reduced_motion turns the 150 ms fades into cuts (hud.md Accessibility; BUG-0008).
## Usage (client, rendering): hud.add_child(InteractionHud.new(InputGlyphs.new(), contexts, bar, prompt_of))
##   where prompt_of() -> {text: String, hold: bool}, or {} for no valid target.

## interaction-patterns Animation Standards: HUD appear/disappear 150 ms; hold cancel / completion 200 ms.
const FADE_S := 0.15
const RING_END_S := 0.2
## hud.md H9 / P10: a refusal shows 1.5 s.
const REJECT_S := 1.5
## P3: the cancel cause label shows 1 s. (The story's AC reads "200 ms"; that is H8's animation column, kept as
## RING_END_S for the broken ring. Inference; a ux-designer ruling would settle it.)
const CAUSE_S := 1.0
## Layout, 1080p reference (hud.md Z4 "within 6% of height"; P2/P10 20 px minimum text). Sizes placeholder.
const RING_RADIUS_PX := 26.0
const RING_WIDTH_PX := 5.0
const RING_SEGMENTS := 8
const PROMPT_BELOW_PX := 60.0
const LABEL_BELOW_PX := 100.0
const FONT_PX := 22

## True while a bleed-out or transforming bar owns Z4 (hud.md Z4 rule), or nothing may show there (Seized,
## spectating; story 004).
var z4_taken := false
## Accessibility reduced motion: prompt and label appear and disappear at full alpha (set by RoundClient).
var reduced_motion := false
## When not empty, the only prompt shown ({text, hold}), whatever the target (hud.md HUD States, Hidden: the
## prompt shows "Leave" only; set by OwnStateHud, story 004).
var only_prompt: Dictionary = {}

var _glyphs: InputGlyphs
var _contexts: InputContextStack
var _bar: PredictedHoldBar
var _prompt_of: Callable
var _action: StringName
var _prompt := ""
var _prompt_age := 0.0
var _end := &""
var _end_s := 0.0
var _end_value := 0.0
var _label := ""
var _label_s := 0.0
var _shown := &""
var _generic := false ## the label is a hold end's generic text: a server reason may replace it
var _reason := ""
var _reason_s := 0.0


## `prompt_of() -> Dictionary` ({text, hold} or {}); `action` names the input the prompt shows.
func _init(glyphs: InputGlyphs, contexts: InputContextStack, bar: PredictedHoldBar, prompt_of: Callable,
		action: StringName = &"interact") -> void:
	_glyphs = glyphs
	_contexts = contexts
	_bar = bar
	_prompt_of = prompt_of
	_action = action
	_bar.ended.connect(on_hold_ended)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


## Untranslated "verb object" for a map interactable (P2). Inference for objective types, as in
## RoundClient.duration_of: the marker type alone cannot tell a dock from a pickup.
static func verb_object(target: Resource, monster: bool) -> String:
	if target is MapPassage:
		return "Use door"
	match (target as MapMarker).type:
		&"hiding": return "Search" if monster else "Hide"
		&"switch": return "Flip switch"
		&"monitor": return "Use monitor"
		&"drive": return "Extract drive"
		&"fuse": return "Take fuse"
		&"fuse_box": return "Install fuse"
		&"terminal": return "Start terminal"
	return "Use"


## What Z4 shows now: &"prompt", &"ring", &"cancel", &"complete" or &"" (crosshair only).
func shown() -> StringName:
	return _shown


## The prompt line as drawn ("" when no prompt shows).
func prompt_text() -> String:
	return _prompt if _shown == &"prompt" else ""


## Ring fill 0-1 (the predicted bar's value, or the value it ended at).
func ring_value() -> float:
	return _bar.value if _shown == &"ring" else _end_value


## The Z5 label as drawn ("" when hidden).
func label_text() -> String:
	return _label if _label_s > 0.0 and _contexts.allows_actions() else ""


## Alpha of the prompt as drawn: fades in over FADE_S, 1 with reduced motion.
func prompt_alpha() -> float:
	return 1.0 if reduced_motion else minf(_prompt_age / FADE_S, 1.0)


## Alpha of the Z5 label as drawn: fades out over FADE_S, 1 with reduced motion.
func label_alpha() -> float:
	return 1.0 if reduced_motion else minf(_label_s / FADE_S, 1.0)


## Shows the generic refusal label (P10); a server reason (on_hold_end) replaces it when one comes.
func refuse() -> void:
	_set_label(tr("Not now"), REJECT_S)


## PredictedHoldBar.ended handler.
func on_hold_ended(cause: StringName) -> void:
	_end_value = _bar.value
	match cause:
		&"refused":
			refuse()
			_take_reason()
			return
		&"completed":
			_end = &"complete"
		&"released":
			_end = &"cancel"
			_set_label(tr("Released"), CAUSE_S)
		_:
			_end = &"cancel"
			_set_label(tr("Interrupted"), CAUSE_S)
			_take_reason()
	_end_s = RING_END_S


## ClientEventRouter handler for EventBatch.HOLD_END (HoldReasonFeed): {reason} of the own hold's refusal or
## cancel. Unknown reasons are ignored.
func on_hold_end(_tick: int, p: Dictionary) -> void:
	var r: Variant = p.get("reason")
	if not (r is StringName and HoldReasonFeed.TEXT.has(r)):
		return
	_reason = tr(HoldReasonFeed.TEXT[r])
	_reason_s = REJECT_S
	if _generic and _label_s > 0.0:
		_take_reason()


## After a hold end's generic label: shows the waiting server reason instead, or marks the label replaceable.
func _take_reason() -> void:
	_generic = _reason_s <= 0.0
	if not _generic:
		_label = _reason
		_reason_s = 0.0


## Advances timers and picks what Z4 shows. Called every frame.
func step(delta: float) -> void:
	_label_s = maxf(_label_s - delta, 0.0)
	_reason_s = maxf(_reason_s - delta, 0.0)
	_end_s = maxf(_end_s - delta, 0.0)
	var p: Dictionary = only_prompt if not only_prompt.is_empty() else _prompt_of.call()
	var was := _prompt
	_prompt = ""
	if not p.is_empty():
		_prompt = "%s %s  %s" % [tr("Hold") if p.get("hold", false) else tr("Press"), _glyphs.glyph_text(_action),
			tr(p.get("text", ""))]
	if _prompt == "" or was == "":
		_prompt_age = 0.0
	_prompt_age += delta
	if z4_taken or not _contexts.allows_actions():
		_shown = &""
	elif _bar.visible:
		_shown = &"ring"
	elif _end_s > 0.0:
		_shown = _end
	elif _prompt != "":
		_shown = &"prompt"
	else:
		_shown = &""
	queue_redraw()


func _process(delta: float) -> void:
	step(delta)


func _input(event: InputEvent) -> void:
	_glyphs.note_event(event)


func _set_label(text: String, seconds: float) -> void:
	_generic = false
	_label = text
	_label_s = seconds


func _draw() -> void:
	var c := size / 2.0
	match _shown:
		&"ring", &"complete":
			draw_arc(c, RING_RADIUS_PX, 0.0, TAU, 48, Color(0, 0, 0, 0.6), RING_WIDTH_PX + 2.0)
			draw_arc(c, RING_RADIUS_PX, -PI / 2.0, -PI / 2.0 + TAU * ring_value(), 48, Color.WHITE, RING_WIDTH_PX)
		&"cancel":
			var a := 1.0 if reduced_motion else _end_s / RING_END_S
			for i in RING_SEGMENTS: # broken ring: gaps between segments, fading out
				var s := -PI / 2.0 + TAU * i / RING_SEGMENTS
				draw_arc(c, RING_RADIUS_PX, s, s + TAU / RING_SEGMENTS * 0.55, 8, Color(1, 1, 1, a), RING_WIDTH_PX)
		&"prompt":
			_text(c + Vector2(0, PROMPT_BELOW_PX), _prompt, prompt_alpha())
	var l := label_text()
	if l != "":
		_text(c + Vector2(0, LABEL_BELOW_PX), l, label_alpha())


func _text(at: Vector2, t: String, alpha: float) -> void:
	var font := get_theme_default_font()
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x
	draw_rect(Rect2(at.x - w / 2.0 - 10, at.y - FONT_PX - 4, w + 20, FONT_PX + 14), Color(0, 0, 0, 0.8 * alpha))
	draw_string(font, Vector2(at.x - w / 2.0, at.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX,
		Color(1, 1, 1, alpha))
