class_name EventBus extends RefCounted
## Server-side event queue with ordered, same-tick delivery (ADR-0005).
## Plain object: the composition root creates and injects it; never an autoload, never signals.
## Not thread-safe: server main thread only. Clients never emit (client path is a later story).
## Handlers must be named methods that change only their own module's state; lambdas are forbidden.
## Usage:
##   var bus := EventBus.new(k.core.max_flush_rounds)
##   bus.subscribe(&"PlayerShocked", recorder.on_shocked)
##   bus.emit(EvPlayerShocked.new()); bus.flush()
##   var delivered := bus.take_tick_events()

## Rounds flush() may run before the overflow path is taken (CoreKnobs.max_flush_rounds).
var max_flush_rounds: int
## When true the overflow path ends in assert(false). Default: debug builds only.
## Tests set false to observe the overflow path without aborting the run.
var fail_hard: bool = OS.is_debug_build()
## Number of overflows since construction or clear().
var overflow_count: int = 0
## type() of the first event dropped by the latest overflow, &"" if none.
var last_overflow_type: StringName = &""

var _queue: Array[ServerEvent] = []
## type -> Array of Callable, in subscribe order (Array[Callable] as a value type does not parse).
var _handlers: Dictionary[StringName, Array] = {}
var _collected: Array[ServerEvent] = []
## The running tick and its server time, set by TickRunner at the start of each step; emit() stamps them.
var tick: int = 0
var server_time: float = 0.0
var _cleared := false ## set by clear(); flush() stops delivering when a handler clears mid-batch


## `rounds` must come from data (`Knobs.core.max_flush_rounds`), never a literal in game code.
func _init(rounds: int) -> void:
	max_flush_rounds = rounds


## Queues `e` for the next flush(), stamped with the tick of emission and its server time (ADR-0005
## §1) once a TickRunner drives the bus (tick > 0), unless the emitter set a tick itself. An event
## emitted outside a step (an RPC handler) carries the last step's tick and is batched on the next.
## Example: `bus.emit(EvSurvivorHit.new())`.
func emit(e: ServerEvent) -> void:
	if tick > 0 and e.tick == 0:
		e.tick = tick
		e.server_time = server_time
	_queue.append(e)


## Adds `handler` (a named-method Callable) for events whose type() equals `type`.
## Example: `bus.subscribe(&"SurvivorHit", health.on_survivor_hit)`.
func subscribe(type: StringName, handler: Callable) -> void:
	if not _handlers.has(type):
		_handlers[type] = []
	_handlers[type].append(handler)


## Drains the queue. A round is one pass over the events queued when that pass began; events
## emitted by handlers during a pass form the next round, so cause and effect resolve in one flush.
## Each event goes to its handlers in subscribe order, over a COPY of the list (a handler that
## subscribes mid-flush does not change this delivery). Invalid callables (freed object) are skipped.
## Overflow: needing more than max_flush_rounds rounds records overflow_count/last_overflow_type,
## push_error()s, DROPS the remaining queue so it cannot loop, then assert(false) only if fail_hard.
## Example: `bus.flush()` once per tick at the defined drain point.
func flush() -> void:
	var rounds := 0
	while not _queue.is_empty():
		if rounds >= max_flush_rounds:
			_overflow()
			return
		rounds += 1
		var batch := _queue
		_queue = []
		_cleared = false
		for e in batch:
			_deliver(e)
			if _cleared:
				return ## a handler ended the round: the rest of this batch is dropped with it


## Every event delivered since the last call, in delivery order; resets the list.
## Events with no subscribers are still included. Example: `for e in bus.take_tick_events(): ...`
func take_tick_events() -> Array[ServerEvent]:
	var out := _collected
	_collected = []
	return out


## Empties the queue, all subscribers and the collected events (and the overflow record).
func clear() -> void:
	_cleared = true
	_queue = []
	_handlers = {}
	_collected = []
	overflow_count = 0
	last_overflow_type = &""


func _deliver(e: ServerEvent) -> void:
	_collected.append(e)
	var list: Array = _handlers.get(e.type(), [])
	for h: Callable in list.duplicate():
		if h.is_valid():
			h.call(e)


func _overflow() -> void:
	overflow_count += 1
	last_overflow_type = _queue[0].type()
	push_error("EventBus: flush needed more than %d rounds; dropped %d event(s), first %s"
		% [max_flush_rounds, _queue.size(), last_overflow_type])
	_queue = []
	assert(not fail_hard, "EventBus flush cascade exceeded max_flush_rounds")
