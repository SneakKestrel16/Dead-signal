# Story data-config/005: knob digest in the join version check (ADR-0006 §7, ADR-0001 §3).
# Integration: reads the shipped knob files; the join test runs a real server and client over ENet.
extends GdUnitTestSuite

const BUILD := "0.1.0"
const WAIT_S := 5.0
## Digest of the shipped data/knobs/*.tres on 2026-10-15 (MA-7: lunge_hit_stop_s). Any change to a shipped knob value changes it:
## update this constant in the same commit (that is the point: it proves the digest is stable across
## runs, and that a value change is visible to the join check).
const SHIPPED_DIGEST := "ef3c831d99d0ab1fcb9c80688cbdf98f478366e483d9749aed1fad3957f16ccc"

static var _next_port := 25900

var _roots: Array[Node] = []


func after_test() -> void:
	await get_tree().create_timer(0.35).timeout ## reject-delay coroutines finish first
	for r in _roots:
		for c in r.get_children():
			if c is NetAuthority:
				c.close()
		var api := r.multiplayer as SceneMultiplayer
		if api.multiplayer_peer != null:
			api.multiplayer_peer.close()
		api.multiplayer_peer = null
		api.auth_callback = Callable()
		get_tree().set_multiplayer(null, r.get_path())
		r.free()
	_roots.clear()


class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


func _net(knobs: Knobs, version: String) -> NetAuthority:
	var n := Node.new()
	n.name = "Dg%d" % _roots.size()
	get_tree().root.add_child(n)
	get_tree().set_multiplayer(SceneMultiplayer.new(), n.get_path())
	_roots.append(n)
	var net := NetAuthority.new()
	net.setup(knobs, version, FakeLobby.new())
	n.add_child(net)
	return net


func test_digest_is_stable_across_loads_and_runs() -> void:
	var a := Knobs.load_all()
	var b := Knobs.load_all()
	assert_array(a.errors()).is_empty()
	assert_str(a.digest()).is_equal(b.digest())
	assert_int(a.digest().length()).is_equal(64)
	assert_str(a.digest()).override_failure_message(
		"shipped digest changed: if a knob in data/knobs/ was changed on purpose, re-pin SHIPPED_DIGEST to %s" % a.digest()
		).is_equal(SHIPPED_DIGEST) ## across runs: the value checked in above


func test_join_version_is_build_plus_first_8_hex() -> void:
	var k := Knobs.load_all()
	var v := k.join_version(BUILD)
	assert_str(v).is_equal(BUILD + "+" + k.digest().left(8))
	assert_bool(RegEx.create_from_string("^0\\.1\\.0\\+[0-9a-f]{8}$").search(v) != null).is_true()


func test_one_changed_knob_changes_the_digest() -> void:
	var k := Knobs.load_all()
	var before := k.digest()
	k.controller.walk_speed += 0.01
	assert_str(k.digest()).is_not_equal(before)
	k.controller.walk_speed -= 0.01
	assert_str(k.digest()).is_equal(before)


func test_a_property_that_is_not_a_saved_field_does_not_change_the_digest() -> void:
	var k := Knobs.load_all()
	var before := k.digest()
	k.controller.resource_name = "renamed" ## a Resource property, not a script variable
	k.loaded_paths.append("res://elsewhere.tres") ## Knobs bookkeeping, not a section field
	assert_str(k.digest()).is_equal(before)


## 1.0 and 1.00 in a .tres parse to the same double, so only values can differ; -0.0 is the one equal
## value with different bytes.
func test_negative_zero_and_zero_give_the_same_digest() -> void:
	var a := Knobs.load_all()
	var b := Knobs.load_all()
	var zero := 0.0
	a.ability.lunge_windup_turn_deg_s = zero
	b.ability.lunge_windup_turn_deg_s = -1.0 * zero ## a real -0.0: the literal -0.0 folds to +0.0
	assert_str(a.digest()).is_equal(b.digest())


func test_array_knob_element_change_changes_the_digest() -> void:
	var k := Knobs.load_all()
	var before := k.digest()
	k.scare.phase_budget = PackedInt32Array([2, 4, 6]) ## same elements, reordered
	assert_str(k.digest()).is_not_equal(before)


func test_client_with_one_changed_knob_is_rejected_with_both_versions() -> void:
	var host_knobs := Knobs.load_all()
	var client_knobs := Knobs.load_all()
	client_knobs.ability.lunge_windup_s = 0.65
	var host_version := host_knobs.join_version(BUILD)
	var client_version := client_knobs.join_version(BUILD)
	assert_str(client_version).is_not_equal(host_version)
	_next_port += 1
	var server := _net(host_knobs, host_version)
	assert_int(server.host(_next_port)).is_equal(OK)
	var client := _net(client_knobs, client_version)
	var rejects: Array = []
	client.join_rejected.connect(func(r: StringName) -> void: rejects.append(r))
	assert_int(client.join("127.0.0.1", _next_port, "Ann")).is_equal(OK)
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while rejects.is_empty() and Time.get_ticks_msec() < end:
		await get_tree().process_frame
	assert_array(rejects).is_equal([NetAuthority.REASON_VERSION_MISMATCH])
	assert_str(client.last_reject_details.server_version).is_equal(host_version)
	assert_str(client.last_reject_details.client_version).is_equal(client_version)
