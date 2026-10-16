class_name PlaceholderAudio extends Node3D
## Client audio sink (story survivor-defense/011; audio pass, design/game-brief.md): plays every cue and
## positional server sound at its position from the SoundBank (stream, bus, gain, pitch). Footsteps arrive as
## Sound entries too (`c<appearance>.<gait>`) and take the surface of the zone they land in (map data). An id
## with no bank entry plays the PLACEHOLDER beep, pitched per id so it can be told apart by ear, on the
## caller's bus. Sets with their own presenter (distortion, lunge) are skipped here so they never play twice.
## The AudioDirector (ADR-0013 §3, pooling) still replaces this class.
## Usage (client):
##   var audio := PlaceholderAudio.new(SoundBank.load_shipped(), map); add_child(audio)
##   router.subscribe(EventBatch.SOUND, audio.on_sound); presenter.cue.connect(audio.play_at)

## Entries kept in `played`, newest last.
const LOG_CAP := 32
## Placeholder beep: length, tone and mix rate. NOT SOURCEABLE: replaced by the sound assets.
const BEEP_S := 0.12
const BEEP_HZ := 660.0
const MIX_HZ := 22050
## ADR-0013 §1: every sound this sink plays is a gameplay cue (footsteps, lunge, stun, distortion), which
## scare ducking never writes (story scare-events/008).
const BUS := &"GameplayCues"
## Sets played by TransformPresenter (BorrowedFace.DISTORTION_SOUND) and LungePresenter
## (MonsterAbilities.CUE_SOUND, SCRAPE_SOUND, HIT_SOUND); literals because core does not see features.
const OWNED_ELSEWHERE: Array[StringName] = [&"distortion", &"lunge_cue", &"lunge_scrape", &"lunge_hit"]

## [sound, at] of the latest plays, at most LOG_CAP (checks and the evidence run's log).
var played: Array = []
## Sound entries with a bad payload.
var rejected: int = 0

var _beep: AudioStreamWAV
var _bank: SoundBank
var _queries: MapQueries
var _zone_of: Dictionary[StringName, StringName] = {}


## `bank`: the sound map (default the shipped one). `map`: where footstep surfaces come from (null = no
## surface: every footstep takes its id's surface-less entry).
func _init(bank: SoundBank = SoundBank.load_shipped(), map: MapData = null) -> void:
	_beep = tone(BEEP_HZ, BEEP_S, 12000.0 / 32767.0)
	_bank = bank
	if map != null:
		_queries = MapQueries.new(map)
		for v in map.volumes:
			_zone_of[v.id] = v.zone


## The footstep surface at `at` (SoundBank.surface_of_zone of its volume's zone), &"" outside the map.
func surface_at(at: Vector3) -> StringName:
	if _queries == null:
		return &""
	var vol := _queries.volume_at(at)
	return _bank.surface_of_zone.get(_zone_of.get(vol, &""), &"") if vol != &"" else &""


## A PLACEHOLDER 16-bit mono sine of `hz` lasting `seconds` at peak `amplitude` (0-1), fading out linearly.
static func tone(hz: float, seconds: float, amplitude: float) -> AudioStreamWAV:
	var n := int(seconds * MIX_HZ)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var fade := 1.0 - float(i) / n
		data.encode_s16(i * 2, int(sin(TAU * hz * i / MIX_HZ) * fade * amplitude * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_HZ
	w.data = data
	return w


## ClientEventRouter handler for EventBatch.SOUND entries ({pos, set}).
func on_sound(_tick: int, payload: Dictionary) -> void:
	var at: Variant = payload.get("pos")
	var sound: Variant = payload.get("set")
	if not (at is Vector3 and sound is StringName):
		rejected += 1
		return
	if not sound in OWNED_ELSEWHERE:
		play_at(sound, at)


## Plays `sound` at `at` (global position) once: its bank entry, or the beep on audio bus `bus` (callouts
## pass Voice, never a ducked bus).
func play_at(sound: StringName, at: Vector3, bus: StringName = &"Master") -> void:
	played.append([sound, at])
	if played.size() > LOG_CAP:
		played.pop_front()
	var p := AudioStreamPlayer3D.new()
	var e := _bank.resolve(sound, surface_at(at))
	if e != null and e.stream != null:
		p.stream = e.stream
		p.bus = e.bus
		p.volume_db = e.volume_db + _bank.extra_db(sound)
		p.pitch_scale = e.pitch_scale
	else:
		p.stream = _beep
		p.bus = bus
		p.pitch_scale = 0.75 + float(absi(hash(sound)) % 50) / 100.0
	p.position = at
	add_child(p)
	p.finished.connect(p.queue_free)
	if p.is_inside_tree():
		p.play()
