extends Node3D
## Windowed client(s) of a round_host.gd round (story match-flow/011): the first-person greybox view.
##   <godot> --path <repo> res://tests/manual/round_view.tscn -- [--host=127.0.0.1] [--port=24690] [--count=1]
##       [--view=0|monster|survivor] [--latency-ms=0] [--bot=hold] [--light]
## --count joins N clients from this process (round_host waits for --players); the shown one is client
## --view (an index, or the first client that is / is not the shapeshifter once its own snapshot says so);
## the others stand still. Mouse look and WASD drive the shown client unless --bot is given.
## --latency-ms puts client 0 behind a UdpLink with that round trip (half each way) on port + 100.
## --bot=hold walks client 0 to the nearest hiding spot, aims at it and holds interact; it prints the drawn
## frame of the press, of the first frame the hold bar is visible (the CI-16 AC1 capture) and of the
## first frame it is full (the server accepted the Start, AD-217).
## Story hud-results/003: --target=<marker type> aims --bot=hold at the nearest marker of that type instead of a
## hiding spot (fuse_box without a fuse: a refused Start). With --shots it waits for the prompt (prompt.png)
## before pressing, saves ring.png at half the ring, label.png on the first frame a refusal or cancel label
## shows and cancel.png on the broken ring; --release-at=<0-1> releases interact once the ring passes it.
## --bot=look turns the shown client to face the nearest remote body it draws (the screenshots).
## --bot=walk walks a survivor from the A1 spawn through the A1-H-S archway into H-S1 (zone A -> link) and
## saves zone_a.png, crossfade.png (half a crossfade after the border) and link.png (FM-12 ambience overlay).
## --bot=monitor (facility-map story 011; run against round_host --place=monitor) shows the client nearest the
## C1 monitor, aims it at the monitor and presses interact to cycle the feed: trueform.png on camera 1 before
## the disguise, disguise.png on camera 1 once the shapeshifter wears its B1 neighbour's form, cam2-4.png and
## off.png after each further press; feed_<tag>.png is the feed viewport alone. The other clients' remote bodies
## are hidden so only the shown client's drawing (its relevance, its snapshot appearance) is on screen. Prints
## the feed and main viewports' measured render times. The other clients' LightingPresenters are hidden too.
## --bot=lunge (story monster-abilities/007): the shown client faces the shapeshifter's body; the shapeshifter's
## client (another --count client) walks at the shown client and requests one Lunge within LUNGE_FROM_M. With
## --shots it saves windup.png (mid wind-up), dash.png (just after it) and hit.png (the hit-stop), as the
## shown client's LungePresenter shows them. Use --view=survivor.
## --no-flinch (story hud-results/005) joins every client with the camera flinch off (the P8 edge pulse shows).
## --fake-paused (story hud-results/005): see _edge_shots.
## --light turns the shown client's flashlight on once it has a body. Bots drive the shown client.
## --solo hides every body but the shown client's own and the other clients' lighting (art-pass screenshots of the map).
## --dev=<command> (dev menu evidence): once the shown client spawns, opens its F1 dev menu, sends <command>
## (DevCommands) and saves devmenu.png 90 drawn frames later.
## --captions (PA captions evidence): turns the shown client's Captions setting on and, once it spawns, plays the
## pa/t_60 and pa/t_10 caption lines through ClientSfx.captioned, the path a real PA line takes (RoundClient wiring).
## --no-roster: the shown client's Show roster off (story hud-results/002; the roster is seeded by _seed_roster).
## --shots=<dir> saves press.png, bar.png and full.png (bot) and view.png at drawn frame --shot-at=N.
## --bot=stage (borrowed-face story 009) lines the other clients up STAGE_AHEAD_M in front of the shown
## client's spawn, the shapeshifter beside one survivor (its target) in the middle, and turns the shown client
## to them. With --disguise the shapeshifter then faces its target and requests that survivor's form until
## its own entry shows it (disguise.png 1 s later); with --stun the shown client fires its taser at the
## shapeshifter once it stands there (after the disguise when both are given; stagger.png 6 drawn frames
## into the stagger). Every DisguisePresenter cue of the shown client is printed.
## Story survivor-defense/011 adds: --stun=survivor fires at the shapeshifter's target (a real survivor)
## instead; --stun=me has the first line survivor fire at the shown client (its own jitter and blue edge);
## (--stun=survivor aims at the last survivor in the line, clear of the shapeshifter.) --twice fires again RESIST_AFTER_S after the first stagger (inside the immunity: the true form's spark);
## --monster-light turns the shapeshifter's flashlight on once disguised (its cosmetic cone). Shots: arc.png,
## spark.png and edge.png on the first drawn frame each shows; ShockPresenter cues are printed too.
## Scare-events story 008: --scare-audio (with --bot=stage) has the shapeshifter request a Blackout at its own
## spot once the line stands (a Major blackout scare to the shown survivor beside it); the shown client's
## ScareTriggered and ScareAudio levels are printed, scare.png / duck.png saved, and for SCARE_AUDIO_FRAMES drawn
## frames each bus's peak (AudioServer.get_bus_peak_volume_left_db; training data, not in docs/engine-reference)
## is printed, then the per-bus maxima. Add --stun to overlap a PlayerShocked / MonsterStunned duck.
## Borrowed-face story 010: during --bot=stage the shown client's TransformPresenter distortions are printed
## with their bearing from its camera and the true bearing of the shapeshifter's own body, and warp-early.png
## warp-late.png are saved WARP_EARLY / WARP_LATE drawn frames after a drawn body first shows Transforming
## (drawn frames, not seconds: --write-movie renders faster than the host's wall clock).
## --bot=ping (story pings-and-callouts/008; use --count=5 --view=survivor): from the shown client's spawn,
## the other clients ping where they look and call out (Danger, Wait), the shown client pings ahead, then
## spams pings past its bucket, then opens the wheel aimed at a line. Shots: pending.png (own pending marker),
## markers.png (server markers and feed), toofast.png (rejection tick), wheel.png (wheel open).
## --bot=shifter (story hud-results/006; --count=5 --view=monster): the shown shapeshifter requests a Lunge,
## walks to the nearest survivor watching it, and once the face is available changes into it; that survivor
## then tases it. Shots of its HUD (S1-S5): trueform.png (Lunge cooling, observation filling), transforming.png
## (S4 mid-bar), disguised.png (form cooldown) and stunned.png (S5).
## --bot=ownstate (story hud-results/004; --count=5 --view=survivor): the shown survivor walks to the nearest
## hiding spot and hides (hidden.png), leaves, then the shapeshifter walks at it and lunges (seized.png in the
## commit, downed.png once Downed); everyone else then walks away so no camping slow stretches the bleed-out,
## and once it bleeds out the shown client spectates (spectating.png), then the view quits.
## --bot=warn (story pings-and-callouts/011; --count=5 --view=survivor): the shown client faces the true-form
## body it draws (else the nearest) and warning-pings it, another survivor warning-pings where it looks, two
## call out. Shots: warning.png (warning markers), expired.png (feed past its 8 s), scrollback.png (the
## feed_scrollback action held through Input.action_press: the retained lines again).
## --bot=gesture (story pings-and-callouts/008 AC-4; --count=5 --view=survivor): the shown client faces the
## nearest other survivor, which calls out Danger; gesture.png is saved GESTURE_SHOT_F drawn frames later
## (inside the 0.5 s placeholder gesture sphere over the speaker).
## --bot=conform (story hud-results/007; --count=6 --view=survivor against round_host --players=6): the five
## survivors each call out a different line in the same drawn frame, then each pings twice, turning between
## the pings (the shown survivor's second one is a warning ping). Shots: feed.png (4 lines visible), scrollback.png (all 5 with feed_scrollback held),
## markers.png (10 pings sent, at most 6 drawn). Prints the feed and marker counts.
## --bot=aim (story monster-abilities/011; --count=5 --view=monster): the shown shapeshifter uses its abilities
## through the shipped actions (Input.action_press, read by its ShapeshifterAim): holds false_signal at the floor
## ahead (fs_preview.png), releases it, holds it looking up (invalid.png if the ray finds no floor in range),
## releases, holds blackout at the floor (bo_preview.png), releases (bo_dark.png). Each release and the
## shapeshifter's cooldowns after it are printed (a running cooldown = the server accepted it).
## --via-input with --bot=lunge presses the lunge action on the shapeshifter's client instead of raw bytes.
## --bot=picker (story borrowed-face/011; --count=5 --view=monster): as --bot=shifter, but the change goes through the
## shown client's FormPicker (the shipped wheel and request): once the watched face is available it opens the
## picker aimed at that face (picker.png), releases it, waits out the transformation (disguised.png), then
## opens it again aimed at the true form (picker-disguised.png) and releases inside the form cooldown, so the
## server refuses and the HUD-3 label shows it (refused.png).
## --pad (story hud-results/012) with --bot=hold: until prompt.png, feeds a synthetic
## InputEventJoypadButton (A, bound to no game action) through Input.parse_input_event, so prompt.png shows
## the pad glyph (InputGlyphs switches by event type).
## --bot=budget (story hud-results/010; --count=6 --view=survivor against round_host --players=6 --force=<s>:evac):
## explore.png at BUDGET_EXPLORE_F, then once the shown HUD says Evacuation the five survivors call out and ping,
## the shown one holds at the nearest hiding spot, and busy.png is saved with the ring at half. Each <tag>.png has a
## <tag>_hud.png of the next frame with the 3D world culled over a flat BUDGET_BG (HUD pixels only) and a
## <tag>.json of rects: world markers (excluded from coverage), roster/checklist/marker rects, text rects.
## Phase-label and prompt changes save BUDGET_RUN consecutive HUD-only frames (evac_NN, prompt_NN); --clock waits
## for 26 s left and saves clock_off_NN with reduced motion off, then clock_on_NN at 22 s with it on, then quits.
## --reduced-motion sets reduced motion on every HUD presenter of the shown client.

