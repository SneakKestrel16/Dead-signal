class_name SoundBank extends Resource
## The audio pass's sound map (design/game-brief.md; ADR-0013 §2 catalog ids): event id -> SoundBankEntry.
## Generated with its files by tools/audio/build_audio.py; values live in res://data/audio/sound_bank.tres.
## resolve() falls back from the most to the least specific id, so one entry serves a family of ids:
## `c3.walk` on tile tries `c3.walk@tile`, `c3.walk`, `c3@tile`, `c3`; `callout/voice_c2/danger` tries
## `callout/voice_c2/danger`, `callout/voice_c2`, `callout`. An id with no entry resolves to null, and the
## caller keeps its generated placeholder tone. A disguised shapeshifter's footsteps and voice already
## arrive as the copied survivor's ids (Footsteps, DisguisePresenter, CalloutDelivery), so they resolve to
## that survivor's entries exactly (borrowed-face.md rule 8, LB-6).
## Usage: `var e := SoundBank.load_shipped().resolve(&"c3.walk", &"tile")`

const PATH := "res://data/audio/sound_bank.tres"

## id -> SoundBankEntry
@export var entries: Dictionary[StringName, Resource] = {}
## Last id segment -> extra gain, dB (footstep gaits: `c3.sprint` is louder than `c3.walk`).
@export var suffix_db: Dictionary[StringName, float] = {}
## Map zone (MapVolume.zone) -> footstep surface (data/art/surface_materials.tres floors: A tile, B checker
## plate = metal, C and link concrete).
@export var surface_of_zone: Dictionary[StringName, StringName] = {}
## Surface of a sound heard nowhere on the map (&"" passed to resolve).
@export var default_surface: StringName = &"concrete"


## The shipped bank; an empty one (every id falls back to its tone) when the file is missing.
static func load_shipped() -> SoundBank:
	var b := load(PATH) as SoundBank
	if b == null:
		push_error("SoundBank: %s did not load" % PATH)
		return SoundBank.new()
	return b


## The entry for `id` heard on `surface` (&"" = default_surface), or null.
func resolve(id: StringName, surface: StringName = &"") -> SoundBankEntry:
	var key := String(id)
	if surface == &"":
		surface = default_surface
	while true:
		if surface != &"" and entries.has(StringName(key + "@" + surface)):
			return _ready_entry(entries[StringName(key + "@" + surface)])
		if entries.has(StringName(key)):
			return _ready_entry(entries[StringName(key)])
		var cut := maxi(key.rfind("."), key.rfind("/"))
		if cut <= 0:
			return null
		key = key.left(cut)
	return null


## Extra gain of `id`'s last segment (suffix_db), 0 when it has none.
func extra_db(id: StringName) -> float:
	var s := String(id)
	return suffix_db.get(StringName(s.substr(s.rfind(".") + 1)), 0.0) if s.contains(".") else 0.0


static func _ready_entry(e: SoundBankEntry) -> SoundBankEntry:
	if e.loop and e.stream != null and &"loop" in e.stream:
		e.stream.set(&"loop", true)
	return e
