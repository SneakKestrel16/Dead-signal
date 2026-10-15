# Story controller-interaction/013: the client ScarePresenter and FlashLimiter (ADR-0015 §5-6; scare-events.md
# rules 24-25, 28): flash on SCARE_FX scaled by the flash setting, a dim instead at scale 0 or over the
# 3-per-second cap, and the camera reaction through CameraFx.
extends GdUnitTestSuite

const EPS := 0.0001
const STEP := 1.0 / 60.0
const SCARE := &"test_scare"
## A catalog entry as the ScareCatalog data will carry it; the values are test data.
const ENTRY := {"flash": 0.8, "flash_s": 0.12, "shake_deg": 2.0, "shake_m": 0.01, "shake_s": 0.3}

var _knobs: Knobs


func before_test() -> void:
	_knobs = Knobs.load_all()


func _presenter(fx: CameraFx = null) -> ScarePresenter:
	var p := ScarePresenter.new(FlashLimiter.new(_knobs.facility.max_flashes_per_s), fx, {SCARE: ENTRY})
	add_child(p)
	return auto_free(p) as ScarePresenter


func test_limiter_admits_the_cap_per_second_and_frees_up_after() -> void:
	var cap := _knobs.facility.max_flashes_per_s
	var l := FlashLimiter.new(cap)
	for i in cap:
		assert_bool(l.try_flash(0.1 * i)).is_true()
	assert_bool(l.try_flash(0.5)).is_false()
	assert_bool(l.try_flash(0.999)).is_false()
	assert_bool(l.try_flash(1.0)).is_true() ## the first flash is a full second old
	assert_bool(l.try_flash(1.05)).is_false()


func test_flash_sits_on_the_scare_layer_additive_and_fades() -> void:
	var p := _presenter()
	assert_int(p.layer).is_equal(ScarePresenter.SCARE_FX_LAYER)
	assert_int(p.flash_rect().mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int((p.flash_rect().material as CanvasItemMaterial).blend_mode).is_equal(CanvasItemMaterial.BLEND_MODE_ADD)
	p.flash_scale = 0.5
	p.on_scare(1, {"scope": 0, "scare": SCARE})
	p.advance(0.0)
	assert_float(p.flash_rect().color.a).is_equal_approx(ENTRY.flash * 0.5, EPS)
	assert_float(p.dim_rect().color.a).is_equal(0.0)
	p.advance(ENTRY.flash_s)
	assert_float(p.flash_rect().color.a).is_equal(0.0)


## Rule 24: at flash scale 0 there is no luminance flash, only the 0.4 s dim, same timing.
func test_scale_zero_dims_instead_of_flashing() -> void:
	var p := _presenter()
	p.flash_scale = 0.0
	p.on_scare(1, {"scope": 0, "scare": SCARE})
	p.advance(0.0)
	assert_float(p.flash_rect().color.a).is_equal(0.0)
	assert_float(p.dim_rect().color.a).is_greater(0.0)
	p.advance(ScarePresenter.DIM_S)
	assert_float(p.dim_rect().color.a).is_equal(0.0)


## ADR-0015 Validation: four flash sources in one second produce three flashes and one dim.
func test_fourth_flash_in_a_second_is_a_dim() -> void:
	var p := _presenter()
	var flashes := 0
	var dims := 0
	for i in 4:
		p.on_scare(1, {"scope": 0, "scare": SCARE})
		p.advance(0.0)
		if p.flash_rect().color.a > 0.0:
			flashes += 1
		elif p.dim_rect().color.a > 0.0:
			dims += 1
		p.advance(0.2)
	assert_int(flashes).is_equal(_knobs.facility.max_flashes_per_s)
	assert_int(dims).is_equal(4 - _knobs.facility.max_flashes_per_s)


func test_camera_reaction_shakes_camera_fx_and_unknown_scares_play_nothing() -> void:
	var fx: CameraFx = auto_free(CameraFx.new(1))
	var p := _presenter(fx)
	p.on_scare(1, {"scope": 0})
	p.advance(0.0)
	fx.advance(STEP)
	assert_vector(fx.rotation).is_equal(Vector3.ZERO)
	assert_float(p.flash_rect().color.a).is_equal(0.0)
	p.on_scare(1, {"scope": 0, "scare": SCARE})
	fx.advance(STEP)
	assert_float(fx.rotation.length()).is_greater(0.0)
