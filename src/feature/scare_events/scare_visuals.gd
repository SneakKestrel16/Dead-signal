class_name ScareVisuals extends Node3D
## Client scare visuals beyond the stinger flash, story scare-events/009 (design/gdd/scare-events.md rules 20,
## 23-25, 28 and Visual/Audio Requirements; ADR-0015 §5-6). Decides nothing; reads what the server sent:
## - Emergency strobe alarm: while FacilityScareDisplay says EMERGENCY, one alarm strobe per beacon fixture of
##   the LightingPresenter pulses at presets.alarm_pulse_hz. Each pulse is a luminance flash, so it asks the
##   ScarePresenter's try_flash() (flash scale above 0 and the one shared FlashLimiter, so strobe and scare
##   flashes together stay under max_flashes_per_s); a refused pulse stays dark. Flash scale is applied at
##   render: pulse energy is beacon_energy * flash_scale. At scale 0 the strobe is a steady light instead
##   (rule 28: same information, no flash) and the LightingPresenter is put in reduced flash, so the beacons
##   (Facility Map owns them, lit by its Evacuation records from the same RoundPhaseChanged) hold still. A
##   blacked-out volume's strobe is off. The emergency strips are the LightingPresenter's and are never touched.
## - Impossible surveillance frame: a delivered ScareTriggered for HALLUCINATION swaps the C1 monitor screen to
##   IMAGE for HALLUCINATION_S, then back to the live feed. The server sends a single-client scare to its one
##   recipient only (EvScareTriggered.project), so only that client shows it.
## - VFX (design/assets/specs/vfx-assets.md), each at the delivered scare's origin, so only its recipients
##   see it: ASSET-079 reveal flare, a short OmniLight3D pulse for transformation_reveal, asked of try_flash()
##   like every flash and scaled by flash_scale; reduced flash (scale 0) or a refused flash: no flare, the
##   true form's silhouette is the reveal. Distance scaling is the light's own falloff (inference: the GDD's
##   "scaled" names no curve). ASSET-083 door burst: a dust puff and a few chunks (vfx_door_dust,
##   vfx_door_debris). ASSET-084 glass break: falling shards (vfx_glass_shards); the panel itself is the
##   map's and stays see-through. Particles are no luminance flash, so they play at every flash scale.
## Usage (client): `add_child(ScareVisuals.new(scares, facility_scare, lights, feed, router))`

## The catalogue's single-client hallucination (data/scare_events/scare_catalogue.tres).
const HALLUCINATION := &"surveillance_image"
## Inference: "brief frame on monitor" (Visual/Audio Requirements) gives no length; the M4 horror pass settles it.
const HALLUCINATION_S := 0.4
## Inference: no strobe pulse length in any source; short enough to read as a strobe at 1-3 Hz.
const STROBE_ON_S := 0.08
## Greybox frame: red-tinted static, fixed seed. NOT SOURCEABLE (no art yet); the art pass replaces it.
## It shows no body, ping or state (rule 21).
const IMAGE_SIZE := Vector2i(160, 120)
const IMAGE_SEED := 9
## Catalogue scare ids (data/scare_events/scare_catalogue.tres) with a VFX here.
const REVEAL := &"transformation_reveal"
const DOOR_BURST := &"door_burst"
const GLASS_BREAK := &"glass_break"
## NOT SOURCEABLE (no VFX direction; the VFX art pass settles them): the flare's height over the origin,
## length, energy, range and colour (cold, as the warp tint), and where the bursts start over the origin.
const FLARE_UP := Vector3(0.0, 1.5, 0.0)
const FLARE_S := 0.25
const FLARE_ENERGY := 4.0
const FLARE_RANGE_M := 8.0
const FLARE_COLOUR := Color(0.75, 0.88, 1.0)
const DOOR_UP := Vector3(0.0, 1.0, 0.0)
const GLASS_UP := Vector3(0.0, 1.8, 0.0)

var _scares: ScarePresenter
var _display: FacilityScareDisplay
var _lights: LightingPresenter
var _feed: SurveillanceFeed
## [OmniLight3D, volume id] per strobe.
var _strobes: Array = []
var _energy := 0.0
var _next_pulse := 0.0
var _on_left := 0.0
var _was_emergency := false
var _scale := 1.0
var _frame_left := 0.0
var _image: ImageTexture
var _flare := OmniLight3D.new()
var _flare_left := 0.0
var _flare_peak := 0.0
## vfx_ name -> burst
var _bursts: Dictionary[StringName, GPUParticles3D] = {}


