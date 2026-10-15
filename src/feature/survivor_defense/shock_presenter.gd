class_name ShockPresenter extends Node3D
## Client presentation of a taser hit per form (story survivor-defense/011; survivor-defense.md rules
## 10-11, Visual/Audio Requirements and Impact Moments; TR-defense-008, TR-defense-011; ADR-0010 §4).
## The form is read from the appearance the hit body shows at that moment, never from who was hit:
## - PlayerShocked on a body showing a survivor (a survivor, or the disguised monster stunned or immune):
##   the DisguisePresenter stagger and grunt, the arc at the target and the crackle. Identical for both.
## - PlayerShocked on a body showing the true form (a resisted true-form hit; survivor_defense.gd shock()):
##   the small spark and the dull fizz only, no stagger.
## - MonsterStunned on a body (only ever sent for the true form): the stagger and pain cry, arc, crackle.
## - Own PlayerShocked: camera jitter (a CameraFx offset only: view direction and aim unchanged) and the
##   brief blue edge, with the crackle. Own MonsterStunned: the 200 ms camera jolt.
## Reduced flash: `flash_scale` scales the arc, spark and edge, and the FlashLimiter can refuse the arc
## and spark; the stagger and sounds still play. Reduced motion: CameraFx.enabled. Client only; decides
## nothing and emits no server event. Greybox: the arc and spark are OmniLight3D pulses, the edge a
## bordered panel; the VFX art pass replaces them.
## Usage (client):
##   var s := ShockPresenter.new(disguise, remotes, puppets.state_of, camera_fx, limiter, knobs)
##   add_child(s); router.subscribe(&"PlayerShocked", s.on_player_shocked)
##   router.subscribe(&"MonsterStunned", s.on_monster_stunned); s.cue.connect(audio.play_at)

## A sound for the audio layer: catalog sound id and where it plays.
signal cue(sound: StringName, at: Vector3)

## Taser crackle and the resisted fizz. Inference: no audio catalog exists yet (ADR-0013 catalog ids);
## the audio catalog settles the names.
const CRACKLE := &"taser_crackle"
const FIZZ := &"taser_fizz"
## Impact Moments: arc flash 150 ms, camera impact (monster) 200 ms.
const ARC_S := 0.15
const JOLT_S := 0.2
## Where on the body the arc and spark show, above its feet. NOT SOURCEABLE: greybox chest height.
const CHEST_UP := Vector3(0.0, 1.1, 0.0)
## NOT SOURCEABLE (no VFX direction yet; settled by the VFX art pass): arc and spark light, the blue edge.
const ARC_COLOUR := Color(0.4, 0.6, 1.0)
const ARC_ENERGY := 6.0
const ARC_RANGE_M := 3.0
const SPARK_COLOUR := Color(1.0, 0.8, 0.4)
const SPARK_ENERGY := 2.0
const SPARK_RANGE_M := 0.8
const EDGE_COLOUR := Color(0.3, 0.55, 1.0)
const EDGE_PX := 24
## "Brief" blue edge (Visual table, no duration given). NOT SOURCEABLE: 0.5 s greybox guess.
const EDGE_S := 0.5
## NOT SOURCEABLE (the GDD gives no amplitudes): jitter and jolt sizes in degrees (jolt x yaw, y pitch).
const JITTER_DEG := 1.5
const JOLT_DEG := Vector2(2.0, -3.0)

## Flash intensity scale 0-1 (accessibility flash setting, as ScarePresenter.flash_scale).
var flash_scale := 1.0
## Shock or stun payloads that named no body and were not the own one.
var rejected: int = 0

var _disguise: DisguisePresenter
var _remotes: Dictionary[int, Node3D]
var _state_of: Callable
var _fx: CameraFx
var _limiter: FlashLimiter
var _jitter_s: float
var _now := 0.0
var _arc := OmniLight3D.new()
var _spark := OmniLight3D.new()
var _edge := Panel.new()
## [peak, seconds left, seconds total] of the arc, spark and edge.
var _arc_run: Array = [0.0, 0.0, 0.0]
var _spark_run: Array = [0.0, 0.0, 0.0]
var _edge_run: Array = [0.0, 0.0, 0.0]


