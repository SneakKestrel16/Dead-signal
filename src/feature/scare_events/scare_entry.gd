class_name ScareEntry extends Resource
## One authored scare (scare-events.md rules 2, 6-8, 19 and the catalogue table). Pure data: values come only
## from res://data/scare_events/scare_catalogue.tres. The enum fields default to -1 and scare_id to &"" so an
## entry that forgot one is a load problem (ScareCatalogue.errors), never a silent default.
## Presentation keys (flash, flash_s, shake_*) are the ones ScarePresenter reads; their values are greybox
## placeholders (inference: the GDD names the kinds of reaction, not numbers; the M4 horror pass settles them).

## Rule 2: who caused it. Monster and Survivor name a player; RoundScript is the authored script.
enum Source { MONSTER, SURVIVOR, ROUND_SCRIPT }
## Rule 19-20: SHARED goes to every relevant client, SINGLE_CLIENT (hallucination) to exactly one.
enum Scope { SHARED, SINGLE_CLIENT }
## Rule 8: Major = stinger + flash or camera reaction, Minor = positional sound, light flicker.
enum Intensity { MAJOR, MINOR }
## Catalogue table "Category" column.
enum Category { PLAYER, ENVIRONMENT, DECEPTION }
## Facility scare state (States and Transitions): Low, Rising, Emergency. Indexes ScareKnobs.phase_budget.
enum Phase { LOW, RISING, EMERGENCY }

@export var scare_id: StringName = &""
@export var category: int = -1
@export var source: int = -1
@export var scope: int = -1
@export var intensity: int = -1
## Rule 19: authored audible range, m, used by the recipient step (story 003).
@export var audible_range_m: float = 0.0
## Rule 6: the phases a RoundScript scare may be drawn in (Phase values); required for RoundScript entries.
@export var phases: PackedInt32Array = PackedInt32Array()
## Rule 6: the map zones (A, B, C, link) a RoundScript scare may be drawn in; required for RoundScript entries.
@export var zones: PackedStringArray = PackedStringArray()
## Facility Map scare anchor ids (research-facility.md Scare anchors) a RoundScript door or glass scare plays at.
@export var anchors: PackedStringArray = PackedStringArray()
## Rule 11: fires at most once per round (e.g. a specific recording).
@export var once_per_round: bool = false
## ScarePresenter keys; 0 = none of that kind.
@export var flash: float = 0.0
@export var flash_s: float = 0.0
@export var shake_deg: float = 0.0
@export var shake_m: float = 0.0
@export var shake_s: float = 0.0


## What is wrong with this entry; [] = valid.
func errors() -> PackedStringArray:
	var errs := PackedStringArray()
	var id := String(scare_id)
	if scare_id == &"":
		errs.append("entry has no scare_id")
		id = "?"
	if not source in Source.values():
		errs.append("%s: source unset or not Monster/Survivor/RoundScript" % id)
	if not scope in Scope.values():
		errs.append("%s: scope unset or not Shared/SingleClient" % id)
	if not intensity in Intensity.values():
		errs.append("%s: intensity unset or not Major/Minor" % id)
	if not category in Category.values():
		errs.append("%s: category unset" % id)
	if audible_range_m < 0.0:
		errs.append("%s: audible_range_m %s is negative" % [id, audible_range_m])
	for p in phases:
		if not p in Phase.values():
			errs.append("%s: phase %d is not Low/Rising/Emergency" % [id, p])
	# Rule 21: a Monster-source hallucination plays the monster's own action, its real position, to one client.
	if scope == Scope.SINGLE_CLIENT and source == Source.MONSTER:
		errs.append("%s: a hallucination may not be Monster source (rule 21)" % id)
	if source == Source.ROUND_SCRIPT and (phases.is_empty() or zones.is_empty()):
		errs.append("%s: a RoundScript scare needs phases and zones (rule 6)" % id)
	return errs


## The ScarePresenter's entry dictionary (only the keys it reads).
func presenter_entry() -> Dictionary:
	return {"flash": flash, "flash_s": flash_s, "shake_deg": shake_deg, "shake_m": shake_m, "shake_s": shake_s}
