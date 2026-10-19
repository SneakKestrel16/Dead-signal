# Accessibility Requirements

> **Status**: Draft (all sections authored)
> **Author**: SneakKestrel16 + ux-designer
> **Last Updated**: 2026-10-12
> **Template**: Accessibility Requirements

## Accessibility Tier Definition

### Tier Definitions

| Tier | Core Commitment | Typical Effort |
|------|----------------|----------------|
| **Basic** | Critical player-facing text is readable at standard resolution. No feature requires color discrimination alone. Volume controls exist for music, SFX, and voice independently. The game is completable without photosensitivity risk. | Low — primarily design constraints |
| **Standard** | All of Basic, plus: full input remapping on all platforms, subtitle support with speaker identification, adjustable text size, at least one colorblind mode, and no timed input that cannot be extended or toggled. | Medium — requires dedicated implementation work |
| **Comprehensive** | All of Standard, plus: screen reader support for menus, mono audio option, difficulty assist modes, HUD element repositioning, reduced motion mode, and visual indicators for all gameplay-critical audio. | High — requires platform API integration and significant UI architecture |
| **Exemplary** | All of Comprehensive, plus: full subtitle customization (font, size, color, background, position), high contrast mode, cognitive load assist tools, tactile/haptic alternatives for all audio-only cues, and external third-party accessibility audit. | Very High — requires dedicated accessibility budget and specialist consultation |

### This Project's Commitment

**Target Tier**: Standard (designer decision, 2026-10-12)

**Rationale**: Dead Signal is a first-person PvP horror game for 4–6 players on PC first. Its barriers concentrate in three places: photosensitivity and motion (flashes, flicker, beacons, the camera flinch, head-bob, sprint FOV), motor timing (every objective, rescue and barricade is a timed hold; the dodge is a ~0.43 s reaction window), and hearing (footsteps, the lunge wind-up cue, the transform distortion and voice callouts carry deduction information). Standard's remapping, captions, text size, colourblind support and a toggle for every hold are the baseline a PC multiplayer game is expected to meet. Comprehensive is beyond one developer's capacity, and two of its items break the game: difficulty assists make a 4–6 player match unfair, and visual indicators for all audio would turn footsteps and False Signal fakes into a radar. Dropping to Basic would lose hold toggles and remapping, shutting out players who cannot sustain a held key on every objective.

**Features explicitly in scope (beyond tier baseline)**:
- **Photosensitivity controls** (from Comprehensive and Exemplary): flash intensity scale 0–1, a cap of 3 flashes per second, reduced-flash beacons and pulses, and a non-flashing change at scale 0. Horror flashes are core content; already committed by `scare-events.md` rules 24–25, `research-facility.md` (reduced-flash variants) and ADR-0009 §7.
- **Reduced motion** (from Comprehensive): camera flinch toggle (screen-edge pulse instead), head-bob reduction, sprint FOV widening off. First-person horror with view effects; already committed by `scare-events.md` rule 27 and `first-person-controller.md` Game Feel.
- **Visual indicators for the two deduction-critical monster cues** (a subset of Comprehensive): the lunge wind-up cue and the transform distortion. They are a survivor's only warning of a lunge and of a transform; `borrowed-face.md` already depends on the non-audio distortion cue. Each indicator carries the same range and direction as its audio and nothing more (information parity, `scare-events.md` rule 28).
- **Separate stinger and scare-master volume** (audio granularity beyond Basic), so gameplay cues stay audible while scares are turned down (`scare-events.md` rule 26).

**Features explicitly out of scope**:
- Difficulty and assist modes: a PvP balance conflict.
- Visual indicators for footsteps, interaction sounds and False Signal: they would show information hearing players do not get through walls (inference about competitive fairness; open for playtest, see Open Questions).
- In-world screen reader: no engine support for 3D scene narration; menus are covered under Platform Accessibility API Integration.
- Extended hold durations: hold times are balance values; toggle mode covers the motor need.

Each also appears in Known Intentional Limitations.

---

## Visual Accessibility

