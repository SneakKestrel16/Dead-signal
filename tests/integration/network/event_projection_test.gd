# Story network-authority/009: event projection batches and positional sounds (ADR-0004 §5-6).
# Each row of the projection table is checked through EventBatch.build, the bytes the server sends one
# viewer per tick, decoded as the client would. S1 and S2 are survivors, M the shapeshifter.
# The real-ENet survivor capture (NA-8) also decodes these batches: handles_relevance_test.
extends GdUnitTestSuite

const S1 := 1
const S2 := 2
const M := 3
const TICK := 40
const SEED := 9009

var _handles: HandleTable


func before_test() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_handles = HandleTable.new(rng)


## The decoded entries viewer `viewer` receives for `events` (and `sounds`), as [type, payload] pairs.
func _got(viewer: int, events: Array[ServerEvent], sounds: Array[EventBatch.Sound] = [],
		viewer_pos := Vector3.ZERO) -> Array:
	var bytes := EventBatch.build(TICK, viewer, events, sounds, viewer_pos, _handles, M)
	if bytes.is_empty():
		return []
	var b := EventBatch.decode(bytes)
	assert_int(b.tick).is_equal(TICK)
	return b.entries


func _one(e: ServerEvent) -> Array[ServerEvent]:
	var out: Array[ServerEvent] = [e]
	return out


# --- AC1: every row of the projection table --------------------------------------

func test_public_rows_reach_survivors_and_shapeshifter_in_full() -> void:
	var phase := EvRoundPhaseChanged.new()
	phase.phase = 2
	var ended := EvRoundEnded.new()
	ended.outcome = 1
	ended.results = {"winner": "survivors"}
	var escaped := EvSurvivorEscaped.new()
	escaped.survivor = S2
	var conn := EvPlayerConnectionChanged.new()
	conn.player = S2
	conn.status = EvPlayerConnectionChanged.DISCONNECTED
	var events: Array[ServerEvent] = [phase, ended, escaped, conn]
	var expected := [[&"RoundPhaseChanged", {"phase": 2}],
		[&"RoundEnded", {"outcome": 1, "reason": 0, "results": {"winner": "survivors"}}],
		[&"SurvivorEscaped", {"survivor": S2}],
		[&"PlayerConnectionChanged", {"player": S2, "status": EvPlayerConnectionChanged.DISCONNECTED}]]
	assert_array(_got(S1, events)).is_equal(expected)
	assert_array(_got(M, events)).is_equal(expected)


func test_life_states_reach_everyone_but_bleed_out_never_reaches_the_shapeshifter() -> void:
	var downed := EvSurvivorDowned.new()
	downed.survivor = S2
	downed.bleed_out_s = 42.5
	var rescued := EvSurvivorRescued.new()
	rescued.survivor = S2
	rescued.rescuer = S1
	var gone := EvSurvivorEliminated.new()
	gone.survivor = S2
	var events: Array[ServerEvent] = [downed, rescued, gone]
	assert_array(_got(S1, events)).is_equal([[&"SurvivorDowned", {"survivor": S2, "bleed_out_s": 42.5}],
		[&"SurvivorRescued", {"survivor": S2}], [&"SurvivorEliminated", {"survivor": S2, "reason": 0}]])
	assert_array(_got(M, events)).is_equal([[&"SurvivorDowned", {"survivor": S2}],
		[&"SurvivorRescued", {"survivor": S2}], [&"SurvivorEliminated", {"survivor": S2, "reason": 0}]])


## Code review 2026-10-14: before roles are dealt (monster -1) every viewer counted as a survivor and
## the shapeshifter's client got the bleed-out state.
func test_bleed_out_reaches_no_one_before_roles_are_dealt() -> void:
	var downed := EvSurvivorDowned.new()
	downed.survivor = S2
	downed.bleed_out_s = 10.0
	var b := EventBatch.build(TICK, M, _one(downed), [], Vector3.ZERO, _handles, -1)
	assert_array(EventBatch.decode(b).entries).is_equal([[&"SurvivorDowned", {"survivor": S2}]])


func test_survivor_hit_and_ability_used_reach_no_client() -> void:
	var hit := EvSurvivorHit.new()
	hit.survivor = S1
	var used := EvAbilityUsed.new()
	used.position = Vector3(3, 0, 4)
	var events: Array[ServerEvent] = [hit, used]
	for viewer in [S1, S2, M]:
		assert_array(_got(viewer, events)).override_failure_message("viewer %d" % viewer).is_empty()


func test_form_changed_reaches_only_the_shapeshifter_as_its_own_form() -> void:
	var e := EvFormChanged.new()
	e.player = M
	e.form = 4
	assert_array(_got(M, _one(e))).is_equal([[&"FormChanged", {"form": 4}]])
	assert_array(_got(S1, _one(e))).is_empty()


