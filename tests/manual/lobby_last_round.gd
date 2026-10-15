extends Node
## Manual capture of the lobby's Last round view (story hud-results/009 evidence) without playing a round:
## the shipped LobbyScreen hosts a session from its own --lobby-* flags, then a recorded RoundEnded payload
## (tests/unit/hud-results/results_fixtures.gd) is fed in as if the round had just ended and returned to the
## room. The button is opened and closed with real ui_accept / ui_cancel input events.
## Flags after `--`: the lobby's (--lobby-host --lobby-port=N --lobby-name=NAME) and --shots=DIR, which saves
## lobby.png (button focused), view.png (the view, Back focused) and back.png (closed, focus on the button), then quits.
## Usage: godot --path . --windowed --resolution 1280x720 res://tests/manual/lobby_last_round.tscn -- \
##   --lobby-host --lobby-port=30860 --lobby-name=Host --shots=DIR

const Fx := preload("res://tests/unit/hud-results/results_fixtures.gd")
## [seconds, step]: each step runs once its time is reached.
const STEPS := [[1.0, "feed"], [2.0, "lobby"], [2.2, "open"], [3.2, "view"], [3.4, "close"], [4.4, "back"]]

var _lobby: LobbyScreen
var _t := 0.0
var _step := 0


func _ready() -> void:
	_lobby = LobbyScreen.new()
	add_child(_lobby)


func _process(delta: float) -> void:
	_t += delta
	if _step >= STEPS.size() or _t < STEPS[_step][0]:
		return
	var step: String = STEPS[_step][1]
	_step += 1
	match step:
		"feed":
			_lobby._last_round = Fx.survivors_win()
			_lobby._show_room()
			_lobby._last_round_button.grab_focus.call_deferred()
		"open":
			_press(&"ui_accept")
		"close":
			_press(&"ui_cancel")
		_:
			_shot(step)
	if _step == STEPS.size():
		get_tree().quit()


func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)


func _shot(tag: String) -> void:
	var dir: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	if dir == "":
		return
	var path := "%s/%s.png" % [dir, tag]
	print("SHOT %s %s focus=%s" % [path, error_string(get_viewport().get_texture().get_image().save_png(path)),
		get_viewport().gui_get_focus_owner()])