In a round, bodies are identified only by character look and colour (`lobby-role-assignment.md` AC-LB-31: no name tags), and a disguise copies the target's colour identity (`borrowed-face.md`). A colourblind survivor who cannot tell C1 from C3 by colour cannot do the core deduction, so character identity must read through silhouette and outfit, with colour secondary. This is a constraint on the art bible.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Minimum text size — menus | Standard | Lobby, settings, results | Not Started | 24 px at 1080p, scaled with resolution. |
| Minimum text size — callout feed and captions | Standard | Callout feed, system messages | Not Started | 28 px at 1080p: PC monitor distance, smaller than the 32 px TV figure (inference). |
| Minimum text size — HUD | Standard | Objective checklist, hold bar label, clock, ping distance | Not Started | 20 px for critical information. |
| Text contrast — UI | Standard | All UI text | Not Started | 4.5:1 body, 3:1 large. The dark horror palette is the risk: opaque or shadowed backing. |
| Text contrast — captions and callout feed | Standard | Feed | Not Started | 7:1 with an opaque backing box by default; scenes are often near-black or strobing. |
| Colourblind support | Standard | Characters C1–C5, ping types, zone stripes, lighting states | Not Started | One red-green palette mode (covers protanopia and deuteranopia) plus a non-colour backup for every colour signal (audit below). Tritanopia is covered by the backups, not a separate mode. |
| Colour-as-only-indicator audit | Basic | All UI and gameplay | Not Started | Table below. |
| UI scaling | Standard | HUD and menus, independent | Not Started | 75–150%. World-space ping markers scale with the HUD. |
| Brightness/gamma | Basic | Global | Not Started | Calibration image at first launch. Darkness is gameplay (Blackout, hiding), so the range is capped: the brightest setting must not make a Blackout volume read as lit (inference; check by screenshot). |
| Photosensitivity warning | Basic | First launch | Not Started | Seizure warning screen before the main menu. |
| Flash intensity scale and flash cap | Standard (elevated) | Scare flashes, flicker, beacons | Not Started | Scale 0–1; ≤ 3 flashes/s at any setting; scale 0 = non-flashing change; reduced-flash beacons (`scare-events.md` rules 24–25, `research-facility.md`, ADR-0009 §6–7). |
| Reduced motion | Standard (elevated) | Camera | Not Started | Flinch toggle (`scare-events.md` rule 27; screen-edge pulse instead), head-bob 0–100%, sprint FOV kick on/off, damage camera-impact shake on/off. Visual only; the server view direction is unaffected except by the flinch. |
| Captions — on/off | Basic | Callouts, PA countdown | Done | Settings row Captions (off) built 2026-10-18; PA lines and the two recording scares ("Speaker: (distorted voice)") caption into the feed (`production/qa/evidence/pa-captions-feed-2026-10-18.png`). The callout feed line is always on: it is a gameplay channel (`pings-and-callouts.md`). Separate captions for PA and scare voices: off by default. |
| Captions — speaker identification | Standard | Callouts | Not Started | The feed shows the displayed identity's name. A fake callout shows the impersonated name: intended (False Signal); captions must never reveal fakes. |
| Visual indicators for monster cues | Standard (elevated) | Lunge wind-up, transform distortion | Not Started | See Auditory Accessibility. |

### Color-as-Only-Indicator Audit

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|----------|-------------|---------------------|-----------------|--------|
| Survivor bodies C1–C5 | Character colour | Who a body is (core deduction) | Distinct silhouette, outfit and head shape per character (art bible constraint) | Not Started |
| Ping markers | Sender's colour | Who pinged | Sender name label on the marker | Not Started |
| Ping types | Red warning | Danger vs location vs item | Distinct icon shape per type | Not Started |
| Callout feed | Sender's colour | Speaker | Name text | Not Started |
| Corridor floor stripes | Blue north, orange south | Which corridor | Painted N / S lettering on floor and walls | Not Started |
| Lighting states | Amber Evacuation, red terminal, green exit open | Round phase, exit open | Alarm audio, PA, HUD phase label, exit door visibly open | Not Started |
| Match clock, final 30 s | Urgent colour | Time nearly up | Ticking audio layer, pulsing scale | Not Started |

---

## Motor Accessibility

