class_name Footsteps extends RefCounted
## Server-side footstep events (first-person-controller.md rule 8, Formulas footstep_radius; ADR-0013 §2,
## ADR-0004 §6; story controller-interaction/014). Each tick a body covers its horizontal speed x dt;
## every `footstep_spacing_m` covered emits one positional sound at its feet through `emit` (ServerMovement.
## emit_sound), sent only to other players within the gait's radius, with no handle. A body that does not
## move (velocity zero, including a frozen or restored one) emits nothing; vertical speed never counts.
## The sound set is the ADR-0013 §2 catalog id `c<appearance>.<gait>` (e.g. `c3.sprint`), from
## BorrowedFace.appearance_of, so a disguised shapeshifter's steps use its target's set (ADR-0010 §2) and
## the true form's are `c0.*`. Inference: ADR-0010's Appearance.footstep_set resource does not exist yet,
## so the set name is derived from the appearance id; a shipped appearances.tres settles it.
## Deviation from ADR-0013 §2: the event has no gait field, so the gait rides in the set id.
## Not here (later stories): ADR-0013 §7 masking (lighting volume footstep_radius_scale; no map data yet).
## Usage:
##   var steps := Footsteps.new(gait_of, borrowed_face.appearance_of, server_movement.emit_sound)
##   steps.add_player(pid, body)
##   server.start_round({TickOrder.FOOTSTEPS: steps}, knobs)

const GAIT_NAMES := {MovementStep.Gait.WALK: "walk", MovementStep.Gait.SPRINT: "sprint",
	MovementStep.Gait.CROUCH: "crouch", MovementStep.Gait.CRAWL: "crawl"}

var _gait_of: Callable
var _appearance_of: Callable
var _emit: Callable
var _knobs: Knobs
var _dt: float
var _bodies: Dictionary[int, CharacterBody3D] = {}
## Player -> metres covered since its last footstep.
var _covered: Dictionary[int, float] = {}


## `gait_of(player) -> MovementStep.Gait` (the controller's gait this tick); `appearance_of(player) -> int`
## (BorrowedFace.appearance_of); `emit(position, sound_set, radius_m, source)` (ServerMovement.emit_sound).
func _init(gait_of: Callable, appearance_of: Callable, emit: Callable) -> void:
	_gait_of = gait_of
	_appearance_of = appearance_of
	_emit = emit


func setup(_runner: TickRunner, _bus: EventBus, _registry: StateRegistry, knobs: Knobs) -> void:
	_knobs = knobs
	_dt = 1.0 / knobs.net.sim_tick_hz


## Starts tracking a player's body (the caller owns it).
func add_player(player: int, body: CharacterBody3D) -> void:
	_bodies[player] = body
	_covered[player] = 0.0


## Stops tracking a player.
func remove_player(player: int) -> void:
	_bodies.erase(player)
	_covered.erase(player)


## Runs after movement: at most one footstep per player per tick.
func server_tick(_tick: int) -> void:
	for player: int in _bodies:
		var body := _bodies[player]
		var covered := _covered[player] + Vector2(body.velocity.x, body.velocity.z).length() * _dt
		if covered >= _knobs.controller.footstep_spacing_m:
			covered = fmod(covered, _knobs.controller.footstep_spacing_m)
			var g: MovementStep.Gait = _gait_of.call(player)
			_emit.call(body.global_position, StringName("c%d.%s" % [_appearance_of.call(player), GAIT_NAMES[g]]),
				radius_of(g), player)
		_covered[player] = covered


## The gait's send radius (the same in every form).
func radius_of(g: MovementStep.Gait) -> float:
	var c := _knobs.controller
	match g:
		MovementStep.Gait.SPRINT:
			return c.footstep_radius_sprint_m
		MovementStep.Gait.CROUCH:
			return c.footstep_radius_crouch_m
		MovementStep.Gait.CRAWL:
			return c.footstep_radius_crawl_m
	return c.footstep_radius_walk_m
