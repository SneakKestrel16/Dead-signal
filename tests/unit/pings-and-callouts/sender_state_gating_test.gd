# Story pings-and-callouts/002: sender-state gating for pings and callouts
# (design/gdd/pings-and-callouts.md rules 14, 21, 22, 23; States and Transitions).
# PingsCallouts.can_send over fake life/status/form sources; the shock lock is a real SurvivorDefense in a
# RoundServer, so the lock's length and the post-lock window are Survivor Defense's own.
extends GdUnitTestSuite

const M := 1 ## the monster
const S := 2 ## a survivor sender
const B := 3 ## the survivor the monster borrows
const SURVIVORS: Array[int] = [2, 3, 4, 5]
const DRIVE_HERE := &"drive_here"
const PING := PingsCallouts.LOCATION
const CALLOUT := PingsCallouts.CALLOUT

var _knobs: Knobs
var _server: RoundServer
var _sd: SurvivorDefense
var _pc: PingsCallouts
var _status: Dictionary
var _life: Dictionary
var _form: int
var _transforming: bool


func before_test() -> void:
	_knobs = Knobs.load_all()
	_status = {}
	_life = {}
	_form = B
	_transforming = false
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_sd = SurvivorDefense.new()
	_sd.set_roster(SURVIVORS, M)
	assert_array(_server.start_round({TickOrder.SURVIVOR_DEFENSE: _sd}, _knobs)).is_empty()
	_pc = PingsCallouts.new()
	_pc.set_sender_sources(M, _status_of, _life_of, _form_of, _transforming_of, _sd.locked)


func after_test() -> void:
	if _server != null:
		_server.end_round()


func _status_of(p: int) -> MatchFlow.Status:
	return _status.get(p, MatchFlow.Status.HEALTHY)


func _life_of(p: int) -> Downing.LifeState:
	return _life.get(p, Downing.LifeState.HEALTHY)


func _form_of() -> int:
	return _form


func _transforming_of() -> bool:
	return _transforming


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


## Whether `p` may send a ping, and each authored callout line.
func _all(p: int) -> Array[bool]:
	var r: Array[bool] = [_pc.can_send(p, PING)]
	for line: StringName in PingsCallouts.CALLOUT_LINES:
		r.append(_pc.can_send(p, CALLOUT, line))
	return r


func _none() -> Array[bool]:
	var r: Array[bool] = []
	r.resize(PingsCallouts.CALLOUT_LINES.size() + 1)
	r.fill(false)
	return r


func _every() -> Array[bool]:
	var r := _none()
	r.fill(true)
	return r


# AC-1 -------------------------------------------------------------------------------------------

func test_healthy_survivor_sends_every_ping_and_callout() -> void:
	assert_array(_all(S)).is_equal(_every())
	for k: int in [PingsCallouts.ITEM, PingsCallouts.WARNING_POINT, PingsCallouts.WARNING_PLAYER]:
		assert_bool(_pc.can_send(S, k)).is_true()


func test_seized_eliminated_escaped_survivor_sends_nothing() -> void:
	_life[S] = Downing.LifeState.SEIZED
	assert_array(_all(S)).is_equal(_none())
	_life[S] = Downing.LifeState.ELIMINATED
	_status[S] = MatchFlow.Status.ELIMINATED
	assert_array(_all(S)).is_equal(_none())
	_life[S] = Downing.LifeState.HEALTHY
	_status[S] = MatchFlow.Status.ESCAPED
	assert_array(_all(S)).is_equal(_none())


func test_downed_survivor_sends_pings_need_rescue_and_danger_only() -> void:
	_life[S] = Downing.LifeState.DOWNED
	_status[S] = MatchFlow.Status.DOWNED
	assert_bool(_pc.can_send(S, PING)).is_true()
	for line: StringName in PingsCallouts.CALLOUT_LINES:
		assert_bool(_pc.can_send(S, CALLOUT, line)).override_failure_message(str(line)) \
			.is_equal(line in [PingsCallouts.NEED_RESCUE, PingsCallouts.DANGER])


