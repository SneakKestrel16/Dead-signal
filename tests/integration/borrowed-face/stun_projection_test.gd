# Story borrowed-face/008: stun events projected by the form shown (borrowed-face.md rule 10, Edge
# Cases "Stunned while transforming out of a disguise", Acceptance Criteria on stuns; TR-borrowedface-002,
# -009; ADR-0004 §5 projection table, ADR-0005 tick order: Survivor Defense (slot 200) before Borrowed Face).
# The real BorrowedFace runs in a RoundServer; every event the bus delivers on the hit tick goes through
# EventBatch.build/decode per viewer, the bytes a client receives (NA-9). The real SurvivorDefense picks
# the events (survivor-defense story 005, rules 1 and 9): hits land through SurvivorDefense.shock from a
# Hitter in the MATCH_FLOW_BEGIN slot, the form shown read from BorrowedFace.form.
# The monster pain cry and stagger are client presentation of MonsterStunned (survivor-defense.md
# Visual/Audio table), so "no pain cry" is asserted as "no MonsterStunned entry" (Story 009 plays them).
# The byte identity of PlayerShocked across a disguise and a survivor is checked in
# tests/integration/survivor-defense/identity_hiding_events_test.gd.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const S3 := 4
const SURVIVORS: Array[int] = [2, 3, 4]
const EYE := Vector3(0.0, 1.6, 0.0)
## Character appearance ids (ADR-0010 §2: 1-5 are C1-C5); the monster's own id is never rendered.
const LOOKS: Dictionary[int, int] = {1: 1, 2: 2, 3: 3, 4: 4}
const SEED := 8


## Lands a hit through SurvivorDefense.shock on `victim` on each tick in `hit_ticks`, before its slot.
class Hitter extends RefCounted:
	var hit_ticks: Array[int] = []
	var victim := MONSTER
	var shock: Callable

	func setup(_tr: TickRunner, _bus: EventBus, _reg: StateRegistry, _k: Knobs) -> void:
		pass

	func server_tick(tick: int) -> void:
		if hit_ticks.has(tick):
			shock.call(victim, tick)


var _server: RoundServer
var _bf: BorrowedFace
var _defense: Hitter
var _def: SurvivorDefense
var _knobs: Knobs
var _handles: HandleTable
var _transform_ticks: int
## Every catalog event the bus delivered, in order.
var _events: Array[ServerEvent] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_transform_ticks = _knobs.ticks(_knobs.borrowed_face.transform_duration_s)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_handles = HandleTable.new(rng)
	for v: int in SURVIVORS + [MONSTER]: # every body relevant to every viewer
		for b: int in SURVIVORS + [MONSTER]:
			if b != v:
				_handles.handle_for(v, b)
	_events.clear()
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_bf = BorrowedFace.new()
	_bf.set_roster(SURVIVORS, MONSTER)
	_def = SurvivorDefense.new()
	_def.set_roster(SURVIVORS, MONSTER)
	_def.set_form_source(_bf.form)
	_defense = Hitter.new()
	_defense.shock = _def.shock
	_bf.set_sight_sources(_eye_of, _yaw_of, _points_of, _sight, _def.locked)
	_bf.set_status_source(_status_of)
	_bf.set_appearance_source(_look_of)
	assert_array(_server.start_round({TickOrder.MATCH_FLOW_BEGIN: _defense, TickOrder.SURVIVOR_DEFENSE: _def,
		TickOrder.BORROWED_FACE: _bf}, _knobs)).is_empty()
	for t: StringName in [&"FormChanged", &"MonsterStunned", &"PlayerShocked"]:
		_server.bus.subscribe(t, _on_event)
	_step(_knobs.ticks(_knobs.borrowed_face.observe_time_s))
	assert_bool(_bf.observed(S1)).is_true()


func after_test() -> void:
	_server.end_round()
	_defense = null
	_def = null
	_bf = null


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


