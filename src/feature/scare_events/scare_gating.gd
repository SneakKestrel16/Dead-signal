class_name ScareGating extends RefCounted
## Per-recipient scare gating, story scare-events/002 (design/gdd/scare-events.md rules 9-12; Formulas
## "Scare gating (per recipient)"; ADR-0015). Pure: no scene, no bus, no clock; the caller passes the time
## and the facility phase. One instance per round (ScareEvents.setup makes a new one), so every record resets
## at round start. Gating knows recipient ids only, never roles: a disguised shapeshifter is gated exactly
## like a survivor (AC 4).
## Usage:
##   var g := ScareGating.new(knobs.scare)
##   var intensity := g.gate(peer, entry, origin, clock.elapsed_s(), clock.phase())
##   if intensity != ScareGating.BLOCKED: deliver at `intensity`

## gate() result: the scare is not delivered to this recipient.
const BLOCKED := -1

var _knobs: ScareKnobs
## recipient id -> Record
var _records: Dictionary = {}


## One client's gating state for the round.
class Record extends RefCounted:
	var last_major: float = -INF
	var last_any: float = -INF
	## "scare_id@location" -> last delivery time (rule 11 repeat block).
	var last_fire: Dictionary = {}
	## scare_ids of once-per-round entries already delivered (rule 11).
	var once: Dictionary = {}
	## Phase whose budget `budget_used` counts; a different phase starts a fresh count (Formulas: reset on
	## RoundPhaseChanged).
	var budget_phase: int = -1
	var budget_used: int = 0
	var hallucinations: int = 0


func _init(knobs: ScareKnobs) -> void:
	_knobs = knobs


## Gates `entry` at `location` for `recipient` at round time `now_s` in facility `phase` (ScareEntry.Phase),
## and records the delivery. Returns the intensity to deliver (ScareEntry.Intensity) or BLOCKED.
## Monster-source scares are never blocked, only reduced Major -> Minor inside the Major cooldown (rules 5, 9).
func gate(recipient: int, entry: ScareEntry, location: Vector3, now_s: float, phase: int) -> int:
	var r := _records.get(recipient) as Record
	if r == null:
		r = Record.new()
		_records[recipient] = r
	if r.budget_phase != phase:
		r.budget_phase = phase
		r.budget_used = 0
	var key := "%s@%s" % [entry.scare_id, location]
	var in_major := now_s - r.last_major < _knobs.major_scare_cooldown_s
	var round_script := entry.source == ScareEntry.Source.ROUND_SCRIPT
	var single := entry.scope == ScareEntry.Scope.SINGLE_CLIENT
	if entry.source != ScareEntry.Source.MONSTER:
		if in_major or now_s - r.last_any < _knobs.minor_scare_cooldown_s:
			return BLOCKED
		if now_s - float(r.last_fire.get(key, -INF)) < _knobs.same_scare_repeat_block_s:
			return BLOCKED
		if round_script and r.budget_used >= _knobs.phase_budget[phase]:
			return BLOCKED
		# Rule 11 "fires at most once" kept per recipient (inference: the GDD does not say whether once is
		# per round overall or per client; per client matches the per-recipient record. A designer ruling
		# settles it).
		if entry.once_per_round and r.once.has(entry.scare_id):
			return BLOCKED
		# Rule 12, inside the non-Monster branch so a Monster scare stays never-blocked (rule 10).
		if single and r.hallucinations >= _knobs.hallucination_max_per_client:
			return BLOCKED
	var intensity := entry.intensity
	if intensity == ScareEntry.Intensity.MAJOR and in_major:
		intensity = ScareEntry.Intensity.MINOR
	r.last_any = now_s
	if intensity == ScareEntry.Intensity.MAJOR:
		r.last_major = now_s # a reduced Minor does not restart it (Formulas)
	r.last_fire[key] = now_s
	if round_script:
		r.budget_used += 1
	if entry.once_per_round:
		r.once[entry.scare_id] = true
	if single:
		r.hallucinations += 1
	return intensity
