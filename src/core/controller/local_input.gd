class_name LocalInput extends Node
## The owning client's input (ADR-0007 §11): the named actions, mouse look and right-stick look. Mouse motion is
## read from InputEventMouseMotion.screen_relative (not `relative`, which the canvas_items stretch
## scales, so sensitivity would change with window size), is not scaled by delta, and is only taken
## while the mouse is captured. The mouse is captured again when the window regains focus (by the
## InputContextStack when `contexts` is set, which also drops the first motion after it).
## Yaw and pitch accumulate here and go into the InputFrame sampled at the physics tick.
## Device checks, if ever needed, use the event type, never `device == 0` (4.7 device IDs).
## Flinch view offset (ADR-0015 §2-3; story controller-interaction/013): the owner keeps the newest
## FlinchRecord from ViewOffsetChanged and renders yaw/pitch plus offset_at(record, estimated server
## tick); the camera reads view_yaw()/view_pitch(), the sampler sends the raw yaw and pitch stamped with
## the record id, view epoch and tick. A re-baseline record is folded into yaw and pitch in the same call
## that adopts it, so the rendered view does not move; the client never zeroes an offset any other way.
## Usage:
##   var li := LocalInput.new(); add_child(li)
##   router.subscribe(&"ViewOffsetChanged", li.on_view_offset)
##   var f := li.sample(int(est_tick))      # once per physics tick, est_tick = estimated server tick
##   head.rotation = Vector3(li.view_pitch(est), li.view_yaw(est), 0.0)   # every rendered frame

## Mouse look sensitivity in radians per screen pixel. NOT SOURCEABLE: no GDD or ADR number (a player
## setting the options menu will own); 0.0025 rad (~0.14°) per pixel is a common default (inference).
var sensitivity := 0.0025
## Right-stick look in radians per second at full deflection (hud-results story 012). NOT SOURCEABLE: no
## GDD or ADR number (an options-menu setting later); ~170°/s is a common pad default (inference).
var stick_rate := 3.0
## Radial stick dead zone; the 0.2 action dead zone in project.godot (inference, a pad playtest settles it).
const STICK_DEADZONE := 0.2
var yaw := 0.0
var pitch := 0.0
## ADR-0014 §2: mouse look reaches the view only while the top context allows look (the callout wheel
## steers with it). null = always.
var contexts: InputContextStack

## The record the owner renders with: record 0 of epoch 0 (no offset) until the server sends one.
var _record := FlinchRecord.new()
## Last right-stick deflection; held between motion events, which only fire on change.
var _stick := Vector2.ZERO


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## _input, not _unhandled_input: captured motion still carries the window-centre position, so a HUD
## Control with a STOP filter would eat it before _unhandled_input (gotchas.md).
func _input(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (contexts == null or contexts.allows_look()):
		handle(event)


func _process(delta: float) -> void:
	if contexts != null and not contexts.allows_look():
		_stick = Vector2.ZERO ## the wheel steers with it; the view takes it again from the next motion
	stick_look(delta)


## Applies one input event to the view: mouse motion turns it, right-stick motion sets the stick that
## stick_look() turns it by. Public so tests can feed events.
func handle(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	# the first motion that moves after a recapture is dropped (ADR-0014 §3, BUG-0014); a zero motion the
	# engine sends on the capture switch must not spend the discard
	if motion != null and motion.screen_relative != Vector2.ZERO \
			and not (contexts != null and contexts.take_motion_discard()):
		look(motion.screen_relative)
	var joy := event as InputEventJoypadMotion
	if joy != null and joy.axis == JOY_AXIS_RIGHT_X:
		_stick.x = joy.axis_value
	elif joy != null and joy.axis == JOY_AXIS_RIGHT_Y:
		_stick.y = joy.axis_value


## Turns the view by the held right stick over `delta` seconds: right turns right, up looks up.
func stick_look(delta: float) -> void:
	if _stick.length() < STICK_DEADZONE:
		return
	look(_stick * stick_rate * delta / sensitivity)


## Turns the view by a screen-pixel delta: right turns right (yaw falls), up looks up.
func look(screen_delta: Vector2) -> void:
	yaw = wrapf(yaw - screen_delta.x * sensitivity, -PI, PI)
	pitch = clampf(pitch - screen_delta.y * sensitivity, -ViewState.PITCH_LIMIT, ViewState.PITCH_LIMIT)


## ClientEventRouter handler for ViewOffsetChanged (ADR-0015 §2-3). A re-baseline the client has not
## already adopted folds the server's held offset into yaw and pitch (pitch clamped on the sum, as on the
## server); a fresh client (record 0) takes the server's reconnect record without folding. A malformed
## payload is ignored whole.
func on_view_offset(_tick: int, payload: Dictionary) -> void:
	var r := FlinchRecord.from_dict(payload)
	if r == null:
		return
	if r.rebaseline and r.record_id != _record.record_id:
		yaw = wrapf(yaw + r.fold.x, -PI, PI)
		pitch = clampf(pitch + r.fold.y, -ViewState.PITCH_LIMIT, ViewState.PITCH_LIMIT)
	_record = r


## The flinch offset (radians, x yaw, y pitch) at `server_tick`, the client's estimate of the server
## tick, fractional between ticks for rendering.
func view_offset(server_tick: float) -> Vector2:
	return FlinchRecord.offset_at(_record, server_tick)


## Rendered yaw: yaw plus the offset, wrapped to [-PI, PI). Camera only; never sent.
func view_yaw(server_tick: float) -> float:
	return wrapf(yaw + view_offset(server_tick).x, -PI, PI)


## Rendered pitch: pitch plus the offset, clamped to ±85° on the sum (ADR-0015 §3). Camera only.
func view_pitch(server_tick: float) -> float:
	return clampf(pitch + view_offset(server_tick).y, -ViewState.PITCH_LIMIT, ViewState.PITCH_LIMIT)


## The view epoch the input frames carry.
func view_epoch() -> int:
	return _record.view_epoch


## The input frame for this physics tick (seq is stamped by OwnerPredictor.predict()). `offset_tick` is
## the client's estimated server tick for this frame; 0 before the client has an estimate.
func sample(offset_tick: int = 0) -> InputFrame:
	var f := InputFrame.new()
	f.move = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	f.sprint = Input.is_action_pressed(&"sprint")
	f.crouch = Input.is_action_pressed(&"crouch")
	# SD-14: interact_alt is a second interact key; either one holds interact.
	f.interact_alt = Input.is_action_pressed(&"interact_alt")
	f.interact = Input.is_action_pressed(&"interact") or f.interact_alt
	f.yaw = yaw
	f.pitch = pitch
	f.record_id = _record.record_id
	f.view_epoch = _record.view_epoch
	f.offset_tick = offset_tick
	return f


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and contexts == null: # with a stack, the root re-applies it
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
