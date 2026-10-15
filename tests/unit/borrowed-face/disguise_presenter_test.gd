# Story borrowed-face/009: disguise and true-form stun presentation (design/gdd/borrowed-face.md rule 10,
# Acceptance Criteria "A disguised shapeshifter that is stunned ..."; TR-defense-011: chosen by the body
# shown at that moment; ADR-0010 §4, no role branching). Fake remotes and a fake appearance source; the
# cast is built here, not loaded.
extends GdUnitTestSuite

const H_COPY := 7
const H_REAL := 9
const C3 := 3

var _knobs: Knobs
var _remotes: Dictionary[int, Node3D] = {}
## handle -> snapshot state ({appearance})
var _states: Dictionary[int, Dictionary] = {}
var _p: DisguisePresenter
## [sound, at] per cue the presenter asked for.
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
	_p = auto_free(DisguisePresenter.new(_remotes, _state_of, _knobs, cast))
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
	mi.position.y = 0.9
	n.add_child(mi)
	_remotes[handle] = n
	_states[handle] = {"appearance": appearance}
	return mi


func test_disguised_shock_staggers_the_borrowed_body_with_its_survivors_grunt() -> void:
	var copy := _body(H_COPY, C3, Vector3(1, 0, 2))
	var real := _body(H_REAL, C3, Vector3(4, 0, 2))
	_p.on_shock(10, {"body": H_COPY})
	_p.advance(0.05)
	assert_array(_cues).is_equal([[&"voice_c3.shocked_grunt", Vector3(1, 0, 2)]])
	assert_float(_p.stagger_weight(H_COPY)).is_greater(0.0)
	assert_float(copy.rotation.x).is_not_equal(0.0)
	# The real survivor beside it is untouched: only the hit body staggers.
	assert_float(_p.stagger_weight(H_REAL)).is_equal(0.0)
	assert_float(real.rotation.x).is_equal(0.0)


func test_true_form_stun_plays_the_monster_stagger_and_pain_cry() -> void:
	var mi := _body(H_COPY, CharacterDef.TRUE_FORM_APPEARANCE_ID, Vector3.ZERO)
	_p.on_shock(10, {"body": H_COPY})
	_p.advance(0.05)
	assert_array(_cues).is_equal([[DisguisePresenter.TRUE_FORM_CUE, Vector3.ZERO]])
	assert_float(mi.rotation.x).is_not_equal(0.0)


func test_cue_follows_the_body_shown_not_the_event_type() -> void:
	# Rule 10: interrupted out of a disguise, the body still shows the survivor; the event type never picks.
	_body(H_COPY, C3, Vector3.ZERO)
	_p.on_shock(10, {"body": H_COPY})
	_states[H_COPY] = {"appearance": CharacterDef.TRUE_FORM_APPEARANCE_ID}
	_p.on_shock(11, {"body": H_COPY})
	assert_array(_cues.map(func(c: Array) -> StringName: return c[0])).is_equal(
			[&"voice_c3.shocked_grunt", DisguisePresenter.TRUE_FORM_CUE])


func test_stagger_lasts_the_stun_root_then_restores_the_rest_pose() -> void:
	var mi := _body(H_COPY, C3, Vector3.ZERO)
	var rest := mi.transform
	_p.on_shock(10, {"body": H_COPY})
	_p.advance(_knobs.defense.stun_root_s * 0.5)
	assert_float(_p.stagger_weight(H_COPY)).is_greater(0.0)
	assert_bool(mi.transform.is_equal_approx(rest)).is_false()
	_p.advance(_knobs.defense.stun_root_s * 0.5 + 0.01)
	assert_float(_p.stagger_weight(H_COPY)).is_equal(0.0)
	assert_bool(mi.transform.is_equal_approx(rest)).is_true()


func test_own_shock_unknown_look_and_bad_payloads_play_no_body_cue() -> void:
	_body(H_COPY, SnapshotCodec.NO_APPEARANCE, Vector3.ZERO)
	_p.on_shock(10, {"own": true})
	_p.on_shock(10, {"body": "x"})
	_p.on_shock(10, {})
	_p.on_shock(10, {"body": H_COPY})
	assert_array(_cues).is_empty()
	assert_int(_p.rejected).is_equal(2)
	assert_float(_p.stagger_weight(H_COPY)).is_greater(0.0)


func test_body_freed_mid_stagger_is_dropped() -> void:
	_body(H_COPY, C3, Vector3.ZERO)
	_p.on_shock(10, {"body": H_COPY})
	_remotes.erase(H_COPY)
	_p.advance(0.05)
	assert_float(_p.stagger_weight(H_COPY)).is_equal(0.0)
