# Story survivor-defense/007: barricade build and remove, closed doors block the dash
# (design/gdd/survivor-defense.md rules 24-26, 28a and the "monster in the doorway" edge case;
# ADR-0008 holds and one exclusive lock per door; ADR-0007 §5 door blockers).
# Integration: real HoldService, Doors, DoorBlockers, Jolt PlayerBody capsules and Barricades on a
# fixture map with one barricadable door. Break (story 008) and the lunge (Monster Abilities) have not
# landed: a fixture Break interactable on the door's lock key, and a stub dash mover (doors_test.gd's)
# against the real doors layer. Re-run when MA-6 and SD-12 land.
extends GdUnitTestSuite

const A := 1 ## survivor
const B := 2 ## survivor
const M := 3 ## the monster
const DOOR := 0 ## net id: the fixture map's only interactable
const DOOR_ID := &"d"
const SWING := AABB(Vector3(-0.5, 0.0, -1.0), Vector3(1.0, 2.0, 2.0))
const LEAF := Vector3(1.0, 2.0, 0.1)
const A_FEET := Vector3(1.2, 0.0, 1.0) ## 1.56 m from the door point, clear of the swing box
const B_FEET := Vector3(-1.2, 0.0, 1.0)
const M_AWAY := Vector3(0.0, 0.0, -5.0)
const M_DOORWAY := Vector3(0.0, 0.0, -0.5) ## inside the swing box, south of the closed leaf


## Story 008's Break stand-in: a monster hold on the door's shared lock key.
class BreakFixture extends Interactable:
	func eligible(actor: int) -> bool:
		return actor == M

	func start_progress_s() -> float:
		return 0.0

	func on_complete(_actor: int) -> void:
		pass

	func on_cancel(_actor: int, _progress_s: float, _reason: StringName) -> void:
		pass


var _knobs: Knobs
var _world: Node3D
var _map: MapData
var _holds: HoldService
var _doors: Doors
var _bars: Barricades
var _registry: StateRegistry
var _bodies: Dictionary = {} ## actor -> PlayerBody
var _feed: Dictionary = {}
var _aim: Dictionary = {}
var _tick := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_world = Node3D.new()
	add_child(_world)
	var door := MapPassage.new()
	door.id = DOOR_ID
	door.kind = MapPassage.BARRICADABLE
	door.position = Vector3.ZERO
	door.width_m = 1.0
	door.swing_box = SWING
	_map = MapData.new()
	_map.passages.append(door)
	_bodies = {}
	_feed = {}
	_aim = {}
	_tick = 0
	_holds = HoldService.new(_knobs, func() -> Array: return _bodies.keys(),
		func(actor: int) -> Array: return _feed.get(actor, []),
		func(actor: int) -> Vector3: return _feet(actor) + Vector3.UP * _bodies[actor].capsule().height / 2.0,
		func(_actor: int, _i: Interactable) -> bool: return true,
		func(actor: int) -> int: return _aim.get(actor, -1))
	_doors = Doors.new(_holds, _map, _capsules)
	_registry = StateRegistry.new()
	_doors.setup(null, null, _registry, _knobs)
	_bars = Barricades.new(_holds, _doors, _map, _healthy_survivor, _monster_capsules)
	_bars.setup(null, null, _registry, _knobs)
	_blocker()
	_doors.blockers = DoorBlockers.new(_world, _map)
	_body(A, A_FEET)
	_body(B, B_FEET)
	_body(M, M_AWAY)


func after_test() -> void:
	_registry.clear()
	_world.free()


func _healthy_survivor(actor: int) -> bool:
	return actor == A or actor == B


func _monster_capsules() -> Array[Vector4]:
	var f := _feet(M)
	return [Vector4(f.x, f.y, f.z, (_bodies[M] as PlayerBody).capsule().height)]


func _feet(actor: int) -> Vector3:
	return (_bodies[actor] as PlayerBody).global_position


func _capsules() -> Array[Vector4]:
	var out: Array[Vector4] = []
	for actor: int in _bodies:
		var f := _feet(actor)
		out.append(Vector4(f.x, f.y, f.z, (_bodies[actor] as PlayerBody).capsule().height))
	return out


func _blocker() -> void:
	var b := StaticBody3D.new()
	b.collision_layer = PhysicsLayers.DOORS
	b.collision_mask = PhysicsLayers.NONE
	b.set_meta(&"passage", DOOR_ID)
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	cs.shape.size = LEAF
	cs.disabled = true
	b.add_child(cs)
	_world.add_child(b)
	b.global_position = Vector3(0.0, LEAF.y / 2.0, 0.0)


func _body(actor: int, feet: Vector3) -> PlayerBody:
	var b := PlayerBody.new()
	b.setup(_knobs, PhysicsLayers.MOVE_SERVER)
	_world.add_child(b)
	b.global_position = feet
	_bodies[actor] = b
	return b


