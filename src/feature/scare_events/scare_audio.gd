class_name ScareAudio extends Node3D
## Client scare audio, story scare-events/008 (design/gdd/scare-events.md rules 16-18, 26; ADR-0013 §1, §4, §5).
## Presentation only: takes ScareTriggered from the ClientEventRouter and plays the scare's diegetic sound as an
## AudioStreamPlayer3D at its true origin on ScareSFX (rule 16: direction and distance come from the listener),
## and on a Major (as delivered: a gated Major arrives as Minor) a non-positional stinger on Stinger one sim tick
## later, so it never starts on the origin sound's tick (rule 17, ADR-0013 §5). Gameplay cues (every positional
## Sound entry, the presenters' cue signals) and PlayerShocked / MonsterStunned duck Ambience and ScareDuck by
## duck_db with duck_attack_s / duck_release_s (rule 18, ADR-0013 §4); no other bus is ducked, so gameplay cues
## and callouts are never masked. The stinger and scare-master scales (rule 26, 0-1) write only the Stinger and
## Scare buses: level only, never timing. No settings store yet: both stay at 1.0.
## Sounds come from the SoundBank (`scare/<scare id>`, `scare/stinger`; audio pass); an id with no entry keeps
## its generated PLACEHOLDER tone. Players are made per sound, not pooled; the AudioDirector (ADR-0013 §3)
## replaces that. The stinger file is authored loudness-normalised to the ambient beds (just under them,
## production/qa/evidence/audio/loudness.md), so its player gain stinger_max_db_rel is its level over the bed.
## ponytail: the duck holds for a fixed time per trigger (a placeholder cue's length, or duck_release_s for the
## stun events) instead of ADR-0013's start/finish counter; equivalent while every cue is a fixed-length beep.
## A scare voice line (CAPTIONS) emits `captioned` as it plays (hud.md H18; the owner shows it when captions
## are on). The recordings are distorted until no words survive (tools/audio/sounds/scares.py), so the caption
## names the sound, not a script.
## Usage (client):
##   var sa := ScareAudio.new(ScareCatalogue.load_shipped(), knobs); add_child(sa)
##   router.subscribe(&"ScareTriggered", sa.on_scare); router.subscribe(EventBatch.SOUND, sa.on_sound)
##   router.subscribe(&"PlayerShocked", sa.on_stun); router.subscribe(&"MonsterStunned", sa.on_stun)

## ADR-0013 §1 buses, looked up by name in default_bus_layout.tres.
## Emitted with a scare voice line's caption text as it plays.
signal captioned(text: String)

const SFX_BUS := &"ScareSFX"
## Scare id -> its caption (hud.md H18 "[Voice]: [text]").
const CAPTIONS := {&"recording_room": "Speaker: (distorted voice)", &"recording_script": "Speaker: (distorted voice)"}
const STINGER_BUS := &"Stinger"
const SCARE_BUS := &"Scare"
const DUCKED: Array[StringName] = [&"Ambience", &"ScareDuck"]
## SoundBank id of the stinger; a scare's diegetic sound is `scare/<scare id>`.
const STINGER_ID := &"scare/stinger"
## PLACEHOLDER tones: lengths, pitches and the diegetic peak. NOT SOURCEABLE: replaced by the sound assets.
const SFX_S := 0.6
const SFX_AMPLITUDE := 0.5
const STINGER_S := 0.8
const STINGER_HZ := 880.0

## Stinger volume scale 0-1 (rule 26); writes the Stinger bus.
var stinger_scale := 1.0:
	set(v):
		stinger_scale = clampf(v, 0.0, 1.0)
		_write.call(STINGER_BUS, linear_to_db(stinger_scale))
## Scare master volume scale 0-1 (rule 26); writes the Scare bus.
var scare_scale := 1.0:
	set(v):
		scare_scale = clampf(v, 0.0, 1.0)
		_write.call(SCARE_BUS, linear_to_db(scare_scale))

var _catalogue: ScareCatalogue
var _scare: ScareKnobs
var _tick_s: float
var _write: Callable
var _stinger_tone: AudioStream
var _bank: SoundBank
var _now := 0.0
## Start times of stingers not started yet.
var _pending: Array[float] = []
var _hold_until := -1.0
var _duck := 0.0


