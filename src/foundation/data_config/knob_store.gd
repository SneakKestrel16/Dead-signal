class_name KnobStore extends RefCounted
## The knob set the next round takes (ADR-0006 §5). The composition root asks for_round() at each round
## start and passes that Knobs to every module's setup(); a round's modules keep that one object, so a
## debug reload mid-round changes nothing until the next round start. Never an autoload.
## Usage:
##   var store := KnobStore.new()
##   server.start_round(modules, store.for_round())
##   store.reload()   # debug builds only; applies at the next start_round

var _dir: String
var _next: Knobs


## Loads the set from `dir` (a test hook, as in Knobs.load_all). Check for_round().errors() before hosting.
func _init(dir: String = Knobs.KNOB_DIR) -> void:
	_dir = dir
	_next = Knobs.load_all(dir)


## The set for the round about to start. The same object until the next successful reload().
func for_round() -> Knobs:
	return _next


## Debug-only: re-runs load_all(). A valid result replaces the next round's set; a broken one is
## refused and the current set stays. Returns the errors ([] = applied). Release builds refuse it.
func reload() -> PackedStringArray:
	if not OS.is_debug_build():
		return PackedStringArray(["knob reload is debug-only"])
	var k := Knobs.load_all(_dir)
	var errs := k.errors()
	if errs.is_empty():
		_next = k
	return errs
