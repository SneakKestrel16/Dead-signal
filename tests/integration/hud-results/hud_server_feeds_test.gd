# Story hud-results/011 (design/ux/hud.md H3, H4, H8, H9; ADR-0004 §5): over real ENet, five rendering
# RoundClients join a round composed from a roster locked with the lobby's own name source
# (RosterHandoff.info_from(net)). AC1: every survivor client's HudModel and H4 rows carry the join names, the
# shapeshifter client gets none. AC2: the server's activation countdown entry reaches every survivor's HudModel,
# running and then Paused. AC3: at a hiding spot, a second survivor's Start is refused on the held lock and its
# H9 label reads "In use"; the holder moved out of range is cancelled and reads "Moved away". Test seams: the
# activation source is swapped on WorldProgress and a spy stands in front of HoldReasonFeed.note.
extends GdUnitTestSuite

const WAIT_S := 8.0
## Ports 30820-30839 belong to this story's runs.
const PORT := 30821
const NAMES: Array[String] = ["Ana", "Ben", "Cy", "Dee", "Eve"]
## The knob's maximum (defense knobs range 0.5-2.0): the first hold must still run through the refusal and
## the cancel, so the test reacts to the server's reports, not to client labels, in between.
const HIDE_S := 2.0

var _knobs: Knobs
var _roots: Array[Node] = []
var _clients: Array[RoundClient] = []
var _c: RoundComposer
var _activation := {}
var _ends: Array = [] ## [actor, reason] HoldService reported (spy in front of HoldReasonFeed.note)
var _labels: Dictionary = {} ## client name -> every H9 label text seen


class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_knobs.defense.hide_transition_s = HIDE_S
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	_clients = []
	_activation = {}
	_ends = []
	_labels = {}


func after_test() -> void:
	if _c != null:
		_c.stop()
		_c = null
	for c in _clients:
		c.close()
	await get_tree().process_frame
	for r in _roots + _clients:
		if not is_instance_valid(r):
			continue
		var api := r.multiplayer as SceneMultiplayer
		if api != null and api.multiplayer_peer != null:
			api.multiplayer_peer.close()
			api.multiplayer_peer = null
		get_tree().set_multiplayer(null, r.get_path())
		r.free()
	_roots.clear()
	_clients.clear()


func _look(id: int) -> int:
	return 1 + id % 5


func _until(cond: Callable, what: String) -> void:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end and not cond.call():
		await get_tree().physics_frame
		_note_labels()
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()


func _joined() -> bool:
	return _clients.all(func(c: RoundClient) -> bool: return c.is_ready())


func _spawned() -> bool:
	return _clients.all(func(c: RoundClient) -> bool: return c.is_spawned())


func _client(id: int) -> RoundClient:
	for c in _clients:
		if c.net.local_player_id == id:
			return c
	return null


func _survivor_clients() -> Array[RoundClient]:
	var out: Array[RoundClient] = []
	for c in _clients:
		if c.net.local_player_id != _c.monster:
			out.append(c)
	return out


func _note_labels() -> void:
	for c in _clients:
		if c.interaction != null and c.interaction.label_text() != "":
			var seen: Array = _labels.get_or_add(c.name, [])
			if not seen.has(c.interaction.label_text()):
				seen.append(c.interaction.label_text())


func _saw(c: RoundClient, text: String) -> bool:
	return _labels.get(c.name, []).has(text)


func _spy_end(actor: int, reason: StringName) -> void:
	_ends.append([actor, reason])
	_c.hold_reasons.note(actor, reason)


## WorldProgress's activation source, swapped in: reaching Activating takes the whole objective chain.
func _fake_activation() -> Dictionary:
	return _activation


func _compose() -> void:
	var server_root := Node3D.new()
	server_root.name = "Host"
	get_tree().root.add_child(server_root)
	_roots.append(server_root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), server_root.get_path())
	var map := MapData.load_map()
	MapGreybox.build(server_root, map)
	var net := NetAuthority.new()
	net.setup(_knobs, _knobs.join_version(RoundClient.VERSION_BUILD), FakeLobby.new())
	server_root.add_child(net)
	assert_int(net.host(PORT)).is_equal(OK)
	for i in NAMES.size():
		var c := RoundClient.new(_knobs, TestMoveStep.apply, TestMoveStep.make_body, map, true)
		c.name = "C%d" % i
		get_tree().root.add_child(c)
		_clients.append(c)
		assert_int(c.join("127.0.0.1", PORT, NAMES[i])).is_equal(OK)
		c.scripted = InputFrame.new()
	await _until(_joined, "5 joined")
	var tokens := PackedStringArray()
	for c in _clients:
		tokens.append(c.net.local_token)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var roster := Roster.lock(tokens, RosterHandoff.info_from(net), "s-hud11", 1, _knobs, RotationQueue.new(), rng)
	assert_object(roster).is_not_null()
	_c = RoundComposer.new(_knobs, roster, map, net, server_root.multiplayer as SceneMultiplayer, server_root,
			TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _look)
	var server := RoundServer.new()
	server_root.add_child(server)
	assert_array(_c.start(server, rng)).is_empty()
	_c.world_progress._activation = _fake_activation
	_c.holds.on_end = _spy_end
	await _until(_spawned, "every own body spawned")


func _named_all() -> bool:
	return _survivor_clients().all(func(c: RoundClient) -> bool:
		return _c.survivors.all(func(s: int) -> bool: return c.hud_model.name_of(s) != ""))


