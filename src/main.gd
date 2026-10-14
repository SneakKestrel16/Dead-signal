## Boot scene: loads the shipped knobs and reports their health on screen and in the log.
## Placeholder until the main menu exists (lobby-role-assignment story 005); it gives
## the smoke check a launchable build (AD-67).
class_name Main extends Control

@onready var _status: Label = $Status


func _ready() -> void:
	var errs := Knobs.load_all().errors()
	for e in errs:
		push_warning("knobs: " + e)
	_status.text = "Dead Signal\nknobs: %d sections, %d problems (see log)" % [Knobs.SECTIONS.size(), errs.size()]
	print("boot ok: knob problems=%d" % errs.size())
