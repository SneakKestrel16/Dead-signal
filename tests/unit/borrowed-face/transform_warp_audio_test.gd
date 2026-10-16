# Story borrowed-face/010: transformation warp and distortion audio (design/gdd/borrowed-face.md rule 8,
# States "Transforming", Tells T1; TR-borrowedface-006; ADR-0004 §6 positional sounds with no handle,
# ADR-0010 §6 overlay warp, ADR-0013 §3 player at the event position). The server half runs BorrowedFace in
# a RoundServer with stub sight and status sources and records emit_sound; the send radius is checked
# through the real EventBatch.build. The client half drives TransformPresenter with fake remotes.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const SURVIVORS: Array[int] = [2]
const EYE := Vector3(0.0, 1.6, 0.0)
## Where the shapeshifter stands: 45 degrees right of a listener at the origin facing -Z.
const MONSTER_AT := Vector3(5.0, 0.0, -5.0)
## AC1 tolerance on the panned bearing (story: proposed).
const BEARING_TOL_DEG := 15.0
const H_MONSTER := 7
const H_OTHER := 9

var _server: RoundServer
var _bf: BorrowedFace
var _knobs: Knobs
## [position, sound_set, radius_m, source] per emit_sound call.
var _sounds: Array = []
var _remotes: Dictionary[int, Node3D] = {}
var _states: Dictionary[int, Dictionary] = {}
var _heard: Array = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_sounds = []
	_remotes = {}
	_states = {}
	_heard = []


func _start() -> void:
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_bf = BorrowedFace.new()
	_bf.set_roster(SURVIVORS, MONSTER)
	_bf.set_sight_sources(_eye_of, _yaw_of, _points_of, _sight)
	_bf.set_status_source(_status_of)
	_bf.emit_sound = _emit
	_bf.position_of = _position_of
	assert_array(_server.start_round({TickOrder.BORROWED_FACE: _bf}, _knobs)).is_empty()
	_step(_knobs.ticks(_knobs.borrowed_face.observe_time_s))


func _eye_of(_p: int) -> Vector3:
	return EYE


func _yaw_of(_p: int) -> float:
	return 0.0


func _points_of(_p: int) -> PackedVector3Array:
	var chest := EYE + Vector3.FORWARD * 5.0
	return PackedVector3Array([chest + Vector3.UP * 0.4, chest, chest + Vector3.DOWN * 0.3])


func _sight(_eye: Vector3, _point: Vector3) -> bool:
	return true


func _status_of(_p: int) -> int:
	return MatchFlow.Status.HEALTHY


func _position_of(_p: int) -> Vector3:
	return MONSTER_AT


func _emit(position: Vector3, sound_set: StringName, radius_m: float, source: int = -1) -> void:
	_sounds.append([position, sound_set, radius_m, source])


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


## The positional sounds a viewer standing at `at` is sent this tick (EventBatch.build, the real send).
func _sent_to(at: Vector3) -> Array:
	var queued: Array[EventBatch.Sound] = []
	for s: Array in _sounds:
		var q := EventBatch.Sound.new()
		q.position = s[0]
		q.sound_set = s[1]
		q.radius_m = s[2]
		q.source = s[3]
		queued.append(q)
	var none: Array[ServerEvent] = []
	var bytes := EventBatch.build(1, 4, none, queued, at, null, MONSTER)
	if bytes.is_empty():
		return []
	return (bytes_to_var(bytes.slice(1)) as Array)[1]


func _on_heard(sound: StringName, at: Vector3) -> void:
	_heard.append([sound, at])


func _presenter() -> TransformPresenter:
	var p: TransformPresenter = auto_free(TransformPresenter.new(_remotes, _state_of, _knobs))
	add_child(p)
	p.heard.connect(_on_heard)
	return p


func _state_of(handle: int) -> Dictionary:
	return _states.get(handle, {})


