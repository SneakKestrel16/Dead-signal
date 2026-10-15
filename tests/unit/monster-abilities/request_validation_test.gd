# Story monster-abilities/001: ability requests and the Lunge state machine
# (design/gdd/monster-abilities.md rules 1-4, 8-9, 12, "States and Transitions"; ADR-0002, ADR-0005,
# ADR-0006). Survivor Defense and Downing have stand-in emitters (stun, hit, commit end); form,
# Transforming and the stun/shock lock are stubs, except the cooldown-independence test, which runs the
# real BorrowedFace.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const SURVIVORS: Array[int] = [2]
const EYE := Vector3(0.0, 1.6, 0.0)
const SRC := "res://src/feature/monster_abilities/monster_abilities.gd"
const L := MonsterAbilities.Lunge
const A := MonsterAbilities.Ability


## Scheduled emitter standing in for Survivor Defense (before the module) or Downing (after it).
class Emitter extends RefCounted:
	var _bus: EventBus
	var _due: Dictionary[int, Array] = {}

	func setup(_runner: TickRunner, bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		_bus = bus

	func at(tick: int, e: ServerEvent) -> void:
		if not _due.has(tick):
			_due[tick] = []
		_due[tick].append(e)

	func server_tick(tick: int) -> void:
		for e: ServerEvent in _due.get(tick, []):
			_bus.emit(e)


var _server: RoundServer
var _ma: MonsterAbilities
var _defense: Emitter
var _downing: Emitter
var _knobs: Knobs
var _windup: int
var _dash: int
var _cooldown: int
var _form_now: int
var _transforming_now: bool
## Stub of StateKeys.SHOCK_STUN_LOCK: Stunned or shock-locked (Survivor Defense rule 14).
var _locked_now: bool
## Every Lunge transition: [state, tick].
var _states: Array = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_windup = _knobs.ticks(_knobs.ability.lunge_windup_s)
	_dash = _knobs.ticks(_knobs.ability.lunge_dash_s)
	_cooldown = _knobs.ticks(_knobs.ability.lunge_cooldown_s)
	_form_now = BorrowedFace.TRUE_FORM
	_transforming_now = false
	_locked_now = false
	_states = []


func _start(extra: Dictionary = {}) -> void:
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_ma = MonsterAbilities.new()
	_ma.set_monster(MONSTER)
	_ma.set_status_sources(_form, _transforming, _locked)
	_ma.on_lunge_state = _on_state
	_defense = Emitter.new()
	_downing = Emitter.new()
	var modules := {TickOrder.SURVIVOR_DEFENSE: _defense, TickOrder.MONSTER_ABILITIES: _ma,
		TickOrder.DOWNING: _downing}
	modules.merge(extra)
	assert_array(_server.start_round(modules, _knobs)).is_empty()


func _form() -> int:
	return _form_now


func _transforming() -> bool:
	return _transforming_now


func _locked(_p: int) -> bool:
	return _locked_now


func _on_state(state: int, tick: int) -> void:
	_states.append([state, tick])


func _step(n: int = 1) -> void:
	for i in n:
		_server.tick_runner.step()


func _now() -> int:
	return _server.tick_runner.current_tick()


func _req(ability: int) -> void:
	_ma.request_ability(MONSTER, MonsterAbilities.request_packet(ability, Vector3(1.0, 0.0, 2.0)))


## Requests a lunge and runs one tick; returns the tick it was accepted on.
func _lunge() -> int:
	_req(A.LUNGE)
	_step()
	assert_int(_ma.lunge_state()).is_equal(L.WIND_UP)
	return _now()


func _ready_ticks() -> Array[int]:
	return [_ma.ready_tick(A.LUNGE), _ma.ready_tick(A.FALSE_SIGNAL), _ma.ready_tick(A.BLACKOUT)]


func _stun() -> EvMonsterStunned:
	var e := EvMonsterStunned.new()
	e.monster = MONSTER
	e.true_form = true
	return e


func _hit() -> EvSurvivorHit:
	var e := EvSurvivorHit.new()
	e.survivor = S1
	return e


## AC-1: a lunge while Stunned, shock-locked or Transforming is rejected with no state change and no
## cooldown cost, disguised or not; Stunned and the shock lock both read SHOCK_STUN_LOCK.
func test_lunge_rejected_while_blocked_costs_nothing() -> void:
	_start()
	for blocker in ["locked", "transforming", "disguised locked", "disguised transforming"]:
		_form_now = S1 if blocker.begins_with("disguised") else BorrowedFace.TRUE_FORM
		_locked_now = blocker.ends_with("locked")
		_transforming_now = blocker.ends_with("transforming")
		_req(A.LUNGE)
		_step()
		assert_int(_ma.lunge_state()).override_failure_message(blocker).is_equal(L.READY)
		assert_array(_ready_ticks()).is_equal([0, 0, 0])
	assert_array(_states).is_empty()


## Story 012 (rule 4, designer decision 2026-10-15): a lunge while Disguised is accepted; the module
## leaves the reveal to Borrowed Face (its AbilityUsed subscription).
func test_lunge_accepted_while_disguised() -> void:
	_start()
	_form_now = S1
	_req(A.LUNGE)
	_step()
	assert_int(_ma.lunge_state()).is_equal(L.WIND_UP)


## AC-1 edge: two (here three) rejection reasons at once still reject cleanly.
func test_several_rejection_reasons_at_once() -> void:
	_start()
	_form_now = S1
	_locked_now = true
	_transforming_now = true
	_req(A.LUNGE)
	_step()
	assert_int(_ma.lunge_state()).is_equal(L.READY)
	assert_array(_ready_ticks()).is_equal([0, 0, 0])


## AC-1: in cooldown a lunge is rejected and the cooldown is unchanged; on the exact tick it ends the
## lunge is accepted.
func test_cooldown_rejects_until_its_exact_end_tick() -> void:
	_start()
	var a := _lunge()
	_step(_windup + _dash)
	var ready := a + _windup + _dash + _cooldown
	assert_int(_ma.lunge_state()).is_equal(L.COOLDOWN)
	assert_int(_ma.ready_tick(A.LUNGE)).is_equal(ready)
	_step(ready - 1 - _now() - 1)
	_req(A.LUNGE)
	_step()
	assert_int(_now()).is_equal(ready - 1)
	assert_int(_ma.lunge_state()).is_equal(L.COOLDOWN)
	assert_int(_ma.ready_tick(A.LUNGE)).is_equal(ready)
	_req(A.LUNGE)
	_step()
	assert_int(_ma.lunge_state()).is_equal(L.WIND_UP)


## Rule 1 / ADR-0002: only the shapeshifter's well-formed request is considered; untrusted bytes that are
## not one (wrong shape, unknown ability, non-finite aim, oversized) decode to nothing.
func test_untrusted_requests_are_ignored() -> void:
	_start()
	_ma.request_ability(S1, MonsterAbilities.request_packet(A.LUNGE))
	_step()
	assert_int(_ma.lunge_state()).is_equal(L.READY)
	var bad: Array[PackedByteArray] = [PackedByteArray(), var_to_bytes({"ability": 0}),
		var_to_bytes({"ability": 7, "aim": Vector3.ZERO}), var_to_bytes({"ability": 0, "aim": Vector3(INF, 0.0, 0.0)}),
		var_to_bytes({"ability": 0, "aim": "x".repeat(MonsterAbilities.REQUEST_CAP_BYTES)})]
	for b in bad:
		assert_dict(MonsterAbilities.decode_request(b)).is_empty()
	assert_dict(MonsterAbilities.decode_request(MonsterAbilities.request_packet(A.BLACKOUT))).is_not_empty()


## AC-2: False Signal and Blackout are rejected in wind-up, Active and takedown commit with no cooldown
## cost; the guard lifts when the commit ends.
func test_other_abilities_rejected_during_lunge() -> void:
	_start()
	var a := _lunge()
	_defense.at(a + _windup + 1, _hit())
	_downing.at(a + _windup + 5, EvSurvivorDowned.new())
	for expected in [L.WIND_UP, L.ACTIVE, L.TAKEDOWN_COMMIT]:
		while _ma.lunge_state() != expected:
			_step()
		for ability in [A.FALSE_SIGNAL, A.BLACKOUT]:
			assert_bool(_ma.can_activate(ability, _now() + 1)).is_false()
			_req(ability)
			_step()
			assert_array(_ready_ticks()).is_equal([0, 0, 0])
	_step()
	assert_int(_ma.lunge_state()).is_equal(L.COOLDOWN)
	assert_bool(_ma.can_activate(A.FALSE_SIGNAL, _now() + 1)).is_true()
	assert_bool(_ma.can_activate(A.BLACKOUT, _now() + 1)).is_true()


## AC-2 edge: a request on the tick the lunge resolves is validated after the resolution, so the guard
## no longer blocks it; it still costs no cooldown here (False Signal's body is story 009).
func test_request_on_resolving_tick_is_not_blocked() -> void:
	_start()
	var a := _lunge()
	_step(_windup + _dash - 1)
	assert_int(_ma.lunge_state()).is_equal(L.ACTIVE)
	assert_bool(_ma.can_activate(A.FALSE_SIGNAL, _now())).is_false()
	_req(A.FALSE_SIGNAL)
	_step()
	assert_int(_now()).is_equal(a + _windup + _dash)
	assert_int(_ma.lunge_state()).is_equal(L.COOLDOWN)
	assert_bool(_ma.can_activate(A.FALSE_SIGNAL, _now())).is_true()
	assert_int(_ma.ready_tick(A.FALSE_SIGNAL)).is_equal(0)


## AC-3: a hit lunge runs Ready, Wind-up, Active, Takedown Commit, Resolved, Cooldown, Ready in GDD order
## on the GDD's ticks; a hit outside Active is ignored (no illegal jump).
func test_state_machine_with_hit() -> void:
	_start()
	_defense.at(2, _hit()) ## during wind-up: ignored
	var a := _lunge()
	var h := a + _windup + 2
	_defense.at(h, _hit())
	var d := h + 5
	_downing.at(d, EvSurvivorEliminated.new())
	_step(d + _cooldown - _now())
	assert_array(_states).is_equal([[L.WIND_UP, a], [L.ACTIVE, a + _windup], [L.TAKEDOWN_COMMIT, h],
		[L.RESOLVED, d], [L.COOLDOWN, d], [L.READY, d + _cooldown]])


## AC-3 edge: a miss skips Takedown Commit and resolves at dash end.
func test_miss_skips_takedown_commit() -> void:
	_start()
	var a := _lunge()
	_step(_windup + _dash)
	var e := a + _windup + _dash
	assert_array(_states).is_equal([[L.WIND_UP, a], [L.ACTIVE, a + _windup], [L.RESOLVED, e], [L.COOLDOWN, e]])


## "States and Transitions": a stun in wind-up resolves the lunge (interrupted); a later hit is ignored.
func test_stun_in_windup_resolves() -> void:
	_start()
	var a := _lunge()
	_defense.at(a + 1, _stun())
	_defense.at(a + _windup + 1, _hit())
	_step(_windup + _dash)
	assert_array(_states).is_equal([[L.WIND_UP, a], [L.RESOLVED, a + 1], [L.COOLDOWN, a + 1]])


## AC-4: a lunge used on the tick a form change completes leaves the False Signal and Blackout cooldowns
## and Borrowed Face's form-change cooldown unchanged (the real BorrowedFace runs in its own slot).
func test_cooldowns_are_independent() -> void:
	var bf := BorrowedFace.new()
	bf.set_roster(SURVIVORS, MONSTER)
	bf.set_sight_sources(_eye_of, _yaw_of, _points_of, _sight)
	bf.set_status_source(_status_of)
	_start({TickOrder.BORROWED_FACE: bf})
	_ma.set_status_sources(bf.form, bf.transforming, _locked)
	var bfk := _knobs.borrowed_face
	var transform := _knobs.ticks(bfk.transform_duration_s)
	var form_cd := _knobs.ticks(bfk.form_change_cooldown_s)
	_step(_knobs.ticks(bfk.observe_time_s))
	bf.request_form_change(MONSTER, BorrowedFace.request_packet(S1))
	_step()
	var b := _now() + transform + form_cd
	_step(b - 1 - _now())
	bf.request_form_change(MONSTER, BorrowedFace.request_packet(BorrowedFace.TRUE_FORM))
	_step()
	var c := b + transform
	_step(c - 1 - _now())
	assert_int(bf.form()).is_equal(S1)
	_req(A.LUNGE)
	_step() ## tick c: the form change completes in slot 300, the lunge is accepted in slot 400
	assert_int(bf.form()).is_equal(BorrowedFace.TRUE_FORM)
	assert_int(_ma.lunge_state()).is_equal(L.WIND_UP)
	assert_array(_ready_ticks()).is_equal([0, 0, 0])
	_step(c + form_cd - 1 - _now() - 1)
	bf.request_form_change(MONSTER, BorrowedFace.request_packet(S1))
	_step()
	assert_bool(bf.transforming()).is_false()
	bf.request_form_change(MONSTER, BorrowedFace.request_packet(S1))
	_step()
	assert_int(_now()).is_equal(c + form_cd)
	assert_bool(bf.transforming()).is_true()
	assert_array(_ready_ticks().slice(1)).is_equal([0, 0])


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


## AC-5: the module source has no numeric literal equal to an AbilityKnobs value.
func test_no_knob_literals_in_module() -> void:
	var src := FileAccess.get_file_as_string(SRC)
	assert_str(src).is_not_empty()
	assert_array(_knob_literals(src)).is_empty()


## AC-5 edge: the scan itself catches 0.6, 4 and 10.
func test_knob_literal_scan_catches_literals() -> void:
	for line in ["var w := 0.6", "x = 4", "if t > 10.0:"]:
		assert_array(_knob_literals(line)).override_failure_message(line).is_not_empty()
	assert_array(_knob_literals("var x := -1 # 0.6 in a comment\nvar s := \"10\"")).is_empty()


## Numeric literals in `src` (comments and strings stripped) equal to any AbilityKnobs value.
func _knob_literals(src: String) -> Array[String]:
	var values: Array[float] = []
	for p in _knobs.ability.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			values.append(float(_knobs.ability.get(p.name)))
	var strip := RegEx.create_from_string("\"[^\"\\n]*\"|#[^\\n]*")
	var num := RegEx.create_from_string("(?<![\\w.])-?\\d+(\\.\\d+)?(e[-+]?\\d+)?")
	var found: Array[String] = []
	for m in num.search_all(strip.sub(src, "", true)):
		if values.has(float(m.get_string())):
			found.append(m.get_string())
	return found
