# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does one networked greybox round deliver "you can't be sure the person next to you is a person"?
# Date: 2026-10-13
extends CanvasLayer
## Minimal HUD (design/ux/hud.md, reduced to slice scope): clock and phase,
## objective line, prompt and hold bar, status, taser charges or the shapeshifter
## panel, survivor roster, event feed, role banner, results.

var game: Node
var _clock: Label
var _objective: Label
var _prompt: Label
var _bar: ProgressBar
var _status: Label
var _corner: Label
var _roster: Label
var _feed: VBoxContainer
var _banner: Label
var _banner_until := 0.0
var _vignette: ColorRect
var _results: PanelContainer
var _cross: ColorRect


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(0.5, 0.0, 0.0, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_vignette)
	_clock = _label(root, 26, Control.PRESET_CENTER_TOP, Vector2(-120, 10), Vector2(240, 60))
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective = _label(root, 17, Control.PRESET_TOP_LEFT, Vector2(18, 14), Vector2(520, 90))
	_roster = _label(root, 15, Control.PRESET_TOP_LEFT, Vector2(18, 110), Vector2(320, 160))
	_cross = ColorRect.new()
	_cross.color = Color(1, 1, 1, 0.6)
	_cross.size = Vector2(4, 4)
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.position = Vector2(-2, -2)
	root.add_child(_cross)
	_prompt = _label(root, 20, Control.PRESET_CENTER, Vector2(-300, 40), Vector2(600, 40))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar = ProgressBar.new()
	_bar.set_anchors_preset(Control.PRESET_CENTER)
	_bar.position = Vector2(-150, 85)
	_bar.size = Vector2(300, 16)
	_bar.show_percentage = false
	root.add_child(_bar)
	_status = _label(root, 20, Control.PRESET_CENTER_BOTTOM, Vector2(-350, -110), Vector2(700, 60))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corner = _label(root, 17, Control.PRESET_BOTTOM_RIGHT, Vector2(-420, -190), Vector2(400, 180))
	_corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_corner.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.position = Vector2(-460, 14)
	_feed.size = Vector2(440, 200)
	root.add_child(_feed)
	_banner = _label(root, 30, Control.PRESET_CENTER, Vector2(-500, -160), Vector2(1000, 120))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func round_started() -> void:
	var s: Dictionary = game.pstate(game.local_id)
	if s.role == "monster":
		_show_banner("You are the SHAPESHIFTER\nKeep a survivor in view for %d s to borrow their face (1-5). Q: true form. Lunge (LMB) only in true form." % Knobs.i("observe_time_s"), 9.0)
	else:
		var ch: Dictionary = Net.CHARACTERS[int(s.character)]
		_show_banner("You are %s\nOne of the others is not who they look like." % ch.name, 7.0)


func feed(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feed.add_child(l)
	while _feed.get_child_count() > 6:
		_feed.get_child(0).free()
	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		if is_instance_valid(l):
			l.queue_free())
	if text.begins_with("Phase") or text.begins_with("Evacuation"):
		_show_banner(text, 3.0)


func _show_banner(text: String, dur: float) -> void:
	_banner.text = text
	_banner_until = Time.get_ticks_msec() / 1000.0 + dur


func _process(_dt: float) -> void:
	if game == null or not game.started:
		_clock.text = "Waiting for players..."
		return
	_banner.visible = Time.get_ticks_msec() / 1000.0 < _banner_until
	var t: float = game.now()
	var w: Dictionary = game.world
	var left := maxf(0.0, Knobs.f("round_duration_s") - (t - float(w.start)))
	_clock.text = "%d:%02d\n%s" % [int(left) / 60, int(left) % 60, String(w.phase).capitalize()]
	_clock.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if left <= 30.0 else Color(0.9, 0.9, 0.9))
	var s: Dictionary = game.pstate(game.local_id)
	if s.is_empty():
		return
	_objective.text = _objective_text(w, s)
	_roster.text = _roster_text()
	_corner.text = _monster_text(s, t) if s.role == "monster" else "Taser cartridges: %d\nFlashlight [F]: %s\nCarrying drives: %d" % [int(s.taser), "on" if game.bodies[game.local_id].flashlight_on else "off", int(s.carrying)]
	var tg: Dictionary = game.local_target()
	var holding: bool = s.hold_kind != ""
	_prompt.text = "" if holding or tg.is_empty() else "[E] " + String(tg.text)
	_bar.visible = holding or (s.life == "downed" and float(s.rescue_p) > 0.0)
	if holding:
		_bar.max_value = float(s.hold_need)
		_bar.value = float(s.hold_p)
	elif s.life == "downed":
		_bar.max_value = Knobs.f("rescue_duration_s")
		_bar.value = float(s.rescue_p)
	_status.text = _status_text(s, t)
	var a := 0.0
	if s.life == "downed" or s.life == "seized":
		a = 0.35
	elif t < float(s.stun_until):
		a = 0.15
	_vignette.color = Color(0.45, 0.0, 0.0, a) if t >= float(s.stun_until) else Color(0.2, 0.4, 0.9, a)