const LINK_PORT_OFFSET := 100
const LINK_SEED := 11
const STAGE_AHEAD_M := 3.5
const STAGE_SPACING_M := 1.2
## The line's centre sits this far +X of the shown spawn: the spawn room's west floor edge is near x 0.
const STAGE_RIGHT_M := 1.0
const ARRIVE_M := 0.15
## Drawn frames between form-change requests while waiting for the observation to complete.
const REQUEST_EVERY := 15
## --twice: seconds after the first stagger; past stun_duration_s, inside stun_immunity_s (shipped values).
const RESIST_AFTER_S := 3.0


## Lighting (story facility-map/010): the map is lit only by each client's LightingPresenter (no sun); only
## the shown client's lights are visible. Every client prints each lighting record it applies ("LIGHT").
## --reduced-flash turns the shown client's reduced flash on. --blackout has the shapeshifter's client request
## a Blackout of its own volume once spawned. --shot-when=dark,evac,power (any of) saves <state>.png on the first frame
## the shown client's own volume shows that state. --yaw=<deg> [--pitch=<deg>] fixes the shown client's view.
## Story scare-events/009: --flash-scale=<0-1> sets every client's flash scale. --shot-when=strobe saves strobe.png
## on the first frame the shown client, standing still in a beacon volume, draws its Emergency strobe lit, and
## between.png 30 drawn frames later; hallucination.png on the first frame its monitor shows the impossible frame
## (round_host --force=<s>:hallucinate), printing every client's hallucinating() at that frame. With strobe, every rising strobe energy prints
## STROBE_ONSET with its drawn frame (the frame-sampled flash count).
## --measure prints the mean frame and GPU render time over MEASURE_FRAMES frames after spawning (run it
## without --write-movie, which fixes the frame step).

const MEASURE_FRAMES := 300
## --bot=lunge: request range, inside lunge_distance_m + lunge_hit_radius_m (test harness value, not a knob).
const LUNGE_FROM_M := 3.0
## --bot=lunge: drawn movement that counts as the dash having started, and frames into the coil for windup.png.
const DASH_SEEN_M := 0.3
const WINDUP_SHOT_FRAMES := 4
const WARP_EARLY := 10
const WARP_LATE := 45
const GESTURE_SHOT_F := 12

var _args: Dictionary = {}
var _knobs: Knobs
var _map: MapData
var _clients: Array[RoundClient] = []
var _shown: RoundClient
var _link: UdpLink
var _target := Vector3.INF
var _press_frame := -1
var _lit := false
## client -> whether it was the shapeshifter when first spawned (a disguise reads as a survivor later)
var _was_monster: Dictionary[RoundClient, bool] = {}
var _home := Vector3.INF
var _disguised_frame := -1
var _aimed := 0
var _fired := false
var _stagger_frame := -1
var _stagger_s := 0.0
var _refired := false
## --bot=walk: waypoint index, and seconds since the border was crossed (-1 before).
var _leg := 0
var _since_border := -1.0
## --bot=monitor: the next capture step, the frame the step started, render time samples.
var _step := 0
var _step_frame := -1
var _times: Dictionary[String, Array] = {}
var _blackout_sent := false
var _aim_start := -1
var _routed: Dictionary[int, bool] = {}
var _measure: Array[float] = []
var _lunged := false
var _coil_at := Vector3.INF
var _coil_seen := -1
var _warp_frame := -1
var _monster_client: RoundClient
var _strobe_last := 0.0
## --scare-audio: frame the shown client got its scare (-1 before), and the max bus peak per bus since.
var _scare_frame := -1
var _peaks: Dictionary[StringName, float] = {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	_knobs = Knobs.load_all()
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	_map = MapData.load_map()
	MapGreybox.build(self, _map)
	var host: String = _args.get("host", "127.0.0.1")
	var port := int(_args.get("port", "24690"))
	var latency := int(_args.get("latency-ms", "0"))
	for i in int(_args.get("count", "1")):
		var c := RoundClient.new(_knobs, TestMoveStep.apply, TestMoveStep.make_body, _map, true)
		c.name = "Client%d" % i
		c.level = self # BUG-0018: every client applies the same door state to the one level
		add_child(c)
		var to := port
		if i == 0 and latency > 0:
			_link = UdpLink.new(LINK_SEED)
			_link.delay_s = latency / 2000.0
			to = port + LINK_PORT_OFFSET
			_link.start(to, port)
		c.flinch_enabled = not _args.has("no-flinch") # hud-results story 005: the P8 pulse instead
		c.join(host, to, "View%d" % i)
		c.scripted = InputFrame.new() # idle; the shown client drops it for LocalInput below
		_clients.append(c)
	print("ROUND VIEW %d clients -> %s:%d latency %d ms" % [_clients.size(), host, port, latency])


func _process(delta: float) -> void:
	if _args.has("shot-at") and Engine.get_frames_drawn() == int(_args["shot-at"]):
		_shot("view")
	if _link != null:
		_link.pump(Time.get_ticks_msec() / 1000.0)
	_pick_view()
	_seed_roster()
	_lighting()
	_scare_shots()
	_edge_shots()
	var c0 := _shown
	if c0 != null and _own_step == 4:
		_own_bot(c0) # a spectator's own body is not "spawned" (see _own_bot)
		return
	if c0 == null or not c0.is_spawned():
		return
	if _args.has("yaw"):
		if c0.scripted == null:
			c0.scripted = InputFrame.new()
		c0.scripted.yaw = deg_to_rad(float(_args["yaw"]))
		c0.scripted.pitch = deg_to_rad(float(_args.get("pitch", "0")))
	if _args.has("measure") and _measure.size() < MEASURE_FRAMES * 2:
		_sample()
	if _args.has("light") and not _lit:
		_lit = true
		c0.toggle_flashlight()
	if _args.has("solo"):
		_solo(c0)
	if c0.scripted == null and _args.has("bot"):
		c0.scripted = InputFrame.new()
	if _args.get("bot", "") == "hold":
		_bot(c0)
	elif _args.get("bot", "") == "look":
		_look(c0)
	elif _args.get("bot", "") == "stage":
		_stage(c0)
	elif _args.get("bot", "") == "walk":
		_walk(c0, delta)
	elif _args.get("bot", "") == "monitor":
		_monitor(c0)
	elif _args.get("bot", "") == "lunge":
		_lunge_bot(c0)
	elif _args.get("bot", "") == "ping":
		_ping_bot(c0)
	elif _args.get("bot", "") == "warn":
		_warn_bot(c0)
	elif _args.get("bot", "") == "gesture":
		_gesture_bot(c0)
	elif _args.get("bot", "") == "shifter":
		_shifter_bot(c0)
	elif _args.get("bot", "") == "conform":
		_conform_bot(c0)
	elif _args.get("bot", "") == "ownstate":
		_own_bot(c0)
	elif _args.get("bot", "") == "aim":
		_aim_bot(c0)
	elif _args.get("bot", "") == "picker":
		_picker_bot(c0)
	elif _args.get("bot", "") == "budget":
		_budget_bot(c0)


## Shows the chosen client's camera and HUD only.
func _pick_view() -> void:
	var want: String = _args.get("view", "0")
	var pick: RoundClient = null
	for i in _clients.size():
		var c := _clients[i]
		if not c.is_spawned():
			continue ## the role reads from the own entry once spawned
		if want == "monitor" and c.body.global_position.distance_to(Vector3(51, 0, 7)) < 3.0:
			pick = c
			break
		if want == str(i) or (want == "monster" and _role(c)) or (want == "survivor" and not _role(c)):
			pick = c
			break
	if pick == null or pick == _shown:
		return
	_shown = pick
	for c in _clients:
		if c.hud != null:
			c.hud.visible = c == pick
		if c.shock != null:
			c.shock.edge().visible = c == pick # every client's edge layer draws in this one window
	pick.camera.make_current()
	if not _args.has("bot"):
		pick.scripted = null
	print("SHOWING %s (%s)" % [pick.name, "monster" if _role(pick) else "survivor"])


func _bot(c: RoundClient) -> void:
	var feet := c.body.global_position
	if _target == Vector3.INF:
		var best := INF
		for t in _map.interactables():
			var m := t as MapMarker
			if m != null and m.type == StringName(_args.get("target", "hiding")) and feet.distance_to(m.position) < best:
				best = feet.distance_to(m.position)
				_target = m.position
		print("BOT target %s from %s" % [_target, feet])
	var point := _target + Vector3.UP * _knobs.controller.capsule_height_m * 0.5
	var eye := feet + Vector3.UP * _knobs.controller.eye_height_m
	var flat := Vector2(point.x - eye.x, point.z - eye.z)
	c.scripted.yaw = atan2(-flat.x, -flat.y)
	c.scripted.pitch = atan2(point.y - eye.y, flat.length())
	var near := flat.length() < _knobs.objectives.interact_range_m * 0.6
	c.scripted.move = Vector2.ZERO if near else Vector2(0, 1)
	var ui := c.interaction
	if _args.has("pad") and not has_meta(&"prompt"): # each frame until the shot: a stray mouse move flips back
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_A
		pad.pressed = true
		Input.parse_input_event(pad)
	if ui != null and _args.has("shots"):
		# the prompt fades in over InteractionHud.FADE_S: shoot it once it has shown 10 drawn frames
		set_meta(&"prompt_frames", get_meta(&"prompt_frames", 0) + 1 if ui.shown() == &"prompt" else 0)
		for tag: String in ["prompt", "cancel"]:
			if tag == "prompt" and get_meta(&"prompt_frames") < 10:
				continue
			if ui.shown() == StringName(tag) and not has_meta(StringName(tag)):
				set_meta(StringName(tag), true)
				_shot(tag)
				print("HUD %s: '%s' label '%s'" % [tag, ui.prompt_text(), ui.label_text()])
		if ui.shown() == &"ring" and ui.ring_value() >= 0.5 and not has_meta(&"ring"):
			set_meta(&"ring", true)
			_shot("ring")
		if ui.label_text() != "" and not has_meta(&"label"):
			set_meta(&"label", true)
			_shot("label")
			print("HUD label '%s' at frame %d" % [ui.label_text(), Engine.get_frames_drawn()])
		if _args.has("release-at") and c.bar.visible and c.bar.value >= float(_args["release-at"]):
			c.scripted.interact = false
	var waited := ui == null or not _args.has("shots") or has_meta(&"prompt")
	if near and waited and _press_frame < 0 and c.body.velocity.length() < 0.05:
		c.scripted.interact = true
		_press_frame = Engine.get_frames_drawn()
		_shot("press")
		print("PRESS frame %d target %d" % [_press_frame, c.local_target(c.scripted.yaw, c.scripted.pitch)])
	elif _press_frame >= 0 and c.bar.visible and not has_meta(&"bar"):
		set_meta(&"bar", true)
		_shot("bar")
		var n := Engine.get_frames_drawn() - _press_frame
		print("BAR frame %d: %d drawn frames after the press" % [Engine.get_frames_drawn(), n])
	if _press_frame >= 0 and not has_meta(&"acked") and c.predictor.last_own.get("hold_net_id", -1) != -1:
		set_meta(&"acked", true)
		print("SERVER HOLD net id %d at frame %d (bar visible %s)" % [c.predictor.last_own.hold_net_id,
				Engine.get_frames_drawn(), c.bar.visible])
	if has_meta(&"acked") and not has_meta(&"full") and c.bar.visible and c.bar.value >= 1.0:
		set_meta(&"full", true)
		_shot("full")
		print("BAR FULL at frame %d (server hold net id %d)" % [Engine.get_frames_drawn(),
				c.predictor.last_own.get("hold_net_id", -1)])


## Saves this frame once it is drawn (the viewport texture read in _process still holds the last frame).
func _shot(tag: String) -> void:
	if not _args.has("shots"):
		return
	var frame := Engine.get_frames_drawn()
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_args["shots"], tag]
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT %s of frame %d" % [path, frame])


