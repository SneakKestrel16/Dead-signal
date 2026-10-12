# Scare Events

> **Status**: Approved
> **Author**: SneakKestrel16
> **Last Updated**: 2026-10-12 (cross-review W13: slammed door presentation only; earlier: re-review: reveal rows merged, Low → Emergency transition; fourth cross-review W2: alarm on install completion; W3: a running flinch ends at a wind-up; design review: any player fires location triggers, no flinch near a wind-up, intensity per scare, gating state updates; earlier same day cross-review B1–B3)
> **Last Verified**: 2026-10-11
> **Implements Pillar**: Fair Fear, Human Deception

## Summary

Scare Events is the authored horror presentation layer: jumpscares, lighting states and scare audio. It plays scares from three sources (player-triggered, environment-triggered, deception-triggered), spaces them with authored cooldowns, scopes each one as a shared event or a single-client hallucination, and guarantees that no scare takes control away long enough to guarantee a hit. Every scare is traceable to a human action or to the authored round script; there are no AI threats.

> **Quick reference** — Layer: `Presentation` · Priority: `Vertical Slice` · Key deps: `Monster Abilities, Borrowed Face, Facility Map, Match Flow & Win Conditions, Network Authority & Replication`

## Overview

Dead Signal's horror comes from people, so Scare Events does not invent threats. It dresses up what humans do (a monster bursting through a door, a disguise dropping, a Blackout) and what the authored round script does (rising unease in Investigation, emergency mode in Evacuation). Each scare is a named, authored entry with a source, a scope, an intensity class and a cooldown. The server decides when a scare fires and who receives it, and broadcasts a `ScareTriggered` event; clients only present it. Scares carry useful directional information, are throttled so they do not become noise, and expose hooks for reduced flash and reduced volume.

## Player Fantasy

Survivor: "That made me jump, and it told me something: the sound came from the left, the lights died in Zone B, she wasn't who I thought." Never: "I got frozen by a cutscene and died." Shapeshifter: "My reveal lands like a film moment, and it was my timing that made it work."

## Detailed Design

### Core Rules

**Authority and traceability**

1. The server decides every scare: whether its trigger is valid, whether cooldowns allow it, its intensity, and its recipients. It then sends `ScareTriggered` (scare_id, scope, source, origin, intensity, recipients). Clients never trigger a scare that another client sees.
1a. `source` and any player identity (the player whose action caused the scare) are server-only fields. The server uses them for gating (Formulas) and telemetry and strips them from every `ScareTriggered` sent to a survivor client, so a scare never names or locates the shapeshifter player (designer decision, 2026-10-12, cross-review B3).
2. Every scare has a **source** field, one of **(proposed)**:
   - `Monster` — caused by the shapeshifter player's action (Blackout, reveal, door burst, lunge).
   - `Survivor` — caused by a player's action at an authored trigger (installing a fuse, entering an authored room, viewing a surveillance monitor) (cross-review B1: "running through a glass partition area" and "opening a sealed room" cut; neither exists on the map).
   - `RoundScript` — fired by the authored round script on a phase change or objective event.
2a. **Location triggers ignore who the player is.** Entering an authored room and viewing a surveillance monitor fire for any player, including the shapeshifter in any form, and are always gated as `Survivor` source. A disguised shapeshifter therefore triggers exactly what a survivor would, so a missing or extra scare is never a tell (design review 2026-10-12, **proposed**). Fuse install differs only because a disguised shapeshifter cannot really install (Survivor Objectives rules 25–26).
3. Nothing else may fire a scare. There is no free-running ambient timer, no creature, no AI.
4. **No scare is a threat by itself.** Scares never deal damage, down, stun, slow, block a route permanently, change objective state or move a player. Environment scares are presentation; the only thing that can hurt a survivor is the monster player, validated by the server through Monster Abilities.
4a. **False Signal never produces a scare.** It has no scare entry and never emits `ScareTriggered`, so its fake callouts and sounds reach survivor clients exactly as a real callout or sound does (Pings & Callouts rule 27, Monster Abilities rule 15) (designer decision, 2026-10-12, cross-review B3).

**The three sources**

