extends "res://lib.gd"
## ADR-0008 Verification Required (1) and (2). (3) tests HoldService logic, which does not exist yet.

const BASE := "res://fixtures/abstract_event.gd"


func run() -> void:
	var head := "extends \"%s\"\n\nfunc project(peer: int) -> Dictionary:\n\treturn {}\n\n" % BASE
	var void_no_return := compile(head + "func on_cancel(actor: int) -> void:\n\tprint(actor)\n")
	var void_unannotated := compile(head + "func on_cancel(actor: int):\n\tprint(actor)\n")
	var branch_missing := compile("extends \"%s\"\n\nfunc project(peer: int) -> Dictionary:\n\tif peer > 0:\n\t\treturn {}\n\nfunc on_cancel(actor: int) -> void:\n\tpass\n" % BASE)
	var ok := void_no_return == OK and branch_missing != OK
	rec("0008-1", "PASS" if ok else "FAIL", "void override with no return compiles=%s (unannotated void override=%s); typed override missing a branch return compiles=%s" % [void_no_return == OK, void_unannotated == OK, branch_missing == OK])
	await _los()
	rec("0008-3", "NOT RUN", "lock contest is a HoldService unit test; HoldService is not written yet")


## (2) Line of sight on PROJECTILE: glass blocks, a door blocker on the doors layer does not
## (doors are tested analytically), SIGHT passes glass.
func _los() -> void:
	var w := make_world("LosWorld")
	var glass := add_box(w, Vector3(0, 1.5, 2), Vector3(2, 3, 0.05), GLASS)
	var door := add_box(w, Vector3(0, 1.5, 4), Vector3(1, 2.2, 0.1), DOORS)
	await physics_frames(2)
	var space := w.get_world_3d().direct_space_state
	var eye := Vector3(0, 1.6, 0)
	var point := Vector3(0, 1.0, 6)
	var hits := {}
	for mask_name in ["PROJECTILE", "SIGHT"]:
		var mask := (WORLD | GLASS) if mask_name == "PROJECTILE" else WORLD
		var q := PhysicsRayQueryParameters3D.create(eye, point, mask)
		q.collide_with_areas = false
		var r := space.intersect_ray(q)
		hits[mask_name] = r.collider.name if r.has("collider") else "none"
	var glass_blocks: bool = hits["PROJECTILE"] == glass.name
	var sight_clear: bool = hits["SIGHT"] == "none"
	glass.queue_free()
	await physics_frames(2)
	var q2 := PhysicsRayQueryParameters3D.create(eye, point, WORLD | GLASS)
	var r2 := space.intersect_ray(q2)
	var door_ignored := not r2.has("collider")
	rec("0008-2", "PASS" if glass_blocks and sight_clear and door_ignored else "FAIL", "PROJECTILE ray hits glass=%s (got %s); SIGHT ray passes glass=%s; PROJECTILE ignores the door blocker (left to the analytic door test)=%s" % [glass_blocks, hits["PROJECTILE"], sight_clear, door_ignored])
	door.queue_free()
	w.queue_free()
	await physics_frames(2)
