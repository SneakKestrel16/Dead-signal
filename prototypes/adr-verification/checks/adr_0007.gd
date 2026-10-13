extends "res://lib.gd"
## ADR-0007 Verification Required (2), (4)-(9). (1) is answered by the spike's project.godot;
## (3) is covered by ADR-0002's replay check.


func run() -> void:
	var c := CharacterBody3D.new()
	rec("0007-2", "OBSERVED", "CharacterBody3D defaults: safe_margin=%s max_slides=%d wall_min_slide_angle=%.1f° floor_max_angle=%.1f° floor_snap_length=%s floor_block_on_wall=%s" % [c.safe_margin, c.max_slides, rad_to_deg(c.wall_min_slide_angle), rad_to_deg(c.floor_max_angle), c.floor_snap_length, c.floor_block_on_wall])
	c.free()
	rec("0007-1", "PASS", "3d/physics_engine=\"Jolt Physics\" in this project.godot; engine reports %s" % ProjectSettings.get_setting("physics/3d/physics_engine"))
	await _stand_up()
	await _shapes()
	await _seam()
	await _same_tick()
	for angle in [40.0, 41.0, 45.0]:
		await _slope(angle, true, 40.5)
	await _slope(41.0, false, 40.5)
	for angle in [39.9, 40.0, 40.4, 40.6, 41.0]:
		await _slope(angle, true, 40.0)
	await _slope(41.0, false, 40.0)
	await _slope(50.0, false, 40.0)
	rec("0007-8", "NOT RUN", "screen_relative under stretch scaling needs a real window and mouse; headless events are synthetic")


