class_name TransformPresenter extends Node
## Client presentation of a transformation (story borrowed-face/010; borrowed-face.md rule 8, States
## "Transforming", Tells T1; TR-borrowedface-006). Two halves, both read only what the client was sent:
## - Warp: every drawn remote body whose snapshot state says transforming gets the warp overlay
##   (spatial_fx_transform_warp.gdshader as material_overlay on its "Mesh", ADR-0010 §6), `warp` rising 0 -> 1 over
##   transform_duration_s from when this client first saw the flag; it leaves when the flag clears
##   (completion or stun interrupt). The flag rides on the body like appearance, so every client that draws
##   the body sees it, with no role or target.
## - Distortion: a positional sound of set BorrowedFace.DISTORTION_SOUND (ADR-0004 §6, no body reference)
##   plays from an AudioStreamPlayer3D placed at the event position, audible to distortion_radius_m (the
##   send radius, ADR-0013 §2), so the engine pans it from the true bearing. Other sound sets are ignored.
## Client only; decides nothing and emits no server event.
## Greybox deviations (ADR-0010 §5, ADR-0013 §3): no pre-warm pass, no AudioDirector pool; the player is created
## per distortion, on the SoundBank entry's bus.
## Usage (client):
##   var w := TransformPresenter.new(remotes, puppets.state_of, knobs)
##   add_child(w); router.subscribe(EventBatch.SOUND, w.on_sound)

## A distortion started playing at `at` (evidence log and tests; the audio itself is the player).
signal heard(sound: StringName, at: Vector3)

const WARP_SHADER := preload("res://src/feature/borrowed_face/spatial_fx_transform_warp.gdshader")
## PLACEHOLDER audio: no asset exists. The distortion is a generated warbling tone; these constants are
## NOT SOURCEABLE and go when the catalog stream replaces it (ADR-0013 §2).
const TONE_MIX_HZ := 22050
const TONE_BASE_HZ := 140.0
const TONE_WOBBLE_HZ := 9.0
const TONE_DEPTH := 0.6
const TONE_GAIN := 0.5

## Reduced motion (accessibility): static tint instead of the moving shimmer (ADR-0010 §6). No settings
## store exists yet, so it stays off until one sets it.
var reduced_motion := false

var _remotes: Dictionary[int, Node3D]
var _state_of: Callable
var _duration_s: float
var _radius_m: float
var _tone: AudioStream
var _bus: StringName = &"Master"
## handle -> seconds since this client first saw it transforming
var _warps: Dictionary[int, float] = {}


## `remotes`: the client's handle -> drawn body (shared, not copied). `state_of(handle) -> Dictionary`: the
## newest snapshot state of a handle (PuppetMap.state_of), read for "transforming".
## `bank`: the sound map; the distortion is its BorrowedFace.DISTORTION_SOUND entry, else the placeholder tone.
func _init(remotes: Dictionary[int, Node3D], state_of: Callable, knobs: Knobs,
		bank: SoundBank = SoundBank.load_shipped()) -> void:
	_remotes = remotes
	_state_of = state_of
	_duration_s = knobs.borrowed_face.transform_duration_s
	_radius_m = knobs.borrowed_face.distortion_radius_m
	var e := bank.resolve(BorrowedFace.DISTORTION_SOUND)
	if e != null and e.stream != null:
		_tone = e.stream
		_bus = e.bus
	else:
		_tone = tone(_duration_s)


## ClientEventRouter handler for EventBatch.SOUND entries ({pos, set}): plays the distortion, ignores the rest.
func on_sound(_tick: int, payload: Dictionary) -> void:
	var at: Variant = payload.get("pos")
	if payload.get("set") != BorrowedFace.DISTORTION_SOUND or not at is Vector3:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _tone
	p.bus = _bus
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.max_distance = _radius_m
	p.position = at # parent is a plain Node, so this is the world position
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()
	heard.emit(BorrowedFace.DISTORTION_SOUND, p.global_position)


## Signed bearing in degrees of `at` seen from `listener` (its -Z is ahead, its +X right): 0 ahead,
## positive to the right. Horizontal only.
static func bearing_deg(listener: Transform3D, at: Vector3) -> float:
	var local := listener.affine_inverse() * at
	return rad_to_deg(atan2(local.x, -local.z))


## Moves every warp on by `delta` seconds, starting and ending overlays from the snapshot flag.
func advance(delta: float) -> void:
	for h: int in _warps.keys():
		if not _remotes.has(h):
			_warps.erase(h)
	for h: int in _remotes:
		var mi := _remotes[h].get_node_or_null(^"Mesh") as GeometryInstance3D
		if mi == null:
			continue
		if not _state_of.call(h).get("transforming", false):
			if _warps.erase(h):
				mi.material_overlay = null
			continue
		if not _warps.has(h):
			_warps[h] = 0.0
			var m := ShaderMaterial.new()
			m.shader = WARP_SHADER
			mi.material_overlay = m
		else:
			_warps[h] += delta
		var mat := mi.material_overlay as ShaderMaterial
		mat.set_shader_parameter(&"warp", minf(_warps[h] / _duration_s, 1.0))
		mat.set_shader_parameter(&"reduced_motion", reduced_motion)


func _process(delta: float) -> void:
	advance(delta)


## PLACEHOLDER distortion stream: `seconds` of a sine whose pitch wobbles, 16-bit mono.
static func tone(seconds: float) -> AudioStreamWAV:
	var n := int(seconds * TONE_MIX_HZ)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / TONE_MIX_HZ
		phase += TAU * TONE_BASE_HZ * (1.0 + TONE_DEPTH * sin(TAU * TONE_WOBBLE_HZ * t)) / TONE_MIX_HZ
		data.encode_s16(i * 2, int(sin(phase) * TONE_GAIN * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TONE_MIX_HZ
	w.stereo = false
	w.data = data
	return w
