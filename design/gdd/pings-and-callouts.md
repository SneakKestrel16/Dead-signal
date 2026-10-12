# Pings & Callouts

> **Status**: Draft
> **Author**: SneakKestrel16
> **Last Updated**: 2026-10-12
> **Last Verified**: 2026-10-11
> **Implements Pillar**: Counterplay (communication), Human Deception, Readable Objectives

## Summary

Pings & Callouts is Dead Signal's voice-free communication layer: world markers ("look here", "item here", "warning") and a small set of authored, voiced callouts ("Drive here", "Need rescue", "I'm with you"). It makes team communication useful without making voice chat mandatory, and it is also a deception surface: a disguised shapeshifter can ping and call out under a borrowed name, and False Signal can fake a teammate callout. Every ping and callout goes through the server.

> **Quick reference** — Layer: `Feature` · Priority: `Vertical Slice` · Key deps: `First-Person Controller & Interaction, Network Authority & Replication, Borrowed Face, Monster Abilities`

## Overview

Survivors have to share where objectives are, who needs help and who they distrust, and they often play without voice chat. Pings put a short-lived marker on a point, an object or a player. Callouts play an authored voice line from the speaker's position and add a line to a text feed. Proximity voice is an optional lobby setting on top of this; nothing in the game requires it. Because the monster is a human who pretends to be a survivor, the same tools are deliberately open to it while it is disguised, so a ping or callout is evidence, not proof.

## Player Fantasy

Survivor: "I can tell my team exactly what I need with one button, even in the dark and even if I never speak." Shapeshifter: "My lie looks exactly like their truth, until someone checks." Both sides should feel that communication is powerful and that trusting it blindly is a mistake.

## Detailed Design

### Core Rules

**General**

1. Every ping and callout is a request from the client to the server. The server validates it, attaches the sender's *displayed identity* (from server-side disguise state, never from the client), and sends it to recipients. Clients never create pings or callouts that other clients see directly.
2. A client may show its own ping as a pending marker immediately; if the server rejects it, the pending marker is removed **(proposed)**.
3. Pings and callouts are presentation and information only. They never change objective, downing, stun, cooldown or outcome state.
4. Voice-free play must be fully viable: every piece of information the round requires (objective found, objective location, rescue needed, danger, distrust, regroup) has a ping or callout that carries it.

**Pings**

5. Three ping types **(proposed)**:
   - **Location ping**: marks a world point the sender is looking at ("go here / look here").
   - **Item ping**: marks a specific interactable object the sender can see (data drive, fuse, fuse box, evacuation terminal, hiding spot, barricadable door, backup light switch, stun item). The marker shows the object type.
   - **Warning ping**: marks a point ("danger here") or a player ("suspicious"). A warning ping on a player attaches to that player's displayed identity and follows them for its lifetime.
6. Server validation for a ping: sender is alive and not eliminated; sender is not in a state that blocks pinging (see States); rate limit not exceeded (Formulas); target is within `ping_max_range_m` and in line of sight from the sender's view; for an item ping, the object exists and is pingable; for a player warning ping, the target player is visible to the sender.
7. Recipients: all living players, including the monster **(proposed; see Open Questions)**. Markers are visible through walls with direction and distance for `ping_lifetime_s`, then fade.
8. Each marker shows the sender's displayed identity (name/colour). A sender may have at most `ping_max_active` markers; a new one replaces the oldest **(proposed)**.

**Callouts**

9. Authored callout set **(proposed: 8 lines)**: "Drive here", "Fuse here", "Need rescue", "I'm with you", "Follow me", "Wait", "Danger", "That wasn't me".
10. A callout plays an authored voice line from the speaker's position using the voice set of the speaker's displayed identity **(proposed: one voice set per survivor slot)**, and adds a feed line `[Name]: [text]` with a direction indicator to every recipient.
11. Recipients: every living player within that callout's audible range (`callout_range_m`; "Need rescue" uses `rescue_callout_range_m`) **(proposed)**. Players out of range get neither the audio nor the feed line.
12. A real callout also plays a short visible gesture on the speaker's body **(proposed)**, so a survivor with line of sight can confirm who spoke.
13. "Drive here" and "Fuse here" may optionally attach an item ping if the sender is looking at a valid item; the attached ping is validated like any item ping and counts against the ping rate limit.
14. A downed survivor can use "Need rescue", "Danger" and pings; this is how a downed survivor "calls for help" in voice-free play.

**Spam limits** (server-enforced; rejected requests are dropped and the sender sees a local "too fast" tick; nothing reaches other players)