Dead Signal's motor load is sustained holds and one reaction window; there is no button mashing and no jump.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Full input remapping | Standard | Every InputMap action (move, sprint, crouch, interact, ping, callout wheel, use item, push-to-talk, flashlight), keyboard/mouse and gamepad independently | Not Started | Mouse buttons bindable to any action; warn on conflict; saved to local user settings. Push-to-talk must be bindable (`technical-preferences.md`). Device checks use event type, never `device == 0` (ADR-0007). |
| Input method switching | Standard | PC | Not Started | Prompts follow the last-used device; no restart. Gamepad support is Partial: every gameplay action reachable, menus may need the mouse (Open Questions). |
| One-hand mode | — | — | Not Committed | Above Standard. Remapping and the toggles below cover most of it; moving and looking at once still needs two hands on keyboard/mouse. |
| Hold-to-press alternatives | Standard | Interaction holds (objectives, rescue, barricade/remove/break, hide, search, backup switch), sprint, crouch, callout wheel | Not Started | A Hold / Toggle setting per group. **Interaction toggle**: first press starts the hold; it continues until a second press, an invalid target or any server cancel. The client keeps sending the interact bit and the server is unchanged (ADR-0008), so toggle gives no gameplay advantage. **Sprint toggle**: ends on stopping or turning more than 45° off facing. **Crouch toggle**: resolves `first-person-controller.md` Open Question "crouch as toggle or hold" as a setting. **Callout wheel**: press to open, press to choose. |
| Rapid input alternatives | Standard | — | N/A | No input needs more than 3 presses per second. |
| Input timing adjustments | Standard | Hold durations, dodge window | Not Offered | Shared PvP balance values (dodge budget 0.43 s, ADR-0003); a per-player multiplier changes the match for everyone else. Toggle mode covers hold endurance. See Known Intentional Limitations. |
| Aim assist | Standard | Taser (5 m), interaction ray | Not Offered | The server applies `stun_aim_tolerance_deg` 10° to everyone equally; per-player assist in mixed-input PvP is a fairness problem. See Known Intentional Limitations. |
| Auto-sprint / movement assists | Standard | Sprint, walk | Not Started | Sprint toggle (above). Auto-run: keeps walking forward with no input until a direction key is pressed; never sprints by itself, so noise stays the player's choice. |
| Platforming / traversal assists | — | — | N/A | No jump, no drops; ramp colliders on every step (ADR-0007). |
| HUD element repositioning | Comprehensive | — | Not Committed | Above tier; HUD scaling is under Visual Accessibility. |

---

## Cognitive Accessibility

A round is a 9-minute online match with no AI and no single-player mode, so pausing and difficulty are not available; the cognitive work is keeping "what next" and "who is who" readable under fear.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Difficulty options | Standard | — | Not Offered | PvP: every rule is shared by 4–6 humans. See Known Intentional Limitations. |
| Pause anywhere | Basic | Menus | Not Offered in rounds | An online round cannot pause. The settings menu opens as an overlay during a round without pausing, and every accessibility setting can be changed there and takes effect at once (they are client-side presentation, `scare-events.md` rule 29; the flinch toggle reaches the server on change). Lobby and results have no time pressure except the 5 s all-Ready countdown, which any player cancels by un-readying (`lobby-role-assignment.md`). |
| Tutorial persistence | Standard | Controls and rules reference | Not Started | A Help page (controls, the hold rule, what each ping type means, what the monster can and cannot copy) reachable from the main menu, the lobby and the in-round overlay. No tutorial system is designed yet (Open Questions). |
| Objective clarity | Standard | Survivor objectives | Not Started | The HUD checklist is always visible, needs zero presses, and comes from server state only (`survivor-objectives.md` rules 7, 27). Discovered points are marked; the phase is shown as text, not only by lighting colour (Visual audit). The shapeshifter's HUD shows its ability cooldowns and the observed list. |
| Visual indicators for audio-only information | Standard | Deduction-critical cues only | Not Started | Scope set in the Tier Definition and listed in the Auditory audit: lunge wind-up and transform distortion get indicators; footsteps and imitable sounds do not. |
| Reading time for UI | Standard | Callout feed, system messages, ping markers | Not Started | Feed lines stay at least 8 s and a scrollback of the last 10 lines opens with one key without pausing play. Join reject reasons do not auto-dismiss. The results screen does not wait for input: it runs `results_duration_s` 20 (`match-flow.md`) and returns to the lobby, where the lobby's Last round view reopens the full results for the rest of the session (`design/ux/results.md`). Ping markers last `ping_lifetime_s` 8 (`pings-and-callouts.md`). |
| Cognitive load documentation | Comprehensive | Per system | Partial | Above tier; tracked per feature in the Per-Feature Accessibility Matrix. |
| Navigation assists | Standard | World navigation | Not Started | Zone signage and N / S corridor lettering (Visual audit); discovered objective points marked on the HUD. No waypoint to undiscovered points: discovery is a rule (`survivor-objectives.md` rule 7). No fast travel (one 60 × 40 m floor). |

