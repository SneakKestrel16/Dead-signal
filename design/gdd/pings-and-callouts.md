# Pings & Callouts

> **Status**: Approved
> **Author**: SneakKestrel16
> **Last Updated**: 2026-10-12 (cross-review W8: tasers are not item-pingable; earlier: cross-review B4: an immune taser hit no longer blocks pings and callouts; previously eighth design review, approved)
> **Last Verified**: 2026-10-12
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
   - **Item ping**: marks a specific interactable object the sender can see (data drive, fuse, fuse box, evacuation terminal, hiding spot, barricadable door, backup light switch). The marker shows the object type. Tasers are never world objects, so they are not pingable (designer decision, 2026-10-12, cross-review W8).
   - **Warning ping**: marks a point ("danger here") or a player ("suspicious"). A warning ping on a player is a static marker at the position the player stood when pinged, labelled with their displayed identity; it never follows the player (designer decision, 2026-10-11, design review). A warning ping on a monster in True Form is allowed and is labelled "Monster", since a True Form body has no displayed identity (designer decision, 2026-10-12, design review). A following marker would have to choose a body when two share a name (rule 24) and would either track a transforming monster into its new disguise or vanish when it transforms; either is an identity tell no survivor earned.
6. Server validation for a ping: sender is in play (not Eliminated or Escaped); sender is not in a state that blocks pinging (see States); rate limit not exceeded (Formulas); target is within `ping_max_range_m` and in line of sight from the sender's view; for an item ping, the object exists and is pingable; for a player warning ping, the target player is visible to the sender (a survivor inside a hiding spot is never a valid target, rule 7a).
7. Recipients: all living survivors, plus the monster **only if the pinged point or object is in the monster's line of sight at the moment the server accepts the ping**. "Line of sight" here means an unobstructed server ray from the monster's eye to the target, within `ping_max_range_m`, with the monster's facing ignored (designer decision, 2026-10-12, design review), so turning around is never a tell. A warning ping on the monster's own body always reaches it. Eliminated and Escaped spectators watch a living survivor (Downing rule 9; Match Flow rule 10) and receive exactly the pings and callouts that survivor's client receives, and send nothing (designer decision, 2026-10-12, design review). The monster rule is a designer decision (2026-10-12, design review; a Downed survivor's ping therefore never gives the monster a through-wall marker, consistent with Downing rule 6). A monster that cannot see the target receives nothing and no rejection signal reaches the sender. Markers are visible to survivors through walls with direction and distance for `ping_lifetime_s`, then fade; the monster's marker, once received, follows the same display rule.
7a. An item ping on an occupied hiding spot shows the spot's object icon only; it never names or marks the occupant, and the occupant's presence is not part of the message **(proposed)**.
8. Each marker shows the sender's displayed identity (name/colour). A sender may have at most `ping_max_active` markers; a new one replaces the oldest **(proposed)**.

**Callouts**

9. Authored callout set **(proposed: 8 lines)**: "Drive here", "Fuse here", "Need rescue", "I'm with you", "Follow me", "Wait", "Danger", "That wasn't me".
10. A callout plays an authored voice line from the speaker's position using the voice set of the speaker's displayed identity (one voice set per survivor character C1–C5, `lobby-role-assignment.md` rule 5), and adds a feed line `[Name]: [text]` with a direction indicator to every recipient.
11. Recipients: every living player within that callout's audible range (`callout_range_m`; "Need rescue" uses `rescue_callout_range_m`) **(proposed)**. Players out of range get neither the audio nor the feed line. **The monster gets the audio only** (positional, wall-attenuated): no feed line, no name and no direction arrow (designer decision, 2026-10-12, design review), so a "Need rescue" within 40 m gives the monster no name, arrow or marker. The wall-attenuated positional audio is still a rough directional cue; Downing rule 6 accepts that explicitly. Survivors get audio, feed line and arrow.
12. A real callout also plays a short visible gesture on the speaker's body **(proposed)**, so a survivor with line of sight can confirm who spoke.
13. "Drive here" and "Fuse here" may optionally attach an item ping if the sender is looking at a valid item; the attached ping is validated like any item ping and counts against the ping rate limit. If the attached ping is rejected (no token, invalid target), the callout is still accepted on its own limits and plays without it.
14. A downed survivor can use "Need rescue", "Danger" and pings; this is how a downed survivor "calls for help" in voice-free play.
14a. A hidden survivor (Survivor Defense rules 18–20) can ping from its restricted peek view and can call out **(proposed)**. The callout plays from the hiding spot, so it reveals the spot to anyone in range; no gesture is visible. Line of sight for a ping is measured from the peek view.

