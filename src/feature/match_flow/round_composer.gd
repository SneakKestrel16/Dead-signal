class_name RoundComposer extends RefCounted
## The server composition root of one round (story match-flow/010, AD-201; ADR-0005 composition root,
## no gameplay autoloads). Builds every round module from the loaded map and knobs, wires every
## cross-module hook, routes client request packets to their module and starts the round through
## RoundServer.start_round. It adds no gameplay rule of its own: every Callable below forwards to a module.
## Decided folds (story ACs): HoldService.barred = Transforming or the shock lock; Objectives' is_healthy
## = Healthy and not hidden; Barricades' monster = the monster and not shock-locked.
## Interactable net ids: Doors registers first (a door's net id is its map index), so it is set up first.
## Inference: the composer lives in Match Flow because Match Flow owns the round lifecycle; it could move
## to src/core/session/ without changing any rule.
## Usage:
##   var c := RoundComposer.new(knobs, roster, MapData.load_map(), net, smp, world, step, mask, make_body, look)
##   c.on_over = _on_round_over          # (ended: bool), after the round is torn down
##   var errs := c.start(server, rng)    # bodies for every roster player, then RoundServer.start_round

## The session's HiddenSpawner (same fixed path on server and clients, placed by the host scene), set
## before start: the round's active objective points replicate through it (CandidateReplication).
## Null = no candidate replication (headless tests without a client scene).
var hidden: HiddenSpawner
## Called with `ended` (true after Results, false for Cancelled) once the round is torn down.
var on_over: Callable

var knobs: Knobs
var roster: Roster
var map: MapData
var net: NetAuthority
var smp: SceneMultiplayer
var server: RoundServer
var sm: ServerMovement
var view: ViewState
var queries: MapQueries
var rules: MapQueries.InteractRules
var lag: LagCompensation
var holds: HoldService
var doors: Doors
var downing: Downing
var bf: BorrowedFace
var sd: SurvivorDefense
var hs: HidingSpots
var bars: Barricades
var objectives: SurvivorObjectives
var ma: MonsterAbilities
var pings: PingsCallouts
var lifecycle: RoundLifecycle
var lighting: FacilityLighting
## The C1 monitor feeds (facility-map story 011).
var cams: Surveillance
## Every snapshot entry's body action (ADR-0004 §2 amendment 2026-10-16); sm holds only its Callable.
var body_actions: BodyActions
var _door_net: Dictionary[StringName, int] = {}
## Sends lighting records per viewer (facility-map story 010); kept here, sm holds only its Callable.
var lighting_rep: LightingReplication
## Delivers accepted pings per recipient (pings-and-callouts story 004); sm holds only its Callable.
var ping_delivery: PingDelivery
var callout_delivery: CalloutDelivery
## World progress bar replication (hud-results story 005); kept here, batch_extras holds only its Callable.
var world_progress: WorldProgress
## Runs HoldService in the HOLDS slot and owns the RoundEnded freeze.
var controller: ControllerAuthority
var footsteps: Footsteps
var offset: ViewOffset
## Server Scare Events module (scare-events story 001); owning systems call scares.fire().
var scares: ScareEvents
## Facility scare state and RoundScript anchor scares (scare-events story 006).
var scare_state: FacilityScareState
## The shapeshifter HUD state sender (hud-results/006); held here, batch_extras holds only its method.
var monster_hud: MonsterHudFeed
## The H4 roster names and the H9 hold end reasons (hud-results/011); held here like monster_hud.
var roster_feed: RosterFeed
var hold_reasons: HoldReasonFeed
## The survivors' own life state sender (hud-results/004); held here, batch_extras holds only its method.
var survivor_hud: SurvivorHudFeed
var round_script: RoundScript
## The ambush test and the Major-scare flinch request (scare-events story 005).
var ambush: AmbushTest
var flinch: ScareFlinch
var candidates: CandidateReplication
## Map interactable index (MapQueries.interactable_on_ray) -> HoldService net ids at that object, built
## after setup: only doors register at their map index, so the aim ray's index is translated here.
var _ids_at: Dictionary[int, Array] = {}
## The reverse: hold net id -> its map interactable index (the door whose own leaf must not block its sight).
var _index_of: Dictionary[int, int] = {}
## Kept here: Borrowed Face's attack source is a method of it, and a Callable does not keep it alive.
var lunge_view: LungeView
var survivors: Array[int] = []
var monster: int = -1
## player id -> body (kept while the player is out of ServerMovement, for its respawn).
var bodies: Dictionary[int, CharacterBody3D] = {}

