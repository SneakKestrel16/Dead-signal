# Story survivor-defense/005: identity-hiding stun and shock events (design/gdd/survivor-defense.md rules
# 1, 9, 10, 11 and acceptance 15; borrowed-face.md rule 10; TR-defense-003, -009; ADR-0004 §5 projection
# table, ADR-0005 tick order: Survivor Defense (200) before Borrowed Face (300)). The real SurvivorDefense
# and BorrowedFace run in a RoundServer; hits land through SurvivorDefense.shock from a Hitter in the
# MATCH_FLOW_BEGIN slot (the trace is story 002's). Every event the bus delivers on the hit tick goes through
# EventBatch.build/decode per viewer, the bytes ServerMovement sends a client on the event channel.
# A resisted true-form hit reaches clients as PlayerShocked on the true-form body (no stun state, no
# MonsterStunned), so "resisted" is told apart from a stun by event type; see SurvivorDefense.shock.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const S3 := 4
const SURVIVORS: Array[int] = [2, 3, 4]
const EYE := Vector3(0.0, 1.6, 0.0)
const LOOKS: Dictionary[int, int] = {1: 1, 2: 2, 3: 3, 4: 4}
const SEED := 5005
## Batch tick used for the byte comparison, so the three packets differ only in what the events carry.
const BYTES_TICK := 1000


## Lands a hit through SurvivorDefense.shock on `victim` on each tick in `at`, before Survivor Defense's slot.
class Hitter extends RefCounted:
	var at: Array[int] = []
	var victim := MONSTER
	var shock: Callable
	## shock's result for the latest hit (true: a lock was applied).
	var locked := false

	func setup(_tr: TickRunner, _bus: EventBus, _reg: StateRegistry, _k: Knobs) -> void:
		pass

	func server_tick(tick: int) -> void:
		if at.has(tick):
			locked = shock.call(victim, tick)


var _server: RoundServer
var _def: SurvivorDefense
var _bf: BorrowedFace
var _hitter: Hitter
var _knobs: Knobs
var _handles: HandleTable
var _transform_ticks: int
var _events: Array[ServerEvent] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_transform_ticks = _knobs.ticks(_knobs.borrowed_face.transform_duration_s)
	_handles = _table()
	for v: int in SURVIVORS + [MONSTER]: # every body relevant to every viewer unless a test retires one
		for b: int in SURVIVORS + [MONSTER]:
			if b != v:
				_handles.handle_for(v, b)
	_events.clear()
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_def = SurvivorDefense.new()
	_def.set_roster(SURVIVORS, MONSTER)
	_bf = BorrowedFace.new()
	_bf.set_roster(SURVIVORS, MONSTER)
	_bf.set_sight_sources(_eye_of, _yaw_of, _points_of, _sight, _def.locked)
	_bf.set_status_source(_status_of)
	_bf.set_appearance_source(_look_of)
	_def.set_form_source(_bf.form)
	_hitter = Hitter.new()
	_hitter.shock = _def.shock
	assert_array(_server.start_round({TickOrder.MATCH_FLOW_BEGIN: _hitter, TickOrder.SURVIVOR_DEFENSE: _def,
		TickOrder.BORROWED_FACE: _bf}, _knobs)).is_empty()
	for t: StringName in [&"FormChanged", &"MonsterStunned", &"PlayerShocked"]:
		_server.bus.subscribe(t, _on_event)
	_step(_knobs.ticks(_knobs.borrowed_face.observe_time_s))
	assert_bool(_bf.observed(S1)).is_true()


func after_test() -> void:
	_server.end_round()
	_hitter = null
	_def = null
	_bf = null


func _table() -> HandleTable:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	return HandleTable.new(rng)


func _eye_of(_p: int) -> Vector3:
	return EYE


func _yaw_of(_p: int) -> float:
	return 0.0


func _points_of(_p: int) -> PackedVector3Array:
	var chest := EYE + Vector3.FORWARD * 5.0
	return PackedVector3Array([chest + Vector3.UP * 0.4, chest, chest + Vector3.DOWN * 0.3])


func _sight(_eye: Vector3, _point: Vector3) -> bool:
	return true


func _status_of(_p: int) -> int:
	return MatchFlow.Status.HEALTHY


func _look_of(p: int) -> int:
	return LOOKS[p]


func _on_event(e: ServerEvent) -> void:
	_events.append(e)


func _tick() -> int:
	return _server.tick_runner.current_tick()


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


## Requests `form` and steps one tick; asserts it was accepted.
func _request(form: int) -> void:
	_bf.request_form_change(MONSTER, BorrowedFace.request_packet(form))
	_step(1)
	assert_bool(_bf.transforming()).is_true()


## Disguised as S1 with the cooldown spent.
func _disguise() -> void:
	_request(S1)
	_step(_transform_ticks + _knobs.ticks(_knobs.borrowed_face.form_change_cooldown_s))
	assert_int(_bf.form()).is_equal(S1)


## Lands a hit on `victim` next tick; keeps that tick's delivered events in _events.
func _hit(victim: int = MONSTER) -> void:
	_hitter.victim = victim
	_hitter.at.append(_tick() + 1)
	_events.clear()
	_step(1)


## The entries `viewer` decodes for the latest hit tick's events.
func _entries(viewer: int) -> Array:
	return EventBatch.decode(EventBatch.build(_tick(), viewer, _events, [], Vector3.ZERO, _handles,
		MONSTER)).get("entries", [])


