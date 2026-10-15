class_name PingCalloutHud extends Control
## Client presentation of pings and callouts (story pings-and-callouts/008; design/gdd/pings-and-callouts.md
## rules 2, 7, 10-12, Visual/Audio; design/ux/hud.md H9, H10, H12, H17; interaction-patterns P5-P7, P9-P10;
## ADR-0014 §1, §7). Reads only the client's projected lists (PingReceiver.pending/rejections, PingMarkers,
## CalloutReceiver.received/audio) and decides nothing.
## - Ping action (one press): an item ping when the view ray picks a pingable object, else a location ping at
##   the view ray's hit (or its end at ping_max_range_m). The request shows at once as a pending marker; the
##   server's own copy replaces it, a rejection removes it with the local "Too fast" tick (H9) and a click.
## - Markers draw on this Control (so through walls) with the sender's name, colour and distance; off-screen
##   or behind they clamp to the 48 px inset with an arrow pointing at the target; they fade over FADE_S
##   before expiry.
## - Callout wheel (hold the wheel action): pushes InputContextStack WHEEL (movement live, look steers the
##   wheel), release sends the aimed line (Drive here / Fuse here attach the aimed item, rule 13) and pops;
##   release in the dead zone cancels.
## - Each callout plays its line through PlaceholderAudio at its origin on VOICE_BUS (never a ducked bus) and
##   adds `[Name]: [text]` with a live direction arrow to the feed; "(not you)" when marked. The monster's
##   audio-only callouts play the sound only. A real callout's gesture shows on the speaker's drawn body.
## PLACEHOLDER look: plain shapes and the fallback font; the HUD art pass replaces the drawing, not the data.
## Names: CharacterDef has no display name yet, so the character id (C1..C5) is the name (inference; a name
## field in the character data would settle it).
## Usage (client, rendering): see RoundClient._on_connected.

## hud.md H9: the rejection label shows 1.5 s.
const TOO_FAST_S := 1.5
## hud.md H12 gives a 150 ms fade-in; the fade-out at expiry has no number, so the same 150 ms is used
## (inference; a hud.md H12 fade-out value would settle it).
const FADE_S := 0.15
## hud.md H10 / interaction-patterns P9 (AD-02): each feed line stays at least 8 s; the scrollback is 10.
const FEED_HOLD_S := 8.0
const FEED_SCROLLBACK := 10
## GDD Animation Feel Targets: the callout gesture is ~30 frames at 60 fps.
const GESTURE_S := 0.5
## Placeholder gesture: a lit sphere this far above the drawn body's feet. PLACEHOLDER, replaced by the
## body animation. The speaker is the drawn body showing the callout's identity nearest its origin, within
## GESTURE_MATCH_M (the origin is the server's body position, so a drawn body sits on it up to interpolation).
const GESTURE_HEIGHT_M := 2.1
const GESTURE_MATCH_M := 1.5
## Callouts are never ducked (control manifest): the Voice bus sends straight to Master.
const VOICE_BUS := &"Voice"
const CLICK_SOUND := &"ping/rejected"
## Layout (hud.md Layout Zones, 1080p reference): 48 px safe margin, feed in Z6 at bottom left with 28 px
## text (P9); wheel and marker sizes are placeholder.
const INSET_PX := 48.0
const FEED_FONT := 28
const MARKER_FONT := 18
const WHEEL_RADIUS_PX := 170.0
## P6 "centre dead zone": no number given (inference, placeholder).
const WHEEL_DEAD_PX := 40.0
const MONSTER_COLOUR := Color(0.85, 0.1, 0.1)
const UNKNOWN_COLOUR := Color(0.6, 0.6, 0.6)

## Seconds the "Too fast" label still shows.
var too_fast_s := 0.0

var _knobs: Knobs
## The client's input contexts (the wheel pushes WHEEL; LocalInput reads look from it).
var contexts: InputContextStack
var _pings: PingReceiver
var _markers: PingMarkers
var _callouts: CalloutReceiver
var _audio: PlaceholderAudio
var _camera: Camera3D
var _remotes: Dictionary[int, Node3D]
var _state_of: Callable
var _now_tick: Callable
var _item_of: Callable
var _own: Callable
var _pingable: Dictionary[int, Array] = {}
var _set: CalloutSet
var _names := {}
var _colours := {}
var _clock := 0.0
var _seen_callouts := 0
var _seen_audio := 0
var _seen_rejections := 0
## Feed lines oldest first: {text, origin, at} (at = _clock when added).
var _feed: Array[Dictionary] = []
## [gesture node, _clock it ends].
var _gestures: Array = []
var _wheel_open := false
var _wheel_aim := Vector2.ZERO