## (4) Stand-up check: intersect_shape with the standing capsule raised 0.01 m, margin 0, own RID excluded.
func _stand_up() -> void:
	var w := make_world("StandWorld")
	add_box(w, Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	add_box(w, Vector3(0, 1.5 + 0.25, 0), Vector3(2, 0.5, 2))   # ceiling underside at 1.5 m
	var p := make_player(w, Vector3(0, 0, 0))
	var open := make_player(w, Vector3(5, 0, 0))
	await physics_frames(2)
	var space := w.get_world_3d().direct_space_state
	var results := {}
	for entry in [["under_ceiling", p, true], ["open_floor", open, true], ["open_no_exclude", open, false]]:
		var body: CharacterBody3D = entry[1]
		var cap := CapsuleShape3D.new()
		cap.radius = 0.30
		cap.height = 1.8
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.transform = Transform3D(Basis(), body.global_position + Vector3(0, 0.9 + 0.01, 0))
		q.margin = 0.0
		q.collision_mask = WORLD | GLASS | DOORS | PLAYERS
		if entry[2]:
			q.exclude = [body.get_rid()]
		results[entry[0]] = space.intersect_shape(q).size()
	var ok: bool = results["under_ceiling"] > 0 and results["open_floor"] == 0 and results["open_no_exclude"] > 0
	rec("0007-4", "PASS" if ok else "FAIL", "overlaps: under a 1.5 m ceiling=%d (blocked), open floor with own RID excluded=%d (clear), open floor without exclude=%d (own capsule)" % [results["under_ceiling"], results["open_floor"], results["open_no_exclude"]])
	w.queue_free()
	await physics_frames(2)


## (5) Code-built capsules are per player.
func _shapes() -> void:
	var w := make_world("ShapeWorld")
	var a := make_player(w, Vector3(0, 0, 0))
	var b := make_player(w, Vector3(3, 0, 0))
	var sa: CapsuleShape3D = (a.get_child(0) as CollisionShape3D).shape
	var sb: CapsuleShape3D = (b.get_child(0) as CollisionShape3D).shape
	sa.height = 1.2
	var ok: bool = sa != sb and sa.get_rid() != sb.get_rid() and is_equal_approx(sb.height, 1.8)
	rec("0007-5", "PASS" if ok else "FAIL", "two players' CapsuleShape3D.new(): distinct=%s, distinct RIDs=%s, shrinking one leaves the other at h=%.1f" % [sa != sb, sa.get_rid() != sb.get_rid(), sb.height])
	w.queue_free()
	await physics_frames(2)


## (6) Walk across a seam between two coplanar floor boxes.
func _seam() -> void:
	var w := make_world("SeamWorld")
	add_box(w, Vector3(0, -0.5, 2.5), Vector3(4, 1, 5))
	add_box(w, Vector3(0, -0.5, 7.5), Vector3(4, 1, 5))
	var p := make_player(w, Vector3(0, 0, 1))
	await physics_frames(2)
	var min_speed := 99.0
	var max_dy := 0.0
	for t in 120:
		await tree.physics_frame
		step(p, Vector3(0, 0, 1))
		if t > 10:
			min_speed = minf(min_speed, Vector2(p.velocity.x, p.velocity.z).length())
			max_dy = maxf(max_dy, absf(p.global_position.y))
	var ok: bool = min_speed > 3.96 and max_dy < 0.01 and p.global_position.z > 6.0
	rec("0007-6", "PASS" if ok else "FAIL", "walk at 4.0 m/s across the z=5 seam: min horizontal speed %.3f, max |y| %.4f, end z %.2f" % [min_speed, max_dy, p.global_position.z])
	w.queue_free()
	await physics_frames(2)


## (7) Same-frame query visibility after position and shape changes. Each case starts settled.
func _same_tick() -> void:
	var w := make_world("TickWorld")
	add_box(w, Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	var space := w.get_world_3d().direct_space_state
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	var seen := func(pos: Vector3) -> bool:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = probe
		q.collision_mask = PLAYERS
		q.transform = Transform3D(Basis(), pos)
		return space.intersect_shape(q).size() > 0
	var out := {}
	# a) teleport by global_position
	var a := make_player(w, Vector3(0, 0, 0))
	await physics_frames(3)
	a.global_position = Vector3(0, 0, 3)
	out["teleport_new_same"] = seen.call(Vector3(0, 0.9, 3))
	out["teleport_old_same"] = seen.call(Vector3(0, 0.9, 0))
	await tree.physics_frame
	out["teleport_new_next"] = seen.call(Vector3(0, 0.9, 3))
	a.queue_free()
	# b) move_and_slide 1 m
	var b := make_player(w, Vector3(6, 0, 0))
	await physics_frames(3)
	b.velocity = Vector3(0, 0, 60)
	b.move_and_slide()
	out["slide_new_same"] = seen.call(Vector3(6, 0.9, b.global_position.z))
	out["slide_old_same"] = seen.call(Vector3(6, 0.9, 0))
	b.queue_free()
	# c) disable the shape
	var c := make_player(w, Vector3(12, 0, 0))
	await physics_frames(3)
	(c.get_child(0) as CollisionShape3D).disabled = true
	out["disabled_seen_same"] = seen.call(Vector3(12, 0.9, 0))
	await tree.physics_frame
	out["disabled_seen_next"] = seen.call(Vector3(12, 0.9, 0))
	c.queue_free()
	# d) shrink the capsule to 1.2 m (top now at 1.2)
	var d := make_player(w, Vector3(18, 0, 0))
	await physics_frames(3)
	var dcs := d.get_child(0) as CollisionShape3D
	(dcs.shape as CapsuleShape3D).height = 1.2
	dcs.position.y = 0.6
	out["shrunk_top_seen_same"] = seen.call(Vector3(18, 1.55, 0))
	await tree.physics_frame
	out["shrunk_top_seen_next"] = seen.call(Vector3(18, 1.55, 0))
	d.queue_free()
	# e) rotated move order: B teleports into A's path, A moves into it in the same frame
	var ea := make_player(w, Vector3(-6, 0, 0))
	var eb := make_player(w, Vector3(-10, 0, 0))
	await physics_frames(3)
	eb.global_position = Vector3(-6, 0, 1.0)
	ea.velocity = Vector3(0, 0, 60)
	ea.move_and_slide()
	out["mover_blocked_by_teleported_same"] = ea.global_position.z < 0.5
	ea.queue_free()
	eb.queue_free()
	print("  same-tick detail: ", out)
	var instant: bool = out["teleport_new_same"] and out["slide_new_same"] and not out["disabled_seen_same"] and not out["shrunk_top_seen_same"] and out["mover_blocked_by_teleported_same"]
	rec("0007-7", "PASS" if instant else "FAIL", "same physics frame (next frame in brackets): teleport visible=%s [%s], old spot still occupied=%s; move_and_slide result visible=%s, old spot=%s; disabled shape still hit=%s [%s]; shrunk capsule top still hit=%s [%s]; move_and_slide blocked by a body teleported this frame=%s" % [out["teleport_new_same"], out["teleport_new_next"], out["teleport_old_same"], out["slide_new_same"], out["slide_old_same"], out["disabled_seen_same"], out["disabled_seen_next"], out["shrunk_top_seen_same"], out["shrunk_top_seen_next"], out["mover_blocked_by_teleported_same"]])
	w.queue_free()
	await physics_frames(2)


## (9) Walk into a slope for 2 s; record the height reached.
func _slope(angle: float, block: bool, max_angle: float) -> void:
	var w := make_world("SlopeWorld")
	add_box(w, Vector3(0, -0.5, 5), Vector3(4, 1, 20))
	add_wedge(w, 2.0, angle, 1.0)
	var p := make_player(w, Vector3(0, 0, 0), block, max_angle)
	await physics_frames(2)
	var max_y := 0.0
	var trace: Array[String] = []
	for t in 120:
		await tree.physics_frame
		step(p, Vector3(0, 0, 1))
		max_y = maxf(max_y, p.global_position.y)
		if false:
			trace.append("t%d y=%.2f floor=%s wall=%s n=%s" % [t, p.global_position.y, p.is_on_floor(), p.is_on_wall(), p.get_floor_normal() if p.is_on_floor() else (p.get_wall_normal() if p.is_on_wall() else Vector3.ZERO)])
	if not trace.is_empty():
		print("  slope 41 trace: ", "; ".join(trace))
	var climbs := max_y > 0.95
	var expect_climb := angle <= 40.0
	var id := "0007-9 (%.1f° slope, floor_max_angle %.1f°, floor_block_on_wall=%s)" % [angle, max_angle, block]
	var verdict := "OBSERVED"
	if block and angle in [40.0, 41.0]:
		verdict = "PASS" if climbs == expect_climb else "FAIL"
	rec(id, verdict, "max height on a 1 m wedge after 2 s walking into it: %.3f m (climbed=%s)" % [max_y, climbs])
	w.queue_free()
	await physics_frames(2)