var _world: Node3D
var _make_body: Callable
var _appearance: Callable


## `world`: the node bodies are parented to (its World3D's space answers the sight and aim rays).
## `step`, `static_mask`: ServerMovement's shared move step and static geometry mask. `make_body(parent,
## position) -> CharacterBody3D` builds one player body with a capsule CollisionShape3D child.
## `character_appearance(player) -> int`: the CharacterDef appearance id of a survivor's own character.
func _init(knobs_: Knobs, roster_: Roster, map_: MapData, net_: NetAuthority, smp_: SceneMultiplayer, world: Node3D,
		step: Callable, static_mask: int, make_body: Callable, character_appearance: Callable) -> void:
	knobs = knobs_
	roster = roster_
	map = map_
	net = net_
	smp = smp_
	_world = world
	_make_body = make_body
	_appearance = character_appearance
	sm = ServerMovement.new(knobs, net, smp, step, static_mask)
	offset = ViewOffset.new(_in_wind_up)
	view = ViewState.new(sm, offset)
	queries = MapQueries.new(map)
	lag = LagCompensation.new(knobs, sm.history, sm.frame_of)
	for id in roster.player_ids():
		if roster.entry(id).role == Roster.SHAPESHIFTER:
			monster = id
		else:
			survivors.append(id)


