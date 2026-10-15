# Story monster-abilities/006: the real Lunge drives the real Downing (design/gdd/monster-abilities.md rules
# 7-9, design/gdd/downing-and-rescue.md rules 4-5; ADR-0005 tick order MonsterAbilities > Downing, events the
# only coupling; ADR-0003 hit test on rewound positions). Nothing here emits SurvivorHit: MonsterAbilities'
# hit test does. The single-server case reads positions from its own RewindHistory; the five-client case
# runs ServerMovement (its history and frames feed LagCompensation) with 5 real ENet clients on 127.0.0.1,
# client 0 behind a UdpLink at 75 ms each way (150 ms RTT), each feeding a LifeDisplay.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const SURVIVORS: Array[int] = [2, 3]
const H := 1.8
const R := 0.3
## 1 m straight ahead of a monster at the origin facing -Z: inside lunge_hit_radius_m and the cone.
const IN := Vector3(0.0, 0.0, -1.0)
const AWAY := Vector3(100.0, 0.0, 100.0)
const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const LUNGES := 20
const LINK_DELAY_S := 0.075 ## 75 ms each way = 150 ms RTT (the AC's one slow client)
const PARK_SPACING_M := 30.0

static var _next_port := 27460

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


var _knobs: Knobs
var _server: RoundServer
var _ma: MonsterAbilities
var _d: Downing
var _history: RewindHistory
var _pos: Dictionary[int, Vector3] = {}
var _hits: Array[EvSurvivorHit] = []
var _life_events: Array[ServerEvent] = []
# five-client rig
var _roots: Array[Node] = []
var _sm: ServerMovement
var _bodies: Dictionary = {}
var _clients: Array[NetAuthority] = []
var _routers: Array[ClientEventRouter] = []
var _displays: Array[LifeDisplay] = []
var _link: UdpLink
var _survivors: Array[int] = []
var _monster := -1
var _disputes: Array[String] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_hits = []
	_life_events = []
	_pos = {MONSTER: Vector3.ZERO, S1: IN, S2: AWAY}
	_bodies = {}
	_clients = []
	_routers = []
	_displays = []
	_survivors = []
	_monster = -1
	_disputes = []
	_link = null


func after_test() -> void:
	if _sm != null:
		_sm.detach()
		_sm = null
	for r in _routers:
		r.close()
	if _server != null:
		_server.end_round()
		_server = null
	if _link != null:
		_link.stop()
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
	_ma = null
	_d = null


func _forward(_p: int) -> Vector3:
	return Vector3.FORWARD


func _on_hit(e: ServerEvent) -> void:
	_hits.append(e as EvSurvivorHit)


func _on_life_event(e: ServerEvent) -> void:
	_life_events.append(e)


func _subscribe() -> void:
	_server.bus.subscribe(&"SurvivorHit", _on_hit)
	for type: StringName in [&"SurvivorDowned", &"SurvivorEliminated"]:
		_server.bus.subscribe(type, _on_life_event)


func _now() -> int:
	return _server.tick_runner.current_tick()


## Ticks the rewind can reach back (frames here report no view tick, so it clamps to the cap) plus slack.
func _settle_ticks() -> int:
	return ceili(_knobs.ability.max_rewind_ms * _knobs.net.sim_tick_hz / 1000.0) + 2


# --- single server: one real chain -----------------------------------------------

func _push(tick: int) -> void:
	for p: int in _pos:
		_history.push(tick, p, _pos[p], H, R, _pos[p] + Vector3(0.0, H - R, 0.0))


func _no_view(_p: int) -> InputFrame:
	return InputFrame.new()


func _single() -> void:
	_history = RewindHistory.new(_knobs.net.history_ticks)
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_d = Downing.new()
	_d.set_roster(SURVIVORS, MONSTER)
	_ma = MonsterAbilities.new()
	_ma.set_monster(MONSTER)
	_ma.set_hit_sources(LagCompensation.new(_knobs, _history, _no_view), SURVIVORS, _d.eligible, _forward)
	assert_array(_server.start_round({TickOrder.MONSTER_ABILITIES: _ma, TickOrder.DOWNING: _d}, _knobs)).is_empty()
	_server.tick_runner.history_stage = _push
	_subscribe()
	_step(_settle_ticks())


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()
		if _roots.size() > 0:
			_poll()


