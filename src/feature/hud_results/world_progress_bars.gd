class_name WorldProgressBars extends Node3D
## Client side of H13 world progress bars (design/ux/hud.md H13; interaction-patterns P4; story
## hud-results/005; ASSET-087): above each object WorldProgress reports, a billboard bar (QuadMesh with
## spatial_ui_world_progress.gdshader, HUD white on black) and a Label3D over it with the percent and "Paused"
## as text (P4: fill plus number; paused is a word, not a colour). Driven only by the server's entries: progress at the entry's tick plus `rate` times
## the server ticks since (never predicted from local input). Decides nothing.
## Usage: `var b := WorldProgressBars.new(knobs, estimated_tick); add_child(b)`
##        `router.subscribe(EventBatch.PROGRESS, b.on_progress)`

## Bar height above the interaction point, bar size, and the label's lift above the bar (m). Inference: sized to
## read at hold range (~1.5 m) without covering the object; no spec gives numbers.
const ABOVE_M := 0.6
const BAR_SIZE := Vector2(0.42, 0.05)
const LABEL_ABOVE_M := 0.06
const SHADER := preload("res://src/feature/hud_results/spatial_ui_world_progress.gdshader")

var _hz: float
var _now_tick: Callable
## key -> {at, progress, rate, paused, tick, node, bar (ShaderMaterial), label}
var _bars: Dictionary[int, Dictionary] = {}


## `now_tick() -> float`: the estimated server tick (RoundClient.estimated_tick).
func _init(knobs: Knobs, now_tick: Callable) -> void:
	_hz = float(knobs.net.sim_tick_hz)
	_now_tick = now_tick


## ClientEventRouter handler for EventBatch.PROGRESS. Bad payloads are ignored.
func on_progress(tick: int, p: Dictionary) -> void:
	var k: Variant = p.get("key")
	if not k is int:
		return
	if p.get("end", false):
		if _bars.has(k):
			_bars[k].node.queue_free()
			_bars.erase(k)
		return
	if not (p.get("at") is Vector3 and p.get("progress") is float and p.get("rate") is float
			and p.get("paused") is bool):
		return
	if not _bars.has(k):
		_bars[k] = _make()
	var b := _bars[k]
	b.merge({"at": p.at, "progress": p.progress, "rate": p.rate, "paused": p.paused, "tick": tick}, true)
	b.node.position = p.at + Vector3.UP * ABOVE_M
	_draw(k)


## Keys of the bars showing.
func keys() -> Array:
	return _bars.keys()


## Progress 0-1 of bar `key` now.
func progress_of(key: int) -> float:
	var b := _bars[key]
	var dt: float = maxf(_now_tick.call() - b.tick, 0.0) / _hz
	return clampf(b.progress + b.rate * dt, 0.0, 1.0)


## The label text of bar `key` now: percent, and "Paused" when paused.
func text_of(key: int) -> String:
	var t := "%d%%" % floori(progress_of(key) * 100.0)
	return "%s  %s" % [t, tr("Paused")] if _bars[key].paused else t


## The bar's drawn fill 0-1 (checks).
func fill_of(key: int) -> float:
	return _bars[key].bar.get_shader_parameter(&"fill")


func _process(_delta: float) -> void:
	for k: int in _bars:
		_draw(k)


func _draw(key: int) -> void:
	var b := _bars[key]
	b.bar.set_shader_parameter(&"fill", progress_of(key))
	b.label.text = text_of(key)


func _make() -> Dictionary:
	var node := Node3D.new()
	var quad := QuadMesh.new()
	quad.size = BAR_SIZE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mesh)
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 32
	l.outline_size = 10
	l.pixel_size = 0.0035
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.position = Vector3.UP * LABEL_ABOVE_M
	node.add_child(l)
	add_child(node)
	return {"node": node, "bar": mat, "label": l}
