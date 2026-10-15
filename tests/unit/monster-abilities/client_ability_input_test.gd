extends GdUnitTestSuite
## Story monster-abilities/011 (monster-abilities.md rules 1, 7, 13, 17; design/ux/hud.md S7, interaction
## pattern P14; ADR-0014 §1-3): ShapeshifterAim sends Lunge, False Signal and Blackout requests from the
## shapeshifter's client only, only while the top input context allows actions, and its S7 preview snaps the
## False Signal point with the same MapQueries.floor_point the server's MonsterAbilities is given.
## The aim is injected (aim_of); the map is one long test volume plus a second one beside it.

const MONSTER := 1
const SURVIVOR := 2
const A := MonsterAbilities.Ability
const T := MonsterAbilities.SignalType
const FEET := Vector3.ZERO
const LONG := &"long"
const SIDE := &"side"

var _knobs: Knobs
var _model: HudModel
var _contexts: InputContextStack
var _map: MapData
var _queries: MapQueries
var _aim: ShapeshifterAim
var _sent: Array[PackedByteArray] = []
var _aim_at := Vector3.ZERO
var _aim_dir := Vector3.FORWARD
var _rs: RoundServer


func before_test() -> void:
	_knobs = Knobs.load_all()
	_sent = []
	_aim_dir = Vector3.FORWARD
	_model = HudModel.new(MatchDisplay.new(_knobs), _knobs)
	_contexts = InputContextStack.new()
	_map = MapData.new()
	_map.volumes = [_volume(LONG, AABB(Vector3(-40.0, 0.0, -5.0), Vector3(80.0, 3.0, 10.0))),
		_volume(SIDE, AABB(Vector3(-40.0, 0.0, 5.0), Vector3(80.0, 3.0, 10.0)))]
	_queries = MapQueries.new(_map)
	_aim = auto_free(ShapeshifterAim.new(_model, null, _contexts, _send, _map, _knobs))
	_aim.aim_of = _aim_source


func _volume(id: StringName, box: AABB) -> MapVolume:
	var v := MapVolume.new()
	v.id = id
	v.box = box
	return v


func _send(bytes: PackedByteArray) -> void:
	_sent.append(bytes)


func _aim_source() -> Dictionary:
	return {"feet": FEET, "point": _aim_at, "dir": _aim_dir}


## The shapeshifter-only HUD state MonsterHudFeed sends (one survivor face, nothing cooling).
func _become_shapeshifter() -> void:
	_model.on_monster_hud(0, {"ready": {}, "faces": [[SURVIVOR, 0.0, 1]], "transform_end": -1, "stun_end": -1,
		"immune_end": -1})


# --- AC-3: a survivor client never sends and never shows S7 ----------------------------------------

func test_survivor_never_sends_any_request() -> void:
	_aim_at = Vector3(3.0, 1.2, 0.0)
	assert_bool(_aim.lunge()).is_false()
	for kind: int in [ShapeshifterAim.Kind.FALSE_SIGNAL, ShapeshifterAim.Kind.BLACKOUT]:
		_aim.begin(kind)
		assert_int(_aim.aiming).is_equal(ShapeshifterAim.Kind.NONE)
		assert_bool(_aim.release()).is_false()
	assert_array(_sent).is_empty()


func test_mount_never_instances_s7_on_a_survivor_client() -> void:
	var layer: CanvasLayer = auto_free(CanvasLayer.new())
	add_child(layer)
	ShapeshifterAim.mount(layer, _model, null, _contexts, null, _map, _knobs)
	await await_idle_frame()
	assert_int(layer.get_child_count()).is_equal(0)
	_become_shapeshifter()
	await await_idle_frame()
	assert_int(layer.get_child_count()).is_equal(1)
	assert_object(layer.get_child(0)).is_instanceof(ShapeshifterAim)


# --- AC-1 / AC-2: requests and their bytes --------------------------------------------------------

func test_lunge_sends_the_lunge_request() -> void:
	_become_shapeshifter()
	assert_bool(_aim.lunge()).is_true()
	assert_int(_sent.size()).is_equal(1)
	assert_int(MonsterAbilities.decode_request(_sent[0])[MonsterAbilities.ABILITY_KEY]).is_equal(A.LUNGE)


func test_release_sends_false_signal_footsteps_at_the_aim() -> void:
	_become_shapeshifter()
	_aim_at = Vector3(3.0, 1.2, 0.0)
	_aim_dir = Vector3(1.0, -0.3, 0.0)
	_aim.begin(ShapeshifterAim.Kind.FALSE_SIGNAL)
	assert_bool(_aim.preview()["valid"]).is_true()
	assert_bool(_aim.release()).is_true()
	var req := MonsterAbilities.decode_signal(_sent[0])
	assert_int(req[MonsterAbilities.TYPE_KEY]).is_equal(T.FOOTSTEPS)
	assert_vector(req[MonsterAbilities.AIM_KEY]).is_equal(_aim_at)
	assert_int(req[MonsterAbilities.SURVIVOR_KEY]).is_equal(SURVIVOR)
	assert_vector(req[MonsterAbilities.DIR_KEY]).is_equal(Vector3(1.0, 0.0, 0.0))
	assert_int(_aim.aiming).is_equal(ShapeshifterAim.Kind.NONE)