## Requests a lunge every tick until accepted, then steps until it leaves wind-up, Active and commit.
func _lunge() -> void:
	var limit := _knobs.ticks(_knobs.ability.lunge_cooldown_s) + 2
	while limit > 0 and _ma.lunge_state() != MonsterAbilities.Lunge.WIND_UP:
		_ma.request_ability(_monster_id(), MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))
		_step(1)
		limit -= 1
	assert_int(_ma.lunge_state()).override_failure_message("lunge never accepted").is_equal(MonsterAbilities.Lunge.WIND_UP)
	for i in _knobs.ticks(_knobs.ability.lunge_windup_s) + _knobs.ticks(_knobs.ability.lunge_dash_s) \
			+ _knobs.ticks(_knobs.downing.takedown_commit_s) + 2:
		if _ma.lunge_state() == MonsterAbilities.Lunge.COOLDOWN:
			return
		_step(1)
	assert_int(_ma.lunge_state()).override_failure_message("lunge never resolved").is_equal(MonsterAbilities.Lunge.COOLDOWN)


func _monster_id() -> int:
	return _monster if _monster != -1 else MONSTER


## Rescues Downed `s` (as RescueHold.on_complete would) and waits out the post-rescue grace.
func _rescue(s: int, rescuer: int) -> void:
	_d.rescue_completed(s, rescuer)
	_step(_knobs.ticks(_knobs.downing.post_rescue_grace_s) + 1)


## AC-2: a real lunge hit runs Downing's commit to SurvivorDowned; the second down is SurvivorEliminated.
func test_real_lunge_hit_downs_and_a_second_down_eliminates() -> void:
	_single()
	_lunge()
	assert_int(_hits.size()).is_equal(1)
	assert_int(_hits[0].survivor).is_equal(S1)
	assert_int(_life_events.size()).is_equal(1)
	assert_str(_life_events[0].type()).is_equal("SurvivorDowned")
	assert_int((_life_events[0] as EvSurvivorDowned).survivor).is_equal(S1)
	assert_int(_life_events[0].tick).is_equal(_hits[0].tick + _knobs.ticks(_knobs.downing.takedown_commit_s))
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)
	assert_int(_ma.ready_tick(MonsterAbilities.Ability.LUNGE)).is_equal(_life_events[0].tick + _knobs.ticks(_knobs.ability.lunge_cooldown_s))
	_rescue(S1, S2)
	_lunge()
	assert_int(_hits.size()).is_equal(2)
	assert_int(_life_events.size()).is_equal(2)
	assert_str(_life_events[1].type()).is_equal("SurvivorEliminated")
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.ELIMINATED)
	assert_int(_d.downs_taken(S1)).is_equal(_knobs.downing.downs_to_eliminate)


## AC-2: a Downed survivor in the cone is not eligible: the real lunge misses and Downing is untouched.
func test_real_lunge_on_a_downed_survivor_misses() -> void:
	_single()
	_lunge()
	_lunge()
	assert_int(_hits.size()).is_equal(1)
	assert_int(_life_events.size()).is_equal(1)
	assert_int(_d.downs_taken(S1)).is_equal(1)


# --- five clients: 20 lunges ------------------------------------------------------

func _root() -> Node:
	var n := Node.new()
	n.name = "Le%d" % _roots.size()
	get_tree().root.add_child(n)
	get_tree().set_multiplayer(SceneMultiplayer.new(), n.get_path())
	_roots.append(n)
	return n


func _poll() -> void:
	if _link != null:
		_link.pump(Time.get_ticks_msec() / 1000.0)
	for r in _roots:
		(r.multiplayer as SceneMultiplayer).poll()


func _until(cond: Callable, what: String) -> void:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end:
		_poll()
		if cond.call():
			return
		await get_tree().process_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()


func _on_joined(pid: int) -> void:
	_bodies[pid] = TestMoveStep.make_body(_roots[0], Vector3(PARK_SPACING_M * (_bodies.size() + 1), 0.0, 0.0))
	_sm.add_player(pid, _bodies[pid])
	_sm.set_frozen(pid, true)


func _all_joined() -> bool:
	if _bodies.size() < 5:
		return false
	for c in _clients:
		if c.local_player_id == -1:
			return false
	return true


## ServerMovement's frame, or an empty one before the player's first input (no view tick: rewind clamps).
func _frame_of(p: int) -> InputFrame:
	var f := _sm.frame_of(p)
	return f if f != null else InputFrame.new()