## Lands a hit on `victim` next tick; returns the batch entries each viewer decodes for that tick's events.
func _hit(victim: int = MONSTER) -> Dictionary[int, Array]:
	_defense.victim = victim
	_defense.hit_ticks.append(_tick() + 1)
	_events.clear()
	_step(1)
	var out: Dictionary[int, Array] = {}
	for v: int in SURVIVORS + [MONSTER]:
		var bytes := EventBatch.build(_tick(), v, _events, [], Vector3.ZERO, _handles, MONSTER)
		out[v] = EventBatch.decode(bytes).get("entries", [])
	return out


## The types in `entries`.
func _types(entries: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Array in entries:
		out.append(e[0])
	return out


## Every survivor viewer got exactly one `want` entry naming the shapeshifter's body, and no `never`.
func _assert_survivors_see(got: Dictionary[int, Array], want: StringName, never: StringName) -> void:
	for v in SURVIVORS:
		assert_array(_types(got[v])).override_failure_message("viewer %d" % v).is_equal([want])
		assert_array(_types(got[v])).not_contains([never])
		assert_dict(got[v][0][1]).is_equal({"body": _handles.handle_for(v, MONSTER)})


## Disguised as S1 with the cooldown spent.
func _disguise() -> void:
	_request(S1)
	_step(_transform_ticks + _knobs.ticks(_knobs.borrowed_face.form_change_cooldown_s))
	assert_int(_bf.form()).is_equal(S1)


## AC 1: a stun while transforming out of a disguise reaches survivors as PlayerShocked only; the
## interrupt keeps the borrowed form.
func test_stun_transforming_out_of_disguise_projects_player_shocked() -> void:
	_disguise()
	_request(BorrowedFace.TRUE_FORM)
	var got := _hit()
	_assert_survivors_see(got, &"PlayerShocked", &"MonsterStunned")
	assert_bool(_bf.transforming()).is_false()
	assert_int(_bf.appearance_of(MONSTER)).is_equal(LOOKS[S1])
	assert_bool(_types(got[MONSTER]).has(&"MonsterStunned")).is_true() # its own client knows it is stunned


## AC 1: a stun while transforming out of true form reaches survivors as MonsterStunned only.
func test_stun_transforming_out_of_true_form_projects_monster_stunned() -> void:
	_request(S1)
	var got := _hit()
	_assert_survivors_see(got, &"MonsterStunned", &"PlayerShocked")
	assert_bool(_bf.transforming()).is_false()
	assert_int(_bf.appearance_of(MONSTER)).is_equal(CharacterDef.TRUE_FORM_APPEARANCE_ID)


## AC 2: a stunned disguise keeps the borrowed form through the whole lock, survivors get the same
## shock payload shape a shocked survivor gives, and no monster event (no stagger or pain cry).
func test_stunned_disguise_stays_borrowed_and_shows_survivor_shock() -> void:
	_disguise()
	var got := _hit()
	_assert_survivors_see(got, &"PlayerShocked", &"MonsterStunned")
	var real := _hit(S2) # a real survivor shocked, as S3 sees it
	assert_array(got[S3][0][1].keys()).is_equal(real[S3][0][1].keys())
	_step(_knobs.ticks(_knobs.defense.stun_duration_s))
	assert_int(_bf.form()).is_equal(S1)
	assert_int(_bf.appearance_of(MONSTER)).is_equal(LOOKS[S1])
	assert_array(_events.filter(func(e: ServerEvent) -> bool: return e is EvFormChanged)).is_empty()


## AC 2: a true-form stun sends survivors the monster stagger event and no survivor shock.
func test_true_form_stun_projects_monster_stunned() -> void:
	var got := _hit()
	_assert_survivors_see(got, &"MonsterStunned", &"PlayerShocked")
	assert_int(_bf.appearance_of(MONSTER)).is_equal(CharacterDef.TRUE_FORM_APPEARANCE_ID)
