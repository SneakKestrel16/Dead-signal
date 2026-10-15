extends Node
## Manual capture of the Results screen (story hud-results/008 evidence) from a fixture payload
## (tests/unit/hud-results/results_fixtures.gd), without a round. Flags after `--`:
##   --payload=survivors|shapeshifter|missing|corrupt   which payload (default survivors)
##   --ui-scale=F    Window.content_scale_factor, as the UI scale setting will apply it (ADR-0014 §9)
##   --focus=N       keyboard focus on stop N (0 = outcome group), to show the focus ring
##   --leave         open the Leave session confirm
##   --shot=PATH     save the viewport to PATH after SHOT_AFTER_S, then quit
## Usage: godot --path . --windowed --resolution 1920x1080 res://tests/manual/results_view.tscn -- --shot=a.png

const Fx := preload("res://tests/unit/hud-results/results_fixtures.gd")
const SHOT_AFTER_S := 1.0

var _opts := {}
var _t := 0.0
var _screen: ResultsScreen


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_opts[kv[0]] = kv[1] if kv.size() > 1 else ""
	get_window().content_scale_factor = float(_opts.get("ui-scale", "1.0"))
	var p: Dictionary
	match _opts.get("payload", "survivors"):
		"shapeshifter":
			p = Fx.shapeshifter_win()
		"missing":
			p = Fx.defense_missing()
		"corrupt":
			p = Fx.survivors_win()
			p.survivors[1].downs = "two"
			p.monster[&"blackouts"] = -1
		_:
			p = Fx.survivors_win()
	var contexts := InputContextStack.new()
	contexts.viewport = get_viewport()
	_screen = ResultsScreen.new(p, Knobs.load_all().match_flow.results_duration_s, contexts)
	add_child(_screen)
	if _opts.has("focus"):
		_screen.focus_stops[int(_opts["focus"])].grab_focus.call_deferred()
	if _opts.has("leave"):
		_screen.leave_button.pressed.emit.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _opts.has("shot") and _t >= SHOT_AFTER_S:
		var path: String = _opts["shot"]
		print("SHOT %s %s" % [path, error_string(get_viewport().get_texture().get_image().save_png(path))])
		get_tree().quit()
