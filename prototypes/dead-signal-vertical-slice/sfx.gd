# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does one networked greybox round deliver "you can't be sure the person next to you is a person"?
# Date: 2026-10-13
extends Node
## Placeholder sounds generated at startup (no audio assets in the slice).
## play_at() places a one-shot 3D sound; play_ui() a 2D one.

const RATE := 22050
var streams: Dictionary = {}


func _ready() -> void:
	streams["step"] = _noise_burst(0.07, 900.0, 0.5)
	streams["step_heavy"] = _noise_burst(0.12, 350.0, 0.8)
	streams["lunge_cue"] = _sweep(0.6, 180.0, 520.0, 0.6, true)
	streams["hit"] = _noise_burst(0.25, 200.0, 1.0)
	streams["miss"] = _noise_burst(0.3, 1800.0, 0.4)
	streams["taser"] = _buzz(0.35, 1400.0)
	streams["distortion"] = _warble(2.0)
	streams["door"] = _noise_burst(0.15, 500.0, 0.6)
	streams["tick"] = _sweep(0.05, 1200.0, 1200.0, 0.3, false)
	streams["extract"] = _sweep(0.4, 400.0, 900.0, 0.5, false)
	streams["alarm"] = _alarm(2.0)
	streams["downed"] = _sweep(0.8, 300.0, 90.0, 0.8, false)
	streams["heartbeat"] = _heartbeat()
	streams["reveal"] = _sweep(0.9, 90.0, 60.0, 1.0, true)


## Plays sound `name` at `pos`, audible to `radius` metres.
func play_at(parent: Node, name: String, pos: Vector3, radius: float, db: float = 0.0) -> void:
	if not streams.has(name) or parent == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[name]
	p.max_distance = radius
	p.unit_size = maxf(1.0, radius / 6.0)
	p.volume_db = db
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


## Plays sound `name` non-spatially.
func play_ui(name: String, db: float = -6.0) -> void:
	if not streams.has(name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = streams[name]
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for k in samples.size():
		bytes.encode_s16(k * 2, int(clampf(samples[k], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


func _noise_burst(dur: float, cutoff: float, amp: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cutoff)
	var y := 0.0
	var a := clampf(cutoff / RATE * 6.0, 0.01, 1.0)
	for k in n:
		y += a * (rng.randf_range(-1.0, 1.0) - y)
		s[k] = y * amp * 2.0 * pow(1.0 - float(k) / n, 2.0)
	return _wav(s)


func _sweep(dur: float, f0: float, f1: float, amp: float, harsh: bool) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for k in n:
		var t := float(k) / n
		ph += TAU * lerpf(f0, f1, t) / RATE
		var v := sin(ph)
		if harsh:
			v = signf(v) * 0.6 + sin(ph * 3.01) * 0.4
		s[k] = v * amp * minf(1.0, t * 20.0) * (1.0 - t * 0.7)
	return _wav(s)


func _buzz(dur: float, f: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	for k in n:
		var t := float(k) / n
		var v := signf(sin(TAU * f * k / RATE)) * 0.4 + rng.randf_range(-0.5, 0.5)
		s[k] = v * 0.6 * (1.0 - t)
	return _wav(s)


func _warble(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for k in n:
		var t := float(k) / RATE
		ph += TAU * (110.0 + 60.0 * sin(TAU * 7.0 * t) + 40.0 * sin(TAU * 0.9 * t)) / RATE
		s[k] = (sin(ph) * 0.5 + sin(ph * 1.5) * 0.3) * minf(1.0, t * 4.0) * minf(1.0, (dur - t) * 4.0)
	return _wav(s)


func _alarm(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for k in n:
		var t := float(k) / RATE
		ph += TAU * (660.0 if fmod(t, 0.5) < 0.25 else 880.0) / RATE
		s[k] = signf(sin(ph)) * 0.35
	return _wav(s)


func _heartbeat() -> AudioStreamWAV:
	var n := int(1.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for k in n:
		var t := float(k) / RATE
		var v := 0.0
		for beat in [0.0, 0.25]:
			var d: float = t - beat
			if d >= 0.0 and d < 0.12:
				v += sin(TAU * 55.0 * d) * (1.0 - d / 0.12)
		s[k] = v * 0.9
	return _wav(s, true)