func test_release_sends_blackout_at_the_aim_and_shows_the_volume() -> void:
	_become_shapeshifter()
	_aim_at = Vector3(2.0, 1.0, 8.0)
	_aim.begin(ShapeshifterAim.Kind.BLACKOUT)
	var p := _aim.preview()
	assert_bool(p["valid"]).is_true()
	assert_str(String(p["volume"])).is_equal(String(SIDE))
	assert_bool(_aim.release()).is_true()
	var req := MonsterAbilities.decode_request(_sent[0])
	assert_int(req[MonsterAbilities.ABILITY_KEY]).is_equal(A.BLACKOUT)
	assert_vector(req[MonsterAbilities.AIM_KEY]).is_equal(_aim_at)


func test_invalid_preview_release_sends_nothing() -> void:
	_become_shapeshifter()
	_aim_at = Vector3(_knobs.ability.blackout_range_m + 5.0, 1.0, 8.0) # another volume, out of range
	_aim.begin(ShapeshifterAim.Kind.BLACKOUT)
	assert_bool(_aim.preview()["valid"]).is_false()
	assert_bool(_aim.release()).is_false()
	_aim_at = Vector3(3.0, 1.2, 30.0) # off the map
	_aim.begin(ShapeshifterAim.Kind.FALSE_SIGNAL)
	assert_bool(_aim.preview()["valid"]).is_false()
	assert_bool(_aim.release()).is_false()
	assert_array(_sent).is_empty()


# --- ADR-0014 §1: context gating ------------------------------------------------------------------

func test_no_request_unless_the_top_context_allows_actions() -> void:
	_become_shapeshifter()
	_aim_at = Vector3(3.0, 1.2, 0.0)
	for ctx: int in [InputContextStack.Ctx.WHEEL, InputContextStack.Ctx.OVERLAY, InputContextStack.Ctx.MENU,
			InputContextStack.Ctx.MODAL]:
		_contexts.reset(ctx)
		assert_bool(_aim.lunge()).is_false()
		_aim.begin(ShapeshifterAim.Kind.FALSE_SIGNAL)
		assert_int(_aim.aiming).is_equal(ShapeshifterAim.Kind.NONE)
	assert_array(_sent).is_empty()


func test_a_context_pushed_while_aiming_cancels_the_aim() -> void:
	_become_shapeshifter()
	_aim_at = Vector3(3.0, 1.2, 0.0)
	_aim.begin(ShapeshifterAim.Kind.FALSE_SIGNAL)
	_contexts.push(InputContextStack.Ctx.OVERLAY, null)
	assert_bool(_aim.release()).is_false()
	_contexts.pop(InputContextStack.Ctx.OVERLAY)
	assert_bool(_aim.release()).is_false() # the aim was dropped, not paused
	assert_array(_sent).is_empty()


# --- S7 snap parity with the server ---------------------------------------------------------------

func test_preview_snap_matches_the_server_snap() -> void:
	_become_shapeshifter()
	var server := _server_abilities()
	var reach := _knobs.ability.false_signal_range_m
	for at: Vector3 in [Vector3(3.0, 1.2, 0.0), Vector3(-6.0, 0.4, 4.9), Vector3(3.0, 1.2, 30.0),
			Vector3(reach + 1.0, 1.0, 0.0), Vector3(reach, 0.0, 0.0)]:
		_aim_at = at
		_aim.begin(ShapeshifterAim.Kind.FALSE_SIGNAL)
		var p := _aim.preview()
		_aim.cancel()
		var req := MonsterAbilities.decode_signal(MonsterAbilities.signal_packet(T.FOOTSTEPS, at, SURVIVOR,
			Vector3.FORWARD))
		var want: Variant = server.false_signal_point(req)
		assert_bool(p["valid"]).override_failure_message("valid at %s" % at).is_equal(want != null)
		if want != null:
			assert_vector(p["point"]).is_equal(want)
	_rs.end_round()


func test_footstep_path_preview_runs_the_server_path_length() -> void:
	_become_shapeshifter()
	_aim_at = Vector3(3.0, 1.2, 0.0)
	_aim_dir = Vector3(0.0, 0.5, -2.0)
	_aim.begin(ShapeshifterAim.Kind.FALSE_SIGNAL)
	var p := _aim.preview()
	var ticks := _knobs.ticks(_knobs.ability.false_signal_footstep_duration_s)
	var length := _knobs.controller.walk_speed * ticks / _knobs.net.sim_tick_hz
	assert_vector(p["end"]).is_equal_approx(Vector3(3.0, 0.0, -length), Vector3.ONE * 1e-4)


## A MonsterAbilities in its own RoundServer with this map's floor snap, as RoundComposer wires it.
func _server_abilities() -> MonsterAbilities:
	_rs = auto_free(RoundServer.new())
	add_child(_rs)
	var ma := MonsterAbilities.new()
	ma.set_monster(MONSTER)
	ma.set_position_source(_feet)
	var radius: Dictionary[StringName, float] = {}
	ma.set_false_signal_sources(Callable(), _queries.floor_point, _observed, Callable(), _footstep_set_of, radius,
		0.5)
	assert_array(_rs.start_round({TickOrder.MONSTER_ABILITIES: ma}, _knobs)).is_empty()
	return ma


func _feet(_p: int) -> Vector3:
	return FEET


func _observed(_s: int) -> bool:
	return true


func _footstep_set_of(s: int) -> StringName:
	return &"c1.walk" if s == SURVIVOR else &""