func _f(actor: int, interact: bool, target: int) -> InputFrame:
	var f := InputFrame.new()
	f.interact = interact
	f.interact_target = target
	_aim[actor] = target
	return f


## One Holds step; each actor in `frames` sends that one frame, the rest send nothing.
func _step(frames: Dictionary) -> void:
	_feed = {}
	for actor: int in frames:
		_feed[actor] = [frames[actor]]
	_holds.server_tick(_tick)
	_tick += 1


## `actor` holds interact on `target` for `n` ticks (a fresh press if it was released).
func _hold(actor: int, target: int, n: int) -> void:
	for i in n:
		_step({actor: _f(actor, true, target)})


func _release(actor: int, target: int) -> void:
	_step({actor: _f(actor, false, target)})


func _toggle(actor: int) -> void:
	_release(actor, DOOR)
	_hold(actor, DOOR, 1)
	_release(actor, DOOR)


func _build_ticks() -> int:
	return _knobs.ticks(_knobs.defense.barricade_duration_s)


func _remove_ticks() -> int:
	return _knobs.ticks(_knobs.defense.barricade_remove_s)


func _barricade() -> void:
	_toggle(A)
	_hold(A, _bars.build_id(DOOR), _build_ticks())
	_release(A, _bars.build_id(DOOR))
	assert_bool(_bars.is_barricaded(DOOR)).is_true()


# --- AC-1: build and remove timing ------------------------------------------------------------------

func test_build_takes_barricade_duration_and_does_not_root() -> void:
	_toggle(A)
	_hold(A, _bars.build_id(DOOR), _build_ticks() - 1)
	assert_bool(_bars.is_barricaded(DOOR)).is_false()
	assert_bool(_holds.hold_of(A).roots).is_false()
	_hold(A, _bars.build_id(DOOR), 1)
	assert_bool(_bars.is_barricaded(DOOR)).is_true()
	var view := _registry.view(StateKeys.BARRICADE_STATE, Barricades.BarricadeView) as Barricades.BarricadeView
	assert_bool(view.is_barricaded(DOOR)).is_true()


func test_cancel_one_tick_before_completion_resets_progress() -> void:
	_toggle(A)
	_hold(A, _bars.build_id(DOOR), _build_ticks() - 1)
	_release(A, _bars.build_id(DOOR))
	_hold(A, _bars.build_id(DOOR), _build_ticks() - 1)
	assert_bool(_bars.is_barricaded(DOOR)).is_false()
	_hold(A, _bars.build_id(DOOR), 1)
	assert_bool(_bars.is_barricaded(DOOR)).is_true()


func test_remove_takes_barricade_remove_s_and_leaves_the_door_closed() -> void:
	_barricade()
	_hold(B, _bars.remove_id(DOOR), _remove_ticks() - 1)
	assert_bool(_bars.is_barricaded(DOOR)).is_true()
	_hold(B, _bars.remove_id(DOOR), 1)
	assert_bool(_bars.is_barricaded(DOOR)).is_false()
	assert_bool(_doors.is_closed(DOOR)).is_true()
	_toggle(B)
	assert_bool(_doors.is_closed(DOOR)).is_false()


func test_an_open_door_cannot_be_barricaded_and_the_monster_cannot_build() -> void:
	_hold(A, _bars.build_id(DOOR), _build_ticks())
	assert_bool(_bars.is_barricaded(DOOR)).is_false()
	_toggle(A)
	_bodies[M].global_position = A_FEET + Vector3(0.0, 0.0, 0.5)
	_hold(M, _bars.build_id(DOOR), _build_ticks())
	assert_bool(_bars.is_barricaded(DOOR)).is_false()


# --- AC-2: a barricaded door ------------------------------------------------------------------------

func test_a_barricaded_door_cannot_be_opened_by_anyone() -> void:
	_barricade()
	_bodies[M].global_position = A_FEET + Vector3(0.0, 0.0, 0.5)
	for actor: int in [A, B, M]:
		_toggle(actor)
		assert_bool(_doors.is_closed(DOOR)).is_true()


func test_build_fails_with_the_monster_in_the_doorway() -> void:
	_toggle(A)
	_bodies[M].global_position = M_DOORWAY
	_hold(A, _bars.build_id(DOOR), _build_ticks())
	assert_bool(_bars.is_barricaded(DOOR)).is_false()
	assert_dict(_holds.hold_of(A)).is_empty()


func test_monster_leaving_the_doorway_on_the_final_tick_lets_the_build_complete() -> void:
	_toggle(A)
	_bodies[M].global_position = M_DOORWAY
	_hold(A, _bars.build_id(DOOR), _build_ticks() - 1)
	_bodies[M].global_position = M_AWAY
	_hold(A, _bars.build_id(DOOR), 1)
	assert_bool(_bars.is_barricaded(DOOR)).is_true()