## Lighting flags: only the shown client's lights draw; route records to the log; Blackout and state shots.
func _lighting() -> void:
	for i in _clients.size():
		var c := _clients[i]
		if c.lights == null:
			continue
		c.lights.visible = c == _shown
		if not _routed.has(i):
			_routed[i] = true
			c.router.subscribe(EventBatch.LIGHTING, _on_light.bind(i))
		if c == _shown and c.lights.reduced_flash != _args.has("reduced-flash"):
			c.lights.reduced_flash = _args.has("reduced-flash")
		if c == _shown and _args.has("dev") and c.is_spawned() and c.dev_menu != null and not has_meta(&"dev"):
			set_meta(&"dev", Engine.get_frames_drawn())
			c.dev_menu.toggle()
			c.dev_menu.send(String(_args["dev"]))
		if has_meta(&"dev") and c == _shown and Engine.get_frames_drawn() == int(get_meta(&"dev")) + 90:
			_shot("devmenu")
		if c == _shown and _args.has("captions") and c.is_spawned() and not has_meta(&"captioned"):
			set_meta(&"captioned", true)
			c.settings = PlayerSettings.new(OS.get_user_data_dir() + "/captions_shot.cfg", [])
			c.settings.captions = true
			for id: StringName in [&"pa/t_60", &"pa/t_10"]:
				c.client_sfx.captioned.emit("%s %s" % [tr("PA:"), ClientSfx.PA_TEXT[id]])
		if _args.has("blackout") and not _blackout_sent and c.is_spawned() and c.is_monster():
			_blackout_sent = true
			(c.multiplayer as SceneMultiplayer).send_bytes(MonsterAbilities.request_packet(
					MonsterAbilities.Ability.BLACKOUT, c.body.global_position), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE)
			print("BLACKOUT requested by %s at %s" % [c.name, c.body.global_position])
	if _shown == null or _shown.lights == null or not _shown.is_spawned():
		return
	var r := _shown.lights.record_of(MapQueries.new(_map).volume_at(_shown.body.global_position))
	if r.is_empty():
		return
	for want in String(_args.get("shot-when", "")).split(",", false):
		var hit: bool = (want == "dark" and r.dark_until > 0) or (want == "evac" and r.base == FacilityLighting.Base.EVACUATION) 				or (want == "power" and r.base == FacilityLighting.Base.POWER_RESTORED)
		if hit and not has_meta(StringName("shot_" + want)):
			set_meta(StringName("shot_" + want), true)
			_shot(want)


## Router handler on every client: one line per applied lighting record (AC 8 timing across clients).
func _on_light(tick: int, payload: Dictionary, client: int) -> void:
	print("LIGHT client %d tick %d at %d ms: %s base %s overlays %s dark_until %s" % [client, tick,
			Time.get_ticks_msec(), payload.get("volume"), payload.get("base"), payload.get("overlays"),
			payload.get("dark_until")])


## Frame time and GPU render time of the main viewport; prints the means after MEASURE_FRAMES frames.
## Viewport render-time measuring is training data (RenderingServer, not in docs/engine-reference).
func _sample() -> void:
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	_measure.append(get_process_delta_time() * 1000.0)
	_measure.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	if _measure.size() < MEASURE_FRAMES * 2:
		return
	var frame := 0.0
	var gpu := 0.0
	for i in range(0, _measure.size(), 2):
		frame += _measure[i]
		gpu += _measure[i + 1]
	var n := _measure.size() / 2.0
	print("MEASURE %d frames in %s (%s): frame %.2f ms, gpu %.2f ms, driver %s" % [n,
			MapQueries.new(_map).volume_at(_shown.body.global_position), _shown.name, frame / n, gpu / n,
			RenderingServer.get_current_rendering_driver_name()])


func _look(c: RoundClient) -> void:
	var feet := c.body.global_position
	var best := INF
	for n: Node3D in c.remotes.values():
		if n.visible and feet.distance_to(n.position) < best:
			best = feet.distance_to(n.position)
			var d := n.position - feet
			c.scripted.yaw = atan2(-d.x, -d.z)
			c.scripted.pitch = -0.1


func _ping_bot(c0: RoundClient) -> void:
	if _step_frame < 0:
		_step_frame = Engine.get_frames_drawn()
	var f := Engine.get_frames_drawn() - _step_frame
	c0.scripted.yaw = 0.6
	c0.scripted.pitch = -0.15
	var others := _clients.filter(func(c: RoundClient) -> bool: return c != c0 and c.is_spawned() and not _role(c))
	if f == 30:
		c0.ping_hud.ping()
		_shot("pending")
	elif f == 40:
		for c: RoundClient in others:
			c.ping_hud.ping()
		if others.size() > 0:
			others[0].callouts.request(&"danger")
		if others.size() > 1:
			others[1].callouts.request(&"wait")
	elif f == 90:
		_shot("markers")
	elif f == 100:
		for i in 8:
			c0.ping_hud.ping()
	elif f == 125:
		_shot("toofast")
	elif f == 140:
		c0.ping_hud.open_wheel()
		c0.ping_hud.aim_wheel(Vector2(120, -120))
	elif f == 150:
		_shot("wheel")
	elif f == 160:
		c0.ping_hud.close_wheel(false)
		print("PING BOT pending=%d rejections=%d callouts=%s" % [c0.pings.pending.size(), c0.pings.rejections,
			c0.ping_hud.feed_history()])
		get_tree().quit()


func _warn_bot(c0: RoundClient) -> void:
	if _step_frame < 0:
		_step_frame = Engine.get_frames_drawn()
	var f := Engine.get_frames_drawn() - _step_frame
	var others := _clients.filter(func(c: RoundClient) -> bool: return c != c0 and c.is_spawned() and not _role(c))
	var target: Node3D = null
	for h: int in c0.remotes:
		if c0.remotes[h].visible and c0.puppets.state_of(h).get("appearance", -1) == CharacterDef.TRUE_FORM_APPEARANCE_ID:
			target = c0.remotes[h]
	if target == null:
		_look(c0)
	else:
		var d := target.position - c0.body.global_position
		c0.scripted.yaw = atan2(-d.x, -d.z)
		c0.scripted.pitch = -0.1
	if f == 30 and others.size() > 1:
		others[0].callouts.request(&"danger")
		others[1].callouts.request(&"wait")
	elif f == 50:
		c0.ping_hud.warn()
		if others.size() > 0:
			others[0].ping_hud.warn()
	elif f == 110:
		_shot("warning")
		print("WARN BOT own=%s received=%s" % [c0.predictor.last_own.get("appearance"), c0.pings.received])
		for m in c0.ping_hud.markers_now():
			print("WARN BOT marker %s warning=%s" % [m["label"], m.get("warning")])
	elif f == 640:
		_shot("expired")
		print("WARN BOT at %d: feed=%d ms=%d" % [f, c0.ping_hud.feed_lines().size(), Time.get_ticks_msec()])
	elif f == 650:
		Input.action_press(&"feed_scrollback")
	elif f == 660:
		_shot("scrollback")
		print("WARN BOT scrollback=%s lines=%s" % [c0.ping_hud.scrollback, c0.ping_hud.feed_lines().size()])
	elif f == 670:
		Input.action_release(&"feed_scrollback")
		get_tree().quit()


