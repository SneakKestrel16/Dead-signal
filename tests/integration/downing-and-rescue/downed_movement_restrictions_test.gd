# Story downing-and-rescue/005: Downed crawl and action restrictions (design/gdd/downing-and-rescue.md
# rules 4.2, 6 and 7, Formulas "Crawl speed"; first-person-controller.md rule 6 and gait order).
# Downing writes its "downing" modifier into each player's MovementModifiers (the ServerMovement set,
# here a Dictionary) and publishes action_locked on the TAKEDOWN_ELIGIBILITY view. The physics tests
# run the controller's MovementStep from the round's movement phase, reading the life state through
# the registry as the Controller does.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const SURVIVORS: Array[int] = [2, 3, 4, 5]
const SPEED_TOL := 0.05 ## controller AC: ±0.05 m/s
const FLOOR_SIZE := 200.0
const SETTLE_TICKS := 5

var _knobs: Knobs
var _server: RoundServer
var _d: Downing
var _abilities: Emitter
var _mods: Dictionary[int, MovementModifiers]
var _commit_ticks: int


func _start(knobs: Knobs = Knobs.load_all()) -> void:
	_knobs = knobs
	_commit_ticks = knobs.ticks(knobs.downing.takedown_commit_s)
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_d = Downing.new()
	_d.set_roster(SURVIVORS, MONSTER)
	_mods = {}
	for p: int in SURVIVORS + [MONSTER]:
		_mods[p] = MovementModifiers.new()
	_d.set_modifiers(_mod_of)
	_abilities = Emitter.new()
	var errs := _server.start_round({TickOrder.MONSTER_ABILITIES: _abilities, TickOrder.DOWNING: _d}, knobs)
	assert_array(errs).is_empty()


func after_test() -> void:
	if _server != null:
		_server.end_round()
	_mover = null
	if _saved_hz > 0:
		Engine.physics_ticks_per_second = _saved_hz
		_saved_hz = 0


func _mod_of(p: int) -> MovementModifiers:
	return _mods.get(p)


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


func _now() -> int:
	return _server.tick_runner.current_tick()


func _life() -> Downing.LifeView:
	return _server.registry.view(StateKeys.TAKEDOWN_ELIGIBILITY, Downing.LifeView) as Downing.LifeView


## Lands a hit on `survivor` next tick: Seized and Committing from then on.
func _hit(survivor: int) -> void:
	var hit := EvSurvivorHit.new()
	hit.survivor = survivor
	_abilities.at(_now() + 1, hit)
	_step(1)


func _stun() -> void:
	var e := EvMonsterStunned.new()
	e.monster = MONSTER
	_server.bus.emit(e)
	_server.bus.flush()
	_step(1)


func _down(survivor: int) -> void:
	_hit(survivor)
	_step(_commit_ticks)
	assert_int(_d.life_state(survivor)).is_equal(Downing.LifeState.DOWNED)


func _free(p: int) -> bool:
	var m := _mods[p]
	return not m.rooted and not m.locked and is_equal_approx(m.effective_scale(), 1.0)


# AC-2: commit roots ---------------------------------------------------------------------------

func test_commit_locks_victim_and_roots_monster_and_locks_their_actions() -> void:
	_start()
	_hit(S1)
	assert_bool(_mods[S1].locked).override_failure_message("Seized victim is locked").is_true()
	assert_bool(_mods[MONSTER].rooted).override_failure_message("Committing monster is rooted").is_true()
	assert_bool(_mods[MONSTER].locked).is_false()
	assert_bool(_free(S2)).is_true()
	assert_bool(_life().action_locked(S1)).is_true()
	assert_bool(_life().action_locked(MONSTER)).override_failure_message(
		"no ability, transform or interact while Committing").is_true()
	assert_bool(_life().action_locked(S2)).is_false()


func test_completed_commit_frees_monster_and_leaves_downed_victim_unrooted() -> void:
	_start()
	_down(S1)
	assert_bool(_free(MONSTER)).is_true()
	assert_bool(_life().action_locked(MONSTER)).is_false()
	assert_bool(_free(S1)).override_failure_message("crawl is the gait, not a Downing modifier").is_true()
	assert_bool(_life().action_locked(S1)).override_failure_message(
		"Downed: no objectives, barricade, hide or items").is_true()


func test_stun_cancel_removes_both_commit_modifiers() -> void:
	_start()
	_hit(S1)
	_stun()
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.HEALTHY)
	assert_bool(_free(S1)).is_true()
	assert_bool(_free(MONSTER)).is_true()
	assert_bool(_life().action_locked(S1)).is_false()
	assert_bool(_life().action_locked(MONSTER)).is_false()


