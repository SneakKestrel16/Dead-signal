class_name ShapeshifterKit extends VBoxContainer
## S2 form and form cooldown, S3 ability cooldowns (design/ux/hud.md S2-S3, Z7 bottom right). S2 shows the
## own snapshot entry's appearance (the current form) and whole seconds to the next form change (1 Hz); S3
## shows Lunge, False Signal and Blackout with tenths of seconds, or "Ready" (P13's shape change on ready is
## the word replacing the number). Greybox text; the spec's icons and sweep are the art pass.

const MARGIN_PX := 16.0
const ABILITIES: Array[StringName] = [&"lunge", &"false_signal", &"blackout"]

var _model: HudModel
var _names: Dictionary[int, String] = {}
var _form: Label
var _abilities: Label


func _init(model: HudModel) -> void:
	_model = model
	name = &"Kit"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -MARGIN_PX
	offset_top = -MARGIN_PX
	offset_right = -MARGIN_PX
	offset_bottom = -MARGIN_PX
	_form = Label.new()
	_form.name = &"S2Form"
	add_child(_form)
	_abilities = Label.new()
	_abilities.name = &"S3Abilities"
	add_child(_abilities)
	for c in CharacterDef.load_all():
		if c != null:
			_names[c.appearance_id] = String(c.id)


## Displayed name of `ability` (an ABILITIES key).
func ability_name(ability: StringName) -> String:
	match ability:
		&"lunge":
			return tr("Lunge")
		&"false_signal":
			return tr("False Signal")
		_:
			return tr("Blackout")


## The S3 line of `ability`: its name and the seconds left, or Ready.
func ability_text(ability: StringName) -> String:
	var left := _model.cooldown_remaining_s(ability)
	return "%s  %s" % [ability_name(ability), "%.1f" % left if left > 0.0 else tr("Ready")]


## Rewrites S2 and S3 from the model.
func refresh() -> void:
	var appearance: int = _model.own_state().get("appearance", -1)
	var form: String = tr("True form") if appearance == CharacterDef.TRUE_FORM_APPEARANCE_ID \
			else _names.get(appearance, "?")
	var left := ceili(_model.cooldown_remaining_s(&"form"))
	_form.text = "%s: %s  %s" % [tr("Form"), form, str(left) if left > 0 else tr("Ready")]
	var lines := PackedStringArray()
	for a in ABILITIES:
		lines.append(ability_text(a))
	_abilities.text = "\n".join(lines)
