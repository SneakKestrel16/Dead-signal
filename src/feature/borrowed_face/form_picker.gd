class_name FormPicker extends Control
## The shapeshifter's form picker (story borrowed-face/011; design/gdd/borrowed-face.md rules 6-9, 14; hud.md S1;
## interaction-patterns P6 wheel, P10 refusal; ADR-0014 §1-§3). Hold `form_picker` to open a wheel of the true
## form plus one segment per survivor of the HudModel face list, aim with the mouse or right stick, release to
## send BorrowedFace.request_packet; release in the centre dead zone cancels. A WHEEL context: movement stays
## live, look and actions are off. It reads HudModel only and decides nothing: the server validates (rule 7).
## Availability is the server's: a face the S1 list does not mark available, a survivor the roster shows
## Eliminated or Escaped (rule 6), and the current form are greyed with a text mark and never sent; choosing
## one shows the refusal at once (P10). A disconnected survivor is not in the model, so the server's refusal
## covers it.
## The server sends no refusal (rule 7: "rejected with no effect"), so a refusal is inferred: no transformation
## started (HudModel.transform_progress) by the newest snapshot tick past the send's newest tick plus the
## round trip plus net.slack_ticks. Inference: the request rides the reliable channel, so a lost packet's
## resend can land after the window and the label shows for a change that then starts; a server refusal
## reply would settle it.
## Every rendering client holds one; it opens only once HudModel holds shapeshifter state (only the shapeshifter's
## peer is sent any). Deviation from ShapeshifterHud's mount-on-first-state: a signal connection binding the
## model and its collaborators leaked the script graph at exit on survivor clients, whose one-shot never fires
## (verified by bisecting tests/integration/hud-results; the mechanism is inference, see gotchas.md).
## PLACEHOLDER look: greybox wheel as the callout wheel's; the HUD art pass owns it. Gamepad: steering only;
## no gamepad button is bound (the callout wheel has none either), settled by the controls page.
## Usage (client, rendering):
##   hud.add_child(FormPicker.for_client(hud_model, contexts, knobs, smp, interaction.refuse, match_display.server_tick))

const ACTION := &"form_picker"
const WHEEL_RADIUS_PX := PingCalloutHud.WHEEL_RADIUS_PX
const FONT_PX := 22

var _model: HudModel
var _contexts: InputContextStack
var _send: Callable
var _refuse: Callable
var _latest_tick: Callable
var _rtt_ticks: Callable
var _slack: int
var _names: Dictionary[int, String] = {}
var _open := false
var _aim := Vector2.ZERO
var _stick := Vector2.ZERO
var _until := -1 ## newest snapshot tick by which a sent request must show a transformation; -1 = none pending
var _was_transforming := false


## A FormPicker for the client's HUD, sending over `smp` (reliable, channel 1, held weakly) and reading the server
## round trip from its ENet peer. See _init for the rest.
static func for_client(model: HudModel, contexts: InputContextStack, knobs: Knobs, smp: SceneMultiplayer,
		refuse: Callable, latest_tick: Callable) -> FormPicker:
	var link: WeakRef = weakref(smp)
	return FormPicker.new(model, contexts, knobs, _send_via.bind(link), refuse, latest_tick,
			_rtt_via.bind(link, knobs.net.sim_tick_hz))


static func _send_via(bytes: PackedByteArray, link: WeakRef) -> void:
	var smp := link.get_ref() as SceneMultiplayer
	if smp != null:
		smp.send_bytes(bytes, 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE)


## ENet's smoothed round trip to the server in ticks (rounded up); 0 when not on ENet.
static func _rtt_via(link: WeakRef, hz: int) -> int:
	var smp := link.get_ref() as SceneMultiplayer
	var enet: ENetMultiplayerPeer = (smp.multiplayer_peer as ENetMultiplayerPeer) if smp != null else null
	if enet == null or enet.get_peer(1) == null:
		return 0
	return ceili(enet.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) * hz / 1000.0)


## send(bytes: PackedByteArray) sends to the server; refuse() shows the HUD-3 refusal label; latest_tick() ->
## int is the newest snapshot tick; rtt_ticks() -> int the round trip in ticks.
func _init(model: HudModel, contexts: InputContextStack, knobs: Knobs, send: Callable, refuse: Callable,
		latest_tick: Callable, rtt_ticks: Callable) -> void:
	_model = model
	_contexts = contexts
	_send = send
	_refuse = refuse
	_latest_tick = latest_tick
	_rtt_ticks = rtt_ticks
	_slack = knobs.net.slack_ticks
	name = &"FormPicker"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	for c in CharacterDef.load_all():
		if c != null:
			_names[c.appearance_id] = String(c.id)


