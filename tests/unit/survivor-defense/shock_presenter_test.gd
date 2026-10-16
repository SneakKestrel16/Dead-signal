# Story survivor-defense/011: shock presentation per form (design/gdd/survivor-defense.md rules 10-11,
# Visual/Audio Requirements, Impact Moments; TR-defense-008, TR-defense-011; ADR-0010 §4: the form shown
# is read from the body's appearance, never from who was hit). Fake remotes and appearance source; the
# cast is built here, not loaded; the CameraFx is real and seeded.
extends GdUnitTestSuite

const H_SURVIVOR := 7
const H_COPY := 9
const H_MONSTER := 11
const C3 := 3

var _knobs: Knobs
var _remotes: Dictionary[int, Node3D] = {}
var _states: Dictionary[int, Dictionary] = {}
var _disguise: DisguisePresenter
var _fx: CameraFx
var _p: ShockPresenter
## [sound, at] per cue either presenter asked for.
var _cues: Array = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_remotes = {}
	_states = {}
	_cues = []
	var cast: Array[CharacterDef] = []
	for i in 5:
		var c := CharacterDef.new()
		c.appearance_id = i + 1
		c.voice_set = StringName("voice_c%d" % (i + 1))
		cast.append(c)
	_disguise = auto_free(DisguisePresenter.new(_remotes, _state_of, _knobs, cast))
	_disguise.cue.connect(_on_cue)
	_fx = auto_free(CameraFx.new(5))
	_p = auto_free(ShockPresenter.new(_disguise, _remotes, _state_of, _fx, FlashLimiter.new(100), _knobs))
	_p.cue.connect(_on_cue)


func _state_of(handle: int) -> Dictionary:
	return _states.get(handle, {})


func _on_cue(sound: StringName, at: Vector3) -> void:
	_cues.append([sound, at])


func _body(handle: int, appearance: int, at: Vector3) -> MeshInstance3D:
	var n: Node3D = auto_free(Node3D.new())
	n.position = at
	var mi := MeshInstance3D.new()
	mi.name = &"Mesh"
	n.add_child(mi)
	_remotes[handle] = n
	_states[handle] = {"appearance": appearance}
	return mi


## Everything an observer gets from one hit on `handle`, with the body's position taken out.
func _observe(handle: int, event: StringName) -> Array:
	_cues = []
	var at := _remotes[handle].position
	if event == &"PlayerShocked":
		_p.on_player_shocked(10, {"body": handle})
	else:
		_p.on_monster_stunned(10, {"body": handle})
	_p.advance(0.05)
	_disguise.advance(0.05)
	var cues := _cues.map(func(c: Array) -> Array: return [c[0], c[1] - at])
	return [cues, _disguise.stagger_weight(handle), _remotes[handle].get_node(^"Mesh").transform,
			_p.arc_light().light_energy, _p.arc_light().position - at, _p.spark_light().light_energy]


# AC-1 ------------------------------------------------------------------------------------------

func test_survivor_shock_and_disguised_hit_look_and_sound_the_same() -> void:
	# A survivor shocked and the disguised monster stunned (or immune) both reach observers as PlayerShocked
	# on a body showing C3 (EvPlayerShocked/EvMonsterStunned projections): the outputs must be identical.
	_body(H_SURVIVOR, C3, Vector3(1, 0, 2))
	_body(H_COPY, C3, Vector3(5, 0, -3))
	var survivor := _observe(H_SURVIVOR, &"PlayerShocked")
	_p.advance(1.0)
	var copy := _observe(H_COPY, &"PlayerShocked")
	assert_array(copy).is_equal(survivor)
	# ... and it is the full shock: stagger, the survivor grunt, the crackle and the arc.
	assert_float(survivor[1]).is_greater(0.0)
	assert_array(survivor[0].map(func(c: Array) -> StringName: return c[0])).contains_exactly_in_any_order(
			[&"voice_c3.shocked_grunt", ShockPresenter.CRACKLE])
	assert_float(survivor[3]).is_greater(0.0)
	assert_float(survivor[5]).is_equal(0.0)