## Builds and wires every module, adds a frozen body per roster player and starts the round on `server`.
## `rng` places the shapeshifter's spawn and the objectives' install alerts. Returns RoundServer's errors.
func start(server_: RoundServer, rng: RandomNumberGenerator) -> PackedStringArray:
	server = server_
	var map_errs := map.errors() # TD-008: RoundServer (Foundation) cannot see MapData, so Match Flow refuses here
	if not map_errs.is_empty():
		push_error("RoundComposer: map invalid, round not started: %s" % "; ".join(map_errs))
		return map_errs
	var cand_errs := SurvivorObjectives.candidate_errors(map, knobs.objectives)
	if not cand_errs.is_empty():
		push_error("RoundComposer: map has no valid active point placement, round not started: %s" % "; ".join(cand_errs))
		return cand_errs
	var catalogue := ScareCatalogue.load_shipped()
	if catalogue == null:
		return PackedStringArray(["scare catalogue invalid, round not started"])
	scares = ScareEvents.new(catalogue)
	scare_state = FacilityScareState.new()
	round_script = RoundScript.new(scares, catalogue, scare_state, map, _live_players, _position,
			ScareRelevance.new(_eye, _clear_sight))
	ambush = AmbushTest.new(scares)
	holds = HoldService.new(knobs, _live_players, sm.frames_of, _centre, _hold_sight, _aim, _body_target,
			_is_monster)
	doors = Doors.new(holds, map, _capsules, _not_locked)
	rules = MapQueries.InteractRules.from_knobs(knobs, doors.is_closed)
	downing = Downing.new()
	bf = BorrowedFace.new()
	sd = SurvivorDefense.new()
	ma = MonsterAbilities.new()
	pings = PingsCallouts.new()
	holds.set_barred(_barred)
	holds.set_ids_at(_ids_of)
	downing.set_roster(survivors, monster)
	downing.set_positions(_position)
	downing.set_hidden(sd.is_hidden)
	downing.set_modifiers(_modifiers)
	downing.set_holds(holds)
	bf.set_roster(survivors, monster)
	bf.set_sight_sources(_eye, view.yaw_of, _body_points, _clear_sight, sd.locked)
	lunge_view = LungeView.new(ma)
	bf.set_attack_source(lunge_view.is_attacking)
	bf.set_appearance_source(_appearance)
	bf.on_form_event = sm.scope.form_changed
	bf.emit_sound = sm.emit_sound
	bf.position_of = _position
	sd.set_roster(survivors, monster)
	sd.set_trace(lag, _eye, sm.frame_of, _blocked)
	sd.set_form_source(bf.form)
	sd.set_locked(downing.action_locked)
	sd.set_modifiers(_modifiers)
	sd.set_holds(holds)
	ma.set_monster(monster)
	ma.set_position_source(_position)
	ma.set_hit_sources(lag, survivors, downing.eligible, view.server_dir, _clear_sight)
	ma.set_status_sources(bf.form, bf.transforming, sd.locked)
	ma.set_modifiers(_modifiers)
	ma.set_blackout_sources(queries.volume_at, _monster_sees)
	ma.set_sound_sink(sm.emit_sound) # MA-7: lunge cue, scrape and hit sounds
	ambush.set_sources(monster, survivors, _body_points, _clear_sight, queries.volume_at)
	bars = Barricades.new(holds, doors, map, _survivor_free, _monster_capsules, _monster_free)
	hs = HidingSpots.new(holds, map, _survivor_free, _is_monster, _set_hidden, _modifiers, _place)
	objectives = SurvivorObjectives.new(holds, map, _objective_healthy, sd.is_hidden, _position)
	objectives.survivor_ids = survivors.duplicate()
	objectives.rng = rng
	pings.set_sources(_eye, _position, _ping_clear, bf.appearance_of, sd.is_hidden, _ping_in_play)
	pings.set_map(map, rules.point_height_m)
	pings.set_body_resolver(_body_of_handle)
	objectives.emit_sound = sm.emit_sound
	hs.emit_sound = sm.emit_sound
	controller = ControllerAuthority.new(sm, holds)
	footsteps = Footsteps.new(_gait, bf.appearance_of, sm.emit_sound)
	footsteps.radius_scale_at = queries.footstep_radius_scale_at
	lighting = FacilityLighting.new(map, _objective_volume)
	lifecycle = RoundLifecycle.new(roster, map, rng)
	lifecycle.spawn = _spawn
	lifecycle.freeze = _freeze
	lifecycle.over = _over
	lifecycle.remove = _remove
	lifecycle.watch = _watch
	lifecycle.match_flow().set_exit(queries, _position)
	bf.set_status_source(lifecycle.match_flow().status_of)
	# MA-11: False Signal on MapQueries.floor_point (the S7 preview's snap); step_s is the walk footstep interval
	# Footsteps sends (footstep_spacing_m at walk_speed). No path cut yet: a straight path (MA-9 deviation).
	var fake_radius: Dictionary[StringName, float] = {SurvivorObjectives.INSTALL_SOUND: knobs.objectives.install_noise_radius_m}
	ma.set_false_signal_sources(sm.emit_sound, queries.floor_point, bf.observed, lifecycle.match_flow().status_of,
			_footstep_set_of, fake_radius, knobs.controller.footstep_spacing_m / knobs.controller.walk_speed)
	pings.set_sender_sources(monster, lifecycle.match_flow().status_of, downing.life_state, bf.form, bf.transforming,
			sd.locked)
	if hidden != null:
		hidden.setup(net)
		candidates = CandidateReplication.new(hidden, map)
	objectives.set_discovery(_eye, view.yaw_of, _clear_sight,
			candidates.discover if candidates != null else Callable(), lifecycle.match_flow().status_of)
	sm.monster = monster
	sm.hold_of = holds.hold_of
	sm.appearance_of = bf.appearance_of
	sm.transforming_of = bf.transforming_of
	sm.flashlight_of = sd.flashlight_on
	sm.drive_of = objectives.carries_drive
	sm.fuse_of = objectives.carries_fuse
	body_actions = BodyActions.new(knobs, holds.hold_of, holds.item, downing.life_state, _committing_monster,
			bf.appearance_of, sd.is_hidden, pings.callouts, _tick)
	sm.action_of = body_actions.action_of
	# Facility-map story 011: relevance reads the authored visibility sets (cut by closed doors) plus a viewed
	# camera's volumes. Before this the composed round used the near rule only (ServerMovement's documented
	# default until the root sets these).
	cams = Surveillance.new(map, knobs, _can_view, _centre, holds.hold_of, _door_closed)
	sm.scope.relevance.volume_at = queries.volume_at
	sm.scope.relevance.visible_volumes = _visible_volumes
	sm.scope.relevance.extra_volumes = cams.extra_volumes
	sm.batch_extras.assign([downing.ring_entries, sd.charge_entries, hs.hiding_entries, bars.barricade_entries,
			cams.camera_entries])
	lighting_rep = LightingReplication.new(lighting, map, _position, doors.is_closed, _tick)
	lighting_rep.extra_volumes = cams.extra_volumes
	sm.batch_extras.append(lighting_rep.entries)
	ping_delivery = PingDelivery.new(pings, monster, _ping_in_play, bf.appearance_of, _tick, _send_own, _position,
			knobs.ping.callout_range_m)
	sm.batch_extras.append(ping_delivery.entries)
	callout_delivery = CalloutDelivery.new(pings, knobs, monster, _ping_in_play, _position, sd.is_hidden, _tick,
			bf.appearance_of)
	sm.batch_extras.append(callout_delivery.entries)
	sm.batch_extras.append(scare_state.entries)
	world_progress = WorldProgress.new(knobs, survivors, roster.player_ids, holds.hold_of, holds.item,
			objectives.activation, _tick)
	sm.batch_extras.append(world_progress.entries)
	monster_hud = MonsterHudFeed.new(monster, survivors, _tick, ma.ready_tick, bf.cooldown_end_tick,
			bf.transform_end_tick, sd.lock_end_tick, sd.free_tick, bf.observation_s, bf.appearance_of)
	sm.batch_extras.append(monster_hud.entries)
	roster_feed = RosterFeed.new(roster, survivors, lifecycle.loaded_ids)
	sm.batch_extras.append(roster_feed.entries)
	hold_reasons = HoldReasonFeed.new(_tick)
	holds.on_end = hold_reasons.note
	sm.batch_extras.append(hold_reasons.entries)
	survivor_hud = SurvivorHudFeed.new(survivors, _tick, downing.life_state, downing.rescue_progress_s)
	sm.batch_extras.append(survivor_hud.entries)
	# BUG-0018: door state reaches the level's blockers here and every client's through door_entries.
	doors.blockers = DoorBlockers.new(_world, map)
	doors.exit_open = objectives.exit_open
	sm.batch_extras.append(doors.door_entries)
	sm.catch_up.assign([lifecycle.match_flow().catch_up, bf.catch_up, objectives.catch_up])
	var park := 0
	for id in roster.player_ids():
		park += 1
		var body: CharacterBody3D = _make_body.call(_world, Vector3(0.0, -1000.0 * park, 0.0))
		bodies[id] = body
		sm.add_player(id, body)
		sm.set_frozen(id, true)
		footsteps.add_player(id, body)
	# Insertion order is setup order: Doors first claims net ids 0..doors-1; tick order is by slot.
	var modules := {
		TickOrder.FACILITY_MAP: doors,
		TickOrder.MATCH_FLOW_BEGIN: lifecycle,
		TickOrder.SURVIVOR_DEFENSE: sd,
		TickOrder.SURVIVOR_DEFENSE + 1: bars,
		TickOrder.BORROWED_FACE: bf,
		TickOrder.MONSTER_ABILITIES: ma,
		TickOrder.FACILITY_LIGHTING: lighting,
		TickOrder.DOWNING: downing,
		TickOrder.HOLDS: controller,
		TickOrder.HIDING_SPOTS: hs,
		TickOrder.SURVEILLANCE: cams,
		TickOrder.FOOTSTEPS: footsteps,
		TickOrder.SURVIVOR_OBJECTIVES: objectives,
		TickOrder.PINGS_CALLOUTS: pings,
		TickOrder.SCARE_EVENTS - 2: MonsterScares.new(scares, catalogue, map, monster, _live_players, _position,
				ScareRelevance.new(_eye, _clear_sight)),
		TickOrder.SCARE_EVENTS - 1: ambush,
		TickOrder.SCARE_EVENTS: scares,
		TickOrder.SCARE_EVENTS + 1: scare_state,
		TickOrder.SCARE_EVENTS + 2: round_script,
		TickOrder.SCARE_EVENTS + 3: MonitorHallucination.new(scares, catalogue, cams, scare_state.state, _live_players),
		TickOrder.MATCH_FLOW_RESOLVE: lifecycle.resolve_step(),
	}
	var errs := server.start_round(modules, knobs)
	if not errs.is_empty():
		return errs
	offset.setup(server.tick_runner, server.bus, server.registry, knobs)
	flinch = ScareFlinch.new(view, offset, _body_points)
	flinch.setup(server.bus)
	server.registry.register_view(StateKeys.CAMERA_FLINCH_TOGGLE, &"NetworkAuthority", PlayerSettingsView.new(net))
	for id in roster.player_ids():
		offset.set_flinch_enabled(id, net.flinch_enabled_of(id))
	net.flinch_enabled_changed.connect(offset.set_flinch_enabled)
	server.bus.subscribe(&"SurvivorHit", _on_seized)
	BackupSwitch.register_all(holds, map, lighting, knobs, _survivor_free)
	holds.register(cams)
	_index_holds()
	if candidates != null:
		candidates.start_round(objectives.active(), survivors, monster,
				SurvivorObjectives.objective_ids(map, objectives.active()))
	sm.attach(server.tick_runner)
	smp.peer_packet.connect(_on_packet)
	return errs


