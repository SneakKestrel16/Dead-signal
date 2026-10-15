class_name RewindHistory extends RefCounted
## Per-player ring of the last `ticks` server ticks (ADR-0003 §4): feet position, capsule height and
## radius, and chest point. ServerMovement pushes every player in TickRunner's history phase; hit tests
## read it through LagCompensation. Only positions and shape are kept: eligibility is never rewound.
## Memory: 36 bytes per player per tick (ADR-0003 guardrail: 6 players x 16 ticks x about 40 bytes).
## Usage:
##   var h := RewindHistory.new(knobs.net.history_ticks)
##   h.push(tick, pid, pos, 1.8, 0.3, chest); var s := h.sample(pid, tick - 4.5); if s.ok: s.pos

var _size: int
var _tracks: Dictionary[int, Track] = {}


class Track extends RefCounted:
	var tick := PackedInt32Array()
	var pos := PackedVector3Array()
	var chest := PackedVector3Array()
	var height := PackedFloat32Array()
	var radius := PackedFloat32Array()


## `ticks` is net.history_ticks.
func _init(ticks: int) -> void:
	_size = ticks


## Records `player_id` at server tick `tick` (overwrites the slot of tick - ticks).
func push(tick: int, player_id: int, pos: Vector3, height: float, radius: float, chest: Vector3) -> void:
	var t: Track = _tracks.get(player_id)
	if t == null:
		t = Track.new()
		t.tick.resize(_size)
		t.tick.fill(-1) ## unrecorded
		t.pos.resize(_size)
		t.chest.resize(_size)
		t.height.resize(_size)
		t.radius.resize(_size)
		_tracks[player_id] = t
	var i := tick % _size
	t.tick[i] = tick
	t.pos[i] = pos
	t.chest[i] = chest
	t.height[i] = height
	t.radius[i] = radius


## Forgets a player.
func remove(player_id: int) -> void:
	_tracks.erase(player_id)


## The player at fractional server tick `tick`, interpolated between the two bracketing ticks:
## {ok: true, pos, height, radius, chest}. {ok: false} when either bracket is not in the ring (too old,
## not yet pushed, unknown player) or `tick` is not finite.
func sample(player_id: int, tick: float) -> Dictionary:
	var t: Track = _tracks.get(player_id)
	if t == null or not is_finite(tick) or tick < 0.0:
		return {"ok": false}
	var t0 := floori(tick)
	var t1 := ceili(tick)
	var i0 := t0 % _size
	var i1 := t1 % _size
	if t.tick[i0] != t0 or t.tick[i1] != t1:
		return {"ok": false}
	var w := tick - t0
	return {
		"ok": true,
		"pos": t.pos[i0].lerp(t.pos[i1], w),
		"height": lerpf(t.height[i0], t.height[i1], w),
		"radius": lerpf(t.radius[i0], t.radius[i1], w),
		"chest": t.chest[i0].lerp(t.chest[i1], w),
	}
