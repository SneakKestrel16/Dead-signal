# Monster Abilities

> **Status**: In Review
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
2. No ability can be activated while the shapeshifter is Stunned, under the shock lock (Survivor Defense rule 14, which includes an immune hit on a disguised shapeshifter), Transforming (Borrowed Face), or in Lunge wind-up, Active or takedown commit **(proposed)**. A lunge is a committed, telegraphed action; no hidden second action rides on it. A stun interrupts a Lunge in wind-up (owned by Survivor Defense).
3. Cooldowns are independent of each other and of the form-change cooldown **(proposed)**.
3a. On every validated activation (Lunge wind-up start, False Signal, Blackout) the server emits `AbilityUsed` (systems-index event table) carrying the ability, the monster's position and facing, the target point or zone, and for False Signal the signal type and, for a callout, the impersonated survivor **(proposed)**. Scare Events and Pings & Callouts consume it; rejected requests emit nothing. `AbilityUsed` is server-internal and is never replicated to survivor clients: it carries the monster's position, which would locate a disguised shapeshifter. Consumers replicate only the effect they present (the sound, the dark zone, the feed line) **(proposed)**.

**Disguise interaction** (all **(proposed)**)

| Ability | Usable while Disguised? | Breaks the disguise? |
|---|---|---|
| Predatory Lunge | No — True Form only; transform first (2 s cue is the warning) | n/a |
| False Signal | Yes | No — sound plays at a separate location |
| Blackout | Yes | No |

**Predatory Lunge** (MVP)

4. Activation: shapeshifter in True Form, lunge cooldown ready, not Stunned, not under the shock lock (Survivor Defense rule 14) and not Transforming.
5. **Wind-up**: `lunge_windup_s` = 0.6 s **(proposed)**. A distinct audio cue plays from the monster's position, audible within `lunge_cue_radius_m` = 20 m **(proposed)**, plus a visible crouch-and-coil pose. The monster cannot move during wind-up and turns at no more than `lunge_windup_turn_deg_s` = 15°/s **(proposed, designer decision 2026-10-11)**, so a survivor who strafes within a realistic reaction time still leaves the dash path (Formulas, Dodge window). Source canon: "clear wind-up and audible cue".
6. **Active**: the monster dashes forward `lunge_distance_m` = 4 m over `lunge_dash_s` = 0.3 s **(proposed)** along its facing at wind-up end. Steering during the dash is limited to `lunge_dash_turn_deg_s` = 30°/s **(proposed)**. Blocked by walls, closed or barricaded doors, and the body of any survivor who is not a valid target (rule 7); the dash stops at the obstacle and the lunge resolves as a miss **(proposed; body rule designer decision 2026-10-11)**.
7. **Hit validation** (server, every server tick of Active): a survivor is hit if all of these hold (all **(proposed)**):
   - the survivor is a valid takedown target as defined by Downing, Rescue & Elimination: Healthy, not Seized, and not in post-rescue or post-release grace (Downed survivors cannot be lunged); hidden survivors are also untargetable (Survivor Defense);
   - distance from the monster's attack point (the centre of its collision body at chest height, designer decision 2026-10-11) to the survivor's collision body is ≤ `lunge_hit_radius_m` = 1.2 m;
   - the survivor is inside a 60° forward cone measured from the same attack point;
   - unobstructed line of sight between the monster's chest and the survivor's chest (no wall, closed door, barricade);
   - the monster has not been Stunned since wind-up began.
   Latency: the server checks against survivor positions rewound by the attacker's latency up to `max_rewind_ms` = 150 ms **(proposed)**; beyond that, current positions are used. Only positions are rewound: eligibility (Healthy, hidden, grace, Seized) and the stun check use current server state. Disputes are logged (Match Telemetry).
