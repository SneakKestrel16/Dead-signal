class_name MatchStatsView extends RefCounted
## Round stats owned by Match Flow (StateKeys.STATS_MATCH, ADR-0011 §1-2): survivor fates and the round's
## start and end tick. Getters only. Holds the module weakly, so no RefCounted cycle survives
## end_round(); after the module is freed it reads ELIMINATED / -1.

var _mf: WeakRef


func _init(mf: MatchFlow) -> void:
	_mf = weakref(mf)


## Survivor `player_id`'s MatchFlow.Status (ESCAPED, ELIMINATED, DISCONNECTED, DID_NOT_ESCAPE once ended).
func get_fate(player_id: int) -> int:
	var mf := _mf.get_ref() as MatchFlow
	return mf.status_of(player_id) if mf != null else MatchFlow.Status.ELIMINATED


## Server tick at which the round clock read 0, -1 before the first tick.
func get_start_tick() -> int:
	var mf := _mf.get_ref() as MatchFlow
	return mf._start_tick if mf != null else -1


## Server tick RoundEnded was emitted on, -1 before.
func get_end_tick() -> int:
	var mf := _mf.get_ref() as MatchFlow
	return mf._end_tick if mf != null else -1