func _gesture_bot(c0: RoundClient) -> void:
	if _step_frame < 0:
		_step_frame = Engine.get_frames_drawn()
	var f := Engine.get_frames_drawn() - _step_frame
	var speaker: RoundClient = null
	for c in _clients:
		if c != c0 and c.is_spawned() and not _role(c) and (speaker == null or c.body.global_position.distance_to(
				c0.body.global_position) < speaker.body.global_position.distance_to(c0.body.global_position)):
			speaker = c
	if speaker == null:
		return
	var eye := c0.body.global_position + Vector3.UP * _knobs.controller.eye_height_m
	var top := speaker.body.global_position + Vector3.UP * _knobs.controller.capsule_height_m
	var flat := Vector2(top.x - eye.x, top.z - eye.z)
	c0.scripted.yaw = atan2(-flat.x, -flat.y)
	c0.scripted.pitch = atan2(top.y - eye.y, flat.length())
	if f == 60:
		speaker.callouts.request(&"danger")
		print("GESTURE BOT %s calls out at %.2f m (frame %d)" % [speaker.name, flat.length(), Engine.get_frames_drawn()])
	elif f > 60 and not has_meta(&"gesture") and c0.remotes.values().any(
			func(n: Node3D) -> bool: return n.has_node(^"Gesture")):
		set_meta(&"gesture", Engine.get_frames_drawn())
		print("GESTURE drawn at frame %d" % Engine.get_frames_drawn())
	elif has_meta(&"gesture") and Engine.get_frames_drawn() == int(get_meta(&"gesture")) + GESTURE_SHOT_F:
		_shot("gesture")
		print("GESTURE BOT feed=%s" % [c0.ping_hud.feed_history()])
	elif f == 200:
		get_tree().quit()


func _conform_bot(c0: RoundClient) -> void:
	if _step_frame < 0:
		_step_frame = Engine.get_frames_drawn()
	var f := Engine.get_frames_drawn() - _step_frame
	var all := _clients.filter(func(c: RoundClient) -> bool: return c.is_spawned() and not _role(c))
	var lines := CalloutSet.load_shipped().lines
	c0.scripted.yaw = 0.6 + (0.25 if f >= 85 else 0.0)
	c0.scripted.pitch = -0.7 if f < 75 else -0.15 # the lit floor behind the feed box, then the pings ahead
	if f == 30:
		for i in all.size():
			(all[i] as RoundClient).callouts.request(lines[i % lines.size()])
	elif f == 60:
		_shot("feed")
		print("CONFORM feed visible=%d history=%s" % [c0.ping_hud.feed_lines().size(), c0.ping_hud.feed_history()])
	elif f == 62:
		Input.action_press(&"feed_scrollback")
	elif f == 70:
		_shot("scrollback")
		print("CONFORM scrollback lines=%d" % c0.ping_hud.feed_lines().size())
	elif f == 72: # not in the shot's frame: _shot returns before the frame is drawn
		Input.action_release(&"feed_scrollback")
	elif f == 75 or f == 90:
		for i in all.size():
			var c: RoundClient = all[i]
			if c != c0:
				c.scripted.yaw = 0.6 + (i - 2) * 0.35 + (0.15 if f == 90 else 0.0)
				c.scripted.pitch = -0.2
	elif f == 80 or f == 95:
		for c: RoundClient in all:
			if f == 95 and c == c0:
				c.ping_hud.warn() # a warning point among the location pings: its own shape
			else:
				c.ping_hud.ping()
	elif f == 140:
		_shot("markers")
		print("CONFORM markers drawn=%d model=%d" % [c0.ping_hud.markers_now().size(), c0.hud_model.markers().size()])
		for m in c0.ping_hud.markers_now():
			print("CONFORM marker kind=%d %s" % [m["kind"], m["label"]])
	elif f == 150:
		get_tree().quit()


## --no-roster turns the shown HUD's Show roster off. The roster names come from the server's RosterFeed
## (HUD-11); this no longer seeds placeholder names.
func _seed_roster() -> void:
	if _shown == null or has_meta(&"roster"):
		return
	for c in _clients:
		if not c.is_spawned():
			return
	set_meta(&"roster", true)
	(_shown.hud.get_node(^"AlwaysOnHud") as AlwaysOnHud).show_roster = not _args.has("no-roster")


## Whether `c` is the shapeshifter, fixed at its first spawned answer.
func _role(c: RoundClient) -> bool:
	if not _was_monster.has(c):
		_was_monster[c] = c.is_monster()
	return _was_monster[c]


func _stage(c0: RoundClient) -> void:
	if c0.disguise != null and not c0.disguise.cue.is_connected(_on_cue):
		c0.disguise.cue.connect(_on_cue)
		c0.shock.cue.connect(_on_cue)
	_shock_shots(c0)
	if c0.warp != null and not c0.warp.heard.is_connected(_on_distortion):
		c0.warp.heard.connect(_on_distortion)
	if _home == Vector3.INF:
		_home = c0.body.global_position
	var line: Array[RoundClient] = []
	var m: RoundClient = null
	for c in _clients:
		if c == c0:
			continue
		if not c.is_spawned():
			return
		if _role(c):
			m = c
		else:
			line.append(c)
	if m == null or line.is_empty():
		return
	_monster_client = m
	_watch_warp(c0)
	var mi := mini(1, line.size())
	line.insert(mi, m)
	var target: RoundClient = line[mi + 1] if mi + 1 < line.size() else line[mi - 1]
	var arrived := true
	for j in line.size():
		var c := line[j]
		var slot := _home + Vector3(STAGE_RIGHT_M + (j - (line.size() - 1) / 2.0) * STAGE_SPACING_M, 0.0,
				-STAGE_AHEAD_M)
		var d := slot - c.body.global_position
		d.y = 0.0
		if d.length() > ARRIVE_M:
			arrived = false
			if Engine.get_frames_drawn() % 150 == 0:
				print("STAGE %s at %s -> %s" % [c.name, c.body.global_position, slot])
			c.scripted.yaw = atan2(-d.x, -d.z)
			c.scripted.move = Vector2(0, 1)
			continue
		c.scripted.move = Vector2.ZERO
		var face := (target if c == m else c0).body.global_position - c.body.global_position
		c.scripted.yaw = atan2(-face.x, -face.z)
	var mid := (m.body.global_position + target.body.global_position) / 2.0 - c0.body.global_position
	c0.scripted.yaw = atan2(-mid.x, -mid.z)
	c0.scripted.pitch = -0.15
	if not arrived and not _fired: # a stunned body may leave its slot; keep watching it
		return
	if _args.has("scare-audio"):
		_scare_audio(c0, m)
	var frame := Engine.get_frames_drawn()
	if _args.has("disguise") and _disguised_frame < 0:
		var want: int = target.predictor.last_own.get("appearance", -1)
		if m.predictor.last_own.get("appearance", -1) == want:
			_disguised_frame = frame
			print("DISGUISED as appearance %d at frame %d" % [want, frame])
			if _args.has("monster-light"):
				m.toggle_flashlight()
		elif frame % REQUEST_EVERY == 0:
			(m.multiplayer as SceneMultiplayer).send_bytes(
					BorrowedFace.request_packet(target.predictor.last_own.get("id", -1)), 1,
					MultiplayerPeer.TRANSFER_MODE_RELIABLE)
		return
	if _disguised_frame >= 0 and frame == _disguised_frame + 30:
		_print_drawn(c0)
		_shot("disguise")
	if not _args.has("stun") or (_disguised_frame >= 0 and frame < _disguised_frame + 45):
		return
	if _args["stun"] == "me":
		_aimed += 1
		if _aimed == 10:
			(line[0].multiplayer as SceneMultiplayer).send_bytes(SurvivorDefense.fire_packet(), 1,
					MultiplayerPeer.TRANSFER_MODE_RELIABLE)
			print("FIRE by %s at the shown client, frame %d" % [line[0].name, frame])
		return
	var aim_at := line[-1] if _args["stun"] == "survivor" else m # the end of the line: clear of the aim tolerance
	var eye := c0.body.global_position + Vector3.UP * _knobs.controller.eye_height_m
	var chest := aim_at.body.global_position + Vector3.UP * _knobs.controller.capsule_height_m * 0.6
	var flat := Vector2(chest.x - eye.x, chest.z - eye.z)
	c0.scripted.yaw = atan2(-flat.x, -flat.y)
	c0.scripted.pitch = atan2(chest.y - eye.y, flat.length())
	_aimed += 1
	if _aimed == 10 and not _fired:
		_fired = true
		(c0.multiplayer as SceneMultiplayer).send_bytes(SurvivorDefense.fire_packet(), 1,
				MultiplayerPeer.TRANSFER_MODE_RELIABLE)
		print("FIRE at frame %d" % frame)
	for h: int in c0.remotes:
		if _stagger_frame < 0 and c0.disguise.stagger_weight(h) > 0.0:
			_stagger_frame = frame
			print("STAGGER on handle %d at frame %d" % [h, frame])
	if _stagger_frame >= 0 and frame == _stagger_frame + 6:
		_print_drawn(c0)
		_shot("stagger")
	if _stagger_frame >= 0:
		_stagger_s += get_process_delta_time()
	if _args.has("twice") and not _refired and _stagger_s >= RESIST_AFTER_S:
		_refired = true
		(c0.multiplayer as SceneMultiplayer).send_bytes(SurvivorDefense.fire_packet(), 1,
				MultiplayerPeer.TRANSFER_MODE_RELIABLE)
		print("FIRE again at frame %d" % frame)


