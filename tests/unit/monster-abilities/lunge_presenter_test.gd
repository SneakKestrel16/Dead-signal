# Story monster-abilities/007: client presentation of the Lunge (design/gdd/monster-abilities.md rule 5,
# Visual/Audio Requirements, Impact Moments; ADR-0013 §2-3). LungePresenter is fed Sound payloads as the
# ClientEventRouter hands them over; remote bodies are plain Node3Ds with a "Mesh" child, as RoundClient
# draws them. Greybox stand-in: generated tones. The coil and stumble are the art's clips (BodyVisual.clip_for
# of pose()), so the presenter never squashes or tilts the "Mesh" the art hangs under.
extends GdUnitTestSuite

const MONSTER_H := 7
const SURVIVOR_H := 8
const MONSTER_AT := Vector3(0.0, 0.0, -20.0)

var _knobs: Knobs
var _remotes: Dictionary[int, Node3D] = {}
var _p: LungePresenter


func before_test() -> void:
	_knobs = Knobs.load_all()
	_remotes = {}
	for h: int in [MONSTER_H, SURVIVOR_H]:
		var n: Node3D = auto_free(Node3D.new())
		var mesh := MeshInstance3D.new()
		mesh.name = &"Mesh"
		n.add_child(mesh)
		add_child(n)
		_remotes[h] = n
	_remotes[MONSTER_H].position = MONSTER_AT
	_p = auto_free(LungePresenter.new(_knobs, _remotes))
	add_child(_p)


func _sound(sound_set: StringName, at: Vector3) -> void:
	_p.on_sound(0, {"pos": at, "set": sound_set})


func _mesh(h: int) -> Node3D:
	return _remotes[h].get_node(^"Mesh")


# AC-1: the cue plays from the monster's position, so a listener 20 m away hears it from its true bearing.

func test_cue_plays_at_the_sound_position_on_a_player_reaching_the_cue_radius() -> void:
	_sound(MonsterAbilities.CUE_SOUND, MONSTER_AT)
	var pl := _p.player(MonsterAbilities.CUE_SOUND)
	assert_bool(pl.playing).is_true()
	assert_vector(pl.global_position).is_equal(MONSTER_AT)
	assert_float(pl.max_distance).is_equal(_knobs.ability.lunge_cue_radius_m)
	assert_float(pl.stream.get_length()).is_equal_approx(_knobs.ability.lunge_windup_s, 0.01)
	# Listener at the origin facing -Z, the monster 20 m ahead: the source bearing is the true bearing.
	var listener := Vector3.ZERO
	var heard := listener.direction_to(pl.global_position)
	var truth := listener.direction_to(_remotes[MONSTER_H].position)
	assert_float(rad_to_deg(heard.angle_to(truth))).is_less_equal(15.0)


func test_unknown_sound_sets_play_nothing() -> void:
	_sound(&"c3.walk", MONSTER_AT)
	for s: StringName in [MonsterAbilities.CUE_SOUND, MonsterAbilities.SCRAPE_SOUND, MonsterAbilities.HIT_SOUND]:
		assert_bool(_p.player(s).playing).is_false()
	_p.advance(0.0)
	assert_vector(_mesh(MONSTER_H).scale).is_equal(Vector3.ONE)


# AC-2: coil pose during wind-up, stumble during the miss slow, on the monster's body only.

func test_coil_pose_holds_for_the_wind_up_then_rests() -> void:
	_sound(MonsterAbilities.CUE_SOUND, MONSTER_AT)
	_p.advance(_knobs.ability.lunge_windup_s * 0.5)
	# Rule 5 telegraph: the visible crouch-and-coil is the true form's Lunge_Coil clip for the whole wind-up.
	assert_str(_p.pose()).is_equal("coil")
	assert_str(BodyVisual.clip_for(CharacterDef.TRUE_FORM_APPEARANCE_ID, 0, 0.0, _p.pose())).is_equal("Lunge_Coil")
	assert_str(BodyVisual.clip_for(3, 0, 0.0, _p.pose())).is_equal("Idle") # survivor bodies never coil
	# No squash on the art: the clip carries the pose.
	assert_vector(_mesh(MONSTER_H).scale).is_equal(Vector3.ONE)
	assert_vector(_mesh(SURVIVOR_H).scale).is_equal(Vector3.ONE)
	_p.advance(_knobs.ability.lunge_windup_s * 0.6)
	assert_str(_p.pose()).is_equal("")