8. A lunge hits at most one survivor: the first tick with one or more survivors passing rule 7 hits the closest of them on that tick, and the hit ends the dash immediately **(proposed, designer decision 2026-10-11)**. On hit, the server emits `SurvivorHit` (monster, survivor, server time, position). Monster Abilities owns *whether* a hit occurred; Downing, Rescue & Elimination owns what it does.
9. **Lunge timeline** (stated identically in `downing-and-rescue.md`): wind-up → dash → **hit** → **takedown commit** (`takedown_commit_s` = 1.5 s **(proposed)**, owned by Downing, Rescue & Elimination) → **lunge resolved** (the commit completes, emitting `SurvivorDowned` or `SurvivorEliminated`, or is cancelled, e.g. by `MonsterStunned`) → **`lunge_cooldown_s` = 10 s cooldown** (source; owned here) starts at resolution. Without a hit, the lunge resolves when the dash ends or when a stun interrupts it, and the cooldown starts then **(proposed reading of "after the attack resolves")**.
10. **Miss slow**: if it resolves without a hit (including blocked by a door), the monster moves at `miss_slow_multiplier` = 0.5 × speed for `miss_slow_s` = 1.5 s **(proposed)**. The source says "missing briefly slows the monster"; values are proposed.
11. **After a hit**: there is no separate hit recovery. The takedown commit (rule 9) is the post-hit commitment: the monster is rooted and cannot use abilities or transform until it resolves (owned by Downing, Rescue & Elimination).
12. **Stun-interrupted**: a lunge interrupted by a stun produces no hit; it counts as resolved (cooldown starts) and the stun replaces the miss slow **(proposed)**.

Counters (pillar: Counterplay): **dodge sideways** (the narrow cone and short reach reward a late strafe after the cue); **slam a door** (closed or barricaded doors block both the dash and line of sight); **stun item** (interrupts wind-up or dash; owned by Survivor Defense).

**False Signal** (Vertical Slice)

13. Activation: cooldown ready; aim point chosen within `false_signal_range_m` = 20 m of the monster **(proposed)**; the server snaps it to the nearest walkable floor point and rejects points inside walls or outside the range.
14. Choose one signal type (source list):
    - **Teammate callout**: an authored callout in the voice set of a survivor the monster has *observed* (Borrowed Face) and who is not Eliminated or Escaped (designer decision, 2026-10-11) **(proposed)**. Its presentation is owned by Pings & Callouts (rules 26–29 there) and is not redefined here: it uses the same authored line, voice set and `[Name]: [text]` feed line as a real callout from that survivor, reaches listeners by the same range rule measured from the chosen point, and differs only in that it has no speaker gesture, cannot attach an item ping, and the impersonated survivor sees it marked "(not you)" **(proposed, per Pings & Callouts)**.
    - **Footsteps**: 3 s of survivor footsteps at the point, moving up to 3 m along a direction chosen by the monster **(proposed)**.
    - **Familiar interaction sound**: an objective interaction sound (e.g. drive extraction, fuse handling) or door sound **(proposed)**. It never changes objective state or alerts.
15. The sound is spatialised from the chosen point and replicated as a shared event to every survivor client within the audible range of the real sound it imitates (the same asset and attenuation; for a callout, the Pings & Callouts range rule) **(proposed)**. Fake sounds use the same audio assets as real ones; they carry no visual source (no body, no light, no ping marker) **(proposed)**. A fake teammate callout additionally shows its feed line as defined by Pings & Callouts.
16. Cooldown: 25 s (source), starting on activation **(proposed)**.

Counters: sound is only an **approximate clue** (source) — survivors **verify by sight** (nobody is there), **team communication** (the named survivor pings their real position), and objective state (no progress appeared on the objective whose sound played).

**Blackout** (Vertical Slice)

17. Activation: cooldown ready; the target is the lighting zone the monster is standing in or one it aims at within `blackout_range_m` = 15 m with line of sight **(proposed)**. Lighting zones are authored per room or short corridor in the Facility Map; the server rejects any zone whose `blackout_able` flag is false (defined per lighting volume in `research-facility.md`; the active terminal room is excluded during Evacuation).
18. Effect: all normal lights in the zone go out for `blackout_duration_s` = 6 s (source). Emergency lights remain faintly visible (source). Flashlights are unaffected **(proposed)**.
19. A backup switch (Facility Map: one per room, none in corridors) restores only the zone containing it, immediately, when a survivor interacts with it for `backup_switch_hold_s` = 1 s **(proposed)**. Restoring early does not reduce the monster's cooldown.
20. One zone per Blackout; Blackout cannot target a zone already blacked out **(proposed)**. Lighting state is server-owned and replicated so every client sees the same zone dark.
21. Cooldown: 45 s (source), starting on activation **(proposed: start on activation, not on expiry)**.