func _body(handle: int, transforming: bool) -> MeshInstance3D:
	var n: Node3D = auto_free(Node3D.new())
	var mi := MeshInstance3D.new()
	mi.name = &"Mesh"
	n.add_child(mi)
	_remotes[handle] = n
	_states[handle] = {"transforming": transforming}
	return mi


## Signed bearing in degrees of `at` from a listener at the origin facing -Z (positive = right).
func _true_bearing(at: Vector3) -> float:
	return rad_to_deg(atan2(at.x, -at.z))


## AC1 server half: an accepted request sends one distortion at the shapeshifter's position, radius
## distortion_radius_m, to everyone in range including the shapeshifter's own client (no source).
func test_accepted_transformation_sends_one_distortion_at_the_shapeshifter() -> void:
	_start()
	_bf.request_form_change(MONSTER, BorrowedFace.request_packet(S1))
	_step(1)
	assert_bool(_bf.transforming()).is_true()
	assert_array(_sounds).is_equal([[MONSTER_AT, BorrowedFace.DISTORTION_SOUND,
			_knobs.borrowed_face.distortion_radius_m, -1]])
	_step(_knobs.ticks(_knobs.borrowed_face.transform_duration_s))
	assert_int(_bf.form()).is_equal(S1)
	assert_int(_sounds.size()).is_equal(1)


func test_rejected_request_sends_no_distortion() -> void:
	_start()
	_bf.request_form_change(MONSTER, BorrowedFace.request_packet(BorrowedFace.TRUE_FORM))
	_step(1)
	assert_bool(_bf.transforming()).is_false()
	assert_array(_sounds).is_empty()


## AC1: a client 15 m away is sent the distortion, one 20 m away is not.
func test_distortion_reaches_15_m_and_not_20_m() -> void:
	_start()
	_bf.request_form_change(MONSTER, BorrowedFace.request_packet(S1))
	_step(1)
	var near := _sent_to(MONSTER_AT + Vector3.BACK * 15.0)
	assert_array(near).is_equal([[EventBatch.SOUND, {"pos": MONSTER_AT, "set": BorrowedFace.DISTORTION_SOUND}]])
	assert_array(_sent_to(MONSTER_AT + Vector3.BACK * 20.0)).is_empty()


## AC1 client half: the distortion plays from a 3D player at the event position, audible to the send
## radius, so it pans from the true bearing.
func test_distortion_plays_at_the_event_position_within_bearing_tolerance() -> void:
	var p := _presenter()
	p.on_sound(1, {"pos": MONSTER_AT, "set": BorrowedFace.DISTORTION_SOUND})
	assert_int(_heard.size()).is_equal(1)
	var at: Vector3 = _heard[0][1]
	var bearing := TransformPresenter.bearing_deg(Transform3D.IDENTITY, at)
	assert_float(absf(bearing - _true_bearing(MONSTER_AT))).is_less_equal(BEARING_TOL_DEG)
	assert_float(bearing).is_equal_approx(45.0, 0.01)
	var player := p.get_child(0) as AudioStreamPlayer3D
	assert_object(player).is_not_null()
	assert_float(player.max_distance).is_equal(_knobs.borrowed_face.distortion_radius_m)
	assert_bool(player.playing).is_true()


func test_other_sounds_are_not_the_distortion() -> void:
	var p := _presenter()
	p.on_sound(1, {"pos": MONSTER_AT, "set": &"c3.walk"})
	p.on_sound(1, {"pos": "junk", "set": BorrowedFace.DISTORTION_SOUND})
	assert_array(_heard).is_empty()
	assert_int(p.get_child_count()).is_equal(0)


