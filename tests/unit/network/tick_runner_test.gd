# Story network-authority/004: TickRunner and the server clock.
extends GdUnitTestSuite

const RUNNER_PATH := "res://src/foundation/network/tick_runner.gd"
const SRC_DIR := "res://src/"
const MIN_SCANNED_FILES := 5

var _saved_hz: int


## Appends its name to a shared log in server_tick.
class Feature extends RefCounted:
	var name: String
	var log: Array
	var ticks: Array[int] = []

	func _init(n: String, l: Array) -> void:
		name = n
		log = l

	func server_tick(tick: int) -> void:
		log.append(name)
		ticks.append(tick)


## Named stage methods that append to a log (lambdas are forbidden by the manifest).
class Stages extends RefCounted:
	var log: Array

	func _init(l: Array) -> void:
		log = l

	func input(_t: int) -> void:
		log.append("input")

	func movement(_t: int) -> void:
		log.append("movement")

	func history(_t: int) -> void:
		log.append("history")

	func flush(_e: ServerEvent) -> void:
		log.append("flush")

	func snapshot(_t: int) -> void:
		log.append("snapshot")


class TickRecorder extends RefCounted:
	var ticks: Array[int] = []
	var seen_current: Array[int] = []
	var runner: TickRunner

	func on_tick(t: int) -> void:
		ticks.append(t)
		seen_current.append(runner.current_tick())


func before_test() -> void:
	_saved_hz = Engine.physics_ticks_per_second


func after_test() -> void:
	Engine.physics_ticks_per_second = _saved_hz


func _knobs(hz: int) -> Knobs:
	var k := Knobs.load_all()
	k.net.sim_tick_hz = hz
	return k


func _runner(hz: int = 60) -> TickRunner:
	var r: TickRunner = auto_free(TickRunner.new())
	r.fail_hard = false
	r.boot(_knobs(hz))
	return r


func test_current_tick_increments_by_one_per_step() -> void:
	var r := _runner()
	var seen: Array[int] = []
	for i in 5:
		r.step()
		seen.append(r.current_tick())
	assert_array(seen).is_equal([1, 2, 3, 4, 5])


func test_server_time_is_tick_over_hz_at_60_and_30() -> void:
	var r60 := _runner(60)
	for i in 90:
		r60.step()
	assert_float(r60.server_time()).is_equal(1.5)
	var r30 := _runner(30)
	for i in 90:
		r30.step()
	assert_float(r30.server_time()).is_equal(3.0)


func test_tick_started_emitted_once_per_step_with_new_tick() -> void:
	var r := _runner()
	var rec := TickRecorder.new()
	rec.runner = r
	r.tick_started.connect(rec.on_tick)
	for i in 3:
		r.step()
	assert_array(rec.ticks).is_equal([1, 2, 3])
	assert_array(rec.seen_current).is_equal([1, 2, 3])


func test_phases_run_in_order_with_features_sorted_by_phase_order() -> void:
	var r := _runner()
	var log: Array = []
	var st := Stages.new(log)
	r.input_stage = st.input
	r.movement_stage = st.movement
	r.history_stage = st.history
	r.snapshot_stage = st.snapshot
	r.bus = EventBus.new(8)
	r.bus.subscribe(&"SurvivorHit", st.flush)
	r.bus.emit(EvSurvivorHit.new())
	# Registered out of order on purpose.
	r.register_feature(Feature.new("c", log), 30)
	r.register_feature(Feature.new("a", log), 10)
	r.register_feature(Feature.new("b", log), 20)
	r.step()
	assert_array(log).is_equal(["input", "movement", "history", "a", "b", "c", "flush", "snapshot"])


func test_feature_receives_the_running_tick() -> void:
	var r := _runner()
	var f := Feature.new("a", [])
	r.register_feature(f, 1)
	r.step()
	r.step()
	assert_array(f.ticks).is_equal([1, 2])


func test_step_without_stages_or_bus_does_not_crash() -> void:
	var r := _runner()
	r.step()
	assert_int(r.current_tick()).is_equal(1)


func test_duplicate_phase_order_records_violation_and_skips_module() -> void:
	var r := _runner()
	var log: Array = []
	r.register_feature(Feature.new("a", log), 10)
	r.register_feature(Feature.new("dup", log), 10)
	r.step()
	assert_int(r.violations.size()).is_equal(1)
	assert_array(log).is_equal(["a"])


func test_boot_sets_physics_ticks_from_knobs() -> void:
	var r: TickRunner = auto_free(TickRunner.new())
	r.boot(_knobs(48))
	assert_int(Engine.physics_ticks_per_second).is_equal(48)


func test_second_boot_does_not_change_physics_ticks() -> void:
	var r := _runner(60)
	r.boot(_knobs(30))
	assert_int(Engine.physics_ticks_per_second).is_equal(60)
	assert_int(r.violations.size()).is_equal(1)


func test_shipped_knobs_boot_at_60() -> void:
	var r: TickRunner = auto_free(TickRunner.new())
	r.boot(Knobs.load_all())
	assert_int(Engine.physics_ticks_per_second).is_equal(60)


# --- source scan: nothing but tick_runner.gd sets physics_ticks_per_second ---

static func _assigns_hz(text: String) -> bool:
	var rx := RegEx.create_from_string("physics_ticks_per_second\\s*(=|\\+=|-=)[^=]")
	return rx.search(text) != null


func _gd_files(dir: String, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_gd_files(dir.path_join(d), out)


func test_scanner_flags_a_fixture_that_assigns_the_setting() -> void:
	assert_bool(_assigns_hz("Engine.physics_ticks_per_second = 30")).is_true()
	assert_bool(_assigns_hz("Engine.physics_ticks_per_second=hz")).is_true()
	assert_bool(_assigns_hz("var x = Engine.physics_ticks_per_second")).is_false()
	assert_bool(_assigns_hz("if Engine.physics_ticks_per_second == 60:")).is_false()


func test_no_script_but_tick_runner_assigns_physics_ticks_per_second() -> void:
	var files := PackedStringArray()
	_gd_files(SRC_DIR, files)
	assert_int(files.size()).is_greater_equal(MIN_SCANNED_FILES)
	assert_bool(files.has(RUNNER_PATH)).is_true()
	var offenders := PackedStringArray()
	for p in files:
		if p != RUNNER_PATH and _assigns_hz(FileAccess.get_file_as_string(p)):
			offenders.append(p)
	assert_array(offenders).is_empty()
