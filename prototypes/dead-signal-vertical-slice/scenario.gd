# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does one networked greybox round deliver "you can't be sure the person next to you is a person"?
# Date: 2026-10-13
extends Node
## Host-side integration test (--scenario=full, host is the shapeshifter via
## --monster=1, two --bot=idle clients). Drives one whole round through the real
## server rules: observation, transform, disguised stun, reveal, Lunge, takedown,
## rescue, elimination, drives, terminal, exit, outcome. Prints SCENARIO PASS or
## SCENARIO FAIL <step> and quits.

var game: Node
var _fails: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(ok: bool, step: String) -> void:
	print(("CHECK ok   " if ok else "CHECK FAIL ") + step)
	if not ok:
		_fails.append(step)


func _face(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)


func _run() -> void:
	while not game.started:
		await _wait(0.2)
	await _wait(0.5)
	var m: int = game.monster_id()
	var sv: Array = game.survivors()
	if m != 1 or sv.size() < 2:
		print("SCENARIO FAIL setup (monster %d, survivors %d)" % [m, sv.size()])
		get_tree().quit(1)
		return
	var a: int = sv[0]
	var b: int = sv[1]
	var st: Dictionary = game.st
	var ch_a := int(st[a].character)
	var ch_b := int(st[b].character)
	var hall := Vector3(28, 0, 22)

	# 1. Observation: A in view at 3 m for 3.5 s unlocks A only.
	game.teleport(m, hall, _face(hall, hall + Vector3(3, 0, 0)))
	game.teleport(a, hall + Vector3(3, 0, 0), 0.0)
	game.teleport(b, Vector3(5, 0, 32), 0.0)
	await _wait(3.8)
	_check(ch_a in st[m].unlocked, "observe unlocks A")
	_check(not ch_b in st[m].unlocked, "B out of view stays locked")

	# 2. Transform into A; Lunge rejected while disguised.
	game._handle(m, "transform", ch_a)
	await _wait(Knobs.f("transform_duration_s") + 0.3)
	_check(int(st[m].form) == ch_a, "transform completes into A")
	game._handle(m, "fire", null)
	_check(st[m].lunge_state == "", "lunge rejected while disguised")

	# 3. B tasers the disguised monster: stunned, disguise kept.
	var bpos := hall + Vector3(0, 0, 3)
	game.teleport(b, bpos, _face(bpos, hall))
	await _wait(0.4)
	game._handle(b, "fire", game.bodies[b].forward())
	await _wait(0.4)
	_check(float(st[m].stun_until) > game.now(), "taser stuns disguised monster")
	_check(int(st[m].form) == ch_a, "stun keeps the disguise")
	_check(int(st[b].taser) == Knobs.i("stun_item_charges") - 1, "taser spends one cartridge")

	# 4. Back to true form after cooldown and stun.
	var wait_cd: float = maxf(float(st[m].form_cd_until), float(st[m].stun_until)) - game.now() + 0.2
	await _wait(maxf(0.1, wait_cd))
	game._handle(m, "transform", -1)
	await _wait(Knobs.f("transform_duration_s") + 0.3)
	_check(int(st[m].form) == -1, "transform back to true form")

	# 5. Lunge hits A 2 m ahead: seized, then downed after the commit.
	game.teleport(m, hall, _face(hall, hall + Vector3(2, 0, 0)))
	game.teleport(a, hall + Vector3(2, 0, 0), 0.0)
	await _wait(0.4)
	game._handle(m, "fire", null)
	await _wait(Knobs.f("lunge_windup_s") + Knobs.f("lunge_dash_s") + 0.2)
	_check(st[a].life == "seized", "lunge seizes A")
	await _wait(Knobs.f("takedown_commit_s") + 0.2)
	_check(st[a].life == "downed" and int(st[a].downs) == 1, "takedown downs A")

	# 6. B rescues A.
	var apos: Vector3 = game.bodies[a].global_position
	game.teleport(b, apos + Vector3(0, 0, 1.0), 0.0)
	await _wait(0.4)
	game._handle(b, "hold", "rescue:%d" % a)
	await _wait(Knobs.f("rescue_duration_s") + 0.4)
	_check(st[a].life == "healthy", "rescue restores A")
	game.teleport(b, Vector3(5, 0, 32), 0.0)

	# 7. Second down eliminates A.
	var cd: float = float(st[m].lunge_cd_until) - game.now() + 0.2
	await _wait(maxf(cd, float(st[a].grace_until) - game.now() + 0.2))
	var p2: Vector3 = game.bodies[a].global_position + Vector3(-2, 0, 0)
	game.teleport(m, p2, _face(p2, game.bodies[a].global_position))
	await _wait(0.4)
	game._handle(m, "fire", null)
	await _wait(Knobs.f("lunge_windup_s") + Knobs.f("lunge_dash_s") + Knobs.f("takedown_commit_s") + 0.5)
	_check(st[a].life == "eliminated", "second down eliminates A")
	game.teleport(m, Vector3(5, 0, 5), 0.0)

	# 8. B runs the objectives: two drives, dock, activation, pickup, exit.
	for k in 2:
		var dv: Dictionary = game.world.drives[k]
		game.teleport(b, dv.pos + Vector3(0.6, 0, 0), 0.0)
		await _wait(0.4)
		game._handle(b, "hold", "drive:%d" % k)
		await _wait(Knobs.f("drive_extract_s") + 0.4)
	_check(int(st[b].carrying) == 2, "B carries both drives")
	var tp: Vector3 = game.terminal_pos()
	game.teleport(b, tp + Vector3(0.8, 0, 0.8), 0.0)
	await _wait(0.4)
	game._handle(b, "hold", "term")
	await _wait(Knobs.f("dock_s") + 0.4)
	_check(int(game.world.docked) == 2, "both drives docked")
	_check(game.world.phase == "evacuation", "armed terminal starts Evacuation")
	game._handle(b, "hold", "term")
	await _wait(Knobs.f("activation_start_s") + 0.4)
	_check(bool(game.world.activating), "activation started")
	await _wait(Knobs.f("evac_activation_s") + 0.5)
	_check(bool(game.world.exit_open), "activation opens the exit")
	for k in 2:
		var dv2: Dictionary = game.world.drives[k]
		game.teleport(b, dv2.pos + Vector3(0, 0, 0.5), 0.0)
		await _wait(0.4)
		game._handle(b, "hold", "drive:%d" % k)
		await _wait(Knobs.f("pickup_s") + 0.4)
	_check(int(st[b].carrying) == 2, "B picks up the ejected drives")
	var ex: Vector3 = game.map.exit_area.get_center()
	game.teleport(b, Vector3(ex.x, 0, ex.z), 0.0)
	await _wait(1.0)
	_check(st[b].life == "escaped", "B escapes")
	_check(int(Net.last_results.get("extracted", 0)) == 2 and String(Net.last_results.get("outcome", "")) == "survivors", "round ends as a survivor win")

	print("SCENARIO PASS" if _fails.is_empty() else "SCENARIO FAIL " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)