**Spam limits** (server-enforced; rejected requests are dropped and the sender sees a local "too fast" tick; nothing reaches other players)

15. Pings: token bucket per player, `ping_bucket_size` tokens, refilling one per `ping_refill_s` **(proposed)**.
16. Callouts: per-player `callout_global_cooldown_s` between any two callouts, and the same callout line cannot repeat within `callout_repeat_block_s` **(proposed)**.
17. The monster uses the same limits as survivors while disguised. These limits are separate from False Signal's cooldown (`false_signal_cooldown_s`, owned by Monster Abilities). A False Signal fake callout touches no callout or ping limit state: it does not update `last_callout_any` or `last_callout[line]` for the impersonated survivor or for the monster player, and it spends no ping token. Only `false_signal_cooldown_s` limits it (designer decision, 2026-10-12, design review), so a fake can never suppress the impersonated survivor's real callout.

**Proximity voice (optional)**

18. Proximity voice is a lobby setting, Off by default **(proposed)**. When On, it applies to every player under the same rule, so voice availability is never itself a role tell **(proposed)**.
19. Voice is positional, with range `voice_range_m` **(proposed)**. Downed survivors can speak. Eliminated and Escaped players are muted to living players for the rest of the round **(proposed)**, so they cannot relay information they gained.
20. No game rule, objective or counter may require voice. Voice only adds to what pings and callouts already carry.

**Monster communication**

21. **Disguised** (Borrowed Face active): the monster can send all ping types and all callouts. They are attributed to the borrowed survivor's identity and use that survivor's voice set. This is a deliberate deception tool **(proposed)**. If the borrowed survivor is Eliminated or Escaped, the disguised monster's pings and callouts are rejected (Borrowed Face rule 13 keeps the disguise on); a dead voice is a free tell, the same reason Monster Abilities rejects a fake callout as that survivor (designer decision, 2026-10-12, design review). Apart from that Eliminated or Escaped rejection, the monster's own state alone decides what it can send (Disguised, Transforming, stunned): the borrowed survivor's Downed, Seized or Hidden state does not restrict it, so a disguise as a Downed survivor may send any ping or callout, not only the Downed subset of rule 14 (designer decision, 2026-10-12, design review; the mismatch is a fair clue).
22. **True form**: the monster cannot ping or call out **(proposed)**. It has no teammate identity to speak as.
23. **Transforming** (`transform_duration_s`): pings and callouts are blocked **(proposed)**. **Shocked or stunned**: for `stun_duration_s` after a taser hit, pings and callouts are blocked for a shocked survivor and for a stunned disguised monster alike (Survivor Defense rule 14; designer decision, 2026-10-11, cross-review re-review R2). A hit inside the post-lock window, including any immune hit, blocks nothing (designer decision, 2026-10-12, cross-review B4). Proximity voice is not blocked.
24. Duplicate identity is a fair clue: if the monster and the real survivor it is copying both ping or call out, both appear with the same name. The server does not hide or merge them **(proposed)**.
25. **Monster voice: both** (designer decision, 2026-10-12). The monster has (a) **preset lines**: while Disguised, the authored callouts in the borrowed survivor's voice set (rule 21); and (b) **proximity voice**: its own real voice, under the same lobby setting and range as survivors (rules 18–19), so voice availability is never a role tell.
    - While Disguised, its proximity voice is its own, unaltered **(proposed)**. The game never changes it to sound like the borrowed survivor (the source rules out voice-imitation software). A voice that does not match the face is a fair tell, and a quiet monster leaning on preset lines is a fair bluff.
    - In True Form or while Transforming, its proximity voice still works but passes through a distortion filter **(proposed)**, so a monster that speaks gives its position away.
    - With proximity voice Off in the lobby, the monster has preset lines only (while Disguised), like survivors.

