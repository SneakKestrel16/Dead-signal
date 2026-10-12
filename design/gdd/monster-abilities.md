# Monster Abilities

> **Status**: Draft
> **Author**: SneakKestrel16
> **Last Updated**: 2026-10-12
> **Last Verified**: 2026-10-11
> **Implements Pillar**: Counterplay (primary), Human Deception, Fair Fear

## Summary

The shapeshifter's three active abilities besides Borrowed Face: Predatory Lunge (the only way it downs survivors), False Signal (a fake sound or callout to mislead), and Blackout (a short local loss of light). Each has a server-validated cooldown and a named survivor counter. Lunge is MVP; False Signal and Blackout are Vertical Slice.

> **Quick reference** — Layer: `Feature` · Priority: `MVP (Lunge) / Vertical Slice (False Signal, Blackout)` · Key deps: `Borrowed Face, Downing, Rescue & Elimination, Survivor Defense, Facility Map`

## Overview

The shapeshifter is a human player, and its abilities are tools for timing and manipulation, not raw power. Predatory Lunge is a short, telegraphed forward attack; if the server confirms a hit, the survivor takes a takedown. False Signal plays a fake teammate callout, footsteps or interaction sound at a nearby spot to pull survivors apart or make them doubt real sounds. Blackout kills the lights in one nearby room or short corridor for 6 seconds. Every ability is announced, short, and answerable: survivors dodge, slam doors, stun, verify, carry flashlights and retreat to light.

## Player Fantasy

**Shapeshifter:** the predator choosing its moment. The lunge lands because you read the group, not because the game handed it to you. False Signal and Blackout let you shape where survivors go and what they believe.

**Survivors:** "I heard it wind up and I made it." Every attack is something you could have answered; when you go down, you know what you did wrong.

## Detailed Design

### Core Rules

**General**

1. The server owns all ability state: cooldowns, wind-up, hit resolution, ability placement and duration. The client sends only an activation request (and an aim point where needed); the server validates and rejects invalid requests with no effect and no cooldown cost. Clients never report hits or damage.
2. No ability can be activated while the shapeshifter is Stunned or Transforming (Borrowed Face) **(proposed)**. A stun interrupts a Lunge in wind-up (owned by Survivor Defense).
3. Cooldowns are independent of each other and of the form-change cooldown **(proposed)**.

**Disguise interaction** (all **(proposed)**)

| Ability | Usable while Disguised? | Breaks the disguise? |
|---|---|---|
| Predatory Lunge | No — True Form only; transform first (2 s cue is the warning) | n/a |
| False Signal | Yes | No — sound plays at a separate location |
| Blackout | Yes | No |

**Predatory Lunge** (MVP)

4. Activation: shapeshifter in True Form, lunge cooldown ready, not Stunned or Transforming.
5. **Wind-up**: `lunge_windup_s` = 0.6 s **(proposed)**. A distinct audio cue plays from the monster's position, audible within `lunge_cue_radius_m` = 20 m **(proposed)**, plus a visible crouch-and-coil pose. The monster cannot move during wind-up but can turn at reduced rate **(proposed)**. Source canon: "clear wind-up and audible cue".
6. **Active**: the monster dashes forward `lunge_distance_m` = 4 m over 0.3 s **(proposed)** along its facing at wind-up end. Steering during the dash is limited to 30°/s **(proposed)**. Blocked by walls and closed or barricaded doors; the dash stops at the obstacle.
7. **Hit validation** (server, during active): a survivor is hit if all of these hold (all **(proposed)**):
   - the survivor is a valid takedown target as defined by Downing, Rescue & Elimination: Healthy, not Seized, and not in post-rescue or post-release grace (Downed survivors cannot be lunged); hidden survivors are also untargetable (Survivor Defense);
   - distance from the monster's attack point to the survivor's collision body is ≤ `lunge_hit_radius_m` = 1.2 m;
   - the survivor is inside a 60° forward cone;
   - unobstructed line of sight between the monster's chest and the survivor's chest (no wall, closed door, barricade);
   - the monster has not been Stunned since wind-up began.
   Latency: the server checks against survivor positions rewound by the attacker's latency up to `max_rewind_ms` = 150 ms **(proposed)**; beyond that, current positions are used. Disputes are logged (Match Telemetry).
