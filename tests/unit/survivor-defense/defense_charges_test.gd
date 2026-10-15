# Story survivor-defense/001: taser charges, reuse delay, item-use gate and forged intents
# (design/gdd/survivor-defense.md rules 1, 7, 8, 13, 29; ADR-0002, ADR-0005).
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const S3 := 4
const S4 := 5
const SURVIVORS: Array[int] = [2, 3, 4, 5]

var _server: RoundServer
var _def: SurvivorDefense
var _d: Downing
var _abilities: Emitter
var _knobs: Knobs


func _start(charges: int = -1) -> void:
	_knobs = Knobs.load_all()
	if charges > 0:
		_knobs.defense.stun_item_charges = charges
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_d = Downing.new()
	_d.set_roster(SURVIVORS, MONSTER)
	_def = SurvivorDefense.new()
	_def.set_roster(SURVIVORS, MONSTER)
	_def.set_locked(_d.action_locked)
	_abilities = Emitter.new()
	var errs := _server.start_round({TickOrder.SURVIVOR_DEFENSE: _def,
		TickOrder.MONSTER_ABILITIES: _abilities, TickOrder.DOWNING: _d}, _knobs)
	assert_array(errs).is_empty()


func after_test() -> void:
	if _server != null:
		_server.end_round()


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


func _now() -> int:
	return _server.tick_runner.current_tick()


func _reuse_ticks() -> int:
	return _knobs.ticks(_knobs.defense.stun_item_reuse_s)


## Sends `player`'s fire intent and runs the tick that validates it.
func _fire(player: int) -> void:
	_def.request_intent(player, SurvivorDefense.fire_packet())
	_step(1)


## Starts a takedown commit on `survivor` on the next tick; returns the tick it completes.
func _seize(survivor: int) -> int:
	var hit := EvSurvivorHit.new()
	hit.survivor = survivor
	var t := _now() + 1
	_abilities.at(t, hit)
	_step(1)
	assert_int(_d.life_state(survivor)).is_equal(Downing.LifeState.SEIZED)
	return t + _knobs.ticks(_knobs.downing.takedown_commit_s)


func _state() -> Array:
	var out := []
	for p: int in SURVIVORS + [MONSTER]:
		out.append([_def.charges(p), _def.is_hidden(p), _d.life_state(p)])
	return out


# AC-1 -------------------------------------------------------------------------------------------

func test_two_cartridges_third_attempt_spends_nothing() -> void:
	_start()
	assert_int(_def.charges(S1)).is_equal(2)
	_fire(S1)
	assert_int(_def.charges(S1)).is_equal(1)
	_step(_reuse_ticks())
	_fire(S1)
	assert_int(_def.charges(S1)).is_equal(0)
	_step(_reuse_ticks())
	_fire(S1)
	assert_int(_def.charges(S1)).override_failure_message("third attempt spends nothing").is_equal(0)
	assert_int(_def.charges(S2)).override_failure_message("per survivor").is_equal(2)


func test_charges_follow_the_knob() -> void:
	for n: int in [1, 3]:
		_start(n)
		for s: int in SURVIVORS:
			assert_int(_def.charges(s)).is_equal(n)
		for i in n + 1:
			_fire(S1)
			_step(_reuse_ticks())
		assert_int(_def.charges(S1)).is_equal(0)
		_server.end_round()
		_server = null


# AC-2 -------------------------------------------------------------------------------------------

func test_second_fire_inside_reuse_window_is_ignored_and_exactly_at_it_fires() -> void:
	_start()
	_fire(S1)
	var fired := _now()
	_step(fired + _reuse_ticks() - 1 - _now() - 1)
	_fire(S1) # validated on fired + reuse - 1
	assert_int(_def.charges(S1)).override_failure_message("inside the window").is_equal(1)
	_fire(S1) # validated on fired + reuse exactly
	assert_int(_now()).is_equal(fired + _reuse_ticks())
	assert_int(_def.charges(S1)).override_failure_message("exactly at stun_item_reuse_s").is_equal(0)


