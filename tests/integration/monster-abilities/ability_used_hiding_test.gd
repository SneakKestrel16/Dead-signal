# Story monster-abilities/005: AbilityUsed emission and Lunge state publishing
# (design/gdd/monster-abilities.md rule 3a, "States and Transitions"; borrowed-face.md rule 7;
# TR-monster-006, -008; ADR-0004 §5, ADR-0005). MonsterAbilities and the real BorrowedFace run in a
# RoundServer with stub sight, status and position sources. Survivor Defense and Downing are stood in for
# by events the test emits (story QA note: until MA-6 and SD-12). The survivor capture runs each tick's
# delivered events through EventBatch.build and decode, the per-viewer path ServerMovement._send_stream
# sends on the event channel (no ENet: the bytes are the ones a client would receive).
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const SURVIVORS: Array[int] = [2, 3]
const EYE := Vector3(0.0, 1.6, 0.0)
const AIM := Vector3(1.0, 0.0, 2.0)
const MONSTER_POS := Vector3(7.25, 0.0, -3.5)
## AC-2 edge case: S1 stands beside the monster, so its body is relevant to S1.
const BESIDE := Vector3(7.75, 0.0, -3.5)
const FAR := Vector3(-40.0, 0.0, 30.0)
const SEED := 5005
const A := MonsterAbilities.Ability
const L := MonsterAbilities.Lunge

var _knobs: Knobs
var _server: RoundServer
var _ma: MonsterAbilities
var _bf: BorrowedFace
var _view: LungeView
var _form_view: TransformView
var _locked_now := false
var _used: Array[EvAbilityUsed] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_locked_now = false
	_used = []
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_bf = BorrowedFace.new()
	_bf.set_roster(SURVIVORS, MONSTER)
	_bf.set_sight_sources(_eye_of, _yaw_of, _points_of, _sight)
	_bf.set_status_source(_status_of)
	_ma = MonsterAbilities.new()
	_ma.set_monster(MONSTER)
	_ma.set_position_source(_position_of)
	assert_array(_server.start_round({TickOrder.BORROWED_FACE: _bf, TickOrder.MONSTER_ABILITIES: _ma}, _knobs)).is_empty()
	_view = _server.registry.view(StateKeys.LUNGE_STATE, LungeView) as LungeView
	_form_view = _server.registry.view(StateKeys.TRANSFORMING, TransformView) as TransformView
	assert_object(_view).is_not_null()
	_ma.set_status_sources(_form_view.get_form, _form_view.get_transforming, _locked)
	_bf.set_attack_source(_view.is_attacking)
	_server.bus.subscribe(&"AbilityUsed", _on_used)


func after_test() -> void:
	_server.end_round()
	_ma = null
	_bf = null


func _position_of(p: int) -> Vector3:
	return MONSTER_POS if p == MONSTER else (BESIDE if p == S1 else FAR)


func _locked(_p: int) -> bool:
	return _locked_now


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


func _on_used(e: ServerEvent) -> void:
	_used.append(e as EvAbilityUsed)


func _step(n: int = 1) -> void:
	for i in n:
		_server.tick_runner.step()


func _now() -> int:
	return _server.tick_runner.current_tick()


func _req() -> void:
	_ma.request_ability(MONSTER, MonsterAbilities.request_packet(A.LUNGE, AIM))


func _emit(e: ServerEvent) -> void:
	_server.bus.emit(e)


func _assert_used(e: EvAbilityUsed, tick: int) -> void:
	assert_int(e.ability).is_equal(A.LUNGE)
	assert_vector(e.position).is_equal(MONSTER_POS)
	assert_vector(e.target).is_equal(AIM)
	assert_int(e.tick).is_equal(tick)


## AC-1: one AbilityUsed at wind-up start per accepted lunge, none for a rejection; two in a row.
func test_one_ability_used_per_accepted_lunge_none_for_a_rejection() -> void:
	_locked_now = true
	_req()
	_step()
	assert_array(_used).override_failure_message("rejected request emitted").is_empty()
	_locked_now = false
	_req()
	_step()
	assert_int(_view.get_state()).is_equal(L.WIND_UP)
	assert_int(_used.size()).is_equal(1)
	_assert_used(_used[0], _now())
	_req() ## rejected: already attacking
	_step()
	assert_int(_used.size()).is_equal(1)
	# Run out wind-up, dash and cooldown (a miss), then lunge again.
	_step(_knobs.ticks(_knobs.ability.lunge_windup_s) + _knobs.ticks(_knobs.ability.lunge_dash_s))
	assert_int(_view.get_state()).is_equal(L.COOLDOWN)
	_step(_ma.ready_tick(A.LUNGE) - _now())
	assert_int(_view.get_state()).is_equal(L.READY)
	assert_int(_used.size()).override_failure_message("emitted outside wind-up start").is_equal(1)
	_req()
	_step()
	assert_int(_used.size()).is_equal(2)
	_assert_used(_used[1], _now())


