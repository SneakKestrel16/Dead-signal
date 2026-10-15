class_name SurvivorDefense extends RefCounted
## Survivor Defense: taser charges, the reuse delay and the item-use gate (Feature layer). Implements
## design/gdd/survivor-defense.md rules 1, 7, 8 (fire and reuse only), 13 and 29; story
## survivor-defense/001; ADR-0002 (clients send intent only), ADR-0005 (TickOrder.SURVIVOR_DEFENSE),
## ADR-0006 (DefenseKnobs). Later stories add the trace (002), the shock lock (003) and hiding (006).
## Server only. Timers count ticks of `net.sim_tick_hz`, never wall time. Clients send a fire intent
## and nothing else: the server owns every charge, so a client claim of a hit, a charge or a finished
## barricade has no entry point and changes nothing (rule 1).
## Usage:
##   var sd := SurvivorDefense.new()
##   sd.set_roster([2, 3, 4, 5], 1)        # survivor ids, monster id: BEFORE start_round
##   sd.set_locked(downing.action_locked)  # Seized / Downed gate (downing-and-rescue.md rule 4.2)
##   server.start_round({TickOrder.SURVIVOR_DEFENSE: sd}, knobs)
##   smp.peer_packet -> sd.request_intent(net.player_id_of(peer), bytes)

## Intent value: fire one cartridge (rule 8).
const FIRE := 1
## Intent packet dictionary key.
const INTENT_KEY := "item"
## decode_intent's result for bytes that are not an intent.
const INVALID_INTENT := 0
## Size cap of an intent packet; anything larger is not one (untrusted client bytes).
const REQUEST_CAP_BYTES := 64

var _survivors: Array[int] = []
var _stun_item_charges: int = 0
var _reuse_ticks: int = 0
## player id -> bool, Downing.action_locked (Seized or Downed); invalid means never locked.
var _is_locked: Callable
## survivor -> cartridges left; absent (the monster, anyone else) has no items.
var _charges: Dictionary[int, int] = {}
## survivor -> first tick a fire is accepted again (rule 8 reuse delay); absent = no delay running.
var _ready_tick: Dictionary[int, int] = {}
## Hidden survivors. Story 006's hide flow drives this through set_hidden.
var _hidden: Dictionary[int, bool] = {}
## player -> this tick's intent (the first one received since the last tick).
var _pending: Dictionary[int, int] = {}


## Getter-only view for StateKeys.HIDDEN_ITEM_USE readers. Holds the module weakly; after the module
## is freed it reads as no charges, not hidden.
class DefenseView extends RefCounted:
	var _sd: WeakRef

	func _init(sd: SurvivorDefense) -> void:
		_sd = weakref(sd)

	## Cartridges `player` has left.
	func charges(player: int) -> int:
		var sd := _sd.get_ref() as SurvivorDefense
		return sd.charges(player) if sd != null else 0

	## Whether `player` is hidden.
	func is_hidden(player: int) -> bool:
		var sd := _sd.get_ref() as SurvivorDefense
		return sd.is_hidden(player) if sd != null else false


## Injects the round's roster. Call before RoundServer.start_round (setup resets state from it).
## The monster id is not kept: it has no items (rule 13), which the roster alone already says.
func set_roster(survivors: Array[int], _monster: int) -> void:
	_survivors = survivors.duplicate()


## Injects the Seized/Downed gate: `source.call(player_id) -> bool` (Downing.action_locked).
## Unset, nobody is locked.
func set_locked(source: Callable) -> void:
	_is_locked = source


## Marks `player` hidden (`on` true) or not. Story 006's hide flow drives this; nothing else should.
func set_hidden(player: int, on: bool) -> void:
	if on:
		_hidden[player] = true
	else:
		_hidden.erase(player)


## Injected by RoundServer. Every survivor starts with `stun_item_charges` cartridges (rules 7, 29),
## no reuse delay, not hidden. Publishes the HIDDEN_ITEM_USE view and subscribes to SurvivorEliminated.
func setup(_tick_runner: TickRunner, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
	_stun_item_charges = knobs.defense.stun_item_charges
	_reuse_ticks = knobs.ticks(knobs.defense.stun_item_reuse_s)
	_charges = {}
	_ready_tick = {}
	_hidden = {}
	_pending = {}
	for s in _survivors:
		_charges[s] = _stun_item_charges
	registry.register_view(StateKeys.HIDDEN_ITEM_USE, &"SurvivorDefense", DefenseView.new(self))
	bus.subscribe(&"SurvivorEliminated", _on_eliminated)


## The bytes a survivor's client sends to fire its taser.
static func fire_packet() -> PackedByteArray:
	return var_to_bytes({INTENT_KEY: FIRE})


## The intent in untrusted `bytes`, or INVALID_INTENT when they are not exactly a known intent. Only
## the shape is checked; whether it may run is decided in server_tick.
static func decode_intent(bytes: PackedByteArray) -> int:
	if bytes.is_empty() or bytes.size() > REQUEST_CAP_BYTES:
		return INVALID_INTENT
	var d: Variant = bytes_to_var(bytes)
	if not (d is Dictionary and d.size() == 1 and d.get(INTENT_KEY) is int and d[INTENT_KEY] == FIRE):
		return INVALID_INTENT
	return d[INTENT_KEY]


## Server entry for a client's intent from `player` (the sender as the network layer identifies it,
## never a field of the bytes). Only the first intent of a tick is kept; it is validated at the
## SURVIVOR_DEFENSE step.
func request_intent(player: int, bytes: PackedByteArray) -> void:
	if _pending.has(player):
		return
	var intent := decode_intent(bytes)
	if intent != INVALID_INTENT:
		_pending[player] = intent


## SURVIVOR_DEFENSE slot: validates this tick's fire intents (rules 8, 13). A survivor downed on this
## tick was Seized until Downing's slot (500) and so is already refused here.
func server_tick(tick: int) -> void:
	for p: int in _pending:
		if can_fire(p, tick):
			_charges[p] -= 1
			_ready_tick[p] = tick + _reuse_ticks
	_pending = {}


## Rules 7, 8, 13: `player` is a survivor with a cartridge left, outside the reuse delay, not Seized,
## Downed or hidden on `tick`.
func can_fire(player: int, tick: int) -> bool:
	return _charges.get(player, 0) > 0 and tick >= _ready_tick.get(player, 0) and not is_hidden(player) \
		and not (_is_locked.is_valid() and _is_locked.call(player))


## Cartridges `player` has left (0 for the monster or any id not in the roster).
func charges(player: int) -> int:
	return _charges.get(player, 0)


## Whether `player` is hidden.
func is_hidden(player: int) -> bool:
	return _hidden.has(player)


## Rule 13: charges are lost on elimination.
func _on_eliminated(e: ServerEvent) -> void:
	var s := (e as EvSurvivorEliminated).survivor
	if _charges.has(s):
		_charges[s] = 0
