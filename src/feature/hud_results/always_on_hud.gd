class_name AlwaysOnHud extends Control
## The always-on survivor HUD (story hud-results/002; design/ux/hud.md H1-H6, Layout Zones Z1-Z4, HUD States;
## ADR-0014 §5, §6): Z1 roster (name, life-state icon + word, drive carrier mark), Z2 clock with the
## final-30-second pulse, phase label and activation countdown, Z3 objective checklist, Z4 crosshair dot.
## A view: it reads HudModel only (signals and getters, refreshed each frame for the clock), decides
## nothing, and every Control is FOCUS_NONE and MOUSE_FILTER_IGNORE. Hidden until the round's first phase
## (Loading: HUD hidden). Every visible string goes through tr().
## PLACEHOLDER look: fallback font, plain plates; the art pass (hud.md Open Questions) replaces it.
## The spec's Tuning Knobs HUD scale, Show roster and Reduced motion are per-player settings, so they are
## properties here, not data/knobs: knobs are hashed into the join version (ADR-0006 §7) and must match on
## every peer. A settings store (Accessibility Options) sets them; until then they keep the hud.md defaults.
## Not drawn yet (no data in HudModel): the Wounded state and the final-30-second ticking layer (audio event
## system). Story 004: the crosshair also hides while hidden (HudModel.own_hidden).
## Usage (client composition root):
##   hud_layer.add_child(AlwaysOnHud.new(hud_model, multiplayer.get_unique_id()))

## Layout constants (hud.md Layout Zones, reference 1920 x 1080): safe margin from every edge, and from the
## centred 16:9 safe rect when the screen is wider than 16:9.
const MARGIN_PX := 48.0
const WIDE_MARGIN_PX := 64.0
const SAFE_ASPECT := 16.0 / 9.0
## Font sizes at HUD scale 1. Critical text >= 20 px at 1080p (hud.md Accessibility); 28 px gives a capital
## height of about 20 px in the fallback font (measured on the evidence screenshots).
const TEXT_FONT := 28
const CLOCK_FONT := 44
const CROSSHAIR_PX := 8.0
const PLATE_PAD_PX := 12.0
const PLATE_COLOUR := Color(0.0, 0.0, 0.0, 0.6) ## backing plate for 4.5:1 contrast (hud.md Accessibility)
const TEXT_COLOUR := Color(0.92, 0.92, 0.92)
const HIGHLIGHT_COLOUR := Color(1.0, 0.85, 0.4) ## checklist change highlight: steady, never a flash
## hud.md H1 (final 30 s pulse), H2/H4 (150 ms fade), H5 (1 s highlight).
const FINAL_S := 30.0
const PULSE_SCALE := 0.12
const FADE_S := 0.15
const HIGHLIGHT_S := 1.0
const CARRIER_MARK := "◆"

## Show roster (hud.md Tuning Knobs, default On).
var show_roster := true
## HUD scale, 0.75-1.5 (hud.md Tuning Knobs, default 100%). Scales text and the crosshair, not the margins.
var hud_scale := 1.0
## Reduced motion: the clock pulse is static and fades are cuts (hud.md Accessibility).
var reduced_motion := false

var roster_plate: PanelContainer
var roster_box: VBoxContainer
var clock_plate: PanelContainer
var clock_label: Label
var phase_label: Label
var activation_label: Label
var objectives_plate: PanelContainer
var objectives_box: VBoxContainer
var crosshair: Panel

var _model: HudModel
var _own_id: int
var _phase := -2
var _rows: Dictionary[int, String] = {} ## survivor -> drawn row text, to fade only changed rows
var _lines: Array[String] = []
var _highlight_until: Array[float] = []
var _now_s := 0.0