## The wheel's segments, clockwise from the top: the true form, then the S1 faces in the server's order.
## Each is {form (request value), name, available, current}.
func entries() -> Array[Dictionary]:
	var own: int = _model.own_state().get("appearance", -1)
	var true_current := own == CharacterDef.TRUE_FORM_APPEARANCE_ID
	var out: Array[Dictionary] = [{"form": BorrowedFace.TRUE_FORM, "name": tr("True form"),
		"available": not true_current, "current": true_current}]
	for f in _model.faces():
		var life := _model.roster_state(f["survivor"])
		var current: bool = f["appearance"] == own
		out.append({"form": f["survivor"], "name": _names.get(f["appearance"], "?"), "current": current,
			"available": f["available"] and not current and life != HudModel.LIFE_ELIMINATED
				and life != HudModel.LIFE_ESCAPED})
	return out


func is_open() -> bool:
	return _open


## Opens the wheel when this client is the shapeshifter and gameplay holds input (ADR-0014 §1).
func open() -> void:
	if _open or not _model.is_shapeshifter() or not _contexts.allows_actions():
		return
	_open = true
	_aim = Vector2.ZERO
	_stick = Vector2.ZERO
	_contexts.push(InputContextStack.Ctx.WHEEL, null)


## Steers the open wheel by a screen-pixel delta (mouse motion).
func aim(delta: Vector2) -> void:
	_aim = (_aim + delta).limit_length(WHEEL_RADIUS_PX)


## The aimed entry index, or -1 in the dead zone or when closed.
func selection() -> int:
	return PingCalloutHud.wheel_pick(_aim, entries().size()) if _open else -1


## Closes the wheel; `send` sends the aimed form's request. True when one was sent. Sends, then pops (ADR-0014 §2).
func close(send: bool) -> bool:
	if not _open:
		return false
	var i := selection()
	_open = false
	var sent := false
	if send and i >= 0:
		var e := entries()[i]
		if e["available"]:
			_send.call(BorrowedFace.request_packet(e["form"]))
			_until = int(_latest_tick.call()) + int(_rtt_ticks.call()) + _slack
			_was_transforming = _model.transform_progress() >= 0.0
			sent = true
		else:
			_refuse.call()
	_contexts.pop(InputContextStack.Ctx.WHEEL)
	return sent


## Judges a pending request: a transformation that started since the send accepts it; none by the deadline
## is a refusal, shown once. Called every frame.
func advance() -> void:
	if _until < 0:
		return
	var transforming := _model.transform_progress() >= 0.0
	if transforming and not _was_transforming:
		_until = -1
	elif not transforming:
		_was_transforming = false # a running transformation ended: a new start now means acceptance
	if _until >= 0 and int(_latest_tick.call()) > _until:
		_until = -1
		_refuse.call()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(ACTION):
		open()
	elif Input.is_action_just_released(ACTION):
		close(true)
	advance()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		aim(motion.screen_relative)
	var joy := event as InputEventJoypadMotion
	if joy != null and (joy.axis == JOY_AXIS_RIGHT_X or joy.axis == JOY_AXIS_RIGHT_Y):
		if joy.axis == JOY_AXIS_RIGHT_X:
			_stick.x = joy.axis_value
		else:
			_stick.y = joy.axis_value
		_aim = (_stick * WHEEL_RADIUS_PX).limit_length(WHEEL_RADIUS_PX)


func _draw() -> void:
	if not _open:
		return
	var font := get_theme_default_font()
	var centre := size / 2.0
	var e := entries()
	var sel := selection()
	draw_circle(centre, WHEEL_RADIUS_PX + 60, Color(0, 0, 0, 0.55))
	for i in e.size():
		var t: String = e[i]["name"]
		if e[i]["current"]:
			t += "  " + tr("Current")
		elif not e[i]["available"]:
			t += "  " + tr("Unavailable")
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x
		var at := centre + Vector2.UP.rotated(TAU * i / e.size()) * WHEEL_RADIUS_PX
		if i == sel:
			draw_rect(Rect2(at + Vector2(-tw / 2.0 - 8, -FONT_PX), Vector2(tw + 16, FONT_PX + 12)),
				Color(1, 1, 1, 0.9), false, 2.0)
		draw_string(font, at + Vector2(-tw / 2.0, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX,
			Color.WHITE if e[i]["available"] else Color(0.55, 0.55, 0.55))
	draw_circle(centre + _aim, 5.0, Color.WHITE)

