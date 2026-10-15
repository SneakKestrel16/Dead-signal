# Story survivor-defense/008: barricade break, persistence and rebarricade lockout
# (design/gdd/survivor-defense.md rules 15, 27, 28, 28a; ADR-0005 BarricadeBroken; ADR-0008 holds).
# Real HoldService (as the TickRunner's input stage, so current_tick() is the Holds tick), Doors,
# Barricades and SurvivorDefense.shock on a two-door fixture map. The monster rule is wired as the round
# would: the role, with SurvivorDefense.locked folded in. Re-run when SD-12 wires Barricades into the round.
extends GdUnitTestSuite

const A := 1 ## survivor
const M := 2 ## the monster
const DOOR := 0
const DOOR2 := 1
const SWING := AABB(Vector3(-0.5, 0.0, -1.0), Vector3(1.0, 2.0, 2.0))

var _knobs: Knobs
var _runner: TickRunner
var _bus: EventBus
var _holds: HoldService
var _doors: Doors
var _bars: Barricades
var _sd: SurvivorDefense
var _registry: StateRegistry
var _feed: Dictionary = {} ## actor -> InputFrame for the next step
var _down: Dictionary = {} ## actor -> net id held
var _broken: Array[EvBarricadeBroken] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	var map := MapData.new()
	for i in 2:
		var door := MapPassage.new()
		door.id = StringName("d%d" % i)
		door.kind = MapPassage.BARRICADABLE
		door.position = Vector3(i, 0.0, 0.0)
		door.width_m = 1.0
		door.swing_box = SWING
		map.passages.append(door)
	_feed = {}
	_down = {}
	_broken = []
	_runner = TickRunner.new()
	_runner.boot(_knobs)
	_bus = EventBus.new(_knobs.core.max_flush_rounds)
	_runner.bus = _bus
	_bus.subscribe(&"BarricadeBroken", _on_broken)
	_holds = HoldService.new(_knobs, _players, _frames, _centre_of, _sight, _aim, Callable(), _is_shapeshifter)
	_runner.input_stage = _holds.server_tick
	_registry = StateRegistry.new()
	_doors = Doors.new(_holds, map, _no_capsules)
	_doors.setup(_runner, _bus, _registry, _knobs)
	_sd = SurvivorDefense.new()
	_sd.set_roster([A] as Array[int], M)
	_sd.set_holds(_holds)
	_sd.setup(_runner, _bus, _registry, _knobs)
	_bars = Barricades.new(_holds, _doors, map, _healthy, _no_capsules, _monster)
	_bars.setup(_runner, _bus, _registry, _knobs)
	for d: int in [DOOR, DOOR2]:
		assert_bool(_doors.toggle(d)).is_true()
		assert_bool(_bars.complete(d, false)).is_true()


func after_test() -> void:
	_registry.clear()
	_runner.free()


func _on_broken(e: ServerEvent) -> void:
	_broken.append(e as EvBarricadeBroken)


func _players() -> Array[int]:
	return [A, M]


func _frames(actor: int) -> Array:
	var f := InputFrame.new()
	f.interact = _down.has(actor)
	f.interact_target = _down.get(actor, -1)
	# SD-14: Barricade, Remove and Break answer interact_alt; these tests name hold net ids directly.
	f.interact_alt = f.interact and _holds._items[f.interact_target].alt
	return [f]


func _centre_of(_actor: int) -> Vector3:
	return Vector3.UP * MapQueries.InteractRules.from_knobs(_knobs).point_height_m


func _sight(_actor: int, _i: Interactable) -> bool:
	return true


func _aim(actor: int) -> int:
	return _down.get(actor, -1)


func _is_shapeshifter(actor: int) -> bool:
	return actor == M


func _healthy(actor: int) -> bool:
	return actor == A


## The round's wiring: the monster in any form, unless stunned.
func _monster(actor: int) -> bool:
	return actor == M and not _sd.locked(actor)


func _no_capsules() -> Array[Vector4]:
	return []


## A release step, then `n` steps holding interact on `target` (one fresh press).
func _hold(actor: int, target: int, n: int) -> void:
	_idle(1)
	_down[actor] = target
	for i in n:
		_runner.step()
	_down.erase(actor)


func _idle(n: int) -> void:
	_down = {}
	for i in n:
		_runner.step()


func _break_ticks() -> int:
	return _knobs.ticks(_knobs.defense.barricade_break_s)


func _lockout_ticks() -> int:
	return _knobs.ticks(_knobs.defense.rebarricade_lockout_s)


## Breaks DOOR in one hold; returns the tick it broke on.
func _break_door() -> int:
	_hold(M, _bars.break_id(DOOR), _break_ticks())
	assert_bool(_bars.is_barricaded(DOOR)).is_false()
	return _runner.current_tick()