## `write_db(bus: StringName, db: float)` sets a bus's volume; default AudioServer by bus name (tests fake it).
## `bank`: the sound map (default the shipped one).
func _init(catalogue: ScareCatalogue, knobs: Knobs, write_db: Callable = Callable(),
		bank: SoundBank = SoundBank.load_shipped()) -> void:
	_bank = bank
	_catalogue = catalogue
	_scare = knobs.scare
	_tick_s = 1.0 / knobs.net.sim_tick_hz
	_write = write_db if write_db.is_valid() else _write_bus
	var st := bank.resolve(STINGER_ID)
	_stinger_tone = st.stream if st != null and st.stream != null 			else PlaceholderAudio.tone(STINGER_HZ, STINGER_S, ZoneAmbience.PLACEHOLDER_AMPLITUDE)
	stinger_scale = 1.0
	scare_scale = 1.0


## ClientEventRouter handler for ScareTriggered ({scare, scope, origin, intensity}).
func on_scare(_tick: int, payload: Dictionary) -> void:
	var id: Variant = payload.get("scare")
	var at: Variant = payload.get("origin")
	var entry := _catalogue.entry(id) if id is StringName else null
	if entry == null or not at is Vector3:
		return
	var p := AudioStreamPlayer3D.new()
	var e := _bank.resolve(StringName("scare/" + id))
	if e != null and e.stream != null:
		p.stream = e.stream
		p.volume_db = e.volume_db
	else:
		p.stream = PlaceholderAudio.tone(220.0 + float(absi(hash(id)) % 200), SFX_S, SFX_AMPLITUDE)
	p.bus = SFX_BUS
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.max_distance = entry.audible_range_m # ADR-0013 §2: audible exactly where it was sent
	p.top_level = true
	_start(p)
	p.global_position = at
	if CAPTIONS.has(id):
		captioned.emit(tr(CAPTIONS[id]))
	if payload.get("intensity") == ScareEntry.Intensity.MAJOR:
		_pending.append(_now + _tick_s)


## ClientEventRouter handler for EventBatch.SOUND: every positional sound is a gameplay cue (own footsteps are
## never sent to their owner), so it ducks scare audio for the placeholder cue's length.
func on_sound(_tick: int, _payload: Dictionary) -> void:
	duck_for(PlaceholderAudio.BEEP_S)


## Presenter cue signals (DisguisePresenter, ShockPresenter `cue(sound, at)`): a gameplay cue.
func on_cue(_sound: StringName, _at: Vector3) -> void:
	duck_for(PlaceholderAudio.BEEP_S)


## ClientEventRouter handler for PlayerShocked and MonsterStunned (rule 18): a timed duck_release_s hold.
func on_stun(_tick: int, _payload: Dictionary) -> void:
	duck_for(_scare.duck_release_s)


## Holds the duck at least `seconds` from now; the release ramp starts after.
func duck_for(seconds: float) -> void:
	_hold_until = maxf(_hold_until, _now + seconds)


## The duck's current gain on Ambience and ScareDuck, dB (0 = none, duck_db = full).
func duck_level_db() -> float:
	return _duck


## Diegetic scare players still alive.
func diegetic() -> Array[AudioStreamPlayer3D]:
	var out: Array[AudioStreamPlayer3D] = []
	for c in get_children():
		if c is AudioStreamPlayer3D and not c.is_queued_for_deletion():
			out.append(c)
	return out


## Stinger players still alive.
func stingers() -> Array[AudioStreamPlayer]:
	var out: Array[AudioStreamPlayer] = []
	for c in get_children():
		if c is AudioStreamPlayer and not c.is_queued_for_deletion():
			out.append(c)
	return out


## Advances pending stingers and the duck ramp by `delta` seconds.
func advance(delta: float) -> void:
	_now += delta
	while not _pending.is_empty() and _pending[0] <= _now + 1e-6:
		_pending.pop_front()
		var s := AudioStreamPlayer.new()
		s.stream = _stinger_tone
		s.bus = STINGER_BUS
		s.volume_db = _scare.stinger_max_db_rel
		_start(s)
	var target := _scare.duck_db if _now < _hold_until else 0.0
	var was := _duck
	if target < _duck:
		_duck = maxf(target, _duck + _scare.duck_db * delta / _scare.duck_attack_s)
	elif target > _duck:
		_duck = minf(target, _duck - _scare.duck_db * delta / _scare.duck_release_s)
	if _duck != was:
		for bus in DUCKED:
			_write.call(bus, _duck)


func _process(delta: float) -> void:
	advance(delta)


func _start(p: Node) -> void:
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _write_bus(bus: StringName, db: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		push_error("ScareAudio: no bus %s in the bus layout" % bus)
		return
	AudioServer.set_bus_volume_db(i, db)
