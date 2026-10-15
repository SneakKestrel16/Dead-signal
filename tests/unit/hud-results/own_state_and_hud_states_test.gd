extends GdUnitTestSuite
## Story hud-results/004 (design/ux/hud.md H15, H16, HUD States by Gameplay Context, Information Hierarchy;
## interaction-patterns P11; ADR-0014 §6): the server's SurvivorHudFeed sends each survivor its own life state
## and rescue progress; HudModel holds the own state (life, hidden, shocked, bleed-out, watched survivor) and
## picks the HUD state; OwnStateHud draws the vignette, word, own bleed-out and spectating label and takes Z4;
## the crosshair hides while Downed or hidden; a spectator has no ping or wheel input. Fed with fake messages.

const SERVER_PEER := 1
const OWN := 7
const OTHER := 8
const MONSTER := 9
const DT := 0.05

var _knobs: Knobs
var _router: ClientEventRouter
var _display: MatchDisplay
var _model: HudModel
var _always: AlwaysOnHud
var _interaction: InteractionHud
var _hud: OwnStateHud
var _prompt := {}
## SurvivorHudFeed sources.
var _now := 0
var _life := {}
var _rescue := {}


func before_test() -> void:
	_knobs = Knobs.load_all()
	_router = ClientEventRouter.new()
	_display = MatchDisplay.new(_knobs)
	_model = HudModel.new(_display, _knobs, _router)
	_always = auto_free(AlwaysOnHud.new(_model, OWN))
	add_child(_always)
	_always.size = Vector2(1920, 1080)
	var bar: PredictedHoldBar = auto_free(PredictedHoldBar.new())
	bar.setup(_knobs)
	_prompt = {"text": "Hide", "hold": true}
	_interaction = auto_free(InteractionHud.new(InputGlyphs.new(), InputContextStack.new(), bar, _prompt_of))
	add_child(_interaction)
	_hud = auto_free(OwnStateHud.new(_model, OWN, _interaction))
	add_child(_hud)
	_hud.size = Vector2(1920, 1080)
	_now = 0
	_life = {}
	_rescue = {}


func _prompt_of() -> Dictionary:
	return _prompt


func _deliver(tick: int, entries: Array) -> void:
	var bytes := EventBatch.build(tick, 0, [], [], Vector3.ZERO, null, -1, entries)
	_router.on_packet(SERVER_PEER, bytes)
	_display.receive(bytes)


func _at(tick: int, own_entry_id: int = OWN) -> void:
	_display.receive(SnapshotCodec.encode(tick, [] as Array[Dictionary]))
	_model.on_own_body({"id": own_entry_id, "own": true, "pos": Vector3.ZERO})


func _start() -> void:
	_deliver(100, [[&"RoundPhaseChanged", {"phase": MatchFlow.Phase.INVESTIGATION}]])
	_model.set_survivors({OWN: "Ana", OTHER: "Ben"})
	_at(100)


func _step(seconds: float) -> void:
	for i in roundi(seconds / DT):
		_hud.step(DT)
		_interaction.step(DT)
	_always.refresh()


# --- SurvivorHudFeed (server, per-peer projection) ---

func _feed() -> SurvivorHudFeed:
	return SurvivorHudFeed.new([OWN, OTHER] as Array[int], func() -> int: return _now,
			func(p: int) -> int: return _life.get(p, Downing.LifeState.HEALTHY),
			func(p: int) -> float: return _rescue.get(p, 0.0))


func test_feed_sends_a_survivor_its_own_life_state_on_change_only() -> void:
	var f := _feed()
	_now = 1
	assert_array(f.entries(OWN)).is_empty() # Healthy, as a client assumes
	_now = 2
	_life[OWN] = Downing.LifeState.SEIZED
	assert_array(f.entries(OWN)).is_equal([[EventBatch.OWN_LIFE, {"life": Downing.LifeState.SEIZED, "rescue_s": 0.0}]])
	assert_array(f.entries(OTHER)).is_empty()
	assert_array(f.entries(MONSTER)).is_empty()
	# A spectator's stream is projected as the watched survivor in the same tick: it gets the same entry.
	assert_int(f.entries(OWN).size()).is_equal(1)
	_now = 3
	assert_array(f.entries(OWN)).is_empty()


func test_feed_sends_rescue_progress_in_tenths_and_the_full_state_on_a_rejoin() -> void:
	var f := _feed()
	_life[OWN] = Downing.LifeState.DOWNED
	_now = 1
	f.entries(OWN)
	_rescue[OWN] = 1.04
	_now = 2
	assert_array(f.entries(OWN)).is_equal([[EventBatch.OWN_LIFE, {"life": Downing.LifeState.DOWNED, "rescue_s": 1.0}]])
	_rescue[OWN] = 1.02 # same tenth: nothing new
	_now = 3
	assert_array(f.entries(OWN)).is_empty()
	assert_array(f.entries(OWN, true)).is_equal(
			[[EventBatch.OWN_LIFE, {"life": Downing.LifeState.DOWNED, "rescue_s": 1.0}]])
	assert_array(f.entries(MONSTER, true)).is_empty()