---

## Auditory Accessibility

Sound is evidence in this game: footsteps, interaction noise and False Signal fakes are deliberately indistinguishable from real sounds in network data (`monster-abilities.md`). The rule for every visual backup here is **information parity**: it carries the same range, direction and timing as the sound, never more, and never distinguishes real from fake (`scare-events.md` rule 28).

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Subtitles for all spoken dialogue | Basic | Callouts, PA countdown, scare voice lines | Done (2026-10-18; the recordings have no surviving words, so their caption names the sound) | Callouts: the feed line is the caption (always on; the monster receives audio only, as designed). PA and scare voice lines: captions off by default. Proximity voice cannot be captioned (Known Intentional Limitations). |
| Closed captions for gameplay-critical SFX | Standard (elevated, subset) | Lunge wind-up, transform distortion | Not Started | Shown as directional screen-edge indicators (below), not bracket text. Other SFX: see the audit table. |
| Mono audio option | Comprehensive | — | Not Committed | Candidate (Open Questions): cheap, and it only removes direction for the player who picks it. |
| Independent volume controls | Basic | Master, Music, SFX, Voice (callouts), Proximity voice, UI, Stinger, Scare master | Not Started | Stinger and scare master are separate from SFX so gameplay cues stay audible (`scare-events.md` rule 26). 0–100%, default 80%; also in the in-round overlay. |
| Visual representations for directional audio | Standard (elevated, subset) | Lunge wind-up cue (`lunge_cue_radius_m` 20), transform distortion (15 m, directional) | Not Started | Screen-edge indicator toward the source, shown only to players inside the sound's audible range, for the sound's duration. Shape-coded, not colour-only. `borrowed-face.md` already depends on this. |
| Hearing aid compatibility | Standard | All cues in the audit table | Not Started | Every cue that carries information has energy below 4 kHz or a visual backup; checked when the sound palette is authored. |

### Gameplay-Critical SFX Audit

| Sound Effect | What It Communicates | Visual Backup | Caption Required | Status |
|-------------|---------------------|--------------|-----------------|--------|
| Lunge wind-up cue (20 m) | A lunge is coming: dodge | Coil pose if in view; screen-edge indicator otherwise | Yes: indicator | Not Started |
| Transform distortion (15 m) | A transform is happening nearby | Visual warp if in view; screen-edge indicator otherwise | Yes: indicator | Not Started |
| Callout voice line | Teammate (or fake) message | Feed line with name and direction arrow | No: feed is the caption | Not Started |
| Ping tone | New marker | Marker on screen through walls | No | Not Started |
| PA countdown, alarm loop | Round phase | HUD clock and phase label | No | Not Started |
| Shock grunt / stun cry | Someone was tased | Visible stagger on the body | No | Not Started |
| Barricade break | A barricade fell | Door visibly opens; break progress visible | No | Not Started |
| Lunge hit / downing | A survivor is down | Downed marker for living survivors | No | Not Started |
| Footsteps (sprint 20 m, walk 6, crouch 2) | Someone is moving nearby | None | No: intentional (parity with fakes, through walls) | Accepted |
| Fuse install noise (25 m) | A fuse is going in | None beyond sparks in view | No: intentional (same reason) | Accepted |
| False Signal sounds | Fake footsteps, interactions, callouts | None in the world, by design | No: a caption would reveal or amplify a fake | Accepted |
| Long-hide breathing/creak | Someone is hidden here | None | No: intentional; the cue exists only as sound | Accepted |

---

## Platform Accessibility API Integration

PC only (`technical-preferences.md`); the store is not chosen (`game-concept.md` Open Questions). Console and mobile rows are N/A.

| Platform | API / Standard | Features Planned | Status | Notes |
|----------|---------------|-----------------|--------|-------|
| PC (Screen Reader) | AccessKit via Godot `Control` nodes (4.5+) → NVDA / Narrator | Menus, lobby, settings, results built from stock `Control` nodes so AccessKit can expose them | Not Committed | Comprehensive tier. Design constraint taken anyway because it is nearly free: no custom-drawn menu widgets. Source: `docs/engine-reference/godot/modules/ui.md` ("Control nodes work with AccessKit"); which controls and what HUD support exists is NOT SOURCEABLE there (Open Questions). |
| Steam (PC) | Steam Input | Gamepad remapping at system level | Not Started (if Steam) | In-game remapping is still required for keyboard/mouse (Motor). |
| Xbox, PlayStation, iOS, Android | — | — | N/A | Not in scope. |

