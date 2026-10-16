class_name LungePresenter extends Node3D
## Client presentation of the Predatory Lunge (story monster-abilities/007; monster-abilities.md rule 5,
## Visual/Audio Requirements, Impact Moments; ADR-0013 §2-3). Takes the server's Lunge sounds (Sound
## entries from the ClientEventRouter: MonsterAbilities.CUE_SOUND, SCRAPE_SOUND, HIT_SOUND) and plays:
## - the wind-up cue from the sound's position (AudioStreamPlayer3D, so it is heard from the monster's
##   bearing) and pose() &"coil" for lunge_windup_s: the rule 5 telegraph, drawn as the true form's
##   Lunge_Coil clip by BodyVisual (only the true form plays lunge clips);
## - on a miss, the scrape and pose() &"stumble" for miss_slow_s (Lunge_Stumble);
## - on a server-confirmed hit, the hit sound and the hit-stop: every remote body holds the pose it had for
##   lunge_hit_stop_s. Presentation only: the simulation, the own body, the camera and input never stop.
## VFX ASSET-085: a hit throws a short dust-and-cloth burst at the survivor (vfx_lunge_hit, no blood: art
## bible §5), a miss a floor scrape of dust at the monster (vfx_lunge_scrape). No flash, so no
## reduced-flash variant. It decides nothing and emits nothing. Sounds reach only clients within the send radius, so a viewer
## farther than lunge_cue_radius_m sees no coil (inference: the GDD ties the pose to the cue; a snapshot
## Lunge flag would show it at any range if the designer wants that).
## Sounds are the SoundBank entries (audio pass), each set's generated tone where the bank has none; the
## three players are built once here, on the entries' bus. The body is never squashed or tilted here: the
## clips carry the pose.
## Must process after RoundClient draws remotes (it is RoundClient's child; tree order runs it later).
## Usage:
##   var fx := LungePresenter.new(knobs, round_client.remotes)
##   round_client.add_child(fx); router.subscribe(EventBatch.SOUND, fx.on_sound)

## Placeholder tones: [start Hz, end Hz, noise mix 0-1, seconds or 0 = the timed state's length].
const TONES := {
	MonsterAbilities.CUE_SOUND: [140.0, 420.0, 0.15, 0.0],
	MonsterAbilities.SCRAPE_SOUND: [90.0, 60.0, 0.8, 0.4],
	MonsterAbilities.HIT_SOUND: [70.0, 40.0, 0.4, 0.2],
}
const MIX_RATE := 22050
## Hit burst height over the survivor's feet. NOT SOURCEABLE: chest height, as ShockPresenter.CHEST_UP.
const HIT_UP := Vector3(0.0, 1.1, 0.0)
## Inverse-distance unit size: about -16 dB at the 20 m cue radius (placeholder; the catalog tunes it).
const UNIT_SIZE := 3.0

var _knobs: Knobs
var _remotes: Dictionary[int, Node3D]
var _players: Dictionary[StringName, AudioStreamPlayer3D] = {}
var _coil_left := 0.0
var _stumble_left := 0.0
var _stop_left := 0.0
## handle -> transform held during the hit-stop.
var _held: Dictionary[int, Transform3D] = {}
## vfx_ name -> burst
var _bursts: Dictionary[StringName, GPUParticles3D] = {}


## `remotes`: RoundClient.remotes (handle -> body), read live; the hit-stop holds their transforms.
## `bank`: the sound map; each set plays its entry, else its placeholder tone.
func _init(knobs: Knobs, remotes: Dictionary[int, Node3D], bank: SoundBank = SoundBank.load_shipped()) -> void:
	_knobs = knobs
	_remotes = remotes
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
	# Looks NOT SOURCEABLE (VFX art pass settles them): grey dust with jumpsuit-cloth flecks; floor dust.
	for b: GPUParticles3D in [
		VfxBurst.make(&"lunge_hit", Color(0.62, 0.6, 0.55, 0.8), 18, 0.5, Vector2(1.0, 2.5), 90.0,
				Vector3(0, -4.0, 0), 0.12, VfxBurst.Shape.QUAD, false, Vector3.BACK),
		VfxBurst.make(&"lunge_scrape", Color(0.5, 0.48, 0.44, 0.7), 14, 0.8, Vector2(0.3, 1.0), 70.0,
				Vector3(0, -1.0, 0), 0.2),
	]:
		add_child(b)
		_bursts[b.name] = b


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
		VfxBurst.fire(_bursts[&"vfx_lunge_scrape"], at)
	else:
		VfxBurst.fire(_bursts[&"vfx_lunge_hit"], at + HIT_UP)
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


## The burst named `vfx_name` (tests).
func burst(vfx_name: StringName) -> GPUParticles3D:
	return _bursts[vfx_name]


## The player of `sound_set` (tests).
func player(sound_set: StringName) -> AudioStreamPlayer3D:
	return _players[sound_set]


## Advances the timed poses by `delta` seconds and holds the remote bodies during a hit-stop.
func advance(delta: float) -> void:
	_coil_left = maxf(_coil_left - delta, 0.0)
	_stumble_left = maxf(_stumble_left - delta, 0.0)
	_stop_left = maxf(_stop_left - delta, 0.0)
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
