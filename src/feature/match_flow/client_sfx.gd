class_name ClientSfx extends Node
## The client's state-driven sounds (audio pass; entity-inventory.md Audio rows 2, 7, 8, 16, 20, 34, 35), read
## each frame from the HUD model and the own flashlight. Presentation only: nothing here reaches the server.
## - Sprint breathing (first-person-controller.md V/A): a loop heard only by the sprinting player, fading in
##   and out with the own gait.
## - Heartbeat (downing-and-rescue.md V/A): while the own body bleeds out, one beat every HEART_FAST_S, slowing
##   to HEART_SLOW_S as the bleed-out runs down. Heard by the victim only.
## - Flashlight click (survivor-defense.md V/A): on each own on/off, at once (the predicted state).
## - Generator spin-up (survivor-objectives.md V/A "Power restored"): once, on the terminal's POWERED event,
##   facility-wide at the listener.
## - Terminal activation tone (survivor-objectives.md V/A): a loop at the terminal while activation runs, its
##   pitch rising with progress; paused, it sags to TONE_STALL_PITCH and drops TONE_STALL_DB ("stalls when
##   paused"). Stops when activation ends.
## - PA chime (match-flow.md V/A, PA countdown): at each of PA_MARKS_S seconds left in Evacuation. The spoken
##   countdown waits for recorded lines (designer, spoken lines open); the chime stands in for the PA.
## - Phase stings (match-flow.md V/A): a subtle tone entering Investigation (Evacuation keeps WorldSfx's
##   alarm), a tick each second of the final TICK_FROM_S, and a win or loss sting for the own role at the end.
## - Face-unlock tick (borrowed-face.md V/A): a quiet UI tick as a borrowable face becomes available, heard by
##   the shapeshifter alone (only its HUD model carries faces).
## - Ping ticks (pings-and-callouts.md V/A): a soft tick at each ping's point, a sharper tone for a warning ping.
## Ids resolve through the SoundBank; one with no entry plays PlaceholderAudio's beep (one-shots) or nothing
## (loops). Timings are inference (no source gives them; playtest settles them).
## Usage (client):
##   var sfx := ClientSfx.new(SoundBank.load_shipped(), audio.play_at, camera.get_global_position, terminal_at, knobs)
##   add_child(sfx); router.subscribe(&"ObjectiveProgressChanged", sfx.on_objective)
##   sfx.update(delta, ClientSfx.state_of(hud_model, match_display, light.is_on()))  # each frame

const BREATH := &"breath_sprint"
const HEART := &"heartbeat"
const CLICK := &"flashlight_click"
const GENERATOR := &"generator_spinup"
const TONE := &"terminal_tone"
const PA := &"pa_chime"
const INVESTIGATION := &"phase/investigation"
const TICK := &"phase/tick"
const WIN := &"phase/win"
const LOSS := &"phase/loss"
const FACE := &"face_unlock"
const PING := &"ping/tick"
const PING_WARNING := &"ping/warning"
const HEART_FAST_S := 0.75
const HEART_SLOW_S := 1.6
const BREATH_FADE_S := 0.6 ## to full or to silence
const SILENT_DB := -60.0
const TONE_PITCH := Vector2(0.85, 1.35) ## at 0 and at full activation progress
const TONE_STALL_PITCH := 0.7
const TONE_STALL_DB := -12.0
const TONE_GLIDE_PER_S := 0.8 ## pitch units per second toward the target
const PA_MARKS_S: Array[float] = [120.0, 60.0]
const TICK_FROM_S := 30.0

## Every one-shot played, [id, at], newest last (checks).
var played: Array = []
## Shown loop state (checks): breathing level 0-1, the tone's pitch and whether it runs.
var breath_level := 0.0
var tone_pitch := 0.0
var tone_on := false

var _bank: SoundBank
var _evac_s: float
var _bleed_s: float
var _play: Callable
var _listener: Callable
var _terminal_at: Callable
var _breath: AudioStreamPlayer
var _tone: AudioStreamPlayer3D
var _light := false
var _light_known := false
var _phase := -1
var _heart_wait := 0.0
var _last_left := INF
var _ended := false
var _powered := false
var _faces := -1


## `play(id, at)` (PlaceholderAudio.play_at); `listener() -> Vector3`; `terminal_at() -> Vector3` (the active
## terminal, Vector3.INF while unknown).
## `knobs`: the activation length (objectives.evac_activation_s) and bleed-out length (downing.bleedout_s).
func _init(bank: SoundBank, play: Callable, listener: Callable, terminal_at: Callable, knobs: Knobs) -> void:
	_bank = bank
	_evac_s = knobs.objectives.evac_activation_s
	_bleed_s = knobs.downing.bleedout_s
	_play = play
	_listener = listener
	_terminal_at = terminal_at
	_breath = _loop_player(BREATH, AudioStreamPlayer.new()) as AudioStreamPlayer
	_tone = _loop_player(TONE, AudioStreamPlayer3D.new()) as AudioStreamPlayer3D