func _init(scares: ScarePresenter, display: FacilityScareDisplay, lights: LightingPresenter,
		feed: SurveillanceFeed, router: ClientEventRouter) -> void:
	name = &"ScareVisuals"
	_scares = scares
	_display = display
	_lights = lights
	_feed = feed
	_scale = scares.flash_scale
	for v in lights.presets.beacon_volumes:
		var vol := lights.get_node_or_null(NodePath(v)) as Node3D
		if vol == null or vol.get_node(^"beacon").get_child_count() == 0:
			continue
		var beacon := vol.get_node(^"beacon") as Node3D
		var o := OmniLight3D.new()
		o.light_color = lights.presets.alarm_colour
		o.omni_range = (beacon.get_child(0) as SpotLight3D).spot_range # clipped to the volume (ADR-0009 §6)
		# Inference: mid-height under the beacon. At the ceiling its clipped range (half the volume's width) does
		# not reach the floor of a 3 m corridor, so the strobe lit nothing (capture 2026-10-15). Facility Map
		# placement of alarm fixtures would settle it (rule 23).
		o.position = lights.position + vol.position + beacon.position * Vector3(1.0, 0.5, 1.0)
		o.visible = false
		add_child(o)
		_strobes.append([o, StringName(v)])
	_flare.light_color = FLARE_COLOUR
	_flare.omni_range = FLARE_RANGE_M
	_flare.light_energy = 0.0
	add_child(_flare)
	for b: GPUParticles3D in [
		VfxBurst.make(&"door_dust", Color(0.55, 0.52, 0.48, 0.7), 24, 1.4, Vector2(0.4, 1.4), 80.0,
				Vector3(0, -0.6, 0), 0.35, VfxBurst.Shape.QUAD, false, Vector3.UP),
		VfxBurst.make(&"door_debris", Color(0.4, 0.4, 0.42), 8, 1.2, Vector2(2.0, 4.0), 60.0,
				Vector3(0, -9.8, 0), 0.08, VfxBurst.Shape.CHIP),
		VfxBurst.make(&"glass_shards", Color(0.75, 0.85, 0.9), 20, 1.0, Vector2(0.3, 1.2), 50.0,
				Vector3(0, -9.8, 0), 0.05, VfxBurst.Shape.CHIP, false, Vector3.DOWN),
	]:
		add_child(b)
		_bursts[b.name] = b
	var img := Image.create(IMAGE_SIZE.x, IMAGE_SIZE.y, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = IMAGE_SEED
	for y in IMAGE_SIZE.y:
		for x in IMAGE_SIZE.x:
			var n := rng.randf()
			img.set_pixel(x, y, Color(n, n * 0.25, n * 0.25))
	_image = ImageTexture.create_from_image(img)
	router.subscribe(&"ScareTriggered", on_scare)


## ClientEventRouter handler for ScareTriggered: the hallucination and the VFX scares are this node's.
func on_scare(_tick: int, payload: Dictionary) -> void:
	var at: Variant = payload.get("origin")
	if at is Vector3:
		match payload.get("scare"):
			REVEAL:
				_flare.position = at + FLARE_UP
				if _scares.try_flash():
					_flare_peak = FLARE_ENERGY * _scares.flash_scale
					_flare_left = FLARE_S
					_flare.light_energy = _flare_peak
			DOOR_BURST:
				VfxBurst.fire(_bursts[&"vfx_door_dust"], at + DOOR_UP)
				VfxBurst.fire(_bursts[&"vfx_door_debris"], at + DOOR_UP)
			GLASS_BREAK:
				VfxBurst.fire(_bursts[&"vfx_glass_shards"], at + GLASS_UP)
	if payload.get("scare") != HALLUCINATION:
		return
	_frame_left = HALLUCINATION_S
	(_feed.screen.material_override as StandardMaterial3D).albedo_texture = _image
	_feed.screen.visible = true


## The strobe lights (tests and captures).
func strobes() -> Array[OmniLight3D]:
	var out: Array[OmniLight3D] = []
	for s: Array in _strobes:
		out.append(s[0])
	return out


## Current strobe energy (0 = dark).
func strobe_energy() -> float:
	return _energy


## The reveal flare light (tests and captures).
func flare() -> OmniLight3D:
	return _flare


## The burst named `vfx_name` (tests and captures).
func burst(vfx_name: StringName) -> GPUParticles3D:
	return _bursts[vfx_name]


## Whether the impossible frame is on the monitor now.
func hallucinating() -> bool:
	return _frame_left > 0.0


## Advances the strobe and the hallucination frame by `delta` seconds.
func advance(delta: float) -> void:
	if _scares.flash_scale != _scale:
		_scale = _scares.flash_scale
		_lights.reduced_flash = _scale <= 0.0
	_strobe(delta)
	_flare_left = maxf(_flare_left - delta, 0.0)
	_flare.light_energy = _flare_peak * _flare_left / FLARE_S
	if _frame_left > 0.0:
		_frame_left -= delta
		if _frame_left <= 0.0:
			(_feed.screen.material_override as StandardMaterial3D).albedo_texture = _feed.viewport.get_texture()
			_feed.screen.visible = _feed.current != Surveillance.OFF


func _process(delta: float) -> void:
	advance(delta)


func _strobe(delta: float) -> void:
	var emergency := _display.state() == FacilityScareState.State.EMERGENCY
	var hz := _lights.presets.alarm_pulse_hz
	if emergency and not _was_emergency:
		_next_pulse = 0.0
	_was_emergency = emergency
	_on_left = maxf(_on_left - delta, 0.0)
	if not emergency or hz <= 0.0:
		_energy = 0.0
	elif _scares.flash_scale <= 0.0:
		_energy = _lights.presets.beacon_steady_energy
	else:
		_next_pulse -= delta
		if _next_pulse <= 0.0:
			_next_pulse += 1.0 / hz
			if _scares.try_flash():
				_on_left = STROBE_ON_S
		_energy = _lights.presets.beacon_energy * _scares.flash_scale if _on_left > 0.0 else 0.0
	for s: Array in _strobes:
		var o: OmniLight3D = s[0]
		o.light_energy = _energy
		o.visible = _energy > 0.0 and _lights.record_of(s[1]).get("dark_until", 0) == 0