func test_unknown_callout_line_is_rejected() -> void:
	assert_bool(_pc.can_send(S, CALLOUT, &"not_a_line")).is_false()
	assert_bool(_pc.can_send(S, PingsCallouts.INVALID)).is_false()


# AC-2 -------------------------------------------------------------------------------------------

func test_true_form_and_transforming_monster_sends_nothing() -> void:
	assert_array(_all(M)).is_equal(_every())
	_form = BorrowedFace.TRUE_FORM
	assert_array(_all(M)).is_equal(_none())
	_transforming = true
	assert_array(_all(M)).is_equal(_none())
	_form = B
	assert_array(_all(M)).is_equal(_none())


# AC-3 -------------------------------------------------------------------------------------------

func test_shock_blocks_survivor_until_stun_duration_then_first_is_accepted() -> void:
	_step(1)
	var hit := _server.tick_runner.current_tick()
	assert_bool(_sd.shock(S, hit)).is_true()
	assert_array(_all(S)).is_equal(_none())
	_step(_knobs.ticks(_knobs.defense.stun_duration_s) - 1)
	assert_array(_all(S)).is_equal(_none())
	_step(1)
	assert_array(_all(S)).is_equal(_every())


func test_stun_blocks_disguised_monster_until_stun_duration() -> void:
	_step(1)
	assert_bool(_sd.shock(M, _server.tick_runner.current_tick())).is_true()
	assert_array(_all(M)).is_equal(_none())
	_step(_knobs.ticks(_knobs.defense.stun_duration_s))
	assert_array(_all(M)).is_equal(_every())


func test_hit_inside_post_lock_window_blocks_nothing() -> void:
	_step(1)
	for p: int in [S, M]:
		_sd.shock(p, _server.tick_runner.current_tick())
	_step(_knobs.ticks(_knobs.defense.stun_duration_s))
	# Immune monster and a survivor in its window: the hit adds no lock.
	for p: int in [S, M]:
		assert_bool(_sd.shock(p, _server.tick_runner.current_tick())).is_false()
		assert_array(_all(p)).is_equal(_every())


# AC-4 -------------------------------------------------------------------------------------------

func test_disguise_as_eliminated_or_escaped_survivor_sends_nothing() -> void:
	for st: MatchFlow.Status in [MatchFlow.Status.ELIMINATED, MatchFlow.Status.ESCAPED]:
		_status[B] = st
		assert_array(_all(M)).is_equal(_none())


func test_disguise_as_downed_seized_or_hidden_survivor_sends_any_callout() -> void:
	_status[B] = MatchFlow.Status.DOWNED
	_life[B] = Downing.LifeState.DOWNED
	assert_bool(_pc.can_send(M, CALLOUT, DRIVE_HERE)).is_true()
	assert_array(_all(M)).is_equal(_every())
	_status[B] = MatchFlow.Status.HEALTHY
	_life[B] = Downing.LifeState.SEIZED
	assert_array(_all(M)).is_equal(_every())


# Wiring: the ping path runs the gate ------------------------------------------------------------

func test_gated_sender_ping_is_not_accepted() -> void:
	_pc.set_sources(func(_p: int) -> Vector3: return Vector3.ZERO, func(_p: int) -> Vector3: return Vector3.ZERO,
			func(_s: int, _f: Vector3, _t: Vector3, _i: int) -> bool: return true,
			func(p: int) -> int: return p, func(_p: int) -> bool: return false)
	_pc.setup(null, null, null, _knobs)
	var bytes := PingsCallouts.ping_packet(PING, Vector3(0.0, 0.0, -5.0))
	_life[S] = Downing.LifeState.SEIZED
	_pc.request_ping(S, bytes)
	_pc.server_tick(1)
	assert_int(_pc.accepted().size()).is_equal(0)
	_life[S] = Downing.LifeState.HEALTHY
	_pc.request_ping(S, bytes)
	_pc.server_tick(2)
	assert_int(_pc.accepted().size()).is_equal(1)