## The frame's inputs from the HUD model, the match display and the own flashlight: {phase, left_s, sprint,
## bleed_s, light, activation, ended, won}.
static func state_of(model: HudModel, display: MatchDisplay, light_on: bool) -> Dictionary:
	var won := false
	if display.is_ended():
		var survivors_won := display.outcome() == MatchFlow.Outcome.SURVIVORS_WIN
		won = survivors_won != model.is_shapeshifter()
	return {"phase": model.phase(), "left_s": model.time_remaining_s(),
		"sprint": model.own_state().get("gait", -1) == MovementStep.Gait.SPRINT and not model.spectating(),
		"bleed_s": model.bleed_out_s(), "light": light_on and not model.spectating(),
		"activation": model.activation(), "ended": display.is_ended(), "won": won,
		"faces": model.faces().filter(func(f: Dictionary) -> bool: return f["available"]).size()}


## ClientEventRouter handler for ObjectiveProgressChanged: the generator on the terminal's POWERED event.
func on_objective(_tick: int, p: Dictionary) -> void:
	if p.get("objective") == SurvivorObjectives.TERMINAL_ID and p.get("state") == SurvivorObjectives.TerminalState.POWERED \
			and not _powered:
		_powered = true
		_one(GENERATOR, _listener.call())


## ClientEventRouter handler for EventBatch.PING ({kind, point, ...}): the tick at the pinged point.
func on_ping(_tick: int, p: Dictionary) -> void:
	if p.get("point") is Vector3 and p.get("kind") is int:
		_one(PING_WARNING if p["kind"] in PingCalloutHud.WARNINGS else PING, p["point"])


## Advances every sound by `delta` seconds against frame state `s` (state_of).
func update(delta: float, s: Dictionary) -> void:
	var here: Vector3 = _listener.call()
	var faces: int = s.get("faces", 0)
	if _faces >= 0 and faces > _faces:
		_one(FACE, here)
	_faces = faces
	if s["ended"]:
		if not _ended:
			_ended = true
			_one(WIN if s["won"] else LOSS, here)
		_set_breath(0.0)
		_set_tone(false, 0.0, false, delta)
		return
	if s["phase"] != _phase:
		if _phase != -1 and s["phase"] == MatchFlow.Phase.INVESTIGATION:
			_one(INVESTIGATION, here)
		_phase = s["phase"]
	var left: float = s["left_s"]
	if _phase == MatchFlow.Phase.EVACUATION and _last_left != INF:
		for mark in PA_MARKS_S:
			if _last_left > mark and left <= mark:
				_one(PA, here)
		if left <= TICK_FROM_S and ceilf(left) < ceilf(_last_left) and left > 0.0:
			_one(TICK, here)
	_last_left = left
	if s["light"] != _light:
		if _light_known:
			_one(CLICK, here)
		_light = s["light"]
	_light_known = true
	var target := 1.0 if s["sprint"] else 0.0
	_set_breath(move_toward(breath_level, target, delta / BREATH_FADE_S))
	_heartbeat(delta, s["bleed_s"], here)
	var act: Dictionary = s["activation"]
	var running: bool = not act.is_empty() and act["remaining_s"] > 0.0
	var progress := 0.0
	if running:
		progress = 1.0 - clampf(act["remaining_s"] / maxf(_evac_s, 0.001), 0.0, 1.0)
	_set_tone(running, progress, running and act["paused"], delta)


func _heartbeat(delta: float, bleed_s: float, here: Vector3) -> void:
	if bleed_s < 0.0:
		_heart_wait = 0.0
		return
	_heart_wait -= delta
	if _heart_wait > 0.0:
		return
	_one(HEART, here)
	## slows as the bleed-out runs down: fast with most of it left, slow near the end
	_heart_wait += lerpf(HEART_SLOW_S, HEART_FAST_S, clampf(bleed_s / maxf(_bleed_s, 0.001), 0.0, 1.0))


func _set_breath(level: float) -> void:
	breath_level = level
	if _breath == null:
		return
	if level <= 0.0:
		if _breath.playing:
			_breath.stop()
		return
	_breath.volume_db = lerpf(SILENT_DB, _bank.resolve(BREATH).volume_db, sqrt(level))
	if not _breath.playing and _breath.is_inside_tree():
		_breath.play()


func _set_tone(on: bool, progress: float, paused: bool, delta: float) -> void:
	if not on:
		tone_on = false
		tone_pitch = 0.0
		if _tone != null and _tone.playing:
			_tone.stop()
		return
	var want := TONE_STALL_PITCH if paused else lerpf(TONE_PITCH.x, TONE_PITCH.y, progress)
	tone_pitch = want if not tone_on else move_toward(tone_pitch, want, TONE_GLIDE_PER_S * delta)
	tone_on = true
	if _tone == null:
		return
	var at: Vector3 = _terminal_at.call()
	_tone.position = at if at.is_finite() else _listener.call()
	_tone.pitch_scale = maxf(tone_pitch, 0.01)
	_tone.volume_db = _bank.resolve(TONE).volume_db + (TONE_STALL_DB if paused else 0.0)
	if not _tone.playing and _tone.is_inside_tree():
		_tone.play()


func _one(id: StringName, at: Vector3) -> void:
	played.append([id, at])
	_play.call(id, at)


## A loop player for `id`, child of this node, or null when the bank has no stream for it.
func _loop_player(id: StringName, p: Node) -> Node:
	var e := _bank.resolve(id)
	if e == null or e.stream == null:
		p.free()
		return null
	p.set(&"stream", e.stream)
	p.set(&"bus", e.bus)
	add_child(p)
	return p