---

## Per-Feature Accessibility Matrix

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|--------|----------------|---------------|-------------------|------------------|-----------|-------|
| Network Authority & Replication | None | None | None | None | N/A | No player-facing surface; client-declared flinch toggle accepted (`first-person-controller.md` OQ) |
| Lobby & Role Assignment | Character preview colour-coded | Ready toggle only | 5 s countdown | None | Partial | Silhouettes per character; un-ready cancels countdown |
| First-Person Controller & Interaction | Head-bob, sprint FOV, camera effects | Held sprint/crouch/interact; 0.43 s dodge | Hold prompts | Footsteps carry information | Partial | Toggles, reduced motion; dodge window fixed (Limitations) |
| Match Flow & Win Conditions | Phase by lighting colour; urgent clock colour | None | Phase and win rules | PA countdown, alarm | Partial | Phase label, ticking layer, PA captions |
| Survivor Objectives | Progress bars, markers | 1–8 s holds, 15 s zone hold | Checklist, carry state, discovery | Install noise | Partial | Always-on checklist; interaction toggle |
| Downing, Rescue & Elimination | Downed marker | 6 s rescue hold; crawl | Bleed-out and camp rules | "Need rescue" callout | Partial | Marker + feed line; rescue toggle |
| Survivor Defense | Flashlight in dark; shock stagger | Taser aim 5 m; holds for hide/barricade | Immunity and lock rules | Shock grunt, hide cue, break | Partial | No aim assist (Limitations); hide cue audio-only by design |
| Borrowed Face | Identity by look and colour | None | Who is who (core deduction) | Transform distortion | Partial | Silhouette constraint; distortion indicator |
| Monster Abilities | Coil pose; Blackout darkness | Lunge aim and timing | Cooldowns | Lunge wind-up cue; False Signal | Partial | Wind-up indicator; False Signal audio-only by design |
| Pings & Callouts | Marker and sender colour | Wheel hold | Marker types, "(not you)" | Callout voice | Partial | Icons + names; wheel toggle; feed is caption |
| Facility Map | Zone colours, beacons, lighting states | None | Layout, 17 volumes | Zone ambience | Partial | N / S lettering; reduced-flash presets (ADR-0009) |
| Scare Events | Flashes, flicker, strobes | None | Fear and startle | Stingers, scare voices | Partial | Flash scale, ≤ 3/s, flinch toggle, stinger/scare volume |
| HUD & Results Screen | Text size, contrast | None | Information density | None | Not Started | No GDD; must meet Visual minimums |
| Accessibility Options | Settings legibility | Navigable by keyboard and gamepad | Live changes in-round | Volume sliders | Not Started | Owns this document's settings |
| Match Telemetry | None | None | None | None | N/A | Not player-facing |

---

## Accessibility Test Plan