## Story survivor-defense/011: arc.png, spark.png and edge.png on the first drawn frame each is lit.
func _shock_shots(c: RoundClient) -> void:
	for kind: Array in [["arc", c.shock.arc_light().light_energy], ["spark", c.shock.spark_light().light_energy],
			["edge", c.shock.edge().modulate.a]]:
		if kind[1] > 0.0 and not has_meta(kind[0]):
			set_meta(kind[0], true)
			print("%s lit (%.2f) at frame %d" % [kind[0], kind[1], Engine.get_frames_drawn()])
			_print_drawn(c)
			_shot(kind[0])


## Warp captures: the first drawn frame a remote shows Transforming, then two shots into it.
func _watch_warp(c0: RoundClient) -> void:
	var frame := Engine.get_frames_drawn()
	var on := false
	for h: int in c0.remotes:
		on = on or (c0.remotes[h].visible and c0.puppets.state_of(h).get("transforming", false))
	if on and _warp_frame < 0:
		_warp_frame = frame
		print("WARP first drawn at frame %d" % frame)
	var tags := {_warp_frame + WARP_EARLY: "warp-early", _warp_frame + WARP_LATE: "warp-late"}
	if _warp_frame >= 0 and tags.has(frame):
		for h: int in c0.remotes:
			var mi := c0.remotes[h].get_node(^"Mesh") as GeometryInstance3D
			var mat := mi.material_overlay as ShaderMaterial
			print("WARP handle %d transforming %s overlay %s warp %s" % [h, c0.puppets.state_of(h).get("transforming",
					false), mat != null, mat.get_shader_parameter(&"warp") if mat != null else "-"])
		_shot(tags[frame])


func _on_distortion(sound: StringName, at: Vector3) -> void:
	var cam := _shown.camera.global_transform
	var truth := _monster_client.body.global_position if _monster_client != null else at
	print("DISTORTION %s at %s frame %d: bearing %.1f deg, true bearing %.1f deg, distance %.2f m" % [sound, at,
			Engine.get_frames_drawn(), TransformPresenter.bearing_deg(cam, at), TransformPresenter.bearing_deg(cam, truth),
			cam.origin.distance_to(at)])


func _on_cue(sound: StringName, at: Vector3) -> void:
	print("CUE %s at %s frame %d" % [sound, at, Engine.get_frames_drawn()])


## Prints every drawn remote's handle, snapshot appearance and position (the shot's legend).
func _print_drawn(c: RoundClient) -> void:
	for h: int in c.remotes:
		var n := c.remotes[h]
		print("DRAWN handle %d appearance %d at %s visible %s stagger %.2f" % [h,
				c.puppets.state_of(h).get("appearance", -1), n.position, n.visible, c.disguise.stagger_weight(h)])


## A1 spawn -> archway A1-H-S (10, 39) -> H-S1; shots on either side of the border and mid-fade.
func _walk(c: RoundClient, delta: float) -> void:
	const ROUTE: Array[Vector3] = [Vector3(8.0, 0.0, 38.8), Vector3(16.0, 0.0, 38.8)]
	var feet := c.body.global_position
	if _leg == 0 and not has_meta(&"zone_a") and c.ambience.active_zone == &"A" and Engine.get_frames_drawn() > 120:
		set_meta(&"zone_a", true)
		_shot("zone_a")
	if _leg < ROUTE.size():
		var d := ROUTE[_leg] - feet
		c.scripted.yaw = atan2(-d.x, -d.z)
		c.scripted.move = Vector2(0, 1)
		if Vector2(d.x, d.z).length() < 0.3:
			_leg += 1
	else:
		c.scripted.move = Vector2.ZERO
	if c.ambience.active_zone == &"link":
		if _since_border < 0.0:
			_since_border = 0.0
			print("BORDER %s at %s" % [c.ambience.debug_text(), feet])
		_since_border += delta
		if _since_border >= ZoneAmbience.CROSSFADE_S / 2.0 and not has_meta(&"crossfade"):
			set_meta(&"crossfade", true)
			print("CROSSFADE %s" % c.ambience.debug_text())
			_shot("crossfade")
		if _since_border >= ZoneAmbience.CROSSFADE_S + 0.5 and not has_meta(&"link"):
			set_meta(&"link", true)
			print("LINK %s" % c.ambience.debug_text())
			_shot("link")

## Camera captures in order: [tag, camera wanted, wait for the disguise first, wait for B1 dark first]. B1 is
## dark only when round_host --force=<s>:blackout fires; "dark" and "dark_cam2" wait for it.
const MONITOR_STEPS := [["trueform", 0, false, false], ["disguise", 0, true, false], ["cam2", 1, false, false],
	["cam3", 2, false, false], ["cam4", 3, false, false], ["off", -1, false, false], ["dark", 0, false, true],
	["dark_cam2", 1, false, false]]
## Drawn frames a step waits once its camera shows (interpolation and the feed settle) before the shot.
const MONITOR_SETTLE := 45


## --solo (art-pass screenshots): no remote body is drawn and only the shown client's lighting lights the world.
func _solo(c0: RoundClient) -> void:
	process_priority = 100 # after the clients' _process, so the hiding sticks this frame
	for c in _clients:
		for n: Node3D in c.remotes.values():
			n.visible = false
		if c != c0:
			c.body.visible = false # its own body and viewmodel: every client draws into this window
			if c.lights != null:
				c.lights.visible = false


func _monitor(c0: RoundClient) -> void:
	process_priority = 100 # after the clients' _process, so the hiding below sticks this frame
	var m: RoundClient = null
	var target: RoundClient = null
	for c in _clients:
		if not c.is_spawned():
			return
		if c != c0:
			for n: Node3D in c.remotes.values():
				n.visible = false
			if c.lights != null:
				c.lights.visible = false # only the shown client's received lighting records light the world
		if _role(c):
			m = c
	for c in _clients:
		if c != c0 and c != m and (target == null or c.body.global_position.distance_to(m.body.global_position)
				< target.body.global_position.distance_to(m.body.global_position)):
			target = c
	var face := target.body.global_position - m.body.global_position
	m.scripted.yaw = atan2(-face.x, -face.z)
	var eye := c0.body.global_position + Vector3.UP * _knobs.controller.eye_height_m
	var point := Vector3(51.0, _knobs.controller.capsule_height_m * 0.5, 7.0)
	var flat := Vector2(point.x - eye.x, point.z - eye.z)
	c0.scripted.yaw = atan2(-flat.x, -flat.y)
	c0.scripted.pitch = atan2(point.y - eye.y, flat.length())
	if _step >= MONITOR_STEPS.size():
		return
	var frame := Engine.get_frames_drawn()
	var step: Array = MONITOR_STEPS[_step]
	if frame % 90 == 0:
		print("MONITOR step %d feed %d target %d appearance %d/%d" % [_step, c0.feed.current,
				c0.local_target(c0.scripted.yaw, c0.scripted.pitch), m.predictor.last_own.get("appearance", -1),
				target.predictor.last_own.get("appearance", -2)])
	_sample_times(c0, step[0])
	if step[2] and m.predictor.last_own.get("appearance", -1) != target.predictor.last_own.get("appearance", -2):
		if frame % REQUEST_EVERY == 0:
			(m.multiplayer as SceneMultiplayer).send_bytes(
					BorrowedFace.request_packet(target.predictor.last_own.get("id", -1)), 1,
					MultiplayerPeer.TRANSFER_MODE_RELIABLE)
		return
	if step[3] and c0.feed.current == step[1] and c0.lights.record_of(&"B1").get("dark_until", 0) == 0:
		return
	if c0.feed.current != step[1]:
		_step_frame = -1
		# A rising edge per press: hold interact for 3 frames out of every 12.
		c0.scripted.interact = frame % 12 < 3
		return
	c0.scripted.interact = false
	if _step_frame < 0:
		_step_frame = frame
		print("FEED camera %d at frame %d (%s)" % [c0.feed.current, frame, step[0]])
	if frame == _step_frame + MONITOR_SETTLE:
		print("LIGHTING B1 %s H-S3 %s (shown client's received records)" % [c0.lights.record_of(&"B1"),
				c0.lights.record_of(&"H-S3")])
	if frame == _step_frame + MONITOR_SETTLE:
		_print_drawn(c0)
		_shot(step[0])
		_feed_shot(c0, step[0])
		_print_times(step[0])
		_step += 1
		_step_frame = -1


## Saves the feed viewport's own image (only while the feed renders).
func _feed_shot(c: RoundClient, tag: String) -> void:
	if not _args.has("shots") or c.feed.current == Surveillance.OFF:
		return
	await RenderingServer.frame_post_draw
	var path := "%s/feed_%s.png" % [_args["shots"], tag]
	c.feed.viewport.get_texture().get_image().save_png(path)
	print("SHOT %s" % path)