8. A lunge hits at most one survivor (the closest valid one) **(proposed)**. On hit, the server emits `SurvivorHit` (monster, survivor, server time, position). Monster Abilities owns *whether* a hit occurred; Downing, Rescue & Elimination owns what it does.
9. **Lunge timeline** (stated identically in `downing-and-rescue.md`): wind-up → dash → **hit** → **takedown commit** (`takedown_commit_s` = 1.5 s **(proposed)**, owned by Downing, Rescue & Elimination) → **lunge resolved** (the commit completes, emitting `SurvivorDowned` or `SurvivorEliminated`, or is cancelled, e.g. by `MonsterStunned`) → **`lunge_cooldown_s` = 10 s cooldown** (source; owned here) starts at resolution. Without a hit, the lunge resolves when the dash ends or when a stun interrupts it, and the cooldown starts then **(proposed reading of "after the attack resolves")**.
10. **Miss slow**: if it resolves without a hit (including blocked by a door), the monster moves at `miss_slow_multiplier` = 0.5 × speed for `miss_slow_s` = 1.5 s **(proposed)**. The source says "missing briefly slows the monster"; values are proposed.
11. **After a hit**: there is no separate hit recovery. The takedown commit (rule 9) is the post-hit commitment: the monster is rooted and cannot use abilities or transform until it resolves (owned by Downing, Rescue & Elimination).
12. **Stun-interrupted**: a lunge interrupted by a stun produces no hit; it counts as resolved (cooldown starts) and the stun replaces the miss slow **(proposed)**.

Counters (pillar: Counterplay): **dodge sideways** (the narrow cone and short reach reward a late strafe after the cue); **slam a door** (closed or barricaded doors block both the dash and line of sight); **stun item** (interrupts wind-up or dash; owned by Survivor Defense).

**False Signal** (Vertical Slice)

13. Activation: cooldown ready; aim point chosen within `false_signal_range_m` = 20 m of the monster **(proposed)**; the server snaps it to the nearest walkable floor point and rejects points inside walls or outside the range.
14. Choose one signal type (source list):
    - **Teammate callout**: an authored callout in the voice set of a survivor the monster has *observed* (Borrowed Face) **(proposed)**. Its presentation is owned by Pings & Callouts (rules 26–29 there) and is not redefined here: it uses the same authored line, voice set and `[Name]: [text]` feed line as a real callout from that survivor, reaches listeners by the same range rule measured from the chosen point, and differs only in that it has no speaker gesture, cannot attach an item ping, and the impersonated survivor sees it marked "(not you)" **(proposed, per Pings & Callouts)**.
    - **Footsteps**: 3 s of survivor footsteps at the point, moving up to 3 m along a direction chosen by the monster **(proposed)**.
    - **Familiar interaction sound**: an objective interaction sound (e.g. drive extraction, fuse handling) or door sound **(proposed)**. It never changes objective state or alerts.
15. The sound is spatialised from the chosen point and replicated to every survivor client in hearing range as a shared event **(proposed)**. Fake sounds use the same audio assets as real ones; they carry no visual source (no body, no light, no ping marker) **(proposed)**. A fake teammate callout additionally shows its feed line as defined by Pings & Callouts.
16. Cooldown: 25 s (source), starting on activation **(proposed)**.

Counters: sound is only an **approximate clue** (source) — survivors **verify by sight** (nobody is there), **team communication** (the named survivor pings their real position), and objective state (no progress appeared on the objective whose sound played).

**Blackout** (Vertical Slice)

17. Activation: cooldown ready; the target is the lighting zone the monster is standing in or one it aims at within `blackout_range_m` = 15 m with line of sight **(proposed)**. Lighting zones are authored per room or short corridor in the Facility Map; the server rejects any zone not flagged as blackout-able (e.g. the evacuation terminal area if the map so decides).
18. Effect: all normal lights in the zone go out for `blackout_duration_s` = 6 s (source). Emergency lights remain faintly visible (source). Flashlights are unaffected **(proposed)**.
19. Backup switches (Facility Map) placed in or near blackout-able zones restore the zone's lights immediately when a survivor interacts with them for `backup_switch_hold_s` = 1 s **(proposed)**. Restoring early does not reduce the monster's cooldown.
20. One zone per Blackout; Blackout cannot target a zone already blacked out **(proposed)**. Lighting state is server-owned and replicated so every client sees the same zone dark.
21. Cooldown: 45 s (source), starting on activation **(proposed: start on activation, not on expiry)**.

Counters (source): **flashlights**, **retreat to lit areas**, **backup switches**.

