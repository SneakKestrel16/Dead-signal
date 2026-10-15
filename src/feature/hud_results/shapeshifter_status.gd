class_name ShapeshifterStatus extends VBoxContainer
## S4 transforming bar and S5 stun / immunity remaining (design/ux/hud.md S4-S5, Z4 under the crosshair).
## Each shows only in its trigger state; values from HudModel. Greybox; it takes the hold bar's slot
## (RoundClient BAR_BELOW_CENTRE_PX): the Transforming bar replaces the prompt in Z4 (hud.md layout).

const BELOW_CENTRE_PX := 60.0
const BAR_SIZE := Vector2(240.0, 16.0)

var _model: HudModel
var _bar: ProgressBar
var _stun: Label


func _init(model: HudModel) -> void:
	_model = model
	name = &"Status"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -BAR_SIZE.x / 2.0
	offset_right = BAR_SIZE.x / 2.0
	offset_top = BELOW_CENTRE_PX
	offset_bottom = BELOW_CENTRE_PX
	_bar = ProgressBar.new()
	_bar.name = &"S4Transforming"
	_bar.custom_minimum_size = BAR_SIZE
	_bar.max_value = 1.0
	_bar.show_percentage = false
	add_child(_bar)
	_stun = Label.new()
	_stun.name = &"S5Stun"
	_stun.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_stun)


## Shows S4 while transforming and S5 while stunned or immune.
func refresh() -> void:
	var p := _model.transform_progress()
	_bar.visible = p >= 0.0
	_bar.value = maxf(p, 0.0)
	var stun := _model.stun_remaining_s()
	var immune := _model.immunity_remaining_s()
	_stun.visible = stun > 0.0 or immune > 0.0
	_stun.text = "%s %.1f" % [tr("Stunned"), stun] if stun > 0.0 else "%s %.1f" % [tr("Immune"), immune]