## Tears the round down: detaches movement and packet routing, ends the RoundServer round, frees bodies.
## Safe to call twice and from inside a tick.
func stop() -> void:
	sm.detach()
	if net.flinch_enabled_changed.is_connected(offset.set_flinch_enabled):
		net.flinch_enabled_changed.disconnect(offset.set_flinch_enabled)
	if candidates != null:
		candidates.end_round()
		candidates = null
	if smp.peer_packet.is_connected(_on_packet):
		smp.peer_packet.disconnect(_on_packet)
	if server != null:
		server.end_round()
	for b in bodies.values():
		if is_instance_valid(b):
			b.queue_free()
	bodies.clear()


## Untrusted client bytes: each module decodes and size-caps its own request and ignores the rest
## (a non-request also reaches ServerMovement's input queue, which drops it).
func _on_packet(peer_id: int, bytes: PackedByteArray) -> void:
	var pid := net.player_id_of(peer_id)
	if pid == -1 or roster.entry(pid).is_empty():
		return
	if RoundLifecycle.is_map_loaded_packet(bytes):
		lifecycle.report_loaded(pid)
		return
	ma.request_ability(pid, bytes)
	bf.request_form_change(pid, bytes)
	sd.request_intent(pid, bytes)
	pings.request_ping(pid, bytes)
	pings.request_callout(pid, bytes)