## `state_of(handle) -> Dictionary` (PuppetMap.state_of), `now_tick() -> float` (estimated server tick),
## `item_of() -> int` (the interactable the view ray picks, -1 for none), `own() -> int` (own displayed
## appearance id). `map` gives the pingable objects (null: location pings only).
func _init(knobs: Knobs, pings: PingReceiver, markers: PingMarkers, callouts: CalloutReceiver,
		contexts_: InputContextStack, audio: PlaceholderAudio, camera: Camera3D, remotes: Dictionary[int, Node3D],
		state_of: Callable, now_tick: Callable, item_of: Callable, own: Callable, map: MapData) -> void:
	_knobs = knobs
	_pings = pings
	_markers = markers
	_callouts = callouts
	contexts = contexts_
	_audio = audio
	_camera = camera
	_remotes = remotes
	_state_of = state_of
	_now_tick = now_tick
	_item_of = item_of
	_own = own
	if map != null:
		_pingable = PingsCallouts.pingable_items(map, 0.0)
	_set = CalloutSet.load_shipped()
	for c in CharacterDef.load_all():
		if c != null:
			_names[c.appearance_id] = String(c.id)
			_colours[c.appearance_id] = c.colour
	set_anchors_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Sends a ping at what the view aims at (P5) and shows it pending.
func ping() -> void:
	var item: int = _item_of.call()
	var at := _aim_point()
	if _pingable.has(item):
		_pings.request(PingsCallouts.ITEM, at, item)
	else:
		_pings.request(PingsCallouts.LOCATION, at)


## Opens the callout wheel (P6) and pushes its input context.
func open_wheel() -> void:
	if _wheel_open or _set == null:
		return
	_wheel_open = true
	_wheel_aim = Vector2.ZERO
	contexts.push(InputContextStack.Ctx.WHEEL, null)


## Steers the open wheel by a screen-pixel delta (mouse motion).
func aim_wheel(delta: Vector2) -> void:
	_wheel_aim = (_wheel_aim + delta).limit_length(WHEEL_RADIUS_PX)


## The aimed line index, or -1 in the dead zone or when closed.
func wheel_selection() -> int:
	return wheel_pick(_wheel_aim, _set.lines.size()) if _wheel_open else -1


## Closes the wheel; `send` sends the aimed line. True when a callout was sent. Pops WHEEL after the send
## (ADR-0014 §2: the wheel sends, then pops).
func close_wheel(send: bool) -> bool:
	if not _wheel_open:
		return false
	var i := wheel_selection()
	_wheel_open = false
	if send and i >= 0:
		var line: StringName = _set.lines[i]
		var item: int = _item_of.call() if line in PingsCallouts.ITEM_LINES else -1
		_callouts.request(line, item if _pingable.has(item) else -1)
	contexts.pop(InputContextStack.Ctx.WHEEL)
	return send and i >= 0


## Sector of `aim` among `n` (0 straight up, clockwise), or -1 inside the dead zone.
static func wheel_pick(aim: Vector2, n: int) -> int:
	if aim.length() < WHEEL_DEAD_PX or n <= 0:
		return -1
	var a := fposmod(atan2(aim.x, -aim.y), TAU)
	return roundi(a / (TAU / n)) % n


## Screen placement of world `point` in a `size` view (the camera viewport's size, unproject_position's space): [position, clamped, arrow angle]. Off-screen or behind
## the camera it clamps to the `inset` edge; behind, the mirrored offset is negated so it points the right
## way (ADR-0014 §7).
static func place(cam: Camera3D, point: Vector3, size: Vector2, inset: float) -> Array:
	var centre := size / 2.0
	var behind := cam.is_position_behind(point)
	var off := cam.unproject_position(point) - centre
	if behind:
		off = -off
	var half := centre - Vector2(inset, inset)
	var on := not behind and absf(off.x) <= half.x and absf(off.y) <= half.y
	if not on:
		if off.is_zero_approx():
			off = Vector2.DOWN
		off *= minf(half.x / maxf(absf(off.x), 1e-4), half.y / maxf(absf(off.y), 1e-4))
	return [centre + off, not on, off.angle()]


## Displayed name of appearance `id`.
func name_of(id: int) -> String:
	if id == CharacterDef.TRUE_FORM_APPEARANCE_ID:
		return tr("Monster")
	return _names.get(id, "?")


