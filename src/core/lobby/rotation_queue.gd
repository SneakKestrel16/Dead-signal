class_name RotationQueue extends RefCounted
## The session's shapeshifter rotation (lobby-role-assignment.md rules 8-10, Formulas "Rotation queue";
## AC-LB-13, AC-LB-15, AC-LB-16). Q_1 is a uniform shuffle of the tokens connected before the first
## round; the first present token is the shapeshifter; after a round that reaches Ended (forfeit
## included) that token moves to the back, and a Cancelled round leaves the queue as it was. Tokens,
## never peer IDs, so a reconnect keeps its place (rule 10). One per session, owned by RosterHandoff.
## Server only. Usage:
##   var q := RotationQueue.new()
##   var token := q.pick(lobby.tokens(), rng)   # at roster lock
##   q.advance()                                # only when that round reached Ended

var _order := PackedStringArray()
var _picked := "" ## the last pick(); advance() moves it to the back


## Q_r as it stands, head first (rule 11: the lobby shows the queue order).
func order() -> PackedStringArray:
	return _order.duplicate()


## Builds Q_1 on the first call (Fisher-Yates over `present` on `rng`); later calls append first-time
## joiners at the back in join order (`new_tokens`), at the next lock whatever the last round's outcome
## (the GDD formula adds them after Ended; a joiner during a Cancelled round's Waiting is added at the
## next lock too: a reading of rule 10, AD-114). Returns the first token of the queue that is in
## `present`, or "" when `present` is empty.
func pick(present: PackedStringArray, rng: RandomNumberGenerator) -> String:
	if _order.is_empty():
		_order = present.duplicate()
		for i in range(_order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := _order[i]
			_order[i] = _order[j]
			_order[j] = t
	for t in present:
		if not _order.has(t):
			_order.append(t)
	_picked = ""
	for t in _order:
		if present.has(t):
			_picked = t
			break
	return _picked


## The round reached Ended: Q_{r+1} = (Q_r without shapeshifter(r)) + [shapeshifter(r)]. Do not call
## for a Cancelled round (rule 9). Once per pick().
func advance() -> void:
	if _picked.is_empty():
		return
	_order.remove_at(_order.find(_picked))
	_order.append(_picked)
	_picked = ""
