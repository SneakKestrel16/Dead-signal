class_name BackupSwitch extends Interactable
## One room's backup light switch (design/gdd/monster-abilities.md rule 19; ADR-0009 §2; ADR-0008;
## story monster-abilities/010). A hold of ability.backup_switch_hold_s within backup_switch_range_m ends
## the Blackout in the switch's own volume. Not rooting, no lock (any survivor may hold it; the first to
## complete wins), progress resets on cancel, not fakeable: `eligible` refuses the shapeshifter.
## Holds FacilityLighting weakly (HoldService keeps this). A top-level script, not an inner class: see
## docs/engine-reference/godot/gotchas.md.
## Usage: `var ids := BackupSwitch.register_all(holds, map, lighting, knobs, healthy_survivor)`

## The map volume this switch restores.
var volume: StringName
## FacilityLighting, as a WeakRef.
var lighting: WeakRef
## `can_use.call(actor) -> bool`: a survivor allowed to interact (the composer's Healthy-survivor rule).
var can_use: Callable


## Registers one BackupSwitch per `switch` marker of `map`, in map order; returns their net ids.
## `can_use(actor) -> bool` must be false for the shapeshifter (rule 19: it may not fake the hold).
static func register_all(holds: HoldService, map: MapData, lights: FacilityLighting, knobs: Knobs,
		can_use_: Callable) -> Array[int]:
	var rules := MapQueries.InteractRules.from_knobs(knobs)
	var ids: Array[int] = []
	for t: Resource in map.interactables():
		var m := t as MapMarker
		if m == null or m.type != &"switch":
			continue
		var s := BackupSwitch.new()
		s.volume = m.volume
		s.lighting = weakref(lights)
		s.can_use = can_use_
		s.point = m.position + Vector3.UP * rules.point_height_m
		s.range_m = rules.range_by_type[&"switch"]
		s.duration_s = knobs.ability.backup_switch_hold_s
		s.roots_actor = false
		s.fakeable = false
		ids.append(holds.register(s))
	return ids


## Inference: a switch may be held whether or not its room is dark (holding a lit room's switch does
## nothing); a GDD line on the prompt in a lit room would settle it.
func eligible(actor: int) -> bool:
	return can_use.is_valid() and can_use.call(actor)


## Rule 19: progress resets on cancel.
func start_progress_s() -> float:
	return 0.0


## Rule 19: restores only the switch's own volume, at once. The monster's cooldown is untouched.
func on_complete(_actor: int) -> void:
	var l := lighting.get_ref() as FacilityLighting
	if l != null:
		l.end_blackout(volume)


func on_cancel(_actor: int, _progress_s: float, _reason: StringName) -> void:
	pass
