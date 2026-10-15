# Story facility-map/010: lighting replication (research-facility.md AC 8, 9, 12; ADR-0009 §5). The send-phase
# provider sends a volume's record only to viewers whose visibility set holds it, on change, re-sent on
# re-entry and in full on a rejoin; viewers of the same volume get a change in the same tick.
extends GdUnitTestSuite

## Viewer 1 stands in A6 (sees A3, H-N1, H-N2), viewer 2 in C4 (sees C1, C2, C3): the two sets do not meet.
const IN_A6 := 1
const IN_C4 := 2
const ALSO_A6 := 3

var _knobs: Knobs
var _map: MapData
var _server: RoundServer
var _lighting: FacilityLighting
var _rep: LightingReplication
var _at: Dictionary[int, StringName] = {}
var _closed: Dictionary[int, bool] = {}


func before_test() -> void:
	_knobs = Knobs.load_all()
	_map = MapData.load_map()
	_server = auto_free(RoundServer.new())
	_lighting = FacilityLighting.new(_map)
	assert_array(_server.start_round({TickOrder.FACILITY_LIGHTING: _lighting}, _knobs)).is_empty()
	_at = {IN_A6: &"A6", IN_C4: &"C4", ALSO_A6: &"A6"}
	_closed = {}
	_rep = LightingReplication.new(_lighting, _map, _position, _door_closed, _server.tick_runner.current_tick)


func after_test() -> void:
	_server.end_round()


func _centre(volume: StringName) -> Vector3:
	for v in _map.volumes:
		if v.id == volume:
			return v.box.get_center()
	return Vector3(-1000.0, 0.0, -1000.0)


func _position(player: int) -> Vector3:
	if _at.get(player) == &"parked":
		return Vector3(0.0, -1000.0, 0.0)
	return _centre(_at.get(player, &""))


func _door_closed(net_id: int) -> bool:
	return _closed.has(net_id)


func _net_id(passage: StringName) -> int:
	var all := _map.interactables()
	for i in all.size():
		if all[i] is MapPassage and (all[i] as MapPassage).id == passage:
			return i
	return -1


func _step() -> void:
	_server.tick_runner.step()


## volume -> payload, from one entries() call.
func _by_volume(entries: Array) -> Dictionary:
	var out := {}
	for e: Array in entries:
		assert_str(String(e[0])).is_equal(String(EventBatch.LIGHTING))
		out[e[1].volume] = e[1]
	return out


func _blackout(volume: StringName) -> void:
	var e := EvAbilityUsed.new()
	e.ability = MonsterAbilities.Ability.BLACKOUT
	e.target = _centre(volume)
	_server.bus.emit(e)
	_server.bus.flush()


func test_first_stream_sends_own_volume_and_visible_set_then_nothing_unchanged() -> void:
	_step()
	var got := _by_volume(_rep.entries(IN_A6))
	assert_array(got.keys()).contains_exactly_in_any_order([&"A6", &"A3", &"H-N1", &"H-N2"])
	assert_int(got[&"A6"].base).is_equal(FacilityLighting.Base.LOW_POWER)
	assert_int(got[&"A6"].dark_until).is_equal(0)
	_step()
	assert_array(_rep.entries(IN_A6)).is_empty()


func test_evacuation_reaches_every_viewer_in_the_same_tick() -> void:
	_step()
	for p in [IN_A6, IN_C4, ALSO_A6]:
		_rep.entries(p)
	_step()
	var e := EvRoundPhaseChanged.new()
	e.phase = MatchFlow.Phase.EVACUATION
	_server.bus.emit(e)
	_server.bus.flush()
	for p in [IN_A6, IN_C4, ALSO_A6]:
		var got := _by_volume(_rep.entries(p))
		assert_bool(got.has(_at[p])).is_true()
		assert_int(got[_at[p]].base).is_equal(FacilityLighting.Base.EVACUATION)


func test_blackout_only_reaches_viewers_that_see_the_volume() -> void:
	_step()
	_rep.entries(IN_A6)
	_rep.entries(IN_C4)
	_step()
	_blackout(&"C4")
	assert_bool(_by_volume(_rep.entries(IN_A6)).has(&"C4")).is_false()
	var c4: Dictionary = _by_volume(_rep.entries(IN_C4))[&"C4"]
	assert_int(c4.dark_until).is_greater(0)
	# Viewer 1 walks into C4 during the Blackout: the current record goes out on re-entry.
	_step()
	_at[IN_A6] = &"C4"
	var later := _by_volume(_rep.entries(IN_A6))
	assert_int(later[&"C4"].dark_until).is_equal(c4.dark_until)


func test_blackout_end_is_sent_as_a_change() -> void:
	_step()
	_blackout(&"C4")
	_rep.entries(IN_C4)
	for i in _knobs.ticks(_knobs.ability.blackout_duration_s) + 1:
		_step()
	var got := _by_volume(_rep.entries(IN_C4))
	assert_int(got[&"C4"].dark_until).is_equal(0)


func test_closed_door_cuts_the_visible_set() -> void:
	_closed[_net_id(&"A3-A6")] = true
	_step()
	assert_bool(_by_volume(_rep.entries(IN_A6)).has(&"A3")).is_false()


func test_full_resends_every_visible_record() -> void:
	_step()
	_rep.entries(IN_A6)
	_step()
	assert_int(_rep.entries(IN_A6, true).size()).is_equal(4)


func test_outside_every_volume_gets_nothing() -> void:
	_at[IN_A6] = &""
	_step()
	assert_array(_rep.entries(IN_A6)).is_empty()


## Bodies not spawned yet (or Out) are parked far below the map, under H-N1's x and z.
func test_parked_body_below_the_map_gets_nothing() -> void:
	_at[IN_A6] = &"parked"
	_step()
	assert_array(_rep.entries(IN_A6)).is_empty()


## A spectator's stream is projected as the watched survivor: both streams of one tick get the same change.
func test_second_stream_as_the_same_player_in_one_tick_gets_the_same_entries() -> void:
	_step()
	var first := _rep.entries(IN_A6)
	assert_array(_rep.entries(IN_A6)).is_equal(first)
