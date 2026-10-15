class_name MovementModifiers extends RefCounted
## The per-owner speed modifier set read by the shared movement step (ADR-0002 rule 5-6 and `apply_move`;
## first-person-controller.md rule 6 and Formulas effective_speed). Each owner (taser, takedown, rescue,
## ...) adds and removes only its own entry; only the most restrictive applies: lock > root > lowest
## slow, never a product. The server fills it; the owning client takes the scale from the latest
## own-body snapshot entry (set_from_scale).
## Usage:
##   mods.add(&"taser_root", MovementModifiers.Kind.ROOT); mods.remove(&"taser_root")
##   var speed := mods.effective(gait_speed)

enum Kind { LOCK, ROOT, SLOW }

## The owner set_from_scale files the snapshot's modifier under (owning client only).
const SNAPSHOT_OWNER := &"_snapshot"

## The three fields below are derived from the set: change them only through add, remove or
## set_from_scale (a direct write is lost at the next rebuild).
## Lowest active slow multiplier, 1.0 when none. Read by the step.
var speed_scale: float = 1.0
## No movement input is applied while rooted. Derived from the set.
var rooted: bool = false
## No movement or look input is applied while locked. Derived from the set.
var locked: bool = false

## owner -> [Kind, mult]. One entry per owner: a second add() by the same owner replaces it.
var _entries: Dictionary[StringName, Array] = {}


## Adds or replaces `owner`'s modifier. `mult` is used by SLOW only and clamped to 0-1 (GDD Output
## Range: never negative, never above the gait speed).
func add(owner: StringName, kind: Kind, mult: float = 1.0) -> void:
	_entries[owner] = [kind, clampf(mult, 0.0, 1.0)]
	_rebuild()


## Removes `owner`'s modifier; an owner with none changes nothing.
func remove(owner: StringName) -> void:
	if _entries.erase(owner):
		_rebuild()


## effective_speed for a gait speed `base`: 0 when locked or rooted, else base × lowest slow.
func effective(base: float) -> float:
	return base * effective_scale()


## The single scale a snapshot carries: 0.0 when rooted or locked, else speed_scale.
func effective_scale() -> float:
	return 0.0 if rooted or locked else speed_scale


## Replaces the set with one entry from a snapshot scale, so a later add/remove rebuilds from it
## (code review 2026-10-14). 0.0 reads as rooted (a snapshot cannot tell root from lock); above 1
## and NaN read as full speed, so a bad snapshot never speeds a body up.
func set_from_scale(scale: float) -> void:
	_entries.clear()
	# NaN and anything >= 1 fail both comparisons, so they add nothing: full speed.
	if scale <= 0.0:
		_entries[SNAPSHOT_OWNER] = [Kind.ROOT, 1.0]
	elif scale < 1.0:
		_entries[SNAPSHOT_OWNER] = [Kind.SLOW, scale]
	_rebuild()


func _rebuild() -> void:
	locked = false
	rooted = false
	speed_scale = 1.0
	for e: Array in _entries.values():
		match e[0]:
			Kind.LOCK:
				locked = true
			Kind.ROOT:
				rooted = true
			Kind.SLOW:
				speed_scale = minf(speed_scale, e[1])
