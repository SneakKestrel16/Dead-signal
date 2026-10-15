class_name SurvivorObjectives extends RefCounted
## Survivor Objectives module, stories 001, 002, 003 and 005 (design/gdd/survivor-objectives.md rules
## 1-3, 8-15, 17-20; ADR-0008). Owns drive and fuse state and carriers (player ids, never nodes). Each active drive
## console, fuse spawn and fuse box is an Interactable on the shared HoldService; its on_complete changes
## state and emits ObjectiveProgressChanged. HoldService emits nothing. Clients send no completion
## message: the only way to change objective state is the server's own hold timer.
## Story 005: two dock slots, the activation panel and one pickup per drive at the terminal; the
## activation countdown runs in server_tick. Match Flow reads ARMED and ACTIVATED from the events alone.
## Story 006 (rule 22): on SurvivorEscaped (Match Flow decides the escape) the drives that survivor
## carries become Extracted. Match Flow counts the EXTRACTED events toward the win.
## Story 002 (rules 11-13, 15): a carrier's drives and fuses drop at the nearest valid floor point under
## them on SurvivorDowned, SurvivorEliminated and disconnect (PlayerConnectionChanged), or on purpose
## (drop()). Each item has one pickup point, moved to wherever it lies; it never despawns.
## Story 004 (rule 16): starting a fuse install (the box's on_start) sends the install noise and an
## alert to the shapeshifter alone: an ObjectiveProgressChanged with state INSTALLING whose projection
## carries only an offset circle that contains the box. Fake holds never call on_start (ADR-0008), so a
## fake install raises neither (rule 26).
## Story 007 (rules 25-26): every point is `fakeable`, so the shapeshifter's Start is a HoldService fake:
## no lock, no state change, no on_start (so no install noise or alert) and a real Start cancels it.
## Not yet here: the registry view of objective state (no StateKeys row).
## Usage:
##   var obj := SurvivorObjectives.new(holds, MapData.load_map(), is_healthy, is_hidden, position_of)
##   obj.drop(actor, SurvivorObjectives.DRIVE_ID + i)   # the carrier's own drop request
##   obj.survivor_ids.assign(survivors)
##   obj.rng = round_rng; obj.emit_sound = server_movement.emit_sound
##   server.start_round({TickOrder.SURVIVOR_OBJECTIVES: obj}, knobs)

enum DriveState { SECURED, CARRIED, DROPPED, DOCKED, EXTRACTED }
## INSTALLING is a fuse box's install alert (story 004), sent at each install start; last so the older
## values keep their numbers. fuse_state_of() never reads it.
enum FuseState { UNFOUND, CARRIED, DROPPED, INSTALLED, INSTALLING }
## Terminal states (GDD States and Transitions); reported with `objective` = TERMINAL_ID. POWERED is
## Locked with both fuses installed (rule 17): sent once, when the second fuse goes in; last so the
## older values keep their numbers. terminal_state() never reads POWERED: it stays LOCKED until ARMED.
enum TerminalState { LOCKED, ARMED, ACTIVATING, ACTIVATED, POWERED }

## Active points for now: the first authored markers of each type. Placeholder until story 008
## (random active point selection, ADR-0012, Proposed) replaces it.
const ACTIVE_DRIVES := 2
const ACTIVE_FUSES := 2
const ACTIVE_FUSE_BOXES := 2
## GDD rule 15: `fuses_required` = 2 and one fuse carried at a time. Rules, not Tuning Knobs rows.
const FUSES_REQUIRED := 2
const MAX_FUSES_CARRIED := 1
## Sound set of the install noise (rule 16); playback is presentation (ADR-0013, Proposed).
const INSTALL_SOUND := &"fuse_install"

## `ObjectiveProgressChanged.objective` id ranges, so one int names one point across kinds: drives
## DRIVE_ID + index, fuses FUSE_ID + index, fuse boxes FUSE_BOX_ID + index (state is a FuseState:
## INSTALLED once filled), the terminal TERMINAL_ID (TerminalState).
const DRIVE_ID := 0
const FUSE_ID := 10
const FUSE_BOX_ID := 20
const TERMINAL_ID := 30
## Keeps a snapped drop inside its volume: a volume's east and south edges belong to the next one.
const FLOOR_EPS_M := 1e-3

