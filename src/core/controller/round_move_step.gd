class_name RoundMoveStep extends RefCounted
## The shipped round's move step and body factory (BUG-0017): MovementStep.step behind the shared
## Callable(body, frame, modifiers) that ServerMovement and OwnerPredictor both call (ADR-0002 apply_move),
## so the server and the owner's prediction run the same step. Each body keeps its own MoveState (in its
## meta) whose modifiers are the owner's set passed in. The gait reads the frame's sprint and crouch; the
## crouch posture (PlayerBody.set_low) is not driven here: no round module drives it yet.
## Bodies are PlayerBody (ADR-0007 values from ControllerKnobs) on the PLAYERS layer colliding with walls,
## glass and closed doors (PhysicsLayers.MOVE_PREDICT, BUG-0018), on the server too: players do not block
## each other, as with the harness step this replaces, so server and prediction share one mask.
## Usage:
##   RoundComposer.new(..., RoundMoveStep.step_for(knobs), PhysicsLayers.WORLD, RoundMoveStep.body_maker(knobs), ...)
##   RoundClient.new(knobs, RoundMoveStep.step_for(knobs), RoundMoveStep.body_maker(knobs), map, true)

const STATE_META := &"move_state"


## The step Callable(body, frame, modifiers) with `knobs` bound.
static func step_for(knobs: Knobs) -> Callable:
	return apply.bind(knobs)


## The body factory Callable(parent, pos) -> CharacterBody3D with `knobs` bound.
static func body_maker(knobs: Knobs) -> Callable:
	return make_body.bind(knobs)


## One tick for `body`: MovementStep.step with its MoveState, the frame's crouch and the owner's modifiers.
static func apply(body: CharacterBody3D, frame: InputFrame, modifiers: MovementModifiers, knobs: Knobs) -> void:
	var state := state_of(body)
	state.modifiers = modifiers
	state.crouched = frame.crouch
	MovementStep.step(body, frame, state, knobs)


## `body`'s MoveState, made on first use.
static func state_of(body: CharacterBody3D) -> MovementStep.MoveState:
	if not body.has_meta(STATE_META):
		body.set_meta(STATE_META, MovementStep.MoveState.new())
	return body.get_meta(STATE_META)


## A PlayerBody under `parent` at `pos`.
static func make_body(parent: Node, pos: Vector3, knobs: Knobs) -> CharacterBody3D:
	var p := PlayerBody.new()
	p.setup(knobs, PhysicsLayers.MOVE_PREDICT)
	parent.add_child(p)
	p.global_position = pos
	return p
