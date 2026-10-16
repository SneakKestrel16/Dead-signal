class_name RoundClient extends Node
## One client of a composed round (story match-flow/011, AD-201; ADR-0002 prediction and interpolation,
## ADR-0004 handles and appearance, ADR-0010 minimal rendering). This node is the client's SceneMultiplayer
## root: it joins with NetAuthority, adds the session HiddenSpawner at the server's fixed path ("Hidden"),
## reports its map loaded on its first snapshot, predicts its own body (OwnerPredictor) and draws every
## remote body from snapshots, interpolated by handle interp_delay_ms behind. A handle missing from the newest snapshot is not drawn
## (hidden survivors and bodies out of scope are not sent). It emits no event and decides nothing: the hold
## bar and flashlight are the existing predictors (PredictedHoldBar, FlashlightPredictor).
## The movement step and body come from the caller: the client must step with the server's own step.
## Usage:
##   var c := RoundClient.new(knobs, step, make_body, map, true)   # true: camera, input and HUD
##   parent.add_child(c); c.join("127.0.0.1", port, "Name")

## Appearance colour of the true form (greybox; ADR-0010 minimal: a colour per form is enough). Characters
## take CharacterDef.colour. Placeholder values: no art direction source yet.
const TRUE_FORM_COLOUR := Color(0.6, 0.05, 0.05)
const UNKNOWN_COLOUR := Color(0.5, 0.5, 0.5)
const BODY_RADIUS_M := 0.3 ## greybox mesh only; collision is the step's capsule
## Flashlight cone half-angle in degrees. NOT SOURCEABLE: survivor-defense.md gives the range only
## (stun_range_m); 25 degrees is a greybox guess, settled by the HUD/VFX art pass.
const CONE_ANGLE_DEG := 25.0
const VERSION_BUILD := "0.1.0"
## Where the own body waits for its first snapshot: far below the map, as RoundComposer parks bodies.
const PARKED := Vector3(0.0, -1000.0, 0.0)

var knobs: Knobs
var net: NetAuthority
var hidden: HiddenSpawner
var predictor: OwnerPredictor
var puppets: PuppetMap
var light := FlashlightPredictor.new()
## Own cartridges and shocks from the server (survivor-defense story 015 reads charges for use_item).
var defense: DefenseDisplay
var bar: PredictedHoldBar
var input: LocalInput
var body: CharacterBody3D
var camera: Camera3D
## Camera chain (story controller-interaction/013, Client scene wiring): body -> head -> CameraFx -> Camera3D.
var head: Node3D
var camera_fx: CameraFx
## Projected events from the server (ViewOffsetChanged, ScareTriggered); null until joined.
var router: ClientEventRouter
## Ping requests and delivered pings (pings-and-callouts story 004).
var pings: PingReceiver
var callouts: CalloutReceiver
## The facility scare state the server sent (scare-events story 006); presentation is story 009.
var facility_scare: FacilityScareDisplay
var scares: ScarePresenter
## Scare audio (scare-events story 008); null until joined, and on a non-rendering client.
var scare_audio: ScareAudio
## Shock and stun stagger and vocal cue on remote bodies (borrowed-face story 009); null when not rendering.
var disguise: DisguisePresenter
## Per-form shock presentation (arc, spark, own jitter, jolt, edge) and the placeholder audio sink
## (survivor-defense story 011); null when not rendering.
var shock: ShockPresenter
var audio: PlaceholderAudio
## Zone ambience bed crossfade and its debug overlay (story facility-map/012); null when not rendering.
var ambience: ZoneAmbience
## The C1 monitor feed (story facility-map/011); null when not rendering.
var feed: SurveillanceFeed
## Map lighting from the server's records (story facility-map/010, ADR-0009 §6); null when not rendering.
var lights: LightingPresenter
## Lunge cue, coil, stumble and hit-stop (story monster-abilities/007); null when not rendering.
var lunge_fx: LungePresenter
## Transformation warp and distortion audio (borrowed-face story 010); null when not rendering.
var warp: TransformPresenter
## Ping markers, callout wheel and feed (pings-and-callouts story 008); null when not rendering.
var ping_hud: PingCalloutHud
## The HUD layer holding the hold bar (null when not rendering).
var hud: CanvasLayer
## The HUD's only data source (hud-results story 001) and the client's display of phase and clock; null when
## not rendering.
var hud_model: HudModel
## Edge cues, taser count and world progress bars (hud-results story 005); null when not rendering.
var edge_cues: EdgeCues
var match_display: MatchDisplay
## Prompt, hold ring and refusal label in Z4/Z5 (hud-results story 003); null when not rendering.
var interaction: InteractionHud
## The camera flinch accessibility toggle sent on join (ADR-0015 §4); set_flinch() changes it later.
var flinch_enabled := true
## Accessibility reduced motion (hud.md Accessibility), pushed to every HUD presenter by set_reduced_motion().
## INFERENCE: no client settings store exists yet, so the initial value is the `--reduced-motion` user flag;
## a settings screen/store would replace that one line.
var reduced_motion := OS.get_cmdline_user_args().has("--reduced-motion")
## The player's settings (LobbyScreen's); apply_settings() sets it and pushes every value. null = defaults and
## the `--reduced-motion` flag above (scripted launches and tests).
var settings: PlayerSettings
## FM-12 zone ambience text overlay: a diagnostic, shown only with the `--ambience-debug` user flag (BUG-0011).
var ambience_debug := OS.get_cmdline_user_args().has("--ambience-debug")
## Camera on the watched survivor while spectating (BUG-0005); null when not rendering.
var spectator_cam: SpectatorCamera
## When set, used instead of LocalInput each tick (scripted runs and tests); yaw/pitch come from it.
var scripted: InputFrame
## Full join version string; "" = knobs.join_version(VERSION_BUILD). A shipped session sets the lobby's.
var version := ""
## The level the caller built for this client (MapGreybox.build's root, or any ancestor of it), set before
## join; null = no doors applied (BUG-0018). Its door blockers follow the server's door state, so prediction
## collides with the doors the server's movement does.
var level: Node
## This client's DoorBlockers (EventBatch.DOORS, BARRICADE); null without a level.
var doors: DoorBlockers
## Objective props over `level`: active points only, carried and dropped items, state glows; null when not
## rendering or without a level.
var objective_props: ObjectiveProps
## handle -> remote body Node3D (child "Mesh" MeshInstance3D, child "Cone" SpotLight3D).
var remotes: Dictionary[int, Node3D] = {}