# --- RoundLifecycle hooks ---------------------------------------------------------

func _spawn(id: int, at: Vector3) -> void:
	var body := bodies[id]
	body.global_position = at
	body.velocity = Vector3.ZERO
	if sm.watched_by(id) == -1 and not _in_sm(id):
		sm.add_player(id, body)
		footsteps.add_player(id, body)
	sm.set_frozen(id, false)


func _freeze(id: int) -> void:
	if _in_sm(id):
		controller.freeze(id)


func _remove(id: int) -> Vector3:
	var at := bodies[id].global_position
	if _in_sm(id):
		if downing.life_state(id) == Downing.LifeState.ELIMINATED:
			sm.cue(id, EventBatch.CUE_ELIMINATED) # the collapse, before the handle retires (ADR-0004 amendment)
		sm.remove_player(id)
	footsteps.remove_player(id)
	bodies[id].global_position = Vector3(0.0, -1000.0, 0.0)
	return at


func _over(ended: bool) -> void:
	stop()
	if on_over.is_valid():
		on_over.call(ended)


# --- position and sight sources ---------------------------------------------------

func _in_sm(id: int) -> bool:
	return _body_live(id)


func _body_live(id: int) -> bool:
	# ServerMovement has no has_player(); its last_valid lookup errors on a removed player.
	return sm._players.has(id)