### States and Transitions

Predatory Lunge:

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| Ready | Cooldown elapsed | Valid activation | Can activate |
| Wind-up | Activation accepted | 0.6 s elapse → Active; stun → Resolved (interrupted) | Audible cue, no movement |
| Active | Wind-up complete | Hit → Takedown Commit; dash end, obstacle, stun → Resolved | Dash; server hit checks |
| Takedown Commit | Hit (`SurvivorHit` emitted) | Commit completes or is cancelled → Resolved | Owned by Downing, Rescue & Elimination (`takedown_commit_s` = 1.5 s, proposed); monster rooted |
| Resolved | Commit end, or a no-hit exit from Wind-up/Active | Immediate → Cooldown | Applies miss slow on a miss |
| Cooldown | Resolved | 10 s elapsed → Ready | Cannot lunge; may transform once any miss slow has ended **(proposed)** |

False Signal and Blackout each have Ready → Active (signal playing / zone dark) → Cooldown → Ready.

### Interactions with Other Systems

- **Downing, Rescue & Elimination**: consumes `SurvivorHit`. Downed survivors are not valid lunge targets.
- **Survivor Defense**: `MonsterStunned` interrupts Lunge; barricaded doors block the dash; flashlights counter Blackout.
- **Borrowed Face**: Lunge needs True Form; no ability during Transforming; transformation cannot start during Lunge wind-up, active or takedown commit; False Signal callouts use the observed-survivor list.
- **Pings & Callouts**: owns the authored callout set and the fake-callout presentation rule (same line, voice and feed line; no gesture, no item ping, "(not you)" mark).
- **Facility Map**: lighting zones, blackout-able flags, emergency lights, backup switches, doors.
- **Scare Events**: Blackout can trigger a lighting scare state; a lunge out of a hiding place counts as a player-triggered scare. Scare Events owns those presentations and cooldowns; scares never delay or block the ability.
- **Match Telemetry**: logs every lunge (hit/miss/interrupted, latency rewind used), False Signal type, Blackout zone.
- **HUD & Results Screen**: cooldowns on the shapeshifter HUD; attack counts in results.

## Formulas

### Lunge hit check

```
hit = survivor.state == Healthy
      and dist(attack_point, survivor_body) <= lunge_hit_radius_m
      and angle(monster_forward, to_survivor) <= lunge_cone_deg / 2
      and line_of_sight(monster_chest, survivor_chest)
      and not stunned_since(windup_start)
check positions at: server_time - min(attacker_latency, max_rewind_ms)
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| lunge_hit_radius_m | float | 0.8–2.0 | data | Reach beyond the dash path **(proposed 1.2)** |
| lunge_cone_deg | float | 40–90 | data | Forward cone **(proposed 60)** |
| lunge_distance_m | float | 2–6 | data | Dash length **(proposed 4)** |
| max_rewind_ms | int | 0–250 | data | Latency compensation cap **(proposed 150)** |

**Effective threat reach** ≈ `lunge_distance_m + lunge_hit_radius_m` = 5.2 m.
**Dodge window**: a survivor running at 4.5 m/s (example speed; controller-owned) who strafes on the cue moves ~2.7 m sideways during 0.6 s wind-up, enough to leave a 60° cone at 3 m range (half-width ≈ 1.7 m).

### Cooldown timing

```
resolve_time          = hit_time + takedown_commit_s (on a hit; commit cancelled earlier → cancel time)
                        or dash_end / stun time (no hit)