var _render: bool
## Remote bodies' character art (rendering clients only; headless clients keep the bare capsule).
var body_visuals: BodyVisual
## First-person arms and held items under the camera (ASSET-011..014); null when not rendering.
var viewmodel: Viewmodel
var _step: Callable
var _make_body: Callable
var _map: MapData
var _queries: MapQueries
var _rules: MapQueries.InteractRules
var _targets: Array[Resource] = []
var _colours: Dictionary[int, Color] = {}
var _own_cone: SpotLight3D
## handle -> Array of [local_ms, pos, yaw]; newest last.
var _buf: Dictionary[int, Array] = {}
## Retired handle -> local ms of its retire: the puppet stays (hidden) for interp_delay_ms, so an elimination
## cue in the batch after the retire can still find it (ADR-0004 §2 amendment 2026-10-16).
var _retired: Dictionary[int, float] = {}
## Handles in the newest applied snapshot.
var _present: Dictionary[int, bool] = {}
var _last_tick := -1
var _now_ms := 0.0
var _loaded_sent := false
var _owns_net := false
var _lost := false


func _init(knobs_: Knobs, step: Callable, make_body: Callable, map: MapData, render: bool) -> void:
	knobs = knobs_
	_step = step
	_make_body = make_body
	_map = map
	_render = render
	_queries = MapQueries.new(map)
	_rules = MapQueries.InteractRules.from_knobs(knobs)
	_targets = map.interactables()
	for c in CharacterDef.load_all():
		_colours[c.appearance_id] = c.colour


