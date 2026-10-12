# Scare Events

> **Status**: Draft
> **Author**: SneakKestrel16
> **Last Updated**: 2026-10-12 (cross-review B1–B3: ambush test, undefined triggers cut; Facility Map owns lighting; False Signal gets no scare; source and identity server-only)
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
   - `Survivor` — caused by a survivor's action (installing a fuse, entering an authored room, viewing a surveillance monitor) (cross-review B1: "running through a glass partition area" and "opening a sealed room" cut; neither exists on the map).
   - `RoundScript` — fired by the authored round script on a phase change or objective event.
3. Nothing else may fire a scare. There is no free-running ambient timer, no creature, no AI.
4. **No scare is a threat by itself.** Scares never deal damage, down, stun, slow, block a route permanently, change objective state or move a player. Environment scares are presentation; the only thing that can hurt a survivor is the monster player, validated by the server through Monster Abilities.
4a. **False Signal never produces a scare.** It has no scare entry and never emits `ScareTriggered`, so its fake callouts and sounds reach survivor clients exactly as a real callout or sound does (Pings & Callouts rule 27, Monster Abilities rule 15) (designer decision, 2026-10-12, cross-review B3).

**The three sources**

| Scare | Category | Source | Scope | Owner of the trigger |
|---|---|---|---|---|
| Transformation reveal (monster drops disguise) | Player-triggered | Monster | Shared | Borrowed Face |
| Door burst (monster breaks a barricade) | Player-triggered | Monster | Shared | Survivor Defense (barricade break) |
| Ambush lunge (wind-up passes the ambush test, rule 5a) | Player-triggered | Monster | Shared | Monster Abilities (Predatory Lunge) |
| Blackout (lights die) | Environment | Monster | Shared | Monster Abilities (Blackout) |
| Slammed door | Environment | RoundScript or Survivor **(proposed)** | Shared | This system |
| Glass break | Environment | RoundScript, at a Facility Map glass scare anchor **(proposed)** (cross-review B1: trip-point and monster-through-glass triggers cut) | Shared | This system |
| Alarm | Environment | Survivor (fuse install) or RoundScript (Evacuation) | Shared | Survivor Objectives / Match Flow |
| Unsettling recording | Environment | Survivor (enters authored room) or RoundScript **(proposed)** | Shared | This system |
| Disguised teammate transforms | Deception | Monster | Shared | Borrowed Face |
| Impossible surveillance image | Deception | Survivor (views a monitor) + RoundScript selects **(proposed)** | Single-client | This system |

5. Player-triggered scares are a presentation layer on top of the gameplay cue. The gameplay cue itself (transformation audio distortion, lunge wind-up and audible cue, barricade break sound) is owned by its system and is **never** suppressed, delayed or reduced by any rule here.
5a. **Ambush test** (cross-review B1): when a Predatory Lunge wind-up starts (`AbilityUsed`), the server runs the test for each survivor within `lunge_cue_radius_m` (Monster Abilities). It passes for that survivor if the monster stands in a lighting volume (Facility Map) that is blacked out, or in one that survivor has had no line of sight into for at least `ambush_unseen_s` **(proposed)**. The ambush lunge scare goes only to survivors for whom it passes; otherwise the lunge plays only its own gameplay cue.
6. RoundScript environment scares are drawn from authored lists per phase and zone, fire only at authored trigger points, and are limited by the phase budget in Formulas **(proposed)**. They exist to raise tension between human encounters, not to imitate the monster: a RoundScript scare may not produce footsteps, a teammate voice, a ping or a callout **(proposed)**. Those are only produced by humans, so a survivor who hears a teammate voice knows a human (teammate or monster) caused it.
7. Slammed doors from RoundScript close a door that is open but never lock or barricade it; any player can reopen it immediately **(proposed)**.

**Cooldowns and repeats** (server-side, per recipient client unless noted)

