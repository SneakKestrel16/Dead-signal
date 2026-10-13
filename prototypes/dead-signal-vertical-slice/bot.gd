# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does one networked greybox round deliver "you can't be sure the person next to you is a person"?
# Date: 2026-10-13
extends Node
## Test bot for a client started with --bot=<mode>: "idle" stands still (scenario
## tests move it), "wander" walks and turns at random (soak).

var game: Node
var _next := 0.0


func _physics_process(_dt: float) -> void:
	if game == null or not game.started:
		return
	var me: SlicePlayer = game.bodies.get(game.local_id)
	if me == null or Net.args.get("bot", "idle") != "wander":
		return
	var t: float = game.now()
	if t >= _next:
		_next = t + randf_range(0.5, 2.0)
		me.yaw += randf_range(-1.5, 1.5)
		me.bot_move = Vector2(randf_range(-0.3, 0.3), -1.0)
		me.bot_sprint = randf() < 0.3