**False Signal fake callout** (False Signal itself is owned by Monster Abilities; this section defines only how its fake callout relates to a real one) **(proposed)**

26. A fake callout uses the same authored line, voice set and feed line format as a real callout from the impersonated survivor. Recipients are chosen by the same range rule, measured from the fake's origin.
27. The server tags each callout as real or fake internally and never sends that tag to any survivor client. The difference must not be detectable from network data, except the absent gesture event (rule 28).
28. What stays different, by design, so the fake is an *approximate clue*:
    - The origin is the point the monster chose, not the impersonated survivor's actual position, so sight and team communication can disprove it.
    - No body performs the speaker gesture at the origin (rule 12).
    - A fake callout cannot attach an item ping (rule 13).
    - The impersonated survivor, if in range, sees the feed line marked "(not you)" **(proposed)** and can answer with "That wasn't me". The same mark appears on *any* callout shown under your name that you did not send, including ones from a disguised monster, so the mark reveals impersonation but not whether it was a fake callout or a disguised body. A ping shown under your name that you did not send carries the mark **only if the ping's sender is within `callout_range_m` of you**, measured between server positions at the moment the server accepts the ping; beyond that range the ping is unmarked (designer decision, 2026-10-12, design review), so a far-away disguised ping stays a usable lie while a near one exposes the monster. Note the consequence: a disguised monster that calls out or pings within `callout_range_m` of the real survivor it copies is tagged "(not you)", a near-certain reveal. Accepted as intended pressure on the monster; playtest-gated (see Tuning Knobs, `callout_range_m`).
    - Timing is a fair tell: a fake callout touches no limits (rule 17), so a same-line repeat inside `callout_repeat_block_s`, or two callouts inside `callout_global_cooldown_s`, under one name cannot all be that survivor's real ones. Accepted as a clue; the server does not hide it.
29. Which identities False Signal may fake (for example, only observed survivors) is decided by Monster Abilities and Borrowed Face, not here.

### States and Transitions

| State (per player) | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| Survivor: Healthy | Round start; `SurvivorRescued`; commit cancelled | Valid `SurvivorHit` (→ Seized); `SurvivorEscaped` | All pings and callouts (hidden: rule 14a) |
| Survivor: Downed | `SurvivorDowned` | `SurvivorRescued` or `SurvivorEliminated` | Pings, "Need rescue", "Danger"; voice if enabled |
| Survivor: Seized | Valid `SurvivorHit` (Downing rule 4) | Commit completes (`SurvivorDowned` / `SurvivorEliminated`) or is cancelled (`MonsterStunned`, monster disconnect) | Blocked: no input except camera (Downing States table); voice if enabled |
| Survivor: Eliminated | `SurvivorEliminated` | Round end | No pings, callouts or voice to living players **(proposed)** |
| Survivor: Escaped | `SurvivorEscaped` | Round end | No pings, callouts or voice to living players (Match Flow rule 10) |
| Monster: Disguised | `FormChanged` to a survivor form completes | A transformation starts (replicated transforming flag, Borrowed Face rule 8) | All pings and callouts as the borrowed identity, except while stunned (rule 23) or when that survivor is Eliminated or Escaped (rule 21: rejected); the borrowed survivor's other states do not restrict it |
| Monster: Transforming | A transformation starts (replicated transforming flag) | `FormChanged` on completion, or a stun interrupts it (back to the previous form) | Blocked **(proposed)** |
| Monster: True form | `FormChanged` into true form; round start | A transformation starts | Blocked **(proposed)** |

Shock is a timed lock, not a state: for `stun_duration_s` after a taser hit (`PlayerShocked`), pings and callouts are blocked on top of whatever state the survivor is in (rule 23), and every transition above still applies during it.

Existing markers persist with the identity they were sent under until they expire, even if the sender's form changes **(proposed)**.

### Interactions with Other Systems

