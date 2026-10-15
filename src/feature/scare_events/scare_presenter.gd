class_name ScarePresenter extends CanvasLayer
## Client presentation of a scare (ADR-0015 §5; scare-events.md rules 24-25, 28; story
## controller-interaction/013): takes ScareTriggered from the ClientEventRouter and plays the scare's
## authored entry: a full-screen additive flash on the SCARE_FX layer, scaled by the flash setting and
## admitted by the FlashLimiter (otherwise, and at scale 0, a 0.4 s non-flashing dim), and the camera
## reaction on CameraFx. Settings scale intensity only; timing is unchanged (rule 28).
## Entry keys (ScareCatalog data): flash (peak alpha 0-1), flash_s, shake_deg, shake_m, shake_s; a
## missing key plays nothing of that kind.
## The P8 edge pulse for a flinch-off player is EdgeCues (hud-results story 005).
## Not here yet (Scare Events epic): the stinger (AudioDirector, ADR-0013) and the ScareCatalog itself. ScareTriggered's projection carries only
## `scope` today, so the entry is looked up by a `scare` id the projection must add; until then on_scare()
## finds no entry and plays nothing.
## Usage:
##   var p := ScarePresenter.new(FlashLimiter.new(knobs.facility.max_flashes_per_s), camera_fx, catalog)
##   add_child(p); router.subscribe(&"ScareTriggered", p.on_scare); p.flash_scale = settings.flash_scale

## Alias of UiLayers.SCARE_FX (ADR-0014 §4 as amended by ADR-0015 §5: between HUD and CAPTIONS).
const SCARE_FX_LAYER := UiLayers.SCARE_FX
## ADR-0015 §5: the non-flashing dim lasts 0.4 s.
const DIM_S := 0.4

## Flash intensity scale 0-1 (rule 24, accessibility setting).
var flash_scale := 1.0

var _limiter: FlashLimiter
var _fx: CameraFx
var _catalog: Dictionary
var _flash := ColorRect.new()
var _dim := ColorRect.new()
var _now := 0.0
## [peak alpha, seconds left, seconds total] of the running flash and dim.
var _flash_run: Array = [0.0, 0.0, 0.0]
var _dim_run: Array = [0.0, 0.0, 0.0]


## `camera_fx` null: no camera reaction. `catalog`: scare id -> entry.
func _init(limiter: FlashLimiter, camera_fx: CameraFx = null, catalog: Dictionary = {}) -> void:
	_limiter = limiter
	_fx = camera_fx
	_catalog = catalog
	layer = SCARE_FX_LAYER
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash.material = add
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_dim.color = Color(0.0, 0.0, 0.0, 0.0)
	for r: ColorRect in [_flash, _dim]:
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(r)


## ClientEventRouter handler for ScareTriggered.
func on_scare(_tick: int, payload: Dictionary) -> void:
	var entry: Variant = _catalog.get(payload.get("scare", &""))
	if entry is Dictionary:
		play(entry)


## Plays one entry now.
func play(entry: Dictionary) -> void:
	var peak: float = entry.get("flash", 0.0)
	if peak > 0.0:
		var secs: float = entry.get("flash_s", 0.0)
		if try_flash():
			_flash_run = [peak * flash_scale, secs, secs]
		else:
			# Inference: the dim is as dark as the flash would have been bright; no source gives its depth.
			_dim_run = [peak, DIM_S, DIM_S]
	var shake_s: float = entry.get("shake_s", 0.0)
	if _fx != null and shake_s > 0.0:
		_fx.shake(entry.get("shake_deg", 0.0), entry.get("shake_m", 0.0), shake_s)
	advance(0.0)


## True, and counted, when a luminance flash may start now: flash scale above 0 (rule 24) and under the
## shared cap (rule 25). Every client flash source asks here, ScareVisuals' strobe too (story 009).
func try_flash() -> bool:
	return flash_scale > 0.0 and _limiter.try_flash(_now)


## Advances the flash and dim by `delta` seconds (both fade linearly).
func advance(delta: float) -> void:
	_now += delta
	_flash.color.a = _fade(_flash_run, delta)
	_dim.color.a = _fade(_dim_run, delta)


## The flash rect (tests and layout checks).
func flash_rect() -> ColorRect:
	return _flash


## The dim rect (tests and layout checks).
func dim_rect() -> ColorRect:
	return _dim


func _process(delta: float) -> void:
	advance(delta)


func _fade(run: Array, delta: float) -> float:
	run[1] = maxf(run[1] - delta, 0.0)
	return run[0] * run[1] / run[2] if run[2] > 0.0 else 0.0