## `disguise`: plays the stagger and vocal cue. `remotes` / `state_of`: as DisguisePresenter. `camera_fx`
## null: no own camera reaction. The jitter lasts `stun_root_s`. Inference: the victim is rooted then
## (rule 11); the GDD gives no jitter duration.
func _init(disguise: DisguisePresenter, remotes: Dictionary[int, Node3D], state_of: Callable,
		camera_fx: CameraFx, limiter: FlashLimiter, knobs: Knobs) -> void:
	_disguise = disguise
	_remotes = remotes
	_state_of = state_of
	_fx = camera_fx
	_limiter = limiter
	_jitter_s = knobs.defense.stun_root_s
	for l: Array in [[_arc, ARC_COLOUR, ARC_RANGE_M], [_spark, SPARK_COLOUR, SPARK_RANGE_M]]:
		var light: OmniLight3D = l[0]
		light.light_color = l[1]
		light.omni_range = l[2]
		light.light_energy = 0.0
		add_child(light)
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = EDGE_COLOUR
	box.set_border_width_all(EDGE_PX)
	_edge.add_theme_stylebox_override(&"panel", box)
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edge.modulate.a = 0.0
	var layer := CanvasLayer.new()
	layer.layer = ScarePresenter.SCARE_FX_LAYER
	layer.add_child(_edge)
	add_child(layer)


## ClientEventRouter handler for PlayerShocked.
func on_player_shocked(tick: int, payload: Dictionary) -> void:
	if payload.get("own") == true:
		if _fx != null:
			_fx.jitter(JITTER_DEG, _jitter_s)
		_edge_run = [flash_scale, EDGE_S, EDGE_S]
		cue.emit(CRACKLE, _fx.global_position if _fx != null and _fx.is_inside_tree() else Vector3.ZERO)
		advance(0.0)
		return
	var h: Variant = payload.get("body")
	if not h is int:
		rejected += 1
		return
	if _state_of.call(h).get("appearance", SnapshotCodec.NO_APPEARANCE) == CharacterDef.TRUE_FORM_APPEARANCE_ID:
		var n: Node3D = _remotes.get(h)
		if n != null:
			_pulse(_spark, _spark_run, SPARK_ENERGY, n.position)
			cue.emit(FIZZ, n.position + CHEST_UP)
		return
	_hit(tick, h)


## ClientEventRouter handler for MonsterStunned.
func on_monster_stunned(tick: int, payload: Dictionary) -> void:
	if payload.get("own") == true:
		if _fx != null:
			_fx.jolt(JOLT_DEG, JOLT_S)
		return
	var h: Variant = payload.get("body")
	if not h is int:
		rejected += 1
		return
	_hit(tick, h)


## The arc light (tests and layout checks).
func arc_light() -> OmniLight3D:
	return _arc


## The resisted spark light (tests and layout checks).
func spark_light() -> OmniLight3D:
	return _spark


## The victim's blue edge (tests and layout checks).
func edge() -> Panel:
	return _edge


## Advances the arc, spark and edge by `delta` seconds (all fade linearly).
func advance(delta: float) -> void:
	_now += delta
	_arc.light_energy = _fade(_arc_run, delta)
	_spark.light_energy = _fade(_spark_run, delta)
	_edge.modulate.a = _fade(_edge_run, delta)


func _process(delta: float) -> void:
	advance(delta)


## The full shock on body `h`: stagger and vocal cue, arc and crackle.
func _hit(tick: int, h: int) -> void:
	_disguise.on_shock(tick, {"body": h})
	var n: Node3D = _remotes.get(h)
	if n == null:
		return
	_pulse(_arc, _arc_run, ARC_ENERGY, n.position)
	cue.emit(CRACKLE, n.position + CHEST_UP)


## Lights `light` at `feet` for ARC_S unless the flash setting or cap refuses it. A new pulse replaces
## the running one. ponytail: one arc and one spark light; per-target lights if two hits per frame matter.
func _pulse(light: OmniLight3D, run: Array, energy: float, feet: Vector3) -> void:
	light.position = feet + CHEST_UP
	if flash_scale > 0.0 and _limiter.try_flash(_now):
		run.assign([energy * flash_scale, ARC_S, ARC_S])
	advance(0.0)


func _fade(run: Array, delta: float) -> float:
	run[1] = maxf(run[1] - delta, 0.0)
	return run[0] * run[1] / run[2] if run[2] > 0.0 else 0.0
