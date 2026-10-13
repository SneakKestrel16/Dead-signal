# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does one networked greybox round deliver "you can't be sure the person next to you is a person"?
# Date: 2026-10-13
extends Node
## Tuning values loaded from res://data/knobs.json. A missing key is an error, never a silent default.

var _v: Dictionary = {}


func _ready() -> void:
	var f := FileAccess.open("res://data/knobs.json", FileAccess.READ)
	if f == null:
		push_error("knobs: res://data/knobs.json missing")
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		push_error("knobs: knobs.json is not a JSON object")
		return
	_v = d


## Returns the knob `key` as a float.
func f(key: String) -> float:
	if not _v.has(key):
		push_error("knobs: missing key " + key)
		return 0.0
	return float(_v[key])


## Returns the knob `key` as an int.
func i(key: String) -> int:
	return int(f(key))
