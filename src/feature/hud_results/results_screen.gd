class_name ResultsScreen extends CanvasLayer
## The Results screen (story hud-results/008; design/ux/results.md R1-R8, States, Interaction Map,
## Accessibility; ADR-0014 §1, §5, §9; ADR-0011 §4). Shown at round end over the frozen round, on the
## OVERLAY layer so the in-round HUD stays under it. It presents one RoundEnded payload
## (RoundResults.to_dict()) and decides nothing: present() maps the payload to display text, and the screen
## builds stock Controls from that. An owner listed in the payload's `missing` shows "Results unavailable"
## for each of its figures, never 0 (AD-229); a field of the wrong type or range makes its zone show
## "Results unavailable" (payload error, AD-32), logged with push_warning; R1 and R2 stay if they are valid.
## Input: MENU is pushed on enter and popped on exit; Leave session opens a P29 confirm under MODAL (focus on
## Stay, Esc = Stay) that closes itself when the countdown reaches 0. No initial focus (Interaction Map); the
## first Down / Tab focuses the first stop, Up / Shift+Tab the last. Esc / B do nothing on this screen.
## Deviations: no enter fade or 200 ms stagger (no reduced-motion setting exists yet, so the spec's
## reduced-motion cut is used for everyone); the countdown runs on local time from show, cosmetic (the
## server's return to the lobby wins). "Survivor stuns landed" and
## "Rescues" in Z4 are sums of the payload's survivor rows (inference from the wireframe: the payload has no
## round totals for them; match-flow.md rule 26 settles whether they should).
## Last round view (story hud-results/009; results.md Entry & Exit, R9, AD-31): last_round() builds a read-only
## copy for the lobby: title "Last round" above R1, no countdown and no Leave session (R7, R8), a Back button
## (R9) with initial focus; Back, Esc or B emit `closed` and the owner frees the screen. MENU is pushed with
## Back focused, so the pop on exit restores focus to the control that opened it.
## Usage: var s := ResultsScreen.new(display.results(), knobs.match_flow.results_duration_s, contexts)
##   add_child(s); s.leave_confirmed.connect(_on_leave)
##   var v := ResultsScreen.last_round(payload, contexts); v.closed.connect(_on_closed); add_child(v)

## The player confirmed Leave session (the caller disconnects; results.md Events Fired).
signal leave_confirmed
## Last round view: the player chose Back (the owner frees the screen).
signal closed

const BODY_PX := 24 ## menu text minimum at 1080p (results.md Accessibility)
const OUTCOME_PX := 48 ## R1 minimum
const SAFE_MARGIN_PX := 48
const UNAVAILABLE := "Results unavailable"
## Greybox colours; no art-direction spec yet (results.md Open Questions: final visual treatment).
## Opaque: a translucent backdrop let the frozen HUD's objective counts show behind "Results unavailable".
const BACKDROP := Color(0.04, 0.04, 0.05)
const RING := Color(0.92, 0.92, 0.85)

const OUTCOME_TEXT: Array[String] = ["SURVIVORS WIN", "SHAPESHIFTER WINS"] # by MatchFlow.Outcome
const OUTCOME_A11Y: Array[String] = ["Survivors win", "Shapeshifter wins"]
const FATE_TEXT := {MatchFlow.Status.ESCAPED: "Escaped", MatchFlow.Status.ELIMINATED: "Eliminated",
	MatchFlow.Status.DID_NOT_ESCAPE: "Did not escape", MatchFlow.Status.DISCONNECTED: "Disconnected"}
## DowningStatsView.get_fate_cause values. "Taken down" is inferred wording: results.md names only "Bled out".
const CAUSE_TEXT := {"": "", "bled_out": "Bled out", "takedown": "Taken down"}
const OBJECTIVE_TEXT := {"drives_recovered": "Drives recovered", "drives_docked": "Drives docked",
	"fuses_installed": "Fuses installed", "evacuation_activated": "Evacuation active",
	"drives_extracted": "Drives extracted"}