8. Each scare has an intensity class: **Major** (stinger + flash or camera reaction) or **Minor** (positional sound, light flicker) **(proposed)**.
9. After a client receives a Major scare, further Major scares for that client within `major_scare_cooldown_s` are **reduced** to their Minor variant (sound kept, stinger and flash dropped) **(proposed)**.
10. RoundScript and Survivor-source scares are **blocked** entirely for a client during `major_scare_cooldown_s` after a Major scare, and blocked during `minor_scare_cooldown_s` after any scare **(proposed)**. Monster-source scares are never blocked (rule 5), only reduced.
11. The same scare_id cannot fire again at the same authored location within `same_scare_repeat_block_s` **(proposed)**. Authored "once per round" scares (e.g. a specific recording) fire at most once.
12. A single-client hallucination is limited to `hallucination_max_per_client` per round **(proposed)**.

**Control-loss limit**

13. Scares never take away movement, look, interaction or stun-item input, with one exception: a Major scare may apply a camera flinch (involuntary view nudge) of at most `scare_max_control_loss_s` = 0.3 s **(proposed)**, during which the player can still move and use a stun item.
14. Flinch never fires on a survivor while the monster is in a lunge wind-up targeting that survivor's area **(proposed)**, and the flinch duration must stay shorter than the lunge wind-up owned by Monster Abilities. If a future scare needs longer control loss, it must be cut (Fair Fear design test).
15. No scare plays a non-skippable animation, forced camera move or full-screen overlay that hides the monster.

**Directional, informative audio**

16. Every diegetic scare sound plays from its true origin in the world (the door that slammed, the room that went dark, the speaker that played). Its direction and distance must be correct for the listener.
17. Non-diegetic stingers are allowed only on Major scares, play at most `stinger_max_db_rel` above the ambient bed **(proposed)**, and never cover the origin sound.
18. Priority (ducking): gameplay cues (lunge wind-up, transform distortion, stun, downed cries, callouts and pings) are never masked by scare audio; scare audio ducks under them **(proposed)**. Stun ducking triggers on `PlayerShocked` or `MonsterStunned` (true-form stun) on survivor clients and on `MonsterStunned` on the monster's client, because survivor clients never receive `MonsterStunned` while the monster is disguised (Survivor Defense rule 1).

**Shared vs. individual scope**

19. **Shared** scares go to every client that is relevant: inside the affected room/zone, within the sound's audible range, or with line of sight to the effect **(proposed: relevance = audible range or line of sight)**. All recipients see the same scare_id at the same origin.
20. **Single-client** scares (hallucinations) are sent only to the intended client. No other client receives any data about them, including the monster.
21. Hallucinations are presentation only and must not: show a fake teammate, ping, callout or pickup; misrepresent objective state or the round timer; or show the monster's real position **(proposed)**. They unsettle; they do not inform or misinform about gameplay state.

**Phase lighting/audio states**

22. On `RoundPhaseChanged` the server sets the facility scare state; all clients present it. The Facility Map owns per-volume lighting state (`research-facility.md` Lighting States): this system only requests those states and adds flicker and stingers on top (designer decision, 2026-10-12, cross-review B2).