## Player ids of this round's survivors; set before setup. Only they hold the terminal zone: the
## shapeshifter never counts (rule 19).
var survivor_ids: Array[int] = []
## Places the install alert's circle; seed it for reproducible rounds and tests.
var rng := RandomNumberGenerator.new()
## `emit_sound(position: Vector3, sound_set: StringName, radius_m: float)`, NA-9's positional sound
## send (ServerMovement.emit_sound). Invalid = no install noise is sent.
var emit_sound: Callable = Callable()

var _holds: HoldService
var _map: MapData
var _is_healthy: Callable
var _is_hidden: Callable
var _position_of: Callable
var _bus: EventBus
var _knobs: Knobs
## Active drive index -> state / carrier player id (-1 = none). Index is the event's `objective`.
var _states: Array[DriveState] = []
var _carriers: Array[int] = []
var _marker_ids: Array[StringName] = []
## Active fuse index -> state / carrier player id (-1 = none).
var _fuse_states: Array[FuseState] = []
var _fuse_carriers: Array[int] = []
## Active fuse box index -> installed fuse index (-1 = empty).
var _box_fuses: Array[int] = []
var _box_points: Array[Vector3] = []
## Dock slot -> docked drive index (-1 = empty).
var _slots: Array[int] = []
var _terminal: TerminalState = TerminalState.LOCKED
var _terminal_point: Vector3
## Drive / fuse index -> the point a Dropped item is picked up at (rules 11, 20). Moved to each drop.
var _drive_pickups: Array[ObjectivePoint] = []
var _fuse_pickups: Array[ObjectivePoint] = []
## Activating ticks with the zone held (Formulas "Effective activation time"); never reset.
var _activation_ticks: int = 0


## `is_healthy(actor: int) -> bool` is the life-state source (Downing's view once it exists); pass an
## invalid Callable to treat everyone as Healthy. `is_hidden(actor: int) -> bool` (Survivor Defense;
## absent = nobody hidden) and `position_of(actor: int) -> Vector3` (absent = nobody in the terminal
## zone) feed the activation countdown; position_of also places drops (absent = at the terminal).
func _init(holds: HoldService, map: MapData, is_healthy: Callable = Callable(),
		is_hidden: Callable = Callable(), position_of: Callable = Callable()) -> void:
	_holds = holds
	_map = map
	_is_healthy = is_healthy
	_is_hidden = is_hidden
	_position_of = position_of


## RoundServer entry: builds the active points and registers their interactables (drives, fuses, boxes,
## then at the terminal: dock slots, the activation panel and one pickup per drive).
func setup(_tick_runner: Node, bus: EventBus, _registry: StateRegistry, knobs: Knobs) -> void:
	_bus = bus
	_knobs = knobs
	_states = []
	_carriers = []
	_marker_ids = []
	_fuse_states = []
	_fuse_carriers = []
	_box_fuses = []
	_box_points = []
	_slots = []
	_drive_pickups = []
	_fuse_pickups = []
	_terminal = TerminalState.LOCKED
	_activation_ticks = 0
	## Named method, not a lambda: the bus must not keep the module alive (no RefCounted cycle).
	bus.subscribe(&"SurvivorEscaped", _on_escaped)
	bus.subscribe(&"SurvivorDowned", _on_downed)
	bus.subscribe(&"SurvivorEliminated", _on_eliminated)
	bus.subscribe(&"PlayerConnectionChanged", _on_connection)
	var o := knobs.objectives
	for m: MapMarker in _first(&"drive", ACTIVE_DRIVES):
		_add(DriveConsole.new(), _states.size(), m, o.drive_extract_s)
		_marker_ids.append(m.id)
		_states.append(DriveState.SECURED)
		_carriers.append(-1)
	for m: MapMarker in _first(&"fuse", ACTIVE_FUSES):
		_add(FuseSpawn.new(), _fuse_states.size(), m, o.pickup_s)
		_fuse_states.append(FuseState.UNFOUND)
		_fuse_carriers.append(-1)
	for m: MapMarker in _first(&"fuse_box", ACTIVE_FUSE_BOXES):
		_add(FuseBox.new(), _box_fuses.size(), m, o.fuse_install_s)
		_box_fuses.append(-1)
		_box_points.append(m.position)
	for m: MapMarker in _first(&"terminal", 1):
		_terminal_point = m.position
		for i in ACTIVE_DRIVES:
			_add(DockSlot.new(), i, m, o.dock_s, "_slot%d" % i)
			_slots.append(-1)
		_add(TerminalPanel.new(), 0, m, o.activation_start_s, "_panel")
		for i in _states.size(): ## ejected drives lie at the terminal (rule 20); moved on each drop
			_drive_pickups.append(_add(DrivePickup.new(), i, m, o.pickup_s, "_drive%d" % i))
	## Registered last so the earlier net ids keep their numbers; moved to each drop.
	for m: MapMarker in _first(&"fuse", ACTIVE_FUSES):
		_fuse_pickups.append(_add(FusePickup.new(), _fuse_pickups.size(), m, o.pickup_s, "_dropped"))