## Displayed colour of appearance `id`.
func colour_of(id: int) -> Color:
	if id == CharacterDef.TRUE_FORM_APPEARANCE_ID:
		return MONSTER_COLOUR
	return _colours.get(id, UNKNOWN_COLOUR)


## Markers to draw now, pending first: {point, label, colour, alpha, pending}.
func markers_now() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var now: float = _now_tick.call()
	var from := _camera.global_position if _camera.is_inside_tree() else Vector3.ZERO
	for p: Dictionary in _pings.pending:
		var own: int = _own.call()
		out.append({"point": p["at"], "colour": colour_of(own), "alpha": 0.5, "pending": true,
			"label": "%s  %d m" % [name_of(own), roundi(from.distance_to(p["at"]))]})
	var fade := maxf(_knobs.ticks(FADE_S), 1.0)
	for m: Dictionary in _markers.active(int(now)):
		var label := "%s  %d m" % [name_of(m["from"]), roundi(from.distance_to(m["point"]))]
		if m.get("type", &"") != &"":
			label = "%s  %s" % [tr(String(m["type"])), label]
		if m.get("not_you", false):
			label += " " + tr("(not you)")
		out.append({"point": m["point"], "colour": colour_of(m["from"]), "pending": false, "label": label,
			"alpha": clampf((m["expires"] - now) / fade, 0.0, 1.0)})
	return out


## Feed lines shown now (each for FEED_HOLD_S): {text, angle}; angle is the arrow's screen angle (0 right,
## PI/2 down = behind).
func feed_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l in _feed:
		if _clock - l["at"] < FEED_HOLD_S:
			out.append({"text": l["text"], "angle": _bearing(l["origin"])})
	return out


## The last FEED_SCROLLBACK feed texts, oldest first.
func feed_history() -> PackedStringArray:
	var out := PackedStringArray()
	for l in _feed:
		out.append(l["text"])
	return out


## Advances timers and takes newly delivered callouts and rejections. Called from _process.
func advance(delta: float) -> void:
	_clock += delta
	too_fast_s = maxf(too_fast_s - delta, 0.0)
	if _pings.rejections != _seen_rejections:
		_seen_rejections = _pings.rejections
		too_fast_s = TOO_FAST_S
		_audio.play_at(CLICK_SOUND, _camera.global_position if _camera.is_inside_tree() else Vector3.ZERO)
	while _seen_callouts < _callouts.received.size():
		_on_callout(_callouts.received[_seen_callouts])
		_seen_callouts += 1
	while _seen_audio < _callouts.audio.size():
		var a: Dictionary = _callouts.audio[_seen_audio]
		_seen_audio += 1
		if a.get("origin") is Vector3:
			_audio.play_at(_sound(a), a["origin"], VOICE_BUS)
	for g: Array in _gestures.duplicate():
		if _clock >= g[1]:
			if is_instance_valid(g[0]):
				(g[0] as Node).queue_free()
			_gestures.erase(g)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		if Input.is_action_just_pressed(&"ping") and contexts.allows_actions():
			ping()
		if Input.is_action_just_pressed(&"callout_wheel") and contexts.allows_actions():
			open_wheel()
		elif Input.is_action_just_released(&"callout_wheel"):
			close_wheel(true)
	advance(delta)
	queue_redraw()


func _input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if _wheel_open and motion != null:
		aim_wheel(motion.screen_relative)


func _on_callout(c: Dictionary) -> void:
	if not (c.get("origin") is Vector3 and c.get("identity") is int and c.get("line") is StringName):
		return
	_audio.play_at(_sound(c), c["origin"], VOICE_BUS)
	var text := "%s: %s" % [name_of(c["identity"]), tr(_set.text_of(c["line"]) if _set != null else "")]
	if c.get("not_you", false):
		text += " " + tr("(not you)")
	_feed.append({"text": text, "origin": c["origin"], "at": _clock})
	if _feed.size() > FEED_SCROLLBACK:
		_feed.pop_front()
	if c.get("gesture", false):
		_gesture(c["identity"], c["origin"])


static func _sound(c: Dictionary) -> StringName:
	return StringName("callout/%s/%s" % [c.get("voice", &""), c.get("line", &"")])