# --- HudModel own state ---

func test_model_hud_state_follows_the_server_entries() -> void:
	_start()
	assert_str(_model.hud_state()).is_equal("")
	_deliver(101, [[EventBatch.HIDING, {"spot": 3}]])
	assert_str(_model.hud_state()).is_equal("hidden")
	assert_bool(_model.own_hidden()).is_true()
	_deliver(102, [[EventBatch.HIDING, {"spot": -1}]])
	_deliver(103, [[&"PlayerShocked", {"own": true}]])
	_at(103)
	assert_str(_model.hud_state()).is_equal("shocked")
	_at(103 + _knobs.ticks(_knobs.defense.stun_root_s))
	assert_str(_model.hud_state()).is_equal("")
	_deliver(200, [[EventBatch.OWN_LIFE, {"life": Downing.LifeState.SEIZED, "rescue_s": 0.0}]])
	assert_str(_model.hud_state()).is_equal("seized")
	_deliver(210, [[EventBatch.OWN_LIFE, {"life": Downing.LifeState.DOWNED, "rescue_s": 0.0}]])
	assert_str(_model.hud_state()).is_equal("downed")
	_deliver(211, [[EventBatch.OWN_LIFE, {"life": "bad", "rescue_s": 0.0}]]) # bad shape: ignored
	assert_str(_model.hud_state()).is_equal("downed")


func test_model_bleed_out_runs_from_the_down_and_follows_the_ring_rate() -> void:
	_start()
	var hz := _knobs.net.sim_tick_hz
	_deliver(200, [[&"SurvivorDowned", {"survivor": OWN, "bleed_out_s": 30.0}],
			[EventBatch.OWN_LIFE, {"life": Downing.LifeState.DOWNED, "rescue_s": 0.0}]])
	_at(200 + hz * 2)
	assert_float(_model.bleed_out_s()).is_equal_approx(28.0, 0.01)
	_deliver(200 + hz * 2, [[EventBatch.BLEED_RING, {"survivor": OWN, "remaining_s": 28.0, "rate": 0.0}],
			[EventBatch.OWN_LIFE, {"life": Downing.LifeState.DOWNED, "rescue_s": 1.5}]])
	_at(200 + hz * 5)
	assert_float(_model.bleed_out_s()).is_equal_approx(28.0, 0.01) # paused by the rescue
	assert_float(_model.rescue_s()).is_equal(1.5)
	_deliver(200 + hz * 5, [[EventBatch.BLEED_RING, {"survivor": OTHER, "remaining_s": 1.0, "rate": 1.0}]])
	assert_float(_model.bleed_out_s()).is_equal_approx(28.0, 0.01) # another survivor's ring
	_deliver(200 + hz * 6, [[&"SurvivorRescued", {"survivor": OWN}],
			[EventBatch.OWN_LIFE, {"life": Downing.LifeState.HEALTHY, "rescue_s": 0.0}]])
	assert_float(_model.bleed_out_s()).is_equal(-1.0)


func test_model_spectating_when_the_own_entry_is_another_survivor_or_own_is_out() -> void:
	_start()
	assert_bool(_model.spectating()).is_false()
	_deliver(300, [[&"SurvivorEliminated", {"survivor": OWN, "reason": 0}]])
	assert_bool(_model.spectating()).is_true()
	assert_int(_model.watched()).is_equal(-1)
	_at(301, OTHER)
	assert_int(_model.watched()).is_equal(OTHER)
	# The watched survivor's own entries reach the spectator; spectating still wins.
	_deliver(302, [[EventBatch.OWN_LIFE, {"life": Downing.LifeState.DOWNED, "rescue_s": 0.0}]])
	assert_str(_model.hud_state()).is_equal("spectating")


# --- OwnStateHud and the other widgets per state (hud.md HUD States) ---