Counters (source): **flashlights**, **retreat to lit areas**, **backup switches** (rooms only; a corridor Blackout has no switch and runs its full duration, designer decision 2026-10-11).

### States and Transitions

Predatory Lunge:

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| Ready | Cooldown elapsed | Valid activation | Can activate |
| Wind-up | Activation accepted | 0.6 s elapse → Active; stun → Resolved (interrupted) | Audible cue, no movement |
| Active | Wind-up complete | Hit → Takedown Commit; dash end, obstacle, stun → Resolved | Dash; server hit checks |
| Takedown Commit | Hit (`SurvivorHit` emitted) | Commit completes or is cancelled → Resolved | Owned by Downing, Rescue & Elimination (`takedown_commit_s` = 1.5 s, proposed); monster rooted |
| Resolved | Commit end, or a no-hit exit from Wind-up/Active | Immediate → Cooldown | Applies miss slow on a miss |
| Cooldown | Resolved | 10 s elapsed → Ready | Cannot lunge; may transform when Borrowed Face rule 7 allows (miss slow does not block it) |

False Signal and Blackout each go Ready → Active (signal playing / zone dark) and back to Ready when their cooldown ends. The cooldown runs from activation (rules 16 and 21), so it overlaps the Active state; it is not a separate phase after it.

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
hit = is_valid_takedown_target(survivor)   # Downing rule 3: Healthy, not hidden, no grace, no active commit
      and dist(attack_point, survivor_body) <= lunge_hit_radius_m   # attack_point = monster centre, chest height
      and angle(monster_forward, attack_point → survivor) <= lunge_cone_deg / 2
      and line_of_sight(monster_chest, survivor_chest)
      and not stunned_since(windup_start)
evaluated: every server tick of Active; first tick with any hit → closest wins, dash ends
check positions at: server_time - min(attacker_latency, max_rewind_ms)   # eligibility and stun: current state
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| lunge_hit_radius_m | float | 0.8–1.25 | data | Reach beyond the dash path **(proposed 1.2)**; above ~1.29 the 0.40 s strafe is caught |
| lunge_cone_deg | float | 40–70 | data | Forward cone **(proposed 60)**; from ~72 the 0.40 s strafe is caught |
| lunge_dash_s | float | 0.2–0.5 | data | Dash duration **(proposed 0.3)** |
| lunge_dash_turn_deg_s | float | 0–30 | data | Steering during the dash **(proposed 30)** |
| lunge_distance_m | float | 2–6 | data | Dash length **(proposed 4)** |
| max_rewind_ms | int | 0–250 | data | Latency compensation cap **(proposed 150)** |
| lunge_windup_turn_deg_s | float | 0–17 | data | Turn rate during wind-up **(proposed 15)** |
| survivor_reaction_s | float | — | design target | Strafe delay after the cue the dodge must survive: 0.25 s reaction + `max_rewind_ms` (designer decision 2026-10-11) |

