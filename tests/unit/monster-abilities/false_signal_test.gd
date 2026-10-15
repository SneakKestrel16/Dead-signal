# Story monster-abilities/009: False Signal (design/gdd/monster-abilities.md rules 13-16, Edge Cases; ADR-0004
# §5-6, ADR-0013). The module runs alone in a RoundServer; the floor snap, the footstep path cut, the
# observed list, statuses and the sound send are stubs. A wall fills x >= WALL_X.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const S3 := 4
const SURVIVORS: Array[int] = [2, 3, 4]
const A := MonsterAbilities.Ability
const T := MonsterAbilities.SignalType
const WALL_X := 15.0
## The footstep path cut stops this far short of the wall (a body radius, stub value).
const WALL_GAP := 0.5
## Real walk footstep interval passed as the cadence (stub value; no Controller knob yet).
const STEP_S := 0.5
const INTERACTION_RADIUS := 25.0

var _server: RoundServer
var _ma: MonsterAbilities
var _knobs: Knobs
var _form_now: int
## Each sent sound: [pos, set, radius, tick].
var _sounds: Array = []
var _used: Array[EvAbilityUsed] = []
var _objective_events := 0
var _observed: Dictionary[int, bool] = {}
var _status: Dictionary[int, int] = {}


func before_test() -> void:
	_knobs = Knobs.load_all()
	_form_now = BorrowedFace.TRUE_FORM
	_sounds = []
	_used = []
	_objective_events = 0
	_observed = {S1: true, S2: true, S3: false}
	_status = {S1: MatchFlow.Status.HEALTHY, S2: MatchFlow.Status.HEALTHY, S3: MatchFlow.Status.HEALTHY}
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_ma = MonsterAbilities.new()
	_ma.set_monster(MONSTER)
	_ma.set_status_sources(_form, _transforming)
	_ma.set_position_source(_position_of)
	var radius: Dictionary[StringName, float] = {SurvivorObjectives.INSTALL_SOUND: INTERACTION_RADIUS}
	_ma.set_false_signal_sources(_emit_sound, _snap, _is_observed, _status_of, _footstep_set_of, radius,
		STEP_S, _path_end)
	assert_array(_server.start_round({TickOrder.MONSTER_ABILITIES: _ma}, _knobs)).is_empty()
	_server.bus.subscribe(&"AbilityUsed", _on_used)
	_server.bus.subscribe(&"ObjectiveProgressChanged", _on_objective)


func after_test() -> void:
	_server.end_round()
	_ma = null


func _form() -> int:
	return _form_now


func _transforming() -> bool:
	return false


func _position_of(_p: int) -> Vector3:
	return Vector3.ZERO


func _emit_sound(pos: Vector3, sound_set: StringName, radius: float) -> void:
	_sounds.append([pos, sound_set, radius, _now()])


func _snap(p: Vector3) -> Variant:
	return null if p.x >= WALL_X else Vector3(p.x, 0.0, p.z)


func _path_end(from: Vector3, to: Vector3) -> Vector3:
	var stop := WALL_X - WALL_GAP
	return to if to.x <= stop else from.lerp(to, (stop - from.x) / (to.x - from.x))


func _is_observed(s: int) -> bool:
	return _observed.get(s, false)


func _status_of(s: int) -> int:
	return _status[s]


func _footstep_set_of(s: int) -> StringName:
	return StringName("c%d.walk" % s) if SURVIVORS.has(s) else &""


func _on_used(e: ServerEvent) -> void:
	_used.append(e as EvAbilityUsed)


func _on_objective(_e: ServerEvent) -> void:
	_objective_events += 1


func _now() -> int:
	return _server.tick_runner.current_tick()


func _step(n: int = 1) -> void:
	for i in n:
		_server.tick_runner.step()


## Sends a False Signal request and runs one tick; true when it was accepted.
func _signal(type: int, aim: Vector3, survivor: int = -1, dir: Vector3 = Vector3.ZERO,
		sound: StringName = &"") -> bool:
	var before := _ma.falsesignals_used()
	_ma.request_ability(MONSTER, MonsterAbilities.signal_packet(type, aim, survivor, dir, sound))
	_step()
	return _ma.falsesignals_used() > before