## Z4 rows in wireframe order: [monster key, label format, owning stats key].
const STATS := [[&"takedowns", "Takedowns %s", StateKeys.STATS_DOWNING],
	[&"eliminations", "Eliminations %s", StateKeys.STATS_DOWNING],
	[&"lunges_landed", "Lunges landed %s", StateKeys.STATS_ABILITIES],
	[&"lunges_missed", "Lunges missed %s", StateKeys.STATS_ABILITIES],
	[&"lunges_interrupted", "Lunges interrupted %s", StateKeys.STATS_ABILITIES],
	[&"times_stunned", "Stunned %s", StateKeys.STATS_DEFENSE],
	[&"form_changes", "Form changes %s", StateKeys.STATS_BORROWED_FACE],
	[&"false_signals", "False Signals %s", StateKeys.STATS_ABILITIES],
	[&"blackouts", "Blackouts %s", StateKeys.STATS_ABILITIES]]

## Focus stops in the spec's order: outcome group, each survivor row, R4, objectives, stats, Leave session.
var focus_stops: Array[Control] = []
var outcome_label: Label
var countdown: Label
var leave_button: Button ## null in the Last round view
var confirm: ConfirmationDialog ## null in the Last round view
var title_label: Label ## Last round view only
var back_button: Button ## R9, Last round view only

var _view: Dictionary
var _left_s: float
var _shown_n := -1
var _contexts: InputContextStack
var _menu := false
var _modal := false
var _last_round := false
var _ring := StyleBoxFlat.new()
var _plain := StyleBoxEmpty.new()


## `payload`: RoundResults.to_dict() as received. `results_duration_s`: the countdown start; NAN hides it.
## `contexts`: the client's InputContextStack, or null (no context bookkeeping).
func _init(payload: Dictionary, results_duration_s: float, contexts: InputContextStack = null) -> void:
	_view = present(payload)
	for e: String in _view.errors:
		push_warning("ResultsScreen: unusable payload field %s" % e)
	_left_s = results_duration_s
	_contexts = contexts
	layer = UiLayers.OVERLAY


## The read-only Last round view of `payload` (R9): no countdown, Back instead of Leave session.
static func last_round(payload: Dictionary, contexts: InputContextStack = null) -> ResultsScreen:
	var s := ResultsScreen.new(payload, NAN, contexts)
	s._last_round = true
	return s


