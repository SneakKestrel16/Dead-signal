class_name BorrowedFace extends RefCounted
## Borrowed Face: the shapeshifter's disguise (Core layer). Story borrowed-face/001 implements the
## observation accumulator: design/gdd/borrowed-face.md rules 1-3 and Formulas "Observation
## accumulation"; ADR-0005 (tick order slot BORROWED_FACE), ADR-0007 §5 (sight rays on SIGHT, doors
## analytic), ADR-0006 (BorrowedFaceKnobs). Story 002 adds form-change requests and target
## persistence (rules 5-6, 13, Edge Cases "Target ..." rows). Story 003 adds the state machine of
## "States and Transitions": cooldown, stun interrupt and FormChanged (rules 7-10, 14-15, Formulas
## "Form-change timing", Edge Cases "Stun lands on ...", "Round ends mid-transformation").
## Story 007 (ADR-0004 §3-4, §9): appearance_of() feeds every snapshot entry's appearance, so every
## client renders the form from replicated state; on_form_event retires lingering handles; a shapeshifter
## that disconnects loses its disguise; catch_up() gives a rejoining shapeshifter client its own form.
## Server only. Observation counts ticks of `net.sim_tick_hz`, never wall time, and never decays.
## Collaborators are injected as Callables (ADR-0005 §6 dependency injection):
##   eye_of(player) -> Vector3                  the shapeshifter's eye position
##   yaw_of(player) -> float                    its look yaw (ViewState.yaw_of; 0 faces -Z)
##   body_points_of(player) -> PackedVector3Array  [head, chest, pelvis]; empty = no body in the world
##   sight(eye, point) -> bool                  line of sight (MapQueries.clear_sight on the server)
##   locked(player) -> bool                     Stunned or under the shock lock (Survivor Defense rule
##                                              14). Stub until Survivor Defense publishes
##                                              StateKeys.SHOCK_STUN_LOCK; unset = never locked
##   status_of(player) -> int                   MatchFlow.Status (MatchFlow.status_of); unset = no
##                                              survivor is a valid target
##   attacking(player) -> bool                  in Lunge wind-up, active or takedown commit (rule 7,
##                                              rule 11; story 005). Stub until Monster Abilities and
##                                              Downing are wired; unset = never attacking
## Usage:
##   var bf := BorrowedFace.new()
##   bf.set_roster([2, 3, 4, 5], 1)   # BEFORE start_round
##   bf.set_sight_sources(eye_of, view.yaw_of, body_points_of, sight, locked)
##   bf.set_status_source(match_flow.status_of)
##   server.start_round({TickOrder.BORROWED_FACE: bf}, knobs)
##   bf.observed(2)
##   smp.peer_packet -> bf.request_form_change(net.player_id_of(peer), bytes)

## Index of the chest point in body_points_of: the cone is measured to it (rule 2).
const CHEST := 1
## Float tolerance so a survivor exactly on observe_range_m counts.
const RANGE_EPS_M := 1e-6
## Form value for the shapeshifter's true form; any other form is a survivor's player id.
const TRUE_FORM := -1
## decode_request's result for bytes that are not a form-change request.
const INVALID_FORM := -2
## Size cap of a form-change request packet; anything larger is not one (untrusted client bytes).
const REQUEST_CAP_BYTES := 64
## Request packet dictionary key.
const REQUEST_KEY := "form"

