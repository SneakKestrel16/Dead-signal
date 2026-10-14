class_name TickRunner extends Node
## The one server clock and the six fixed tick phases (ADR-0002). Server side only.
## Created and injected by the composition root; never an autoload.
## Phases per tick: 1 dequeue input, 2 movement, 3 snapshot history, 4 feature server_tick(tick)
## in phase_order, 5 bus.flush(), 6 build and send snapshots. Rules run only from here:
## a Feature module must not run rules from its own _physics_process, and timers count ticks.
## Feature module interface: any object with `server_tick(tick: int) -> void`.
## Phases 1-3 and 6 are hooks (Callable taking the tick, default no-op) that later stories set.
## Usage:
##   var runner := TickRunner.new(); runner.boot(knobs); runner.bus = bus
##   runner.register_feature(health, 10)

## Emitted at the start of every tick, carrying the NEW tick (current_tick() equals it).
signal tick_started(tick: int)

## Phase 1 hook: dequeue one input frame per player (story 005). Callable(tick: int).
var input_stage: Callable
## Phase 2 hook: movement (story 006). Callable(tick: int).
var movement_stage: Callable
## Phase 3 hook: push positions into the snapshot history (story 006). Callable(tick: int).
var history_stage: Callable
## Phase 6 hook: build and send per-peer snapshots (story 007). Callable(tick: int).
var snapshot_stage: Callable
## Phase 5 target: flushed once per tick. Null is allowed (tests); phase 5 is then skipped.
var bus: EventBus
## When true a violation ends in assert(false). Default: debug builds only; tests set false.
var fail_hard: bool = OS.is_debug_build()
## Human-readable record of every violation (duplicate phase_order, second boot).
var violations: PackedStringArray = []

var _tick: int = 0
var _hz: int = 0
var _booted: bool = false
## Sorted ascending by "order": Array of {order: int, module: Object}.
var _features: Array[Dictionary] = []


## Sets Engine.physics_ticks_per_second from knobs.net.sim_tick_hz. Only the FIRST call acts;
## later calls record a violation and change nothing. Example: `runner.boot(Knobs.load_all())`.
func boot(knobs: Knobs) -> void:
	if _booted:
		_violate("boot called twice; physics_ticks_per_second stays %d" % _hz)
		return
	_booted = true
	_hz = knobs.net.sim_tick_hz
	Engine.physics_ticks_per_second = _hz


## The tick being run (0 before the first step).
func current_tick() -> int:
	return _tick


## Server time in seconds: server_tick / sim_tick_hz. Requires boot().
func server_time() -> float:
	return float(_tick) / float(_hz)


## Registers `module` (an object with server_tick(tick)) to run in phase 4, lowest `phase_order`
## first. A `phase_order` already taken is a violation and the module is NOT registered.
func register_feature(module: Object, phase_order: int) -> void:
	for f in _features:
		if f.order == phase_order:
			_violate("duplicate phase_order %d" % phase_order)
			return
	_features.append({"order": phase_order, "module": module})
	_features.sort_custom(_by_order)


## Runs one whole tick: tick += 1, tick_started, then phases 1-6. Tests call this directly.
func step() -> void:
	_tick += 1
	tick_started.emit(_tick)
	_run(input_stage)
	_run(movement_stage)
	_run(history_stage)
	for f in _features:
		f.module.server_tick(_tick)
	if bus != null:
		bus.flush()
	_run(snapshot_stage)


func _physics_process(_delta: float) -> void:
	step()


func _by_order(a: Dictionary, b: Dictionary) -> bool:
	return a.order < b.order


func _run(stage: Callable) -> void:
	if stage.is_valid():
		stage.call(_tick)


func _violate(msg: String) -> void:
	violations.append(msg)
	push_error("TickRunner: " + msg)
	assert(not fail_hard, "TickRunner: " + msg)