## Collects the feed and main viewports' measured CPU and GPU render times (ms) per capture step.
func _sample_times(c: RoundClient, tag: String) -> void:
	var feed_rid := c.feed.viewport.get_viewport_rid()
	var main_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(feed_rid, true)
	RenderingServer.viewport_set_measure_render_time(main_rid, true)
	var row: Array = _times.get_or_add(tag, [])
	row.append([RenderingServer.viewport_get_measured_render_time_cpu(feed_rid),
			RenderingServer.viewport_get_measured_render_time_gpu(feed_rid),
			RenderingServer.viewport_get_measured_render_time_cpu(main_rid),
			RenderingServer.viewport_get_measured_render_time_gpu(main_rid)])


func _print_times(tag: String) -> void:
	var rows: Array = _times.get(tag, [])
	var sum := [0.0, 0.0, 0.0, 0.0]
	for r: Array in rows.slice(maxi(0, rows.size() - MONITOR_SETTLE)):
		for i in 4:
			sum[i] += r[i]
	var n := float(mini(rows.size(), MONITOR_SETTLE))
	print("RENDER %s over %d frames: feed cpu %.3f gpu %.3f ms, main cpu %.3f gpu %.3f ms" % [tag, n,
			sum[0] / n, sum[1] / n, sum[2] / n, sum[3] / n])

## --bot=lunge: see the class doc. Shots are timed from the shown client's coil, so they show what it drew.
func _lunge_bot(c: RoundClient) -> void:
	var m: RoundClient = null
	for o in _clients:
		if o != c and o.is_spawned() and o.is_monster():
			m = o
	var drawn := Vector3.INF ## the shapeshifter's body as the shown client draws it
	for h: int in c.remotes:
		if c.puppets.state_of(h).get("appearance", -1) == CharacterDef.TRUE_FORM_APPEARANCE_ID:
			drawn = c.remotes[h].position
			var d := c.remotes[h].position - c.body.global_position
			c.scripted.yaw = atan2(-d.x, -d.z)
			c.scripted.pitch = -0.15
	if m == null:
		return
	if m.scripted == null:
		m.scripted = InputFrame.new()
	var to := c.body.global_position - m.body.global_position
	m.scripted.yaw = atan2(-to.x, -to.z)
	var near := Vector2(to.x, to.z).length() <= LUNGE_FROM_M
	m.scripted.move = Vector2.ZERO if near or _lunged else Vector2(0, 1)
	if near and not _lunged:
		_lunged = true
		if _args.has("via-input"):
			Input.action_press(&"lunge") # read by the shapeshifter's ShapeshifterAim, the only one mounted
			get_tree().create_timer(0.1).timeout.connect(Input.action_release.bind(&"lunge"))
		else:
			(m.multiplayer as SceneMultiplayer).send_bytes(
					MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE)
		print("LUNGE requested at %.2f m (frame %d)" % [Vector2(to.x, to.z).length(), Engine.get_frames_drawn()])
	var pose := c.lunge_fx.pose()
	if pose == &"coil" and _coil_at == Vector3.INF:
		_coil_at = drawn
		print("COIL seen at frame %d, monster drawn at %s" % [Engine.get_frames_drawn(), drawn])
	if pose == &"coil" and not has_meta(&"windup") and Engine.get_frames_drawn() >= _coil_frame():
		set_meta(&"windup", true)
		_shot("windup")
	# Dash: the first frame the drawn body has left its wind-up spot (the client is not told when Active starts).
	if _coil_at != Vector3.INF and drawn != Vector3.INF and drawn.distance_to(_coil_at) > DASH_SEEN_M 			and not has_meta(&"dash"):
		set_meta(&"dash", true)
		_shot("dash")
	if pose == &"hit_stop" and not has_meta(&"hit"):
		set_meta(&"hit", true)
		_shot("hit")
		print("HIT-STOP seen at frame %d" % Engine.get_frames_drawn())
	if pose == &"stumble" and not has_meta(&"miss"):
		set_meta(&"miss", true)
		_shot("miss")
		print("STUMBLE seen at frame %d" % Engine.get_frames_drawn())


## --bot=aim: [drawn frame since start, pitch, press (&"" none), release (&"" none), shot ("" none)].
const AIM_STEPS: Array = [[60, -0.5, &"false_signal", &"", ""], [100, -0.5, &"", &"", "fs_preview"],
	[105, -0.5, &"", &"false_signal", ""], [150, 1.2, &"false_signal", &"", ""], [190, 1.2, &"", &"", "invalid"],
	[195, 1.2, &"", &"false_signal", ""], [220, -0.5, &"blackout", &"", ""], [260, -0.5, &"", &"", "bo_preview"],
	[265, -0.5, &"", &"blackout", ""], [330, -0.5, &"", &"", "bo_dark"]]


func _aim_bot(c: RoundClient) -> void:
	var aim := c.hud.find_child("S7PlacementPreview", false, false) as ShapeshifterAim
	if aim == null:
		return
	if _aim_start < 0:
		_aim_start = Engine.get_frames_drawn()
	var f := Engine.get_frames_drawn() - _aim_start
	for st: Array in AIM_STEPS:
		if f < st[0]:
			c.scripted.pitch = st[1]
			break
		if f != st[0]:
			continue
		if st[2] != &"":
			Input.action_press(st[2])
		if st[3] != &"":
			var p := aim.preview()
			Input.action_release(st[3])
			print("AIM %s released at frame %d: valid %s aim %s point %s volume %s" % [st[3], f, p["valid"], p["aim"],
					p["point"], p["volume"]])
			get_tree().create_timer(1.0).timeout.connect(_print_cooldowns.bind(c))
		if st[4] != "":
			if st[4] != "bo_dark":
				var p := aim.preview()
				print("PREVIEW %s: valid %s aim %s point %s end %s volume %s" % [st[4], p["valid"], p["aim"],
						p["point"], p["end"], p["volume"]])
			_shot(st[4])


func _print_cooldowns(c: RoundClient) -> void:
	var row := PackedStringArray()
	for k: StringName in MonsterHudFeed.ABILITY_KEYS:
		row.append("%s %.1f s" % [k, c.hud_model.cooldown_remaining_s(k)])
	print("COOLDOWNS " + ", ".join(row))


func _coil_frame() -> int:
	if _coil_seen < 0:
		_coil_seen = Engine.get_frames_drawn()
	return _coil_seen + WINDUP_SHOT_FRAMES


## Story scare-events/009 captures (see the class doc).
func _scare_shots() -> void:
	if _shown == null or not _shown.is_spawned() or _shown.scares == null:
		return
	if _args.has("flash-scale"):
		for c in _clients:
			if c.scares != null:
				c.scares.flash_scale = float(_args["flash-scale"])
	var sv := _shown.get_node(^"ScareVisuals") as ScareVisuals
	var wants := String(_args.get("shot-when", "")).split(",", false)
	var vol := String(MapQueries.new(_map).volume_at(_shown.body.global_position))
	if "strobe" in wants and sv.strobe_energy() > _strobe_last:
		print("STROBE_ONSET frame %d energy %.2f" % [Engine.get_frames_drawn(), sv.strobe_energy()])
	if "strobe" in wants:
		_strobe_last = sv.strobe_energy()
	if "strobe" in wants and vol in _shown.lights.presets.beacon_volumes and _shown.body.velocity.length() < 0.05:
		if not has_meta(&"strobe") and sv.strobe_energy() > 0.0:
			set_meta(&"strobe", Engine.get_frames_drawn())
			print("STROBE in %s energy %.2f scale %.2f state %d" % [vol, sv.strobe_energy(),
					_shown.scares.flash_scale, _shown.facility_scare.state()])
			_shot("strobe")
		elif has_meta(&"strobe") and not has_meta(&"between") and Engine.get_frames_drawn() >= int(get_meta(&"strobe")) + 30:
			set_meta(&"between", true)
			print("BETWEEN energy %.2f" % sv.strobe_energy())
			_shot("between")
	if "hallucination" in wants and not has_meta(&"hallucination") and sv.hallucinating():
		set_meta(&"hallucination", true)
		for c in _clients:
			print("HALLUCINATING %s %s" % [c.name, (c.get_node(^"ScareVisuals") as ScareVisuals).hallucinating()])
		_shot("hallucination")
const SCARE_AUDIO_FRAMES := 240
const PEAK_BUSES: Array[StringName] = [&"Master", &"Ambience", &"GameplayCues", &"Scare", &"ScareDuck", &"Stinger",
	&"ScareSFX"]


func _scare_audio(c0: RoundClient, m: RoundClient) -> void:
	if not has_meta(&"scare_sent"):
		set_meta(&"scare_sent", true)
		c0.router.subscribe(&"ScareTriggered", _on_scare_audio)
		(m.multiplayer as SceneMultiplayer).send_bytes(MonsterAbilities.request_packet(
				MonsterAbilities.Ability.BLACKOUT, m.body.global_position), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE)
		print("SCARE-AUDIO blackout requested at %s, frame %d" % [m.body.global_position, Engine.get_frames_drawn()])
	var frame := Engine.get_frames_drawn()
	if _scare_frame < 0 or frame > _scare_frame + SCARE_AUDIO_FRAMES:
		return
	var row := PackedStringArray()
	for bus in PEAK_BUSES:
		var db := AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index(bus), 0)
		_peaks[bus] = maxf(_peaks.get(bus, -INF), db)
		row.append("%s %.1f" % [bus, db])
	print("PEAK +%d duck %.2f stingers %d diegetic %d | %s" % [frame - _scare_frame, c0.scare_audio.duck_level_db(),
			c0.scare_audio.stingers().size(), c0.scare_audio.diegetic().size(), ", ".join(row)])
	if frame == _scare_frame + 3:
		_shot("scare")
	if frame == _scare_frame + SCARE_AUDIO_FRAMES:
		print("PEAK MAX over %d frames: %s" % [SCARE_AUDIO_FRAMES, _peaks])