lunge_ready_time      = resolve_time + lunge_cooldown_s          (10)
false_signal_ready    = activate_time + false_signal_cooldown_s  (25)
blackout_ready        = activate_time + blackout_cooldown_s      (45)
```

Fastest lunge cycle after a miss: 0.6 wind-up + 0.3 dash + 10 cooldown = 10.9 s.
Fastest cycle after a hit whose commit completes: 0.6 wind-up + up to 0.3 dash + 1.5 commit + 10 cooldown ≈ 12.4 s.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|---|---|---|
| Two survivors in the cone | Closest valid one is hit; only one `SurvivorHit` | One takedown per commitment |
| Survivor closes a door during the dash | Dash stops; LOS fails; counts as miss with slow | Slam-a-door counter |
| Stun lands during wind-up | No dash, no hit; cooldown starts | Stun interrupts attacks (source) |
| Client shows a hit, server says miss | Server wins; logged as dispute | Never trust client damage |
| Survivor becomes Downed by another cause mid-dash | Not a valid target | Hit checks current state |
| Lunge while Disguised | Rejected | Requires True Form (kept for now; playtest) |
| False Signal aimed through a wall | Allowed if within range; sound plays there | Sound travels; sight verifies |
| False Signal callout as an unobserved survivor | Rejected | Uses observed list |
| Blackout on the evacuation zone | Allowed unless Facility Map flags it not blackout-able | Map owns zone flags |
| Backup switch used then monster recasts | Cannot until 45 s cooldown ends | Counter must matter |
| Round ends during Blackout | Lights state reset by Match Flow | Clean results |

## Dependencies

| System | Direction | Nature of Dependency |
|---|---|---|
| Borrowed Face | This depends on it | Form gates Lunge; observed list |
| Survivor Defense | This depends on it | Stun interrupts; barricades block; flashlights |
| Facility Map | This depends on it | Lighting zones, emergency lights, backup switches, doors |
| Network Authority & Replication | This depends on it | Server validation, latency rewind, replication |
| First-Person Controller & Interaction | This depends on it | Movement for dash and slow; backup switch hold |
| Pings & Callouts | This depends on it | Authored callout set; fake-callout presentation |
| Downing, Rescue & Elimination | Bidirectional | Consumes `SurvivorHit`; this system reads takedown eligibility and the commit end (lunge resolved) from it |
| Match Flow & Win Conditions | This depends on it | `RoundPhaseChanged`, round end (resets); supplies ability stats for results |
| Survivor Objectives | This depends on it | Objective interaction sounds imitated by False Signal; install alert is sent to the shapeshifter |
| Scare Events | Depends on this | Lunge and Blackout as scare triggers |
| Match Telemetry | Depends on this | Attack/stun dispute logs |
| HUD & Results Screen | Depends on this | Cooldown display, attack stats |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| lunge_cooldown_s | 10 (source) | 6–20 | Fewer attempts | Pressure spikes |
| lunge_windup_s | 0.6 (proposed) | 0.4–1.0 | Easier dodge | Unfair, unreadable |
| lunge_distance_m | 4 (proposed) | 2–6 | More reach | Must get very close |
| lunge_hit_radius_m | 1.2 (proposed) | 0.8–2.0 | Forgiving for monster | Whiffs feel unfair to monster |
| lunge_cone_deg | 60 (proposed) | 40–90 | Sideways dodge weaker | Too precise |
| miss_slow_multiplier / miss_slow_s | 0.5 / 1.5 (proposed) | 0.3–0.8 / 0.5–3 | Misses punished harder | Misses nearly free |
| max_rewind_ms | 150 (proposed) | 0–250 | Favors high-ping monster | Favors survivors |
| false_signal_cooldown_s | 25 (source) | 15–60 | Fake sounds rarer, more credible | Noise spam; real sounds devalued |
| false_signal_range_m | 20 (proposed) | 10–30 | Wider misdirection | Locates the monster |
| blackout_duration_s | 6 (source) | 3–10 | Stronger ambush | Barely matters |
| blackout_cooldown_s | 45 (source) | 30–90 | Rarer | Map feels permanently dark |
| backup_switch_hold_s | 1 (proposed) | 0.5–3 | Counter riskier | Counter trivial |

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|---|---|---|---|
| Lunge wind-up | Coil pose | Distinct cue, 20 m, directional | MVP |
| Lunge hit | Impact on survivor | Hit sound | MVP |
| Lunge miss | Monster stumble/slow | Scrape | MVP |
| False Signal | None in the world (by design); fake callout shows a feed line per Pings & Callouts | Chosen sound at point | VS |
| Blackout | Zone lights out; faint emergency lights | Power-cut thunk | VS |
| Backup switch | Lights return | Relay clack | VS |

## Game Feel

### Feel Reference

Lunge: Dead by Daylight's lunge — committed and telegraphed, with a punishing miss. Anti-reference: an instant hitscan melee with no tell.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|---|---|---|---|
| Lunge start (local pose + cue) | 50 | 3 | Predicted locally; server confirms |
| False Signal / Blackout | 150 | 9 | Server-confirmed effect |

### Animation Feel Targets

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|---|---|---|---|---|---|
| Predatory Lunge | 36 (0.6 s) | 18 (0.3 s) | hit: takedown commit (Downing) / 90 miss | Weighty, committed | Proposed values |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|---|---|---|---|
| Hit-stop | 80 | Brief freeze on server-confirmed hit only | Yes |
| Camera impact (survivor hit) | 200 | Jolt, no input lock beyond downing rules | Yes |

### Weight and Responsiveness Profile

- **Weight**: heavy and committed; once the dash starts, the monster is locked in.
- **Player control**: survivors keep full control throughout (Fair Fear).
- **Failure texture**: a missed monster feels slowed and exposed; a hit survivor heard the cue.

### Feel Acceptance Criteria

- [ ] Survivors who were hit report that they heard the wind-up.
- [ ] No playtester describes a hit as having come from "nowhere".

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|---|---|---|---|
| Ability cooldowns | Shapeshifter HUD | Each 0.1 s | Shapeshifter only |
| False Signal placement preview | Shapeshifter world marker | Continuous | While aiming |
| Blackout target zone | Shapeshifter world highlight | Continuous | While aiming |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|---|---|---|---|
| Hit outcome | `design/gdd/downing-and-rescue.md` | `SurvivorHit` handling, takedown commit (`takedown_commit_s`), eligibility | Ownership handoff |
| Imitated interaction sounds | `design/gdd/survivor-objectives.md` | Objective interaction sounds, fake-interaction rule | Data dependency |
| Stun interrupts | `design/gdd/survivor-defense.md` | `MonsterStunned`, barricades, flashlight | State trigger |
| True Form requirement, observed list | `design/gdd/borrowed-face.md` | Disguise state | Rule dependency |
| Fake callout presentation | `design/gdd/pings-and-callouts.md` | Authored callouts, monster voice rules | Rule dependency |
| Lighting zones, switches | `design/levels/research-facility.md` | Zones, emergency lights, backup switches | Data dependency |
| Scare presentation | `design/gdd/scare-events.md` | `ScareTriggered`, lighting scare state | Ownership handoff |
| Round reset | `design/gdd/match-flow.md` | `RoundPhaseChanged`, round end | State trigger |

## Acceptance Criteria

- [ ] Lunge plays its cue 0.6 s before the dash; a survivor 20 m away hears it from the correct direction.
- [ ] Server rejects a lunge during cooldown, while Disguised, while Stunned, or while Transforming.
- [ ] A survivor behind a closed door 1 m from the monster is never hit.
- [ ] A miss slows the monster to 50% for 1.5 s; the next lunge is accepted no earlier than 10 s after resolution.
- [ ] After a hit whose takedown commit completes at time T (or is cancelled by a stun at time T), the next lunge is rejected before T + 10 s and accepted at T + 10 s.
- [ ] A stun during wind-up produces no `SurvivorHit`.
- [ ] **Multi-client**: across 20 lunges with 5 clients connected (including one at 150 ms simulated latency), all 5 clients agree on every hit/miss and the survivor's resulting state; every dispute is logged.
- [ ] False Signal is rejected within 25 s of the previous one; a callout naming an unobserved survivor is rejected; objective state is never changed by a fake interaction sound.
- [ ] **Multi-client**: Blackout darkens the same zone on all 5 clients for 6 s (±1 tick) with emergency lights visible; a backup switch restores it on all clients.
- [ ] All values are read from data, not hardcoded.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Are the Lunge values (0.6 s wind-up, 4 m dash, 1.2 m radius, 60° cone, 0.5×/1.5 s miss slow) right? | SneakKestrel16 | Before Milestone 3 | — |
| Does a fake callout look exactly like a real one (HUD text, marker)? | SneakKestrel16 | Before Milestone 3 | Owned by Pings & Callouts (rules 26–29); this doc follows it |
| Can False Signal impersonate an Eliminated survivor? (Pings & Callouts defers this here) | SneakKestrel16 | Before Milestone 3 | Open |
| Should Lunge be usable from disguise? | SneakKestrel16 | Before Milestone 5 | **Kept True Form only for now (2026-10-12); test in the M5 playtest.** Test plan lives in Borrowed Face's Open Questions |
| Which zones are blackout-able, and is the evacuation area excluded? | SneakKestrel16 | Before Milestone 3 | Facility Map |
| Does the Blackout cooldown start at activation or at expiry? | SneakKestrel16 | Before Milestone 5 | — |
| Latency rewind cap (150 ms) — acceptable for the chosen hosting model? | SneakKestrel16 | Before Milestone 1 | Network Authority ADR |