func test_one_intent_per_tick() -> void:
	_start()
	_def.request_intent(S1, SurvivorDefense.fire_packet())
	_def.request_intent(S1, SurvivorDefense.fire_packet())
	_step(1)
	assert_int(_def.charges(S1)).is_equal(1)


func test_charges_persist_through_down_and_rescue_and_are_lost_on_elimination() -> void:
	_start()
	_fire(S1)
	var done := _seize(S1)
	_step(done - _now())
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)
	assert_int(_def.charges(S1)).is_equal(1)
	_d.stand_up(S1)
	assert_int(_def.charges(S1)).override_failure_message("kept through rescue").is_equal(1)
	_fire(S1)
	assert_int(_def.charges(S1)).override_failure_message("usable after rescue").is_equal(0)
	var el := EvSurvivorEliminated.new()
	el.survivor = S2
	_server.bus.emit(el)
	_server.bus.flush()
	assert_int(_def.charges(S2)).override_failure_message("lost on elimination").is_equal(0)
	_fire(S2)
	assert_int(_def.charges(S2)).is_equal(0)


# AC-3 -------------------------------------------------------------------------------------------

func test_seized_downed_hidden_and_monster_cannot_fire() -> void:
	_start()
	var done := _seize(S1)
	_fire(S1)
	assert_int(_def.charges(S1)).override_failure_message("Seized").is_equal(2)
	_step(done - 1 - _now())
	_fire(S1) # validated on the completion tick, before Downing's slot downs them
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)
	assert_int(_def.charges(S1)).override_failure_message("tick of the down").is_equal(2)
	_fire(S1)
	assert_int(_def.charges(S1)).override_failure_message("Downed").is_equal(2)
	_def.set_hidden(S2, true)
	_fire(S2)
	assert_int(_def.charges(S2)).override_failure_message("hidden").is_equal(2)
	_def.set_hidden(S2, false)
	_fire(S2)
	assert_int(_def.charges(S2)).override_failure_message("unhidden fires").is_equal(1)
	_fire(MONSTER)
	assert_int(_def.charges(MONSTER)).override_failure_message("the monster has no items").is_equal(0)
	_def.request_intent(99, SurvivorDefense.fire_packet())
	_step(1)
	assert_int(_def.charges(99)).is_equal(0)


func test_view_publishes_charges_and_hidden_read_only() -> void:
	_start()
	var v := _server.registry.view(StateKeys.HIDDEN_ITEM_USE, SurvivorDefense.DefenseView) \
		as SurvivorDefense.DefenseView
	_fire(S3)
	_def.set_hidden(S4, true)
	assert_int(v.charges(S3)).is_equal(1)
	assert_bool(v.is_hidden(S4)).is_true()
	assert_bool(v.is_hidden(S3)).is_false()


# AC-4 -------------------------------------------------------------------------------------------

func test_forged_messages_change_nothing() -> void:
	_start()
	_fire(S2) # S2 starts inside its reuse window
	var done := _seize(S1) # and S1 is held in a running takedown commit
	var before := _state()
	var forged: Array[PackedByteArray] = [
		var_to_bytes({"stun_hit": MONSTER}),
		var_to_bytes({"charges": 9}),
		var_to_bytes({"charges": {S2: 9}}),
		var_to_bytes({"barricade_complete": 7}),
		var_to_bytes({SurvivorDefense.INTENT_KEY: SurvivorDefense.FIRE, "charges": 9}),
		var_to_bytes({SurvivorDefense.INTENT_KEY: 99}),
		var_to_bytes({SurvivorDefense.INTENT_KEY: "fire"}),
		PackedByteArray([0xFF, 0x00, 0x13]),
		PackedByteArray(),
	]
	var big := PackedByteArray()
	big.resize(SurvivorDefense.REQUEST_CAP_BYTES + 1)
	forged.append(big)
	for p: int in [S3, S4, MONSTER]:
		for b in forged:
			_def.request_intent(p, b)
			_step(1)
	assert_array(_state()).is_equal(before)
	assert_bool(_now() < done).override_failure_message("still inside the commit").is_true()


## Emits each scheduled event in its own tick slot (stands in for Monster Abilities).
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