## Players with a body in ServerMovement (an Out or disconnected player holds nothing).
func _live_players() -> Array[int]:
	var out: Array[int] = []
	for id in roster.player_ids():
		if _body_live(id):
			out.append(id)
	return out


## The running tick (the TickRunner exists only once start_round ran).
func _tick() -> int:
	return server.tick_runner.current_tick() if server.tick_runner != null else 0


func _position(id: int) -> Vector3:
	return bodies[id].global_position if bodies.has(id) else Vector3.ZERO


func _centre(id: int) -> Vector3:
	return _position(id) + Vector3.UP * knobs.controller.capsule_height_m * 0.5


## Inference: standing eye height; crouched eye_low_height_m is the controller's (not wired here).
func _eye(id: int) -> Vector3:
	return _position(id) + Vector3.UP * knobs.controller.eye_height_m


## [head, chest, pelvis]. Inference: chest at 3/4 and pelvis at 1/2 of the standing capsule; borrowed-face.md
## names the points but not their heights. Empty for a player with no body in the world.
func _body_points(id: int) -> PackedVector3Array:
	if not _body_live(id):
		return PackedVector3Array()
	var feet := _position(id)
	var h := knobs.controller.capsule_height_m
	return PackedVector3Array([_eye(id), feet + Vector3.UP * h * 0.75, feet + Vector3.UP * h * 0.5])


func _space() -> PhysicsDirectSpaceState3D:
	return _world.get_world_3d().direct_space_state


func _rid(id: int) -> Array[RID]:
	var out: Array[RID] = []
	if bodies.has(id):
		out.append(bodies[id].get_rid())
	return out


func _hold_sight(actor: int, i: Interactable) -> bool:
	# SD-14: a door's Barricade, Remove and Break sit at net ids other than the door's map index; without the
	# translation the closed leaf they act on blocks their sight.
	return queries.clear_line(_eye(actor), i.point, _index_of.get(i.net_id, i.net_id), rules, _space(), _rid(actor))


## The map interactable index the server's own view ray picks (AD-217: what a client's interact_target names).
func _aim(actor: int) -> int:
	return queries.interactable_on_ray(_eye(actor), view.server_dir(actor), _centre(actor), rules, _space(), _rid(actor))


## HoldService ids_at: the hold net ids at map interactable `idx` (a door also carries Barricade/Remove/Break;
## a hiding spot Hide and Search), in net id order.
func _ids_of(idx: int) -> Array:
	return _ids_at.get(idx, [])


## Builds _ids_at: each registered interactable belongs to the nearest map interactable's point.
## Inference: every hold sits at (or beside) its map object; ponytail: O(items x objects) once per round.
func _index_holds() -> void:
	_ids_at = {}
	_index_of = {}
	var targets := map.interactables()
	var pts: Array[Vector3] = []
	for t in targets:
		var door := t as MapPassage
		pts.append((door.position if door else (t as MapMarker).position) + Vector3.UP * rules.point_height_m)
	for item: Interactable in holds._items:
		var best := -1
		var best_d := INF
		for i in pts.size():
			var d := item.point.distance_squared_to(pts[i])
			if d < best_d:
				best_d = d
				best = i
		if best != -1:
			if not _ids_at.has(best):
				_ids_at[best] = []
			_ids_at[best].append(item.net_id)
			_index_of[item.net_id] = best


