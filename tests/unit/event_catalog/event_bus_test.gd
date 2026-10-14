# Story event-catalog-state-registry/002: EventBus emit, subscribe and flush.
extends GdUnitTestSuite

const SHOCKED := &"PlayerShocked"
const HIT := &"SurvivorHit"


## Handlers as NAMED methods (lambdas are forbidden by the manifest).
class Recorder extends RefCounted:
	var name: String
	var log: Array = []
	var bus: EventBus
	## Handler that on_subscribe_late subscribes mid-flush.
	var late_handler: Callable

	func _init(n: String = "") -> void:
		name = n

	func on_event(e: ServerEvent) -> void:
		log.append([name, e.tick])

	## Emits a follow-up SurvivorHit (tick + 100) once.
	func on_emit_follow_up(e: ServerEvent) -> void:
		log.append([name, e.tick])
		var f := EvSurvivorHit.new()
		f.tick = e.tick + 100
		bus.emit(f)

	## Subscribes late_handler to the same type mid-flush.
	func on_subscribe_late(e: ServerEvent) -> void:
		log.append([name, e.tick])
		bus.subscribe(e.type(), late_handler)

	## Re-emits the same type with tick + 1 until tick reaches the limit stored in `limit`.
	var limit: int = 0

	func on_cascade(e: ServerEvent) -> void:
		log.append([name, e.tick])
		if e.tick < limit:
			var n := EvPlayerShocked.new()
			n.tick = e.tick + 1
			bus.emit(n)


class NodeHandler extends Node:
	var calls: int = 0

	func on_event(_e: ServerEvent) -> void:
		calls += 1


func _shocked(tick: int) -> EvPlayerShocked:
	var e := EvPlayerShocked.new()
	e.tick = tick
	return e


func _bus() -> EventBus:
	var b := EventBus.new(8)
	b.fail_hard = false
	return b


func test_two_subscribers_receive_in_subscribe_order() -> void:
	var bus := _bus()
	var a := Recorder.new("a")
	var b := Recorder.new("b")
	a.log = b.log
	bus.subscribe(SHOCKED, a.on_event)
	bus.subscribe(SHOCKED, b.on_event)
	bus.emit(_shocked(1))
	bus.flush()
	assert_array(a.log).is_equal([["a", 1], ["b", 1]])


func test_freed_node_subscriber_is_skipped_without_error() -> void:
	var bus := _bus()
	var node := NodeHandler.new()
	var rec := Recorder.new("r")
	bus.subscribe(SHOCKED, node.on_event)
	bus.subscribe(SHOCKED, rec.on_event)
	node.free()
	bus.emit(_shocked(1))
	bus.flush()
	assert_array(rec.log).is_equal([["r", 1]])
	assert_int(bus.overflow_count).is_equal(0)


func test_event_emitted_by_handler_is_delivered_in_same_flush() -> void:
	var bus := _bus()
	var rec := Recorder.new("r")
	rec.bus = bus
	bus.subscribe(SHOCKED, rec.on_emit_follow_up)
	bus.subscribe(HIT, rec.on_event)
	bus.emit(_shocked(1))
	bus.flush()
	assert_array(rec.log).is_equal([["r", 1], ["r", 101]])


func test_handler_subscribed_mid_flush_is_not_called_for_current_event() -> void:
	var bus := _bus()
	var first := Recorder.new("first")
	var late := Recorder.new("late")
	first.bus = bus
	first.late_handler = late.on_event
	bus.subscribe(SHOCKED, first.on_subscribe_late)
	bus.emit(_shocked(1))
	bus.flush()
	assert_array(late.log).is_empty()
	# The late subscription does take effect for the next event.
	bus.emit(_shocked(2))
	bus.flush()
	assert_array(late.log).is_equal([["late", 2]])


func test_take_tick_events_returns_delivered_in_order_then_resets() -> void:
	var bus := _bus()
	bus.emit(_shocked(1))
	bus.emit(_shocked(2))
	bus.flush()
	var got := bus.take_tick_events()
	assert_array(got.map(func(e): return e.tick)).is_equal([1, 2])
	assert_array(bus.take_tick_events()).is_empty()


func test_event_with_no_subscribers_is_still_collected() -> void:
	var bus := _bus()
	bus.emit(_shocked(7))
	bus.flush()
	assert_int(bus.take_tick_events().size()).is_equal(1)


func test_clear_empties_queue_subscribers_and_collected() -> void:
	var bus := _bus()
	var rec := Recorder.new("r")
	bus.subscribe(SHOCKED, rec.on_event)
	bus.emit(_shocked(1))
	bus.flush()
	bus.emit(_shocked(2))
	bus.clear()
	bus.flush()
	bus.emit(_shocked(3))
	bus.flush()
	assert_array(rec.log).is_equal([["r", 1]])
	assert_int(bus.take_tick_events().size()).is_equal(1)  # only tick 3, collected after clear


func test_cascade_of_exactly_max_rounds_does_not_overflow() -> void:
	var bus := _bus()
	var rec := Recorder.new("r")
	rec.bus = bus
	rec.limit = 8  # ticks 1..8 = 8 rounds
	bus.subscribe(SHOCKED, rec.on_cascade)
	bus.emit(_shocked(1))
	bus.flush()
	assert_int(rec.log.size()).is_equal(8)
	assert_int(bus.overflow_count).is_equal(0)


func test_cascade_needing_nine_rounds_takes_overflow_path() -> void:
	var bus := _bus()
	var rec := Recorder.new("r")
	rec.bus = bus
	rec.limit = 9  # ticks 1..9 = 9 rounds
	bus.subscribe(SHOCKED, rec.on_cascade)
	bus.emit(_shocked(1))
	bus.flush()
	assert_int(rec.log.size()).is_equal(8)
	assert_int(bus.overflow_count).is_equal(1)
	assert_str(bus.last_overflow_type).is_equal("PlayerShocked")
	# Queue was dropped: a second flush delivers nothing.
	bus.flush()
	assert_int(rec.log.size()).is_equal(8)