func _objective_text(w: Dictionary, s: Dictionary) -> String:
	var term_room: String = _room(w.terminal)
	if s.role == "monster":
		return "Shapeshifter: stop the evidence leaving.\nDown every survivor, or run out the clock.\nTerminal is in %s." % term_room
	var carried := 0
	var found := 0
	for dv in w.drives:
		if dv.state != "active":
			found += 1
		if dv.state == "carried":
			carried += 1
	if w.activated:
		return "EXIT OPEN — carry both drives out through the exit (C4, east wall).\nExtracted: %d/2" % int(w.extracted)
	if w.activating:
		return "Hold the terminal area in %s: %d s left.\nStay within %d m of the terminal." % [term_room, int(ceil(Knobs.f("evac_activation_s") - float(w.activation))), Knobs.i("terminal_zone_radius_m")]
	if int(w.docked) >= 2:
		return "Terminal armed in %s — hold E at it to start evacuation." % term_room
	if found < 2:
		return "Recover 2 data drives (green glow) in the labs or archive: %d/2 found.\nThen dock them at the terminal in %s." % [found, term_room]
	return "Dock the data drives at the terminal in %s: %d/2 docked." % [term_room, int(w.docked)]


func _roster_text() -> String:
	var lines: PackedStringArray = ["Survivors"]
	for id in game.survivors():
		var s: Dictionary = game.st[id]
		var ch: Dictionary = Net.CHARACTERS[int(s.character)]
		var state: String = {"healthy": "", "seized": " — SEIZED", "downed": " — DOWN", "eliminated": " — gone", "escaped": " — escaped"}[s.life]
		if s.life == "healthy" and int(s.downs) > 0:
			state = " — wounded"
		lines.append("  %s (%s)%s" % [ch.name, game.player_name(id), state])
	var mid: int = game.monster_id()
	if mid != 0:
		lines.append("Shapeshifter: " + game.player_name(mid))
	return "\n".join(lines)


func _monster_text(s: Dictionary, t: float) -> String:
	var lines: PackedStringArray = []
	var form := int(s.form)
	lines.append("Form: " + ("TRUE FORM" if form == -1 else "disguised as " + String(Net.CHARACTERS[form].name)))
	if float(s.transform_until) > t:
		lines.append("Transforming... %.1f s" % (float(s.transform_until) - t))
	elif t < float(s.form_cd_until):
		lines.append("Form change in %.0f s" % (float(s.form_cd_until) - t))
	else:
		lines.append("Form change ready")
	if form == -1:
		lines.append("Lunge [LMB]: " + ("ready" if t >= float(s.lunge_cd_until) else "%.0f s" % (float(s.lunge_cd_until) - t)))
	else:
		lines.append("Lunge needs true form [Q]")
	lines.append("Faces:")
	for id in game.survivors():
		var ch := int(game.st[id].character)
		var p: float = minf(1.0, float(s.observe.get(str(ch), 0.0)) / Knobs.f("observe_time_s"))
		var unlocked: bool = ch in s.unlocked
		lines.append("  [%d] %s %s" % [ch + 1, Net.CHARACTERS[ch].name, "UNLOCKED" if unlocked else "%d%%" % int(p * 100.0)])
	return "\n".join(lines)


func _status_text(s: Dictionary, t: float) -> String:
	match String(s.life):
		"seized":
			return "SEIZED — a teammate's taser can free you"
		"downed":
			return "DOWN — bleeding out in %d s. Crawl to a teammate.%s" % [int(maxf(0.0, float(s.bleed_until) - t)), " Being rescued..." if game._being_rescued(game.local_id) else ""]
		"eliminated":
			return "You were eliminated. Spectating (fly with WASD)."
		"escaped":
			return "You escaped. Spectating (fly with WASD)."
	if t < float(s.stun_until):
		return "SHOCKED"
	if s.role == "monster" and int(s.victim) != 0:
		return "Taking them down..."
	return ""


func _room(token: String) -> String:
	var f := FileAccess.get_file_as_string("res://data/points.json")
	var d: Variant = JSON.parse_string(f)
	return String(d.get(token, "?")) if typeof(d) == TYPE_DICTIONARY else "?"


func show_results(res: Dictionary, won: bool) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.85)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_results = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 1.0)
	sb.set_content_margin_all(24)
	_results.add_theme_stylebox_override("panel", sb)
	_results.set_anchors_preset(Control.PRESET_CENTER)
	_results.position = Vector2(-330, -220)
	_results.custom_minimum_size = Vector2(660, 440)
	add_child(_results)
	var v := VBoxContainer.new()
	_results.add_child(v)
	var head := Label.new()
	head.text = ("YOU WIN" if won else "YOU LOSE") + "\n" + String(res.headline)
	head.add_theme_font_size_override("font_size", 28)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var body := Label.new()
	var lines: PackedStringArray = ["", "Round time %d:%02d · drives extracted %d/2" % [int(res.elapsed) / 60, int(res.elapsed) % 60, int(res.extracted)], ""]
	for row in res.rows:
		var who: String = "Shapeshifter" if row.role == "monster" else String(Net.CHARACTERS[int(row.character)].name)
		lines.append("%s — %s: %s, downs %d" % [row.name, who, row.life, int(row.downs)])
	lines.append("")
	lines.append("Returning to the lobby in %d s" % Knobs.i("results_duration_s"))
	body.text = "\n".join(lines)
	body.add_theme_font_size_override("font_size", 17)
	v.add_child(body)


func _label(parent: Control, size: int, preset: int, pos: Vector2, sz: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.set_anchors_preset(preset)
	l.position += pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
