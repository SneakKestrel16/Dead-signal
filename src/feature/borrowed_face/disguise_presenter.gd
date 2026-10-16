class_name DisguisePresenter extends Node
## Client presentation of a shock or stun on a remote body (story borrowed-face/009; borrowed-face.md
## rule 10, TR-defense-011, ADR-0010 §4). The stagger plays on whatever body the client draws for the
## handle, so a disguised shapeshifter staggers as the borrowed survivor and a true form as the monster:
## the drawn body already follows the snapshot's appearance (RoundClient.colour_of), so nothing here
## copies or recolours it. The vocal cue is chosen by the appearance the body shows at that moment, never
## by the event type, role or player: the survivor's shocked grunt for C1-C5, the pain cry for the true
## form. Disguise copy rules need no client code: carried items, Downed presentation and name labels are
## never drawn on a body (ADR-0010 §7), and footsteps use the appearance's set server-side (Footsteps).
## Client only; decides nothing and emits no server event. The stagger itself is the art's hit clip
## (BodyVisual.clip_for with STAGGER while stagger_weight > 0, ADR-0010 §3); nothing here moves the body.
## Usage (client):
##   var d := DisguisePresenter.new(remotes, puppets.state_of, knobs)
##   add_child(d)   # the shock events reach on_shock through ShockPresenter (survivor-defense story 011)
##   d.cue.connect(audio.play_at)

## A vocal cue for the audio layer: catalog sound id and where the body stands.
signal cue(sound: StringName, at: Vector3)

## The true form's pain cry. Inference: no voice catalog exists yet (ADR-0013 catalog ids); named after
## Footsteps' `c0` true-form set and the CharacterDef voice_set pattern. The audio catalog settles it.
const TRUE_FORM_CUE := &"voice_c0.pain_cry"
## Survivor cue = CharacterDef.voice_set + this suffix (same inference as TRUE_FORM_CUE).
const GRUNT_SUFFIX := ".shocked_grunt"

## Shock or stun payloads that named no body and were not the own one.
var rejected: int = 0

var _remotes: Dictionary[int, Node3D]
var _state_of: Callable
var _duration_s: float
## appearance id -> survivor voice set
var _voices: Dictionary[int, StringName] = {}
## handle -> seconds since its stagger began
var _staggers: Dictionary[int, float] = {}


## `remotes`: the client's handle -> drawn body (shared, not copied). `state_of(handle) -> Dictionary`:
## the newest snapshot state of a handle (PuppetMap.state_of). The stagger lasts `stun_root_s`.
## Inference: the body stands rooted then (survivor-defense.md lock: root, then slow); the clip length
## settles it. `cast`: the survivor characters (default: the shipped files).
func _init(remotes: Dictionary[int, Node3D], state_of: Callable, knobs: Knobs,
		cast: Array[CharacterDef] = CharacterDef.load_all()) -> void:
	_remotes = remotes
	_state_of = state_of
	_duration_s = knobs.defense.stun_root_s
	for c in cast:
		if c != null:
			_voices[c.appearance_id] = c.voice_set


## ClientEventRouter handler for PlayerShocked and MonsterStunned: staggers the named body and asks for
## the cue of the appearance it shows now. The own body ({own: true}) is first person: no puppet here.
func on_shock(_tick: int, payload: Dictionary) -> void:
	if payload.get("own") == true:
		return
	var h: Variant = payload.get("body")
	if not h is int:
		rejected += 1
		return
	_staggers[h] = 0.0
	var sound := cue_of(_state_of.call(h).get("appearance", SnapshotCodec.NO_APPEARANCE))
	if sound != &"":
		var n: Node3D = _remotes.get(h)
		cue.emit(sound, n.position if n != null else Vector3.ZERO)


## The vocal cue of a body showing `appearance`; &"" when the appearance is unknown.
func cue_of(appearance: int) -> StringName:
	if appearance == CharacterDef.TRUE_FORM_APPEARANCE_ID:
		return TRUE_FORM_CUE
	if _voices.has(appearance):
		return StringName(String(_voices[appearance]) + GRUNT_SUFFIX)
	return &""


## Stagger weight of `handle` now: 1 at the hit, easing to 0 at the end; 0 when not staggering.
func stagger_weight(handle: int) -> float:
	if not _staggers.has(handle):
		return 0.0
	return 1.0 - _staggers[handle] / _duration_s


## Moves every stagger on by `delta` seconds; a stagger ends after stun_root_s or when its body goes.
func advance(delta: float) -> void:
	for h: int in _staggers.keys():
		_staggers[h] += delta
		if not _remotes.has(h) or _staggers[h] >= _duration_s:
			_staggers.erase(h)


func _process(delta: float) -> void:
	advance(delta)
