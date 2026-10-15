class_name ShapeshifterFaceList extends VBoxContainer
## S1 face list (design/ux/hud.md S1, Z1 top left): one row per survivor with its character name, observation
## progress and the available mark once observe_time_s is reached (borrowed-face.md rule 3). Reads HudModel.
## Greybox layout; the art pass owns the final look.

const MARGIN_PX := 16.0
const BAR_SIZE := Vector2(120.0, 10.0)

var _model: HudModel
var _names: Dictionary[int, String] = {}


func _init(model: HudModel) -> void:
	_model = model
	name = &"S1FaceList"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(MARGIN_PX, MARGIN_PX)
	for c in CharacterDef.load_all():
		if c != null:
			_names[c.appearance_id] = String(c.id)


## Matches the row count to the survivors, then rewrites each row's text and bar.
func refresh() -> void:
	var faces := _model.faces()
	while get_child_count() > faces.size():
		var last := get_child(get_child_count() - 1)
		remove_child(last)
		last.free()
	while get_child_count() < faces.size():
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(Label.new())
		var bar := ProgressBar.new()
		bar.custom_minimum_size = BAR_SIZE
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = 1.0
		bar.show_percentage = false
		row.add_child(bar)
		add_child(row)
	for i in faces.size():
		var f := faces[i]
		var row := get_child(i)
		var who: String = _names.get(f["appearance"], "?")
		(row.get_child(0) as Label).text = "%s  %s" % [who, tr("Available")] if f["available"] else who
		(row.get_child(1) as ProgressBar).value = f["progress"]