var _survivors: Array[int] = []
var _monster: int = -1
var _eye_of: Callable
var _yaw_of: Callable
var _body_points_of: Callable
var _sight: Callable
var _locked: Callable
var _status_of: Callable
var _attacking: Callable
var _hz: int = 0
var _observe_ticks: int = 0
var _range_m: float = 0.0
var _half_fov: float = 0.0
## survivor -> valid observation ticks this round (rule 1: obs_time in ticks)
var _obs: Dictionary[int, int] = {}
var _bus: EventBus
var _transform_ticks: int = 0
var _cooldown_ticks: int = 0
## First tick a request may be accepted again (rule 9); 0 at round start, so no cooldown runs.
var _cooldown_end_tick: int = 0
var _form: int = TRUE_FORM
## Target of the transformation in progress; TRUE_FORM is a valid target, so _transforming says if one runs.
var _target: int = TRUE_FORM
var _transforming := false
var _transform_end_tick: int = 0
## The first request received since the last tick, or INVALID_FORM: one request per tick.
var _pending: int = INVALID_FORM
var _appearance_of: Callable
## Tick of the last form change (0 = round start), stamped on the catch-up event.
var _form_tick: int = 0
## Callable(player) run when a transformation starts and when the form changes (ADR-0004 §4: a form
## change or transformation start on a lingering body retires its handle). The composition root sets it
## to ServerMovement.scope.form_changed; unset = nothing.
var on_form_event: Callable


## Injects the round's roster. Call before RoundServer.start_round (setup resets state from it).
func set_roster(survivors: Array[int], monster: int) -> void:
	_survivors = survivors.duplicate()
	_monster = monster


## Injects the sight collaborators (see the class comment). Unset ones observe nothing, except
## `locked`, which unset means never locked.
func set_sight_sources(eye_of: Callable, yaw_of: Callable, body_points_of: Callable, sight: Callable,
		locked: Callable = Callable()) -> void:
	_eye_of = eye_of
	_yaw_of = yaw_of
	_body_points_of = body_points_of
	_sight = sight
	_locked = locked


## Injects the survivor status source (see the class comment).
func set_status_source(status_of: Callable) -> void:
	_status_of = status_of


## Injects the attack source (see the class comment): a transformation never cancels an attack (rule 11).
func set_attack_source(attacking: Callable) -> void:
	_attacking = attacking


## Injects character_appearance(player) -> int, the CharacterDef appearance id of a player's own
## character (survivors; the lobby's character assignment). Unset = every body NO_APPEARANCE.
func set_appearance_source(character_appearance: Callable) -> void:
	_appearance_of = character_appearance


## The appearance id clients render `player`'s body with: its own character, except the shapeshifter,
## which shows the copied survivor's character or CharacterDef.TRUE_FORM_APPEARANCE_ID (ADR-0004 §4).
## No player ID, role or observation travels with it.
func appearance_of(player: int) -> int:
	if player == _monster and _form == TRUE_FORM:
		return CharacterDef.TRUE_FORM_APPEARANCE_ID
	var who := _form if player == _monster else player
	return _appearance_of.call(who) if _appearance_of.is_valid() else SnapshotCodec.NO_APPEARANCE


## Whether clients show `player`'s body as transforming (rule 8: distortion audio, visual warp): true only
## for the shapeshifter mid-transformation. The GDD makes this cue a tell every client may perceive (Tells
## T1), so it is replicated on the body like appearance; no role or target travels with it.
func transforming_of(player: int) -> bool:
	return player == _monster and _transforming


## The bytes the shapeshifter's client sends to request a change into `form` (a survivor id or TRUE_FORM).
static func request_packet(form: int) -> PackedByteArray:
	return var_to_bytes({REQUEST_KEY: form})


## The form requested by untrusted `bytes`, or INVALID_FORM when they are not a request. Only checks
## the shape; whether the form is a valid target is decided in server_tick.
static func decode_request(bytes: PackedByteArray) -> int:
	if bytes.is_empty() or bytes.size() > REQUEST_CAP_BYTES:
		return INVALID_FORM
	var d: Variant = bytes_to_var(bytes)
	if not (d is Dictionary and d.size() == 1 and d.get(REQUEST_KEY) is int):
		return INVALID_FORM
	return d[REQUEST_KEY]


## Server entry for a client's form-change request from `player` (the sender as the network layer
## identifies it, never a field of the bytes). Ignored unless it is the shapeshifter and the bytes
## decode; only the first request of a tick is kept, and it is validated at the BORROWED_FACE step.
func request_form_change(player: int, bytes: PackedByteArray) -> void:
	if player != _monster or _pending != INVALID_FORM:
		return
	_pending = decode_request(bytes)