func test_monster_stunned_by_handle_only_in_true_form_and_only_if_relevant() -> void:
	var e := EvMonsterStunned.new()
	e.monster = M
	e.true_form = true
	assert_array(_got(S1, _one(e))).is_empty() # not relevant: no handle for the monster yet
	var h := _handles.handle_for(S1, M)
	assert_array(_got(S1, _one(e))).is_equal([[&"MonsterStunned", {"body": h}]])
	e.true_form = false
	assert_array(_got(S1, _one(e))).is_empty() # a disguised stun is never sent to survivors
	assert_array(_got(M, _one(e))).is_equal([[&"MonsterStunned", {"own": true}]])


func test_objective_points_undiscovered_are_omitted_for_survivors_only() -> void:
	var e := EvObjectiveProgressChanged.new()
	e.objective = 5
	e.state = 1
	assert_array(_got(S1, _one(e))).is_empty() # fails closed until the owner marks it discovered
	assert_array(_got(M, _one(e))).is_equal([[&"ObjectiveProgressChanged", {"objective": 5, "state": 1, "carrier": -1}]])
	e.discovered = true
	assert_array(_got(S1, _one(e))).is_equal([[&"ObjectiveProgressChanged", {"objective": 5, "state": 1, "carrier": -1}]])


func test_scare_reaches_its_recipient_with_no_identity() -> void:
	var e := EvScareTriggered.new()
	e.recipient = S1
	e.scope = 2
	e.scare_id = &"door_burst"
	e.origin = Vector3(1, 0, 2)
	e.source = 0
	e.player = M
	assert_array(_got(S1, _one(e))).is_equal([[&"ScareTriggered",
			{"scare": &"door_burst", "scope": 2, "origin": Vector3(1, 0, 2), "intensity": 0}]])
	assert_array(_got(S2, _one(e))).is_empty()
	assert_array(_got(M, _one(e))).is_empty()


func test_barricade_broken_is_not_sent_as_an_event() -> void:
	var e := EvBarricadeBroken.new()
	e.barricade = 7
	for viewer in [S1, M]:
		assert_array(_got(viewer, _one(e))).is_empty()


func test_flinch_and_view_offset_reach_only_their_own_player() -> void:
	var f := EvFlinchRequested.new()
	f.player = S1
	var v := EvViewOffsetChanged.new()
	v.player = S1
	v.record = FlinchRecord.new()
	v.record.target = Vector2(0.1, -0.2)
	var events: Array[ServerEvent] = [f, v]
	assert_array(_got(S1, events)).is_equal([[&"FlinchRequested", {"flinch": true}],
		[&"ViewOffsetChanged", v.record.to_dict()]])
	assert_array(_got(S2, events)).is_empty()
	assert_array(_got(M, events)).is_empty()


# --- AC2: PlayerShocked is byte-identical for every case -------------------------

func test_player_shocked_is_byte_identical_whoever_was_shocked() -> void:
	var shocked_survivor := EvPlayerShocked.new()
	shocked_survivor.player = S2
	var shocked_monster := EvPlayerShocked.new()
	shocked_monster.player = M # disguised monster tased
	var h_s2 := _handles.handle_for(S1, S2)
	var h_m := _handles.handle_for(S1, M)
	var a := EventBatch.build(TICK, S1, _one(shocked_survivor), [], Vector3.ZERO, _handles, M)
	var b := EventBatch.build(TICK, S1, _one(shocked_monster), [], Vector3.ZERO, _handles, M)
	# Only the handle differs. Handles are random per body, and var_to_bytes widens ints >= 2^31 to
	# 8 bytes, so even the size follows the random handle, never the case: swap it and the bytes match.
	assert_array(EventBatch.decode(a).entries).is_equal([[&"PlayerShocked", {"body": h_s2}]])
	assert_array(EventBatch.decode(b).entries).is_equal([[&"PlayerShocked", {"body": h_m}]])
	assert_bool(_with_handle(a, h_s2, 0) == _with_handle(b, h_m, 0)).is_true()


func test_player_shocked_reaches_no_one_the_body_is_not_relevant_to() -> void:
	var e := EvPlayerShocked.new()
	e.player = S2
	assert_array(_got(S1, _one(e))).is_empty()
	assert_array(_got(S2, _one(e))).is_equal([[&"PlayerShocked", {"own": true}]])


## `bytes` with the encoded `handle` replaced by `to` (re-encoded, so offsets are not guessed).
func _with_handle(bytes: PackedByteArray, handle: int, to: int) -> PackedByteArray:
	var b := EventBatch.decode(bytes)
	for entry: Array in b.entries:
		if entry[1].get("body") == handle:
			entry[1]["body"] = to
	var out := PackedByteArray([EventBatch.TAG])
	out.append_array(var_to_bytes([b.tick, b.entries]))
	return out


