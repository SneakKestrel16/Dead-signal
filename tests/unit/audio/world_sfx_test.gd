# Audio pass (design/game-brief.md): WorldSfx turns replicated door, barricade, objective and phase state into
# bank sounds (entity-inventory.md Audio rows 9-10, 25, 34): a door opening or closing, a barricade built or
# broken, a drive docked, the Evacuation alarm. The first door snapshot is the baseline and plays nothing.
extends GdUnitTestSuite

const LISTENER := Vector3(1, 2, 3)

var _map: MapData
var _sfx: WorldSfx
## [sound, at] of every play, in order.
var _plays: Array = []


func before_test() -> void:
	_map = MapData.load_map()
	_plays = []
	_sfx = WorldSfx.new(_map, _play, func() -> Vector3: return LISTENER)


func _play(sound: StringName, at: Vector3) -> void:
	_plays.append([sound, at])


func _door_at(net_id: int) -> Vector3:
	return (_map.interactables()[net_id] as MapPassage).position


func _closed(count: int) -> Array:
	var out := []
	out.resize(count)
	out.fill(true)
	return out


func test_first_doors_snapshot_is_silent_and_each_change_plays_at_its_door() -> void:
	var n := _sfx.door_count()
	assert_int(n).is_greater(1)
	var states := _closed(n)
	_sfx.on_doors(1, {"closed": states.duplicate(), "exit": false})
	assert_array(_plays).is_empty()
	states[1] = false
	_sfx.on_doors(2, {"closed": states.duplicate(), "exit": false})
	_sfx.on_doors(3, {"closed": states.duplicate(), "exit": false})
	states[1] = true
	_sfx.on_doors(4, {"closed": states.duplicate(), "exit": false})
	assert_array(_plays).is_equal([[WorldSfx.DOOR_OPEN, _door_at(1)], [WorldSfx.DOOR_CLOSE, _door_at(1)]])


func test_exit_opening_plays_once_and_malformed_doors_are_ignored() -> void:
	var n := _sfx.door_count()
	_sfx.on_doors(1, {"closed": _closed(n), "exit": false})
	_sfx.on_doors(2, {"closed": _closed(n), "exit": true})
	_sfx.on_doors(3, {"closed": _closed(n), "exit": true})
	_sfx.on_doors(4, {"closed": [1, 2], "exit": true})
	assert_int(_plays.size()).is_equal(1)
	assert_str(String(_plays[0][0])).is_equal(String(WorldSfx.DOOR_OPEN))


func test_barricade_built_and_broken_play_at_the_door() -> void:
	_sfx.on_barricade(1, {"door": 0, "barricaded": true})
	_sfx.on_barricade(2, {"door": 0, "barricaded": false})
	_sfx.on_barricade(3, {"door": 999, "barricaded": true})
	assert_array(_plays).is_equal([[WorldSfx.BARRICADE_BUILD, _door_at(0)], [WorldSfx.BARRICADE_BREAK, _door_at(0)]])


func test_drive_dock_and_evacuation_alarm_play_once() -> void:
	var at := Vector3(4, 0, 5)
	var docked := SurvivorObjectives.DriveState.DOCKED
	_sfx.on_objective(1, {"objective": SurvivorObjectives.DRIVE_ID, "state": docked, "at": at})
	_sfx.on_objective(2, {"objective": SurvivorObjectives.DRIVE_ID, "state": docked, "at": at})
	_sfx.on_objective(3, {"objective": SurvivorObjectives.FUSE_ID, "state": SurvivorObjectives.FuseState.CARRIED, "at": at})
	_sfx.on_phase(4, {"phase": MatchFlow.Phase.INVESTIGATION})
	_sfx.on_phase(5, {"phase": MatchFlow.Phase.EVACUATION})
	assert_array(_plays).is_equal([[WorldSfx.DOCK, at], [WorldSfx.ALARM, LISTENER]])


func test_every_world_sound_has_a_bank_entry() -> void:
	var bank := SoundBank.load_shipped()
	for s: StringName in [WorldSfx.DOOR_OPEN, WorldSfx.DOOR_CLOSE, WorldSfx.BARRICADE_BUILD,
			WorldSfx.BARRICADE_BREAK, WorldSfx.DOCK, WorldSfx.ALARM]:
		assert_bool(bank.resolve(s) != null).override_failure_message(String(s)).is_true()
