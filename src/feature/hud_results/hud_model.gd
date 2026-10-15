class_name HudModel extends RefCounted
## The HUD's only source (ADR-0014 §6; design/ux/hud.md Information Architecture). Client only, decides
## nothing. Two writers: the own snapshot entry (on_own_body, called by the snapshot handler) and
## ClientEventRouter handlers (objectives, roster, feed lines, markers, cooldowns). Phase and clock are
## not copied: they are read from MatchDisplay. Widgets connect to the signals, read the getters, and never
## hold a gameplay module, the snapshot or the router. Untrusted payloads are shape-checked and ignored if bad.
## Deviation from ADR-0014 §6: a sixth signal, roster_changed, because the roster is its own element group
## (hud.md) and none of the five covers it.
## Shapeshifter state (story 006, S1-S6): the producer is MonsterHudFeed, one EventBatch.MONSTER_HUD entry
## sent to the shapeshifter's peer only (ready ticks, transformation end, stun and immunity ends, observation);
## on_monster_hud() fills the cooldowns from it. The install alert is the shapeshifter-only form of
## ObjectiveProgressChanged ({centre, radius_m, duration_s}). A survivor client never receives either, so
## is_shapeshifter() stays false there. Deviation from ADR-0014 §6: a seventh signal, monster_state_changed,
## for that element group. on_cooldown() keeps story 001's single-cooldown shape for tests; nothing sends it.
## Usage (client composition root):
##   var model := HudModel.new(match_display, knobs, router)
##   model.own_state_changed.connect(widget.refresh); widget.show(model.objective_lines())

signal objectives_changed
signal roster_changed
signal feed_line_added(line: Dictionary)
signal marker_changed(marker_id: int)
signal cooldowns_changed
signal own_state_changed
signal monster_state_changed

## Roster life states.
const LIFE_UNKNOWN := -1
const LIFE_HEALTHY := 0
const LIFE_DOWNED := 1
const LIFE_ELIMINATED := 2
const LIFE_ESCAPED := 3
## hud.md Visual Budget: at most 6 world markers at once; further markers keep the newest (story 007).
const MAX_MARKERS := 6

var _display: MatchDisplay
var _hz: int
var _marker_life_ticks: int
var _marker_max_active: int
var _feed_cap: int = PingCalloutHud.FEED_SCROLLBACK ## hud.md H10 scrollback
var _objectives: Dictionary[int, Dictionary] = {}
var _roster: Dictionary[int, int] = {}
var _own: Dictionary = {}
var _feed: Array[Dictionary] = []
var _markers: Array[Dictionary] = [] ## oldest first; "expires" is a server tick
var _ready_tick: Dictionary[StringName, int] = {} ## ability -> server tick it is ready again
var _transform_ticks: int
var _observe_s: float
var _monster: Dictionary = {} ## the newest MONSTER_HUD payload; empty on a survivor client
var _alerts: Array[Dictionary] = [] ## install alerts {centre, radius_m, expires (server tick)}
var _names: Dictionary[int, String] = {} ## survivor player id -> display name (set_survivors)
var _activation: Dictionary = {} ## {remaining_s, paused} (on_activation); empty = unknown


## `router`: subscribes the event handlers; null = call them by hand (tests).
func _init(display: MatchDisplay, knobs: Knobs, router: ClientEventRouter = null) -> void:
	_display = display
	_hz = knobs.net.sim_tick_hz
	_marker_life_ticks = knobs.ticks(knobs.ping.ping_lifetime_s)
	_marker_max_active = knobs.ping.ping_max_active
	_transform_ticks = knobs.ticks(knobs.borrowed_face.transform_duration_s)
	_observe_s = knobs.borrowed_face.observe_time_s
	if router != null:
		router.subscribe(&"ObjectiveProgressChanged", on_objective)
		for t: StringName in [&"SurvivorDowned", &"SurvivorRescued", &"SurvivorEliminated", &"SurvivorEscaped"]:
			router.subscribe(t, on_survivor_event.bind(t))
		router.subscribe(EventBatch.CALLOUT, on_callout)
		router.subscribe(EventBatch.PING, on_ping)
		router.subscribe(EventBatch.MONSTER_HUD, on_monster_hud)


## Current Phase (MatchFlow.Phase), -1 before the round begins (MatchDisplay).
func phase() -> int:
	return _display.phase()


## Seconds to the round deadline (MatchDisplay).
func time_remaining_s() -> float:
	return _display.time_remaining_s()


## One line per objective: {objective, state, carrier, at?}, in objective id order. A copy.
func objective_lines() -> Array[Dictionary]:
	var ids := _objectives.keys()
	ids.sort()
	var out: Array[Dictionary] = []
	for id: int in ids:
		out.append(_objectives[id].duplicate())
	return out


