class_name LocalInput extends Node
## The owning client's input (ADR-0007 §11): the eleven named actions and mouse look. Mouse motion is
## read from InputEventMouseMotion.screen_relative (not `relative`, which the canvas_items stretch
## scales, so sensitivity would change with window size), is not scaled by delta, and is only taken
## while the mouse is captured. The mouse is captured again when the window regains focus.
## Yaw and pitch accumulate here and go into the InputFrame sampled at the physics tick.
## Device checks, if ever needed, use the event type, never `device == 0` (4.7 device IDs).
## Usage: `var li := LocalInput.new(); add_child(li); var f := li.sample()` once per physics tick.

## Mouse look sensitivity in radians per screen pixel. NOT SOURCEABLE: no GDD or ADR number (a player
## setting the options menu will own); 0.0025 rad (~0.14°) per pixel is a common default (inference).
var sensitivity := 0.0025
var yaw := 0.0
var pitch := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		handle(event)


## Applies one input event to the view (mouse motion only). Public so tests can feed events.
func handle(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		look(motion.screen_relative)


## Turns the view by a screen-pixel delta: right turns right (yaw falls), up looks up.
func look(screen_delta: Vector2) -> void:
	yaw = wrapf(yaw - screen_delta.x * sensitivity, -PI, PI)
	pitch = clampf(pitch - screen_delta.y * sensitivity, -ViewState.PITCH_LIMIT, ViewState.PITCH_LIMIT)


## The input frame for this physics tick (seq is stamped by OwnerPredictor.predict()).
func sample() -> InputFrame:
	var f := InputFrame.new()
	f.move = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	f.sprint = Input.is_action_pressed(&"sprint")
	f.crouch = Input.is_action_pressed(&"crouch")
	f.interact = Input.is_action_pressed(&"interact")
	f.yaw = yaw
	f.pitch = pitch
	return f


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