func _rig() -> void:
	var server_root := _root()
	var net := NetAuthority.new()
	net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	server_root.add_child(net)
	_next_port += 2
	assert_int(net.host(_next_port)).is_equal(OK)
	_sm = ServerMovement.new(_knobs, net, server_root.multiplayer as SceneMultiplayer, TestMoveStep.apply, TestMoveStep.WORLD)
	net.player_joined.connect(_on_joined)
	_link = UdpLink.new(4600)
	_link.delay_s = LINK_DELAY_S
	assert_int(_link.start(_next_port + 1, _next_port)).is_equal(OK)
	for i in 5:
		var root := _root()
		var c := NetAuthority.new()
		c.setup(_knobs, SERVER_VERSION, FakeLobby.new())
		root.add_child(c)
		assert_int(c.join("127.0.0.1", _next_port + 1 if i == 0 else _next_port, "P%d" % i)).is_equal(OK)
		_clients.append(c)
		var router := ClientEventRouter.new(root.multiplayer as SceneMultiplayer)
		_routers.append(router)
		_displays.append(LifeDisplay.new(router))
	await _until(_all_joined, "5 clients joined")
	for i in 4:
		_survivors.append(_clients[i].local_player_id)
	_monster = _clients[4].local_player_id
	_d = Downing.new()
	_d.set_roster(_survivors, _monster)
	_ma = MonsterAbilities.new()
	_ma.set_monster(_monster)
	_ma.set_hit_sources(LagCompensation.new(_knobs, _sm.history, _frame_of), _survivors, _d.eligible, _forward)
	_server = auto_free(RoundServer.new())
	add_child(_server)
	assert_array(_server.start_round({TickOrder.MONSTER_ABILITIES: _ma, TickOrder.DOWNING: _d}, _knobs)).is_empty()
	_server.tick_runner.set_physics_process(false) # the test steps every tick itself
	_sm.monster = _monster
	_sm.batch_extras.append(_d.ring_entries)
	_sm.attach(_server.tick_runner)
	_subscribe()
	(_bodies[_monster] as Node3D).global_position = Vector3.ZERO


## Server truth as a client roster shows it (Seized is body presentation, not a roster state).
func _shown(s: int) -> int:
	var st := _d.life_state(s)
	return Downing.LifeState.HEALTHY if st == Downing.LifeState.SEIZED else st


func _converged() -> bool:
	for disp in _displays:
		for s in _survivors:
			if disp.life_state(s) != _shown(s) or disp.downs_taken(s) != _d.downs_taken(s):
				return false
	return true


## Sum of downs `disp` shows: a client sees a hit as the down it ends in.
func _downs_shown(disp: LifeDisplay) -> int:
	var n := 0
	for s in _survivors:
		n += disp.downs_taken(s)
	return n


## Waits for convergence (bounded), then logs every client that disagrees with the server on lunge `n`.
func _record(n: int, hit: bool, before: Array[int]) -> void:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end and not _converged():
		_poll()
		await get_tree().process_frame
	for i in _displays.size():
		var disp := _displays[i]
		var seen_hit := _downs_shown(disp) > before[i]
		if seen_hit != hit:
			_disputes.append("lunge %d client %d: shows %s, server %s" % [n, i, "hit" if seen_hit else "miss", "hit" if hit else "miss"])
		for s in _survivors:
			if disp.life_state(s) != _shown(s) or disp.downs_taken(s) != _d.downs_taken(s):
				_disputes.append("lunge %d client %d survivor %d: shows %d/%d, server %d/%d" % [n, i, s,
						disp.life_state(s), disp.downs_taken(s), _shown(s), _d.downs_taken(s)])


## AC-3: 20 real lunges, even ones at a survivor in the cone, odd ones at nobody; every client agrees with the
## server on every hit/miss and life state. A Downed target is rescued first; an Eliminated one is a miss.
func test_five_clients_agree_on_every_lunge() -> void:
	await _rig()
	var hits := 0
	for n in LUNGES:
		var target := _survivors[(n / 2) % _survivors.size()]
		if n % 2 == 0 and _d.life_state(target) == Downing.LifeState.DOWNED:
			_rescue(target, _survivors[(n / 2 + 1) % _survivors.size()])
		for k in _survivors.size():
			var s := _survivors[k]
			var aimed := n % 2 == 0 and s == target
			(_bodies[s] as Node3D).global_position = IN if aimed else Vector3(PARK_SPACING_M * (k + 1), 0.0, 0.0)
		_step(_settle_ticks())
		var before: Array[int] = []
		for disp in _displays:
			before.append(_downs_shown(disp))
		var hits_before := _hits.size()
		_lunge()
		var hit := _hits.size() > hits_before
		if hit:
			hits += 1
		await _record(n, hit, before)
	for d in _disputes:
		print("dispute: ", d)
	assert_int(hits).override_failure_message("no hit: nothing was compared").is_greater(0)
	assert_int(hits).override_failure_message("no miss: nothing was compared").is_less(LUNGES)
	assert_array(_disputes).override_failure_message("\n".join(_disputes)).is_empty()
	for disp in _displays:
		assert_int(disp.rejected).is_equal(0)