func test_downing_removes_only_its_own_modifier() -> void:
	_start()
	_mods[MONSTER].add(&"taser_slow", MovementModifiers.Kind.SLOW, 0.5)
	_hit(S1)
	_stun()
	assert_bool(_mods[MONSTER].rooted).is_false()
	assert_float(_mods[MONSTER].speed_scale).is_equal(0.5)


# AC-3: rescue root ----------------------------------------------------------------------------

func test_rescue_hold_roots_downed_survivor_until_it_stops() -> void:
	_start()
	_down(S1)
	_d.set_rescuing(S1, true)
	assert_bool(_mods[S1].rooted).override_failure_message("rooted on the same tick the hold starts").is_true()
	_step(3)
	assert_bool(_mods[S1].rooted).is_true()
	_d.set_rescuing(S1, false)
	assert_bool(_free(S1)).is_true()


func test_bleed_out_during_rescue_removes_root() -> void:
	_start()
	_down(S1)
	_d.set_rescuing(S1, true)
	_d.set_rescuing(S1, false)
	_step(_knobs.ticks(_knobs.downing.bleedout_s))
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.ELIMINATED)
	assert_bool(_free(S1)).is_true()


func test_no_modifier_source_is_harmless() -> void:
	_start()
	_d.set_modifiers(Callable())
	_hit(S1)
	_step(_commit_ticks)
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)


# AC-1, AC-4: crawl through the real movement step, speed from DowningKnobs -----------------------

## Body on a floor driven by the round's movement phase: MoveState.downed from the registry view,
## modifiers from Downing. Returns the body; the frame is the caller's to fill.
func _body_with_movement(frame: InputFrame) -> PlayerBody:
	_saved_hz = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	var world: Node3D = auto_free(Node3D.new())
	add_child(world)
	TestMoveStep.add_box(world, Vector3(0, -0.5, 0), Vector3(FLOOR_SIZE, 1.0, FLOOR_SIZE))
	var body := PlayerBody.new()
	body.setup(_knobs, PhysicsLayers.MOVE_SERVER)
	world.add_child(body)
	body.global_position = Vector3.ZERO
	_mover = Mover.new(body, S1, frame, _life(), _mods[S1], _knobs)
	_server.tick_runner.movement_stage = _mover.move
	return body


var _saved_hz: int = 0
var _mover: Mover


func _hspeed(b: CharacterBody3D) -> float:
	return Vector2(b.velocity.x, b.velocity.z).length()


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _crawl_speed_with(knobs: Knobs) -> float:
	_start(knobs)
	var f := InputFrame.new()
	var b := _body_with_movement(f)
	await _physics(SETTLE_TICKS)
	_down(S1)
	f.move = Vector2(0, 1)
	f.sprint = true
	await _physics(knobs.net.sim_tick_hz)
	return _hspeed(b)


func test_downed_survivor_crawls_at_crawl_speed_even_with_sprint_held() -> void:
	var k := Knobs.load_all()
	var v := await _crawl_speed_with(k)
	var want := k.controller.walk_speed * k.downing.crawl_speed_mult
	assert_float(want).override_failure_message("defaults: 1 m/s").is_equal_approx(1.0, 1e-6)
	assert_float(v).is_equal_approx(want, SPEED_TOL)


func test_crawl_speed_follows_the_knob() -> void:
	var k := Knobs.load_all()
	k.downing.crawl_speed_mult = 0.4
	var v := await _crawl_speed_with(k)
	assert_float(v).is_equal_approx(k.controller.walk_speed * 0.4, SPEED_TOL)


func test_rescued_downed_survivor_does_not_move() -> void:
	_start()
	var f := InputFrame.new()
	var b := _body_with_movement(f)
	await _physics(SETTLE_TICKS)
	_down(S1)
	_d.set_rescuing(S1, true)
	f.move = Vector2(0, 1)
	var at := b.global_position
	await _physics(_knobs.net.sim_tick_hz)
	assert_float(_hspeed(b)).is_equal(0.0)
	assert_float(Vector2(b.global_position.x - at.x, b.global_position.z - at.z).length()).is_less(0.01)


## Stands in for the composer's server step: the Controller reads the life state from the registry.
class Mover extends RefCounted:
	var _body: PlayerBody
	var _player: int
	var _frame: InputFrame
	var _life: Downing.LifeView
	var _state := MovementStep.MoveState.new()
	var _knobs: Knobs

	func _init(body: PlayerBody, player: int, frame: InputFrame, life: Downing.LifeView, mods: MovementModifiers, knobs: Knobs) -> void:
		_body = body
		_player = player
		_frame = frame
		_life = life
		_state.modifiers = mods
		_knobs = knobs

	func move(_tick: int) -> void:
		_state.downed = _life.life_state(_player) == Downing.LifeState.DOWNED
		MovementStep.step(_body, _frame, _state, _knobs)


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
