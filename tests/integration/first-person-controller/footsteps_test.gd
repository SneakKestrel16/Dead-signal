# Story controller-interaction/014: footstep events from gait and disguise (first-person-controller.md
# rule 8, Formulas footstep_radius, Acceptance Criteria Footsteps; ADR-0013 §2, ADR-0004 §6, ADR-0010 §2).
# Integration: the real Footsteps module feeds Sounds that the real EventBatch projects per listener.
# The manual 18 m through-a-wall trial (AC 4) is a designer playtest item, not automated here.
extends GdUnitTestSuite

const SOURCE := 1
const LISTENER := 2
const MONSTER := 5
const TARGET := 3
## Listener distances from the AC; each pair straddles one radius.
const DISTANCES: Array[float] = [1.9, 2.1, 5.9, 6.1, 19.9, 20.1]

var _knobs: Knobs
var _steps: Footsteps
var _sounds: Array[EventBatch.Sound] = []
var _gaits: Dictionary[int, MovementStep.Gait] = {}
var _appearances: Dictionary[int, int] = {}
var _bodies: Dictionary[int, CharacterBody3D] = {}


func before_test() -> void:
	_knobs = Knobs.load_all()
	_sounds = []
	_gaits = {}
	_appearances = {}
	_bodies = {}
	_steps = Footsteps.new(_gait_of, _appearance_of, _emit)
	_steps.setup(null, null, null, _knobs)


func after_test() -> void:
	for b in _bodies.values():
		b.free()


func _gait_of(player: int) -> MovementStep.Gait:
	return _gaits.get(player, MovementStep.Gait.WALK)


func _appearance_of(player: int) -> int:
	return _appearances.get(player, player)


func _emit(position: Vector3, sound_set: StringName, radius_m: float, source: int) -> void:
	var s := EventBatch.Sound.new()
	s.position = position
	s.sound_set = sound_set
	s.radius_m = radius_m
	s.source = source
	_sounds.append(s)


func _body(player: int, at: Vector3, velocity: Vector3) -> CharacterBody3D:
	var b := CharacterBody3D.new()
	add_child(b)
	b.global_position = at
	b.velocity = velocity
	_bodies[player] = b
	_steps.add_player(player, b)
	return b


## Runs `ticks` server ticks and returns the sounds emitted by `source` during them.
func _run(ticks: int, source: int) -> Array[EventBatch.Sound]:
	_sounds = []
	for t in ticks:
		_steps.server_tick(t)
	return _sounds.filter(func(s: EventBatch.Sound) -> bool: return s.source == source)


## Sound sets in the batch `viewer` at `viewer_pos` would receive for `sounds`.
func _heard(viewer: int, viewer_pos: Vector3, sounds: Array[EventBatch.Sound]) -> Array:
	var none: Array[ServerEvent] = []
	var bytes := EventBatch.build(1, viewer, none, sounds, viewer_pos, HandleTable.new(), MONSTER)
	if bytes.is_empty():
		return []
	var out := []
	for e: Array in EventBatch.decode(bytes).entries:
		if e[0] == EventBatch.SOUND:
			out.append(e[1].set)
	return out


func _radius(g: MovementStep.Gait) -> float:
	var c := _knobs.controller
	match g:
		MovementStep.Gait.SPRINT:
			return c.footstep_radius_sprint_m
		MovementStep.Gait.CROUCH:
			return c.footstep_radius_crouch_m
		MovementStep.Gait.CRAWL:
			return c.footstep_radius_crawl_m
	return c.footstep_radius_walk_m


## One second of movement at `speed` m/s along +X.
func _second() -> int:
	return _knobs.net.sim_tick_hz


func test_listener_hears_footsteps_only_inside_the_gaits_radius_in_every_form() -> void:
	var expected := {MovementStep.Gait.CROUCH: 2.0, MovementStep.Gait.CRAWL: 2.0,
		MovementStep.Gait.WALK: 6.0, MovementStep.Gait.SPRINT: 20.0}
	_body(SOURCE, Vector3.ZERO, Vector3(_knobs.controller.walk_speed, 0, 0))
	for appearance: int in [CharacterDef.TRUE_FORM_APPEARANCE_ID, TARGET]:
		_appearances[SOURCE] = appearance
		for g: MovementStep.Gait in expected:
			_gaits[SOURCE] = g
			var steps := _run(_second(), SOURCE)
			assert_array(steps).override_failure_message("no step: gait %d" % g).is_not_empty()
			var one: Array[EventBatch.Sound] = [steps[0]]
			for d in DISTANCES:
				var at: Vector3 = steps[0].position + Vector3(0, 0, d)
				assert_int(_heard(LISTENER, at, one).size()) \
					.override_failure_message("gait %d appearance %d at %.1f m" % [g, appearance, d]) \
					.is_equal(1 if d <= expected[g] else 0)
			assert_float(steps[0].radius_m).is_equal(_radius(g))


func test_steps_follow_distance_moved_at_one_per_spacing() -> void:
	var v := _knobs.controller.walk_speed
	_body(SOURCE, Vector3.ZERO, Vector3(0, -9.0, v)) ## a fall adds no steps: only horizontal speed counts
	var steps := _run(_second(), SOURCE)
	assert_int(steps.size()).is_equal(floori(v / _knobs.controller.footstep_spacing_m))


func test_stationary_player_emits_no_footsteps_over_five_seconds_beside_other_steps() -> void:
	_body(SOURCE, Vector3.ZERO, Vector3.ZERO)
	# A body moving elsewhere keeps footstep sounds flowing through the same queue, as False Signal's
	# fakes would (monster-abilities story 009 is not merged; inference: its fakes use this emit path).
	_body(MONSTER, Vector3(15, 0, 0), Vector3(_knobs.controller.walk_speed, 0, 0))
	for g: MovementStep.Gait in [MovementStep.Gait.WALK, MovementStep.Gait.SPRINT]:
		_gaits[SOURCE] = g
		assert_array(_run(5 * _second(), SOURCE)).is_empty()
	assert_array(_sounds).is_not_empty()


func test_disguised_walking_monster_sounds_like_its_target_to_remote_clients() -> void:
	_appearances[MONSTER] = TARGET ## BorrowedFace.appearance_of: the copied survivor's appearance
	_body(MONSTER, Vector3.ZERO, Vector3(_knobs.controller.walk_speed, 0, 0))
	_body(TARGET, Vector3(0, 0, 50), Vector3(_knobs.controller.walk_speed, 0, 0))
	var monster := _run(_second(), MONSTER)
	var target := _sounds.filter(func(s: EventBatch.Sound) -> bool: return s.source == TARGET)
	var near_monster: Vector3 = monster[0].position + Vector3(0, 0, 1)
	var near_target: Vector3 = target[0].position + Vector3(0, 0, 1)
	var m_one: Array[EventBatch.Sound] = [monster[0]]
	var t_one: Array[EventBatch.Sound] = [target[0]]
	assert_array(_heard(LISTENER, near_monster, m_one)).is_equal([&"c3.walk"])
	assert_array(_heard(LISTENER, near_monster, m_one)).is_equal(_heard(LISTENER, near_target, t_one))
	assert_array(_heard(MONSTER, near_monster, m_one)).is_empty() ## the emitter plays its own steps
	_appearances[MONSTER] = CharacterDef.TRUE_FORM_APPEARANCE_ID
	var true_form := _run(_second(), MONSTER)
	var tf_one: Array[EventBatch.Sound] = [true_form[0]]
	assert_array(_heard(LISTENER, true_form[0].position, tf_one)).is_equal([&"c0.walk"])
