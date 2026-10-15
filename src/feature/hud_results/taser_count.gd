class_name TaserCount extends Label
## H11 taser cartridges (design/ux/hud.md H11, Z7; interaction-patterns P13; story hud-results/005): icon
## and count from the server's EventBatch.CHARGES entry, which reaches the owner in the batch of the tick
## its count changed (SurvivorDefense.charge_entries), so a shot shows within one snapshot. Hidden until
## the server sends a count: the shapeshifter's client never gets one. Every survivor carries the taser
## (survivor-defense.md), so "holding the item" is having a count (inference: no held-item state exists;
## a hand slot would settle it). GREYBOX: text stands in for the icon; the 150 ms count animation waits
## for the art pass.
## Usage: `var t := TaserCount.new(); hud.add_child(t); router.subscribe(EventBatch.CHARGES, t.on_charges)`

## GREYBOX place in Z7 (bottom right), pixels from the corner.
const MARGIN_PX := 32.0

## Cartridges left, -1 before the server sent any.
var count := -1


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_size_override(&"font_size", 28)
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -240.0 - MARGIN_PX
	offset_right = -MARGIN_PX
	offset_top = -48.0 - MARGIN_PX
	offset_bottom = -MARGIN_PX


## ClientEventRouter handler for EventBatch.CHARGES ({charges}).
func on_charges(_tick: int, payload: Dictionary) -> void:
	var c: Variant = payload.get("charges")
	if not c is int:
		return
	count = c
	visible = count >= 0
	text = "%s × %d" % [tr("Taser"), count]