15. Pings: token bucket per player, `ping_bucket_size` tokens, refilling one per `ping_refill_s` **(proposed)**.
16. Callouts: per-player `callout_global_cooldown_s` between any two callouts, and the same callout line cannot repeat within `callout_repeat_block_s` **(proposed)**.
17. The monster uses the same limits as survivors while disguised. These limits are separate from False Signal's cooldown (`false_signal_cooldown_s`, owned by Monster Abilities).

**Proximity voice (optional)**

18. Proximity voice is a lobby setting, Off by default **(proposed)**. When On, it applies to all five players under the same rule, so voice availability is never itself a role tell **(proposed)**.
19. Voice is positional, with range `voice_range_m` **(proposed)**. Downed survivors can speak. Eliminated players are muted to living players for the rest of the round **(proposed)**, so they cannot relay information they gained.
20. No game rule, objective or counter may require voice. Voice only adds to what pings and callouts already carry.

**Monster communication**

21. **Disguised** (Borrowed Face active): the monster can send all ping types and all callouts. They are attributed to the borrowed survivor's identity and use that survivor's voice set. This is a deliberate deception tool **(proposed)**.
22. **True form**: the monster cannot ping or call out **(proposed)**. It has no teammate identity to speak as.
23. **Transforming** (`transform_duration_s`): pings and callouts are blocked **(proposed)**.
24. Duplicate identity is a fair clue: if the monster and the real survivor it is copying both ping or call out, both appear with the same name. The server does not hide or merge them **(proposed)**.
25. Monster voice: open question from the source brief (proximity voice, preset lines only, or both). Options and the proposed prototype default are in Open Questions; until decided, the monster has preset lines (rule 21) and follows rule 18 for voice.

**False Signal fake callout** (False Signal itself is owned by Monster Abilities; this section defines only how its fake callout relates to a real one) **(proposed)**

26. A fake callout uses the same authored line, voice set and feed line format as a real callout from the impersonated survivor. Recipients are chosen by the same range rule, measured from the fake's origin.
27. The server tags each callout as real or fake internally and never sends that tag to any survivor client. The difference must not be detectable from network data.
28. What stays different, by design, so the fake is an *approximate clue*:
    - The origin is the point the monster chose, not the impersonated survivor's actual position, so sight and team communication can disprove it.
    - No body performs the speaker gesture at the origin (rule 12).
    - A fake callout cannot attach an item ping (rule 13).
    - The impersonated survivor, if in range, sees the feed line marked "(not you)" **(proposed)** and can answer with "That wasn't me". The same mark appears on *any* callout or ping shown under your name that you did not send, including ones from a disguised monster, so the mark reveals impersonation but not whether it was a fake callout or a disguised body.
29. Which identities False Signal may fake (for example, only observed survivors) is decided by Monster Abilities and Borrowed Face, not here.

### States and Transitions

| State (per player) | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| Survivor: Healthy | Round start; `SurvivorRescued` | `SurvivorDowned` | All pings and callouts |
| Survivor: Downed | `SurvivorDowned` | `SurvivorRescued` or `SurvivorEliminated` | Pings, "Need rescue", "Danger"; voice if enabled |
| Survivor: Eliminated | `SurvivorEliminated` | Round end | No pings, callouts or voice to living players **(proposed)** |
| Monster: Disguised | `FormChanged` to a survivor form completes | `FormChanged` begins | All pings and callouts as the borrowed identity |
| Monster: Transforming | `FormChanged` begins | Transformation completes | Blocked **(proposed)** |
| Monster: True form | Reveal / round start undisguised | `FormChanged` to a survivor form completes | Blocked **(proposed)** |

Existing markers persist with the identity they were sent under until they expire, even if the sender's form changes **(proposed)**.

### Interactions with Other Systems

- **Network Authority & Replication**: carries ping/callout requests and server broadcasts; supplies server-side positions and line-of-sight checks.
- **First-Person Controller & Interaction**: supplies the view ray and input bindings (ping button, callout wheel).
- **Borrowed Face**: supplies the displayed identity and Disguised/Transforming/True-form state (`FormChanged`).
- **Monster Abilities**: False Signal requests a fake callout; this system presents it per rules 26–29.
- **Downing, Rescue & Elimination**: `SurvivorDowned` / `SurvivorRescued` / `SurvivorEliminated` gate what a survivor can send.
- **Survivor Objectives**: defines which objects are item-pingable and their type labels.
- **Survivor Defense**: hiding spots, barricadable doors and stun items are item-pingable.
- **Facility Map**: room IDs/names for callout vocabulary; backup switch placement.
- **Scare Events**: scare audio must not mask callouts or ping sounds (Scare Events owns the ducking rule).
- **HUD & Results Screen**: draws markers, the callout wheel and the feed.
- **Match Telemetry**: logs pings and callouts per player and type, and fake callouts sent.

## Formulas

### Ping rate limit (token bucket)