# --- AC-3: a lunge path crossing a closed door stops at the door and misses ---------------------------

func _dash(dasher: PlayerBody) -> void:
	var mps := _knobs.ability.lunge_distance_m / _knobs.ability.lunge_dash_s
	await get_tree().physics_frame
	await get_tree().physics_frame ## in the broadphase before the first step
	for t in _knobs.ticks(_knobs.ability.lunge_dash_s):
		await get_tree().physics_frame
		dasher.velocity = Vector3(0.0, 0.0, mps)
		dasher.move_and_slide()


## The stub lunge's resolution: a hit is the dasher's capsule reaching the victim's.
func _hit(dasher: PlayerBody, victim: PlayerBody) -> bool:
	return dasher.global_position.distance_to(victim.global_position) <= 2.0 * _knobs.controller.player_radius_m + 0.05


func test_a_lunge_into_a_barricaded_door_stops_at_the_door_and_misses() -> void:
	_barricade()
	var victim := _bodies[B] as PlayerBody
	victim.global_position = Vector3(0.0, 0.0, SWING.end.z + 0.5)
	var dasher := _bodies[M] as PlayerBody
	dasher.global_position = Vector3(0.0, 0.0, SWING.position.z - 0.5)
	await _dash(dasher)
	assert_float(dasher.global_position.z).is_less(-LEAF.z / 2.0)
	assert_bool(_hit(dasher, victim)).is_false()


func test_a_door_closed_on_the_dash_tick_stops_the_lunge() -> void:
	var victim := _bodies[B] as PlayerBody
	victim.global_position = Vector3(0.0, 0.0, SWING.end.z + 0.5)
	var dasher := _bodies[M] as PlayerBody
	dasher.global_position = Vector3(0.0, 0.0, SWING.position.z - 0.31)
	_toggle(A) ## same tick the dash starts: no physics frame between the close and the first step
	assert_bool(_doors.is_closed(DOOR)).is_true()
	await _dash(dasher)
	assert_float(dasher.global_position.z).is_less(-LEAF.z / 2.0)
	assert_bool(_hit(dasher, victim)).is_false()


# --- AC-4: one action at a time; a forged completion changes nothing ----------------------------------

func test_a_running_break_refuses_build_and_remove() -> void:
	_barricade()
	var brk := BreakFixture.new()
	brk.point = Vector3.UP * _knobs.controller.capsule_height_m / 2.0
	brk.range_m = _knobs.objectives.interact_range_m
	brk.duration_s = _knobs.defense.barricade_break_s
	brk.roots_actor = true
	brk.lock_key = Barricades.lock_key(DOOR)
	var brk_id := _holds.register(brk)
	_bodies[M].global_position = Vector3(0.0, 0.0, -1.5)
	_hold(M, brk_id, 1)
	_step({M: _f(M, true, brk_id), B: _f(B, true, _bars.remove_id(DOOR))})
	assert_dict(_holds.hold_of(B)).is_empty()
	assert_int(_holds.hold_of(M).net_id).is_equal(brk_id)
	_step({M: _f(M, true, brk_id), A: _f(A, true, _bars.build_id(DOOR))})
	assert_dict(_holds.hold_of(A)).is_empty()
	assert_bool(_bars.is_barricaded(DOOR)).is_true()


func test_same_tick_build_from_two_survivors_runs_only_one() -> void:
	_toggle(A)
	var id := _bars.build_id(DOOR)
	_step({A: _f(A, true, id), B: _f(B, true, id)})
	assert_int(int(_holds.hold_of(A).is_empty()) + int(_holds.hold_of(B).is_empty())).is_equal(1)
	for i in _build_ticks() - 1:
		_step({A: _f(A, true, id), B: _f(B, true, id)})
	assert_bool(_bars.is_barricaded(DOOR)).is_true()


func test_a_forged_barricade_complete_changes_nothing() -> void:
	_toggle(A)
	var sd := SurvivorDefense.new()
	sd.set_roster([A, B] as Array[int], M)
	sd.setup(null, EventBus.new(_knobs.core.max_flush_rounds), StateRegistry.new(), _knobs)
	for forged: Dictionary in [{"barricade": DOOR}, {"item": 2, "door": DOOR}, {"barricade_complete": true}]:
		sd.request_intent(A, var_to_bytes(forged))
		sd.server_tick(_tick)
		_step({A: _f(A, false, _bars.build_id(DOOR))})
	assert_bool(_bars.is_barricaded(DOOR)).is_false()
	assert_int(sd.charges(A)).is_equal(_knobs.defense.stun_item_charges)
