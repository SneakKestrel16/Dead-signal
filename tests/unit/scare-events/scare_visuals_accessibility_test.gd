# Story scare-events/009: scare visuals and flash accessibility (scare-events.md rules 24, 25, 28; ADR-0015 §5-6).
# ScareVisuals with fake inputs: the Emergency strobe alarm and the beacons follow the facility scare state, every
# flash source shares one FlashLimiter (never more than max_flashes_per_s onsets in any second, the strobe
# included), flash scale 0 gives no luminance flash, the emergency strips stay on, and the impossible
# surveillance frame shows only on the client the scare was delivered to.
extends GdUnitTestSuite

const STEP := 1.0 / 60.0
const EVAC := FacilityLighting.Base.EVACUATION
const BEACON := &"H-S1"
## A flash entry as the shipped catalogue carries it (test data).
const FLASH := {"flash": 0.6, "flash_s": 0.12}

var _knobs: Knobs
var _map: MapData
var _presets: LightingPresets


func before_test() -> void:
	_knobs = Knobs.load_all()
	_map = MapData.load_map()
	_presets = LightingPresets.load_shipped().duplicate() as LightingPresets


## [ScarePresenter, FacilityScareDisplay, LightingPresenter, SurveillanceFeed, ScareVisuals], all in the tree.
func _rig() -> Array:
	var router := ClientEventRouter.new()
	var scares: ScarePresenter = auto_free(ScarePresenter.new(FlashLimiter.new(_knobs.facility.max_flashes_per_s)))
	var display := FacilityScareDisplay.new(router)
	var lights: LightingPresenter = auto_free(LightingPresenter.new(_map, _presets))
	var feed: SurveillanceFeed = auto_free(SurveillanceFeed.new(_map, _knobs))
	var v: ScareVisuals = auto_free(ScareVisuals.new(scares, display, lights, feed, router))
	for n: Node in [scares, lights, feed, v]:
		add_child(n)
		n.set_process(false) # the test steps time itself
	return [scares, display, lights, feed, v]


func _emergency(r: Array) -> void:
	(r[1] as FacilityScareDisplay).on_facility_scare(1, {"state": FacilityScareState.State.EMERGENCY, "power": false})
	for vol in _map.volumes:
		(r[2] as LightingPresenter).on_lighting(1, {"volume": vol.id, "base": EVAC, "overlays": 0, "dark_until": 0})


func _step(r: Array) -> void:
	(r[0] as ScarePresenter).advance(STEP)
	(r[4] as ScareVisuals).advance(STEP)


func test_strobe_shows_only_in_emergency_at_the_beacon_volumes() -> void:
	var r := _rig()
	var v: ScareVisuals = r[4]
	assert_int(v.strobes().size()).is_greater(0)
	for i in 30:
		_step(r)
		assert_float(v.strobe_energy()).is_equal(0.0)
	_emergency(r)
	var lit := false
	for i in 60:
		_step(r)
		lit = lit or v.strobe_energy() > 0.0
	assert_bool(lit).is_true()
	assert_bool((r[2] as LightingPresenter).get_node(NodePath("%s/beacon" % BEACON)).visible).is_true()
	(r[1] as FacilityScareDisplay).on_facility_scare(2, {"state": FacilityScareState.State.RESULTS, "power": false})
	_step(r)
	assert_float(v.strobe_energy()).is_equal(0.0)


## Rule 25 counting lighting: strobe pulses and scare flashes together never start more than the cap in a second.
func test_never_more_than_the_cap_per_second_counting_the_strobe() -> void:
	_presets.alarm_pulse_hz = 3.0 # the strobe alone at the cap; scares then must lose to the limiter
	var r := _rig()
	var scares: ScarePresenter = r[0]
	var v: ScareVisuals = r[4]
	_emergency(r)
	var onsets: Array[float] = []
	var last_flash := 0.0
	var last_strobe := 0.0
	var t := 0.0
	for i in 600:
		if i % 6 == 0:
			scares.play(FLASH)
		_step(r)
		t += STEP
		var f := scares.flash_rect().color.a
		var s := v.strobe_energy()
		if f > last_flash:
			onsets.append(t)
		if s > last_strobe:
			onsets.append(t)
		last_flash = f
		last_strobe = s
	assert_int(onsets.size()).is_greater(_knobs.facility.max_flashes_per_s)
	onsets.sort()
	for i in onsets.size():
		var n := 0
		for o in onsets:
			if o >= onsets[i] and o < onsets[i] + 1.0 - STEP / 2.0:
				n += 1
		assert_int(n).is_less_equal(_knobs.facility.max_flashes_per_s)