func _first(type: StringName, n: int) -> Array[MapMarker]:
	var out: Array[MapMarker] = []
	for m: MapMarker in _map.markers:
		if m.type == type and out.size() < n:
			out.append(m)
	if out.size() < n:
		push_error("SurvivorObjectives: map has %d %s markers, needs %d" % [out.size(), type, n])
	return out


## `lock_tag` splits one marker into separately locked points (each dock slot, each ejected drive).
func _add(p: ObjectivePoint, index: int, m: MapMarker, duration_s: float, lock_tag := "") -> ObjectivePoint:
	p.owner = weakref(self)
	p.index = index
	p.point = m.position
	p.range_m = _knobs.objectives.interact_range_m
	p.duration_s = duration_s
	p.lock_key = StringName("%s_%s%s" % [m.type, m.id, lock_tag])
	## Rule 25: the shapeshifter fakes at any objective point; HoldService never calls the owner for a fake.
	## Inference: "any objective point" includes fuse spawns and dropped-item pickups, not only the
	## console, box and terminal the rule lists; a designer ruling on rule 25's list settles it.
	p.fakeable = true
	_holds.register(p)
	return p


## Activation countdown (rule 19): counts each Activating tick with the zone held, pauses otherwise,
## and activates once the count reaches `evac_activation_s`. Holds are timed in the Holds step.
func server_tick(_tick: int) -> void:
	if _terminal != TerminalState.ACTIVATING or not _zone_held():
		return
	_activation_ticks += 1
	if _activation_ticks >= _knobs.ticks(_knobs.objectives.evac_activation_s):
		_activate()


## Terminal state: LOCKED, ARMED, ACTIVATING or ACTIVATED (never POWERED).
func terminal_state() -> TerminalState:
	return _terminal


## True once evacuation is activated (rule 20).
func exit_open() -> bool:
	return _terminal == TerminalState.ACTIVATED


## Number of active drives.
func drive_count() -> int:
	return _states.size()


## State of active drive `index`.
func state_of(index: int) -> DriveState:
	return _states[index]


## Player id carrying drive `index`, -1 if nobody.
func carrier_of(index: int) -> int:
	return _carriers[index]


## How many drives `actor` carries.
func carried_by(actor: int) -> int:
	return _carriers.count(actor)


## State of active fuse `index`.
func fuse_state_of(index: int) -> FuseState:
	return _fuse_states[index]


## Player id carrying fuse `index`, -1 if nobody.
func fuse_carrier_of(index: int) -> int:
	return _fuse_carriers[index]


## Fuse index installed in active box `index`, -1 if empty.
func box_fuse_of(index: int) -> int:
	return _box_fuses[index]


## True once FUSES_REQUIRED fuses are installed (rule 17). Installed fuses are permanent.
func power_restored() -> bool:
	return _fuse_states.count(FuseState.INSTALLED) >= FUSES_REQUIRED


## Where drive (DRIVE_ID + i) or fuse (FUSE_ID + i) `objective` is picked up while Dropped.
func dropped_at(objective: int) -> Vector3:
	if objective >= FUSE_ID:
		return _fuse_pickups[objective - FUSE_ID].point
	return _drive_pickups[objective - DRIVE_ID].point


## Rules 11, 15: `actor` drops the drive (DRIVE_ID + i) or fuse (FUSE_ID + i) they carry, instantly, at
## their position. False and no change unless they carry it. A hold that needed it ends on its next
## eligibility check.
func drop(actor: int, objective: int) -> bool:
	var i := objective - DRIVE_ID
	if i >= 0 and i < _states.size() and _states[i] == DriveState.CARRIED and _carriers[i] == actor:
		_drop_drive(i, _floor_point(_where(actor)))
		return true
	i = objective - FUSE_ID
	if i >= 0 and i < _fuse_states.size() and _fuse_states[i] == FuseState.CARRIED \
			and _fuse_carriers[i] == actor:
		_drop_fuse(i, _floor_point(_where(actor)))
		return true
	return false