| Feature | Test Method | Test Cases | Pass Criteria | Responsible | Status |
|---------|------------|------------|--------------|-------------|--------|
| Text contrast ratios | Automated contrast check on retained screenshots | HUD, feed, menus in Low Power, Evacuation and Blackout | Body ≥ 4.5:1, large ≥ 3:1, feed ≥ 7:1 | ux-designer | Not Started |
| Colour-only indicators | Coblis on screenshots (protanopia, deuteranopia, tritanopia) | C1–C5 side by side; every ping type; corridor stripes; each lighting state | Every audit row readable without colour | ux-designer | Not Started |
| Flash safety | Frame capture of every scare, beacon and flicker at flash scale 1 and 0 | All scares in the catalogue; Evacuation beacons; Blackout | ≤ 3 flashes/s at scale 1; no luminance flash at scale 0; timing and origin unchanged (`scare-events.md` AC) | qa-tester | Not Started |
| Input remapping | Rebind every action to non-default keys and gamepad | Full round as survivor and as shapeshifter | Every action works; conflicts warned; bindings persist | qa-tester | Not Started |
| Hold toggles | Toggle mode on for every group | Every objective, rescue, barricade, hide, search, backup switch; sprint; crouch; wheel | Every hold completes without a sustained press; server cancel rules unchanged | qa-tester | Not Started |
| Reduced motion | Flinch off, head-bob 0, FOV kick off | Scare flinch, sprint, damage impact | No camera rotation except player input; server view direction unchanged (`first-person-controller.md` AC) | qa-tester | Not Started |
| Cue indicators and parity | Packet and screen check | Lunge wind-up and transform at 0.9× and 1.1× audible range; a False Signal next to a real sound | Indicator only inside range; nothing marks a fake | qa-tester | Not Started |
| Menu screen reader | NVDA on lobby, settings, results | Every interactive element | Announced with a name; reachable by keyboard | ux-designer | Not Started (Not Committed tier) |

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| Difficulty and assist modes | Comprehensive | PvP: rules are shared by every player | Players who need slower pace cannot get it | Toggles, reduced motion, cue indicators |
| Input timing adjustment (hold durations, dodge window) | Standard | Shared balance values (ADR-0003 dodge budget) | Players with slow reaction or limited endurance lose more dodges | Hold toggles; the dodge window is tuned for a ~0.15 s reaction at 100 ms RTT (`monster-abilities.md`) |
| Aim assist | Standard | Mixed-input PvP fairness | Players with tremor miss more taser shots | `stun_aim_tolerance_deg` 10° for everyone |
| Pause in rounds | Basic | Online match | Players who must step away lose the round | Settings overlay without pause; reconnect grace 60 s (`match-flow.md`) |
| Visual backups for footsteps, install noise, False Signal, long-hide cue | Comprehensive | Would expose information hearing players lack, or reveal fakes | Deaf and hard-of-hearing players lose part of the deduction | Lunge and transform indicators; callout feed; markers |
| Captions for proximity voice | Basic | No speech-to-text in scope | Deaf players miss voice chat | Voice is optional and off by default; no rule requires voice (`pings-and-callouts.md`); pings and callouts cover every gameplay message |
| In-world screen reader | Exemplary | No engine support for 3D scene narration | Blind players cannot play rounds | Not mitigable for a first-person horror game; menus use stock `Control` nodes |

---

## Audit History

| Date | Auditor | Type | Scope | Findings Summary | Status |
|------|---------|------|-------|-----------------|--------|
| 2026-10-12 | ux-designer (this session) | Design review | Tier commitment against approved GDDs and ADR-0009 | Standard + elevations committed; colour-only identity of C1–C5 found (art bible constraint); 7 limitations recorded | Open |

---

## External Resources

| Resource | URL | Relevance |
|----------|-----|-----------|
| WCAG 2.1 | https://www.w3.org/TR/WCAG21/ | Contrast ratios, text sizing |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Game-specific checklist |
| Colour Blindness Simulator (Coblis) | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Colourblind screenshot checks |
| CVAA | https://www.fcc.gov/consumers/guides/21st-century-communications-and-video-accessibility-act-cvaa | US rules for games with communication features (proximity voice, callouts) |
| Godot engine reference (AccessKit) | `docs/engine-reference/godot/modules/ui.md` | Pinned 4.7.2 facts on screen reader support |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Player journey map does not exist; author `design/player-journey.md` from `.claude/docs/templates/player-journey.md` to ground first-launch and onboarding needs | SneakKestrel16 | Before HUD spec | Unresolved |
| Which `Control` nodes does AccessKit expose on 4.7.2, and does it cover live HUD text? (`modules/ui.md` says only "Control nodes work with AccessKit") | ux-designer | Before menu implementation | Unresolved: NOT SOURCEABLE in the engine reference |
| Does CVAA apply to proximity voice and callouts for a PC release, and what does it require? | SneakKestrel16 | Before store choice | Unresolved |
| Offer mono audio? Cheap, removes direction only for the player who chooses it | SneakKestrel16 | Before Accessibility Options GDD | Unresolved |
| Gamepad support is Partial: must every menu be gamepad-navigable? | SneakKestrel16 | Before UI ADR | Unresolved |
| No tutorial or onboarding is designed; where does the Help page live and what does first launch teach? | SneakKestrel16 | Before HUD spec | Unresolved |
| Playtest the footstep exclusion: do deaf players report the deduction as unplayable? | SneakKestrel16 | Milestone 5 playtest | Unresolved |
| Gamma cap: what brightest setting still keeps a Blackout volume dark? | ux-designer | With ADR-0009 lighting spike | Unresolved |
