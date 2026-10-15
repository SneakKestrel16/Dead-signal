class_name WorldProgressBars extends Node3D
## Client side of H13 world progress bars (design/ux/hud.md H13; interaction-patterns P4; story
## hud-results/005): one billboard Label3D above each object WorldProgress reports, fill plus percent, and
## "Paused" as text. Driven only by the server's entries: progress at the entry's tick plus `rate` times
## the server ticks since (never predicted from local input). Decides nothing.
## GREYBOX: a text bar stands in for the art pass.
## Usage: `var b := WorldProgressBars.new(knobs, estimated_tick); add_child(b)`
##        `router.subscribe(EventBatch.PROGRESS, b.on_progress)`

## GREYBOX: label height above the interaction point, cells in the text bar.
const ABOVE_M := 0.6
const CELLS := 10

var _hz: float
var _now_tick: Callable
## key -> {at, progress, rate, paused, tick, label}
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
			_bars[k].label.queue_free()
			_bars.erase(k)
		return
	if not (p.get("at") is Vector3 and p.get("progress") is float and p.get("rate") is float
			and p.get("paused") is bool):
		return
	if not _bars.has(k):
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 40
		l.outline_size = 10
		l.pixel_size = 0.004
		add_child(l)
		_bars[k] = {"label": l}
	var b := _bars[k]
	b.merge({"at": p.at, "progress": p.progress, "rate": p.rate, "paused": p.paused, "tick": tick}, true)
	b.label.position = p.at + Vector3.UP * ABOVE_M
	b.label.text = text_of(k)


## Keys of the bars showing.
func keys() -> Array:
	return _bars.keys()


## Progress 0-1 of bar `key` now.
func progress_of(key: int) -> float:
	var b := _bars[key]
	var dt: float = maxf(_now_tick.call() - b.tick, 0.0) / _hz
	return clampf(b.progress + b.rate * dt, 0.0, 1.0)


## The label text of bar `key` now: cells, percent, and "Paused" when paused.
func text_of(key: int) -> String:
	var f := progress_of(key)
	var n := roundi(f * CELLS)
	var t := "[%s%s] %d%%" % ["|".repeat(n), ".".repeat(CELLS - n), floori(f * 100.0)]
	return "%s  %s" % [t, tr("Paused")] if _bars[key].paused else t


func _process(_delta: float) -> void:
	for k: int in _bars:
		_bars[k].label.text = text_of(k)