func _on_scare_audio(_tick: int, payload: Dictionary) -> void:
	if _scare_frame < 0:
		_scare_frame = Engine.get_frames_drawn()
	var cam := _shown.camera.global_transform
	var at: Vector3 = payload.get("origin", Vector3.ZERO)
	print("SCARE %s intensity %s at %s frame %d: bearing %.1f deg, distance %.2f m" % [payload.get("scare"),
			payload.get("intensity"), at, Engine.get_frames_drawn(), TransformPresenter.bearing_deg(cam, at),
			cam.origin.distance_to(at)])


## Story hud-results/005: pulse.png once the shown client's flinch-off pulse is fully in (--no-flinch). With
## --fake-paused, a client-side PROGRESS entry (not from the server: manual capture of the Paused label only)
## is fed to the shown client's bars 2 m ahead of it once it stands, and paused.png is saved 10 frames later.
func _edge_shots() -> void:
	if _shown == null or _shown.edge_cues == null or not _shown.is_spawned():
		return
	if not has_meta(&"pulse"):
		for c in _shown.edge_cues.cues():
			if c.kind == EdgeCues.Kind.PULSE and c.alpha > 0.95:
				set_meta(&"pulse", true)
				_shot("pulse")
	if _args.has("fake-paused") and not has_meta(&"paused") and _shown.predictor.states_received > 60:
		set_meta(&"paused", Engine.get_frames_drawn())
		var ahead := _shown.body.global_position + Basis.from_euler(Vector3(0.0, _shown.head.rotation.y, 0.0)) * Vector3(0.0, 0.8, -2.5)
		for n in _shown.get_children():
			if n is WorldProgressBars:
				n.on_progress(int(_shown.estimated_tick()), {"key": WorldProgress.ACTIVATION_KEY, "at": ahead,
					"progress": 0.4, "rate": 0.0, "paused": true})
	if has_meta(&"paused") and Engine.get_frames_drawn() == int(get_meta(&"paused")) + 10:
		_shot("paused")


## --bot=shifter step: 0 walk and observe, 1 transforming, 2 disguised, 3 tased, 4 done.
var _shifter_step := 0
var _shifter_frame := -1
var _shifter_face: RoundClient


func _shifter_bot(c0: RoundClient) -> void:
	var frame := Engine.get_frames_drawn()
	if _shifter_face == null:
		var best := INF
		for c in _clients:
			if c != c0 and c.is_spawned() and c.body.global_position.distance_to(c0.body.global_position) < best:
				best = c.body.global_position.distance_to(c0.body.global_position)
				_shifter_face = c
		if _shifter_face == null:
			return
		_shifter_frame = frame
		(c0.multiplayer as SceneMultiplayer).send_bytes(MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE),
				1, MultiplayerPeer.TRANSFER_MODE_RELIABLE)
		print("SHIFTER lunge requested; watching %s from %.1f m" % [_shifter_face.name, best])
	var s := _shifter_face
	var d := s.body.global_position - c0.body.global_position
	d.y = 0.0
	c0.scripted.yaw = atan2(-d.x, -d.z)
	c0.scripted.move = Vector2(0, 1) if d.length() > 3.0 and frame > _shifter_frame + 40 else Vector2.ZERO
	var m := c0.hud_model
	var faces := m.faces().filter(func(f: Dictionary) -> bool: return f["survivor"] == s.net.local_player_id)
	if faces.is_empty():
		return
	var face: Dictionary = faces[0]
	match _shifter_step:
		0:
			if face["progress"] >= 0.4 and not has_meta(&"trueform"):
				set_meta(&"trueform", true)
				_shot("trueform")
				print("HUD trueform: lunge %.1f s, face %.2f" % [m.cooldown_remaining_s(&"lunge"), face["progress"]])
			if face["available"] and frame % REQUEST_EVERY == 0:
				(c0.multiplayer as SceneMultiplayer).send_bytes(BorrowedFace.request_packet(s.net.local_player_id), 1,
						MultiplayerPeer.TRANSFER_MODE_RELIABLE)
			if m.transform_progress() >= 0.4:
				_shot("transforming")
				print("HUD transforming: %.2f" % m.transform_progress())
				_shifter_step = 1
		1:
			if c0.predictor.last_own.get("appearance", -1) == s.predictor.last_own.get("appearance", -2):
				_shifter_step = 2
				_shifter_frame = frame
		2:
			if frame == _shifter_frame + 30:
				_shot("disguised")
				print("HUD disguised: form cooldown %.1f s" % m.cooldown_remaining_s(&"form"))
				_shifter_step = 3
				_shifter_frame = frame
		3:
			var back := c0.body.global_position - s.body.global_position
			s.scripted.yaw = atan2(-back.x, -back.z)
			s.scripted.pitch = -0.1
			if frame == _shifter_frame + 10:
				(s.multiplayer as SceneMultiplayer).send_bytes(SurvivorDefense.fire_packet(), 1,
						MultiplayerPeer.TRANSFER_MODE_RELIABLE)
			if m.stun_remaining_s() > 0.0 and not has_meta(&"stunned"):
				set_meta(&"stunned", true)
				_shot("stunned")
				print("HUD stunned: %.1f s" % m.stun_remaining_s())
				_shifter_step = 4


## --bot=ownstate step: 0 hide, 1 hidden then leave, 2 lunged (Seized, then Downed), 3 Downed, 4 spectating.
var _own_step := 0
var _own_frame := -1


func _own_bot(c0: RoundClient) -> void:
	var f := Engine.get_frames_drawn()
	var m := c0.hud_model
	var st := m.hud_state()
	var always := c0.hud.get_node(^"AlwaysOnHud") as AlwaysOnHud
	var own := c0.hud.get_node(^"OwnStateHud") as OwnStateHud
	match _own_step:
		0:
			var feet := c0.body.global_position
			if _target == Vector3.INF:
				var best := INF
				for t in _map.interactables():
					var mk := t as MapMarker
					if mk != null and mk.type == &"hiding" and feet.distance_to(mk.position) < best:
						best = feet.distance_to(mk.position)
						_target = mk.position
			var point := _target + Vector3.UP * _knobs.controller.capsule_height_m * 0.5
			var eye := feet + Vector3.UP * _knobs.controller.eye_height_m
			var flat := Vector2(point.x - eye.x, point.z - eye.z)
			c0.scripted.yaw = atan2(-flat.x, -flat.y)
			c0.scripted.pitch = atan2(point.y - eye.y, flat.length())
			var near := flat.length() < _knobs.objectives.interact_range_m * 0.6
			c0.scripted.move = Vector2.ZERO if near else Vector2(0, 1)
			c0.scripted.interact = near and c0.body.velocity.length() < 0.05
			if m.own_hidden():
				c0.scripted.interact = false
				_own_step = 1
				_own_frame = f
		1:
			if f == _own_frame + 30:
				_shot("hidden")
				print("HUD hidden: state %s prompt '%s' crosshair %s" % [st, c0.interaction.prompt_text(),
						always.crosshair.visible])
			c0.scripted.interact = f > _own_frame + 40
			if not m.own_hidden():
				c0.scripted.interact = false
				_own_step = 2
				print("LEFT the hiding spot at frame %d" % f)
		2:
			_lunge_bot(c0)
			if st == HudModel.STATE_SEIZED and not has_meta(&"seized_at"):
				set_meta(&"seized_at", f)
			if has_meta(&"seized_at") and f == get_meta(&"seized_at") + 20:
				_shot("seized")
				print("HUD seized: word '%s' vignette %.2f z4 '%s'" % [own.word(), own.vignette(), c0.interaction.shown()])
			if st == HudModel.STATE_DOWNED:
				_own_step = 3
				_own_frame = f
		3:
			for o in _clients:
				if o == c0:
					continue
				if o.scripted == null:
					o.scripted = InputFrame.new()
				var away := o.body.global_position - c0.body.global_position
				o.scripted.yaw = atan2(-away.x, -away.z)
				# Stop just past the camp-slow radius: walking on for 10 s left the greybox floors and the watched
				# survivor fell out of the map (BUG-0005 capture, entry y -17400).
				var far := away.length() > _knobs.downing.camp_slow_radius_m + 2.0
				o.scripted.move = Vector2.ZERO if far or f >= _own_frame + 600 else Vector2(0, 1)
			if f == _own_frame + 30:
				_shot("downed")
				print("HUD downed: word '%s' bleed '%s' z4 '%s' crosshair %s" % [own.word(), own.bleed_text(),
						c0.interaction.shown(), always.crosshair.visible])
			if (f - _own_frame) % 300 == 0:
				print("BLEED %.1f s at frame %d" % [m.bleed_out_s(), f])
			if m.spectating():
				_own_step = 4
				_own_frame = f
		4:
			# The client's own SpectatorCamera places the view (BUG-0005); the bot only watches.
			if m.watched() >= 0 and not has_meta(&"spect_at"):
				set_meta(&"spect_at", f)
			if has_meta(&"spect_at") and f == get_meta(&"spect_at") + 30:
				_shot("spectating")
				print("HUD spectating: '%s' watched %d can_act %s z4 '%s'" % [own.spectating_text(), m.watched(),
						c0.ping_hud.can_act(), c0.interaction.shown()])
				print("SPECTATOR camera %s body %s entry %s unacked %d taser %s" % [c0.camera.global_position,
						c0.body.global_position, c0.predictor.last_own.get("pos"), c0.predictor.unacked_count(),
						c0.hud.get_children().filter(func(n: Node) -> bool: return n is TaserCount)[0].visible])
			if has_meta(&"spect_at") and f == get_meta(&"spect_at") + 40:
				get_tree().quit()
