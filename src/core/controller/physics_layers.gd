class_name PhysicsLayers
## The four physics layers and the four query masks (ADR-0007 §5). Nothing else defines a layer
## number: every collision_layer, collision_mask and query mask in src/ is built from these
## (enforced by tests/integration/first-person-controller/body_collision_test.gd).
## Usage: `body.collision_mask = PhysicsLayers.MOVE_SERVER`

## No layer: a body that collides with nothing (Out, hidden).
const NONE := 0
## Walls, floors, ramp colliders, static props.
const WORLD := 1 << 0
## Glass partitions and windows.
const GLASS := 1 << 1
## One blocker per door, enabled while closed or barricaded.
const DOORS := 1 << 2
## Player capsules.
const PLAYERS := 1 << 3

## Server player movement.
const MOVE_SERVER := WORLD | GLASS | DOORS | PLAYERS
## Client prediction: doors from replicated state; other players are corrected by the server.
const MOVE_PREDICT := WORLD | GLASS | DOORS
## Sight rays (observation, pings, lunge line of sight): glass does not block sight.
const SIGHT := WORLD
## Taser ray, lunge dash path, interaction blocking.
const PROJECTILE := WORLD | GLASS