## Joins the host. Call once this node is in the tree. `token` rejoins as that player; `root` is the
## multiplayer root (default this node), so the session HiddenSpawner's path matches the server's.
func join(host: String, port: int, display_name: String, token: String = "", root: Node = null) -> Error:
	get_tree().set_multiplayer(SceneMultiplayer.new(), (root if root != null else self).get_path())
	net = NetAuthority.new()
	net.setup(knobs, version if version != "" else knobs.join_version(VERSION_BUILD), _NoLobby.new())
	add_child(net)
	_owns_net = true
	prepare()
	net.join_rejected.connect(_on_rejected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.server_disconnected.connect(_on_lost)
	return net.join(host, port, display_name, token)


## Adds the session HiddenSpawner (once). A client that adopts a session calls it before the round is
## composed, so the server's hidden entities find their path (match-flow story 013).
func prepare() -> void:
	if hidden == null:
		hidden = HiddenSpawner.new()
		add_child(hidden)


## Plays the round over an already joined session (the lobby's; ADR-0001: no second ENet session). This
## node's multiplayer must be that session's; close() leaves the session open.
func adopt(session: NetAuthority) -> void:
	net = session
	prepare()
	_on_connected()


## Stops listening and leaves the session. Safe to call twice.
func close() -> void:
	_lost = true # BUG-0015: no predict (and send) between close and the free; the session may already be gone
	if predictor != null:
		predictor.close()
	if puppets != null:
		puppets.close()
	if match_display != null:
		match_display.close()
	if router != null:
		router.close()
	if net != null and _owns_net:
		net.close()


func _on_rejected(reason: StringName) -> void:
	push_warning("RoundClient %s: join rejected (%s)" % [name, reason])


## The host left: stop predicting (and sending). Closing here would run inside the multiplayer poll.
func _on_lost() -> void:
	_lost = true


func _on_connected() -> void:
	var smp := multiplayer as SceneMultiplayer
	body = _make_body.call(self, PARKED) # the first snapshot restores the server's position
	var visual := Node3D.new()
	body.add_child(visual)
	predictor = OwnerPredictor.new(knobs, body, visual, _step, smp)
	predictor.own_id = net.local_player_id # BUG-0005: no prediction or input while spectating
	puppets = PuppetMap.new(smp)
	smp.peer_packet.connect(_on_packet) # after PuppetMap: handle introductions land first
	router = ClientEventRouter.new(smp)
	pings = PingReceiver.new(router, smp)
	callouts = CalloutReceiver.new(router, smp)
	facility_scare = FacilityScareDisplay.new(router)
	defense = DefenseDisplay.new(router)
	if level != null: # BUG-0018
		doors = DoorBlockers.new(level, _map)
		router.subscribe(EventBatch.DOORS, doors.on_doors)
		router.subscribe(EventBatch.BARRICADE, doors.on_barricade)
	if _render:
		head = Node3D.new()
		head.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		head.position.y = knobs.controller.eye_height_m
		visual.add_child(head)
		camera_fx = CameraFx.new()
		head.add_child(camera_fx)
		camera = Camera3D.new()
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		camera_fx.add_child(camera)
		camera.make_current()
		_own_cone = _cone()
		camera.add_child(_own_cone)
		input = LocalInput.new()
		add_child(input)
		router.subscribe(&"ViewOffsetChanged", input.on_view_offset)
		# No accessibility settings store yet: flash_scale, camera_fx.enabled and the scare audio volume
		# scales keep their defaults (full, on).
		var scare_catalogue := ScareCatalogue.load_shipped()
		scares = ScarePresenter.new(FlashLimiter.new(knobs.facility.max_flashes_per_s), camera_fx,
				scare_catalogue.presenter_catalog())
		add_child(scares)
		router.subscribe(&"ScareTriggered", scares.on_scare)
		scare_audio = ScareAudio.new(scare_catalogue, knobs)
		add_child(scare_audio)
		for t: StringName in [&"PlayerShocked", &"MonsterStunned"]:
			router.subscribe(t, scare_audio.on_stun)
		router.subscribe(&"ScareTriggered", scare_audio.on_scare)
		router.subscribe(EventBatch.SOUND, scare_audio.on_sound)
		body_visuals = BodyVisual.new()
		router.subscribe(EventBatch.BODY_CUE, _on_body_cue) # ADR-0004 §2 amendment 2026-10-16
		viewmodel = Viewmodel.new(body_visuals)
		viewmodel.reduced_motion = reduced_motion
		camera.add_child(viewmodel)
		disguise = DisguisePresenter.new(remotes, puppets.state_of, knobs)
		add_child(disguise)
		# Survivor-defense story 011: ShockPresenter routes the shock events per form (it calls the
		# stagger), and PlaceholderAudio plays every cue and server sound until audio assets exist.
		# ponytail: its own FlashLimiter; share the scares' one when a settings store wires flash_scale.
		shock = ShockPresenter.new(disguise, remotes, puppets.state_of, camera_fx,
				FlashLimiter.new(knobs.facility.max_flashes_per_s), knobs)
		add_child(shock)
		router.subscribe(&"PlayerShocked", shock.on_player_shocked)
		router.subscribe(&"MonsterStunned", shock.on_monster_stunned)
		audio = PlaceholderAudio.new(SoundBank.load_shipped(), _map)
		add_child(audio)
		router.subscribe(EventBatch.SOUND, audio.on_sound)
		disguise.cue.connect(audio.play_at)
		shock.cue.connect(audio.play_at)
		var world_sfx := WorldSfx.new(_map, audio.play_at, camera.get_global_position) # audio pass
		router.subscribe(EventBatch.DOORS, world_sfx.on_doors)
		router.subscribe(EventBatch.BARRICADE, world_sfx.on_barricade)
		router.subscribe(&"ObjectiveProgressChanged", world_sfx.on_objective)
		router.subscribe(&"RoundPhaseChanged", world_sfx.on_phase)
		lights = LightingPresenter.new(_map, LightingPresets.load_shipped())
		add_child(lights)
		camera.environment = lights.presets.environment()
		router.subscribe(EventBatch.LIGHTING, lights.on_lighting)
		lunge_fx = LungePresenter.new(knobs, remotes)
		add_child(lunge_fx)
		router.subscribe(EventBatch.SOUND, lunge_fx.on_sound)
		warp = TransformPresenter.new(remotes, puppets.state_of, knobs)
		add_child(warp)
		router.subscribe(EventBatch.SOUND, warp.on_sound)
		if level != null:
			lights.spin_fixtures(level) # C4 and corridor beacon meshes turn with their lights
			objective_props = ObjectiveProps.new(level, _map)
			objective_props.reduced_motion = reduced_motion
			objective_props.reduced_flash = lights.reduced_flash
			add_child(objective_props)
			objective_props.watch(hidden)
			router.subscribe(&"ObjectiveProgressChanged", objective_props.on_objective)
			router.subscribe(EventBatch.PROGRESS, objective_props.on_progress)
		feed = SurveillanceFeed.new(_map, knobs)
		add_child(feed)
		router.subscribe(EventBatch.CAMERA, feed.on_camera)
		add_child(ScareVisuals.new(scares, facility_scare, lights, feed, router)) # scare-events story 009
		hud = CanvasLayer.new()
		hud.layer = UiLayers.HUD
		add_child(hud)
		match_display = MatchDisplay.new(knobs, smp)
		hud_model = HudModel.new(match_display, knobs, router)
		ShapeshifterHud.mount(hud, hud_model, camera) # hud-results/006: instanced on shapeshifter state only
		hud.add_child(AlwaysOnHud.new(hud_model, net.local_player_id)) # H1-H6 (hud-results story 002)
		ambience = ZoneAmbience.new(_map, ZoneAmbience.bank_beds(SoundBank.load_shipped()), body)
		add_child(ambience)
		if ambience_debug:
			hud.add_child(ambience.make_overlay())
		ping_hud = PingCalloutHud.new(knobs, pings, hud_model, callouts, InputContextStack.new(),
				audio, camera, remotes, puppets.state_of, estimated_tick,
				func() -> int: return local_target(head.rotation.y, head.rotation.x),
				func() -> int: return predictor.last_own.get("appearance", -1), _map)
		hud.add_child(ping_hud)
		input.contexts = ping_hud.contexts
		ShapeshifterAim.mount(hud, hud_model, camera, ping_hud.contexts, smp, _map, knobs) # MA-11: abilities, S7
		ping_hud.contexts.viewport = get_viewport()
		edge_cues = EdgeCues.new(knobs, camera.get_global_transform, func() -> bool: return flinch_enabled)
		hud.add_child(edge_cues)
		router.subscribe(EventBatch.SOUND, edge_cues.on_sound)
		router.subscribe(&"ScareTriggered", edge_cues.on_scare)
		hud.add_child(TaserCount.new(hud_model))
		spectator_cam = SpectatorCamera.new(net.local_player_id)
		var bars := WorldProgressBars.new(knobs, estimated_tick)
		add_child(bars)
		router.subscribe(EventBatch.PROGRESS, bars.on_progress)
		router.subscribe(&"RoundPhaseChanged", _on_phase_changed)
		router.subscribe(&"RoundEnded", _on_round_ended)
		bar = PredictedHoldBar.new()
		add_child(bar)
		bar.self_modulate = Color.TRANSPARENT # the predictor only: InteractionHud draws the ring
		interaction = InteractionHud.new(InputGlyphs.new(), ping_hud.contexts, bar, prompt_of)
		hud.add_child(interaction)
		router.subscribe(EventBatch.HOLD_END, interaction.on_hold_end) # H9 server reason (hud-results/011)
		hud.add_child(OwnStateHud.new(hud_model, net.local_player_id, interaction)) # H15, H16, states (hud-results/004)
		hud.add_child(FormPicker.for_client(hud_model, ping_hud.contexts, knobs, smp, interaction.refuse,
				match_display.server_tick)) # borrowed-face/011
		push_reduced_motion(hud, reduced_motion) # BUG-0008: one place for every presenter
		if settings != null:
			apply_settings(settings)
	else:
		bar = PredictedHoldBar.new() # not drawn; keeps the same per-tick path as the rendering client
		add_child(bar)
	bar.setup(knobs)
	# Join accepted (connected_to_server fires after auth): send the flinch toggle (ADR-0015 §4). Default on
	# until a settings store exists.
	smp.send_bytes(NetAuthority.flinch_packet(flinch_enabled), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE)


## True once this client owns a predicted body.
func is_ready() -> bool:
	return predictor != null


## True once the own body stands in the map (RoundLifecycle spawned it; before that it is parked below).
func is_spawned() -> bool:
	return predictor != null and predictor.states_received > 0 and body.global_position.y > PARKED.y / 2.0


## Whether this client plays the shapeshifter in its true form (own entry shows the true-form appearance).
func is_monster() -> bool:
	return predictor != null and predictor.last_own.get("appearance", -1) == CharacterDef.TRUE_FORM_APPEARANCE_ID


## Sets reduced motion on every HUD presenter under `layer` that has the property (AlwaysOnHud, EdgeCues,
## OwnStateHud, InteractionHud, PingCalloutHud).
static func push_reduced_motion(layer: Node, on: bool) -> void:
	for n in layer.get_children():
		if &"reduced_motion" in n:
			n.set(&"reduced_motion", on)


## Changes reduced motion for the whole HUD (BUG-0008).
func set_reduced_motion(on: bool) -> void:
	reduced_motion = on
	if viewmodel != null:
		viewmodel.reduced_motion = on
	if objective_props != null:
		objective_props.reduced_motion = on
	if warp != null:
		warp.reduced_motion = on
	if hud != null:
		push_reduced_motion(hud, on)


## Changes the flinch toggle and tells the server (ADR-0015 §4).
func set_flinch(on: bool) -> void:
	flinch_enabled = on
	if predictor != null:
		(multiplayer as SceneMultiplayer).send_bytes(NetAuthority.flinch_packet(on), 1,
				MultiplayerPeer.TRANSFER_MODE_RELIABLE)


## Applies every PlayerSettings value to this client's presenters and input, live (scare-events.md rule 29);
## the flinch toggle reaches the server only when it changes (ADR-0015 §4).
func apply_settings(s: PlayerSettings) -> void:
	settings = s
	set_reduced_motion(s.reduced_motion)
	if s.camera_flinch != flinch_enabled:
		set_flinch(s.camera_flinch)
	if input != null:
		input.sensitivity = s.mouse_sensitivity
		input.stick_rate = s.stick_rate
	var flash := s.effective_flash_scale()
	for p: Object in [scares, shock]:
		if p != null:
			p.set(&"flash_scale", flash)
	if lights != null:
		lights.reduced_flash = flash <= 0.0 # ScareVisuals derives the same from scares.flash_scale
	if objective_props != null:
		objective_props.reduced_flash = flash <= 0.0
	if scare_audio != null:
		scare_audio.stinger_scale = s.stinger_volume
		scare_audio.scare_scale = s.scare_volume
	if hud != null:
		for n in hud.get_children():
			if &"hud_scale" in n:
				n.set(&"hud_scale", s.hud_scale)


## The estimated server tick of this moment (fractional), or 0 before the estimator has one.
func estimated_tick(fraction: float = 0.0) -> float:
	if predictor == null or not predictor.estimator.has_estimate():
		return 0.0
	return predictor.estimator.estimated_server_tick(predictor.local_tick() + fraction)


## Flips the flashlight at once and sends the intent (survivor-defense story 009).
func toggle_flashlight() -> void:
	(multiplayer as SceneMultiplayer).send_bytes(light.toggle(), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE)


## Sends one taser fire intent when may_fire allows it (survivor-defense story 015); the server decides
## cartridges, reuse delay and hits. Returns whether it sent.
func fire_taser() -> bool:
	if not may_fire(ping_hud.contexts if ping_hud != null else null, defense.charges()):
		return false
	(multiplayer as SceneMultiplayer).send_bytes(SurvivorDefense.fire_packet(), 1,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	return true


## use_item gate: a cartridge in the last server count (-1, no taser, for the shapeshifter; 0 is the GDD's
## "input ignored" edge case) and an actions-allowing context on top (ADR-0014 §1: not the wheel, an overlay
## or a menu). Null `contexts` (a client without UI) is ungated.
static func may_fire(contexts: InputContextStack, charges: int) -> bool:
	return charges > 0 and (contexts == null or contexts.allows_actions())


func _frame() -> InputFrame:
	if scripted != null:
		var f := InputFrame.new()
		f.move = scripted.move
		f.yaw = scripted.yaw
		f.pitch = scripted.pitch
		f.interact = scripted.interact
		f.interact_alt = scripted.interact_alt
		return f
	return input.sample(int(estimated_tick())) if input != null else InputFrame.new()


func _physics_process(_delta: float) -> void:
	if predictor == null or _lost:
		return
	if not _loaded_sent and predictor.states_received > 0:
		# The first snapshot means the round is composed (ServerMovement attaches in RoundComposer.start), so
		# RoundLifecycle is there to take the report; sent on join it would arrive before the round exists.
		_loaded_sent = true
		(multiplayer as SceneMultiplayer).send_bytes(RoundLifecycle.map_loaded_packet(), 1,
				MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	if input != null and scripted == null and Input.is_action_just_pressed(&"flashlight"):
		toggle_flashlight()
	if input != null and scripted == null and Input.is_action_just_pressed(&"use_item"):
		fire_taser()
	if predictor.spectating():
		predictor.predict(InputFrame.new()) # applies snapshots and keeps the tick estimate; sends nothing
		light.take_server(predictor.last_own.get("flashlight", false)) # the watched survivor's light
		return
	var f := _frame()
	# AD-217: interact_target is the map index the server's ray must also pick. Stamped before predict(),
	# which sends the frame, so from the pre-move position; the server's Holds step aims after the move.
	# Inference: one tick of movement rarely changes the picked object; a mismatch at an object's edge only
	# costs that press (rejected, bar hides at the ack).
	var t := local_target(f.yaw, f.pitch)
	f.interact_target = t
	predictor.predict(f)
	bar.advance(f, t >= 0, duration_of(t))
	bar.on_snapshot(predictor.last_own)
	if not predictor.last_own.is_empty():
		light.take_server(predictor.last_own.get("flashlight", false))


func _process(delta: float) -> void:
	_now_ms += delta * 1000.0
	if match_display != null:
		match_display.advance(delta)
	if predictor != null:
		predictor.advance_visual(delta)
	if head != null:
		if scripted != null:
			head.rotation = Vector3(scripted.pitch, scripted.yaw, 0.0)
		else:
			var est := estimated_tick(Engine.get_physics_interpolation_fraction())
			head.rotation = Vector3(input.view_pitch(est), input.view_yaw(est), 0.0)
	if spectator_cam != null:
		spectator_cam.place(head, knobs.controller.eye_height_m, _now_ms - knobs.net.interp_delay_ms,
				knobs.net.max_extrapolation_ms)
	if _own_cone != null:
		_own_cone.visible = light.is_on()
	if viewmodel != null: # the own look; none while spectating (the watched body is drawn remotely)
		viewmodel.update(-1 if predictor.spectating() else predictor.last_own.get("appearance", -1),
				defense.charges(), bar.visible, delta)
	_draw_remotes()


## The map interactable index the owner's view ray picks (MapQueries, the server's own query), or -1.
func local_target(yaw: float, pitch: float) -> int:
	if body == null or not body.is_inside_tree():
		return -1
	var feet := body.global_position
	var dir := Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3.FORWARD
	return _queries.interactable_on_ray(feet + Vector3.UP * knobs.controller.eye_height_m, dir,
			feet + Vector3.UP * knobs.controller.capsule_height_m * 0.5, _rules,
			body.get_world_3d().direct_space_state, [body.get_rid()])


## The prompt for the interactable the view ray picks (hud-results story 003): {text, hold}, or {} for none.
func prompt_of() -> Dictionary:
	var t := local_target(head.rotation.y, head.rotation.x)
	if t < 0:
		return {}
	return {"text": InteractionHud.verb_object(_targets[t], is_monster()), "hold": duration_of(t) > 0.0}


## Hold duration of map interactable `index` for this player (0 = instant or none: no bar). Sources: doors
## are instant (Doors), hiding = hide_transition_s / search_duration_s (HidingSpots), switch =
## backup_switch_hold_s (BackupSwitch). Inference for objective types (SurvivorObjectives picks the knob per
## point role; the marker type alone cannot tell a dock from a pickup): drive = drive_extract_s, fuse =
## pickup_s, fuse_box = fuse_install_s, terminal = activation_start_s. The monitor is instant (Surveillance).
func duration_of(index: int) -> float:
	if index < 0 or index >= _targets.size() or _targets[index] is MapPassage:
		return 0.0
	match (_targets[index] as MapMarker).type:
		&"hiding":
			return knobs.defense.search_duration_s if is_monster() else knobs.defense.hide_transition_s
		&"switch":
			return knobs.ability.backup_switch_hold_s
		&"monitor":
			return 0.0
		&"drive":
			return knobs.objectives.drive_extract_s
		&"fuse":
			return knobs.objectives.pickup_s
		&"fuse_box":
			return knobs.objectives.fuse_install_s
		_:
			return knobs.objectives.activation_start_s


## Greybox colour of `appearance` (snapshot appearance byte).
func colour_of(appearance: int) -> Color:
	if appearance == CharacterDef.TRUE_FORM_APPEARANCE_ID:
		return TRUE_FORM_COLOUR
	return _colours.get(appearance, UNKNOWN_COLOUR)


## Snapshot bytes from the server: records each remote entry for interpolation. Public so tests can feed it.
func receive(bytes: PackedByteArray) -> void:
	if EventBatch.is_message(bytes) or HandleTable.is_message(bytes):
		return
	var snap := SnapshotCodec.decode(bytes)
	if snap.is_empty() or snap.tick <= _last_tick:
		return
	_last_tick = snap.tick
	_present.clear()
	for b: Dictionary in snap.bodies:
		if b.get("own", false) and hud_model != null:
			hud_model.on_own_body(b)
			spectator_cam.on_own(b, _now_ms)
		if b.get("own", false) or not puppets.has(b.id):
			continue
		_present[b.id] = true
		if not _buf.has(b.id):
			_buf[b.id] = []
		_buf[b.id].append([_now_ms, b.pos, b.yaw])
		if _buf[b.id].size() > 8:
			_buf[b.id].remove_at(0)


## ADR-0014 §1: the input stack resets to GAMEPLAY at round start and to MENU at round end.
func _on_phase_changed(_tick: int, p: Dictionary) -> void:
	if p.get("phase") == MatchFlow.Phase.INFILTRATION:
		ping_hud.contexts.reset(InputContextStack.Ctx.GAMEPLAY)


func _on_round_ended(_tick: int, _p: Dictionary) -> void:
	ping_hud.contexts.reset(InputContextStack.Ctx.MENU)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and ping_hud != null:
		ping_hud.contexts.reapply_mouse_mode() # alt-tab drops the capture (ADR-0014 §3)


func _on_packet(peer_id: int, bytes: PackedByteArray) -> void:
	if peer_id == PuppetMap.SERVER_PEER:
		receive(bytes)


## Shows every introduced handle present in the newest snapshot at its interpolated pose; hides the rest.
func _draw_remotes() -> void:
	if puppets == null:
		return
	for h: int in remotes.keys():
		if not puppets.has(h):
			remotes[h].visible = false
			if _now_ms - _retired.get_or_add(h, _now_ms) >= knobs.net.interp_delay_ms:
				remotes[h].queue_free()
				remotes.erase(h)
				_buf.erase(h)
				_retired.erase(h)
	var at := _now_ms - knobs.net.interp_delay_ms
	for h: int in puppets.handles():
		var st := puppets.state_of(h)
		if st.is_empty() or not _buf.has(h):
			continue
		if not remotes.has(h):
			remotes[h] = _remote()
		var n := remotes[h]
		n.visible = _present.has(h)
		var pose := sample(_buf[h], at, knobs.net.max_extrapolation_ms)
		n.position = pose[0]
		n.rotation.y = pose[1]
		var mat := (n.get_node(^"Mesh") as MeshInstance3D).material_override as StandardMaterial3D
		mat.albedo_color = colour_of(st.get("appearance", SnapshotCodec.NO_APPEARANCE))
		(n.get_node(^"Cone") as SpotLight3D).visible = st.get("flashlight", false)
		if body_visuals != null: # character art over the greybox capsule (ASSET-001..010)
			body_visuals.show(h, n.get_node(^"Mesh"), st.get("appearance", SnapshotCodec.NO_APPEARANCE),
					st.get("gait", 0), pose[0], _now_ms,
					BodyVisual.STAGGER if disguise.stagger_weight(h) > 0.0 else lunge_fx.pose(), # clips over the gait
					st.get("action", SnapshotCodec.Action.NONE))
			if objective_props != null: # carried objectives in the right hand (rule 10)
				objective_props.hold_items(n.get_node(^"Mesh"), st.get("drive", false), st.get("fuse", false))


## A BODY_CUE {handle, cue}: an elimination keeps the puppet where it stood as a collapsed corpse (no longer a
## remote; freed with this node), any other cue plays its one-shot clip.
## ponytail: corpses stay for the round (at most 4); fade them if the designer wants bodies gone.
func _on_body_cue(_tick: int, payload: Dictionary) -> void:
	var h: Variant = payload.get("handle")
	var kind: Variant = payload.get("cue")
	if not (h is int and kind is StringName) or not remotes.has(h):
		return
	if kind != EventBatch.CUE_ELIMINATED:
		body_visuals.cue(h, kind)
		return
	var n := remotes[h]
	remotes.erase(h)
	_buf.erase(h)
	_retired.erase(h)
	if body_visuals.collapse(n.get_node(^"Mesh")):
		n.visible = true
	else:
		n.queue_free()


## Interpolated [pos, yaw] at `at_ms` from `buf` ([local_ms, pos, yaw], oldest first); past the newest it
## extrapolates at most `max_extra_ms`, before the oldest it holds the oldest.
static func sample(buf: Array, at_ms: float, max_extra_ms: float) -> Array:
	var last: Array = buf[buf.size() - 1]
	if at_ms <= buf[0][0]:
		return [buf[0][1], buf[0][2]]
	for i in range(buf.size() - 1, 0, -1):
		var a: Array = buf[i - 1]
		var b: Array = buf[i]
		if at_ms >= a[0] and at_ms <= b[0]:
			var w: float = (at_ms - a[0]) / maxf(b[0] - a[0], 0.001)
			return [(a[1] as Vector3).lerp(b[1], w), lerp_angle(a[2], b[2], w)]
	if buf.size() < 2:
		return [last[1], last[2]]
	var prev: Array = buf[buf.size() - 2]
	var dt: float = maxf(last[0] - prev[0], 0.001)
	var ahead := minf(at_ms - last[0], max_extra_ms)
	return [(last[1] as Vector3) + ((last[1] as Vector3) - prev[1]) * (ahead / dt), last[2]]


func _remote() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var mesh := CapsuleMesh.new()
	mesh.radius = BODY_RADIUS_M
	mesh.height = knobs.controller.capsule_height_m
	var mi := MeshInstance3D.new()
	mi.name = &"Mesh"
	mi.mesh = mesh
	mi.material_override = StandardMaterial3D.new()
	mi.position.y = mesh.height / 2.0
	n.add_child(mi)
	var cone := _cone()
	cone.name = &"Cone"
	cone.position.y = knobs.controller.eye_height_m
	n.add_child(cone)
	return n


func _cone() -> SpotLight3D:
	var s := SpotLight3D.new()
	s.spot_range = knobs.defense.stun_range_m
	s.spot_angle = CONE_ANGLE_DEG
	s.light_energy = 4.0
	s.visible = false
	return s


func _exit_tree() -> void:
	close()


## NetAuthority's lobby provider on a client (only the host reads it).
class _NoLobby extends RefCounted:
	func state() -> StringName:
		return &"in_match"

	func player_count() -> int:
		return 0