## Survivors the model has heard of: {survivor, state}, in id order.
func roster() -> Array[Dictionary]:
	var ids := _roster.keys()
	ids.sort()
	var out: Array[Dictionary] = []
	for id: int in ids:
		out.append({"survivor": id, "state": _roster[id]})
	return out


## Life state of `survivor` (LIFE_*), LIFE_UNKNOWN before any event named it.
func roster_state(survivor: int) -> int:
	return _roster.get(survivor, LIFE_UNKNOWN)


## Display name of survivor `survivor` (set_survivors), "" when unknown.
func name_of(survivor: int) -> String:
	return _names.get(survivor, "")


## Seeds the round's survivors (player id -> display name) as Healthy, keeping any state already heard
## (story hud-results/002, H4). No server message carries the round roster to clients yet (lobby-to-round
## wiring, match-flow story 013, is the inferred producer); until then the roster holds only the survivors
## an event named.
func set_survivors(names: Dictionary) -> void:
	for id: Variant in names:
		if id is int:
			_names[id] = str(names[id])
			if not _roster.has(id):
				_roster[id] = LIFE_HEALTHY
	roster_changed.emit()


## Evacuation activation countdown (H3): {remaining_s: float, paused: bool}, empty when unknown. A copy.
func activation() -> Dictionary:
	return _activation.duplicate()


## Handler for the activation countdown: {remaining_s: float, paused: bool}. No server message carries it
## yet (inference: SurvivorObjectives' _activation_ticks and zone check, sent per change; wired when the
## objectives epic names the producer), so H3 shows the terminal's Activating state without seconds.
func on_activation(_tick: int, p: Dictionary) -> void:
	if not (p.get("remaining_s") is float and p.get("paused") is bool):
		return
	_activation = {"remaining_s": p["remaining_s"], "paused": p["paused"]}
	objectives_changed.emit()


## The own body's snapshot entry (gait, hold echo, ...), a copy; empty before the first snapshot.
func own_state() -> Dictionary:
	return _own.duplicate()


## Callout feed lines, oldest first, at most the scrollback. A copy.
func feed_lines() -> Array[Dictionary]:
	return _feed.duplicate()


## The live ping markers at the newest server tick, oldest first: the delivered payload plus "expires".
func markers() -> Array[Dictionary]:
	return markers_at(_display.server_tick())


## The live ping markers at server tick `now`, oldest first (the HUD passes its estimated tick). A copy of
## the list; do not mutate the entries.
func markers_at(now: int) -> Array[Dictionary]:
	return _markers.filter(func(m: Dictionary) -> bool: return m["expires"] > now)


## Seconds until `ability` is ready; 0.0 when unknown or ready.
func cooldown_remaining_s(ability: StringName) -> float:
	if not _ready_tick.has(ability):
		return 0.0
	return float(maxi(0, _ready_tick[ability] - maxi(_display.server_tick(), 0))) / float(_hz)


## Snapshot handler: the own body's decoded entry.
func on_own_body(body: Dictionary) -> void:
	if body != _own:
		_own = body.duplicate()
		own_state_changed.emit()


## ClientEventRouter handler for ObjectiveProgressChanged. An install alert (no `objective`) is not a line:
## it becomes an S6 alert living duration_s from `tick`.
func on_objective(tick: int, p: Dictionary) -> void:
	if p.get("centre") is Vector3 and p.get("radius_m") is float and p.get("duration_s") is float:
		_alerts.append({"centre": p["centre"], "radius_m": p["radius_m"],
			"expires": tick + roundi(p["duration_s"] * _hz)})
		monster_state_changed.emit()
		return
	if not (p.get("objective") is int and p.get("state") is int):
		return
	_objectives[p["objective"]] = {"objective": p["objective"], "state": p["state"],
		"carrier": p.get("carrier", -1), "at": p.get("at", Vector3.INF)}
	objectives_changed.emit()


## ClientEventRouter handler (bound with the event type) for the survivor life events.
func on_survivor_event(_tick: int, p: Dictionary, type: StringName) -> void:
	var id: Variant = p.get("survivor")
	if not id is int:
		return
	match type:
		&"SurvivorDowned": _roster[id] = LIFE_DOWNED
		&"SurvivorRescued": _roster[id] = LIFE_HEALTHY
		&"SurvivorEliminated": _roster[id] = LIFE_ELIMINATED
		&"SurvivorEscaped": _roster[id] = LIFE_ESCAPED
		_: return
	roster_changed.emit()


