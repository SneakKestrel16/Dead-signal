# Body action and body cues (ADR-0004 §2 amendment 2026-10-16): the server derives what each body visibly does
# from module state; a disguise doing a survivor's action reads exactly as that survivor; true-form-only
# actions never appear on a disguise; one-shot cues carry the viewer's handle and nothing else.
extends GdUnitTestSuite

const MONSTER := 1
const SURVIVOR := 2
const LOOK := 3 ## a survivor appearance (ADR-0010 §2: 1-5)

var _holds: Dictionary[int, Dictionary] = {}
var _items: Dictionary[int, Interactable] = {}
var _life: Dictionary[int, int] = {}
var _looks: Dictionary[int, int] = {}
var _hidden: Dictionary[int, bool] = {}
var _callouts: Array[PingsCallouts.CalloutRecord] = []
var _committing := false
var _tick := 100


func before_test() -> void:
	_holds.clear()
	_items.clear()
	_life.clear()
	_hidden.clear()
	_callouts.clear()
	_committing = false
	_tick = 100
	_looks = {MONSTER: CharacterDef.TRUE_FORM_APPEARANCE_ID, SURVIVOR: LOOK}


func _acts() -> BodyActions:
	return BodyActions.new(Knobs.load_all(), func(a: int) -> Dictionary: return _holds.get(a, {}),
			func(id: int) -> Interactable: return _items.get(id), func(p: int) -> int: return _life.get(p, 0),
			func(p: int) -> bool: return _committing and p == MONSTER, func(p: int) -> int: return _looks[p],
			func(p: int) -> bool: return _hidden.get(p, false), func() -> Array: return _callouts,
			func() -> int: return _tick)


func _hold(actor: int, item: Interactable, fake: bool = false) -> void:
	_items[7] = item
	_holds[actor] = {"net_id": 7, "elapsed_ticks": 3, "fake": fake, "roots": true}


func test_seized_victim_and_true_form_pin() -> void:
	var acts := _acts()
	assert_int(acts.action_of(SURVIVOR)).is_equal(SnapshotCodec.Action.NONE)
	_life[SURVIVOR] = Downing.LifeState.SEIZED
	_committing = true
	assert_int(acts.action_of(SURVIVOR)).is_equal(SnapshotCodec.Action.SEIZED)
	assert_int(acts.action_of(MONSTER)).is_equal(SnapshotCodec.Action.PIN)


func test_pin_never_shows_on_a_disguise() -> void:
	_committing = true
	_looks[MONSTER] = LOOK
	assert_int(_acts().action_of(MONSTER)).is_equal(SnapshotCodec.Action.NONE)


func test_hold_kind_follows_the_interactable() -> void:
	var acts := _acts()
	_hold(SURVIVOR, RescueHold.new())
	assert_int(acts.action_of(SURVIVOR)).is_equal(SnapshotCodec.Action.KNEEL)
	_hold(SURVIVOR, BarricadeHold.new())
	assert_int(acts.action_of(SURVIVOR)).is_equal(SnapshotCodec.Action.BARRICADE)
	_hold(SURVIVOR, HidingHold.new())
	assert_int(acts.action_of(SURVIVOR)).is_equal(SnapshotCodec.Action.HIDE)
	_hidden[SURVIVOR] = true ## a leave from inside the spot: the exit is a cue
	assert_int(acts.action_of(SURVIVOR)).is_equal(SnapshotCodec.Action.NONE)
	var search := HidingHold.new()
	search.search = true
	_hold(MONSTER, search)
	assert_int(acts.action_of(MONSTER)).is_equal(SnapshotCodec.Action.INTERACT)
	_hold(SURVIVOR, BackupSwitch.new())
	assert_int(acts.action_of(SURVIVOR)).is_equal(SnapshotCodec.Action.INTERACT)


## Borrowed Face: a disguise's fake hold on an object reads as a survivor's real hold on it, down to the bytes
## of its snapshot entry under the same handle and pose.
func test_disguised_fake_hold_looks_identical_to_a_real_hold() -> void:
	_looks[MONSTER] = LOOK
	var point := BackupSwitch.new()
	_hold(SURVIVOR, point)
	var real := _acts().action_of(SURVIVOR)
	_holds.clear()
	_hold(MONSTER, point, true)
	var fake := _acts().action_of(MONSTER)
	assert_int(fake).is_equal(real)
	var entry := func(action: int, appearance: int) -> Dictionary:
		return {"id": 42, "pos": Vector3(1, 0, 2), "yaw": 0.5, "gait": 0, "appearance": appearance, "action": action}
	var bodies_real: Array[Dictionary] = [entry.call(real, _looks[SURVIVOR])]
	var bodies_fake: Array[Dictionary] = [entry.call(fake, _looks[MONSTER])]
	assert_array(SnapshotCodec.encode(9, bodies_fake)).is_equal(SnapshotCodec.encode(9, bodies_real))


func test_call_for_help_shows_for_a_while_and_a_fake_never_does() -> void:
	var acts := _acts()
	var rec := PingsCallouts.CalloutRecord.new()
	rec.sender = SURVIVOR
	rec.line = PingsCallouts.NEED_RESCUE
	rec.tick = 100
	var fake := PingsCallouts.CalloutRecord.new()
	fake.sender = MONSTER
	fake.line = PingsCallouts.NEED_RESCUE
	fake.fake = true
	fake.tick = 100
	_callouts.assign([rec, fake])
	assert_int(acts.action_of(SURVIVOR)).is_equal(SnapshotCodec.Action.CALL_HELP)
	assert_int(acts.action_of(MONSTER)).is_equal(SnapshotCodec.Action.NONE)
	_callouts.clear()
	var hz: int = Knobs.load_all().net.sim_tick_hz
	_tick = 100 + ceili(BodyActions.CALL_HELP_S * hz)
	assert_int(acts.action_of(SURVIVOR)).is_equal(SnapshotCodec.Action.CALL_HELP)
	_tick += 1
	assert_int(acts.action_of(SURVIVOR)).is_equal(SnapshotCodec.Action.NONE)


## Cues name the viewer's own handle only, reach only viewers holding one, and skip the viewer's own body.
func test_cues_carry_only_the_viewers_handle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var handles := HandleTable.new(rng)
	var seen_by_3 := handles.handle_for(3, SURVIVOR)
	var cues := {SURVIVOR: EventBatch.CUE_ELIMINATED, 4: EventBatch.CUE_HIDE_EXIT}
	var done := {}
	var out := ServerMovement.cue_entries(cues, 3, handles, done)
	assert_array(out).is_equal([[EventBatch.BODY_CUE, {"handle": seen_by_3, "cue": EventBatch.CUE_ELIMINATED}]])
	assert_array((out[0][1] as Dictionary).keys()).contains_exactly_in_any_order(["handle", "cue"])
	assert_array(ServerMovement.cue_entries(cues, 3, handles, done)).is_empty() ## once per tick
	assert_array(ServerMovement.cue_entries(cues, 5, handles, {})).is_empty() ## no handle, no cue
	assert_array(ServerMovement.cue_entries({3: EventBatch.CUE_HIDE_EXIT}, 3, handles, {})).is_empty() ## own body
	var spectator := ServerMovement.cue_entries(cues, 9, HandleMirror.new(handles, 3), {}) ## watching player 9
	assert_int(spectator[0][1].handle).is_equal(seen_by_3) ## a spectator's stream uses its own handles