## AC-2: what every client's event batch carries during a whole lunge, with S1 beside the monster: no
## AbilityUsed and no monster position, though the server delivered the event.
func test_no_client_batch_carries_ability_used_or_the_monster_position() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var handles := HandleTable.new(rng)
	handles.handle_for(S1, MONSTER) ## the monster's body is relevant to the survivor beside it
	var pos_bytes := var_to_bytes(MONSTER_POS)
	pos_bytes = pos_bytes.slice(4) ## the three floats, without the Variant type header
	_server.bus.take_tick_events()
	_req()
	var delivered := 0
	var ticks := _knobs.ticks(_knobs.ability.lunge_windup_s) + _knobs.ticks(_knobs.ability.lunge_dash_s) + 2
	for i in ticks:
		_step()
		var events := _server.bus.take_tick_events()
		for e in events:
			if e is EvAbilityUsed:
				delivered += 1
		for viewer: int in [S1, S2, MONSTER]:
			var bytes := EventBatch.build(_now(), viewer, events, [], _position_of(viewer), handles, MONSTER)
			var hex := bytes.hex_encode()
			assert_bool(hex.contains(pos_bytes.hex_encode())).override_failure_message(
				"viewer %d got the monster position at tick %d" % [viewer, _now()]).is_false()
			if bytes.is_empty():
				continue
			for entry: Array in EventBatch.decode(bytes).entries:
				assert_str(str(entry[0])).override_failure_message("viewer %d" % viewer).is_not_equal("AbilityUsed")
	assert_int(delivered).override_failure_message("capture saw no AbilityUsed").is_equal(1)


## AC-3: wind-up, Active and takedown commit are readable from the registry for the monster only, and
## the state clears on resolution (Survivor Defense reads it to end stun immunity, rule 16).
func test_lunge_state_readable_in_each_phase_and_cleared_on_resolution() -> void:
	assert_int(_view.get_state()).is_equal(L.READY)
	assert_bool(_view.is_attacking(MONSTER)).is_false()
	_req()
	_step()
	assert_int(_view.get_state()).is_equal(L.WIND_UP)
	assert_bool(_view.is_attacking(MONSTER)).is_true()
	assert_bool(_view.is_attacking(S1)).override_failure_message("a survivor is never attacking").is_false()
	_step(_knobs.ticks(_knobs.ability.lunge_windup_s))
	assert_int(_view.get_state()).is_equal(L.ACTIVE)
	assert_bool(_view.is_attacking(MONSTER)).is_true()
	var hit := EvSurvivorHit.new()
	hit.survivor = S1
	_emit(hit)
	_step()
	assert_int(_view.get_state()).is_equal(L.TAKEDOWN_COMMIT)
	assert_bool(_view.is_attacking(MONSTER)).is_true()
	var downed := EvSurvivorDowned.new()
	downed.survivor = S1
	_emit(downed)
	_step()
	assert_int(_view.get_state()).is_equal(L.COOLDOWN)
	assert_bool(_view.is_attacking(MONSTER)).override_failure_message("not cleared on resolution").is_false()


## AC-3, borrowed-face.md rule 7: a transformation requested in wind-up, Active or takedown commit is
## rejected through the registry view; after the lunge resolves the same request is accepted.
func test_transformation_blocked_while_the_lunge_attacks() -> void:
	_step(_knobs.ticks(_knobs.borrowed_face.observe_time_s))
	assert_bool(_bf.observed(S1)).is_true()
	_req()
	_step()
	for phase in [L.WIND_UP, L.ACTIVE, L.TAKEDOWN_COMMIT]:
		if phase == L.ACTIVE:
			_step(_knobs.ticks(_knobs.ability.lunge_windup_s) - 1)
		elif phase == L.TAKEDOWN_COMMIT:
			var hit := EvSurvivorHit.new()
			hit.survivor = S2
			_emit(hit)
		_bf.request_form_change(MONSTER, BorrowedFace.request_packet(S1))
		_step()
		assert_int(_view.get_state()).is_equal(phase)
		assert_bool(_form_view.get_transforming()).override_failure_message("transform accepted in %d" % phase).is_false()
	var stun := EvMonsterStunned.new()
	stun.monster = MONSTER
	stun.true_form = true
	_emit(stun)
	_step()
	assert_bool(_view.is_attacking(MONSTER)).is_false()
	_bf.request_form_change(MONSTER, BorrowedFace.request_packet(S1))
	_step()
	assert_bool(_form_view.get_transforming()).override_failure_message("rejected after resolution").is_true()


## The view holds the module weakly: freed, it reads Ready and not attacking.
func test_view_reads_ready_after_the_module_is_gone() -> void:
	var view := LungeView.new(MonsterAbilities.new())
	assert_int(view.get_state()).is_equal(L.READY)
	assert_bool(view.is_attacking(MONSTER)).is_false()