func _healthy(actor: int) -> bool:
	if not _is_healthy.is_valid():
		return true
	var healthy: bool = _is_healthy.call(actor)
	return healthy


## Drive pickup: Healthy, carrier under the cap, drive in `from` (SECURED at its console, or DROPPED).
func _can_extract(index: int, actor: int, from := DriveState.SECURED) -> bool:
	if _states[index] != from or not _healthy(actor):
		return false
	return carried_by(actor) < _knobs.objectives.max_drives_carried


func _complete(index: int, actor: int, from := DriveState.SECURED) -> void:
	if not _can_extract(index, actor, from):
		return
	_states[index] = DriveState.CARRIED
	_carriers[index] = actor
	## the extractor was in the room; a carried drive is shown to every survivor (rule 10)
	_emit(DRIVE_ID + index, DriveState.CARRIED)


## Fuse pickup: Healthy, fuse in `from` (UNFOUND at its spawn, or DROPPED where it fell), carrier under
## the one-fuse cap. Drives do not count against it (rule 15).
func _can_pick_up(index: int, actor: int, from := FuseState.UNFOUND) -> bool:
	if _fuse_states[index] != from or not _healthy(actor):
		return false
	return _fuse_carriers.count(actor) < MAX_FUSES_CARRIED


func _pick_up(index: int, actor: int, from := FuseState.UNFOUND) -> void:
	if not _can_pick_up(index, actor, from):
		return
	_fuse_states[index] = FuseState.CARRIED
	_fuse_carriers[index] = actor
	_emit(FUSE_ID + index, FuseState.CARRIED)


## Install: Healthy, carrying a fuse, box still empty (each box takes one fuse; rule 15).
func _can_install(box: int, actor: int) -> bool:
	return _box_fuses[box] == -1 and _healthy(actor) and _fuse_carriers.has(actor)


## Rule 16 at install start: the install noise to everyone within `install_noise_radius_m` and the
## shapeshifter-only alert circle. A cancelled and restarted install starts again, so alerts again.
func _install_started(box: int) -> void:
	var o := _knobs.objectives
	var at: Vector3 = _box_points[box]
	if emit_sound.is_valid():
		## inference: the installer hears it too (source -1); no install sound is predicted client-side
		## yet. ADR-0013 (audio, Proposed) settles it.
		emit_sound.call(at, INSTALL_SOUND, o.install_noise_radius_m)
	var e := EvObjectiveProgressChanged.new()
	e.objective = FUSE_BOX_ID + box
	e.state = FuseState.INSTALLING
	e.alert_centre = alert_centre(at, o.alert_area_radius_m, rng)
	e.alert_radius_m = o.alert_area_radius_m
	e.alert_duration_s = o.alert_duration_s
	_bus.emit(e)


## Formulas "Install alert placement": `box` plus a point uniform in the horizontal disc of `radius_m`,
## so the circle of `radius_m` round the result always contains the box.
static func alert_centre(box: Vector3, radius_m: float, random: RandomNumberGenerator) -> Vector3:
	var r := radius_m * sqrt(random.randf())
	var a := random.randf() * TAU
	return box + Vector3(cos(a) * r, 0.0, sin(a) * r)


func _install(box: int, actor: int) -> void:
	if not _can_install(box, actor):
		return
	var fuse := _fuse_carriers.find(actor)
	_fuse_states[fuse] = FuseState.INSTALLED
	_fuse_carriers[fuse] = -1
	_box_fuses[box] = fuse
	_emit(FUSE_ID + fuse, FuseState.INSTALLED)
	_emit(FUSE_BOX_ID + box, FuseState.INSTALLED) ## boxes are always marked (rule 7)
	if _fuse_states.count(FuseState.INSTALLED) == FUSES_REQUIRED: ## exactly once: installs are permanent
		_emit(TERMINAL_ID, TerminalState.POWERED)
	_try_arm()


## Dock (rule 14): Healthy, carrying a drive, slot empty, terminal not yet armed. Allowed before power.
func _can_dock(slot: int, actor: int) -> bool:
	return _terminal == TerminalState.LOCKED and _slots[slot] == -1 and _healthy(actor) \
		and _carriers.has(actor)


func _dock(slot: int, actor: int) -> void:
	if not _can_dock(slot, actor):
		return
	var drive := _carriers.find(actor)
	_states[drive] = DriveState.DOCKED
	_carriers[drive] = -1
	_slots[slot] = drive
	_emit(DRIVE_ID + drive, DriveState.DOCKED)
	_try_arm()