| State | When | Lighting | Audio bed | Scare budget |
|---|---|---|---|---|
| Infiltration – Low | 0:00–2:00 | Facility starts in the Facility Map's **Low Power** lighting state: dim, stable work lights, Zone B dimmest, fuse boxes and terminal dark **(proposed; matches `research-facility.md`)** | Quiet hum, distant facility noise | Low (few RoundScript scares) **(proposed)** |
| Investigation – Rising | 2:00–7:00 | Facility Map's current state; this system adds flicker whose frequency rises over the phase **(proposed)** | Bed intensity rises with time | Medium, increasing |
| Power Restored (overlay) | Both fuses installed (`ObjectiveProgressChanged`) **(proposed)** | Leaves Low Power: main lights up in Zones B and C (Facility Map's Power Restored state) | Machinery up; alarm on install | Unchanged |
| Evacuation – Emergency | Final 2:00 | Facility Map's Evacuation state: overheads ~50%, rotating amber beacons, faint emergency floor lights (designer decision, 2026-10-12, cross-review B2) | Alarm loop, PA countdown | High, but per-client cooldowns still apply |
| Blackout (local overlay) | Monster Blackout, `blackout_duration_s` | Facility Map's Blackout (local) state: local lights off; emergency lights faintly visible | Power-down sound at origin | n/a |
| Results | Round end | Facility Map's Reset state: every volume back to round-start Low Power (designer decision, 2026-10-12, cross-review B2) | Music | None |

23. Emergency lighting must keep landmarks and the exit readable (Readable Objectives); Facility Map owns where emergency lights are.

**Accessibility hooks** (Accessibility Options owns the settings UI; this system must expose):

24. **Flash intensity scale** (0–1) applied to all scare flashes and light flicker; at the lowest setting, flashes are replaced by a non-flashing light change.
25. **Flash rate cap**: no scare may produce more than 3 luminance flashes per second at any setting **(proposed)**.
26. **Stinger volume scale** and **scare master volume scale** (0–1), separate from game master volume, so gameplay cues stay audible.
27. **Camera flinch toggle**: when off, rule 13's flinch is replaced by a screen-edge pulse.
28. **Information parity**: reduced settings change intensity, never information. Direction, origin and timing of every scare stay the same.
29. All hooks are client-side presentation settings; they never change server timing, cooldowns or recipients.

### States and Transitions

| State (facility scare state) | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| Low | Round start (Infiltration) | `RoundPhaseChanged` → Investigation | Low RoundScript budget |
| Rising | `RoundPhaseChanged` → Investigation | `RoundPhaseChanged` → Evacuation | Budget and flicker rise with time |
| Emergency | `RoundPhaseChanged` → Evacuation | Round end | Emergency lights, alarm bed |
| Results | Round end | Next round | No scares |

Per-client scare cooldown state: Ready → Major cooldown (`major_scare_cooldown_s`) → Ready; Ready → Minor cooldown (`minor_scare_cooldown_s`) → Ready. Cooldowns reset at round start.

### Interactions with Other Systems

- **Match Flow & Win Conditions**: `RoundPhaseChanged` drives the facility scare state.
- **Monster Abilities**: Blackout and Predatory Lunge send scare triggers (source Monster) through `AbilityUsed` after the server validates the ability; False Signal sends none (rule 4a); lunge wind-up timing bounds the flinch rule.
- **Borrowed Face**: `FormChanged` into true form triggers the reveal scare for survivors within `reveal_radius_m` (10 m, owned by Borrowed Face rule 15) with line of sight.
- **Survivor Defense**: barricade breaks trigger door burst; stun use is never blocked by scares.
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
    block if phase_budget_used >= phase_budget[phase]
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| major_scare_cooldown_s | float | 30–90 | data | Proposed 45 |
| minor_scare_cooldown_s | float | 5–20 | data | Proposed 10 |
| same_scare_repeat_block_s | float | 60–540 | data | Proposed 120 |
| phase_budget | int per phase | 0–12 | data | RoundScript scares per client: Low 2, Rising 6, Emergency 4 (proposed) |

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
| Hallucination target is downed | Hallucination still allowed but no flinch | Downed players already have reduced control |
| Hallucination scheduled while monster within lunge range of target | Delayed until not applicable or dropped **(proposed)** | Must never assist an attack |
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
| hallucination_max_per_client | 2 (proposed) | 0–4 | More paranoia | Less individual horror |
| stinger_max_db_rel | +6 dB (proposed) | 0–9 | Louder jolts, masks info | Subtler |
| ambush_unseen_s | 3 (proposed) | 1–10 | Fewer lunges count as ambushes | More lunges count as ambushes; scare noise (cross-review B1) |

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|---|---|---|---|
| Transformation reveal | True form, light flare (scaled) | Distortion at origin + stinger | High |
| Door burst | Door debris, dust | Impact at door | High |
| Ambush lunge | Flinch (≤0.3 s) | Stinger layered on lunge cue | High |
| Blackout | Lights off, emergency lights faint | Power-down at origin | High |
| Slammed door / glass break | Door swing / shards | At origin | Medium |
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
| Camera flinch | ≤300 | View nudge toward origin | Yes (toggle) |
| Screen flash | ≤150 per flash | Brightness pulse, rate-capped | Yes (scale) |

### Weight and Responsiveness Profile

Sharp and short. The player always keeps control. A scare should leave the player knowing more (direction, location, who) than before it. Failure texture: if a survivor is downed after a scare, the cause must read as the monster's choice, not the scare's.

### Feel Acceptance Criteria

- [ ] Playtesters can point toward the origin of a scare they just heard.
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
| Reduced flash/volume settings | `design/accessibility-requirements.md` | Settings consuming rules 24–29 | Ownership handoff |

## Acceptance Criteria

- [ ] With 5 clients, a shared scare (e.g. door burst) is received by every relevant client with the same scare_id and origin, and by no irrelevant client.
- [ ] A hallucination is received only by its target; network capture on the other 4 clients shows no data for it.
- [ ] Every `ScareTriggered` in a full-round server log has a source of Monster, Survivor or RoundScript, and every Monster/Survivor source names a player; a packet capture on a survivor client shows no source or player identity in any `ScareTriggered` (designer decision, 2026-10-12, cross-review B3).
- [ ] Across 20 False Signals of every type, no `ScareTriggered` is emitted, and a survivor client's packet capture of a fake callout or sound matches that of the real one except the absent gesture event (designer decision, 2026-10-12, cross-review B3).
- [ ] A lunge wind-up started in a blacked-out volume, or in a volume a survivor within `lunge_cue_radius_m` has not seen into for `ambush_unseen_s`, sends the ambush lunge scare to that survivor; a wind-up in a lit volume that survivor saw into within `ambush_unseen_s` sends them none (cross-review B1).
- [ ] No scare changes health, down state, objective progress, cooldowns or position on the server.
- [ ] Maximum measured input loss from any scare is ≤ 0.3 s; movement and stun input work during a flinch.
- [ ] A RoundScript scare within 45 s of a Major scare on the same client is blocked; a Monster scare in the same window plays as Minor.
- [ ] The same scare_id at the same location does not fire twice within 120 s.
- [ ] Lunge wind-up and transform distortion cues play at full level during any scare and with any accessibility setting.
- [ ] With flash scale 0, no scare produces a luminance flash; scare timing and origin are unchanged.
- [ ] No scare produces more than 3 flashes per second.
- [ ] All 5 clients enter Emergency state within one network round trip of `RoundPhaseChanged` to Evacuation.
- [ ] RoundScript never produces footsteps, a teammate voice, a ping or a callout.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Should the monster be able to trigger environment scares directly (e.g. slam a door) beyond its three abilities? Proposed no: keeps the kit at three abilities. | SneakKestrel16 | Before Milestone 3 | |
| Is the impossible surveillance image a hallucination (single client) or shared with everyone watching the same monitor? | SneakKestrel16 | Before Milestone 4 | |
| Is the facility powered down at round start (so fuses visibly restore lights)? | SneakKestrel16 | Before Milestone 2 | Proposed: yes, Low Power at round start (aligned with Facility Map) |
| Does the fake voice behind a door (False Signal) count as a Major scare for cooldown purposes? | SneakKestrel16 | Before Milestone 4 | **Settled:** False Signal produces no scare at all (rule 4a; designer decision, 2026-10-12, cross-review B3) |
| Are 0.3 s flinch and 45 s major cooldown right? Tune from closed playtest. | SneakKestrel16 | Before Milestone 5 | |
| Should the monster player see/hear environment scares the same as survivors? | SneakKestrel16 | Before Milestone 4 | |
