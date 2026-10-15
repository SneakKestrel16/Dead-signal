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
	var img := Image.create(IMAGE_SIZE.x, IMAGE_SIZE.y, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = IMAGE_SEED
	for y in IMAGE_SIZE.y:
		for x in IMAGE_SIZE.x:
			var n := rng.randf()
			img.set_pixel(x, y, Color(n, n * 0.25, n * 0.25))
	_image = ImageTexture.create_from_image(img)
	router.subscribe(&"ScareTriggered", on_scare)


## ClientEventRouter handler for ScareTriggered: only the hallucination is this node's.
func on_scare(_tick: int, payload: Dictionary) -> void:
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


## Whether the impossible frame is on the monitor now.
func hallucinating() -> bool:
	return _frame_left > 0.0


## Advances the strobe and the hallucination frame by `delta` seconds.
func advance(delta: float) -> void:
	if _scares.flash_scale != _scale:
		_scale = _scares.flash_scale
		_lights.reduced_flash = _scale <= 0.0
	_strobe(delta)
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