func _paused_seen(paused: bool) -> bool:
	return _survivor_clients().all(func(c: RoundClient) -> bool:
		var a := c.hud_model.activation()
		return not a.is_empty() and a["paused"] == paused)


## A stand point `d` m from the hiding spot's point whose eye ray picks map interactable `idx`, around the spot
## from `start` (radians) in eighths of a turn.
func _stand_for(idx: int, point: Vector3, d: float, start: float) -> Vector3:
	var space := (_roots[0] as Node3D).get_world_3d().direct_space_state
	var half := _knobs.controller.capsule_height_m * 0.5
	for k in 8:
		var a := start + TAU * k / 8.0
		var feet := Vector3(point.x + d * cos(a), point.y - half, point.z + d * sin(a))
		var eye := feet + Vector3.UP * _knobs.controller.eye_height_m
		if _c.queries.interactable_on_ray(eye, point - eye, feet + Vector3.UP * half, _c.rules, space) == idx:
			return feet
	return Vector3.INF


## Faces `c`'s scripted view from `feet` at `point` (ViewState.direction's yaw/pitch convention).
func _aim(c: RoundClient, feet: Vector3, point: Vector3) -> void:
	var dir := (point - (feet + Vector3.UP * _knobs.controller.eye_height_m)).normalized()
	c.scripted.yaw = atan2(-dir.x, -dir.z)
	c.scripted.pitch = asin(dir.y)


func test_roster_names_activation_feed_and_hold_reasons_reach_the_clients() -> void:
	await _compose()
	# AC1: names from the lobby's own source, survivors only.
	await _until(_named_all, "every survivor client named every survivor")
	for c in _survivor_clients():
		assert_int(c.hud_model.roster().size()).is_equal(_c.survivors.size())
		for s in _c.survivors:
			assert_str(c.hud_model.name_of(s)).is_equal(_c.net.display_name_of(s))
		var hud := c.hud.get_node(^"AlwaysOnHud") as AlwaysOnHud
		hud.refresh()
		var rows: Array[String] = []
		for l in hud.roster_box.get_children():
			rows.append((l as Label).text)
		assert_str(rows[0]).override_failure_message("H4 row: %s" % [rows]) \
				.starts_with(_c.net.display_name_of(_c.survivors[0]))
	var monster := _client(_c.monster)
	assert_int(monster.hud_model.roster().size()).override_failure_message("the shapeshifter got the roster") \
			.is_equal(0)

	# AC2: the activation countdown entry, running then Paused.
	_activation = {"at": Vector3.ZERO, "ticks": 0, "held": true}
	await _until(_paused_seen.bind(false), "every survivor's countdown running")
	assert_float(_survivor_clients()[0].hud_model.activation()["remaining_s"]) \
			.is_less_equal(_knobs.objectives.evac_activation_s)
	_activation = {"at": Vector3.ZERO, "ticks": 30, "held": false}
	await _until(_paused_seen.bind(true), "every survivor's countdown Paused")
	assert_bool(monster.hud_model.activation().is_empty()).override_failure_message("the shapeshifter got it") \
			.is_true()

	# AC3: one refusal (lock held) and one cancel (out of range), each with its server reason in H9.
	var idx := -1
	var marker: MapMarker
	for i in _c.map.interactables().size():
		marker = _c.map.interactables()[i] as MapMarker
		if marker != null and marker.type == &"hiding":
			idx = i
			break
	assert_int(idx).is_not_negative()
	var point := marker.position + Vector3.UP * _c.rules.point_height_m
	var a_id := _c.survivors[0]
	var b_id := _c.survivors[1]
	var feet_a := _stand_for(idx, point, 1.2, 0.0)
	var feet_b := _stand_for(idx, point, 1.2, PI)
	assert_vector(feet_a).override_failure_message("no stand point aims at the spot").is_not_equal(Vector3.INF)
	assert_vector(feet_b).is_not_equal(Vector3.INF)
	_c.bodies[a_id].global_position = feet_a
	_c.bodies[b_id].global_position = feet_b
	var ca := _client(a_id)
	var cb := _client(b_id)
	_aim(ca, feet_a, point)
	_aim(cb, feet_b, point)
	await _until(func() -> bool: return ca.local_target(ca.scripted.yaw, ca.scripted.pitch) == idx \
			and cb.local_target(cb.scripted.yaw, cb.scripted.pitch) == idx, "both clients aim at the spot")
	ca.scripted.interact = true
	await _until(func() -> bool: return not _c.holds.hold_of(a_id).is_empty(), "the first survivor holds Hide")
	cb.scripted.interact = true
	await _until(func() -> bool: return _ends.has([b_id, &"in_use"]), "the server refuses the second Start on the lock")
	_c.bodies[a_id].global_position = feet_a + (feet_a - Vector3(point.x, feet_a.y, point.z)).normalized() * 2.5
	await _until(func() -> bool: return _ends.has([a_id, &"range"]), "the server cancels the moved holder")
	await _until(func() -> bool: return _saw(cb, "In use") and _saw(ca, "Moved away"), "both H9 reasons shown")
	assert_array(_labels.get(cb.name, [])).override_failure_message("refused client labels") \
			.contains(["In use"])
	assert_array(_labels.get(ca.name, [])).override_failure_message("cancelled client labels") \
			.contains(["Moved away"])