## The rescue hold on the body `handle` names for `actor` (Downing.rescue_net_id), or -1.
func _body_target(actor: int, handle: int) -> int:
	var b := _body_of_handle(actor, handle)
	return downing.rescue_net_id(b) if b != -1 else -1


## The player whose body `handle` names for `actor`, or -1 (PingsCallouts' warning-player target, story 011).
func _body_of_handle(actor: int, handle: int) -> int:
	for b in sm.scope.handles.bodies_of(actor):
		if sm.scope.handles.handle_for(actor, b) == handle:
			return b
	return -1


## PingsCallouts' sight ray: the sender's own capsule is skipped; `item` (a map interactable index, or -1)
## is the door whose own leaf must not block its ping.
func _ping_clear(sender: int, from: Vector3, to: Vector3, item: int) -> bool:
	return queries.clear_line(from, to, item, rules, _space(), _rid(sender))


## A warning ping may target the shapeshifter and survivors still Healthy or Downed (who may send is
## PingsCallouts.can_send, story 002).
func _ping_in_play(id: int) -> bool:
	if id == monster:
		return true
	var s := lifecycle.match_flow().status_of(id)
	return s == MatchFlow.Status.HEALTHY or s == MatchFlow.Status.DOWNED


func _clear_sight(from: Vector3, to: Vector3) -> bool:
	return queries.clear_sight(from, to, doors.is_closed, _space())


func _blocked(from: Vector3, to: Vector3) -> bool:
	return not queries.clear_line(from, to, -1, rules, _space())


func _capsules() -> Array[Vector4]:
	var out: Array[Vector4] = []
	for id in bodies:
		if _body_live(id):
			var p := _position(id)
			out.append(Vector4(p.x, p.y, p.z, knobs.controller.capsule_height_m))
	return out


func _monster_capsules() -> Array[Vector4]:
	var out: Array[Vector4] = []
	if _body_live(monster):
		var p := _position(monster)
		out.append(Vector4(p.x, p.y, p.z, knobs.controller.capsule_height_m))
	return out


func _modifiers(id: int) -> MovementModifiers:
	return sm.modifiers_of(id) if _body_live(id) else null


func _place(id: int, at: Vector3) -> void:
	if bodies.has(id):
		bodies[id].global_position = at


## FacilityLighting's objective_volume: the map volume of an active fuse box (FUSE_BOX_ID + index) or the
## terminal (TERMINAL_ID), &"" otherwise. ponytail: reads SurvivorObjectives' private point arrays (no public
## getter yet; SO-8 owns that file); add `box_point(i)` / `terminal_point()` there and switch to them.
func _objective_volume(objective: int) -> StringName:
	if objective == SurvivorObjectives.TERMINAL_ID:
		return queries.volume_at(objectives._terminal_point)
	var box := objective - SurvivorObjectives.FUSE_BOX_ID
	if box >= 0 and box < objectives._box_points.size():
		return queries.volume_at(objectives._box_points[box])
	return &""


## Blackout aim sight: the monster's eye sees `aim` (doors closed block).
## A survivor's walk footstep set as Footsteps names it (`c<appearance>.walk`), &"" for anyone else.
func _footstep_set_of(id: int) -> StringName:
	if not survivors.has(id):
		return &""
	return StringName("c%d.%s" % [bf.appearance_of(id), Footsteps.GAIT_NAMES[MovementStep.Gait.WALK]])


func _monster_sees(id: int, aim: Vector3) -> bool:
	return queries.clear_sight(_eye(id), aim, doors.is_closed, _space(), _rid(id))


## ViewOffset's wind-up gate (scare-events.md rule 14): the monster's Lunge is in wind-up or Active and `id` is
## within lunge_cue_radius_m of it.
func _in_wind_up(id: int) -> bool:
	return ma != null and ma.lunge_state() in [MonsterAbilities.Lunge.WIND_UP, MonsterAbilities.Lunge.ACTIVE] 			and _position(id).distance_to(_position(monster)) <= knobs.ability.lunge_cue_radius_m