# --- AC3: positional sounds ------------------------------------------------------

func _footstep(at: Vector3, radius: float, source := -1) -> Array[EventBatch.Sound]:
	var s := EventBatch.Sound.new()
	s.position = at
	s.sound_set = &"steps_c2"
	s.radius_m = radius
	s.source = source
	var out: Array[EventBatch.Sound] = [s]
	return out


func test_footstep_one_metre_outside_its_radius_reaches_no_peer() -> void:
	var r := Knobs.load_all().controller.footstep_radius_walk_m
	var none: Array[ServerEvent] = []
	for viewer in [S1, S2, M]:
		assert_int(EventBatch.build(TICK, viewer, none, _footstep(Vector3(r + 1.0, 0, 0), r), Vector3.ZERO, _handles, M).size()) 			.override_failure_message("viewer %d" % viewer).is_equal(0)
	assert_array(_got(S1, none, _footstep(Vector3(r, 0, 0), r))).is_not_empty() # the radius itself is inside


func test_footstep_inside_its_radius_carries_position_and_set_only() -> void:
	var r := Knobs.load_all().controller.footstep_radius_walk_m
	var at := Vector3(r - 0.5, 0, 0)
	var none: Array[ServerEvent] = []
	assert_array(_got(S1, none, _footstep(at, r, M))).is_equal([[EventBatch.SOUND, {"pos": at, "set": &"steps_c2"}]])
	assert_array(_got(M, none, _footstep(at, r, M), at)).is_empty() # the emitter plays its own steps


# --- edge cases ------------------------------------------------------------------

func test_events_projecting_to_nothing_send_no_batch() -> void:
	var hit := EvSurvivorHit.new()
	assert_int(EventBatch.build(TICK, S1, _one(hit), [], Vector3.ZERO, _handles, M).size()).is_equal(0)


## Code review 2026-10-14: entries of the wrong shape reached the client router.
func test_decode_drops_entries_of_the_wrong_shape() -> void:
	var raw := PackedByteArray([EventBatch.TAG])
	raw.append_array(var_to_bytes([5, [[&"RoundPhaseChanged", {"phase": 1}], ["x"], [1, 2], [&"T", [1]]]]))
	assert_array(EventBatch.decode(raw).entries).is_equal([[&"RoundPhaseChanged", {"phase": 1}]])


func test_emit_keeps_a_tick_the_emitter_set() -> void:
	var bus := EventBus.new(8)
	bus.tick = 5
	var e := EvRoundPhaseChanged.new()
	e.tick = 3
	bus.emit(e)
	assert_int(e.tick).is_equal(3)


func test_malformed_batches_decode_to_empty() -> void:
	assert_dict(EventBatch.decode(PackedByteArray())).is_empty()
	assert_dict(EventBatch.decode(PackedByteArray([EventBatch.TAG, 1, 2]))).is_empty()
	var wrong := PackedByteArray([EventBatch.TAG])
	wrong.append_array(var_to_bytes({"tick": 1}))
	assert_dict(EventBatch.decode(wrong)).is_empty()
	assert_bool(EventBatch.is_message(HandleTable.encode(PackedInt64Array([HandleTable.INTRODUCE, 5])))).is_false()


## SR-1 deferred item: emit() stamps the running tick and server time (ADR-0005 §1).
func test_emit_stamps_the_running_tick_and_server_time() -> void:
	var knobs := Knobs.load_all()
	var runner: TickRunner = auto_free(TickRunner.new())
	runner.fail_hard = false
	runner.boot(knobs)
	var bus := EventBus.new(knobs.core.max_flush_rounds)
	runner.bus = bus
	runner.step()
	runner.step()
	var e := EvRoundPhaseChanged.new()
	bus.emit(e)
	assert_int(e.tick).is_equal(2)
	assert_float(e.server_time).is_equal_approx(2.0 / knobs.net.sim_tick_hz, 1e-9)


## Batches share the EVENT channel and peer_packet with handle messages and snapshots: the snapshot
## readers skip them by their first byte instead of counting them as bad packets.
func test_clients_snapshot_readers_skip_event_batches() -> void:
	var batch := EventBatch.build(TICK, S1, _one(EvRoundPhaseChanged.new()), [], Vector3.ZERO, _handles, M)
	var puppets := PuppetMap.new()
	puppets.receive(batch)
	assert_int(puppets.bad_packets).is_equal(0)
	var body: CharacterBody3D = auto_free(CharacterBody3D.new())
	var predictor := OwnerPredictor.new(Knobs.load_all(), body, auto_free(Node3D.new()), func(_b: Node, _f: InputFrame, _m: MovementModifiers) -> void: pass, SceneMultiplayer.new())
	predictor._on_packet(OwnerPredictor.SERVER_PEER, batch)
	assert_int(predictor.bad_snapshots).is_equal(0)
