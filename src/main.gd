## Boot scene: loads the shipped knobs and reports their health on screen and in the log.
## Placeholder until the main menu exists (lobby-role-assignment story 005); it gives
## the smoke check a launchable build (AD-67).
class_name Main extends Control

## Shown under the status on the next boot of this scene, then cleared ("Host left", ADR-0001 §7).
static var notice: String = ""

@onready var _status: Label = $Status


func _ready() -> void:
	var errs := Knobs.load_all().errors()
	for e in errs:
		push_warning("knobs: " + e)
	_status.text = "Dead Signal\nknobs: %d sections, %d problems (see log)" % [Knobs.SECTIONS.size(), errs.size()]
	print("boot ok: knob problems=%d" % errs.size())
	if notice != "":
		_status.text += "
" + notice
		print("notice: " + notice)
		notice = ""


## Returns to this scene (the main menu until lobby-role-assignment story 005) showing `text`.
## Records nothing: a session that ended this way has no result (ADR-0001 §7).
static func return_with(tree: SceneTree, text: String) -> void:
	notice = text
	tree.change_scene_to_file("res://src/main.tscn")