## HidingSpots' set_hidden: SurvivorDefense's flag, and a ViewOffset re-baseline on entering (ADR-0015).
func _set_hidden(id: int, on: bool) -> void:
	sd.set_hidden(id, on)
	if on:
		offset.rebaseline(id)
	else:
		sm.cue(id, EventBatch.CUE_HIDE_EXIT)


## BodyActions' commit source: `id` is the monster in a takedown commit.
func _committing_monster(id: int) -> bool:
	return id == sm.monster and downing.committing()


## RoundLifecycle's watch: the spectator's stream starts empty, so the watched survivor's current flinch
## record is sent again (ADR-0015 §2: the record reaches the owner's spectators).
func _watch(spectator: int, survivor: int) -> void:
	sm.watch(spectator, survivor)
	if survivor != -1: ## -1: nobody left to watch (BUG-0007)
		offset.resend(survivor)


## A hit survivor is Seized: ViewOffset re-baselines it (ADR-0015).
func _on_seized(e: ServerEvent) -> void:
	offset.rebaseline((e as EvSurvivorHit).survivor)


## Footsteps' gait source: MovementStep.gait from the consumed frame and what the modules know.
## Inference: crouched is false (the body's low state is the controller step's, not wired here); the real
## movement step owning a MoveState per player would settle it.
func _gait(id: int) -> MovementStep.Gait:
	var st := MovementStep.MoveState.new()
	st.downed = downing.life_state(id) == Downing.LifeState.DOWNED
	st.holding = not holds.hold_of(id).is_empty()
	st.transforming = bf.transforming_of(id)
	return MovementStep.gait(sm.frame_of(id), st) if _body_live(id) else MovementStep.Gait.WALK


# --- decided folds (story ACs) ------------------------------------------------------

func _is_monster(id: int) -> bool:
	return id == monster


## Doors' rule (survivor-defense rule 24): anyone, unless shock-locked.
func _not_locked(id: int) -> bool:
	return not sd.locked(id)


## HoldService bar: Borrowed Face's Transforming bar combined with the shock lock.
func _barred(id: int) -> bool:
	return bf.transforming_of(id) or sd.locked(id)


## Objectives' is_healthy: Healthy and not hidden.
func _objective_healthy(id: int) -> bool:
	return downing.life_state(id) == Downing.LifeState.HEALTHY and not sd.is_hidden(id)


## Barricades' and HidingSpots' healthy: a Healthy survivor, free to act (Downing and the shock lock fold in).
func _survivor_free(id: int) -> bool:
	return id != monster and downing.life_state(id) == Downing.LifeState.HEALTHY \
			and not downing.action_locked(id) and not sd.locked(id)


## Surveillance's viewer rule: any player, the monster included (scare-events.md rule 2a), unless shock-locked,
## Seized or Downed (ADR-0009 §8 "shocked or downed").
func _can_view(id: int) -> bool:
	return not sd.locked(id) and not downing.action_locked(id)


## Door passage id -> closed or barricaded, for visibility sets (doors' net ids are their MapData.interactables
## index), built once.
func _door_closed(door: StringName) -> bool:
	if _door_net.is_empty():
		var targets := map.interactables()
		for i in targets.size():
			if targets[i] is MapPassage:
				_door_net[(targets[i] as MapPassage).id] = i
	return _door_net.has(door) and doors.is_closed(_door_net[door])


func _visible_volumes(volume: StringName) -> PackedStringArray:
	return queries.visible_set(volume, _door_closed)


## Barricades' monster: the monster in any form, unless shock-locked.
func _monster_free(id: int) -> bool:
	return id == monster and not sd.locked(id)


## PingDelivery's send_own: reliable bytes on the event channel to `player`'s own peer only.
func _send_own(player: int, bytes: PackedByteArray) -> void:
	var peer := net.peer_id_of(player)
	if peer != -1:
		smp.send_bytes(bytes, peer, MultiplayerPeer.TRANSFER_MODE_RELIABLE, NetChannels.EVENT)
