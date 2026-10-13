# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does one networked greybox round deliver "you can't be sure the person next to you is a person"?
# Date: 2026-10-13
extends Node
## Windowed evidence capture (--scenario=shots --shots_dir=<abs dir> --nocapture,
## host is a survivor, a bot named by --monster_name is the shapeshifter). Poses
## the bodies through the server's test hook and saves screenshots of the key views.

var game: Node


func _ready() -> void:
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _face(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path: String = Net.args.get("shots_dir", "user://") .path_join(file + ".png")
	img.save_png(path)
	print("SHOT ", path)


func _place(id: int, pos: Vector3, look_at: Vector3) -> void:
	game.teleport(id, pos, _face(pos, look_at))


func _run() -> void:
	while not game.started:
		await _wait(0.2)
	await _wait(1.0)
	var me: int = game.local_id
	var m: int = game.monster_id()
	var other := 0
	for id in game.survivors():
		if id != me:
			other = id
	var st: Dictionary = game.st
	if st[me].role == "monster":
		await _monster_run(me, st)
		return

	_place(me, Vector3(8, 0, 38.5), Vector3(3, 0, 31))
	_place(other, Vector3(4, 0, 33), Vector3(8, 0, 38))
	_place(m, Vector3(55, 0, 30), Vector3(50, 0, 30))
	await _wait(2.0)
	await _shot("01-spawn-a1")

	_place(me, Vector3(13, 0, 39), Vector3(30, 0, 39))
	_place(other, Vector3(22, 0, 39), Vector3(13, 0, 39))
	await _wait(1.0)
	await _shot("02-corridor-hs")

	var ch := int(st[other].character)
	st[m].unlocked.append(ch)
	game._handle(m, "transform", ch)
	await _wait(Knobs.f("transform_duration_s") + 0.4)
	_place(me, Vector3(30.6, 0, 25), Vector3(30.6, 0, 20))
	_place(other, Vector3(29.8, 0, 20.5), Vector3(30.6, 0, 25))
	_place(m, Vector3(31.4, 0, 20.5), Vector3(30.6, 0, 25))
	await _wait(1.0)
	await _shot("03-which-one-b1")

	st[m].form_cd_until = 0.0
	game._handle(m, "transform", -1)
	await _wait(1.0)
	await _shot("04-transforming")
	await _wait(Knobs.f("transform_duration_s"))
	_place(other, Vector3(26, 0, 18), Vector3(30, 0, 18))
	await _wait(0.6)
	await _shot("05-true-form")

	var dv: Dictionary = game.world.drives[0]
	var dp: Vector3 = dv.pos
	_place(m, Vector3(55, 0, 30), Vector3(50, 0, 30))
	var stand := dp + Vector3(0, 0, 1.4)
	if game.map.cell_kind(int(stand.z / 2.0), int(stand.x)) != "":
		stand = dp + Vector3(1.4, 0, 0)
	_place(me, stand, dp)
	await _wait(1.0)
	await _shot("06-drive-prompt")

	var tp: Vector3 = game.terminal_pos()
	_place(me, tp + Vector3(0, 0, 2.2), tp)
	await _wait(1.0)
	await _shot("07-terminal")

	game._end_round("monster", "Evidence capture: forced end")
	await _wait(1.0)
	await _shot("08-results")
	print("SHOTS DONE")
	get_tree().quit(0)


func _monster_run(me: int, st: Dictionary) -> void:
	var sv: Array = game.survivors()
	var hall := Vector3(28, 0, 22)
	_place(me, hall, hall + Vector3(0, 0, -6))
	_place(sv[0], hall + Vector3(-1, 0, -6), hall)
	if sv.size() > 1:
		_place(sv[1], Vector3(5, 0, 32), Vector3(5, 0, 30))
	await _wait(1.8)
	await _shot("09-monster-observing")
	await _wait(2.0)
	await _shot("10-monster-face-unlocked")
	print("SHOTS DONE")
	get_tree().quit(0)
