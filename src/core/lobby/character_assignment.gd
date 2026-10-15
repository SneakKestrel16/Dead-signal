class_name CharacterAssignment extends RefCounted
## Survivor characters for one round (lobby-role-assignment.md rule 7, Formulas "Character
## assignment"; TR-lobby-006). assign() is the preference-and-clash formula Roster.lock uses (story 009);
## deal_m1 is the M1 random deal, now the step that deals clash losers the free characters. Each
## survivor gets one distinct character, the shapeshifter none (it is not passed in). Server-side at
## roster lock.
## Usage: `var chars := CharacterAssignment.assign(survivor_prefs, CharacterDef.IDS, rng)`


## player ID -> character id for every survivor in `prefs` (survivor player ID -> preferred character),
## all distinct, drawn with `rng` (seed it in tests). A preference no other survivor shares is kept; of
## k survivors sharing one, one uniformly random claimant keeps it (W); the rest (L) are dealt the
## characters nobody kept by a uniform permutation. A preference outside `characters` (or &"") claims
## nothing: that survivor is dealt like a clash loser. Empty when there are more survivors than characters.
static func assign(prefs: Dictionary[int, StringName], characters: Array[StringName], rng: RandomNumberGenerator) -> Dictionary:
	if prefs.size() > characters.size():
		return {}
	var out := {}
	var free: Array[StringName] = []
	for c in characters: ## characters order, claimants in `prefs` order: deterministic for a seed
		var claimants: Array[int] = []
		for id: int in prefs:
			if prefs[id] == c:
				claimants.append(id)
		if claimants.is_empty():
			free.append(c)
		else:
			out[claimants[rng.randi_range(0, claimants.size() - 1)]] = c
	var losers: Array[int] = []
	for id: int in prefs:
		if not out.has(id):
			losers.append(id)
	out.merge(deal_m1(losers, free, rng))
	return out


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
