class_name RoundServer extends Node
## Composition root for one round (ADR-0005). Builds the services (TickRunner, EventBus,
## StateRegistry), injects them into each module via `setup(tick_runner, bus, registry, knobs)`,
## registers modules in TickOrder, and tears everything down at round end. Never an autoload.
## Not thread-safe: server main thread only. Creates no Feature modules itself; the caller
## supplies them (Feature epics).
## Usage:
##   var server := RoundServer.new()
##   server.start_round({TickOrder.DOWNING: downing}, Knobs.load_all())
##   server.tick_runner.step()   # or add_child(server) and let physics drive it
##   server.end_round()

## Services of the running round; null outside a round.
var tick_runner: TickRunner
var bus: EventBus
var registry: StateRegistry

var _modules: Array[Object] = []


## Starts a round. `modules` maps a TickOrder slot (int) to a module object with
## `setup(tick_runner, bus, registry, knobs)` and `server_tick(tick)`. Modules subscribe and
## register views inside setup(). Ends a still-running round first.
func start_round(modules: Dictionary, knobs: Knobs) -> void:
	end_round()
	bus = EventBus.new(knobs.core.max_flush_rounds)
	registry = StateRegistry.new()
	tick_runner = TickRunner.new()
	tick_runner.boot(knobs)
	tick_runner.bus = bus
	add_child(tick_runner)
	for slot: int in modules:
		var module: Object = modules[slot]
		_modules.append(module)
		module.setup(tick_runner, bus, registry, knobs)
		tick_runner.register_feature(FeatureStep.new(module, bus), slot)


## Ends the round: clears bus and registry (breaks module <-> view cycles), frees the
## TickRunner and drops every module reference. Safe to call when no round is running.
func end_round() -> void:
	if bus != null:
		bus.clear()
	if registry != null:
		registry.clear()
	if tick_runner != null:
		remove_child(tick_runner)
		tick_runner.free()
	tick_runner = null
	bus = null
	registry = null
	_modules = []
