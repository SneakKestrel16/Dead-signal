class_name FeatureStep extends RefCounted
## Phase-4 wrapper: runs one module's server_tick, then bus.flush(), so every step's events are
## handled before the next step runs (ADR-0005). Created by RoundServer; holds the module until
## the TickRunner is freed at round end.
## Usage: `runner.register_feature(FeatureStep.new(module, bus), TickOrder.DOWNING)`

var _module: Object
var _bus: EventBus


## `module` must have `server_tick(tick: int)`.
func _init(module: Object, bus: EventBus) -> void:
	_module = module
	_bus = bus


## Called by TickRunner phase 4.
func server_tick(tick: int) -> void:
	_module.server_tick(tick)
	_bus.flush()