# AC-2 ------------------------------------------------------------------------------------------

func test_true_form_stun_plays_the_pain_cry_stagger_and_arc() -> void:
	_body(H_MONSTER, CharacterDef.TRUE_FORM_APPEARANCE_ID, Vector3(2, 0, 2))
	var seen := _observe(H_MONSTER, &"MonsterStunned")
	assert_array(seen[0].map(func(c: Array) -> StringName: return c[0])).contains_exactly_in_any_order(
			[DisguisePresenter.TRUE_FORM_CUE, ShockPresenter.CRACKLE])
	assert_float(seen[1]).is_greater(0.0)
	assert_float(seen[3]).is_greater(0.0)


func test_resisted_true_form_hit_plays_the_spark_and_fizz_only() -> void:
	# A resisted true-form hit is PlayerShocked on a body showing the true form (survivor_defense.gd shock()).
	var mi := _body(H_MONSTER, CharacterDef.TRUE_FORM_APPEARANCE_ID, Vector3(2, 0, 2))
	var rest := mi.transform
	var seen := _observe(H_MONSTER, &"PlayerShocked")
	assert_array(seen[0]).is_equal([[ShockPresenter.FIZZ, ShockPresenter.CHEST_UP]])
	assert_float(seen[1]).is_equal(0.0)
	assert_bool(mi.transform.is_equal_approx(rest)).is_true()
	assert_float(seen[3]).is_equal(0.0)
	assert_float(seen[5]).is_greater(0.0)


func test_presentation_follows_the_body_shown_not_the_hit() -> void:
	# Hit while Transforming out of a disguise: the body still shows C3, so the full shock plays; once it
	# shows the true form the same event is the spark.
	_body(H_COPY, C3, Vector3.ZERO)
	assert_float(_observe(H_COPY, &"PlayerShocked")[1]).is_greater(0.0)
	_p.advance(1.0)
	_disguise.advance(5.0)
	_states[H_COPY] = {"appearance": CharacterDef.TRUE_FORM_APPEARANCE_ID}
	assert_float(_observe(H_COPY, &"PlayerShocked")[1]).is_equal(0.0)


# Own view: jitter and edge for the shocked player, jolt for the stunned monster -------------------

func test_own_shock_jitters_the_camera_offset_and_shows_the_blue_edge() -> void:
	_p.on_player_shocked(10, {"own": true})
	_p.advance(0.01)
	_fx.advance(0.01)
	assert_bool(_fx.rotation.is_zero_approx()).is_false()
	assert_float(_p.edge().modulate.a).is_greater(0.0)
	assert_array(_cues.map(func(c: Array) -> StringName: return c[0])).is_equal([ShockPresenter.CRACKLE])
	# Past stun_root_s the jitter is over: the offset returns to rest (it never touched yaw or pitch).
	_fx.advance(_knobs.defense.stun_root_s)
	assert_bool(_fx.rotation.is_zero_approx()).is_true()
	# ASSET-080: the edge lasts the stun (stun_root_s), then goes.
	assert_float(_p.edge().modulate.a).is_greater(0.0)
	_p.advance(_knobs.defense.stun_root_s)
	assert_float(_p.edge().modulate.a).is_equal(0.0)


func test_own_stun_jolts_the_camera_for_200_ms() -> void:
	_p.on_monster_stunned(10, {"own": true})
	_fx.advance(0.01)
	assert_bool(_fx.rotation.is_zero_approx()).is_false()
	_fx.advance(ShockPresenter.JOLT_S)
	assert_bool(_fx.rotation.is_zero_approx()).is_true()


# Reduced-flash variant ---------------------------------------------------------------------------

