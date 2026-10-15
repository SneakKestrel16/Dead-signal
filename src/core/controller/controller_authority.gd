class_name ControllerAuthority extends RefCounted
## The controller's server-side round hooks (first-person-controller.md Edge Cases and Dependencies;
## ADR-0002 §4-6, ADR-0008 §3; story controller-interaction/011). Runs HoldService as the Holds step
## (TickOrder.HOLDS) and applies the two Match Flow facts the controller consumes:
## - freeze(player_id), RoundLifecycle's freeze hook on the RoundEnded tick: movement stops
##   (ServerMovement.set_frozen) and the hold cancels with &"round_ended"; from then on the player's
##   intent reaches neither movement nor holds (a frozen player's ServerMovement.frames_of is empty).
## - PlayerConnectionChanged DISCONNECTED cancels that player's hold with &"disconnected" on the flush
##   after the emitting step.
## The input timeout and the inside-geometry restore need nothing here: InputQueue releases input after
## intent_timeout_ms, the released frame stops movement and HoldService cancels on it (&"released");
## ServerMovement restores the last valid position.
## Inference: RoundLifecycle calls freeze from MATCH_FLOW_RESOLVE, after that tick's movement and Holds
## step, so "stops on that tick" means velocity 0 and no hold left at the end of the tick; a hold that
## completed in the Holds step of that same tick stays complete. A Match Flow ruling on whether a
## completion and RoundEnded on one tick both stand would settle it.
## Usage:
##   var ctl := ControllerAuthority.new(sm, holds)
##   server.start_round({TickOrder.HOLDS: ctl, ...}, knobs); lifecycle.freeze = ctl.freeze

var _movement: ServerMovement
var _holds: HoldService


func _init(movement: ServerMovement, holds: HoldService) -> void:
	_movement = movement
	_holds = holds


func setup(_runner: TickRunner, bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
	bus.subscribe(&"PlayerConnectionChanged", _on_connection)


## The Holds step.
func server_tick(tick: int) -> void:
	_holds.server_tick(tick)


## RoundEnded: stops `player_id`'s movement, cancels their hold and ignores their intent from now on.
func freeze(player_id: int) -> void:
	_movement.set_frozen(player_id, true)
	_holds.cancel(player_id, &"round_ended")


func _on_connection(e: ServerEvent) -> void:
	var c := e as EvPlayerConnectionChanged
	if c.status == EvPlayerConnectionChanged.DISCONNECTED:
		_holds.cancel(c.player, &"disconnected")