# --- AC-1: 5 s of total break time, kept across interruptions and a stun ---------------------------

func test_break_takes_break_s_total_across_releases_and_a_stun() -> void:
	var id := _bars.break_id(DOOR)
	_hold(M, id, 10)
	_hold(M, id, 20)
	_down[M] = id
	_runner.step()
	_sd.shock(M, _runner.current_tick()) ## rule 15: the stun interrupts, damage dealt is kept
	assert_dict(_holds.hold_of(M)).is_empty()
	_hold(M, id, 1)
	assert_dict(_holds.hold_of(M)).is_empty() ## stunned: no interact
	_idle(_knobs.ticks(_knobs.defense.stun_duration_s))
	assert_bool(_sd.locked(M)).is_false()
	_hold(M, id, _break_ticks() - 31 - 1)
	assert_bool(_bars.is_barricaded(DOOR)).is_true()
	_hold(M, id, 1)
	assert_bool(_bars.is_barricaded(DOOR)).is_false()
	assert_bool(_doors.is_closed(DOOR)).is_true() ## Broken -> Closed


func test_release_on_the_final_tick_keeps_all_but_one_tick() -> void:
	var id := _bars.break_id(DOOR)
	_hold(M, id, _break_ticks() - 1)
	assert_bool(_bars.is_barricaded(DOOR)).is_true()
	_hold(M, id, 1)
	assert_bool(_bars.is_barricaded(DOOR)).is_false()


func test_removal_clears_break_progress() -> void:
	var id := _bars.break_id(DOOR)
	_hold(M, id, _break_ticks() - 1)
	_hold(A, _bars.remove_id(DOOR), _knobs.ticks(_knobs.defense.barricade_remove_s))
	assert_bool(_bars.is_barricaded(DOOR)).is_false()
	_hold(A, _bars.build_id(DOOR), _knobs.ticks(_knobs.defense.barricade_duration_s))
	assert_bool(_bars.is_barricaded(DOOR)).is_true()
	_hold(M, id, _break_ticks() - 1)
	assert_bool(_bars.is_barricaded(DOOR)).is_true()


# --- AC-2: rebuild lockout -------------------------------------------------------------------------

func test_rebuild_one_tick_before_the_lockout_is_rejected() -> void:
	var at := _break_door()
	_idle(at + _lockout_ticks() - 3 - _runner.current_tick())
	_hold(A, _bars.build_id(DOOR), 1) ## release on lockout - 2, press on lockout - 1
	assert_int(_runner.current_tick()).is_equal(at + _lockout_ticks() - 1)
	assert_dict(_holds.hold_of(A)).is_empty()
	assert_bool(_bars.can_build(A, DOOR)).is_false()


func test_rebuild_at_exactly_the_lockout_is_allowed() -> void:
	var at := _break_door()
	_idle(at + _lockout_ticks() - 2 - _runner.current_tick())
	_hold(A, _bars.build_id(DOOR), 1)
	assert_int(_runner.current_tick()).is_equal(at + _lockout_ticks())
	assert_int(_holds.hold_of(A).net_id).is_equal(_bars.build_id(DOOR))
	_hold(A, _bars.build_id(DOOR), _knobs.ticks(_knobs.defense.barricade_duration_s))
	assert_bool(_bars.is_barricaded(DOOR)).is_true()


# --- AC-3: who may break -----------------------------------------------------------------------------

func test_break_is_a_real_rooted_monster_hold_and_survivors_cannot_start_it() -> void:
	_hold(A, _bars.break_id(DOOR), 1)
	assert_dict(_holds.hold_of(A)).is_empty()
	## M counts as the shapeshifter, so a fakeable target would be a fake hold: Break is never one.
	_hold(M, _bars.break_id(DOOR), 1)
	assert_bool(_holds.hold_of(M).fake).is_false()
	assert_bool(_holds.hold_of(M).roots).is_true()


func test_break_needs_a_barricade() -> void:
	_break_door()
	_hold(M, _bars.break_id(DOOR), 1)
	assert_dict(_holds.hold_of(M)).is_empty()


# --- AC-4: BarricadeBroken once per break ------------------------------------------------------------

func test_each_break_emits_barricade_broken_once() -> void:
	_break_door()
	_idle(3)
	assert_int(_broken.size()).is_equal(1)
	assert_int(_broken[0].barricade).is_equal(DOOR)
	_hold(M, _bars.break_id(DOOR2), _break_ticks())
	_idle(3)
	assert_int(_broken.size()).is_equal(2)
	assert_int(_broken[1].barricade).is_equal(DOOR2)