## AC2: the warp overlay is on the transforming body for the whole state, rises 0 -> 1 over the
## transform duration, and leaves when the flag clears; other bodies never get it.
func test_warp_covers_the_transforming_body_only_while_the_flag_is_set() -> void:
	var p := _presenter()
	var mon := _body(H_MONSTER, true)
	var other := _body(H_OTHER, false)
	var dur := _knobs.borrowed_face.transform_duration_s
	p.advance(0.0)
	var mat := mon.material_overlay as ShaderMaterial
	assert_object(mat).is_not_null()
	assert_object(other.material_overlay).is_null()
	p.advance(dur / 2.0)
	assert_float(mat.get_shader_parameter(&"warp")).is_equal_approx(0.5, 0.01)
	p.advance(dur)
	assert_float(mat.get_shader_parameter(&"warp")).is_equal_approx(1.0, 0.001)
	assert_object(mon.material_overlay).is_same(mat)
	_states[H_MONSTER] = {"transforming": false}
	p.advance(0.016)
	assert_object(mon.material_overlay).is_null()
	_states[H_MONSTER] = {"transforming": true}
	p.advance(0.0)
	assert_float((mon.material_overlay as ShaderMaterial).get_shader_parameter(&"warp")).is_equal(0.0)


## A drawn body as RoundClient + BodyVisual leave it: "Mesh" with no mesh of its own (the capsule is
## detached) and the art under "Mesh/Visual": two LOD meshes and an accessory. Returns the art meshes.
func _art_body(handle: int, transforming: bool, appearance: int = S1) -> Array[MeshInstance3D]:
	var mesh := _body(handle, transforming)
	_states[handle]["appearance"] = appearance
	var visual := Node3D.new()
	visual.name = BodyVisual.VISUAL
	mesh.add_child(visual)
	var out: Array[MeshInstance3D] = []
	for n: StringName in [&"body_lod0", &"body_lod1", &"acc_c1_hardhat"]:
		var mi := MeshInstance3D.new()
		mi.name = n
		mi.mesh = BoxMesh.new()
		visual.add_child(mi)
		out.append(mi)
	return out


## ASSET-078: the warp is on the art itself (every art mesh of the body, one shared material), not on a
## swapped-in capsule, and leaves every one of them when the flag clears.
func test_warp_overlays_every_art_mesh_while_transforming_only() -> void:
	var p := _presenter()
	var art := _art_body(H_MONSTER, true)
	var other := _art_body(H_OTHER, false)
	p.advance(0.0)
	var mat := art[0].material_overlay as ShaderMaterial
	assert_object(mat).is_not_null()
	assert_object(mat.shader).is_same(TransformPresenter.WARP_SHADER)
	for mi in art:
		assert_object(mi.material_overlay).is_same(mat)
	for mi in other:
		assert_object(mi.material_overlay).is_null()
	_states[H_MONSTER]["transforming"] = false
	p.advance(0.016)
	for mi in art:
		assert_object(mi.material_overlay).is_null()


## LB-6 / art bible P2: a steady disguised body (a survivor look, not transforming) never carries the warp,
## however long it is drawn.
func test_no_warp_on_a_steady_disguised_body() -> void:
	var p := _presenter()
	var art := _art_body(H_MONSTER, false, S1)
	for i in 10:
		p.advance(0.5)
	for mi in art:
		assert_object(mi.material_overlay).is_null()


## The art is rebuilt when the appearance changes (BodyVisual); meshes that appear mid-warp get the same
## overlay, at the same progress.
func test_meshes_built_mid_warp_join_the_running_warp() -> void:
	var p := _presenter()
	var art := _art_body(H_MONSTER, true)
	p.advance(0.0)
	p.advance(_knobs.borrowed_face.transform_duration_s / 2.0)
	var late := MeshInstance3D.new()
	late.mesh = BoxMesh.new()
	art[0].get_parent().add_child(late)
	p.advance(0.0)
	assert_object(late.material_overlay).is_same(art[0].material_overlay)
	assert_float((late.material_overlay as ShaderMaterial).get_shader_parameter(&"warp")).is_equal_approx(0.5, 0.01)


## Reduced motion reaches the overlay: static tint, no moving shimmer (ADR-0010 §6).
func test_reduced_motion_reaches_the_overlay() -> void:
	var p := _presenter()
	var art := _art_body(H_MONSTER, true)
	p.reduced_motion = true
	p.advance(0.0)
	assert_bool((art[0].material_overlay as ShaderMaterial).get_shader_parameter(&"reduced_motion")).is_true()