## The payload as display text. Keys: outcome, reason, outcome_a11y (R1, R2); survivors (rows of name,
## fate, phrase, detail, a11y) and survivors_ok; shapeshifter, shapeshifter_a11y (R4); objectives (rows of
## label, count, time) and objectives_ok; stats (Z4 lines) and stats_ok; errors (unusable field names).
## A zone whose *_ok is false shows "Results unavailable" instead of its rows.
static func present(p: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var miss := PackedStringArray()
	var m: Variant = p.get("missing", [])
	if m is Array:
		for k: Variant in m:
			miss.append(str(k))
	else:
		errors.append("missing")
		for k in [StateKeys.STATS_DOWNING, StateKeys.STATS_ABILITIES, StateKeys.STATS_DEFENSE,
				StateKeys.STATS_BORROWED_FACE, StateKeys.STATS_OBJECTIVES]:
			miss.append(String(k))
	var unav := _t(UNAVAILABLE)
	var v := {"errors": errors}

	# Z1: R1 and R2
	var o: Variant = p.get("outcome")
	var r: Variant = p.get("reason")
	var d: Variant = p.get("duration_s")
	var o_ok: bool = o is int and o >= 0 and o < OUTCOME_TEXT.size()
	var r_ok: bool = r is int and r >= 0 and r < MatchFlow.REASON_TEXT.size()
	var d_ok: bool = (d is float or d is int) and is_finite(d) and d >= 0
	for f: Array in [["outcome", o_ok], ["reason", r_ok], ["duration_s", d_ok]]:
		if not f[1]:
			errors.append(f[0])
	var reason := _t(MatchFlow.REASON_TEXT[r]) if r_ok else unav
	v.outcome = _t(OUTCOME_TEXT[o]) if o_ok else unav
	v.reason = _t("%s  ·  %s") % [reason, clock(d)] if r_ok and d_ok else reason
	v.outcome_a11y = _t("%s. %s at %d minutes %d") % [_t(OUTCOME_A11Y[o]) if o_ok else unav, reason,
		int(roundf(d)) / 60, int(roundf(d)) % 60] if d_ok else "%s. %s" % [v.outcome, reason]

	# Z2: survivor rows, then R4
	var downing_gone := miss.has(String(StateKeys.STATS_DOWNING))
	var defense_gone := miss.has(String(StateKeys.STATS_DEFENSE))
	var objectives_gone := miss.has(String(StateKeys.STATS_OBJECTIVES))
	var rows: Array[Dictionary] = []
	var stuns_total := 0
	var rescues_total := 0
	var surv: Variant = p.get("survivors")
	v.survivors_ok = surv is Array
	if not v.survivors_ok:
		errors.append("survivors")
	else:
		for i in (surv as Array).size():
			var row := _survivor(surv[i], downing_gone, defense_gone, objectives_gone)
			if row.is_empty():
				errors.append("survivors[%d]" % i)
				v.survivors_ok = false
				break
			rows.append(row)
			stuns_total += surv[i].stuns_landed
			rescues_total += surv[i].rescues
	v.survivors = rows if v.survivors_ok else []
	var ss: Variant = p.get("shapeshifter_name", "")
	if not ss is String:
		errors.append("shapeshifter_name")
		ss = ""
	var ss_name: String = ss if ss != "" else _t("unknown")
	var forfeit: bool = r_ok and r == MatchFlow.Reason.FORFEIT
	v.shapeshifter = (_t("Shapeshifter: %s (disconnected)") if forfeit else _t("Shapeshifter: %s")) % ss_name
	v.shapeshifter_a11y = _t("Shapeshifter: %s, disconnected, forfeited") % ss_name if forfeit else v.shapeshifter

	# Z3: objective lines
	var objs: Array[Dictionary] = []
	var ob: Variant = p.get("objectives")
	v.objectives_ok = not objectives_gone and ob is Array
	if not objectives_gone and not ob is Array:
		errors.append("objectives")
	if v.objectives_ok:
		for i in (ob as Array).size():
			var line := _objective(ob[i])
			if line.is_empty():
				errors.append("objectives[%d]" % i)
				v.objectives_ok = false
				break
			objs.append(line)
	v.objectives = objs if v.objectives_ok else []

	# Z4: stats
	var stats := PackedStringArray([_t("Match %s") % (clock(d) if d_ok else unav)])
	var mon: Variant = p.get("monster")
	v.stats_ok = mon is Dictionary
	if not v.stats_ok:
		errors.append("monster")
	else:
		for s: Array in STATS:
			if miss.has(String(s[2])):
				stats.append(_t(s[1]) % unav)
				continue
			var n: Variant = mon.get(s[0], mon.get(String(s[0])))
			if not (n is int and n >= 0):
				errors.append("monster.%s" % s[0])
				v.stats_ok = false
				break
			stats.append(_t(s[1]) % n)
		var rows_ok: bool = v.survivors_ok
		stats.append(_t("Survivor stuns landed %s") % (stuns_total if rows_ok and not defense_gone else unav))
		stats.append(_t("Rescues %s") % (rescues_total if rows_ok and not downing_gone else unav))
	v.stats = stats if v.stats_ok else PackedStringArray()
	return v


## Round seconds as m:ss.
static func clock(seconds: float) -> String:
	var t := int(roundf(seconds))
	return "%d:%02d" % [t / 60, t % 60]


## One survivor row's text, or {} when a field is unusable.
static func _survivor(s: Variant, downing_gone: bool, defense_gone: bool, objectives_gone: bool) -> Dictionary:
	if not s is Dictionary:
		return {}
	var name: Variant = s.get("name")
	var fate: Variant = s.get("fate")
	var cause: Variant = s.get("cause")
	if not (name is String and FATE_TEXT.has(fate) and cause is String and CAUSE_TEXT.has(cause)):
		return {}
	for k in ["drives_carried", "downs", "rescues", "stuns_landed"]:
		var n: Variant = s.get(k)
		if not (n is int and n >= 0):
			return {}
	var unav := _t(UNAVAILABLE)
	var shown_name: String = name if name != "" else _t("Unknown player")
	var fate_text := _t(FATE_TEXT[fate])
	var phrase := ""
	var fate_a11y := fate_text.to_lower()
	var drives: int = s.drives_carried
	if fate == MatchFlow.Status.ESCAPED and objectives_gone:
		phrase = _t("(drives: %s)") % unav
		fate_a11y = _t("escaped, drives: %s") % unav
	elif fate == MatchFlow.Status.ESCAPED and drives > 0:
		phrase = TranslationServer.translate_plural("(%d drive)", "(%d drives)", drives) % drives
		fate_a11y = TranslationServer.translate_plural("escaped with %d drive", "escaped with %d drives", drives) \
				% drives
	elif fate == MatchFlow.Status.ELIMINATED and downing_gone:
		phrase = _t("(cause: %s)") % unav
		fate_a11y += ", " + _t("cause: %s") % unav
	elif fate == MatchFlow.Status.ELIMINATED and cause != "":
		phrase = _t("(%s)") % _t(CAUSE_TEXT[cause])
		fate_a11y += ", " + _t(CAUSE_TEXT[cause]).to_lower()
	var downs: String = unav if downing_gone else str(s.downs)
	var rescues: String = unav if downing_gone else str(s.rescues)
	var stuns: String = unav if defense_gone else str(s.stuns_landed)
	var a11y := PackedStringArray([shown_name, fate_a11y,
		_t("downs: %s") % unav if downing_gone else _plural("%d down", "%d downs", s.downs),
		_t("rescues: %s") % unav if downing_gone else _plural("%d rescue", "%d rescues", s.rescues),
		_t("stuns landed: %s") % unav if defense_gone else _plural("%d stun landed", "%d stuns landed", s.stuns_landed)])
	return {"name": shown_name, "fate": fate_text, "phrase": phrase,
		"detail": _t("downs %s · rescues %s · stuns %s") % [downs, rescues, stuns], "a11y": ", ".join(a11y)}


## One objective line's text, or {} when a field is unusable.
static func _objective(o: Variant) -> Dictionary:
	if not o is Dictionary:
		return {}
	var line: Variant = o.get("line")
	var count: Variant = o.get("count")
	var of: Variant = o.get("of")
	var done: Variant = o.get("completed_s")
	if not (OBJECTIVE_TEXT.has(line) and count is int and count >= 0 and of is int and of >= 1
			and (done is float or done is int) and is_finite(done)):
		return {}
	var count_text: String
	if line == "evacuation_activated":
		count_text = _t("Yes") if count > 0 else _t("No")
	else:
		count_text = "%d/%d" % [count, of]
	return {"label": _t(OBJECTIVE_TEXT[line]), "count": count_text, "time": clock(done) if done >= 0 else "—"}


static func _t(s: String) -> String:
	return TranslationServer.translate(s)


static func _plural(one: String, many: String, n: int) -> String:
	return TranslationServer.translate_plural(one, many, n) % n


func _ready() -> void:
	_ring.draw_center = false
	_ring.set_border_width_all(3)
	_ring.border_color = RING
	_ring.set_content_margin_all(8)
	_plain.set_content_margin_all(8)
	var theme := Theme.new()
	theme.default_font_size = BODY_PX
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	var bg := ColorRect.new()
	bg.color = BACKDROP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var aspect := AspectRatioContainer.new() # 21:9: content in a centred 16:9 rect (results.md Layout)
	aspect.ratio = 16.0 / 9.0
	aspect.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(aspect)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, SAFE_MARGIN_PX)
	aspect.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)

	if _last_round:
		title_label = _label(page, tr("Last round"))
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var z1 := _stop(page, _view.outcome_a11y)
	var z1_box := VBoxContainer.new()
	z1.add_child(z1_box)
	outcome_label = _label(z1_box, _view.outcome, true)
	outcome_label.add_theme_font_size_override(&"font_size", OUTCOME_PX)
	outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(z1_box, _view.reason, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var scroll := ScrollContainer.new() # P28: Z2-Z4 scroll, Z1 and Z5 never do
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.focus_mode = Control.FOCUS_NONE
	page.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	body.add_child(columns)
	var z2 := VBoxContainer.new()
	z2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(z2)
	if not _view.survivors_ok:
		_label(z2, _t(UNAVAILABLE))
	for row: Dictionary in _view.survivors:
		var box := VBoxContainer.new()
		_stop(z2, row.a11y).add_child(box)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 16)
		box.add_child(top)
		_label(top, row.name).custom_minimum_size.x = 200
		_label(top, row.fate)
		if row.phrase != "":
			_label(top, row.phrase)
		var indent := MarginContainer.new()
		indent.add_theme_constant_override("margin_left", 32)
		box.add_child(indent)
		_label(indent, row.detail, true)
	_label(_stop(z2, _view.shapeshifter_a11y), _view.shapeshifter, true)

	var objective_lines := PackedStringArray()
	for o: Dictionary in _view.objectives:
		objective_lines.append("%s %s %s" % [o.label, o.count, o.time])
	var z3 := _stop(columns, "; ".join(objective_lines) if _view.objectives_ok else _t(UNAVAILABLE))
	z3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _view.objectives_ok:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 24)
		z3.add_child(grid)
		for o: Dictionary in _view.objectives:
			_label(grid, o.label)
			_label(grid, o.count)
			_label(grid, o.time)
	else:
		_label(z3, _t(UNAVAILABLE))

	var z4 := _stop(body, "; ".join(_view.stats) if _view.stats_ok else _t(UNAVAILABLE))
	var flow := HFlowContainer.new() # reflows to more rows rather than truncating (Localization)
	flow.add_theme_constant_override("h_separation", 32)
	z4.add_child(flow)
	if not _view.stats_ok:
		_label(flow, _t(UNAVAILABLE))
	for s: String in _view.stats:
		_label(flow, s)

	var footer := HBoxContainer.new()
	page.add_child(footer)
	countdown = _label(footer, "") # never a live region (ADR-0014 §9)
	countdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _last_round:
		back_button = Button.new()
		back_button.text = tr("Back")
		back_button.pressed.connect(closed.emit)
		footer.add_child(back_button)
		focus_stops.append(back_button)
		_link_focus()
		countdown.hide()
		if _contexts != null:
			_contexts.push(InputContextStack.Ctx.MENU, back_button) # initial focus on R9
			_menu = true
		else:
			back_button.grab_focus.call_deferred()
		return
	leave_button = Button.new()
	leave_button.text = tr("Leave session")
	leave_button.accessibility_name = tr("Leave session")
	leave_button.pressed.connect(_on_leave_pressed)
	footer.add_child(leave_button)
	focus_stops.append(leave_button)
	_link_focus()

	confirm = ConfirmationDialog.new() # P29
	confirm.theme = theme
	confirm.title = tr("Leave session")
	confirm.dialog_text = tr("Leave this session?")
	confirm.ok_button_text = tr("Leave")
	confirm.cancel_button_text = tr("Stay")
	confirm.confirmed.connect(_on_leave_confirmed)
	confirm.visibility_changed.connect(_on_confirm_visibility)
	add_child(confirm)
	_tick_countdown()
	if _contexts != null:
		_contexts.push(InputContextStack.Ctx.MENU, null) # no initial focus on the live screen
		_menu = true


