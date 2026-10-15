# Story event-catalog-state-registry/004: composition root and feature tick order.
extends GdUnitTestSuite

const PROJECT_FILE := "res://project.godot"
const SHOCK := &"PlayerShocked"

## The documented ADR-0005 order, by slot constant.
const SLOTS: Array[int] = [
	TickOrder.MATCH_FLOW_BEGIN, TickOrder.SURVIVOR_DEFENSE, TickOrder.BORROWED_FACE,
	TickOrder.MONSTER_ABILITIES, TickOrder.FACILITY_MAP, TickOrder.DOWNING, TickOrder.HOLDS,
	TickOrder.SURVIVOR_OBJECTIVES, TickOrder.PINGS_CALLOUTS, TickOrder.SCARE_EVENTS,
	TickOrder.MATCH_FLOW_RESOLVE,
]
const NAMES: Array[String] = [
	"MatchFlow.begin", "SurvivorDefense", "BorrowedFace", "MonsterAbilities", "FacilityMap",
	"Downing", "Holds", "SurvivorObjectives", "PingsCallouts", "ScareEvents", "MatchFlow.resolve",
]

var _saved_hz: int


## Getter-only view that points back at its module (the cycle of ADR-0005 verification 4).
class StubView extends RefCounted:
	var module: Object


## Logs "tick:<name>", then how many events earlier steps had delivered (proof of a flush after
## the previous step), emits one event, and, when `listens`, logs each event it handles.
class StubModule extends RefCounted:
	var name: String
	var log: Array
	var index: int
	var listens: bool
	var bus: EventBus
	var registry: StateRegistry

	func _init(n: String, i: int, l: Array, listen: bool) -> void:
		name = n
		index = i
		log = l
		listens = listen

	func setup(_runner: TickRunner, b: EventBus, r: StateRegistry, _k: Knobs) -> void:
		bus = b
		registry = r
		if listens:
			bus.subscribe(SHOCK, on_shock)
		var v := StubView.new()
		v.module = self
		registry.register_view(StringName("stub_" + name), &"Stub", v)

	func server_tick(_tick: int) -> void:
		log.append("tick:%s delivered:%d" % [name, bus.take_tick_events().size()])
		var e := EvPlayerShocked.new()
		e.tick = index
		bus.emit(e)

	func on_shock(e: ServerEvent) -> void:
		log.append("handled:%s" % NAMES[e.tick])


func before_test() -> void:
	_saved_hz = Engine.physics_ticks_per_second


func after_test() -> void:
	Engine.physics_ticks_per_second = _saved_hz


func _stubs(log: Array, listener: int) -> Array[StubModule]:
	var out: Array[StubModule] = []
	for i in SLOTS.size():
		out.append(StubModule.new(NAMES[i], i, log, i == listener))
	return out


func _slotted(stubs: Array[StubModule]) -> Dictionary:
	var d := {}
	for i in SLOTS.size():
		d[SLOTS[i]] = stubs[i]
	return d


func _server() -> RoundServer:
	var s: RoundServer = auto_free(RoundServer.new())
	return s


func test_one_tick_runs_steps_in_documented_order_with_flush_after_each() -> void:
	var log := []
	var server := _server()
	server.start_round(_slotted(_stubs(log, SLOTS.size() - 1)), Knobs.load_all())

	server.tick_runner.step()

	# Each step sees the one event the step before it emitted and flushed (no flush -> 0).
	var expected := []
	for i in NAMES.size():
		expected.append("tick:%s delivered:%d" % [NAMES[i], mini(i, 1)])
	var ticks := log.filter(func(s: String) -> bool: return s.begins_with("tick:"))
	assert_array(ticks).is_equal(expected)
	server.end_round()


func test_event_from_step_two_is_handled_before_step_three_runs() -> void:
	var log := []
	var server := _server()
	# The event of step 2 must still be handled before step 3 starts.
	server.start_round(_slotted(_stubs(log, 8)), Knobs.load_all())

	server.tick_runner.step()

	var handled := log.find("handled:SurvivorDefense")
	assert_int(handled).is_greater_equal(0)
	assert_int(handled).is_less(log.find("tick:BorrowedFace delivered:1"))
	assert_int(handled).is_greater(log.find("tick:SurvivorDefense delivered:1"))
	server.end_round()


func test_stub_registered_out_of_order_still_runs_by_phase_order() -> void:
	var log := []
	var stubs := _stubs(log, -1)
	var reversed := {}
	for i in range(SLOTS.size() - 1, -1, -1):
		reversed[SLOTS[i]] = stubs[i]
	var server := _server()
	server.start_round(reversed, Knobs.load_all())

	server.tick_runner.step()

	var names := log.map(func(s: String) -> String: return s.split(" ")[0].trim_prefix("tick:"))
	assert_array(names).is_equal(NAMES)
	server.end_round()


func _start_and_weakrefs(server: RoundServer) -> Array[WeakRef]:
	var stubs := _stubs([], 0)
	server.start_round(_slotted(stubs), Knobs.load_all())
	server.tick_runner.step()
	var refs: Array[WeakRef] = [weakref(server.tick_runner), weakref(server.bus), weakref(server.registry)]
	for s in stubs:
		refs.append(weakref(s))
		refs.append(weakref(server.registry.view(StringName("stub_" + s.name), StubView)))
	return refs


func test_end_round_leaves_nothing_alive_and_no_orphans() -> void:
	var server := _server()
	var orphans_before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)  # server itself counts
	var refs := _start_and_weakrefs(server)
	var bus := server.bus
	var registry := server.registry
	for r in refs:
		assert_bool(r.get_ref() != null).is_true()  # not assert_object: it would hold the ref

	server.end_round()

	assert_object(server.tick_runner).is_null()
	assert_object(server.bus).is_null()
	assert_object(server.registry).is_null()
	assert_int(server.get_child_count()).is_equal(0)
	assert_int(bus.take_tick_events().size()).is_equal(0)
	bus.emit(EvPlayerShocked.new())
	bus.flush()
	assert_int(bus.take_tick_events().size()).is_equal(1)  # queue works but nobody subscribed
	registry.fail_hard = false
	assert_object(registry.view(StringName("stub_Downing"), StubView)).is_null()
	assert_int(registry.violations.size()).is_equal(1)  # unregistered: the views are gone
	bus = null
	registry = null
	await get_tree().process_frame # the runner is queue_free()d (SR-1: safe to end a round mid-tick)
	for r in refs:
		assert_object(r.get_ref()).is_null()
	# <=: the awaited frame also frees orphans gdUnit left before orphans_before was read.
	assert_float(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)).is_less_equal(orphans_before)


## Flags every [autoload] entry: no gameplay service may be a global (control manifest).
## ponytail: no allowlist; the first legitimate non-gameplay autoload adds one here.
func _autoload_entries(cfg: ConfigFile) -> PackedStringArray:
	if not cfg.has_section("autoload"):
		return PackedStringArray()
	return PackedStringArray(cfg.get_section_keys("autoload"))


func test_project_godot_has_no_autoload_entries() -> void:
	var cfg := ConfigFile.new()

	var err := cfg.load(PROJECT_FILE)

	assert_int(err).is_equal(OK)
	assert_bool(cfg.has_section("application")).is_true()  # the scan really read the file
	assert_array(_autoload_entries(cfg)).is_empty()


func test_autoload_scan_flags_a_fixture_with_an_autoload_section() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("autoload", "RoundState", "*res://src/round_state.gd")

	assert_array(_autoload_entries(cfg)).contains_exactly(["RoundState"])
