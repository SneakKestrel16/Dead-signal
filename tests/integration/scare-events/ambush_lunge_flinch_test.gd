# Story scare-events/005: the ambush lunge scare and the flinch near a lunge (scare-events.md rules 5a, 13,
# 14; ADR-0015). A composed round: a Lunge wind-up sends ambush_lunge to the survivors within
# lunge_cue_radius_m who have not seen the monster's chest for ambush_unseen_s or when the monster stands in a
# blacked-out volume; a Major scare flinches a toggled-on player through ViewOffset, never one near a lunge in
# wind-up or Active; over real ENet a stun fired and movement made during the flinch ramp both work and the
# view is back under the player's control within scare_max_control_loss_s.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const SESSION := "s-se5"
## Far from every map door, so no door leaf crosses the scripted sight lines (round_composer_test's spot).
const BASE := Vector3(300.0, 0.0, 300.0)
## Outside lunge_cue_radius_m of BASE.
const FAR := Vector3(0.0, 0.0, 60.0)

static var _next_port := 28150

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


## Runs queued Callable(tick) in a tick after the Holds step (and so after Monster Abilities).
class ActStep extends RefCounted:
	var queue: Array[Callable] = []

	func setup(_runner: TickRunner, _bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		pass

	func server_tick(tick: int) -> void:
		var q := queue
		queue = []
		for c in q:
			c.call(tick)


var _knobs: Knobs
var _server: RoundServer
var _c: RoundComposer
var _roots: Array[Node] = []
var _clients: Array[NetAuthority] = []
var _net: NetAuthority
var _act: ActStep
## [scare_id, recipient] of every ScareTriggered.
var _scares: Array = []
## player -> ViewOffsetChanged records that start a flinch (a non-zero target with a ramp).
var _flinches: Dictionary[int, Array] = {}
var _stunned := false


func before_test() -> void:
	_knobs = Knobs.load_all()
	_clients = []
	_scares = []
	_flinches = {}
	_stunned = false


func after_test() -> void:
	if _c != null:
		_c.stop()
		_c = null
	await get_tree().process_frame
	_server = null
	for r in _roots:
		for n in r.get_children():
			if n is NetAuthority:
				n.close()
		var api := r.multiplayer as SceneMultiplayer
		if api.multiplayer_peer != null:
			api.multiplayer_peer.close()
		api.multiplayer_peer = null
		get_tree().set_multiplayer(null, r.get_path())
		r.free()
	_roots.clear()


func _root() -> Node:
	var n := Node3D.new()
	n.name = "Se%d" % _roots.size()
	get_tree().root.add_child(n)
	get_tree().set_multiplayer(SceneMultiplayer.new(), n.get_path())
	_roots.append(n)
	return n


func _poll() -> void:
	for r in _roots:
		(r.multiplayer as SceneMultiplayer).poll()


func _info(token: String) -> Dictionary:
	var pid := token.trim_prefix("t").to_int()
	return {"player_id": pid, "name": "P%d" % pid}


func _no_look(_id: int) -> int:
	return 0


func _all_joined() -> bool:
	for c in _clients:
		if c.local_player_id == -1:
			return false
	return true


## Hosts on a fresh port and joins `clients` real ENet clients.
func _rig(clients: int) -> void:
	_net = NetAuthority.new()
	_net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	_root().add_child(_net)
	_next_port += 1
	assert_int(_net.host(_next_port)).is_equal(OK)
	for i in clients:
		var root := _root()
		var c := NetAuthority.new()
		c.setup(_knobs, SERVER_VERSION, FakeLobby.new())
		root.add_child(c)
		root.add_child(HiddenSpawner.new())
		assert_int(c.join("127.0.0.1", _next_port, "P%d" % i)).is_equal(OK)
		_clients.append(c)
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end and not _all_joined():
		_poll()
		await get_tree().process_frame
	assert_bool(_all_joined()).override_failure_message("clients never joined").is_true()


## A composed, Running round (joined clients, or 5 made-up ids and no network), every player frozen.
func _compose() -> void:
	if _roots.is_empty():
		_net = NetAuthority.new()
		_net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
		_root().add_child(_net)
	var tokens := PackedStringArray()
	for c in _clients:
		tokens.append("t%d" % c.local_player_id)
	if tokens.is_empty():
		tokens = PackedStringArray(["t1", "t2", "t3", "t4", "t5"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 10
	var roster := Roster.lock(tokens, _info, SESSION, 1, _knobs, RotationQueue.new(), rng)
	var server_root := _roots[0]
	_c = RoundComposer.new(_knobs, roster, MapData.load_map(), _net, server_root.multiplayer as SceneMultiplayer,
			server_root as Node3D, TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _no_look)
	_server = auto_free(RoundServer.new())
	add_child(_server)
	assert_array(_c.start(_server, rng)).is_empty()
	_server.tick_runner.set_physics_process(false)
	_act = ActStep.new()
	_server.tick_runner.register_feature(FeatureStep.new(_act, _server.bus), TickOrder.HOLDS + 1)
	_server.bus.subscribe(&"ScareTriggered", _on_scare)
	_server.bus.subscribe(&"ViewOffsetChanged", _on_offset)
	_server.bus.subscribe(&"MonsterStunned", _on_stunned)
	for id in roster.player_ids():
		_c.lifecycle.report_loaded(id)
	for i in _knobs.ticks(1.0):
		if _c.lifecycle.state() == RoundLifecycle.State.RUNNING:
			break
		_step(1)
	assert_int(_c.lifecycle.state()).is_equal(RoundLifecycle.State.RUNNING)
	for id in roster.player_ids():
		_place(id, BASE + FAR * 2.0 + Vector3(5.0 * id, 0.0, 0.0))


func _on_scare(e: ServerEvent) -> void:
	var s := e as EvScareTriggered
	_scares.append([s.scare_id, s.recipient])


func _on_offset(e: ServerEvent) -> void:
	var o := e as EvViewOffsetChanged
	if o.record.ramp_ticks > 0 and o.record.target != Vector2.ZERO:
		if not _flinches.has(o.player):
			_flinches[o.player] = []
		_flinches[o.player].append(o.record)


func _on_stunned(_e: ServerEvent) -> void:
	_stunned = true


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()
		_poll()


func _place(id: int, at: Vector3) -> void:
	_c.sm.set_frozen(id, true)
	_c.bodies[id].global_position = at


func _wall(at: Vector3) -> void:
	TestMoveStep.add_box(_roots[0], at, Vector3(0.5, 4.0, 6.0))


func _ambushed() -> Array[int]:
	var out: Array[int] = []
	for s: Array in _scares:
		if s[0] == AmbushTest.SCARE_ID:
			out.append(s[1])
	return out


func _lunge() -> void:
	_c.ma.request_ability(_c.monster, MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))
	_step(1)
	assert_int(_c.ma.lunge_state()).is_equal(MonsterAbilities.Lunge.WIND_UP)
	_step(1)


func _fire(_tick: int, id: StringName, origin: Vector3, to: Array, source: int) -> void:
	_c.scares.fire(id, origin, to, source, _c.monster if source == ScareEntry.Source.MONSTER else -1)


## AC-1: lit volume. Unseen for ambush_unseen_s passes; seen within it (in sight now, or hidden for less than
## ambush_unseen_s) does not; a survivor beyond lunge_cue_radius_m gets nothing either way.
func test_wind_up_ambushes_only_survivors_who_have_not_seen_the_monster() -> void:
	_compose()
	var s := _c.survivors
	var unseen := _knobs.ticks(_knobs.scare.ambush_unseen_s)
	_place(_c.monster, BASE)
	_place(s[0], BASE + Vector3(0.0, 0.0, -5.0)) # in sight throughout
	_place(s[1], BASE + Vector3(-5.0, 0.0, 0.0)) # in sight, hidden later
	_place(s[2], BASE + Vector3(-5.0, 0.0, 1.0)) # in sight, hidden later still
	_place(s[3], BASE + FAR) # out of range, never seen
	_wall(BASE + Vector3(2.5, 1.5, 0.0))
	await get_tree().physics_frame
	_step(5)
	_place(s[1], BASE + Vector3(5.0, 0.0, -1.0)) # behind the wall
	_step(5)
	_place(s[2], BASE + Vector3(5.0, 0.0, 1.0))
	_step(unseen - 3) # s[1] unseen for unseen + 2 at the wind-up tick, s[2] for unseen - 3
	_lunge()
	assert_array(_ambushed()).is_equal([s[1]])


## AC-1: a seen survivor near a monster in a blacked-out volume is ambushed.
func test_wind_up_in_a_blacked_out_volume_ambushes_a_seen_survivor() -> void:
	_compose()
	var v: MapVolume = _c.map.volumes[0]
	var at := Vector3(v.box.get_center().x, 0.0, v.box.get_center().z)
	_place(_c.monster, at)
	_place(_c.survivors[0], at + Vector3(0.0, 0.0, -3.0))
	_step(3)
	var dark := EvAbilityUsed.new()
	dark.ability = MonsterAbilities.Ability.BLACKOUT
	dark.target = at
	_server.bus.emit(dark)
	_step(2)
	assert_bool(_c.lighting.is_dark(v.id)).is_true()
	_lunge()
	assert_array(_ambushed()).is_equal([_c.survivors[0]])


## AC-2, AC-3: Major scares flinch a toggled-on player through ViewOffset, except within lunge_cue_radius_m of
## a lunge in wind-up or Active (the ambush scare included); after the lunge the same player flinches again.
## Minor scares and toggled-off players never flinch.
func test_major_scare_flinches_except_near_a_wind_up_or_active_lunge() -> void:
	_compose()
	var near := _c.survivors[0]
	var far := _c.survivors[1]
	var off := _c.survivors[2]
	_place(_c.monster, BASE)
	_place(near, BASE + Vector3(5.0, 0.0, 0.0)) # in range, outside the lunge cone (the monster faces -Z)
	_wall(BASE + Vector3(2.5, 1.5, 0.0)) # near never sees the monster: the ambush scare reaches it
	_place(far, BASE + FAR)
	_place(off, BASE + FAR + Vector3(3.0, 0.0, 0.0))
	await get_tree().physics_frame
	for id in [near, far]:
		_c.offset.set_flinch_enabled(id, true)
	_c.offset.set_flinch_enabled(off, false)
	_step(_knobs.ticks(_knobs.scare.ambush_unseen_s) + 1)
	var side := BASE + Vector3(20.0, 1.5, 20.0)
	_act.queue.append(_fire.bind(&"slammed_door", side, [far], ScareEntry.Source.ROUND_SCRIPT))
	_step(1)
	assert_bool(_flinches.has(far)).override_failure_message("a Minor scare flinched").is_false()
	_c.ma.request_ability(_c.monster, MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))
	_act.queue.append(_fire.bind(&"door_burst", side, [near, far, off], ScareEntry.Source.MONSTER))
	_step(2)
	assert_int(_c.ma.lunge_state()).is_equal(MonsterAbilities.Lunge.WIND_UP)
	assert_array(_ambushed()).contains([near])
	assert_bool(_flinches.has(near)).override_failure_message("flinch in wind-up").is_false()
	assert_bool(_flinches.has(off)).override_failure_message("toggled-off flinch").is_false()
	assert_int(_flinches.get(far, []).size()).is_equal(1)
	var fired_active := [false]
	for i in _knobs.ticks(_knobs.ability.lunge_windup_s) + 2:
		if _c.ma.lunge_state() == MonsterAbilities.Lunge.ACTIVE:
			_act.queue.append(_fire.bind(&"door_burst", side, [near], ScareEntry.Source.MONSTER))
			_step(1)
			fired_active[0] = true
			break
		_step(1)
	assert_bool(fired_active[0]).override_failure_message("lunge never Active").is_true()
	assert_bool(_flinches.has(near)).override_failure_message("flinch in Active").is_false()
	var free := false
	for i in _knobs.ticks(_knobs.ability.lunge_dash_s) + _knobs.ticks(1.0):
		var st := _c.ma.lunge_state()
		if st != MonsterAbilities.Lunge.WIND_UP and st != MonsterAbilities.Lunge.ACTIVE:
			free = true
			break
		_step(1)
	assert_bool(free).is_true()
	# The ambush and the suppressed bursts reached `near` as Major (no flinch, rule 14), so gating (story 002,
	# rule 9) would reduce a burst inside major_scare_cooldown_s to Minor: let the cooldown run out first.
	_step(_knobs.ticks(_knobs.scare.major_scare_cooldown_s) + 1)
	_act.queue.append(_fire.bind(&"door_burst", side, [near], ScareEntry.Source.MONSTER))
	_step(2)
	assert_int(_flinches.get(near, []).size()).is_equal(1)


## AC-3 over real ENet: the flinch turns the view toward the origin within scare_max_control_loss_s (the
## measured look loss), and a taser fired by the flinched client and movement input during the ramp work.
func test_flinch_ramp_loses_at_most_the_bound_and_keeps_move_and_stun() -> void:
	await _rig(5)
	_compose()
	var shooter := _c.survivors[0]
	var mover := _c.survivors[1]
	_place(_c.monster, BASE)
	_place(shooter, BASE + Vector3(0.0, 0.0, 3.0)) # behind the monster, facing it along -Z
	_place(mover, BASE + FAR)
	_step(ceili(_knobs.ability.max_rewind_ms * _knobs.net.sim_tick_hz / 1000.0) + 2)
	_c.sm.set_frozen(mover, false)
	for id in [shooter, mover]:
		_net.set_flinch_enabled(id, true)
	var origin := BASE + Vector3(0.2, 1.6, 0.0)
	_act.queue.append(_fire.bind(&"door_burst", origin, [shooter, mover], ScareEntry.Source.MONSTER))
	_step(1)
	assert_int(_flinches.get(shooter, []).size()).is_equal(1)
	var rec: FlinchRecord = _flinches[shooter][0]
	var client := -1
	for i in _clients.size():
		if _clients[i].local_player_id == shooter:
			client = i
	(_roots[client + 1].multiplayer as SceneMultiplayer).send_bytes(SurvivorDefense.fire_packet(), 1,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	var start := _c.bodies[mover].global_position
	var loss := 0
	var moved_every_tick := true
	for i in _knobs.ticks(1.0):
		if _c.offset.offset_of(shooter).is_equal_approx(rec.target):
			break
		var f := InputFrame.new()
		f.seq = i + 1
		f.move = Vector2(0.0, 1.0)
		_c.sm.push_local(mover, f)
		var before := _c.bodies[mover].global_position
		_step(1)
		await get_tree().process_frame
		var now := _c.bodies[mover].global_position
		moved_every_tick = moved_every_tick and Vector2(now.x - before.x, now.z - before.z).length() > 0.0
		loss += 1
	assert_float(loss / float(_knobs.net.sim_tick_hz)).is_less_equal(_knobs.scare.scare_max_control_loss_s)
	assert_bool(moved_every_tick).override_failure_message("movement lost during the flinch").is_true()
	assert_float(Vector2(_c.bodies[mover].global_position.x - start.x,
			_c.bodies[mover].global_position.z - start.z).length()).is_greater(0.0)
	for i in _knobs.ticks(1.0) + _knobs.ticks(_knobs.defense.stun_use_delay_s):
		if _stunned:
			break
		_step(1)
		await get_tree().process_frame
	assert_bool(_stunned).override_failure_message("taser fired during the flinch did not stun").is_true()