## The latest hit tick's batch for `viewer`, built with a fresh table holding only its handle for `body`:
## every body gets the same handle value, so equal bytes mean an equal event list and payload shape.
func _bytes_of(viewer: int, body: int) -> PackedByteArray:
	var t := _table()
	t.handle_for(viewer, body)
	return EventBatch.build(BYTES_TICK, viewer, _events, [], Vector3.ZERO, t, MONSTER)


func _types(entries: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Array in entries:
		out.append(e[0])
	return out


## Every survivor viewer but the hit one got exactly [want] naming `body` by its handle.
func _assert_survivors_see(want: StringName, body: int = MONSTER) -> void:
	for v in SURVIVORS:
		if v == body:
			continue
		var got := _entries(v)
		assert_array(_types(got)).override_failure_message("viewer %d: %s" % [v, got]).is_equal([want])
		if got.size() == 1:
			assert_dict(got[0][1]).is_equal({"body": _handles.handle_for(v, body)})


## AC-1 (acceptance 15): disguised, a hit on a survivor, on the monster (stunned) and on the monster again
## (immune) give a survivor client byte-identical batches: one PlayerShocked, no MonsterStunned.
func test_disguised_hits_are_identical_to_survivor_shock_on_the_wire() -> void:
	_disguise()
	_hit(S1)
	assert_bool(_hitter.locked).is_true()
	_assert_survivors_see(&"PlayerShocked", S1)
	var survivor := _bytes_of(S3, S1)
	_hit()
	assert_bool(_hitter.locked).is_true() # stunned
	_assert_survivors_see(&"PlayerShocked")
	var stunned := _bytes_of(S3, MONSTER)
	assert_bool(_types(_entries(MONSTER)).has(&"MonsterStunned")).is_true() # its own client knows
	_step(_knobs.ticks(_knobs.defense.stun_duration_s) - 1)
	_hit()
	assert_bool(_hitter.locked).is_false() # immune: inside the post-lock window
	_assert_survivors_see(&"PlayerShocked")
	var immune := _bytes_of(S3, MONSTER)
	assert_bool(survivor.is_empty()).is_false()
	assert_array(Array(stunned)).is_equal(Array(survivor))
	assert_array(Array(immune)).is_equal(Array(survivor))


## AC-2 (rule 10): a true-form stun reaches every client as MonsterStunned; a hit on the last immunity
## tick is resisted (PlayerShocked, no MonsterStunned) for every client, and the next tick stuns again.
func test_true_form_stun_then_resisted_hit_on_last_immunity_tick() -> void:
	_hit()
	assert_bool(_hitter.locked).is_true()
	_assert_survivors_see(&"MonsterStunned")
	assert_array(_entries(MONSTER)).is_equal([[&"MonsterStunned", {"own": true}]])
	var free := _tick() + _knobs.ticks(_knobs.defense.stun_duration_s) + _knobs.ticks(_knobs.defense.stun_immunity_s)
	_step(free - 2 - _tick())
	_hit()
	assert_int(_tick()).is_equal(free - 1)
	assert_bool(_hitter.locked).is_false()
	_assert_survivors_see(&"PlayerShocked")
	assert_array(_entries(MONSTER)).is_equal([[&"PlayerShocked", {"own": true}]])
	_hit()
	assert_bool(_hitter.locked).is_true()
	_assert_survivors_see(&"MonsterStunned")


## AC-3 (rule 1, borrowed-face rule 10): transforming out of a disguise counts as disguised, including a
## hit on the change-complete tick, which the stun interrupts (the borrowed body stays shown).
func test_transforming_out_of_disguise_counts_as_disguised() -> void:
	_disguise()
	_request(BorrowedFace.TRUE_FORM)
	_step(_transform_ticks - 1)
	_hit()
	_assert_survivors_see(&"PlayerShocked")
	assert_bool(_bf.transforming()).is_false()
	assert_int(_bf.form()).is_equal(S1)


## AC-3: transforming out of true form into a disguise counts as true form, on the change-complete tick too.
func test_transforming_into_disguise_counts_as_true_form() -> void:
	_request(S1)
	_hit()
	_assert_survivors_see(&"MonsterStunned")
	assert_int(_bf.form()).is_equal(BorrowedFace.TRUE_FORM)
	_step(_knobs.ticks(_knobs.borrowed_face.form_change_cooldown_s) + _knobs.ticks(_knobs.defense.stun_duration_s)
		+ _knobs.ticks(_knobs.defense.stun_immunity_s))
	_request(S1)
	_step(_transform_ticks - 1)
	_hit()
	assert_bool(_hitter.locked).is_true()
	_assert_survivors_see(&"MonsterStunned")
	assert_int(_bf.form()).is_equal(BorrowedFace.TRUE_FORM)


## AC-4: the shocked player's own client gets {own: true}; another gets {body: handle} only while the
## body is relevant to it, otherwise no entry at all.
func test_shocked_player_gets_own_and_irrelevant_peer_gets_nothing() -> void:
	_handles.retire(S3, S1)
	_hit(S1)
	assert_array(_entries(S1)).is_equal([[&"PlayerShocked", {"own": true}]])
	assert_array(_entries(S2)).is_equal([[&"PlayerShocked", {"body": _handles.handle_for(S2, S1)}]])
	assert_array(_entries(S3)).is_empty()
	assert_array(_entries(MONSTER)).is_equal([[&"PlayerShocked", {"body": _handles.handle_for(MONSTER, S1)}]])