- **Network Authority & Replication**: carries ping/callout requests and server broadcasts; supplies server-side positions and line-of-sight checks.
- **First-Person Controller & Interaction**: supplies the view ray and input bindings (ping button, callout wheel).
- **Borrowed Face**: supplies the displayed identity and Disguised/Transforming/True-form state (`FormChanged`).
- **Monster Abilities**: False Signal requests a fake callout through `AbilityUsed`; this system presents it per rules 26–29.
- **Downing, Rescue & Elimination**: `SurvivorDowned` / `SurvivorRescued` / `SurvivorEliminated` gate what a survivor can send.
- **Survivor Objectives**: defines which objects are item-pingable and their type labels.
- **Survivor Defense**: hiding spots and barricadable doors are item-pingable.
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

Initial state: `tokens = ping_bucket_size` at round start; a reconnecting player keeps the token and timestamp state they had (so a reconnect never refills the bucket); `last_callout_any` and every `last_callout[line]` start at minus infinity, so the first callout is always accepted.

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| ping_bucket_size | int | 2–5 | data | Burst size (proposed 3) |
| ping_refill_s | float | 1–4 | data | Seconds per token (proposed 2) |
| elapsed_s | float | ≥0 | server clock | Time since last update |

**Expected output**: 3 pings in a burst, then one every 2 s (30 per minute steady state; 33 in a first minute that starts with a full bucket). **Example**: three pings at t=0, a fourth at t=1 is rejected (tokens 0.5), one at t=2 is accepted.

### Callout acceptance

```
accept if (now - last_callout_any) >= callout_global_cooldown_s
      and (now - last_callout[line]) >= callout_repeat_block_s
```

Only accepted callouts update `last_callout_any` and `last_callout[line]`; a rejected request changes nothing (as with a rejected ping, which spends no token). Proposed 3 s and 8 s: at most 20 callouts per minute, and the same line at most once every 8 s. **Example**: "Danger" at t=0, "Wait" at t=3 accepted, "Danger" at t=6 rejected, "Danger" at t=8 accepted.

### Callout recipients

```
recipient if distance(origin, listener) <= range(line) and listener is living
            (the monster, as a listener, gets audio only, rule 11)
spectator (Eliminated / Escaped) receives iff the survivor they watch is a recipient
```

`range(line)` = `callout_range_m` (proposed 25) or `rescue_callout_range_m` (proposed 40). Range is straight-line distance; walls attenuate the audio but do not block delivery **(proposed)**. The origin is the speaker's position for a real callout, the chosen point for a fake.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|---|---|---|
| Disguised monster and the real survivor ping at the same time | Both markers appear under the same name | Duplicates are a learnable, fair clue |
| Monster pings an objective, then reveals | Marker keeps the borrowed name until expiry | No retroactive rewrite; survivors can reason about it |
| Client sends a ping at a point outside line of sight | Server rejects; pending marker removed | Prevents wallhack-style pinging via modified clients |
| Client spoofs a sender name | Ignored; server always attaches identity from its own state | Identity is server-owned |
| Fake callout impersonates a survivor who is eliminated | Cannot happen: Monster Abilities rejects it (designer decision, 2026-10-11) | Owner decided |
| Downed survivor spams "Need rescue" | Repeat block applies (8 s) | One clear call is enough; no audio spam |
| Survivor is rescued mid-callout | Line finishes playing | Presentation only |
| Two callouts overlap at one listener | Both play; feed shows both in arrival order | No information silently dropped |
| Survivor warning-pings a teammate who is real | Allowed; static marker where they stood, with their name | Distrust is part of play |
| Disguised monster is warning-pinged, then transforms | Marker stays where it was placed, under the old name, until expiry | Rule 5: the marker never follows a body, so it carries no transform information |
| Two bodies share the name of the warning-pinged player | Only the pinged body's position is marked; nothing attaches to the other | Rule 5 |
| Hidden survivor calls out | Line plays from the hiding spot; anyone in range can locate the spot | Rule 14a; the survivor's choice |
| Proximity voice On, monster player speaks in own voice while disguised | Heard as the player's real voice, coming from the disguised body | Rule 25 (decided 2026-10-12); the mismatch is the tell |
| Monster speaks in true form | Heard through the distortion filter from its position | Rule 25 (proposed filter) |
| Survivor warning-pings a monster in True Form | Allowed; static marker at its position labelled "Monster" | Rule 5 (decided 2026-10-12) |
| Downed survivor pings out of the monster's line of sight | Survivors receive it; the monster receives nothing | Rule 7 (decided 2026-10-12); no through-wall body locator |
| Fake callout in survivor X's name, then X sends the same line | X's callout is accepted if X's own limits allow; the fake changed no timestamps | Rule 17 (decided 2026-10-12) |
| Survivor warning-pings a player who is inside a hiding spot | Rejected; the occupant is not a valid target | Rule 6 and 7a; a ping must not reveal an occupant |
| Monster is disguised as a survivor who is then Eliminated or Escaped, and tries to ping or call out | Rejected; the disguise stays on but is silent | Rule 21 (decided 2026-10-12); a dead voice is a free tell |
| Player disconnects with active markers | Markers expire normally | No state to clean up beyond timers |