## ClientEventRouter handler for EventBatch.CALLOUT.
func on_callout(tick: int, p: Dictionary) -> void:
	if not (p.get("line") is StringName or p.get("line") is String):
		return
	var line := {"tick": tick, "line": StringName(p["line"]), "identity": p.get("identity", -1),
		"origin": p.get("origin", Vector3.ZERO), "gesture": p.get("gesture", false),
		"voice": p.get("voice", &""), "not_you": p.get("not_you", false)}
	_feed.append(line)
	if _feed.size() > _feed_cap:
		_feed.remove_at(0)
	feed_line_added.emit(line)


## ClientEventRouter handler for EventBatch.PING (pings-and-callouts rules 5, 8; story pings-and-callouts/005,
## moved here from PingMarkers by hud-results/007): static markers keyed by the sender's opaque `handle`, never
## by `from`, so two bodies wearing one name stay two markers; each keeps the identity it was sent under;
## newest ping_max_active per handle, newest MAX_MARKERS overall, expiring ping_lifetime_s after `tick`. A
## sender's disconnect sends nothing, so its markers expire normally.
func on_ping(tick: int, p: Dictionary) -> void:
	if not (p.get("handle") is int and p.get("from") is int and p.get("point") is Vector3):
		return
	var m := p.duplicate()
	m["expires"] = tick + _marker_life_ticks
	_markers = _markers.filter(func(o: Dictionary) -> bool: return o["expires"] > tick)
	_markers.append(m)
	var count := 0
	for i in range(_markers.size() - 1, -1, -1):
		if _markers[i]["handle"] == m["handle"]:
			count += 1
			if count > _marker_max_active:
				_markers.remove_at(i)
	while _markers.size() > MAX_MARKERS:
		_markers.remove_at(0)
	marker_changed.emit(m["handle"])


## Handler for an ability cooldown start: {ability: StringName, remaining_s: float} at batch tick `tick`.
func on_cooldown(tick: int, p: Dictionary) -> void:
	if not (p.get("ability") is StringName and p.get("remaining_s") is float):
		return
	_ready_tick[p["ability"]] = tick + roundi(p["remaining_s"] * _hz)
	cooldowns_changed.emit()


## Handler for EventBatch.MONSTER_HUD (MonsterHudFeed): the shapeshifter's own HUD state. Bad shape: ignored.
func on_monster_hud(_tick: int, p: Dictionary) -> void:
	var ready: Variant = p.get("ready")
	var faces: Variant = p.get("faces")
	if not (ready is Dictionary and faces is Array and p.get("transform_end") is int
			and p.get("stun_end") is int and p.get("immune_end") is int):
		return
	for k: Variant in ready:
		if not (k is StringName and ready[k] is int):
			return
	for f: Variant in faces:
		if not (f is Array and f.size() == 3 and f[0] is int and f[1] is float and f[2] is int):
			return
	_monster = p.duplicate(true)
	for k: StringName in ready:
		_ready_tick[k] = ready[k]
	cooldowns_changed.emit()
	monster_state_changed.emit()


## True once the shapeshifter's own HUD state arrived: only ever on the shapeshifter's client.
func is_shapeshifter() -> bool:
	return not _monster.is_empty()


## S1: one row per survivor {survivor, appearance, progress 0..1, available}, in the server's roster order.
func faces() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f: Array in _monster.get("faces", []):
		var progress := clampf(f[1] / _observe_s, 0.0, 1.0) if _observe_s > 0.0 else 1.0
		out.append({"survivor": f[0], "appearance": f[2], "progress": progress, "available": progress >= 1.0})
	return out


## S4: transformation progress 0..1, or -1.0 when none runs.
func transform_progress() -> float:
	var end: int = _monster.get("transform_end", -1)
	if end < 0 or _transform_ticks <= 0:
		return -1.0
	return clampf(1.0 - float(end - maxi(_display.server_tick(), 0)) / _transform_ticks, 0.0, 1.0)


## S5: seconds of stun left; 0.0 when not stunned.
func stun_remaining_s() -> float:
	return _until_s(_monster.get("stun_end", -1))


## S5: seconds of post-stun immunity left (not counting a running stun); 0.0 when none.
func immunity_remaining_s() -> float:
	if stun_remaining_s() > 0.0:
		return 0.0
	return _until_s(_monster.get("immune_end", -1))


## S6: live install alerts {centre, radius_m, expires} at the newest server tick, oldest first.
func install_alerts() -> Array[Dictionary]:
	var now := _display.server_tick()
	return _alerts.filter(func(a: Dictionary) -> bool: return a["expires"] > now)


func _until_s(end_tick: int) -> float:
	return float(maxi(0, end_tick - maxi(_display.server_tick(), 0))) / float(_hz)