## Injected by RoundServer. Reads knobs, resets every survivor's observation to 0 (rule 1) and puts
## the shapeshifter in true form, not transforming, no cooldown (rule 5), discarding anything left
## from a round that ended mid-transformation. Subscribes to MonsterStunned (rule 10).
func setup(_tick_runner: TickRunner, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
	_bus = bus
	registry.register_view(StateKeys.TRANSFORMING, &"BorrowedFace", TransformView.new(self))
	_hz = knobs.net.sim_tick_hz
	_observe_ticks = knobs.ticks(knobs.borrowed_face.observe_time_s)
	_range_m = knobs.borrowed_face.observe_range_m
	_half_fov = deg_to_rad(knobs.borrowed_face.observe_fov_deg / 2.0)
	_transform_ticks = knobs.ticks(knobs.borrowed_face.transform_duration_s)
	_cooldown_ticks = knobs.ticks(knobs.borrowed_face.form_change_cooldown_s)
	_cooldown_end_tick = 0
	_obs = {}
	for s in _survivors:
		_obs[s] = 0
	_form = TRUE_FORM
	_target = TRUE_FORM
	_transforming = false
	_pending = INVALID_FORM
	_form_tick = 0
	bus.subscribe(&"MonsterStunned", _on_monster_stunned)
	bus.subscribe(&"PlayerConnectionChanged", _on_connection_changed)


## BORROWED_FACE slot: observation, then a transformation due this tick completes, then this
## tick's request is validated (a request accepted this tick never completes on it). Survivor
## Defense (slot 200) flushes first, so a stun on the completion tick has already interrupted (rule 9).
func server_tick(tick: int) -> void:
	_observe()
	if _transforming and tick >= _transform_end_tick:
		_complete(tick)
	var req := _pending
	_pending = INVALID_FORM
	if req != INVALID_FORM and tick >= _cooldown_end_tick and _can_change_into(req):
		_target = req
		_transforming = true
		_transform_end_tick = tick + _transform_ticks
		_form_event()


## Rule 9: switch the form, start the cooldown and emit FormChanged; Scare Events reads it for the
## reveal (rule 15), after this step's flush and never gating it. Rule 13 and Edge Cases: the target
## was valid at request time; its status now does not matter.
func _complete(tick: int) -> void:
	var e := EvFormChanged.new()
	e.player = _monster
	e.previous = _form
	e.form = _target
	_form = _target
	_transforming = false
	_cooldown_end_tick = tick + _cooldown_ticks
	_form_tick = tick
	_form_event()
	_bus.emit(e)


func _form_event() -> void:
	if on_form_event.is_valid():
		on_form_event.call(_monster)


## Edge Cases "Shapeshifter disconnects while disguised": the disguise is lost at the drop (true form,
## any transformation discarded, no FormChanged since none completed, cooldown and observation kept), so
## it rejoins in true form. Inference: the GDD row names the reconnect outcome, not when the form drops;
## dropping it at the disconnect means no client renders a disguise on an empty seat. A Borrowed Face
## ruling on mid-grace presentation settles it.
func _on_connection_changed(e: ServerEvent) -> void:
	var c := e as EvPlayerConnectionChanged
	if c.player != _monster or c.status != EvPlayerConnectionChanged.DISCONNECTED:
		return
	var changed := _form != TRUE_FORM
	_transforming = false
	_form = TRUE_FORM
	if changed:
		_form_tick = e.tick
		_form_event()


## Reconnect catch-up (ADR-0004 §9, ServerMovement.catch_up): the current form as a FormChanged, which
## projects to the shapeshifter's own client only. Survivor clients get the form from the snapshot
## appearance of the body's fresh introduce.
func catch_up() -> Array[ServerEvent]:
	var e := EvFormChanged.new()
	e.tick = _form_tick
	e.player = _monster
	e.previous = _form
	e.form = _form
	var out: Array[ServerEvent] = [e]
	return out


## Rule 10: a stun during a transformation keeps the previous form and starts the full cooldown at
## the interrupt. A stun outside one costs nothing here (the cooldown follows only completed or
## interrupted transformations, "States and Transitions").
func _on_monster_stunned(e: ServerEvent) -> void:
	if _transforming and (e as EvMonsterStunned).monster == _monster:
		_transforming = false
		_cooldown_end_tick = e.tick + _cooldown_ticks


## Rule 6 and rule 7 except the cooldown (checked in server_tick) and the Lunge/takedown commit
## (Story 004/005). Stunned or shock-locked rejects with no cooldown cost. A request into the
## current form is rejected (inference: no rule names it, and accepting it would only spend the
## change; a designer ruling settles it). Disconnected means Match Flow's DISCONNECTED (grace
## expired); a survivor inside reconnect grace keeps its last status and stays a valid target
## (inference from Match Flow rule 13; a Borrowed Face ruling on in-grace targets settles it).
func _can_change_into(form: int) -> bool:
	if _transforming or form == _form:
		return false
	if _locked.is_valid() and _locked.call(_monster):
		return false
	if _attacking.is_valid() and _attacking.call(_monster):
		return false ## rule 11: never cancels an attack; no cooldown cost (rule 7)
	if form == TRUE_FORM:
		return true
	if not (_survivors.has(form) and observed(form) and _status_of.is_valid()):
		return false
	var st: int = _status_of.call(form)
	return st == MatchFlow.Status.HEALTHY or st == MatchFlow.Status.DOWNED


## Current form: TRUE_FORM or the copied survivor's player id. Unchanged by the copied survivor
## being downed, eliminated, escaping or disconnecting (rule 13).
func form() -> int:
	return _form


## True while a transformation is in progress.
func transforming() -> bool:
	return _transforming


## Target form of the transformation in progress; meaningless when not transforming.
func transform_target() -> int:
	return _target


## Rule 2: one tick of valid observation for each unobserved survivor meeting every condition.
## Survivor Defense (slot 200) runs first, so a stun landing this tick blocks it.
func _observe() -> void:
	if not (_eye_of.is_valid() and _yaw_of.is_valid() and _body_points_of.is_valid() and _sight.is_valid()):
		return
	if _locked.is_valid() and _locked.call(_monster):
		return
	var eye: Vector3 = _eye_of.call(_monster)
	var look := ViewState.direction(_yaw_of.call(_monster), 0.0)
	for s in _survivors:
		if _obs[s] < _observe_ticks and _observable(eye, look, _body_points_of.call(s)):
			_obs[s] += 1


## Rule 3: true once `survivor` has `observe_time_s` of valid observation this round.
func observed(survivor: int) -> bool:
	return _obs.get(survivor, 0) >= _observe_ticks and _observe_ticks > 0


## Seconds of valid observation on `survivor` this round, capped at observe_time_s (for the HUD).
func observation_s(survivor: int) -> float:
	return float(_obs.get(survivor, 0)) / _hz if _hz > 0 else 0.0


## Rule 2 range, cone and line of sight. Range is measured eye to chest (inference: the GDD says
## "dist(monster_eye, survivor)" without naming a point; a designer ruling settles it). The cone is
## horizontal to the chest; a chest straight above or below the eye has angle 0 and counts.
func _observable(eye: Vector3, look: Vector3, points: PackedVector3Array) -> bool:
	if points.size() <= CHEST:
		return false
	var chest := points[CHEST]
	if eye.distance_to(chest) > _range_m + RANGE_EPS_M:
		return false
	var flat := Vector3(chest.x - eye.x, 0.0, chest.z - eye.z)
	if look.angle_to(flat) > _half_fov:
		return false
	for p in points:
		if _sight.call(eye, p):
			return true
	return false