## Rule 18: Armed exactly when both slots hold a drive and power is restored. Sent once.
func _try_arm() -> void:
	if _terminal == TerminalState.LOCKED and not _slots.is_empty() and not _slots.has(-1) \
			and power_restored():
		_terminal = TerminalState.ARMED
		_emit(TERMINAL_ID, TerminalState.ARMED)


func _can_start(actor: int) -> bool:
	return _terminal == TerminalState.ARMED and _healthy(actor)


func _start(actor: int) -> void:
	if not _can_start(actor):
		return
	_terminal = TerminalState.ACTIVATING
	_emit(TERMINAL_ID, TerminalState.ACTIVATING)


## Rule 19: a Healthy, non-hidden survivor within `terminal_zone_radius_m` (horizontal) of the terminal.
func _zone_held() -> bool:
	if not _position_of.is_valid():
		return false
	var r := _knobs.objectives.terminal_zone_radius_m
	for id in survivor_ids:
		if not _healthy(id) or (_is_hidden.is_valid() and _is_hidden.call(id)):
			continue
		var p: Vector3 = _position_of.call(id)
		if Vector2(p.x - _terminal_point.x, p.z - _terminal_point.z).length() <= r:
			return true
	return false


## Rule 20: opens the exit and ejects both docked drives at the terminal as Dropped.
func _activate() -> void:
	_terminal = TerminalState.ACTIVATED
	for slot in _slots.size():
		var drive := _slots[slot]
		_slots[slot] = -1
		_states[drive] = DriveState.DROPPED
		_drive_pickups[drive].point = _terminal_point
		_emit(DRIVE_ID + drive, DriveState.DROPPED)
	_emit(TERMINAL_ID, TerminalState.ACTIVATED)


## Rule 22: the drives an escaping survivor carries leave with them as Extracted.
func _on_escaped(e: ServerEvent) -> void:
	var actor := (e as EvSurvivorEscaped).survivor
	for drive in _carriers.size():
		if _carriers[drive] == actor:
			_states[drive] = DriveState.EXTRACTED
			_carriers[drive] = -1
			_emit(DRIVE_ID + drive, DriveState.EXTRACTED)


## Rule 12: a Downed carrier drops everything they carry where they went down.
func _on_downed(e: ServerEvent) -> void:
	_drop_all((e as EvSurvivorDowned).survivor)


## Rule 13: dropped at the last position; a carrier Downed first has nothing left to drop.
func _on_eliminated(e: ServerEvent) -> void:
	_drop_all((e as EvSurvivorEliminated).survivor)


## Rule 13, Edge Cases: a disconnect drops at once, before the reconnect grace; a reconnect gives
## nothing back.
func _on_connection(e: ServerEvent) -> void:
	var c := e as EvPlayerConnectionChanged
	if c.status == EvPlayerConnectionChanged.DISCONNECTED:
		_drop_all(c.player)


func _drop_all(actor: int) -> void:
	var at := _floor_point(_where(actor))
	for i in _carriers.size():
		if _carriers[i] == actor:
			_drop_drive(i, at)
	for i in _fuse_carriers.size():
		if _fuse_carriers[i] == actor:
			_drop_fuse(i, at)


func _drop_drive(i: int, at: Vector3) -> void:
	_states[i] = DriveState.DROPPED
	_carriers[i] = -1
	_drive_pickups[i].point = at
	_emit(DRIVE_ID + i, DriveState.DROPPED) ## marked for all survivors as "Drive dropped" (rule 12)


func _drop_fuse(i: int, at: Vector3) -> void:
	_fuse_states[i] = FuseState.DROPPED
	_fuse_carriers[i] = -1
	_fuse_pickups[i].point = at
	_emit(FUSE_ID + i, FuseState.DROPPED)


func _where(actor: int) -> Vector3:
	if not _position_of.is_valid():
		return _terminal_point
	var p: Vector3 = _position_of.call(actor)
	return p


## Edge Cases "nearest valid floor point": the point in the nearest map volume (horizontal distance) at
## that volume's floor; no physics. Inference: the map has no walkable-floor data finer than its
## volumes, so props inside a volume are not avoided; authored floor data in the map file would settle it.
func _floor_point(p: Vector3) -> Vector3:
	var best := p
	var best_d := INF
	for v: MapVolume in _map.volumes:
		var b := v.box
		var q := Vector3(clampf(p.x, b.position.x, b.end.x - FLOOR_EPS_M), b.position.y,
			clampf(p.z, b.position.z, b.end.z - FLOOR_EPS_M))
		var d := Vector2(q.x - p.x, q.z - p.z).length()
		if d < best_d:
			best = q
			best_d = d
	return best