| Scare | Category | Source | Scope | Intensity **(proposed)** | Owner of the trigger |
|---|---|---|---|---|---|
| Transformation reveal (monster drops disguise; this is also the "disguised teammate transforms" deception scare, one entry per `FormChanged`) | Player-triggered | Monster | Shared | Major | Borrowed Face |
| Door burst (monster breaks a barricade) | Player-triggered | Monster | Shared | Major | Survivor Defense (barricade break) |
| Ambush lunge (wind-up passes the ambush test, rule 5a) | Player-triggered | Monster | Shared | Major, never a flinch (rule 14) | Monster Abilities (Predatory Lunge) |
| Blackout (lights die) | Environment | Monster | Shared | Major | Monster Abilities (Blackout) |
| Slammed door | Environment | RoundScript, at a Facility Map door scare anchor (design review 2026-10-12: Survivor trigger cut; none was defined and the Facility Map anchors are RoundScript only) | Shared | Minor | This system |
| Glass break | Environment | RoundScript, at a Facility Map glass scare anchor **(proposed)** (cross-review B1: trip-point and monster-through-glass triggers cut) | Shared | Major | This system |
| Alarm | Environment | Survivor (fuse install completed, `ObjectiveProgressChanged`; the install-start noise is Survivor Objectives rule 16's own cue) or RoundScript (Evacuation) (designer decision, 2026-10-12, cross-review W2 (2026-10-12b)) | Shared | Minor | Survivor Objectives / Match Flow |
| Unsettling recording | Environment | Survivor (any player enters authored room, rule 2a) or RoundScript **(proposed)** | Shared | Minor | This system |
| Impossible surveillance image | Deception | Survivor (any player views a monitor, rule 2a) + RoundScript selects **(proposed)** | Single-client | Minor | This system |

5. Player-triggered scares are a presentation layer on top of the gameplay cue. The gameplay cue itself (transformation audio distortion, lunge wind-up and audible cue, barricade break sound) is owned by its system and is **never** suppressed, delayed or reduced by any rule here.
5a. **Ambush test** (cross-review B1): when a Predatory Lunge wind-up starts (`AbilityUsed`), the server runs the test for each survivor within `lunge_cue_radius_m` (Monster Abilities). It passes for that survivor if the monster stands in a lighting volume (Facility Map) that is blacked out, or if that survivor has had no line of sight to the monster's chest (the same unobstructed chest-to-chest test as Monster Abilities rule 7, view direction ignored) for at least `ambush_unseen_s` **(proposed)**. The server keeps one last-seen time per survivor for the monster, not a history per volume (design review 2026-10-12). The ambush lunge scare goes only to survivors for whom it passes; otherwise the lunge plays only its own gameplay cue.
6. RoundScript environment scares are drawn from authored lists per phase and zone, fire only at authored trigger points, and are limited by the phase budget in Formulas **(proposed)**. They exist to raise tension between human encounters, not to imitate the monster: a RoundScript scare may not produce footsteps, a teammate voice, a ping or a callout **(proposed)**. Those are only produced by humans, so a survivor who hears a teammate voice knows a human (teammate or monster) caused it.
7. A RoundScript slammed door is presentation only: the door plays a slam sound and a shudder at its anchor, but its real open or closed state never changes, so it never blocks a lunge, line of sight, a ping or a route (designer decision, 2026-10-12, cross-review W13; rule 4).

**Cooldowns and repeats** (server-side, per recipient client unless noted)

8. Each scare has an intensity class: **Major** (stinger + flash or camera reaction) or **Minor** (positional sound, light flicker) **(proposed)**.
9. After a client receives a Major scare, further Major scares for that client within `major_scare_cooldown_s` are **reduced** to their Minor variant (sound kept, stinger and flash dropped) **(proposed)**.
10. RoundScript and Survivor-source scares are **blocked** entirely for a client during `major_scare_cooldown_s` after a Major scare, and blocked during `minor_scare_cooldown_s` after any scare **(proposed)**. Monster-source scares are never blocked (rule 5), only reduced.
11. The same scare_id cannot fire again at the same authored location within `same_scare_repeat_block_s` **(proposed)**. Authored "once per round" scares (e.g. a specific recording) fire at most once.
12. A single-client hallucination is limited to `hallucination_max_per_client` per round **(proposed)**.

**Control-loss limit**

13. Scares never take away movement, look, interaction or stun-item input, with one exception: a Major scare may apply a camera flinch (involuntary view nudge, **the single view rotation `first-person-controller.md` rule 7 sanctions**; every other camera effect in the game is a visual offset only). The flinch works as follows (designer decision, 2026-10-12, cross-review 12e): the camera flinch toggle (rule 27) is a per-player flag the server knows (Accessibility Options owns the setting; the client sends it on join and on change). With the toggle off the server applies **no** rotation and only the screen-edge pulse plays. With it on, the nudge is a server-held yaw/pitch offset added to the yaw and pitch the client sends (Controller rule 9); it ramps in over at most `scare_max_control_loss_s` = 0.3 s **(proposed)** and is then held, so the view does not return. The client applies the same offset to its own view, so the server's view direction and aim ray agree with what the player sees. During the ramp the player can still move and use a stun item. The offset is written into the Controller's view-offset input (systems-index state row; Controller rules 7 and 9). Size (designer decision, 2026-10-12, cross-review 12g): the flinch target is capped at `flinch_max_angle_deg` = 10 degrees **(proposed placeholder, inferred; safe range to be set in the M5 playtest)** toward the origin. Lifecycle (designer decision, 2026-10-12, cross-review 12f): a new flinch **replaces** the held offset (no stacking; the new ramp starts from the current offset toward the new target, within 0.3 s, and the view rotates by at most `flinch_max_angle_deg` in total, not twice that); **the Controller** (not Scare Events) resets the offset to 0 at round end, on the player becoming Downed, Hidden or Seized, on reconnect (the server discards it and the client starts fresh) and when the flinch toggle is switched off while an offset is held (designer decision, 2026-10-12, cross-review 12g). Scare Events only writes new flinches. A reset is a re-baseline, not a visible rotation: the current view direction becomes the new baseline, so nothing snaps back.
14. Flinch never fires on a survivor within `lunge_cue_radius_m` of a monster in lunge wind-up or Active (Monster Abilities rules 5–6); any Major scare reaching that survivor then plays without its flinch, and a flinch already running is cancelled when such a wind-up starts: it **freezes where it is**, the held offset stays and nothing reverts, since a revert would be a second rotation (fourth cross-review W3; designer decision, 2026-10-12, cross-review 12f). The ambush lunge scare is therefore stinger only, so a forced view nudge never spoils a dodge (design review 2026-10-12, **proposed**). The flinch duration must also stay shorter than the lunge wind-up owned by Monster Abilities. If a future scare needs longer control loss, it must be cut (Fair Fear design test).
15. No scare plays a non-skippable animation, forced camera move or full-screen overlay that hides the monster.

**Directional, informative audio**

16. Every diegetic scare sound plays from its true origin in the world (the door that slammed, the room that went dark, the speaker that played). Its direction and distance must be correct for the listener.
17. Non-diegetic stingers are allowed only on Major scares, play at most `stinger_max_db_rel` above the ambient bed **(proposed)**, and never cover the origin sound.
18. Priority (ducking): gameplay cues (lunge wind-up, transform distortion, stun, downed cries, fuse install noise (Survivor Objectives rule 16), barricade break, callouts and pings) are never masked by scare audio; scare audio ducks under them **(proposed)**. Stun ducking triggers on `PlayerShocked` or `MonsterStunned` (true-form stun) on survivor clients and on `MonsterStunned` on the monster's client, because survivor clients never receive `MonsterStunned` while the monster is disguised (Survivor Defense rule 1).

**Shared vs. individual scope**

19. **Shared** scares go to every client that is relevant: inside the affected room/zone, within the sound's audible range, or with line of sight to the effect **(proposed: relevance = audible range or line of sight)**. Each scare entry carries its own authored audible range (data). All recipients see the same scare_id at the same origin.
20. **Single-client** scares (hallucinations) are sent only to the intended client. No other client receives any data about them, including the monster.
21. Hallucinations are presentation only and must not: show a fake teammate, ping, callout or pickup; misrepresent objective state or the round timer; or show the monster's real position **(proposed)**. They unsettle; they do not inform or misinform about gameplay state.

**Phase lighting/audio states**

22. On `RoundPhaseChanged` the server sets the facility scare state; all clients present it. The Facility Map owns per-volume lighting state (`research-facility.md` Lighting States): this system only requests those states and adds flicker and stingers on top (designer decision, 2026-10-12, cross-review B2).

| State | When | Lighting | Audio bed | Scare budget |
|---|---|---|---|---|
| Infiltration – Low | Round start until `RoundPhaseChanged` (normally 0:00–2:00) | Facility starts in the Facility Map's **Low Power** lighting state: dim, stable work lights, Zone B dimmest, fuse boxes and terminal dark **(proposed; matches `research-facility.md`)** | Quiet hum, distant facility noise | Low (few RoundScript scares) **(proposed)** |
| Investigation – Rising | Until `RoundPhaseChanged` to Evacuation (normally 2:00–7:00) | Facility Map's current state; this system adds flicker whose frequency rises over the phase **(proposed)** | Bed intensity rises with time | Medium, increasing |
| Power Restored (overlay) | Both fuses installed (`ObjectiveProgressChanged`) **(proposed)** | Leaves Low Power: main lights up in Zones B and C (Facility Map's Power Restored state) | Machinery up; alarm on install | Unchanged |
| Evacuation – Emergency | `RoundPhaseChanged` to Evacuation: 7:00, or earlier when the terminal is armed (Match Flow rule 6) | Facility Map's Evacuation state: overheads ~50%, rotating amber beacons, faint emergency floor lights (designer decision, 2026-10-12, cross-review B2) | Alarm loop, PA countdown | High, but per-client cooldowns still apply |
| Blackout (local overlay) | Monster Blackout, `blackout_duration_s` | Facility Map's Blackout (local) state: local lights off; emergency lights faintly visible | Power-down sound at origin | n/a |
| Results | Round end | Facility Map's Reset state: every volume back to round-start Low Power (designer decision, 2026-10-12, cross-review B2) | Music | None |

23. Emergency lighting must keep landmarks and the exit readable (Readable Objectives); Facility Map owns where emergency lights are.

**Accessibility hooks** (Accessibility Options owns the settings UI; this system must expose):

24. **Flash intensity scale** (0–1) applied to all scare flashes and light flicker; at the lowest setting, flashes are replaced by a non-flashing light change.
25. **Flash rate cap**: no scare may produce more than 3 luminance flashes per second at any setting **(proposed)**.
26. **Stinger volume scale** and **scare master volume scale** (0–1), separate from game master volume, so gameplay cues stay audible.
27. **Camera flinch toggle**: when off, rule 13's flinch is replaced by a screen-edge pulse and the server applies no rotation: that player's server view direction never changes during a scare. The flag is held per player by the server (rule 13) (designer decision, 2026-10-12, cross-review 12e).
28. **Information parity**: reduced settings change intensity, never information. Direction, origin and timing of every scare stay the same.
29. All hooks are client-side presentation settings; they never change server timing, cooldowns or recipients.

### States and Transitions

| State (facility scare state) | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| Low | Round start (Infiltration) | `RoundPhaseChanged` → Investigation (Rising), or → Evacuation (Emergency) when the terminal is armed early (Match Flow rule 6) | Low RoundScript budget |
| Rising | `RoundPhaseChanged` → Investigation | `RoundPhaseChanged` → Evacuation | Budget and flicker rise with time |
| Emergency | `RoundPhaseChanged` → Evacuation | Round end | Emergency lights, alarm bed |
| Results | Round end | Next round | No scares |

Per-client scare cooldown state: Ready → Major cooldown (`major_scare_cooldown_s`) → Ready; Ready → Minor cooldown (`minor_scare_cooldown_s`) → Ready. Cooldowns reset at round start.

### Interactions with Other Systems

- **Match Flow & Win Conditions**: `RoundPhaseChanged` drives the facility scare state.
- **Monster Abilities**: Blackout and Predatory Lunge send scare triggers (source Monster) through `AbilityUsed` after the server validates the ability; False Signal sends none (rule 4a); lunge wind-up timing bounds the flinch rule.
- **Borrowed Face**: `FormChanged` into true form triggers the reveal scare for survivors within `reveal_radius_m` (10 m, owned by Borrowed Face rule 15) with line of sight.
- **Survivor Defense**: barricade breaks trigger door burst; stun use is never blocked by scares.
- **First-Person Controller & Interaction**: the camera flinch (rules 13-14) is the single sanctioned view rotation in Controller rule 7; the server holds it as a yaw/pitch offset added to the client's view angles, so the server's view direction follows it, and only for players whose flinch toggle is on (designer decision, 2026-10-12, cross-review 12d and 12e). Scare Events writes new flinches into the Controller's view-offset input (systems-index state row) and the Controller performs every reset; the Controller does not depend on Scare Events (cross-review 12f). Scares otherwise never move or lock movement or look.
- **Survivor Objectives**: fuse install triggers an alarm; both fuses installed triggers Power Restored.
- **Facility Map**: owns per-volume lighting state (rule 22); scare anchors (doors, glass), recording speakers, surveillance monitors, emergency lights.
- **Pings & Callouts**: callouts and pings outrank scare audio.
- **Accessibility Options**: consumes the hooks in rules 24–29.
- **Network Authority & Replication**: carries `ScareTriggered` with scope.
- **Match Telemetry**: logs scare_id, source, recipients, reduced/blocked counts.

## Formulas

### Scare gating (per recipient)

```
if source == Monster:
    deliver; if Major and now - last_major < major_scare_cooldown_s: deliver as Minor
else:
    block if now - last_major < major_scare_cooldown_s
    block if now - last_any   < minor_scare_cooldown_s
    block if now - last_fire[scare_id, location] < same_scare_repeat_block_s
    block if source == RoundScript and phase_budget_used >= phase_budget[phase]
    block if source == RoundScript and the scare's volume is under Blackout

on delivery (any source):
    last_any = now
    if delivered as Major: last_major = now     // a reduced Minor does not reset it
    last_fire[scare_id, location] = now
    if source == RoundScript: phase_budget_used += 1   // reset on RoundPhaseChanged
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| major_scare_cooldown_s | float | 30–90 | data | Proposed 45 |
| minor_scare_cooldown_s | float | 5–20 | data | Proposed 10 |
| same_scare_repeat_block_s | float | 60–540 | data | Proposed 120 |
| phase_budget | int per phase | 0–12 | data | RoundScript scares per client: Low 2, Rising 6, Emergency 4 (proposed). Survivor-source scares are not budgeted; once-per-round and repeat blocks bound them |

**Expected output**: at most one Major scare per client per 45 s from non-monster sources, so at most ~12 per 540 s round in the worst case; the budget caps RoundScript scares at 12 per client. **Example**: a survivor gets a door burst (Monster, Major) at 3:00; a RoundScript recording at 3:20 is blocked; the monster reveals at 3:30 and it plays as Minor (distortion and sound, no stinger); at 3:46 a RoundScript glass break is allowed.

### Control-loss bound

```
flinch_s = min(authored_flinch_s, scare_max_control_loss_s)   // 0.3 s proposed
require scare_max_control_loss_s < lunge wind-up (Monster Abilities)
```

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|---|---|---|
| Monster reveals during a client's Major cooldown | Reveal plays as Minor; transform distortion cue unchanged | Gameplay cues are never suppressed |
| Blackout and a RoundScript flicker in the same room | Blackout wins; RoundScript scare blocked for that room for the duration | Avoids stacking; human action is the clearer signal |
| Survivor triggers an alarm while another is mid-flinch | Each client gated independently | Cooldowns are per client |
| A second Major flinch arrives while an offset is held or ramping | The new flinch replaces the held offset; the ramp starts from the current offset | No stacking, so the offset is bounded by `flinch_max_angle_deg`, and the replacing ramp rotates the view by at most that amount in total. When both caps cannot be met, the new target is clipped into the range both allow, so the flinch ends nearer the current view than its origin direction; the cap is one combined angle for yaw and pitch together, not per axis (designer decision, 2026-10-12, cross-review 12h; combined-angle reading is the recommended default) (12g W2) |
| Flinched survivor disconnects and reconnects within grace | The server discards the offset; the client starts fresh; both agree on the first tick | The Controller re-baselines; the view is never rotated (12f W2, 12g W1) |
| Survivor becomes Downed, Hidden or Seized with a held offset | The Controller re-baselines the offset to 0, no visible rotation (Scare Events does not reset) | The Hidden peek view ignores the offset (12f W2) |
| Hallucination target is downed | Hallucination still allowed but no flinch | Downed players already have reduced control |
| Hallucination scheduled while the shapeshifter, in any form, is within `lunge_cue_radius_m` of the target | Dropped **(proposed)** | Must never assist an attack; checking any form keeps the drop from becoming a tell |
| Two Major scares from the monster in quick succession (burst then lunge) | Both delivered; second reduced to Minor | Monster scares are never blocked |
| Client with reduced flash set to 0 | Light change without flashing; same timing and origin | Information parity |
| Client reconnects mid-round | Receives current facility scare state; missed scares not replayed | Avoids stale scares |
| Evacuation starts during Blackout | Emergency state applies. A Blackout in the active terminal room ends at that moment; a Blackout in any other room stays for its remaining duration | Facility Map owns lighting (`blackout_able`) (designer decision, 2026-10-12, cross-review B2) |
| Modified client plays a scare locally | Only that client sees it; no gameplay effect | Server-only triggers for others |

## Dependencies

| System | Direction | Nature of Dependency |
|---|---|---|
| Match Flow & Win Conditions | This depends on it | `RoundPhaseChanged`, phase windows |
| Monster Abilities | This depends on it | Blackout and Lunge triggers and wind-up timing |
| Borrowed Face | This depends on it | Reveal trigger, `FormChanged` |
| Survivor Defense | This depends on it | `BarricadeBroken` trigger; stun input never blocked |
| First-Person Controller & Interaction | This depends on it | Soft. The camera flinch is the single sanctioned view rotation (Controller rule 7): a server-held offset added to client yaw/pitch, none for a player with the toggle off. This writes the Controller's view-offset input; the Controller does not depend on this (designer decision, 2026-10-12, cross-review 12f) |
| Survivor Objectives | This depends on it | Fuse install alarm, power restored |
| Facility Map | This depends on it | Lighting states (owner), lighting volumes for the ambush test, scare anchors, emergency lights, monitors |
| Network Authority & Replication | This depends on it | `ScareTriggered` replication and scoping |
| Pings & Callouts | This depends on it | Ducking priority for callouts |
| Accessibility Options | Accessibility depends on this | Hooks in rules 24–29 |
| Match Telemetry | Telemetry depends on this | Scare logs |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| major_scare_cooldown_s | 45 (proposed) | 30–90 | Fewer big scares | Scare fatigue |
| minor_scare_cooldown_s | 10 (proposed) | 5–20 | Quieter facility | Noisy, less informative |
| same_scare_repeat_block_s | 120 (proposed) | 60–540 | More variety | Repetition |
| phase_budget (Low/Rising/Emergency) | 2/6/4 (proposed) | 0–12 each | More ambient tension | Facility feels static |
| scare_max_control_loss_s | 0.3 (proposed) | 0–0.5 | Bigger flinch, fairness risk | Softer scares |
| flinch_max_angle_deg | 10 (proposed placeholder, inferred) | TBD, set in the M5 playtest | Bigger jolt toward the origin, camera-steal risk | Flinch reads as a twitch |
| hallucination_max_per_client | 2 (proposed) | 0–4 | More paranoia | Less individual horror |
| stinger_max_db_rel | +6 dB (proposed) | 0–9 | Louder jolts, masks info | Subtler |
| ambush_unseen_s | 3 (proposed) | 1–10 | Fewer lunges count as ambushes | More lunges count as ambushes; scare noise (cross-review B1) |

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|---|---|---|---|
| Transformation reveal | True form, light flare (scaled) | Distortion at origin + stinger | High |
| Door burst | Door debris, dust | Impact at door | High |
| Ambush lunge | No flinch (rule 14) | Stinger layered on lunge cue | High |
| Blackout | Lights off, emergency lights faint | Power-down at origin | High |
| Slammed door / glass break | Door shudder in place, no swing (rule 7) / shards | At origin | Medium |
| Alarm | Strobe (rate-capped) | Positional alarm | Medium |
| Recording | Speaker light | Distorted voice from speaker | Medium |
| Impossible surveillance image | Brief frame on monitor (single client) | Static at monitor | Medium |
| Emergency mode | Amber rotating beacons (Facility Map Evacuation state) | Alarm loop, PA | High |

## Game Feel

### Feel Reference

Alien: Isolation's vent and alarm sounds: frightening because they tell you where something is. NOT a five-nights-style full-screen jumpscare that ends input.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|---|---|---|---|
| Movement during a scare | Unchanged from normal | — | Scares never add input delay |
| Stun item during a scare | Unchanged from normal | — | Never blocked |

### Animation Feel Targets

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|---|---|---|---|---|---|
| Camera flinch | 0 | ≤18 | 0 | Jolt, not lock | 0.3 s cap (proposed) |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|---|---|---|---|
| Camera flinch | ≤300 | View nudge toward origin; the single sanctioned view rotation, a server-held offset that is held after the ramp and replaced by the next flinch (the server view direction follows it; reset points in rule 13); none for a player with the toggle off | Yes (toggle) |
| Screen flash | ≤150 per flash | Brightness pulse, rate-capped | Yes (scale) |

### Weight and Responsiveness Profile

Sharp and short. The player always keeps control. A scare should leave the player knowing more (direction, location, who) than before it. Failure texture: if a survivor is downed after a scare, the cause must read as the monster's choice, not the scare's.

### Feel Acceptance Criteria

- [ ] In a closed playtest, at least 8 of 10 testers point within 45° of the origin of a scare they just heard.
- [ ] No playtester attributes a down to "the game froze me".

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|---|---|---|---|
| Flinch-off substitute pulse | Screen edge, toward origin | On scare | Flinch toggle off |
| None otherwise | — | — | Scares are diegetic; HUD owns phase display |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|---|---|---|---|
| Phase windows and phase change | `design/gdd/match-flow.md` | `RoundPhaseChanged`, phase windows | State trigger |
| Blackout, Lunge | `design/gdd/monster-abilities.md` | `blackout_duration_s`, lunge wind-up, `lunge_cue_radius_m` | Data dependency |
| Transformation reveal | `design/gdd/borrowed-face.md` | `FormChanged`, `transform_duration_s` distortion cue | State trigger |
| Barricade break; stun never blocked; stun ducking | `design/gdd/survivor-defense.md` | `BarricadeBroken`, `MonsterStunned`, `PlayerShocked` | Rule dependency |
| Fuse alarm, power restored | `design/gdd/survivor-objectives.md` | `ObjectiveProgressChanged` | State trigger |
| Lighting states, scare anchors, emergency lights, monitors | `design/levels/research-facility.md` | Lighting States (owner), Scare anchors table, authored placements | Data dependency |
| Callout ducking priority | `design/gdd/pings-and-callouts.md` | Callouts and pings | Rule dependency |
| Reduced flash/volume settings | `design/accessibility-requirements.md` (not yet authored) | Settings consuming rules 24–29 | Ownership handoff |

## Acceptance Criteria

- [ ] With 5 clients, a shared scare (e.g. door burst) is received by every relevant client with the same scare_id and origin, and by no irrelevant client.
- [ ] A hallucination is received only by its target; network capture on the other 4 clients shows no data for it.
- [ ] Every `ScareTriggered` in a full-round server log has a source of Monster, Survivor or RoundScript, and every Monster/Survivor source names a player; a packet capture on a survivor client shows no source or player identity in any `ScareTriggered` (designer decision, 2026-10-12, cross-review B3).
- [ ] Across 20 False Signals of every type, no `ScareTriggered` is emitted, and a survivor client's packet capture of a fake callout or sound matches that of the real one except the absent gesture event (designer decision, 2026-10-12, cross-review B3).
- [ ] A lunge wind-up started in a blacked-out volume, or by a monster that a survivor within `lunge_cue_radius_m` has had no line of sight to for `ambush_unseen_s`, sends the ambush lunge scare to that survivor; a wind-up in a lit volume by a monster that survivor saw within `ambush_unseen_s` sends them none (cross-review B1).
- [ ] No flinch plays on a survivor within `lunge_cue_radius_m` of a monster in lunge wind-up or Active, from the ambush lunge scare or any other Major scare; a reveal flinch running when a wind-up starts 0.1 s after the form change is cancelled on that tick and **freezes**: the offset keeps its value at that tick and does not revert.
- [ ] No scare changes health, down state, objective progress, cooldowns or position on the server.
- [ ] With the camera flinch toggle off, a Major scare plays the screen-edge pulse only: the player's server view direction and aim ray are identical before and after the scare, and a taser shot fired during the 0.3 s window resolves against the client's unrotated view. With the toggle on, the server view direction equals client yaw/pitch plus the flinch offset, reached within 0.3 s and held afterwards, and the client view matches it (designer decision, 2026-10-12, cross-review 12e). A second flinch replaces the offset rather than adding to it, the offset never exceeds `flinch_max_angle_deg` (10 degrees placeholder) and a replacing flinch rotates the view by at most `flinch_max_angle_deg` in total; the Controller re-baselines the offset to 0, with the view direction unchanged on that tick, at round end, on Downed, Hidden or Seized, after reconnect and when the flinch toggle is switched off while an offset is held (designer decision, 2026-10-12, cross-review 12f and 12g, W1, W2, W4).
- [ ] Maximum measured input loss from any scare is ≤ 0.3 s; movement and stun input work during a flinch.
- [ ] A RoundScript scare within 45 s of a Major scare on the same client is blocked; a Monster scare in the same window plays as Minor.
- [ ] The same scare_id at the same location does not fire twice within 120 s.
- [ ] Lunge wind-up and transform distortion cues play at full level during any scare and with any accessibility setting.
- [ ] With flash scale 0, no scare produces a luminance flash; scare timing and origin are unchanged.
- [ ] No scare produces more than 3 flashes per second.
- [ ] All 5 clients enter Emergency state within one network round trip of `RoundPhaseChanged` to Evacuation.
- [ ] RoundScript never produces footsteps, a teammate voice, a ping or a callout.
- [ ] A disguised shapeshifter entering an authored room or viewing a monitor fires the same scare a survivor would; server logs show identical gating for both.
- [ ] A RoundScript scare within 10 s of any scare on the same client is blocked; no client receives more RoundScript scares in a phase than that phase's budget (2/6/4).
- [ ] No client receives more than `hallucination_max_per_client` (2) hallucinations in a round.
- [ ] A RoundScript slammed door leaves its door's server open or closed state unchanged; a lunge, an observation line of sight and a ping through an open anchor door behave the same before and after the slam.
- [ ] A client that reconnects mid-round shows the current facility scare state within one network round trip and replays no missed scare.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Should the monster be able to trigger environment scares directly (e.g. slam a door) beyond its three abilities? Proposed no: keeps the kit at three abilities. | SneakKestrel16 | Before Milestone 3 | |
| Is the impossible surveillance image a hallucination (single client) or shared with everyone watching the same monitor? | SneakKestrel16 | Before Milestone 4 | |
| Is the facility powered down at round start (so fuses visibly restore lights)? | SneakKestrel16 | Before Milestone 2 | Proposed: yes, Low Power at round start (aligned with Facility Map) |
| Does the fake voice behind a door (False Signal) count as a Major scare for cooldown purposes? | SneakKestrel16 | Before Milestone 4 | **Settled:** False Signal produces no scare at all (rule 4a; designer decision, 2026-10-12, cross-review B3) |
| Are 0.3 s flinch and 45 s major cooldown right? Tune from closed playtest. Also: does the held view settle read as a jolt or as a camera steal? | SneakKestrel16 | Before Milestone 5 | Held-view question added (designer decision, 2026-10-12, cross-review 12f) |
| Should the monster player see/hear environment scares the same as survivors? | SneakKestrel16 | Before Milestone 4 | |
