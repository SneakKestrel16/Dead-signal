extends Node
## ADR-0007 (8): sums InputEventMouseMotion.relative and .screen_relative for OS-injected
## mouse motion while captured, with or without canvas_items stretch.
## godot --path . res://mouse_look.tscn --resolution WxH -- <stretch|none> <tag>

var rel := Vector2.ZERO
var srel := Vector2.ZERO
var events := 0
var tag := "run"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var stretch := args.size() > 0 and args[0] == "stretch"
	if args.size() > 1:
		tag = args[1]
	var root := get_tree().root
	root.content_scale_size = Vector2i(1152, 648)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if stretch else Window.CONTENT_SCALE_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().create_timer(1.0).timeout
	_write("READY")
	await get_tree().create_timer(5.0).timeout
	_write("window=%s content_scale_size=%s stretch=%s focused=%s events=%d relative=%s screen_relative=%s" % [root.size, root.content_scale_size, stretch, root.has_focus(), events, rel, srel])
	get_tree().quit()


func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		rel += e.relative
		srel += e.screen_relative
		events += 1


func _write(text: String) -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path("res://logs/mouse_%s.txt" % tag), FileAccess.WRITE)
	f.store_string(text + "\n")
	f.close()