## Every event here is about something carried, installed or always marked, so `discovered` is true.
func _emit(objective: int, state: int) -> void:
	var e := EvObjectiveProgressChanged.new()
	e.objective = objective
	e.state = state
	e.discovered = true
	_bus.emit(e)


## The drive console (GDD rule 8).
class DriveConsole extends ObjectivePoint:
	## Healthy, drive still Secured, carrier under the cap.
	func eligible(actor: int) -> bool:
		var m: SurvivorObjectives = owner.get_ref()
		return m != null and m._can_extract(index, actor)

	## Gives the drive to `actor`.
	func on_complete(actor: int) -> void:
		var m: SurvivorObjectives = owner.get_ref()
		if m != null:
			m._complete(index, actor)


## A fuse lying at its spawn (GDD rule 15, `pickup_s` hold); Unfound only (a dropped one is a FusePickup).
class FuseSpawn extends ObjectivePoint:
	func eligible(actor: int) -> bool:
		var m: SurvivorObjectives = owner.get_ref()
		return m != null and m._can_pick_up(index, actor)

	## Gives the fuse to `actor`.
	func on_complete(actor: int) -> void:
		var m: SurvivorObjectives = owner.get_ref()
		if m != null:
			m._pick_up(index, actor)


## A dropped fuse where it fell (GDD rule 15, `pickup_s` hold). Eligible only while Dropped.
class FusePickup extends ObjectivePoint:
	func eligible(actor: int) -> bool:
		var m: SurvivorObjectives = owner.get_ref()
		return m != null and m._can_pick_up(index, actor, SurvivorObjectives.FuseState.DROPPED)

	## Gives the fuse to `actor`.
	func on_complete(actor: int) -> void:
		var m: SurvivorObjectives = owner.get_ref()
		if m != null:
			m._pick_up(index, actor, SurvivorObjectives.FuseState.DROPPED)


## An active fuse box (GDD rule 15, `fuse_install_s` hold). One holder at a time: its lock_key.
class FuseBox extends ObjectivePoint:
	func eligible(actor: int) -> bool:
		var m: SurvivorObjectives = owner.get_ref()
		return m != null and m._can_install(index, actor)

	## Installs the fuse `actor` carries.
	func on_complete(actor: int) -> void:
		var m: SurvivorObjectives = owner.get_ref()
		if m != null:
			m._install(index, actor)

	## Install start (rule 16): noise and the shapeshifter's alert. HoldService calls this only after
	## eligible() and the lock passed.
	func on_start(_actor: int) -> void:
		var m: SurvivorObjectives = owner.get_ref()
		if m != null:
			m._install_started(index)


## A terminal drive slot (GDD rule 14, `dock_s` hold). Each slot has its own lock.
class DockSlot extends ObjectivePoint:
	func eligible(actor: int) -> bool:
		var m: SurvivorObjectives = owner.get_ref()
		return m != null and m._can_dock(index, actor)

	## Docks a drive `actor` carries.
	func on_complete(actor: int) -> void:
		var m: SurvivorObjectives = owner.get_ref()
		if m != null:
			m._dock(index, actor)


## The terminal's activation panel (GDD rule 19, `activation_start_s` hold); accepts only when Armed.
class TerminalPanel extends ObjectivePoint:
	func eligible(actor: int) -> bool:
		var m: SurvivorObjectives = owner.get_ref()
		return m != null and m._can_start(actor)

	## Starts the activation countdown.
	func on_complete(actor: int) -> void:
		var m: SurvivorObjectives = owner.get_ref()
		if m != null:
			m._start(actor)


## A dropped drive (GDD rules 11, 20, `pickup_s` hold): at the terminal after ejection, or where it
## fell. Eligible only while Dropped, so a docked drive cannot be removed.
class DrivePickup extends ObjectivePoint:
	func eligible(actor: int) -> bool:
		var m: SurvivorObjectives = owner.get_ref()
		return m != null and m._can_extract(index, actor, SurvivorObjectives.DriveState.DROPPED)

	## Gives the drive to `actor`.
	func on_complete(actor: int) -> void:
		var m: SurvivorObjectives = owner.get_ref()
		if m != null:
			m._complete(index, actor, SurvivorObjectives.DriveState.DROPPED)
