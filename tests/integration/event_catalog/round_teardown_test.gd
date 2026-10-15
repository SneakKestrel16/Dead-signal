# SR-1 review 2026-10-14 (Sprint 1 retroactive review): round teardown from inside a running tick.
extends GdUnitTestSuite


## Ends the round from inside its own server_tick.
class Ender extends RefCounted:
	var server: RoundServer

	func setup(_runner: TickRunner, _bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		pass

	func server_tick(_tick: int) -> void:
		server.end_round()


## end_round() freed the TickRunner synchronously, mid-step(); it is now queued, so a module or bus
## handler can end the round and the tick finishes on a live object.
func test_end_round_from_inside_a_tick_does_not_free_the_running_runner() -> void:
	var server: RoundServer = auto_free(RoundServer.new())
	add_child(server)
	var ender := Ender.new()
	ender.server = server
	server.start_round({TickOrder.DOWNING: ender}, Knobs.load_all())
	var runner := server.tick_runner
	runner.step()
	assert_object(server.tick_runner).is_null()
	assert_bool(is_instance_valid(runner)).is_true() # still alive until the frame ends
	await get_tree().process_frame
	assert_bool(is_instance_valid(runner)).is_false()


## start_round() never checked knobs.errors(), so a missing core.tres crashed on knobs.core.
func test_start_round_with_broken_knobs_refuses_and_starts_nothing() -> void:
	var server: RoundServer = auto_free(RoundServer.new())
	var k := Knobs.load_all()
	k.core = null
	var errs := server.start_round({}, k)
	assert_array(errs).is_not_empty()
	assert_object(server.tick_runner).is_null()


## A handler that clears the bus mid-flush (end_round) stopped nothing: the rest of the batch was
## still delivered and collected after the clear.
func test_clear_inside_a_handler_stops_the_flush() -> void:
	var bus := EventBus.new(8)
	var got: Array[StringName] = []
	bus.subscribe(&"RoundPhaseChanged", func(_e: ServerEvent) -> void:
		got.append(&"RoundPhaseChanged")
		bus.clear())
	bus.subscribe(&"RoundEnded", func(_e: ServerEvent) -> void: got.append(&"RoundEnded"))
	bus.emit(EvRoundPhaseChanged.new())
	bus.emit(EvRoundEnded.new())
	bus.flush()
	assert_array(got).is_equal([&"RoundPhaseChanged"])
	assert_array(bus.take_tick_events()).is_empty()
