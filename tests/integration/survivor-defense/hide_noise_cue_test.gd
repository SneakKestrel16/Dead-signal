# Story survivor-defense/010: hide noise and the long-hide cue (design/gdd/survivor-defense.md rules 19, 21;
# ADR-0013 / ADR-0004 §6: a positional sound with a radius, sent through ServerMovement.emit_sound).
# Integration: real HoldService and HidingSpots on the real map's hiding spots, run by a RoundServer after
# the Holds step; emit_sound is the test's recorder. Delivery within the radius is ServerMovement's, tested
# by its own suites.
extends GdUnitTestSuite

const A := 1 ## survivor
const M := 3 ## the monster
const FAR := Vector3(-100.0, 0.0, -100.0)

var _knobs: Knobs
var _map: MapData
var _server: RoundServer
var _holds: HoldService
var _hs: HidingSpots
var _hidden: Dictionary = {}
var _feed: Dictionary = {}
var _centres: Dictionary = {}
var _sounds: Array[Array] = []


## Runs HoldService in the HOLDS slot (stands in for the composer's Holds step).
class HoldsStep extends RefCounted:
	var _holds: HoldService

	func _init(holds: HoldService) -> void:
		_holds = holds

	func setup(_runner: TickRunner, _bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		pass

	func server_tick(tick: int) -> void:
		_holds.server_tick(tick)


func before_test() -> void:
	_knobs = Knobs.load_all()
	_map = MapData.load_map()
	_hidden = {}
	_feed = {}
	_sounds = []
	_centres = {A: FAR, M: FAR}
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_holds = HoldService.new(_knobs, _players, _frames, _centre, _sight, _claimed)
	_hs = HidingSpots.new(_holds, _map, _healthy, _is_monster, _set_hidden)
	_hs.emit_sound = _on_sound
	assert_array(_server.start_round({TickOrder.HOLDS: HoldsStep.new(_holds),
		TickOrder.HOLDS + 1: _hs}, _knobs)).is_empty()


func after_test() -> void:
	_server.end_round()


func _players() -> Array:
	return _centres.keys()


func _frames(actor: int) -> Array:
	return _feed.get(actor, [])


func _centre(actor: int) -> Vector3:
	return _centres.get(actor, FAR)


func _sight(_actor: int, _i: Interactable) -> bool:
	return true


func _claimed(actor: int) -> int:
	var id := -1
	for f: InputFrame in _feed.get(actor, []):
		if f.interact:
			id = f.interact_target
	return id


func _healthy(actor: int) -> bool:
	return actor == A


func _is_monster(actor: int) -> bool:
	return actor == M


func _set_hidden(actor: int, on: bool) -> void:
	_hidden[actor] = on


func _on_sound(position: Vector3, sound_set: StringName, radius_m: float) -> void:
	_sounds.append([position, sound_set, radius_m])


func _sets() -> Array[StringName]:
	var out: Array[StringName] = []
	for s in _sounds:
		out.append(s[1])
	return out


## `n` ticks with `actor` holding interact on `target`; everyone else sends a released frame (-1: all do).
func _run(actor: int, target: int, n: int) -> void:
	for i in n:
		_feed = {}
		for p: int in _centres:
			var f := InputFrame.new()
			f.interact = p == actor and target >= 0
			f.interact_target = target if f.interact else -1
			_feed[p] = [f]
		_server.tick_runner.step()


func _idle(n: int) -> void:
	_run(A, -1, n)


func _hide(spot: int) -> void:
	_centres[A] = _hs.point(spot)
	_run(A, _hs.hide_id(spot), _knobs.ticks(_knobs.defense.hide_transition_s))
	_idle(1)
	assert_bool(_hidden.get(A, false)).is_true()


# --- AC-1: enter and exit each make a sound within hide_noise_radius_m ----------------------------------

func test_enter_and_exit_each_emit_a_sound_at_the_spot_within_the_noise_radius() -> void:
	_hide(0)
	assert_array(_sets()).is_equal([HidingSpots.ENTER_SOUND])
	_run(A, _hs.hide_id(0), _knobs.ticks(_knobs.defense.hide_transition_s))
	_idle(1)
	assert_bool(_hidden[A]).is_false()
	assert_array(_sets()).is_equal([HidingSpots.ENTER_SOUND, HidingSpots.EXIT_SOUND])
	for s in _sounds:
		assert_vector(s[0]).is_equal(_hs.point(0))
		assert_float(s[2]).is_equal(_knobs.defense.hide_noise_radius_m)


func test_a_cancelled_entry_makes_no_sound() -> void:
	_centres[A] = _hs.point(0)
	_run(A, _hs.hide_id(0), _knobs.ticks(_knobs.defense.hide_transition_s) - 1)
	_idle(2)
	assert_array(_sounds).is_empty()


func test_an_eject_is_an_exit_and_makes_the_exit_sound() -> void:
	_hide(0)
	_centres[M] = _hs.point(0)
	_run(M, _hs.search_id(0), _knobs.ticks(_knobs.defense.search_duration_s))
	_run(M, -1, 1)
	assert_bool(_hidden[A]).is_false()
	assert_array(_sets()).is_equal([HidingSpots.ENTER_SOUND, HidingSpots.EXIT_SOUND])


# --- AC-2: the long-hide cue ----------------------------------------------------------------------------

func test_cue_after_hide_quiet_then_every_interval_and_stops_on_exit() -> void:
	var quiet := _knobs.ticks(_knobs.defense.hide_quiet_s)
	var every := _knobs.ticks(_knobs.defense.hide_cue_interval_s)
	_hide(0)
	_sounds = []
	_idle(quiet - 2) ## _hide already ran one idle tick after the entry
	assert_array(_sounds).is_empty()
	_idle(1)
	assert_array(_sets()).is_equal([HidingSpots.CUE_SOUND])
	assert_vector(_sounds[0][0]).is_equal(_hs.point(0))
	_idle(every - 1)
	assert_int(_sounds.size()).is_equal(1)
	_idle(1)
	assert_int(_sounds.size()).is_equal(2)
	_idle(every * 3)
	assert_int(_sounds.size()).is_equal(5)
	var before := _sounds.size()
	_run(A, _hs.hide_id(0), _knobs.ticks(_knobs.defense.hide_transition_s))
	_idle(quiet + every * 2)
	assert_array(_sets().slice(before)).is_equal([HidingSpots.EXIT_SOUND])


func test_re_entering_restarts_the_quiet_time() -> void:
	var quiet := _knobs.ticks(_knobs.defense.hide_quiet_s)
	_hide(0)
	_idle(quiet / 2)
	_run(A, _hs.hide_id(0), _knobs.ticks(_knobs.defense.hide_transition_s))
	_idle(1)
	_hide(0)
	_sounds = []
	_idle(quiet - 2)
	assert_array(_sounds).is_empty()
	_idle(1)
	assert_array(_sets()).is_equal([HidingSpots.CUE_SOUND])
