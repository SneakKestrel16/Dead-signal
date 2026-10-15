class_name PlaceholderAudio extends Node3D
## PLACEHOLDER client audio sink (story survivor-defense/011): plays every cue and positional server sound
## as the same short beep at its position, pitched per sound id so they can be told apart by ear. No audio
## assets or catalog exist yet; the AudioDirector and sound catalog (ADR-0013) replace this whole class.
## Footsteps arrive as Sound entries too, so they beep as well.
## Usage (client):
##   var audio := PlaceholderAudio.new(); add_child(audio)
##   router.subscribe(EventBatch.SOUND, audio.on_sound); presenter.cue.connect(audio.play_at)

## Entries kept in `played`, newest last.
const LOG_CAP := 32
## Placeholder beep: length, tone and mix rate. NOT SOURCEABLE: replaced by the sound assets.
const BEEP_S := 0.12
const BEEP_HZ := 660.0
const MIX_HZ := 22050

## [sound, at] of the latest plays, at most LOG_CAP (checks and the evidence run's log).
var played: Array = []
## Sound entries with a bad payload.
var rejected: int = 0

var _beep := AudioStreamWAV.new()


func _init() -> void:
	var n := int(BEEP_S * MIX_HZ)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var fade := 1.0 - float(i) / n
		data.encode_s16(i * 2, int(sin(TAU * BEEP_HZ * i / MIX_HZ) * fade * 12000.0))
	_beep.format = AudioStreamWAV.FORMAT_16_BITS
	_beep.mix_rate = MIX_HZ
	_beep.data = data


## ClientEventRouter handler for EventBatch.SOUND entries ({pos, set}).
func on_sound(_tick: int, payload: Dictionary) -> void:
	var at: Variant = payload.get("pos")
	var sound: Variant = payload.get("set")
	if not (at is Vector3 and sound is StringName):
		rejected += 1
		return
	play_at(sound, at)


## Plays `sound` at `at` (global position) once.
func play_at(sound: StringName, at: Vector3) -> void:
	played.append([sound, at])
	if played.size() > LOG_CAP:
		played.pop_front()
	var p := AudioStreamPlayer3D.new()
	p.stream = _beep
	p.pitch_scale = 0.75 + float(absi(hash(sound)) % 50) / 100.0
	p.position = at
	add_child(p)
	p.finished.connect(p.queue_free)
	if p.is_inside_tree():
		p.play()
