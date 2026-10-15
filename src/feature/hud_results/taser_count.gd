class_name TaserCount extends Label
## H11 taser cartridges (design/ux/hud.md H11, Z7; interaction-patterns P13; story hud-results/005): icon
## and count from HudModel.charges() (ADR-0014 §6), filled from the server's EventBatch.CHARGES entry, which
## reaches the owner in the batch of the tick its count changed (SurvivorDefense.charge_entries), so a shot
## shows within one snapshot. Hidden until the server sends a count: the shapeshifter's client never gets
## one. Hidden while spectating (BUG-0006; hud.md HUD States: no kit): the watched survivor's entry reaches
## the spectator. Every survivor carries the taser (survivor-defense.md), so "holding the item" is having a
## count (inference: no held-item state exists; a hand slot would settle it). GREYBOX: text stands in for
## the icon; the 150 ms count animation waits for the art pass.
## Usage: `hud.add_child(TaserCount.new(hud_model))`

## GREYBOX place in Z7 (bottom right), pixels from the corner.
const MARGIN_PX := 32.0

## Cartridges left, -1 before the server sent any.
var count := -1

var _model: HudModel


func _init(model: HudModel) -> void:
	_model = model
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_size_override(&"font_size", 28)
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -240.0 - MARGIN_PX
	offset_right = -MARGIN_PX
	offset_top = -48.0 - MARGIN_PX
	offset_bottom = -MARGIN_PX
	model.own_state_changed.connect(refresh)


## Reads the count and the spectating state from the model.
func refresh() -> void:
	count = _model.charges()
	visible = count >= 0 and not _model.spectating()
	text = "%s × %d" % [tr("Taser"), count]