func _exit_tree() -> void:
	_pop_modal()
	if _menu:
		_menu = false
		_contexts.pop(InputContextStack.Ctx.MENU)


func _process(delta: float) -> void:
	if is_nan(_left_s):
		return
	_left_s = maxf(0.0, _left_s - delta)
	_tick_countdown()


func _unhandled_input(event: InputEvent) -> void:
	if confirm != null and confirm.visible:
		return
	if event.is_action_pressed(&"ui_cancel"): # Esc / B: Back in the Last round view, nothing live (AD-30)
		get_viewport().set_input_as_handled()
		if _last_round:
			closed.emit()
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	# Nothing is focused at first; the first navigation key enters the stops from the matching end.
	if event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_focus_next"):
		focus_stops[0].grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_focus_prev"):
		focus_stops[focus_stops.size() - 1].grab_focus()
		get_viewport().set_input_as_handled()


func _tick_countdown() -> void:
	if is_nan(_left_s):
		countdown.hide()
		return
	var n := ceili(_left_s)
	if n == _shown_n:
		return
	_shown_n = n
	countdown.text = tr("Returning to lobby in %d") % n
	leave_button.accessibility_name = tr("Leave session, returning to lobby in %d seconds") % n
	if n == 0 and confirm.visible: # P29: closes without acting when its context ends
		confirm.hide()


