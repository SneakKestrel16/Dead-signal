class_name CalloutSet extends Resource
## The authored callout set (design/gdd/pings-and-callouts.md rule 9; story pings-and-callouts/003: the lines are
## data). Values come only from res://data/callouts/callout_set.tres, validated at load: a bad set is reported,
## never defaulted. Line ids are what the server and the wire carry; `texts` is the feed text, same order.
## Usage: `var s := CalloutSet.load_shipped(); var t := s.text_of(&"drive_here")`

const PATH := "res://data/callouts/callout_set.tres"

## Line ids, in wheel order.
@export var lines: Array[StringName] = []
## Feed text of each line (rule 10 `[Name]: [text]`), parallel to `lines`.
@export var texts: PackedStringArray = PackedStringArray()


## The shipped set; null (with push_error per problem) when it is missing or invalid. `required` are the ids
## the rules name (PingsCallouts' consts); each must be in the set.
static func load_shipped(required: Array[StringName] = []) -> CalloutSet:
	var s := load(PATH) as CalloutSet
	if s == null:
		push_error("CalloutSet: %s did not load" % PATH)
		return null
	var errs := s.errors(required)
	for e in errs:
		push_error("CalloutSet: %s" % e)
	return null if not errs.is_empty() else s


## The shipped line ids, or [] when the set is invalid (every callout is then rejected, never defaulted).
static func shipped_lines(required: Array[StringName]) -> Array[StringName]:
	var s := load_shipped(required)
	return s.lines if s != null else ([] as Array[StringName])


## Every problem in the set; [] = valid.
func errors(required: Array[StringName] = []) -> PackedStringArray:
	var errs := PackedStringArray()
	if lines.is_empty():
		errs.append("set has no lines")
	if texts.size() != lines.size():
		errs.append("%d texts for %d lines" % [texts.size(), lines.size()])
	for i in lines.size():
		if lines[i] == &"" or lines.find(lines[i]) != i:
			errs.append("empty or duplicate line id %s" % lines[i])
	for id in required:
		if id not in lines:
			errs.append("missing line %s" % id)
	return errs


## The feed text of `line`, or "" when it is not in the set.
func text_of(line: StringName) -> String:
	var i := lines.find(line)
	return texts[i] if i >= 0 and i < texts.size() else ""