func test_scrape_ends_the_coil_and_stumbles_for_the_miss_slow() -> void:
	_sound(MonsterAbilities.CUE_SOUND, MONSTER_AT)
	_p.advance(0.1)
	_sound(MonsterAbilities.SCRAPE_SOUND, MONSTER_AT)
	assert_bool(_p.player(MonsterAbilities.SCRAPE_SOUND).playing).is_true()
	_p.advance(_knobs.ability.miss_slow_s * 0.5)
	assert_str(_p.pose()).is_equal("stumble")
	assert_str(BodyVisual.clip_for(CharacterDef.TRUE_FORM_APPEARANCE_ID, 0, 0.0, _p.pose())).is_equal("Lunge_Stumble")
	assert_vector(_mesh(MONSTER_H).scale).is_equal(Vector3.ONE)
	assert_float(_mesh(MONSTER_H).rotation.x).is_equal(0.0)
	_p.advance(_knobs.ability.miss_slow_s * 0.6)
	assert_str(_p.pose()).is_equal("")


# AC-3: presentation-only hit-stop: remote bodies hold their pose for lunge_hit_stop_s, nothing else stops.

func test_hit_freezes_remote_bodies_for_the_hit_stop_only() -> void:
	_sound(MonsterAbilities.HIT_SOUND, MONSTER_AT)
	assert_bool(_p.player(MonsterAbilities.HIT_SOUND).playing).is_true()
	assert_float(_knobs.ability.lunge_hit_stop_s).is_equal(0.08)
	_remotes[SURVIVOR_H].position = Vector3(1.0, 0.0, 1.0) ## the client draws a newer pose
	_p.advance(_knobs.ability.lunge_hit_stop_s * 0.5)
	assert_vector(_remotes[SURVIVOR_H].position).is_equal(Vector3.ZERO)
	assert_vector(_remotes[MONSTER_H].position).is_equal(MONSTER_AT)
	assert_float(Engine.time_scale).is_equal(1.0) ## no simulation pause
	assert_bool(get_tree().paused).is_false()
	_p.advance(_knobs.ability.lunge_hit_stop_s)
	_remotes[SURVIVOR_H].position = Vector3(2.0, 0.0, 2.0)
	_p.advance(0.01)
	assert_vector(_remotes[SURVIVOR_H].position).is_equal(Vector3(2.0, 0.0, 2.0))


func test_a_body_freed_during_the_hit_stop_is_skipped() -> void:
	_sound(MonsterAbilities.HIT_SOUND, MONSTER_AT)
	_remotes.erase(SURVIVOR_H)
	_p.advance(0.01)
	assert_vector(_remotes[MONSTER_H].position).is_equal(MONSTER_AT)


# VFX ASSET-085 (design/assets/specs/vfx-assets.md; art bible §5 no gore) ---------------------------

func test_hit_bursts_dust_and_cloth_on_the_survivor_and_no_scrape() -> void:
	var at := Vector3(1.0, 0.0, -3.0)
	_sound(MonsterAbilities.HIT_SOUND, at)
	assert_bool(_p.burst(&"vfx_lunge_hit").emitting).is_true()
	assert_vector(_p.burst(&"vfx_lunge_hit").position).is_equal(at + LungePresenter.HIT_UP)
	assert_bool(_p.burst(&"vfx_lunge_scrape").emitting).is_false()
	# No blood: no burst colour is red-dominant.
	for b: StringName in [&"vfx_lunge_hit", &"vfx_lunge_scrape"]:
		var c := (_p.burst(b).process_material as ParticleProcessMaterial).color
		assert_bool(c.r > c.g * 1.5 and c.r > c.b * 1.5).override_failure_message(b).is_false()


func test_miss_scrapes_floor_dust_at_the_monster() -> void:
	_sound(MonsterAbilities.SCRAPE_SOUND, MONSTER_AT)
	assert_bool(_p.burst(&"vfx_lunge_scrape").emitting).is_true()
	assert_vector(_p.burst(&"vfx_lunge_scrape").position).is_equal(MONSTER_AT)
	assert_bool(_p.burst(&"vfx_lunge_hit").emitting).is_false()