## A focusable group (P23 row or zone) with one accessible name and a shape focus ring.
func _stop(parent: Node, a11y: String) -> PanelContainer:
	var c := PanelContainer.new()
	c.focus_mode = Control.FOCUS_ALL
	c.accessibility_name = a11y
	c.add_theme_stylebox_override(&"panel", _plain)
	c.focus_entered.connect(_on_stop_focus.bind(c, true))
	c.focus_exited.connect(_on_stop_focus.bind(c, false))
	parent.add_child(c)
	focus_stops.append(c)
	return c


## `wrap` only where the parent sets the width: an autowrapped Label in an HBox or Grid has no minimum width.
func _label(parent: Node, text: String, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


## Up/Down and Tab walk the stops in order; Left/Right stay put. No wrap at either end.
func _link_focus() -> void:
	var last := focus_stops.size() - 1
	for i in focus_stops.size():
		var c := focus_stops[i]
		var prev := c.get_path_to(focus_stops[maxi(i - 1, 0)])
		var next := c.get_path_to(focus_stops[mini(i + 1, last)])
		c.focus_neighbor_top = prev
		c.focus_previous = prev
		c.focus_neighbor_bottom = next
		c.focus_next = next
		c.focus_neighbor_left = NodePath(".")
		c.focus_neighbor_right = NodePath(".")


func _on_stop_focus(stop: PanelContainer, focused: bool) -> void:
	stop.add_theme_stylebox_override(&"panel", _ring if focused else _plain)


func _on_leave_pressed() -> void:
	confirm.popup_centered()
	if _contexts != null:
		_contexts.push(InputContextStack.Ctx.MODAL, confirm.get_cancel_button())
		_modal = true
	else:
		confirm.get_cancel_button().grab_focus.call_deferred()


func _on_leave_confirmed() -> void:
	leave_confirmed.emit()


func _on_confirm_visibility() -> void:
	if not confirm.visible:
		_pop_modal()


func _pop_modal() -> void:
	if _modal:
		_modal = false
		_contexts.pop(InputContextStack.Ctx.MODAL)