## PLACEHOLDER gesture: a lit sphere over the speaker's drawn body for GESTURE_S.
func _gesture(identity: int, origin: Vector3) -> void:
	var best: Node3D = null
	var best_d := GESTURE_MATCH_M
	for h: int in _remotes:
		var n := _remotes[h]
		if not is_instance_valid(n) or _state_of.call(h).get("appearance", -1) != identity:
			continue
		var d := Vector2(n.position.x - origin.x, n.position.z - origin.z).length()
		if d <= best_d:
			best = n
			best_d = d
	if best == null:
		return
	var s := SphereMesh.new()
	s.radius = 0.15
	s.height = 0.3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.3)
	var g := MeshInstance3D.new()
	g.name = &"Gesture"
	g.mesh = s
	g.material_override = mat
	g.position.y = GESTURE_HEIGHT_M
	best.add_child(g)
	_gestures.append([g, _clock + GESTURE_S])


## Screen angle from the view centre toward `origin` on the floor plane (0 right, -PI/2 ahead).
func _bearing(origin: Vector3) -> float:
	if not _camera.is_inside_tree():
		return 0.0
	var local := _camera.global_basis.inverse() * (origin - _camera.global_position)
	return Vector2(local.x, local.z).angle()


func _aim_point() -> Vector3:
	var range_m := _knobs.ping.ping_max_range_m
	if not _camera.is_inside_tree():
		return Vector3.ZERO
	var from := _camera.global_position
	var to := from - _camera.global_basis.z * range_m
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	return hit["position"] if not hit.is_empty() else to


func _draw() -> void:
	var font := get_theme_default_font()
	var size_px := get_viewport_rect().size
	if _camera.is_inside_tree():
		for m in markers_now():
			var pl := place(_camera, m["point"], size_px, INSET_PX)
			var c: Color = m["colour"]
			c.a = m["alpha"]
			if pl[1]:
				_arrow(pl[0], pl[2], 14.0, c)
			else:
				draw_colored_polygon(PackedVector2Array([pl[0] + Vector2(0, -10), pl[0] + Vector2(8, 0),
					pl[0] + Vector2(0, 10), pl[0] + Vector2(-8, 0)]), c)
			var tw := font.get_string_size(m["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, MARKER_FONT).x
			var at: Vector2 = (pl[0] as Vector2) + Vector2(-tw / 2.0, -16.0)
			at.x = clampf(at.x, INSET_PX, size_px.x - INSET_PX - tw)
			draw_string_outline(font, at, m["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, MARKER_FONT, 4,
				Color(0, 0, 0, c.a))
			draw_string(font, at, m["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, MARKER_FONT, c)
	var lines := feed_lines()
	var y := size_px.y - INSET_PX - (lines.size() - 1) * (FEED_FONT + 10)
	for l in lines:
		var tw := font.get_string_size(l["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, FEED_FONT).x
		draw_rect(Rect2(INSET_PX - 8, y - FEED_FONT - 2, tw + 56, FEED_FONT + 10), Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(INSET_PX, y), l["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, FEED_FONT, Color.WHITE)
		_arrow(Vector2(INSET_PX + tw + 24, y - FEED_FONT / 2.0 + 2), l["angle"], 10.0, Color.WHITE)
		y += FEED_FONT + 10
	var centre := size_px / 2.0
	if too_fast_s > 0.0:
		var t := tr("Too fast")
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, MARKER_FONT).x
		draw_string(font, centre + Vector2(-tw / 2.0, 100), t, HORIZONTAL_ALIGNMENT_LEFT, -1, MARKER_FONT,
			Color(1, 0.8, 0.3, minf(too_fast_s / 0.15, 1.0)))
	if _wheel_open:
		var sel := wheel_selection()
		var n := _set.lines.size()
		draw_circle(centre, WHEEL_RADIUS_PX + 60, Color(0, 0, 0, 0.55))
		for i in n:
			var dir := Vector2.UP.rotated(TAU * i / n)
			var t := tr(_set.texts[i])
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, MARKER_FONT).x
			var at := centre + dir * WHEEL_RADIUS_PX
			if i == sel:
				draw_rect(Rect2(at + Vector2(-tw / 2.0 - 8, -MARKER_FONT), Vector2(tw + 16, MARKER_FONT + 12)),
					Color(1, 1, 1, 0.9), false, 2.0)
			draw_string(font, at + Vector2(-tw / 2.0, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, MARKER_FONT,
				Color.WHITE if i == sel else Color(0.75, 0.75, 0.75))
		draw_circle(centre + _wheel_aim, 5.0, Color.WHITE)


func _arrow(at: Vector2, angle: float, r: float, c: Color) -> void:
	var d := Vector2.from_angle(angle)
	var side := d.orthogonal() * r * 0.6
	draw_colored_polygon(PackedVector2Array([at + d * r, at - d * r * 0.6 + side, at - d * r * 0.6 - side]), c)