func test_downed_shows_vignette_word_and_bleed_out_in_z4_and_keeps_roster_and_checklist() -> void:
	_start()
	_step(0.1)
	assert_str(_interaction.shown()).is_equal("prompt")
	_deliver(200, [[&"SurvivorDowned", {"survivor": OWN, "bleed_out_s": 30.0}],
			[EventBatch.OWN_LIFE, {"life": Downing.LifeState.DOWNED, "rescue_s": 0.0}]])
	_at(200)
	_step(0.3)
	assert_str(_hud.word()).is_equal("Downed")
	assert_float(_hud.vignette()).is_equal(1.0)
	assert_str(_hud.bleed_text()).is_equal("30 s")
	assert_str(_interaction.shown()).is_equal("") # bleed-out replaces the prompt
	assert_bool(_always.crosshair.visible).is_false()
	assert_bool(_always.roster_plate.visible).is_true()
	assert_bool(_always.objectives_plate.visible).is_true()
	_deliver(201, [[EventBatch.OWN_LIFE, {"life": Downing.LifeState.DOWNED, "rescue_s": 2.0}]])
	_step(0.05)
	assert_float(_hud.rescue_fill()).is_equal_approx(2.0 / _knobs.downing.rescue_duration_s, 0.001)


func test_seized_shows_vignette_and_word_hides_prompt_and_ring_keeps_crosshair() -> void:
	_start()
	_deliver(200, [[EventBatch.OWN_LIFE, {"life": Downing.LifeState.SEIZED, "rescue_s": 0.0}]])
	_step(0.3)
	assert_str(_hud.word()).is_equal("Seized")
	assert_str(_interaction.shown()).is_equal("")
	assert_str(_hud.bleed_text()).is_equal("")
	assert_bool(_always.crosshair.visible).is_true()
	assert_str(_hud.spectating_text()).is_equal("")


func test_hidden_hides_crosshair_and_prompt_reads_leave_without_vignette() -> void:
	_start()
	_deliver(200, [[EventBatch.HIDING, {"spot": 2}]])
	_step(0.3)
	assert_bool(_always.crosshair.visible).is_false()
	assert_str(_interaction.shown()).is_equal("prompt")
	assert_str(_interaction.prompt_text()).contains("Leave")
	assert_str(_interaction.prompt_text()).not_contains("Hide")
	assert_str(_hud.word()).is_equal("")
	assert_float(_hud.vignette()).is_equal(0.0)
	_deliver(201, [[EventBatch.HIDING, {"spot": -1}]])
	_step(0.1)
	assert_str(_interaction.prompt_text()).contains("Hide")


func test_shocked_shows_word_and_jitter_jitter_off_with_reduced_motion() -> void:
	_start()
	_deliver(200, [[&"PlayerShocked", {"own": true}]])
	_at(200)
	_step(0.3)
	assert_str(_hud.word()).is_equal("Shocked")
	assert_str(_interaction.shown()).is_equal("prompt") # shocked keeps the prompt (state table: no row change)
	_hud.reduced_motion = true
	_step(0.05)
	assert_bool(_hud.jitter().is_zero_approx()).is_true()


func test_vignette_takes_250_ms_and_cuts_with_reduced_motion() -> void:
	_start()
	_deliver(200, [[EventBatch.OWN_LIFE, {"life": Downing.LifeState.SEIZED, "rescue_s": 0.0}]])
	_step(0.1)
	assert_float(_hud.vignette()).is_equal_approx(0.1 / OwnStateHud.TRANSITION_S, 0.01)
	_step(0.15)
	assert_float(_hud.vignette()).is_equal_approx(1.0, 0.01)
	_hud.reduced_motion = true
	_deliver(201, [[EventBatch.OWN_LIFE, {"life": Downing.LifeState.HEALTHY, "rescue_s": 0.0}]])
	_step(0.05)
	assert_float(_hud.vignette()).is_equal(0.0)


func test_spectating_shows_label_roster_clock_objectives_and_no_prompt_ping_or_wheel() -> void:
	_start()
	_deliver(300, [[&"SurvivorEliminated", {"survivor": OWN, "reason": 0}]])
	_at(301, OTHER)
	_step(0.3)
	assert_str(_hud.spectating_text()).is_equal("Spectating: Ben")
	assert_str(_hud.word()).is_equal("")
	assert_str(_interaction.shown()).is_equal("")
	assert_bool(_always.crosshair.visible).is_false()
	for c: Control in [_always.roster_plate, _always.clock_plate, _always.objectives_plate]:
		assert_bool(c.visible).is_true()
	var contexts := InputContextStack.new()
	var ping_hud: PingCalloutHud = auto_free(PingCalloutHud.new(_knobs, PingReceiver.new(_router), _model,
			CalloutReceiver.new(_router), contexts, null, null, {} as Dictionary[int, Node3D],
			func(_h: int) -> Dictionary: return {}, func() -> float: return 301.0,
			func() -> int: return -1, func() -> int: return 1, null))
	assert_bool(ping_hud.can_act()).is_false()
	_model.own_id = OTHER # the same model for a survivor still in the round
	assert_bool(ping_hud.can_act()).is_true()


func test_every_own_state_control_ignores_focus_and_mouse() -> void:
	assert_int(_hud.focus_mode).is_equal(Control.FOCUS_NONE)
	assert_int(_hud.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(_hud.get_child_count()).is_equal(0)