func _interaction(aim: Vector3) -> bool:
	return _signal(T.INTERACTION, aim, -1, Vector3.ZERO, SurvivorObjectives.INSTALL_SOUND)


## AC-1: rejected within false_signal_cooldown_s of the previous one; the cooldown runs from activation.
func test_cooldown_from_activation() -> void:
	assert_bool(_interaction(Vector3(5.0, 0.0, 0.0))).is_true()
	var at := _now()
	var cd := _knobs.ticks(_knobs.ability.false_signal_cooldown_s)
	assert_int(_ma.ready_tick(A.FALSE_SIGNAL)).is_equal(at + cd)
	_step(cd - 2)
	assert_bool(_interaction(Vector3(5.0, 0.0, 0.0))).is_false()
	assert_int(_sounds.size()).is_equal(1)
	assert_bool(_interaction(Vector3(5.0, 0.0, 0.0))).is_true()
	assert_int(_now()).is_equal(at + cd)
	assert_int(_ma.falsesignals_used()).is_equal(2)
	var stats := _server.registry.view(StateKeys.STATS_ABILITIES, AbilitiesStatsView) as AbilitiesStatsView
	assert_int(stats.get_false_signals_used()).override_failure_message("MA-8 stats view").is_equal(2)


## AC-1: an aim point beyond false_signal_range_m or inside a wall is rejected at no cooldown cost; an
## accepted point snaps to walkable floor.
func test_range_wall_and_snap() -> void:
	var r := _knobs.ability.false_signal_range_m
	assert_bool(_interaction(Vector3(0.0, 0.0, r + 0.01))).is_false()
	assert_bool(_interaction(Vector3(WALL_X + 1.0, 0.0, 0.0))).is_false()
	assert_int(_ma.ready_tick(A.FALSE_SIGNAL)).is_equal(0)
	assert_array(_used).is_empty()
	assert_bool(_interaction(Vector3(0.0, 1.2, r - 2.0))).is_true()
	assert_vector(_sounds[0][0]).is_equal(Vector3(0.0, 0.0, r - 2.0))
	assert_vector(_used[0].target).is_equal(Vector3(0.0, 0.0, r - 2.0))


## AC-2: a callout naming an unobserved, Eliminated or Escaped survivor is rejected; an observed one in
## play is accepted as AbilityUsed with the signal type and the impersonated survivor (no sound here:
## Pings & Callouts presents it).
func test_callout_survivor_rules() -> void:
	var aim := Vector3(4.0, 0.0, 4.0)
	assert_bool(_signal(T.CALLOUT, aim, S3)).override_failure_message("unobserved").is_false()
	assert_bool(_signal(T.CALLOUT, aim, MONSTER)).override_failure_message("not a survivor").is_false()
	_status[S1] = MatchFlow.Status.ELIMINATED
	assert_bool(_signal(T.CALLOUT, aim, S1)).override_failure_message("eliminated").is_false()
	_status[S1] = MatchFlow.Status.ESCAPED
	assert_bool(_signal(T.CALLOUT, aim, S1)).override_failure_message("escaped").is_false()
	assert_bool(_signal(T.CALLOUT, aim, S2)).is_true()
	assert_int(_used.size()).is_equal(1)
	assert_int(_used[0].ability).is_equal(A.FALSE_SIGNAL)
	assert_str(String(_used[0].detail)).is_equal("callout")
	assert_int(_used[0].survivor).is_equal(S2)
	assert_array(_sounds).is_empty()


## AC-3: footsteps for false_signal_footstep_duration_s, one per walk step, moving at walk_speed (so at
## most walk_speed x duration from the aim point), each sent at the walk radius around its current point.
func test_footsteps_walk_path() -> void:
	var aim := Vector3(0.0, 0.0, 2.0)
	assert_bool(_signal(T.FOOTSTEPS, aim, S1, Vector3(0.0, 0.0, -3.0))).is_true()
	var start := _now()
	_step(_knobs.ticks(_knobs.ability.false_signal_footstep_duration_s) + 10)
	var dur := _knobs.ticks(_knobs.ability.false_signal_footstep_duration_s)
	var every := _knobs.ticks(STEP_S)
	var walk := _knobs.controller.walk_speed
	var hz := float(_knobs.net.sim_tick_hz)
	assert_int(_sounds.size()).is_equal(ceili(float(dur) / every))
	for i in _sounds.size():
		var s: Array = _sounds[i]
		assert_int(s[3]).is_equal(start + i * every)
		assert_str(String(s[1])).is_equal("c2.walk")
		assert_float(s[2]).is_equal(_knobs.controller.footstep_radius_walk_m)
		assert_float(aim.distance_to(s[0])).is_equal_approx(walk * i * every / hz, 1e-4)
		assert_float(aim.distance_to(s[0])).is_less_equal(walk * _knobs.ability.false_signal_footstep_duration_s)
	assert_str(String(_used[0].detail)).is_equal("footsteps")


