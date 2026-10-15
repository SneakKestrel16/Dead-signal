# Story event-catalog-state-registry/005: ClientEventRouter (ADR-0005 §7, ADR-0004 §5-6).
# Batches are fed as the real wire bytes (EventBatch's tag + var_to_bytes([tick, entries])), by hand
# through on_packet(); no ENet: the router only reads bytes the transport already delivered.
extends GdUnitTestSuite

const EVENTS_DIR := "res://src/foundation/events/"
const SRC := "res://src/"
const SERVER := 1
const TICK := 40


## Handlers as NAMED methods (lambdas are forbidden by the manifest). All write one shared log.
class Recorder extends RefCounted:
	var name: String
	var log: Array

	func _init(n: String, shared: Array) -> void:
		name = n
		log = shared

	func on_entry(tick: int, payload: Dictionary) -> void:
		log.append([name, tick, payload.get("i")])


var _router: ClientEventRouter
var _log: Array


func before_test() -> void:
	_router = ClientEventRouter.new()
	_log = []


func _batch(tick: int, entries: Array) -> PackedByteArray:
	var out := PackedByteArray([EventBatch.TAG])
	out.append_array(var_to_bytes([tick, entries]))
	return out


func _sub(type: StringName, name: String) -> Recorder:
	var r := Recorder.new(name, _log)
	assert_bool(_router.subscribe(type, r.on_entry)).is_true()
	return r


func test_three_types_reach_their_handlers_in_batch_order() -> void:
	var a := _sub(&"RoundPhaseChanged", "phase")
	var b := _sub(&"PlayerConnectionChanged", "conn")
	var c := _sub(EventBatch.SOUND, "sound")
	var b2 := _sub(&"PlayerConnectionChanged", "conn2")
	_router.on_packet(SERVER, _batch(TICK, [
		[&"PlayerConnectionChanged", {"i": 0}],
		[&"RoundPhaseChanged", {"i": 1}],
		[EventBatch.SOUND, {"i": 2}],
		[&"RoundPhaseChanged", {"i": 3}],
	]))
	assert_array(_log).is_equal([
		["conn", TICK, 0], ["conn2", TICK, 0], ["phase", TICK, 1], ["sound", TICK, 2], ["phase", TICK, 3],
	])
	assert_int(_router.dropped).is_equal(0)
	assert_int(_router.rejected).is_equal(0)
	assert_object(a).is_not_null() # keep the recorders alive past the call
	assert_object(b).is_not_null()
	assert_object(b2).is_not_null()
	assert_object(c).is_not_null()


func test_unknown_type_is_dropped_and_logged_and_the_rest_still_arrives() -> void:
	var a := _sub(&"RoundEnded", "ended")
	_router.on_packet(SERVER, _batch(TICK, [
		[&"NotAnEvent", {"i": 0}],
		[&"RoundEnded", {"i": 1}],
		[&"NotAnEvent", {"i": 2}],
		[&"AlsoUnknown", {"i": 3}],
		[&"RoundEnded", {"i": 4}],
	]))
	assert_array(_log).is_equal([["ended", TICK, 1], ["ended", TICK, 4]])
	assert_int(_router.dropped).is_equal(3)
	assert_object(a).is_not_null()


func test_known_type_with_no_handler_is_not_a_drop() -> void:
	_router.on_packet(SERVER, _batch(TICK, [[&"SurvivorEscaped", {"i": 0}]]))
	assert_int(_router.dropped).is_equal(0)
	assert_array(_log).is_empty()


func test_subscribe_refuses_names_outside_the_catalog() -> void:
	var r := Recorder.new("x", _log)
	assert_bool(_router.subscribe(&"NotAnEvent", r.on_entry)).is_false()
	_router.on_packet(SERVER, _batch(TICK, [[&"NotAnEvent", {"i": 0}]]))
	assert_array(_log).is_empty()


func test_only_server_event_batches_are_routed() -> void:
	var a := _sub(&"RoundPhaseChanged", "phase")
	var bytes := _batch(TICK, [[&"RoundPhaseChanged", {"i": 0}]])
	_router.on_packet(2, bytes) # another client: never the server's
	_router.on_packet(SERVER, PackedByteArray([HandleTable.TAG, 1, 2])) # not ours: ignored
	_router.on_packet(SERVER, PackedByteArray([EventBatch.TAG, 0xFF, 0xFF])) # malformed batch
	assert_array(_log).is_empty()
	assert_int(_router.rejected).is_equal(1)
	_router.on_packet(SERVER, bytes)
	assert_array(_log).is_equal([["phase", TICK, 0]])
	assert_object(a).is_not_null()


func test_real_build_output_routes() -> void:
	var a := _sub(&"RoundPhaseChanged", "phase")
	var e := EvRoundPhaseChanged.new() # server side of the wire, built here only to make the bytes
	e.phase = 1
	var events: Array[ServerEvent] = [e]
	var sounds: Array[EventBatch.Sound] = []
	_router.on_packet(SERVER, EventBatch.build(TICK, 2, events, sounds, Vector3.ZERO, HandleTable.new(), 3))
	assert_int(_log.size()).is_equal(1)
	assert_int(_log[0][1]).is_equal(TICK)
	assert_object(a).is_not_null()


## The router's catalog equals the type() of every ev_*.gd script (the test may construct them; the
## router may not).
func test_catalog_matches_event_scripts() -> void:
	var types: Array[StringName] = []
	for f in DirAccess.get_files_at(EVENTS_DIR):
		if f.begins_with("ev_") and f.ends_with(".gd"):
			var s: GDScript = load(EVENTS_DIR + f)
			types.append(s.new().type())
	assert_int(types.size()).is_greater(0)
	var catalog: Array[StringName] = ClientEventRouter.CATALOG.duplicate()
	assert_int(catalog.size()).is_equal(types.size())
	for t in types:
		assert_bool(t in catalog).override_failure_message("%s missing from CATALOG" % t).is_true()


## Client scripts: every src script that consumes event batches (decodes them or holds a router).
## None constructs, loads or extends a ServerEvent.
func test_no_client_script_constructs_a_server_event() -> void:
	var consumer := RegEx.create_from_string("EventBatch\\.decode\\(|ClientEventRouter")
	var forbidden := RegEx.create_from_string(
			"\\bEv[A-Z]\\w*\\.new\\(|\\bServerEvent\\.new\\(|extends\\s+ServerEvent|events/ev_")
	var client: Array[String] = []
	var bad: Array[String] = []
	for path: String in _src_scripts():
		var code := _code_of(FileAccess.get_file_as_string(path))
		if consumer.search(code) == null:
			continue
		client.append(path)
		for m in forbidden.search_all(code):
			bad.append("%s: %s" % [path, m.get_string()])
	# Non-vacuous: the two known client consumers are in the scanned set.
	assert_bool(EVENTS_DIR + "client_event_router.gd" in client).is_true()
	assert_bool(SRC + "feature/match_flow/match_display.gd" in client).is_true()
	assert_array(bad).is_empty()


## Source with `#` comments removed (a doc line may mention a class by name).
func _code_of(text: String) -> String:
	var out := PackedStringArray()
	for line in text.split("\n"):
		out.append(line.split("#")[0])
	return "\n".join(out)


func _src_scripts() -> Array[String]:
	var out: Array[String] = []
	var dirs: Array[String] = [SRC]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir + sub + "/")
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				out.append(dir + f)
	return out