## --bot=picker state.
var _picker_step := 0
var _picker_frame := -1


func _picker_bot(c0: RoundClient) -> void:
	var frame := Engine.get_frames_drawn()
	if _shifter_face == null:
		var best := INF
		for c in _clients:
			if c != c0 and c.is_spawned() and c.body.global_position.distance_to(c0.body.global_position) < best:
				best = c.body.global_position.distance_to(c0.body.global_position)
				_shifter_face = c
		if _shifter_face == null:
			return
	var s := _shifter_face
	var d := s.body.global_position - c0.body.global_position
	d.y = 0.0
	c0.scripted.yaw = atan2(-d.x, -d.z)
	c0.scripted.move = Vector2(0, 1) if d.length() > 3.0 and _picker_step == 0 else Vector2.ZERO
	var picker := c0.hud.get_node_or_null(^"FormPicker") as FormPicker
	if picker == null:
		return
	var entries := picker.entries()
	var at := -1
	for i in entries.size():
		if entries[i]["form"] == s.net.local_player_id:
			at = i
	if at < 0:
		return
	match _picker_step:
		0:
			if entries[at]["available"]:
				picker.open()
				picker.aim(Vector2.UP.rotated(TAU * at / entries.size()) * FormPicker.WHEEL_RADIUS_PX)
				_picker_step = 1
				_picker_frame = frame
		1:
			if frame == _picker_frame + 5:
				_shot("picker")
				print("PICKER open: %s, selection %d" % [str(entries), picker.selection()])
			if frame == _picker_frame + 10:
				print("PICKER sent: %s" % picker.close(true))
				_picker_step = 2
		2:
			if c0.predictor.last_own.get("appearance", -1) == s.predictor.last_own.get("appearance", -2):
				_picker_step = 3
				_picker_frame = frame
		3:
			if frame == _picker_frame + 30:
				_shot("disguised")
				print("PICKER disguised: form cooldown %.1f s" % c0.hud_model.cooldown_remaining_s(&"form"))
			if frame == _picker_frame + 35: # after disguised.png is drawn
				picker.open()
				picker.aim(Vector2.UP * FormPicker.WHEEL_RADIUS_PX) # entry 0: the true form
				_picker_step = 4
				_picker_frame = frame
		4:
			if frame == _picker_frame + 5:
				_shot("picker-disguised")
				print("PICKER open disguised: %s" % str(entries))
			if frame == _picker_frame + 10:
				print("PICKER sent true form: %s (cooldown %.1f s)" % [picker.close(true),
						c0.hud_model.cooldown_remaining_s(&"form")])
				_picker_step = 5
		5:
			if c0.interaction.label_text() != "":
				_shot("refused")
				print("PICKER refused: label '%s' at frame %d, transform progress %.2f" % [
						c0.interaction.label_text(), frame, c0.hud_model.transform_progress()])
				_picker_step = 6


const BUDGET_EXPLORE_F := 60
const BUDGET_RUN := 8
const BUDGET_BG := Color(1.0, 0.0, 1.0)
var _hud_only_left := 0
var _hud_only_tag := ""
var _saved_env: Environment


## Story hud-results/010: see the header (--bot=budget).
func _budget_bot(c0: RoundClient) -> void:
	_hud_only_tick(c0)
	if _step_frame < 0:
		_step_frame = Engine.get_frames_drawn()
		_set_reduced_motion(c0, _args.has("reduced-motion"))
	var f := Engine.get_frames_drawn() - _step_frame
	var all := _clients.filter(func(c: RoundClient) -> bool: return c.is_spawned() and not _role(c))
	if _args.has("clock"):
		var left := c0.hud_model.time_remaining_s()
		if left <= 26.0 and not has_meta(&"clock_off"):
			set_meta(&"clock_off", true)
			_set_reduced_motion(c0, false)
			_hud_only(c0, "clock_off", BUDGET_RUN)
		elif left <= 22.0 and not has_meta(&"clock_on"):
			set_meta(&"clock_on", true)
			_set_reduced_motion(c0, true)
			_hud_only(c0, "clock_on", BUDGET_RUN)
		elif left <= 20.0:
			get_tree().quit()
		return
	if f < BUDGET_EXPLORE_F:
		_look(c0)
		return
	if f == BUDGET_EXPLORE_F:
		_budget_shot(c0, "explore")
		return
	if c0.hud_model.phase() != MatchFlow.Phase.EVACUATION:
		return
	if not has_meta(&"evac"):
		set_meta(&"evac", f)
		_hud_only(c0, "evac", BUDGET_RUN)
		var lines := CalloutSet.load_shipped().lines
		for i in all.size():
			(all[i] as RoundClient).callouts.request(lines[i % lines.size()])
		return
	var since: int = f - int(get_meta(&"evac"))
	if since == 10:
		for c: RoundClient in all:
			c.scripted.pitch = -0.2
			c.ping_hud.ping()
	if since < 12 or _hud_only_left > 0:
		return
	_bot(c0)
	var ui := c0.interaction
	if ui.shown() == &"prompt" and not has_meta(&"prompt_run"):
		set_meta(&"prompt_run", true)
		_hud_only(c0, "prompt", BUDGET_RUN)
	if ui.shown() == &"ring" and ui.ring_value() >= 0.5 and not has_meta(&"busy"):
		set_meta(&"busy", true)
		print("BUDGET busy feed=%d markers=%d since_evac=%d" % [c0.ping_hud.feed_lines().size(),
			c0.ping_hud.markers_now().size(), since])
		_budget_shot(c0, "busy")
		set_meta(&"quit_at", Engine.get_frames_drawn() + 20)
	if has_meta(&"quit_at") and Engine.get_frames_drawn() >= int(get_meta(&"quit_at")):
		get_tree().quit()


func _set_reduced_motion(c0: RoundClient, on: bool) -> void:
	c0.set_reduced_motion(on)
	print("BUDGET reduced_motion=%s" % on)


## This frame as <tag>.png and the next one HUD-only as <tag>_hud.png, with <tag>.json of rects.
func _budget_shot(c0: RoundClient, tag: String) -> void:
	_shot(tag)
	var size := get_viewport().get_visible_rect().size
	var font := c0.ping_hud.get_theme_default_font()
	var markers: Array = []
	var named := {}
	var text := {}
	var i := 0
	for m in c0.ping_hud.markers_now():
		var pl := PingCalloutHud.place(c0.camera, m["point"], size, PingCalloutHud.INSET_PX)
		var at: Vector2 = pl[0]
		var tw := font.get_string_size(m["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, PingCalloutHud.MARKER_FONT).x
		var lx := clampf(at.x - tw / 2.0, PingCalloutHud.INSET_PX, size.x - PingCalloutHud.INSET_PX - tw)
		var r := Rect2(at - Vector2(16, 16), Vector2(32, 32)).merge(Rect2(lx - 4, at.y - 16 - 24, tw + 8, 32))
		markers.append([r.position.x, r.position.y, r.size.x, r.size.y])
		named["marker%d_kind%d_shape" % [i, m["kind"]]] = [at.x - 14, at.y - 14, 28, 28]
		text["marker%d_label" % i] = [lx, at.y - 16 - 22, tw, 30]
		i += 1
	var hud := c0.hud.get_node(^"AlwaysOnHud") as AlwaysOnHud
	for box: VBoxContainer in [hud.roster_box, hud.objectives_box]:
		for l: Label in box.get_children():
			if l.visible:
				var gr := l.get_global_rect()
				named["%s:%s" % ["roster" if box == hud.roster_box else "checklist", l.text]] = 					[gr.position.x, gr.position.y, gr.size.x, gr.size.y]
				text["%s:%s" % ["roster" if box == hud.roster_box else "checklist", l.text]] = 					[gr.position.x, gr.position.y, gr.size.x, gr.size.y]
	for l: Label in [hud.clock_label, hud.phase_label]:
		var gr := l.get_global_rect()
		text[l.text] = [gr.position.x, gr.position.y, gr.size.x, gr.size.y]
	var f := FileAccess.open("%s/%s.json" % [_args["shots"], tag], FileAccess.WRITE)
	f.store_string(JSON.stringify({"markers": markers, "named": named, "text": text}, " "))
	f.close()
	print("BUDGET %s rects markers=%d named=%d" % [tag, markers.size(), named.size()])
	_hud_only(c0, tag + "_hud", 1, false)


## Culls the 3D world over a flat BUDGET_BG for `n` drawn frames from the next one, saving each.
func _hud_only(c0: RoundClient, tag: String, n: int, numbered := true) -> void:
	_hud_only_tag = tag if not numbered else tag + "_%02d"
	_hud_only_left = n
	set_meta(&"hud_only_n", n)


func _hud_only_tick(c0: RoundClient) -> void:
	if _hud_only_left <= 0:
		if _saved_env != null or c0.camera.cull_mask == 0:
			c0.camera.cull_mask = 0xFFFFF
			c0.camera.environment = _saved_env
			_saved_env = null
		return
	if c0.camera.cull_mask != 0:
		_saved_env = c0.camera.environment
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = BUDGET_BG
		c0.camera.environment = env
		c0.camera.cull_mask = 0
	var k: int = int(get_meta(&"hud_only_n")) - _hud_only_left
	_shot(_hud_only_tag % k if _hud_only_tag.contains("%") else _hud_only_tag)
	_hud_only_left -= 1
