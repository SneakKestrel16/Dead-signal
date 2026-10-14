class_name CharacterDef extends Resource
## One survivor character C1-C5 (lobby-role-assignment.md rule 5): its own look, colour and voice set.
## The shapeshifter's true form is a separate model, never one of these. One file per character under
## res://data/characters/, loaded by fixed name (ADR-0006). Values come only from those files; the art
## bible and audio direction own the real look, colour and voice set (the shipped ones are placeholders).
## Usage: `var cast := CharacterDef.load_all(); if not CharacterDef.errors(cast).is_empty(): refuse`

const DIR := "res://data/characters/"
## Fixed file names, in id order.
const IDS: Array[StringName] = [&"C1", &"C2", &"C3", &"C4", &"C5"]
## ADR-0010 §2 (Proposed): appearance id 0 is the true form, 1-5 are C1-C5.
const TRUE_FORM_APPEARANCE_ID := 0

@export var id: StringName
## The body model this character renders with (ADR-0010 Appearance id).
@export var appearance_id: int = -1
@export var colour: Color = Color(0, 0, 0, 0)
## The callout and voice set (pings-and-callouts.md: one voice set per character).
@export var voice_set: StringName


## Every character file in IDS order; a missing or wrong-typed file leaves a null (errors() names it).
static func load_all(dir: String = DIR) -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	for cid in IDS:
		var path := dir + String(cid).to_lower() + ".tres"
		out.append(load(path) as CharacterDef if ResourceLoader.exists(path) else null)
	return out


## Problems with a loaded cast; [] = valid: exactly the five ids in order, each look, colour and voice
## set distinct, and no look equal to the true form's.
static func errors(cast: Array[CharacterDef]) -> PackedStringArray:
	var errs := PackedStringArray()
	if cast.size() != IDS.size():
		errs.append("characters: %d loaded, need %d" % [cast.size(), IDS.size()])
		return errs
	var looks := {}
	var colours := {}
	var voices := {}
	for i in cast.size():
		var c := cast[i]
		if c == null:
			errs.append("character %s: file missing or not a CharacterDef" % IDS[i])
			continue
		if c.id != IDS[i]:
			errs.append("character file %s: id is %s" % [IDS[i], c.id])
		if c.appearance_id < 0 or c.appearance_id == TRUE_FORM_APPEARANCE_ID:
			errs.append("character %s: appearance_id %d is unset or the true form's" % [c.id, c.appearance_id])
		if c.colour.a == 0.0 or c.voice_set == &"":
			errs.append("character %s: colour or voice_set unset" % c.id)
		for pair: Array in [[looks, c.appearance_id, "look"], [colours, c.colour, "colour"], [voices, c.voice_set, "voice set"]]:
			var seen: Dictionary = pair[0]
			if seen.has(pair[1]):
				errs.append("character %s: same %s as %s" % [c.id, pair[2], seen[pair[1]]])
			seen[pair[1]] = c.id
	return errs
