# Story data-config/004: refuse to host on bad knobs; knobs frozen per round (ADR-0006 §4-5).
# Integration: a real NetAuthority on 127.0.0.1, a real RoundServer, and a copy of the shipped knob files
# in user:// for the reload case.
extends GdUnitTestSuite

const VERSION := "test-1.0+aaaa1111"
const COPY_DIR := "user://dc4_knobs/"
## Every src/ assignment to a knob field: `knobs.x.y = `, `_knobs.x.y += `, ... (not `==`).
const KNOB_WRITE := "(^|[^\\w])_?knobs\\.[\\w.]+\\s*([-+*/]?=)(?!=)"

static var _next_port := 25700

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0

## A module that records the Knobs it was given (TickOrder slot interface).
class RecordingModule extends RefCounted:
	var knobs: Knobs

	func setup(_runner: TickRunner, _bus: EventBus, _registry: StateRegistry, k: Knobs) -> void:
		knobs = k

	func server_tick(_tick: int) -> void:
		pass

var _nets: Array[NetAuthority] = []


func after_test() -> void:
	for n in _nets:
		n.close()
	_nets.clear()
	var d := DirAccess.open(COPY_DIR)
	if d != null:
		for f in d.get_files():
			d.remove(f)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(COPY_DIR))


func _port() -> int:
	_next_port += 1
	return _next_port


func _net(knobs: Knobs) -> NetAuthority:
	var net: NetAuthority = auto_free(NetAuthority.new())
	net.setup(knobs, VERSION, FakeLobby.new())
	net.fail_hard = false
	add_child(net)
	_nets.append(net)
	return net


## Hosting with `knobs` must be refused, list every error, and leave the port unbound.
func _assert_refused(knobs: Knobs, expect_in_errors: String) -> void:
	var net := _net(knobs)
	var refused: Array[PackedStringArray] = []
	net.host_refused.connect(func(e: PackedStringArray) -> void: refused.append(e))
	var port := _port()
	assert_int(net.host(port)).is_equal(ERR_INVALID_DATA)
	assert_int(refused.size()).is_equal(1)
	assert_str(" | ".join(refused[0])).contains(expect_in_errors)
	assert_array(refused[0]).is_equal(knobs.errors()) ## the whole list, not the first error
	# create_server was never called: the port is still free for another server.
	var probe := ENetMultiplayerPeer.new()
	assert_int(probe.create_server(port, 1)).is_equal(OK)
	probe.close()


# --- AC1 ----------------------------------------------------------------------

func test_out_of_range_value_refuses_to_host_naming_the_field() -> void:
	var k := Knobs.load_all()
	k.controller.walk_speed = 9.0 ## range 3.7-4.5
	await _assert_refused(k, "walk_speed")


func test_missing_value_refuses_to_host_naming_the_field() -> void:
	var k := Knobs.load_all()
	k.net.port = KnobUnset.INT
	await _assert_refused(k, "port")


func test_broken_cross_knob_rule_refuses_to_host_naming_the_rule() -> void:
	var k := Knobs.load_all()
	k.net.starvation_low = k.net.starvation_high
	await _assert_refused(k, "net.starvation_low")


func test_all_errors_are_listed_not_only_the_first() -> void:
	var k := Knobs.load_all()
	k.controller.walk_speed = 9.0
	k.net.port = KnobUnset.INT
	var net := _net(k)
	var refused: Array[PackedStringArray] = []
	net.host_refused.connect(func(e: PackedStringArray) -> void: refused.append(e))
	net.host(_port())
	var all := " | ".join(refused[0])
	assert_str(all).contains("walk_speed").contains("port")


func test_valid_knobs_host_normally() -> void:
	var net := _net(Knobs.load_all())
	var refused: Array[PackedStringArray] = []
	net.host_refused.connect(func(e: PackedStringArray) -> void: refused.append(e))
	assert_int(net.host(_port())).is_equal(OK)
	assert_array(refused).is_empty()


# --- AC2 ----------------------------------------------------------------------

func _copy_shipped_knobs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(COPY_DIR))
	for f in DirAccess.get_files_at(Knobs.KNOB_DIR):
		if f.ends_with(".tres"):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(Knobs.KNOB_DIR + f), ProjectSettings.globalize_path(COPY_DIR + f))


func _set_in_file(section: String, line_from: String, line_to: String) -> void:
	var path := COPY_DIR + section + ".tres"
	var text := FileAccess.get_file_as_string(path)
	assert_bool(text.contains(line_from)).override_failure_message("%s has no '%s'" % [path, line_from]).is_true()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text.replace(line_from, line_to))
	f.close()


func test_debug_reload_mid_round_changes_nothing_until_the_next_round() -> void:
	_copy_shipped_knobs()
	var store := KnobStore.new(COPY_DIR)
	assert_array(store.for_round().errors()).is_empty()
	var server: RoundServer = auto_free(RoundServer.new())
	add_child(server)
	var round_1 := RecordingModule.new()
	server.start_round({TickOrder.DOWNING: round_1}, store.for_round())
	_set_in_file("controller", "walk_speed = 4.0", "walk_speed = 4.2")
	assert_array(store.reload()).is_empty()
	assert_float(round_1.knobs.controller.walk_speed).is_equal(4.0) ## this round: unchanged
	var round_2 := RecordingModule.new()
	server.start_round({TickOrder.DOWNING: round_2}, store.for_round())
	assert_float(round_2.knobs.controller.walk_speed).is_equal(4.2) ## next round: reloaded
	assert_bool(round_1.knobs == round_2.knobs).is_false()
	server.end_round()


func test_a_broken_reload_is_refused_and_the_current_set_stays() -> void:
	_copy_shipped_knobs()
	var store := KnobStore.new(COPY_DIR)
	var before := store.for_round()
	_set_in_file("controller", "walk_speed = 4.0", "walk_speed = 9.0")
	assert_str(" ".join(store.reload())).contains("walk_speed")
	assert_object(store.for_round()).is_same(before)


# --- AC3 ----------------------------------------------------------------------

func _src_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_src_files(dir.path_join(d)))
	return out


func test_no_gameplay_code_writes_a_knob_field() -> void:
	var re := RegEx.create_from_string(KNOB_WRITE)
	var hits := PackedStringArray()
	for path in _src_files("res://src"):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code := lines[i].split("#")[0] ## comments may show writes as examples
			if re.search(code) != null:
				hits.append("%s:%d: %s" % [path, i + 1, lines[i].strip_edges()])
	assert_array(hits).override_failure_message("knob writes (manifest knob_write):\n" + "\n".join(hits)).is_empty()


func test_knob_write_pattern_catches_writes_and_ignores_reads() -> void:
	var re := RegEx.create_from_string(KNOB_WRITE)
	for w in ["\tknobs.net.port = 1", "\t_knobs.controller.walk_speed += 0.1", "x; knobs.ability.lunge_s *= 2"]:
		assert_object(re.search(w)).override_failure_message(w).is_not_null()
	for r in ["\tvar p := knobs.net.port", "\tif _knobs.net.port == 1:", "\tvar my_knobs.x = 1", "\tfoo(knobs.net.port)"]:
		assert_object(re.search(r)).override_failure_message(r).is_null()
