class_name ScareCatalogue extends Resource
## The authored scare catalogue (scare-events.md Detailed Design table; ADR-0005: the catalogue is data).
## Values come only from res://data/scare_events/scare_catalogue.tres, validated at load: a bad entry or a
## duplicate id is reported, never defaulted. False Signal has no entry on purpose (rule 4a).
## Usage: `var c := ScareCatalogue.load_shipped(); var e := c.entry(&"door_burst")`

const PATH := "res://data/scare_events/scare_catalogue.tres"

@export var entries: Array[ScareEntry] = []

var _by_id: Dictionary = {}


## The shipped catalogue; null (with push_error per problem) when it is missing or invalid.
static func load_shipped() -> ScareCatalogue:
	var c := load(PATH) as ScareCatalogue
	if c == null:
		push_error("ScareCatalogue: %s did not load" % PATH)
		return null
	var errs := c.errors()
	for e in errs:
		push_error("ScareCatalogue: %s" % e)
	return null if not errs.is_empty() else c


## Every problem in the catalogue; [] = valid. Also builds the id index.
func errors() -> PackedStringArray:
	var errs := PackedStringArray()
	_by_id = {}
	if entries.is_empty():
		errs.append("catalogue has no entries")
	for e in entries:
		if e == null:
			errs.append("catalogue has a null entry")
			continue
		errs.append_array(e.errors())
		if _by_id.has(e.scare_id):
			errs.append("duplicate scare_id %s" % e.scare_id)
		_by_id[e.scare_id] = e
	return errs


## The entry for `id`, or null.
func entry(id: StringName) -> ScareEntry:
	if _by_id.is_empty():
		errors()
	return _by_id.get(id)


## scare id -> ScarePresenter entry dictionary, for the client presenter.
func presenter_catalog() -> Dictionary:
	var out := {}
	for e in entries:
		out[e.scare_id] = e.presenter_entry()
	return out
