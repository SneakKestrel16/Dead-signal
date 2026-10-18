class_name BodySfx extends Node
## Sounds a body makes by what it is doing (entity-inventory.md Audio rows 3, 14, 15, 18, 25), read each frame
## from the snapshot action every body carries (SnapshotCodec.Action, BodyActions), the own body included:
## - Takedown struggle: a loud one-shot at the victim as it is Seized (downing-and-rescue.md V/A).
## - Release gasp: at a Seized body set free within GASP_WINDOW_S of a MonsterStunned (a stun cancelling the
##   commit; the stun's crack is the taser's own).
## - Collapse: a Seized body let go with no stun, the takedown done (Downed or Eliminated; downing-and-rescue.md
##   V/A, collapse).
## - Loops at the body while the action runs: INTERACT the interact loop (a fake hold reads as INTERACT too,
##   survivor-objectives.md rule 25: the same quiet loop), BARRICADE hammering (building or breaking: one loop,
##   inference), KNEEL the rescue effort.
## The Call for Help cry is the need_rescue callout's own voice line, not played here. Presentation only.
## Usage (client):
##   var b := BodySfx.new(SoundBank.load_shipped(), audio.play_at); add_child(b)
##   router.subscribe(&"MonsterStunned", b.on_stunned)
##   b.update(delta, [[key, position, action], ...])  # each frame, every drawn body and the own

const STRUGGLE := &"takedown_struggle"
const GASP := &"release_gasp"
const COLLAPSE := &"body_collapse"
const LOOPS: Dictionary[int, StringName] = {
	SnapshotCodec.Action.INTERACT: &"interact_loop",
	SnapshotCodec.Action.BARRICADE: &"barricade_loop",
	SnapshotCodec.Action.KNEEL: &"rescue_loop",
}
const GASP_WINDOW_S := 1.0

## Every one-shot played, [id, at], newest last (checks).
var played: Array = []
## key -> the loop id running at that body (checks).
var looping: Dictionary = {}

var _bank: SoundBank
var _play: Callable
var _last: Dictionary = {}
var _players: Dictionary = {}
var _since_stun := INF


## `play(id, at)` (PlaceholderAudio.play_at).
func _init(bank: SoundBank, play: Callable) -> void:
	_bank = bank
	_play = play


## ClientEventRouter handler for MonsterStunned: opens the release-gasp window.
func on_stunned(_tick: int, _p: Dictionary) -> void:
	_since_stun = 0.0


## Advances by `delta` seconds; `bodies` is every body shown this frame as [key, position, action].
func update(delta: float, bodies: Array) -> void:
	_since_stun += delta
	var seen := {}
	for b: Array in bodies:
		var key: Variant = b[0]
		var at: Vector3 = b[1]
		var act: int = b[2]
		seen[key] = true
		var was: int = _last.get(key, SnapshotCodec.Action.NONE)
		if act != was:
			if act == SnapshotCodec.Action.SEIZED:
				_one(STRUGGLE, at)
			elif was == SnapshotCodec.Action.SEIZED:
				_one(GASP if _since_stun <= GASP_WINDOW_S else COLLAPSE, at)
		_last[key] = act
		_set_loop(key, LOOPS.get(act, &""), at)
	for key: Variant in _last.keys():
		if not seen.has(key):
			_last.erase(key)
			_set_loop(key, &"", Vector3.ZERO)


func _one(id: StringName, at: Vector3) -> void:
	played.append([id, at])
	_play.call(id, at)


func _set_loop(key: Variant, id: StringName, at: Vector3) -> void:
	if looping.get(key, &"") != id:
		var old: AudioStreamPlayer3D = _players.get(key)
		if old != null:
			old.queue_free()
			_players.erase(key)
		if id == &"":
			looping.erase(key)
			return
		looping[key] = id
		var e := _bank.resolve(id)
		if e != null and e.stream != null:
			var p := AudioStreamPlayer3D.new()
			p.stream = e.stream
			p.bus = e.bus
			p.volume_db = e.volume_db
			add_child(p)
			_players[key] = p
			if p.is_inside_tree():
				p.play()
	var cur: AudioStreamPlayer3D = _players.get(key)
	if cur != null:
		cur.position = at