**Effective threat reach** ≈ `lunge_distance_m + lunge_hit_radius_m` = 5.2 m.
**Dodge window** (designer decision 2026-10-11): the dodge must survive a survivor who starts strafing `survivor_reaction_s` = 0.25 s reaction + 0.15 s full rewind = 0.40 s after the cue. A survivor 3 m ahead running at 4.5 m/s (example speed; controller-owned) who strafes from 0.40 s is ~0.9 m sideways at dash start and ~2.25 m at dash end.
Worked by stepping the per-tick check (0.5 ms steps; dash modelled as a straight line at its final heading, which overstates the monster's reach). The deciding moment is mid-dash, not dash end: at dash end the survivor is ~0.8 m behind the monster and outside the cone. The closest in-cone approach is at ~0.17 s into the dash, with the survivor on the cone edge. At 18° off the starting facing that approach is 1.30 m (miss against 1.2 m). A hit needs ~19.5°.
The monster reaches `lunge_windup_turn_deg_s` × `lunge_windup_s` + `lunge_dash_turn_deg_s` × `lunge_dash_s` = 9° + 9° = 18°, so that strafe dodges. The margin is ~0.1 m, or ~20 ms: at 18° a strafe from 0.42 s is caught. Above ~17°/s wind-up turn, `lunge_hit_radius_m` above ~1.29 or `lunge_cone_deg` from ~72, the 0.40 s strafe is caught; those set the safe-range ceilings. A strafe on the cue needs ~47° to catch. A strafe from 0.45 s needs only ~15°.
**Survivor latency** (designer decision 2026-10-11, accepted): the 0.40 s budget covers the monster's rewind only. The survivor hears the cue one-way late, and their strafe reaches the server one-way late, so their round trip comes out of the 0.25 s reaction. A survivor at 100 ms RTT must react in ~0.15 s.
Distances and the cone are measured from the monster's centre at chest height (rule 7). The survivor's collision radius is undefined until the First-Person Controller GDD sets it; a nonzero radius narrows the window (inference: recompute when the radius is set, and lower the turn rate or `lunge_hit_radius_m` if the 0.40 s strafe no longer dodges). Rerun this check after any change to wind-up, turn rates, dash length or time, radius or cone: they are coupled.

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
| Survivor enters grace, hiding or another commit mid-dash | Not a valid target | Hit checks current state |
| Lunge while Disguised | Rejected | Requires True Form (kept for now; playtest) |
| False Signal aimed through a wall | Allowed if within range; sound plays there | Sound travels; sight verifies |
| False Signal callout as an unobserved survivor | Rejected | Uses observed list |
| False Signal callout as an Eliminated survivor | Rejected | Designer decision, 2026-10-11: a dead voice is a free tell, and survivors gain nothing from it |
| False Signal callout as an Escaped survivor | Rejected **(proposed)** | Same as Eliminated: the survivor has left the facility, so the voice is a free tell |
| Dash meets a survivor who is not a valid target (hidden, grace, Downed, Seized) | Dash stops at the body; miss with slow | Designer decision, 2026-10-11: no pass-through or clipping |
| Blackout active in the terminal room when Evacuation starts | Blackout ends at that moment; cooldown unchanged | Owned by Facility Map (`research-facility.md`, `blackout_able`) |
| Blackout on the evacuation zone | Rejected for the active terminal room during Evacuation; allowed before it (`blackout_able`, Facility Map) | Map owns zone flags |
| Backup switch used then monster recasts | Cannot until 45 s cooldown ends | Counter must matter |
| Monster disconnects mid-lunge | Wind-up or dash ends with no hit; a takedown commit is cancelled by Downing on `PlayerConnectionChanged`. No cooldown matters: Match Flow removes the character | Disconnect rule owned by Match Flow **(proposed)** |
| Round ends during Blackout | Facility Map ends the Blackout and resets lighting on `RoundEnded` (`research-facility.md` Lighting States, Reset row) | Clean results; the map owns lighting state |

## Dependencies

| System | Direction | Nature of Dependency |
|---|---|---|
| Borrowed Face | Bidirectional | Form gates Lunge; observed list; reads Lunge state to block transformation (its rule 7) |
| Survivor Defense | Bidirectional | Stun interrupts; barricades block; flashlights; reads Lunge wind-up to end stun immunity |
| Facility Map | This depends on it | Lighting zones, emergency lights, backup switches, doors |
| Network Authority & Replication | This depends on it | Server validation, latency rewind, replication |
| First-Person Controller & Interaction | This depends on it | Movement for dash and slow; backup switch hold |
| Pings & Callouts | Bidirectional | Authored callout set and fake-callout presentation; consumes `AbilityUsed` for False Signal |
| Downing, Rescue & Elimination | Bidirectional | Consumes `SurvivorHit`; this system reads takedown eligibility and the commit end (lunge resolved) from it |
| Match Flow & Win Conditions | Bidirectional | `RoundPhaseChanged`, round end (resets); supplies ability stats for results |
| Survivor Objectives | This depends on it | Objective interaction sounds imitated by False Signal; install alert is sent to the shapeshifter |
| Scare Events | Depends on this | Lunge and Blackout as scare triggers |
| Match Telemetry | Depends on this | Attack/stun dispute logs |
| HUD & Results Screen | Depends on this | Cooldown display, attack stats |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| lunge_cooldown_s | 10 (source) | 6–20 | Fewer attempts | Pressure spikes |
| lunge_windup_s | 0.6 (proposed) | 0.4–1.0 | Easier dodge | Unfair, unreadable |
| lunge_windup_turn_deg_s | 15 (proposed) | 0–17 | Monster tracks strafes; above ~17 a 0.40 s strafe is caught | Facing locked early; strafing too safe |
| lunge_distance_m | 4 (proposed) | 2–6 | More reach | Must get very close |
| lunge_dash_s | 0.3 (proposed) | 0.2–0.5 | Slower dash, more steering time | Snappier dash |
| lunge_dash_turn_deg_s | 30 (proposed) | 0–30 | Dash tracks strafes; breaks the dodge window | Dash straight; strafing safer |
| lunge_cue_radius_m | 20 (proposed) | 15–30 | More survivors warned | Cue missed at range |
| lunge_hit_radius_m | 1.2 (proposed) | 0.8–1.25 | Forgiving for monster; above ~1.29 the 0.40 s strafe is caught | Whiffs feel unfair to monster |
| lunge_cone_deg | 60 (proposed) | 40–70 | Sideways dodge weaker; from ~72 the 0.40 s strafe is caught | Too precise |
| miss_slow_multiplier / miss_slow_s | 0.5 / 1.5 (proposed) | 0.3–0.8 / 0.5–3 | Misses punished harder | Misses nearly free |
| max_rewind_ms | 150 (proposed) | 0–250 | Favors high-ping monster | Favors survivors |
| false_signal_cooldown_s | 25 (source) | 15–60 | Fake sounds rarer, more credible | Noise spam; real sounds devalued |
| false_signal_range_m | 20 (proposed) | 10–30 | Wider misdirection | Locates the monster |
| blackout_duration_s | 6 (source) | 3–10 | Stronger ambush | Barely matters |
| blackout_range_m | 15 (proposed) | 8–25 | Ambush from further away | Must be near the target zone |
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
| Predatory Lunge | 36 (0.6 s) | 18 (0.3 s) | hit: takedown commit (Downing) / miss: none, movement slowed 90 frames (rule 10) | Weighty, committed | Proposed values |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|---|---|---|---|
| Hit-stop | 80 | Brief visual freeze on server-confirmed hit only; presentation-only, no simulation pause and no input lock | Yes |
| Camera impact (survivor hit) | 200 | Jolt, no input lock beyond downing rules | Yes |

### Weight and Responsiveness Profile

- **Weight**: heavy and committed; once the dash starts, the monster is locked in.
- **Player control**: survivors keep full control throughout (Fair Fear).
- **Failure texture**: a missed monster feels slowed and exposed; a hit survivor heard the cue.

### Feel Acceptance Criteria

- [ ] In a playtest of at least 10 rounds, at least 80% of hit survivors answer yes to "did you hear the cue before the hit?" **(proposed threshold)**.
- [ ] In the same playtest, 0 post-round surveys select "the hit came from nowhere".

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

- [ ] Lunge plays its cue 0.6 s before the dash; a survivor 20 m away hears it from a bearing within ±15° of the monster's true bearing **(proposed tolerance)**.
- [ ] Server rejects a lunge during cooldown, while Disguised (Borrowed Face rule 11, kept until playtest), while Stunned, or while Transforming.
- [ ] Server rejects a lunge, False Signal or Blackout from a disguised shapeshifter during the `stun_duration_s` after an immune taser hit (shock lock, Survivor Defense rule 14), and accepts them once the lock ends.
- [ ] A survivor behind a closed door 1 m from the monster is never hit.
- [ ] A dash whose path meets a hidden, grace, Downed or Seized survivor stops at that body, emits no `SurvivorHit`, and applies the miss slow.
- [ ] A miss slows the monster to 50% for 1.5 s; the next lunge is accepted no earlier than 10 s after resolution.
- [ ] A transformation request during the miss slow is accepted when Borrowed Face rule 7's conditions hold.
- [ ] After a hit whose takedown commit completes at time T (or is cancelled by a stun at time T), the next lunge is rejected before T + 10 s and accepted at T + 10 s.
- [ ] A stun during wind-up produces no `SurvivorHit`.
- [ ] During wind-up the monster's facing changes by no more than 15°/s, and during the dash by no more than 30°/s; with the monster at 150 ms latency, a survivor 3 m ahead who strafes at `survivor_move_speed` starting 0.25 s after the cue is not hit (4.5 m/s example until the Controller GDD sets the speed).
- [ ] With the monster at 150 ms latency, hit checks use survivor positions rewound 150 ms; at 300 ms they use positions rewound 150 ms (the cap). A survivor who became hidden or entered grace after the rewound time is not hit.
- [ ] While a lunge is in wind-up, Active or takedown commit, False Signal and Blackout requests are rejected with no cooldown cost.
- [ ] With two valid survivors in the cone, only the closer one receives `SurvivorHit`, and the dash ends on the hit tick.
- [ ] A survivor in post-rescue or post-release grace, or hidden, inside the cone and radius is not hit.
- [ ] A stun during the dash ends it with no `SurvivorHit`, and the cooldown starts at the stun.
- [ ] Using False Signal or Blackout while Disguised is accepted and leaves the disguise intact.
- [ ] Using one ability does not change the other abilities' cooldowns or the form-change cooldown.
- [ ] Every `AbilityUsed` stays on the server; a packet capture on a survivor client shows no `AbilityUsed` and no monster position from it.
- [ ] Every accepted Lunge, False Signal and Blackout emits exactly one `AbilityUsed` with its ability, position and target; a rejected request emits none.
- [ ] **Multi-client**: across 20 lunges with 5 clients connected (including one at 150 ms simulated latency), all 5 clients agree on every hit/miss and the survivor's resulting state; every dispute is logged.
- [ ] False Signal is rejected within 25 s of the previous one; a callout naming an unobserved, Eliminated or Escaped survivor is rejected; Footsteps play for 3 s and move no more than 3 m from the aim point; an aim point beyond 20 m or inside a wall is rejected; objective state is never changed by a fake interaction sound.
- [ ] **Multi-client**: Blackout darkens the same zone on all 5 clients for 6 s (±1 tick) with emergency lights visible; a backup switch held for 1 s restores its own zone on all clients and no other zone, and releasing it earlier does not. Blackout is rejected on a zone whose `blackout_able` is false or that is already dark. Flashlights in the zone stay lit.
- [ ] Changing any Tuning Knobs value in the data file changes in-game behavior with no code change, and ability code contains no literal for those parameters.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Are the Lunge values (0.6 s wind-up, 4 m dash, 1.2 m radius, 60° cone, 0.5×/1.5 s miss slow) right? | SneakKestrel16 | Before Milestone 3 | — |
| Does a fake callout look exactly like a real one (HUD text, marker)? | SneakKestrel16 | Before Milestone 3 | Owned by Pings & Callouts (rules 26–29); this doc follows it |
| Can False Signal impersonate an Eliminated survivor? (Pings & Callouts defers this here) | SneakKestrel16 | Before Milestone 3 | **Settled:** no (designer decision, 2026-10-11); rule 14, edge case and AC |
| Should Lunge be usable from disguise? | SneakKestrel16 | Before Milestone 5 | **Kept True Form only for now (2026-10-12); test in the M5 playtest.** Test plan lives in Borrowed Face's Open Questions |
| Which zones are blackout-able, and is the evacuation area excluded? | SneakKestrel16 | Before Milestone 3 | Facility Map. **Proposed 2026-10-11 (re-review R4):** every volume except the active terminal room during Evacuation |
| Does the Blackout cooldown start at activation or at expiry? | SneakKestrel16 | Before Milestone 5 | Proposed at activation (rule 21); confirm in playtest |
| Does the lunge dodge survive a 0.40 s strafe once the survivor collision radius is set? | SneakKestrel16 | With the Controller GDD | Recompute Formulas, Dodge window |
| Latency rewind cap (150 ms) — acceptable for the chosen hosting model? | SneakKestrel16 | Before Milestone 1 | Network Authority ADR |
| Is a ~0.15 s reaction acceptable for a survivor at 100 ms RTT? (survivor RTT comes out of the 0.25 s budget) | SneakKestrel16 | Network Authority ADR | Accepted for now (2026-10-11); revisit with the hosting model |