```
tokens = min(ping_bucket_size, tokens + elapsed_s / ping_refill_s)
accept ping if tokens >= 1, then tokens -= 1
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| ping_bucket_size | int | 2–5 | data | Burst size (proposed 3) |
| ping_refill_s | float | 1–4 | data | Seconds per token (proposed 2) |
| elapsed_s | float | ≥0 | server clock | Time since last update |

**Expected output**: 3 pings in a burst, then one every 2 s (max 30 per minute). **Example**: three pings at t=0, a fourth at t=1 is rejected (tokens 0.5), one at t=2 is accepted.

### Callout acceptance

```
accept if (now - last_callout_any) >= callout_global_cooldown_s
      and (now - last_callout[line]) >= callout_repeat_block_s
```

Proposed 3 s and 8 s: at most 20 callouts per minute, and the same line at most once every 8 s. **Example**: "Danger" at t=0, "Wait" at t=3 accepted, "Danger" at t=6 rejected, "Danger" at t=8 accepted.

### Callout recipients

```
recipient if distance(origin, listener) <= range(line) and listener is living
```

`range(line)` = `callout_range_m` (proposed 25) or `rescue_callout_range_m` (proposed 40). Range is straight-line distance; walls attenuate the audio but do not block delivery **(proposed)**. The origin is the speaker's position for a real callout, the chosen point for a fake.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|---|---|---|
| Disguised monster and the real survivor ping at the same time | Both markers appear under the same name | Duplicates are a learnable, fair clue |
| Monster pings an objective, then reveals | Marker keeps the borrowed name until expiry | No retroactive rewrite; survivors can reason about it |
| Client sends a ping at a point outside line of sight | Server rejects; pending marker removed | Prevents wallhack-style pinging via modified clients |
| Client spoofs a sender name | Ignored; server always attaches identity from its own state | Identity is server-owned |
| Fake callout impersonates a survivor who is eliminated | Allowed or blocked per Monster Abilities; if allowed, it plays as normal | It is a strong clue for survivors; owner decides |
| Downed survivor spams "Need rescue" | Repeat block applies (8 s) | One clear call is enough; no audio spam |
| Survivor is rescued mid-callout | Line finishes playing | Presentation only |
| Two callouts overlap at one listener | Both play; feed shows both in arrival order | No information silently dropped |
| Survivor warning-pings a teammate who is real | Allowed; marker follows them | Distrust is part of play |
| Proximity voice On, monster player speaks in own voice while disguised | Governed by the open monster-voice decision | Source brief leaves it open |
| Player disconnects with active markers | Markers expire normally | No state to clean up beyond timers |

## Dependencies

| System | Direction | Nature of Dependency |
|---|---|---|
| Network Authority & Replication | This depends on it | Server validation, broadcast, positions, line of sight |
| First-Person Controller & Interaction | This depends on it | View ray, input |
| Borrowed Face | This depends on it | Displayed identity, form state (`FormChanged`) |
| Downing, Rescue & Elimination | This depends on it | Survivor state gates sending |
| Survivor Objectives | This depends on it | Pingable object types |
| Survivor Defense | This depends on it | Pingable hiding spots, barricadable doors, stun items |
| Facility Map | This depends on it | Room IDs and names as callout locations; pingable backup switches |
| Monster Abilities | Monster Abilities depends on this | False Signal's fake callout is presented by this system |
| Scare Events | Scare Events depends on this | Must not mask callouts |
| HUD & Results Screen | HUD depends on this | Markers, wheel, feed |
| Match Telemetry | Telemetry depends on this | Ping/callout logs |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| ping_lifetime_s | 8 (proposed) | 4–15 | Clearer, more clutter | Less clutter, easy to miss |
| ping_max_range_m | 40 (proposed) | 20–60 | Long-range scouting | Pings feel short |
| ping_max_active | 2 (proposed) | 1–4 | More markers per player | Less clutter |
| ping_bucket_size | 3 (proposed) | 2–5 | Bigger bursts | Tighter spam control |
| ping_refill_s | 2 (proposed) | 1–4 | Fewer pings | More spam risk |
| callout_global_cooldown_s | 3 (proposed) | 2–6 | Less chatter | More spam risk |
| callout_repeat_block_s | 8 (proposed) | 5–15 | Less repetition | More repetition |
| callout_range_m | 25 (proposed) | 15–40 | Team-wide reach; weaker fakes | Tighter, more local |
| rescue_callout_range_m | 40 (proposed) | 25–60 | Downed found faster | Rescues harder |
| voice_range_m | 20 (proposed) | 10–35 | Voice dominates pings | Voice more local |

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|---|---|---|---|
| Location ping | Marker with name, distance | Soft tick, positional | High |
| Item ping | Marker with object icon | Tick, positional | High |
| Warning ping | Red marker / player outline tag | Sharper tone | High |
| Callout | Feed line + direction arrow; speaker gesture | Authored line, voice set of displayed identity | High |
| "(not you)" feed mark | Tag on own impersonated line | None | Medium |
| Rejected request | Local "too fast" tick | Local click | Low |

## Game Feel

### Feel Reference

Apex Legends' ping wheel for speed and clarity: one press, one unambiguous meaning. NOT a chat menu that takes the player's eyes off the corridor.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|---|---|---|---|
| Ping (own pending marker) | 50 | 3 | Local, before server confirm |
| Callout wheel open | 50 | 3 | Wheel never pauses movement |
| Others see ping/callout | Server round trip | — | Network-bound |

### Animation Feel Targets

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|---|---|---|---|---|---|
| Callout gesture | 0 | ~30 | 0 | Readable, non-blocking | Does not interrupt movement or interactions |

### Impact Moments

None. Communication never applies hit-stop, shake or slowdown.

### Weight and Responsiveness Profile

Light and instant. The player keeps full movement control while pinging or using the wheel. Failure texture: a rejected ping is clearly signalled locally, never silent.

### Feel Acceptance Criteria

- [ ] Playtesters can ping an item and use a callout without stopping movement.
- [ ] No playtester reports needing voice to complete a round.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|---|---|---|---|
| Ping markers | World-space, clamped to screen edge when off-screen | Per frame | While active |
| Callout wheel | Screen centre | On hold | Allowed states only |
| Callout feed (last 4 lines) | Screen edge | On event | In range |
| Rate-limit feedback | Near crosshair | On reject | Sender only |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|---|---|---|---|
| Displayed identity, form states | `design/gdd/borrowed-face.md` | Disguise state, `FormChanged`, `transform_duration_s` | Data dependency |
| Fake teammate callout | `design/gdd/monster-abilities.md` | False Signal, `false_signal_cooldown_s`, which identities can be faked | Rule dependency |
| Sending allowed by survivor state | `design/gdd/downing-and-rescue.md` | `SurvivorDowned`, `SurvivorRescued`, `SurvivorEliminated` | State trigger |
| Pingable objects | `design/gdd/survivor-objectives.md` | Drives, fuses, evacuation terminal | Data dependency |
| Pingable defenses | `design/gdd/survivor-defense.md` | Hiding spots, barricadable doors, stun items | Data dependency |
| Backup switches as pingable | `design/levels/research-facility.md` | Backup light switch placement | Data dependency |
| Callouts not masked by scares | `design/gdd/scare-events.md` | Audio ducking priority | Rule dependency |

## Acceptance Criteria

- [ ] With 5 clients, a survivor's item ping appears on all 4 other clients at the same object with the same sender name within 1 network round trip.
- [ ] A client that sends a ping at a point outside its line of sight is rejected by the server; no other client receives it.
- [ ] A client sending 10 pings in 1 s results in exactly 3 delivered pings.
- [ ] The same callout sent twice within 8 s is delivered once.
- [ ] A disguised monster's ping and callout show the borrowed survivor's name and voice on all 4 survivor clients.
- [ ] In true form and while transforming, the monster's ping and callout requests are rejected.
- [ ] A False Signal fake callout is indistinguishable from a real one in the data received by survivor clients (packet inspection shows no real/fake field).
- [ ] The impersonated survivor, within range, sees "(not you)" on a fake callout; other survivors do not.
- [ ] A player outside `callout_range_m` receives neither audio nor feed line.
- [ ] A downed survivor can send "Need rescue"; an eliminated player cannot send any ping or callout.
- [ ] A full 5-client round is completed with proximity voice Off and no external voice chat.
- [ ] No ping or callout changes objective, downing, stun or outcome state on the server.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Monster voice: proximity voice, preset lines only, or both? Proposed prototype default: preset lines while disguised; proximity voice follows the same lobby setting as survivors; muted in true form. Test all three in closed playtest. | SneakKestrel16 | Before Milestone 4 | |
| Does the monster receive survivor pings (proposed yes, as a member of the group), or only those it could see in-world? | SneakKestrel16 | Before Milestone 4 | |
| Does each survivor slot have its own voice set (needed for fake callouts to imitate a specific teammate)? | SneakKestrel16 | Before Milestone 4 | |
| Should a fake callout carry any authored tell beyond rule 28 (e.g. faint signal distortion), or rely only on position and verification? | SneakKestrel16 | Before Milestone 3 | |
| Are callouts positional only (proposed) or also carried over a facility radio? | SneakKestrel16 | Before Milestone 4 | |
| Is the 8-line callout set right, and is "That wasn't me" too strong a counter? | SneakKestrel16 | Before Milestone 5 | |