func test_reduced_flash_scales_the_arc_spark_and_edge() -> void:
	_body(H_SURVIVOR, C3, Vector3.ZERO)
	_p.flash_scale = 0.5
	var half: float = _observe(H_SURVIVOR, &"PlayerShocked")[3]
	_p.advance(1.0)
	_p.flash_scale = 1.0
	var full: float = _observe(H_SURVIVOR, &"PlayerShocked")[3]
	assert_float(half).is_equal_approx(full * 0.5, 1e-4)
	_p.advance(1.0)
	_p.flash_scale = 0.0
	var seen := _observe(H_SURVIVOR, &"PlayerShocked")
	assert_float(seen[3]).is_equal(0.0)
	assert_float(seen[1]).is_greater(0.0) # the stagger and sound still play
	# ASSET-080 reduced-flash variant: the edge still shows, as a static edge with no flicker.
	_p.on_player_shocked(11, {"own": true})
	var alphas: Array[float] = []
	for i in 20:
		_p.advance(0.02)
		alphas.append(_p.edge().modulate.a)
	assert_float(alphas.min()).is_equal(ShockPresenter.EDGE_STATIC_A)
	assert_float(alphas.max()).is_equal(ShockPresenter.EDGE_STATIC_A)


func test_reduced_flash_fires_no_arc_burst() -> void:
	_body(H_SURVIVOR, C3, Vector3.ZERO)
	_p.flash_scale = 0.0
	_observe(H_SURVIVOR, &"PlayerShocked")
	assert_bool(_p.arc_burst().emitting).is_false()


func test_full_flash_edge_flickers() -> void:
	_p.on_player_shocked(11, {"own": true})
	var alphas: Array[float] = []
	for i in 20:
		_p.advance(0.02)
		alphas.append(_p.edge().modulate.a)
	assert_float(alphas.max() - alphas.min()).is_greater(0.1)


# VFX ASSET-080/081: arc particles at the target, spark particles on a resisted hit -----------------

func test_shock_fires_the_blue_white_arc_burst_at_the_target_chest() -> void:
	_body(H_SURVIVOR, C3, Vector3(1, 0, 2))
	_p.on_player_shocked(10, {"body": H_SURVIVOR})
	assert_bool(_p.arc_burst().emitting).is_true()
	assert_vector(_p.arc_burst().position).is_equal(Vector3(1, 0, 2) + ShockPresenter.CHEST_UP)
	assert_bool(_p.spark_burst().emitting).is_false()


func test_resisted_hit_fires_the_spark_burst_only() -> void:
	_body(H_MONSTER, CharacterDef.TRUE_FORM_APPEARANCE_ID, Vector3(2, 0, 2))
	_p.on_player_shocked(10, {"body": H_MONSTER})
	assert_bool(_p.spark_burst().emitting).is_true()
	assert_vector(_p.spark_burst().position).is_equal(Vector3(2, 0, 2) + ShockPresenter.CHEST_UP)
	assert_bool(_p.arc_burst().emitting).is_false()


func test_flash_cap_refuses_the_arc_but_not_the_stagger() -> void:
	_p = auto_free(ShockPresenter.new(_disguise, _remotes, _state_of, _fx, FlashLimiter.new(1), _knobs))
	_body(H_SURVIVOR, C3, Vector3.ZERO)
	assert_float(_observe(H_SURVIVOR, &"PlayerShocked")[3]).is_greater(0.0)
	_p.advance(ShockPresenter.ARC_S) # the first arc is over, still inside the same second
	var seen := _observe(H_SURVIVOR, &"PlayerShocked") # over the cap
	assert_float(seen[3]).is_equal(0.0)
	assert_float(seen[1]).is_greater(0.0)


func test_bad_payloads_play_nothing() -> void:
	_p.on_player_shocked(10, {"body": "x"})
	_p.on_monster_stunned(10, {})
	_p.on_player_shocked(10, {"body": 99}) # never introduced: no appearance, no body
	assert_array(_cues).is_empty()
	assert_float(_p.arc_light().light_energy).is_equal(0.0)
	assert_int(_p.rejected).is_equal(2)
