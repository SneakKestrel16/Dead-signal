class_name LungePresenter extends Node3D
## Client presentation of the Predatory Lunge (story monster-abilities/007; monster-abilities.md rule 5,
## Visual/Audio Requirements, Impact Moments; ADR-0013 §2-3). Takes the server's Lunge sounds (Sound
## entries from the ClientEventRouter: MonsterAbilities.CUE_SOUND, SCRAPE_SOUND, HIT_SOUND) and plays:
## - the wind-up cue from the sound's position (AudioStreamPlayer3D, so it is heard from the monster's
##   bearing) and the coil pose on the monster's remote body for lunge_windup_s;
## - on a miss, the scrape and a stumble for miss_slow_s;
## - on a server-confirmed hit, the hit sound and the hit-stop: every remote body holds the pose it had for
##   lunge_hit_stop_s. Presentation only: the simulation, the own body, the camera and input never stop.
## It decides nothing and emits nothing. Sounds reach only clients within the send radius, so a viewer
## farther than lunge_cue_radius_m sees no coil (inference: the GDD ties the pose to the cue; a snapshot
## Lunge flag would show it at any range if the designer wants that).
## Sounds are the SoundBank entries (audio pass), each set's generated tone where the bank has none; the
## three players are built once here, on the entries' bus. GREYBOX: a squashed mesh for the coil, a forward
## tilt for the stumble.
## Must process after RoundClient draws remotes (it is RoundClient's child; tree order runs it later).
## Usage:
##   var fx := LungePresenter.new(knobs, round_client.remotes, is_monster_handle)
##   round_client.add_child(fx); router.subscribe(EventBatch.SOUND, fx.on_sound)

## Placeholder pose sizes (greybox; replaced by the art pass): coil squash and the stumble's peak tilt.
const COIL_SCALE := Vector3(1.2, 0.65, 1.2)
const STUMBLE_TILT_DEG := 20.0
## Placeholder tones: [start Hz, end Hz, noise mix 0-1, seconds or 0 = the timed state's length].
const TONES := {
	MonsterAbilities.CUE_SOUND: [140.0, 420.0, 0.15, 0.0],
	MonsterAbilities.SCRAPE_SOUND: [90.0, 60.0, 0.8, 0.4],
	MonsterAbilities.HIT_SOUND: [70.0, 40.0, 0.4, 0.2],
}
const MIX_RATE := 22050
## Inverse-distance unit size: about -16 dB at the 20 m cue radius (placeholder; the catalog tunes it).
const UNIT_SIZE := 3.0

var _knobs: Knobs
var _remotes: Dictionary[int, Node3D]
var _is_monster: Callable
var _players: Dictionary[StringName, AudioStreamPlayer3D] = {}
var _coil_left := 0.0
var _stumble_left := 0.0
var _stop_left := 0.0
## handle -> transform held during the hit-stop.
var _held: Dictionary[int, Transform3D] = {}


## `remotes`: RoundClient.remotes (handle -> body with a "Mesh" child), read live. `is_monster(handle)
## -> bool`: the handle is the shapeshifter's body.
## `bank`: the sound map; each set plays its entry, else its placeholder tone.
func _init(knobs: Knobs, remotes: Dictionary[int, Node3D], is_monster: Callable,
		bank: SoundBank = SoundBank.load_shipped()) -> void:
	_knobs = knobs
	_remotes = remotes
	_is_monster = is_monster
	process_priority = 1
	for s: StringName in TONES:
		var t: Array = TONES[s]
		var secs: float = t[3] if t[3] > 0.0 else knobs.ability.lunge_windup_s
		var p := AudioStreamPlayer3D.new()
		var e := bank.resolve(s)
		if e != null and e.stream != null:
			p.stream = e.stream
			p.bus = e.bus
			p.volume_db = e.volume_db
		else:
			p.stream = tone(t[0], t[1], t[2], secs)
		p.max_distance = knobs.ability.lunge_cue_radius_m ## ADR-0013: equals the send radius
		p.unit_size = UNIT_SIZE
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_players[s] = p


## ClientEventRouter handler for EventBatch.SOUND; ignores every other sound set.
func on_sound(_tick: int, payload: Dictionary) -> void:
	var s: StringName = payload.get("set", &"")
	var at: Variant = payload.get("pos")
	if not _players.has(s) or not at is Vector3:
		return
	_players[s].global_position = at
	_players[s].play()
	_coil_left = 0.0
	if s == MonsterAbilities.CUE_SOUND:
		_coil_left = _knobs.ability.lunge_windup_s
		_stumble_left = 0.0
	elif s == MonsterAbilities.SCRAPE_SOUND:
		_stumble_left = _knobs.ability.miss_slow_s
	else:
		_stop_left = _knobs.ability.lunge_hit_stop_s
		_held.clear()
		for h: int in _remotes:
			_held[h] = _remotes[h].transform


## What is showing now: &"hit_stop", &"coil", &"stumble" or &"" (tests and the round_view capture bot).
func pose() -> StringName:
	if _stop_left > 0.0:
		return &"hit_stop"
	if _coil_left > 0.0:
		return &"coil"
	return &"stumble" if _stumble_left > 0.0 else &""


## The player of `sound_set` (tests).
func player(sound_set: StringName) -> AudioStreamPlayer3D:
	return _players[sound_set]


## Advances the timed poses by `delta` seconds and writes them onto the remote bodies.
func advance(delta: float) -> void:
	_coil_left = maxf(_coil_left - delta, 0.0)
	_stumble_left = maxf(_stumble_left - delta, 0.0)
	_stop_left = maxf(_stop_left - delta, 0.0)
	for h: int in _remotes:
		if not _is_monster.call(h):
			continue
		var mesh := _remotes[h].get_node_or_null(^"Mesh") as Node3D
		if mesh == null:
			continue
		mesh.scale = COIL_SCALE if _coil_left > 0.0 else Vector3.ONE
		mesh.position.y = _knobs.controller.capsule_height_m * 0.5 * mesh.scale.y ## feet stay on the floor
		## forward lean, straightening linearly over the miss slow
		mesh.rotation.x = -deg_to_rad(STUMBLE_TILT_DEG) * _stumble_left / _knobs.ability.miss_slow_s
	if _stop_left > 0.0:
		for h: int in _held:
			if _remotes.has(h):
				_remotes[h].transform = _held[h]


func _process(delta: float) -> void:
	advance(delta)


## Placeholder tone: a sweep from `from_hz` to `to_hz` mixed with `noise` of white noise, `secs` long,
## 16-bit mono, with a short attack and a linear fade. Fixed noise seed: the same bytes every run.
static func tone(from_hz: float, to_hz: float, noise: float, secs: float) -> AudioStreamWAV:
	var n := int(secs * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(from_hz, to_hz, t) / MIX_RATE
		var v := sin(phase) * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise
		data.encode_s16(i * 2, int(v * minf(t * 20.0, 1.0) * (1.0 - t) * 0.8 * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w
