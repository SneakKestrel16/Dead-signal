class_name ShapeshifterHud extends Control
## The shapeshifter's HUD, S1-S6 of design/ux/hud.md (story hud-results/006, ADR-0014 §6): face list (Z1),
## form and ability cooldowns (Z7), transforming bar and stun/immunity (Z4), install alert (world/Z8). Every
## value is read from HudModel. mount() instances it on the first shapeshifter state the model receives, and
## only the shapeshifter's peer is ever sent one (MonsterHudFeed, ADR-0004 §5), so a survivor client never
## holds any S node: absent by data, not hidden by visibility (story Control Manifest rule).
## S7 placement preview and the ability input are ShapeshifterAim (story monster-abilities/011), mounted the same way.
## Usage (client composition root): ShapeshifterHud.mount(hud_layer, hud_model, camera)

var face_list: ShapeshifterFaceList
var kit: ShapeshifterKit
var status: ShapeshifterStatus
var alert: ShapeshifterInstallAlert


## Instances a ShapeshifterHud under `layer` the first time `model` reports shapeshifter state. `camera`
## places the install alert; null = alerts are not drawn.
static func mount(layer: CanvasLayer, model: HudModel, camera: Camera3D) -> void:
	model.monster_state_changed.connect(_spawn.bind(layer, model, camera), CONNECT_ONE_SHOT)


static func _spawn(layer: CanvasLayer, model: HudModel, camera: Camera3D) -> void:
	if is_instance_valid(layer):
		layer.add_child(ShapeshifterHud.new(model, camera))


func _init(model: HudModel, camera: Camera3D) -> void:
	name = &"ShapeshifterHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert = ShapeshifterInstallAlert.new(model, camera)
	add_child(alert)
	face_list = ShapeshifterFaceList.new(model)
	add_child(face_list)
	kit = ShapeshifterKit.new(model)
	add_child(kit)
	status = ShapeshifterStatus.new(model)
	add_child(status)
	refresh()


## Re-reads the model (every frame: countdowns move between server messages).
func refresh() -> void:
	face_list.refresh()
	kit.refresh()
	status.refresh()
	alert.refresh()


func _process(_delta: float) -> void:
	refresh()