## Dependencies

| System | Direction | Nature of Dependency |
|---|---|---|
| Network Authority & Replication | This depends on it | Server validation, broadcast, positions, line of sight |
| Lobby & Role Assignment | This depends on it | Survivor character (voice set, colour) per player; the proximity voice setting (rule 18) |
| First-Person Controller & Interaction | This depends on it | View ray, input |
| Borrowed Face | This depends on it | Displayed identity, form state (`FormChanged`) |
| Match Flow & Win Conditions | This depends on it | `SurvivorEscaped` (Escaped state; Match Flow rule 10) |
| Downing, Rescue & Elimination | Bidirectional | Survivor state gates sending; Downing uses the "Need rescue" callout as its Call for Help |
| Survivor Objectives | This depends on it | Pingable object types |
| Survivor Defense | This depends on it | Pingable hiding spots and barricadable doors; the shock lock (Survivor Defense rule 14) blocks pings and callouts (rule 23) |
| Facility Map | This depends on it | Room IDs and names as callout locations; pingable backup switches |
| Monster Abilities | Bidirectional | False Signal's fake callout is presented by this system; consumes `AbilityUsed` |
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
| "(not you)" mark | Tag on own impersonated feed line, or on a nearby impersonated ping (rule 28) | None | Medium |
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

- [ ] With a survivor moving at walk speed, sending a ping and opening the callout wheel to send a callout leaves the server-recorded velocity unchanged on every tick.
- [ ] Across ≥10 playtest rounds with proximity voice Off, at most 10% of survivor players answer "yes" to the post-round question "Did you need voice to do something this round?".

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
| Pingable defenses | `design/gdd/survivor-defense.md` | Hiding spots, barricadable doors | Data dependency |
| Backup switches as pingable | `design/levels/research-facility.md` | Backup light switch placement | Data dependency |
| Callouts not masked by scares | `design/gdd/scare-events.md` | Audio ducking priority | Rule dependency |

## Acceptance Criteria

