class_name CharacterAssignment extends RefCounted
## Survivor characters for one round (lobby-role-assignment.md rule 7). Phase M1 deals them at random:
## each survivor gets one distinct character, the shapeshifter none (it is not passed in). Lobby story
## 009 replaces deal_m1 with the preference-and-clash formula. Server-side at roster lock.
## Usage: `var chars := CharacterAssignment.deal_m1(survivor_ids, CharacterDef.IDS, rng)`


## player ID -> character id for every survivor, all distinct, drawn with `rng` (seed it in tests).
## Empty when there are more survivors than characters (cannot happen: at most 5 survivors, rule 7).
static func deal_m1(survivors: Array[int], characters: Array[StringName], rng: RandomNumberGenerator) -> Dictionary:
	if survivors.size() > characters.size():
		return {}
	var pool := characters.duplicate()
	for i in range(pool.size() - 1, 0, -1): ## Fisher-Yates on the injected RNG
		var j := rng.randi_range(0, i)
		var t: StringName = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var out := {}
	for i in survivors.size():
		out[survivors[i]] = pool[i]
	return out
