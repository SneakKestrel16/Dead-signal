# Story monster-abilities/009 AC-6: a fake sound's wire payload is the real one's (design/gdd/monster-abilities.md
# rule 15; ADR-0004 §5-6: AbilityUsed is never sent, sounds carry position and set only; ADR-0013 §2).
# The real MonsterAbilities runs in a RoundServer and sends through a stand-in for ServerMovement.emit_sound
# (same EventBatch.Sound fields, no source). Each viewer's EventBatch.build/decode of the fake tick (with
# that tick's delivered AbilityUsed) is compared with the batch of the real sound at the same point: the
# install noise SurvivorObjectives sends, and a survivor's walk footstep at the walk radius.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const PLAYERS: Array[int] = [1, 2, 3, 4]
const SEED := 9009
const INSTALL_RADIUS := 25.0
const STEP_S := 0.5
const BYTES_TICK := 1000
const AIM := Vector3(6.0, 0.0, 0.0)

var _server: RoundServer
var _ma: MonsterAbilities
var _knobs: Knobs
var _handles: HandleTable
var _sounds: Array[EventBatch.Sound] = []
var _events: Array[ServerEvent] = []
## Viewer positions: on the point, inside both radii, inside only the install radius, outside both.
var _viewer_pos: Dictionary[int, Vector3] = {}


func before_test() -> void:
	_knobs = Knobs.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_handles = HandleTable.new(rng)
	for v in PLAYERS:
		for b in PLAYERS:
			if b != v:
				_handles.handle_for(v, b)
	var walk_r := _knobs.controller.footstep_radius_walk_m
	_viewer_pos = {1: AIM, 2: AIM + Vector3(0.0, 0.0, walk_r - 1.0), 3: AIM + Vector3(0.0, 0.0, walk_r + 1.0),
		4: AIM + Vector3(0.0, 0.0, INSTALL_RADIUS + 1.0)}
	_sounds = []
	_events = []
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_ma = MonsterAbilities.new()
	_ma.set_monster(MONSTER)
	var radius: Dictionary[StringName, float] = {SurvivorObjectives.INSTALL_SOUND: INSTALL_RADIUS}
	_ma.set_false_signal_sources(_emit_sound, _snap, _observed, Callable(), _footstep_set_of, radius, STEP_S)
	assert_array(_server.start_round({TickOrder.MONSTER_ABILITIES: _ma}, _knobs)).is_empty()
	_server.bus.subscribe(&"AbilityUsed", _on_event)


func after_test() -> void:
	_server.end_round()
	_ma = null


## Stand-in for ServerMovement.emit_sound with no source (every listener in range hears it).
func _emit_sound(pos: Vector3, sound_set: StringName, radius: float) -> void:
	_sounds.append(_sound(pos, sound_set, radius))


func _sound(pos: Vector3, sound_set: StringName, radius: float) -> EventBatch.Sound:
	var s := EventBatch.Sound.new()
	s.position = pos
	s.sound_set = sound_set
	s.radius_m = radius
	return s


func _snap(p: Vector3) -> Variant:
	return Vector3(p.x, 0.0, p.z)


func _observed(_s: int) -> bool:
	return true


func _footstep_set_of(s: int) -> StringName:
	return StringName("c%d.walk" % s)


func _on_event(e: ServerEvent) -> void:
	_events.append(e)


func _batch(viewer: int, events: Array[ServerEvent], sounds: Array[EventBatch.Sound]) -> Dictionary:
	var bytes := EventBatch.build(BYTES_TICK, viewer, events, sounds, _viewer_pos[viewer], _handles, MONSTER)
	return EventBatch.decode(bytes) if not bytes.is_empty() else {}


## Runs one False Signal tick; returns its sounds and AbilityUsed for the per-viewer comparison.
func _fake(packet: PackedByteArray) -> void:
	_ma.request_ability(MONSTER, packet)
	_server.tick_runner.step()
	assert_int(_ma.falsesignals_used()).is_equal(1)
	assert_int(_events.size()).is_equal(1)


func _assert_same_per_viewer(real: Array[EventBatch.Sound]) -> void:
	var reached := 0
	for v in PLAYERS:
		var fake_b := _batch(v, _events, _sounds)
		var real_b := _batch(v, [] as Array[ServerEvent], real)
		assert_dict(fake_b).override_failure_message("viewer %d: %s vs %s" % [v, fake_b, real_b]).is_equal(real_b)
		reached += 0 if fake_b.is_empty() else 1
	assert_int(reached).override_failure_message("someone hears it, someone does not").is_between(1, PLAYERS.size() - 1)


func test_fake_install_noise_matches_real() -> void:
	_fake(MonsterAbilities.signal_packet(MonsterAbilities.SignalType.INTERACTION, AIM, -1, Vector3.ZERO,
		SurvivorObjectives.INSTALL_SOUND))
	var real: Array[EventBatch.Sound] = [_sound(AIM, SurvivorObjectives.INSTALL_SOUND, INSTALL_RADIUS)]
	_assert_same_per_viewer(real)


func test_fake_footstep_matches_real() -> void:
	_fake(MonsterAbilities.signal_packet(MonsterAbilities.SignalType.FOOTSTEPS, AIM, S1, Vector3.RIGHT))
	var real: Array[EventBatch.Sound] = [_sound(AIM, _footstep_set_of(S1),
		_knobs.controller.footstep_radius_walk_m)]
	_assert_same_per_viewer(real)