- [ ] With 5 clients, a survivor's item ping appears on the 3 other survivor clients, and on the monster's client only when the object is in the monster's line of sight, at the same object with the same sender name within 250 ms of the server accepting it, measured on a LAN or with a simulated 100 ms round trip.
- [ ] A survivor's player warning ping appears at the target's position at ping time and does not move for its lifetime, even if the target moves or transforms.
- [ ] A ping or callout request from a Seized or Escaped survivor is rejected.
- [ ] A client that sends a ping at a point outside its line of sight is rejected by the server; no other client receives it.
- [ ] A client with a full bucket (3 tokens) sending 10 pings in 1 s has exactly 3 accepted; with `ping_max_active` = 2, other clients display only the newest 2.
- [ ] A survivor's ping on a point or object outside the monster's line of sight is delivered to the 4 survivors' clients and not to the monster's client, including when the sender is Downed.
- [ ] A warning ping on a monster in True Form is accepted and shows the label "Monster" at its position at ping time.
- [ ] A fake callout leaves the impersonated survivor's and the monster player's callout cooldowns and ping tokens unchanged: the survivor's same-line callout sent 1 s after the fake is accepted.
- [ ] The same callout sent twice within 8 s is delivered once; after a callout at t=0, a different callout at t=1 is rejected and one at t=3 is accepted.
- [ ] A ping rejected by the server removes the sender's pending marker, and no other client receives it.
- [ ] "Drive here" with an attached item ping spends one ping token in addition to the callout; with 0 tokens the callout plays without the attached ping.
- [ ] An Eliminated or Escaped player's proximity voice is not delivered to any living player; their client receives exactly the pings and callouts delivered to the survivor they are watching.
- [ ] A warning ping on a survivor inside a hiding spot is rejected.
- [ ] A disguised monster's ping shows the borrowed survivor's name on every other living survivor client, and its callout shows the name and voice on every survivor client within `callout_range_m`. The copied survivor's client shows "(not you)" on a ping only when the sender is within `callout_range_m`, and always on a callout it receives.
- [ ] A disguised monster whose borrowed survivor is Downed or Seized can send any callout (for example "Drive here") when the monster itself is not stunned or transforming.
- [ ] A survivor's callout within range reaches the monster's client as audio only: the monster's client receives no feed line, name or direction field, including for "Need rescue" at 40 m through a wall.
- [ ] A hidden survivor's callout plays from the hiding spot and shows no speaker gesture; its ping is validated from the peek view.
- [ ] An item ping on an occupied hiding spot contains no occupant identity on any client.
- [ ] Monster proximity voice in True Form or while Transforming is delivered through the distortion filter; Disguised it is delivered unaltered.
- [ ] Two bodies sharing a name that both ping show two markers under that name; the server does not merge them.
- [ ] In true form and while transforming, the monster's ping and callout requests are rejected.
- [ ] A False Signal fake callout is indistinguishable from a real one in the data received by survivor clients (packet inspection of the callout message shows no real/fake field; the absent speaker gesture of rule 28 is the only permitted difference).
- [ ] A False Signal fake callout never carries an attached item ping, even when the line is "Drive here" or "Fuse here".
- [ ] A real callout plays the speaker gesture on the sender's body on every survivor client with line of sight to it; a hidden survivor's callout and a fake callout play none.
- [ ] The impersonated survivor, within range, sees "(not you)" on a fake callout; other survivors do not.
- [ ] A player outside `callout_range_m` receives neither audio nor feed line.
- [ ] A downed survivor can send "Need rescue"; an eliminated player cannot send any ping or callout.
- [ ] With proximity voice Off, each information type in rule 4 (objective found, objective location, rescue needed, danger, distrust, regroup) is sent by a client using only a ping or callout and received by the other 3 survivor clients.
- [ ] A disguised monster whose borrowed survivor is Eliminated or Escaped has its ping and callout requests rejected; one whose borrowed survivor is Downed has them accepted.
- [ ] No ping or callout changes objective, downing, stun or outcome state on the server.
- [ ] For `stun_duration_s` after a taser hit, a ping or callout from a shocked survivor or a stunned disguised monster is rejected, and the first one after it ends is accepted; after a hit on an immune disguised monster or on a survivor inside their post-lock window, it is accepted (cross-review B4).

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Monster voice: proximity voice, preset lines only, or both? | SneakKestrel16 | Before Milestone 4 | **Decided 2026-10-12: both** (rule 25). The true-form distortion filter is proposed |
| Does the monster receive survivor pings, or only those it could see in-world? | SneakKestrel16 | Before Milestone 4 | **Decided 2026-10-12: only pings whose target is in its line of sight** (rule 7) |
| Does each survivor slot have its own voice set (needed for fake callouts to imitate a specific teammate, and relied on by rules 10 and 21)? Rules 10, 21 and 26 stay **(proposed)** until this is decided | SneakKestrel16 | Before Milestone 4 | Resolved 2026-10-12: yes, one voice set per survivor character C1–C5; a survivor keeps their lobby-picked character between rounds (`lobby-role-assignment.md` rules 5–7) |
| Should a fake callout carry any authored tell beyond rule 28 (e.g. faint signal distortion), or rely only on position and verification? | SneakKestrel16 | Before Milestone 3 | |
| Are callouts positional only (proposed) or also carried over a facility radio? | SneakKestrel16 | Before Milestone 4 | |
| Is the 8-line callout set right, and is "That wasn't me" too strong a counter? | SneakKestrel16 | Before Milestone 5 | |
