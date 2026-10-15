# Story lobby-role-assignment/012: the logic behind the lobby's queue order and preference picker
# (lobby-role-assignment.md rules 11, 12, AC-LB-19, AC-LB-20; TR-lobby-005, -006). The server sends the
# rotation queue (player IDs and names, absent players included, never tokens) and the first present
# player as the next shapeshifter; a client's preference request is one of five fixed packets, matched
# byte for byte and refused while Ready. The look is in production/qa/evidence/lobby-queue-order/.
extends GdUnitTestSuite

const A := "tok-a"
const B := "tok-b"
const C := "tok-c"

var _knobs: Knobs
var _lobby: LobbyState
var _ids: Dictionary[String, int] = {A: 0, B: 3, C: 4}
var _names: Dictionary[int, String] = {0: "Ann", 3: "Bob", 4: "Cy"}


func before_test() -> void:
	_knobs = Knobs.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1212
	_lobby = LobbyState.new(_knobs, rng)
	_lobby.host_token = A
	for t in [A, B, C]:
		_lobby.join(t)


func _id_of(token: String) -> int:
	return _ids.get(token, -1)


func _name_of(id: int) -> String:
	return _names.get(id, "")


func _decode(queue: PackedStringArray) -> Dictionary:
	return LobbySync.decode(LobbySync.encode(_lobby, 0, _id_of, _name_of, queue))


func test_absent_head_is_listed_and_next_is_first_present() -> void:
	_lobby.leave(B)
	var s := _decode(PackedStringArray([B, C, A]))
	assert_array(s.queue).is_equal([{"id": 3, "name": "Bob"}, {"id": 4, "name": "Cy"}, {"id": 0, "name": "Ann"}])
	assert_int(s.next).is_equal(4)


func test_present_head_is_next() -> void:
	assert_int(_decode(PackedStringArray([A, B, C])).next).is_equal(0)


func test_no_queue_before_the_first_round() -> void:
	var s := _decode(PackedStringArray())
	assert_array(s.queue).is_empty()
	assert_int(s.next).is_equal(-1)


func test_queue_never_carries_tokens() -> void:
	_lobby.leave(B)
	var wire := var_to_str(bytes_to_var(LobbySync.encode(_lobby, 0, _id_of, _name_of, PackedStringArray([B, C, A]))))
	assert_bool(wire.contains("Bob")).is_true()
	for token in [A, B, C]:
		assert_bool(wire.contains(token)).is_false()


func test_long_queue_is_cut_to_the_cap_and_still_decodes() -> void:
	var q := PackedStringArray([A, B, C])
	for i in LobbySync.MAX_QUEUE:
		q.append("gone-%d" % i)
	var s := _decode(q)
	assert_int(s.queue.size()).is_equal(LobbySync.MAX_QUEUE)


func test_decode_rejects_bad_queue() -> void:
	var good: Dictionary = bytes_to_var(LobbySync.encode(_lobby, 0, _id_of, _name_of, PackedStringArray([A, B])))
	assert_dict(LobbySync.decode(var_to_bytes(good))).is_not_empty() # control
	var bad_id := good.duplicate(true)
	bad_id.queue[0].id = "0"
	assert_dict(LobbySync.decode(var_to_bytes(bad_id))).is_empty()
	var extra_key := good.duplicate(true)
	extra_key.queue[0]["token"] = A
	assert_dict(LobbySync.decode(var_to_bytes(extra_key))).is_empty()
	var bad_next := good.duplicate(true)
	bad_next.next = 1.5
	assert_dict(LobbySync.decode(var_to_bytes(bad_next))).is_empty()
	var too_long := good.duplicate(true)
	for i in LobbySync.MAX_QUEUE:
		too_long.queue.append(good.queue[0])
	assert_dict(LobbySync.decode(var_to_bytes(too_long))).is_empty()


func test_preference_request_matches_exact_packets_only() -> void:
	for cid in CharacterDef.IDS:
		assert_str(String(LobbySync.preference_request(LobbySync.preference_packet(cid)))).is_equal(String(cid))
	assert_str(String(LobbySync.preference_request(var_to_bytes({"lobby_pref": "C9"})))).is_empty()
	assert_str(String(LobbySync.preference_request(LobbySync.ready_packet(true)))).is_empty()
	var longer: PackedByteArray = LobbySync.preference_packet(&"C2").duplicate()
	longer.append(0)
	assert_str(String(LobbySync.preference_request(longer))).is_empty()
	assert_int(LobbySync.ready_request(LobbySync.preference_packet(&"C2"))).is_equal(-1)


func test_preference_applies_only_while_not_ready() -> void:
	var other: StringName = &"C1" if _lobby.preference(B) != &"C1" else &"C2"
	LobbySync.apply_request(_lobby, B, LobbySync.preference_packet(other))
	assert_str(String(_lobby.preference(B))).is_equal(String(other))
	LobbySync.apply_request(_lobby, B, LobbySync.ready_packet(true))
	assert_bool(_lobby.is_ready(B)).is_true()
	var third: StringName = &"C3" if other != &"C3" else &"C4"
	LobbySync.apply_request(_lobby, B, LobbySync.preference_packet(third))
	assert_str(String(_lobby.preference(B))).is_equal(String(other))
	LobbySync.apply_request(_lobby, B, LobbySync.ready_packet(false))
	LobbySync.apply_request(_lobby, B, LobbySync.preference_packet(third))
	assert_str(String(_lobby.preference(B))).is_equal(String(third))


func test_queue_text_marks_absent_head_and_names_next() -> void:
	_lobby.leave(B)
	var text := LobbyScreen.queue_text(_decode(PackedStringArray([B, C, A])), 0)
	var lines := text.split("\n")
	assert_int(lines.size()).is_equal(4)
	assert_str(lines[1]).is_equal("1. Bob (away)")
	assert_str(lines[2]).is_equal("2. Cy  <- next shapeshifter")
	assert_str(lines[3]).is_equal("3. Ann (you)")


func test_queue_text_before_first_round_says_not_drawn() -> void:
	assert_str(LobbyScreen.queue_text(_decode(PackedStringArray()), 0)) \
			.is_equal("Shapeshifter queue: drawn when the first round starts")