## AC-3, Edge Cases: the footstep path stops at the first wall; the steps end there.
func test_footsteps_stop_at_wall() -> void:
	var aim := Vector3(WALL_X - 3.0, 0.0, 0.0)
	assert_bool(_signal(T.FOOTSTEPS, aim, S1, Vector3.RIGHT)).is_true()
	_step(_knobs.ticks(_knobs.ability.false_signal_footstep_duration_s) + 10)
	var reach := (WALL_X - WALL_GAP) - aim.x
	var walk := _knobs.controller.walk_speed
	assert_int(_sounds.size()).is_equal(ceili(reach / walk / STEP_S))
	for s: Array in _sounds:
		assert_float(s[0].x).is_less_equal(WALL_X - WALL_GAP)


## Footsteps need a survivor's set and a horizontal direction.
func test_footsteps_need_set_and_direction() -> void:
	assert_bool(_signal(T.FOOTSTEPS, Vector3.ZERO, MONSTER, Vector3.RIGHT)).is_false()
	assert_bool(_signal(T.FOOTSTEPS, Vector3.ZERO, S1, Vector3.UP)).is_false()
	assert_array(_sounds).is_empty()


## AC-4: a fake interaction sound is a sound only: no objective state changes; an unknown sound set is
## rejected.
func test_interaction_changes_no_objective() -> void:
	assert_bool(_signal(T.INTERACTION, Vector3.ZERO, -1, Vector3.ZERO, &"not_a_sound")).is_false()
	assert_bool(_interaction(Vector3(3.0, 0.0, 0.0))).is_true()
	_step(5)
	assert_int(_objective_events).is_equal(0)
	assert_array(_sounds).is_equal([[Vector3(3.0, 0.0, 0.0), SurvivorObjectives.INSTALL_SOUND, INTERACTION_RADIUS, _now() - 5]])


## AC-5: accepted while Disguised; the module never touches the form.
func test_accepted_while_disguised() -> void:
	_form_now = S1
	assert_bool(_interaction(Vector3(3.0, 0.0, 0.0))).is_true()
	assert_int(_form_now).is_equal(S1)


## Untrusted bytes: a plain request, an oversize or wrong-shaped signal packet, or another sender, is no
## False Signal.
func test_bad_requests_rejected() -> void:
	_ma.request_ability(MONSTER, MonsterAbilities.request_packet(A.FALSE_SIGNAL, Vector3.ZERO))
	_step()
	_ma.request_ability(S1, MonsterAbilities.signal_packet(T.INTERACTION, Vector3.ZERO, -1, Vector3.ZERO,
		SurvivorObjectives.INSTALL_SOUND))
	_step()
	var p := MonsterAbilities.signal_packet(T.INTERACTION, Vector3.ZERO, -1, Vector3.ZERO,
		StringName("x".repeat(MonsterAbilities.SIGNAL_CAP_BYTES)))
	assert_dict(MonsterAbilities.decode_signal(p)).is_empty()
	var bad := {"ability": A.FALSE_SIGNAL, "aim": Vector3.ZERO, "type": 7, "survivor": -1, "dir": Vector3.ZERO,
		"sound": &""}
	assert_dict(MonsterAbilities.decode_signal(var_to_bytes(bad))).is_empty()
	bad["type"] = T.CALLOUT
	bad["dir"] = Vector3(NAN, 0.0, 0.0)
	assert_dict(MonsterAbilities.decode_signal(var_to_bytes(bad))).is_empty()
	assert_int(_ma.falsesignals_used()).is_equal(0)
	assert_array(_used).is_empty()