## Rule 24 and 28: at flash scale 0 no luminance rises once Emergency shows; the alarm stays as a steady light,
## the beacons hold still, and a scare still plays on its own frame (as a dim).
func test_scale_zero_gives_no_luminance_flash() -> void:
	var r := _rig()
	var scares: ScarePresenter = r[0]
	var lights: LightingPresenter = r[2]
	var v: ScareVisuals = r[4]
	scares.flash_scale = 0.0
	_emergency(r)
	_step(r)
	var steady := v.strobe_energy()
	assert_float(steady).is_greater(0.0)
	assert_bool(lights.reduced_flash).is_true()
	assert_bool(lights.get_node(NodePath("%s/beacon" % BEACON)).visible).is_false()
	assert_bool(lights.get_node(NodePath("%s/beacon_steady" % BEACON)).visible).is_true()
	for i in 300:
		if i % 15 == 0:
			scares.play(FLASH)
			scares.advance(0.0)
			assert_float(scares.dim_rect().color.a).is_greater(0.0) # same frame: timing unchanged
		_step(r)
		assert_float(scares.flash_rect().color.a).is_equal(0.0)
		assert_float(v.strobe_energy()).is_equal(steady)


func test_emergency_strips_stay_on_in_every_state_and_scale() -> void:
	var r := _rig()
	var lights: LightingPresenter = r[2]
	(r[2] as LightingPresenter).on_lighting(1, {"volume": BEACON, "base": EVAC, "overlays": 0, "dark_until": 99})
	for scale in [1.0, 0.0]:
		(r[0] as ScarePresenter).flash_scale = scale
		for s in FacilityScareState.State.values():
			(r[1] as FacilityScareDisplay).on_facility_scare(1, {"state": s, "power": false})
			for i in 10:
				_step(r)
			for vol in _map.volumes:
				assert_bool(lights.get_node(NodePath("%s/emergency_strip" % vol.id)).visible).is_true()


## Rule 20: the server projects the hallucination to its recipient only; only that client's feed shows the frame.
func test_impossible_frame_only_on_the_target_feed() -> void:
	var a := _rig()
	var b := _rig()
	var e := EvScareTriggered.new()
	e.scare_id = ScareVisuals.HALLUCINATION
	e.scope = ScareEntry.Scope.SINGLE_CLIENT
	e.recipient = 7
	for pair: Array in [[a, 7], [b, 8]]:
		var p := e.project(pair[1], null, -1)
		if not p.is_empty():
			(pair[0][4] as ScareVisuals).on_scare(1, p)
	var fa: SurveillanceFeed = a[3]
	var fb: SurveillanceFeed = b[3]
	assert_bool(fa.screen.visible).is_true()
	assert_object((fa.screen.material_override as StandardMaterial3D).albedo_texture).is_not_equal(fa.viewport.get_texture())
	assert_bool(fb.screen.visible).is_false()
	assert_object((fb.screen.material_override as StandardMaterial3D).albedo_texture).is_equal(fb.viewport.get_texture())
	(b[4] as ScareVisuals).on_scare(1, {"scare": &"door_burst", "scope": 0})
	assert_bool(fb.screen.visible).is_false()
	for i in ceili(ScareVisuals.HALLUCINATION_S / STEP) + 1:
		_step(a)
	assert_bool(fa.screen.visible).is_false()
	assert_object((fa.screen.material_override as StandardMaterial3D).albedo_texture).is_equal(fa.viewport.get_texture())