## `own_id`: this client's player id (the crosshair hides while it is Downed or out of the round).
func _init(model: HudModel, own_id: int) -> void:
	_model = model
	_own_id = own_id
	name = &"AlwaysOnHud"
	_quiet(self)
	var plate := StyleBoxFlat.new()
	plate.bg_color = PLATE_COLOUR
	plate.set_content_margin_all(PLATE_PAD_PX)
	roster_plate = _plate(plate)
	roster_box = _box(roster_plate)
	clock_plate = _plate(plate)
	var clock_box := _box(clock_plate)
	clock_label = _label(clock_box)
	phase_label = _label(clock_box)
	activation_label = _label(clock_box)
	for l: Label in [clock_label, phase_label, activation_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objectives_plate = _plate(plate)
	objectives_box = _box(objectives_plate)
	crosshair = Panel.new()
	_quiet(crosshair)
	var dot := StyleBoxFlat.new()
	dot.bg_color = TEXT_COLOUR
	dot.set_corner_radius_all(64)
	dot.set_border_width_all(2)
	dot.border_color = PLATE_COLOUR.darkened(1.0) # dark rim: the dot reads on lit bodies and dark walls
	crosshair.add_theme_stylebox_override(&"panel", dot)
	add_child(crosshair)
	model.roster_changed.connect(refresh)
	model.objectives_changed.connect(refresh)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh()


func _process(delta: float) -> void:
	_now_s += delta
	refresh()


## The centred safe rect for a screen of `size`: the whole screen up to 16:9, else a centred 16:9 rect.
static func safe_rect(screen: Vector2) -> Rect2:
	if screen.x / screen.y <= SAFE_ASPECT + 1e-3:
		return Rect2(Vector2.ZERO, screen)
	var w := screen.y * SAFE_ASPECT
	return Rect2((screen.x - w) / 2.0, 0.0, w, screen.y)


## Margin from the safe rect's edges for a screen of `size` (hud.md Platform Adaptation).
static func margin_for(screen: Vector2) -> float:
	return MARGIN_PX if screen.x / screen.y <= SAFE_ASPECT + 1e-3 else WIDE_MARGIN_PX


## Reads HudModel and redraws every element, then places the zones. Called each frame and on model signals.
func refresh() -> void:
	var phase := _model.phase()
	var in_round := phase >= 0
	for c: Control in [roster_plate, clock_plate, objectives_plate, crosshair]:
		c.visible = in_round
	if not in_round:
		return
	_clock()
	if phase != _phase:
		_phase = phase
		phase_label.text = tr(String(MatchFlow.Phase.keys()[phase]))
		_fade(phase_label)
	_roster()
	_checklist()
	var own := _model.roster_state(_own_id)
	crosshair.visible = (own == HudModel.LIFE_HEALTHY or own == HudModel.LIFE_UNKNOWN) and not _model.own_hidden() 			and not _model.spectating()
	_layout()


func _clock() -> void:
	var left := _model.time_remaining_s()
	var t := ceili(left)
	clock_label.text = "%02d:%02d" % [t / 60, t % 60]
	clock_label.add_theme_font_size_override(&"font_size", roundi(CLOCK_FONT * hud_scale))
	var s := 1.0
	if left <= FINAL_S and left > 0.0 and not reduced_motion:
		s += PULSE_SCALE * (left - floorf(left)) # grows at each second, settles by the next
	clock_label.pivot_offset = clock_label.size / 2.0
	clock_label.scale = Vector2(s, s)
	var lines := _model.objective_lines()
	var term := lines.filter(func(l: Dictionary) -> bool: return l["objective"] == SurvivorObjectives.TERMINAL_ID)
	activation_label.visible = not term.is_empty() \
			and term[0]["state"] == SurvivorObjectives.TerminalState.ACTIVATING
	var a := _model.activation()
	if a.is_empty():
		activation_label.text = tr("Activating")
	elif a["paused"]:
		activation_label.text = tr("Paused")
	else:
		activation_label.text = tr("Activation %d s") % ceili(a["remaining_s"])


func _roster() -> void:
	roster_plate.visible = show_roster and not _model.roster().is_empty()
	var carriers := {}
	for l in _model.objective_lines():
		if l["objective"] < SurvivorObjectives.FUSE_ID and l["state"] == SurvivorObjectives.DriveState.CARRIED:
			carriers[l["carrier"]] = true
	var rows := _model.roster()
	_ensure(roster_box, rows.size())
	for i in rows.size():
		var id: int = rows[i]["survivor"]
		var text := "%s  %s" % [_name(id), _life(rows[i]["state"])]
		if carriers.has(id):
			text += "  " + CARRIER_MARK
		var row := roster_box.get_child(i) as Label
		if _rows.get(id, "") != text:
			_rows[id] = text
			row.text = text
			_fade(row)


func _checklist() -> void:
	var drives := 0
	var carried: Array[String] = []
	var fuses := 0
	var terminal := SurvivorObjectives.TerminalState.LOCKED
	for l in _model.objective_lines():
		var o: int = l["objective"]
		if o < SurvivorObjectives.FUSE_ID:
			if l["state"] != SurvivorObjectives.DriveState.SECURED:
				drives += 1
			if l["state"] == SurvivorObjectives.DriveState.CARRIED:
				carried.append(CARRIER_MARK + " " + _name(l["carrier"]))
			elif l["state"] == SurvivorObjectives.DriveState.DROPPED:
				carried.append(tr("Dropped"))
		elif o >= SurvivorObjectives.FUSE_BOX_ID and o < SurvivorObjectives.TERMINAL_ID:
			if l["state"] == SurvivorObjectives.FuseState.INSTALLED:
				fuses += 1
		elif o == SurvivorObjectives.TERMINAL_ID:
			terminal = l["state"]
	var lines: Array[String] = ["%s %d/%d" % [tr("Drives"), drives, SurvivorObjectives.ACTIVE_DRIVES]]
	lines.append_array(carried)
	lines.append("%s %d/%d" % [tr("Fuses"), fuses, SurvivorObjectives.FUSES_REQUIRED])
	lines.append("%s %s" % [tr("Terminal"), tr(String(SurvivorObjectives.TerminalState.keys()[terminal]).capitalize())])
	_ensure(objectives_box, lines.size())
	_highlight_until.resize(lines.size())
	for i in lines.size():
		if i >= _lines.size() or _lines[i] != lines[i]:
			_highlight_until[i] = _now_s + HIGHLIGHT_S if not _lines.is_empty() else 0.0
		var row := objectives_box.get_child(i) as Label
		row.text = lines[i]
		row.add_theme_color_override(&"font_color",
				HIGHLIGHT_COLOUR if _now_s < _highlight_until[i] else TEXT_COLOUR)
	_lines = lines


## Places Z1 top left, Z2 top centre, Z3 top right and Z4 at the centre, inside the safe rect.
func _layout() -> void:
	var safe := safe_rect(size)
	var m := margin_for(size)
	for l in _all_labels():
		l.add_theme_font_size_override(&"font_size", roundi(TEXT_FONT * hud_scale))
	clock_label.add_theme_font_size_override(&"font_size", roundi(CLOCK_FONT * hud_scale))
	for p: Control in [roster_plate, clock_plate, objectives_plate]:
		p.size = p.get_combined_minimum_size()
	roster_plate.position = Vector2(safe.position.x + m, m)
	clock_plate.position = Vector2(safe.get_center().x - clock_plate.size.x / 2.0, m)
	objectives_plate.position = Vector2(safe.end.x - m - objectives_plate.size.x, m)
	var d := CROSSHAIR_PX * hud_scale
	crosshair.size = Vector2(d, d)
	crosshair.position = size / 2.0 - crosshair.size / 2.0


func _all_labels() -> Array[Label]:
	var out: Array[Label] = [phase_label, activation_label]
	for box: VBoxContainer in [roster_box, objectives_box]:
		for c in box.get_children():
			out.append(c as Label)
	return out


func _name(id: int) -> String:
	var n := _model.name_of(id)
	return n if n != "" else tr("Survivor %d") % id


## Icon + word, never colour alone (hud.md Accessibility).
func _life(state: int) -> String:
	match state:
		HudModel.LIFE_DOWNED: return "✚ " + tr("Downed")
		HudModel.LIFE_ELIMINATED: return "○ " + tr("Eliminated")
		HudModel.LIFE_ESCAPED: return "↗ " + tr("Escaped")
	return "● " + tr("Healthy")


## 150 ms fade-in on change; a cut with reduced motion.
func _fade(c: Control) -> void:
	if reduced_motion or not is_inside_tree():
		return
	c.modulate.a = 0.0
	create_tween().tween_property(c, ^"modulate:a", 1.0, FADE_S)


func _ensure(box: VBoxContainer, n: int) -> void:
	while box.get_child_count() < n:
		_label(box)
	for i in box.get_child_count():
		(box.get_child(i) as Label).visible = i < n


func _plate(style: StyleBox) -> PanelContainer:
	var p := PanelContainer.new()
	_quiet(p)
	p.add_theme_stylebox_override(&"panel", style)
	add_child(p)
	return p


func _box(parent: Control) -> VBoxContainer:
	var b := VBoxContainer.new()
	_quiet(b)
	parent.add_child(b)
	return b


func _label(parent: Control) -> Label:
	var l := Label.new()
	_quiet(l)
	l.add_theme_color_override(&"font_color", TEXT_COLOUR)
	l.add_theme_font_size_override(&"font_size", roundi(TEXT_FONT * hud_scale))
	parent.add_child(l)
	return l


static func _quiet(c: Control) -> void:
	c.focus_mode = Control.FOCUS_NONE
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
