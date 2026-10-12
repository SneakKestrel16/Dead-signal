# Downing, Rescue & Elimination

> **Status**: Approved
> **Author**: SneakKestrel16
> **Last Updated**: 2026-10-11 (re-review: camp pause lapses with no Healthy survivor)
> **Last Verified**: 2026-10-11
> **Implements Pillar**: Counterplay; Fair Fear

## Summary

This system decides what happens to a survivor when the shapeshifter lands a
takedown: the first completed takedown downs them, a second eliminates them.
Between the hit and the down sits a short "takedown commit" that teammates can
interrupt, and a downed survivor can crawl, call for help and be rescued with a
risky six-second interaction before they bleed out, so no single mistake decides
the match.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Monster Abilities, First-Person Controller & Interaction, Survivor Defense, Survivor Objectives, Match Flow & Win Conditions`

## Overview

Every survivor has three life states: Healthy, Downed and Eliminated. When the
shapeshifter's Predatory Lunge connects, Monster Abilities sends a validated
`SurvivorHit`. The monster then has to finish the takedown: for a short time it
is rooted over its victim, visible and vulnerable, and a teammate can stun it to
cancel the takedown entirely. If the commit completes, a survivor who has never
been downed becomes Downed; a survivor who has already been downed and rescued
is Eliminated (`downs_to_eliminate` = 2). A Downed survivor crawls slowly and can
call for help; a teammate who holds a six-second rescue brings them back to their
feet, one down closer to elimination. A Downed survivor nobody reaches in time
bleeds out and is Eliminated. The server owns every state change.

## Player Fantasy

**Survivor:** "I got caught, but it isn't over." Being downed is frightening and
helpless, but your team can still save you, and saving a friend in the dark
while something may be watching is the bravest thing you do in a round.

**Shapeshifter:** a landed takedown is a payoff, but finishing it costs you
seconds in the open. You choose whether to strike near the group or wait until
someone is truly alone.

## Detailed Design

### Core Rules

1. **Server authority.** The server holds each survivor's life state, down
   count, commit timers and rescue progress. Clients send only intent (start or
   stop holding Rescue, crawl input, Call for Help). Clients never report hits,
   downs, rescue completion or elimination; the server validates every timer,
   range and line-of-sight check and broadcasts the result.
2. **Down count.** Each survivor has `downs_taken`, starting at 0 each round. It
   increases only when a takedown commit completes. It never decreases.
3. **Takedown eligibility.** A survivor is a valid takedown target only when
   Healthy, not hidden (Survivor Defense), and not inside post-rescue grace,
   post-release grace or an active commit. Monster
   Abilities reads this eligibility before producing `SurvivorHit`; a
   `SurvivorHit` for an ineligible survivor is ignored. Downed survivors cannot
   be hit, so there is no "execute" on a downed survivor **(proposed)**.
4. **Takedown commit.** On a valid `SurvivorHit`:
   1. The victim enters **Seized** and the monster enters **Committing** for
      `takedown_commit_s` = 1.5 s **(proposed)**.
   2. During the commit the monster is rooted, cannot use any ability, cannot
      transform and cannot interact. The victim cannot move, interact or use
      items **(proposed)**: the victim's own defensive window was the lunge
      wind-up (see Survivor Defense); the commit is the *team's* window.
   3. The commit plays in the monster's true form and is visible and audible to
      every client in range **(proposed; disguise handling owned by Borrowed
      Face)**.
   4. If `MonsterStunned` arrives for the committing monster, the commit is
      cancelled: the victim returns to their prior state (Healthy, with
      `downs_taken` unchanged), receives `post_release_grace_s` = 2 s of takedown
      ineligibility **(proposed)**, and no down is recorded.
   5. If the commit timer completes, the server resolves the takedown: if
      `downs_taken` + 1 < `downs_to_eliminate`, the victim becomes **Downed** and
      `SurvivorDowned` is emitted; otherwise the victim becomes **Eliminated**
      and `SurvivorEliminated` is emitted. `downs_taken` increments in both cases.
   6. **Lunge timeline** (stated identically in `monster-abilities.md`): wind-up →
      dash → **hit** → **takedown commit** (`takedown_commit_s` = 1.5 s
      **(proposed)**, owned here) → **lunge resolved** (the commit completes,
      emitting `SurvivorDowned` or `SurvivorEliminated`, or is cancelled, e.g. by
      `MonsterStunned`) → **`lunge_cooldown_s` = 10 s cooldown** (source; owned by
      Monster Abilities) starts at resolution. There is no separate post-hit
      recovery; the commit is the monster's post-hit commitment. Monster
      Abilities reads resolution from `SurvivorDowned`, `SurvivorEliminated`,
      `MonsterStunned` or `PlayerConnectionChanged` (monster disconnect).
5. **What counts as the second down.** The second *completed takedown commit*
   on the same survivor in a round. A cancelled commit, an ignored hit, or a hit
   absorbed by grace is not a down. A second down skips the Downed state and
   eliminates directly; the commit is the last chance to save them.
6. **Downed.** A Downed survivor:
   - crawls at `crawl_speed_mult` = 0.25 × normal walk speed **(proposed)**;
   - cannot sprint, interact with objectives, barricade, hide, use items or
     carry objective items (drop handling is owned by Survivor Objectives);
   - can use pings, the "Danger" callout and voice (Pings & Callouts rules 14
     and 19), and can use **Call for Help**,
     which is the "Need rescue" authored callout owned by Pings & Callouts: a
     directional cry heard by every living player, including the monster, within
     `rescue_callout_range_m` = 40 m, limited by that system's
     `callout_repeat_block_s` = 8 s **(proposed; values owned by Pings & Callouts)**;
   - is shown to living survivors with a "Downed" marker at their position on the
     HUD **(proposed)**. The monster gets no HUD marker; it must hear or see them.
   - has a **bleed-out timer** (designer decision, 2026-10-12): a Downed survivor
     who is not rescued within `bleedout_s` = 60 s **(proposed value)** is
     Eliminated, with reason "Bled out", and `SurvivorEliminated` is emitted.
     `downs_taken` becomes `downs_to_eliminate`. The timer **pauses** while a
     rescue is actively being held on them and resumes when the hold stops; it
     never resets during the same Downed state **(proposed)**. It also
     **pauses while the shapeshifter, in any form, is within
     `camp_pause_radius_m` = 10 m** of the Downed survivor (designer decision,
     2026-10-11, against rescue camping; radius **proposed**), but only while
     at least one living survivor is Healthy **(designer decision, 2026-10-11)**.
     Distance is straight-line, through walls and floors **(proposed)**. Waiting at the
     body then never finishes the victim, so camping gains nothing. Bleed-out only
     applies to a first down, because a second down eliminates directly
     (rule 5).
7. **Rescue.** A Healthy survivor who is not hidden (Survivor Defense), within `rescue_range_m` = 1.5 m **(proposed)**
   of a Downed survivor, with line of sight, may hold Rescue.
   - Completing `rescue_duration_s` = 6 s of held progress rescues them.
   - While a rescue is active, both rescuer and Downed survivor are rooted
     **(proposed)**.
   - Only one rescuer counts at a time; extra helpers do not speed it up
     **(proposed)**.
   - **Interruptions** (server-checked every tick): rescuer releases the input,
     leaves range or loses line of sight, the rescuer receives a valid
     `SurvivorHit`, the rescuer is otherwise no longer Healthy, or the match
     ends. Blackout and scare events do *not* interrupt a rescue **(proposed)**.
   - **Progress persists and decays**: after an interruption, progress is kept on
     the Downed survivor and decays at `rescue_decay_rate` = 0.5 s per second
     **(proposed)** until a rescue resumes or it reaches zero. Any survivor may
     resume it.
   - Only survivors can perform a rescue; the monster cannot start or fake one
     **(proposed; see Open Questions)**.
8. **Rescued state.** A rescued survivor stands up Healthy with `downs_taken` = 1
   (the HUD shows them as "Wounded"; this is Healthy with one down, not a new
   life state). They get `post_rescue_grace_s` = 3 s of takedown ineligibility
   **(proposed)** so a monster waiting beside the body cannot instantly finish
   them. `SurvivorRescued` is emitted. No movement penalty **(proposed)**.
9. **Eliminated.** An Eliminated survivor is out for the rest of the round and
   becomes a spectator of living survivors **(proposed)**. They cannot ping or
   speak to living players **(proposed)**. Their body stays as a non-interactive
   marker **(proposed)**. Their unused defensive item is lost (Survivor Defense).
10. **All living survivors Downed.** Downed is not Eliminated (source: the
    monster wins only when all survivors are eliminated). If every
    non-eliminated, non-escaped survivor is Downed at once, nobody can rescue,
    so each one bleeds out (rule 6) and is Eliminated. When the last survivor is
    Eliminated, Match Flow ends the round at once as a monster win (designer
    decision, 2026-10-12). There is no separate team-wipe rule; bleed-out
    replaces it, so the round can no longer stall until the deadline. The
    camping pause (rule 6) does not apply here: with no Healthy survivor left,
    nobody can rescue, so the monster standing near a body cannot hold it alive.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| Healthy (`downs_taken` 0 or 1) | Round start; rescue complete; commit cancelled | Valid `SurvivorHit` → Seized | Full movement and interaction. Ineligible for takedown while in grace |
| Seized | Valid `SurvivorHit` on an eligible Healthy survivor | Commit completes → Downed or Eliminated; `MonsterStunned` on monster → Healthy | Rooted, no input except camera; lasts `takedown_commit_s` |
| Downed | Commit completes with `downs_taken` becoming 1 | Rescue completes → Healthy; `bleedout_s` elapses → Eliminated | Crawl, Call for Help, pings. Cannot be hit. Bleed-out timer runs (pauses during an active rescue) |
| Eliminated | Commit completes with `downs_taken` becoming 2; or bleed-out | None (end of round) | Spectator |

Monster-side state owned here: **Committing** (entry: valid `SurvivorHit`; exit:
commit complete or `MonsterStunned`). `MonsterStunned` itself is owned by
Survivor Defense.

### Interactions with Other Systems

| System | In | Out |
|--------|----|-----|
| Monster Abilities | `SurvivorHit` (validated hit, victim, monster) | Takedown eligibility per survivor; "lunge resolved" when the commit ends |
| Survivor Defense | `MonsterStunned` (cancels commit) | Committing state (a valid stun target); Downed/Eliminated (no item use; item lost on elimination) |
| Survivor Objectives | — | `SurvivorDowned` / `SurvivorEliminated` (Objectives owns dropping carried drives/fuses); Downed survivors cannot interact with objectives |
| Match Flow & Win Conditions | Round end (freeze all timers); `PlayerConnectionChanged` (cancel commit on monster disconnect) | `SurvivorEliminated` (all eliminated = monster win); disconnect rule owned by Match Flow |
| Borrowed Face | — | Committing state (transformation blocked; true form shown) |
| First-Person Controller & Interaction | Generic timed hold-to-interact pattern | Movement lock (Seized, rescue), crawl speed |
| Pings & Callouts | Ping availability while Downed | Call for Help cue |
| HUD & Results Screen | — | Downed markers, "Wounded" roster state, rescue progress, downs/rescues for results |
| Match Telemetry | — | Hits, commits cancelled, downs, rescues, rescue interruptions, eliminations |

## Formulas

### Takedown outcome

```
on commit complete:
  downs_taken = downs_taken + 1
  state = (downs_taken >= downs_to_eliminate) ? Eliminated : Downed
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| downs_taken | int | 0–2 | server state | Completed takedowns on this survivor this round |
| downs_to_eliminate | int | 2 | canon (source) | Downs that eliminate |

Example: a rescued survivor (`downs_taken` 1) is hit and the commit completes →
`downs_taken` 2 ≥ 2 → Eliminated.

### Rescue progress

```
while rescuing:      progress = min(rescue_duration_s, progress + dt)
while not rescuing:  progress = max(0, progress - rescue_decay_rate * dt)
rescue completes when progress >= rescue_duration_s
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| progress | float s | 0–6 | server state | Stored on the Downed survivor |
| rescue_duration_s | float s | 6 | canon (source) | Held time to rescue |
| rescue_decay_rate | float | 0–1 | proposed 0.5 | Seconds of progress lost per second idle |
| dt | float s | — | server tick | Tick length |

Example: a rescue is interrupted at 4.0 s; a teammate resumes 3 s later →
4.0 − 1.5 = 2.5 s stored, 3.5 s left to hold. Expected total rescue time: 6 s
uninterrupted; never more than 6 s of held progress from zero.

### Bleed-out

```
paused = being actively rescued or (monster_distance_m <= camp_pause_radius_m and healthy_survivors >= 1)
while Downed and not paused:  bleed_elapsed_s = bleed_elapsed_s + dt
while Downed and paused:      bleed_elapsed_s unchanged
Eliminated when bleed_elapsed_s >= bleedout_s
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| bleed_elapsed_s | float s | 0–bleedout_s | server state | Starts at 0 on entering Downed |
| bleedout_s | float s | 30–120 | proposed 60 | Time a Downed survivor survives unrescued |
| monster_distance_m | float m | 0+ | server state | Straight-line distance from the shapeshifter (any form) to the Downed survivor |
| camp_pause_radius_m | float m | 5–20 | proposed 10 | Monster closer than this pauses bleed-out |
| healthy_survivors | int | 0–3 | server state | Living, non-escaped survivors who are Healthy (not Seized, Downed or Eliminated) |

Example: downed at 200 s, a teammate holds a rescue from 230 s to 233 s (interrupted),
nobody else comes → bleed_elapsed reaches 60 s at 263 s → Eliminated at 263 s.
Worst-case stall with everyone Downed: `bleedout_s` (60 s), down from "until the deadline".

### Crawl speed

```
crawl_speed = walk_speed * crawl_speed_mult
```
`walk_speed` is owned by First-Person Controller (no GDD yet). With
`crawl_speed_mult` 0.25, a survivor walking 4 m/s crawls 1 m/s.

### Monster exposure per takedown

```
monster_exposed_s = lunge_windup_s + takedown_commit_s
```
Lunge wind-up is owned by Monster Abilities. With `takedown_commit_s` 1.5 s, the
team has at least 1.5 s to reach stun range after a hit lands.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Rescuer is hit mid-rescue | Rescue interrupts (progress kept, decaying); rescuer enters Seized | Rescue is risky by design |
| `MonsterStunned` and commit completion land on the same server tick | Stun wins; commit cancelled | Favor the interrupt; counterplay pillar |
| Victim's teammate stuns the monster during wind-up (before hit) | No `SurvivorHit`; this system does nothing | Wind-up interrupts are owned by Survivor Defense / Monster Abilities |
| Monster disconnects during a commit (`PlayerConnectionChanged`) | Commit cancelled; victim returns to Healthy with `post_release_grace_s` | No down without a completed commit |
| Victim disconnects while Seized | The commit keeps running and resolves on schedule: Downed (bleed-out starts) or Eliminated, recorded while they are disconnected. A stun still cancels it. On reconnect they return in the resulting state (designer decision, 2026-10-12) | Disconnecting must not dodge a takedown (Match Flow rule 19) |
| Victim disconnects while Downed | Handled by Match Flow's disconnect rule. The bleed-out timer keeps running during reconnect grace; if it expires, the survivor is Eliminated ("Bled out") while still disconnected | Disconnecting must not stall the round (Match Flow rule 19) |
| Downed survivor crawls into a hiding spot | Not allowed; hiding requires Healthy | Hiding a downed body would stall the round |
| Two survivors try to rescue the same person | First valid starter is the rescuer; second gets "already being rescued" | One rescuer counts |
| Rescue completes on the same tick the rescuer is hit | Hit processed first; rescue interrupted | Server orders hit resolution before interactions **(proposed)** |
| Downed survivor carried a data drive | Survivor Objectives decides drop behavior | Ownership of item rules |
| All living survivors Downed, one has escaped | Escaped survivors are not counted; Match Flow evaluates win | Escape state is Match Flow's |
| Round timer expires mid-commit or mid-rescue | All timers freeze; Match Flow decides the outcome | Round end overrides |
| Monster attempts a lunge on a survivor in grace | Not a valid target; Monster Abilities treats it as no hit | Grace prevents instant re-takedown |
| Bleed-out would expire while a rescue is being held | Cannot happen: the timer is paused during an active hold | Rescue in progress always gets its chance |
| Rescue completes on the same tick the bleed-out expires | Bleed-out is paused during the hold, so the rescue wins | Rule 6 |
| Monster stays within 10 m of a Downed survivor | Bleed-out stays paused for as long as it stays; the victim is never finished by waiting | Rule 6; anti-camping, decided 2026-10-11 |
| Every living survivor is Downed | Each bleeds out on their own timer; the round ends when the last is Eliminated | Rule 10; decided 2026-10-12 |
| Downed survivor bleeds out while carrying nothing near the exit | Eliminated; Downed survivors cannot escape | Match Flow escape rule |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| Monster Abilities | Bidirectional | Consumes `SurvivorHit`; Monster Abilities depends on this for target eligibility and lunge-resolved timing |
| Survivor Defense | Bidirectional | Consumes `MonsterStunned`; Survivor Defense reads Committing and Downed states |
| First-Person Controller & Interaction | This depends on it | Hold-to-interact, movement lock, crawl |
| Survivor Objectives | Objectives depends on this | Reacts to `SurvivorDowned`/`SurvivorEliminated` for item drops |
| Match Flow & Win Conditions | Bidirectional | Match Flow consumes `SurvivorEliminated`; this system obeys round end and Match Flow's disconnect rule |
| Borrowed Face | Borrowed Face depends on this | Blocks transformation during Committing |
| Pings & Callouts | Bidirectional | Downed survivors use pings; Call for Help cue |
| Network Authority & Replication | This depends on it | Server-authoritative state and replication |
| HUD & Results Screen | HUD depends on this | Displays down/rescue state |
| Match Telemetry | Telemetry depends on this | Logs downs, rescues, eliminations |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| downs_to_eliminate | 2 (canon) | 2 | — (fixed by source) | — |
| rescue_duration_s | 6 (canon) | 4–8 | Rescues riskier; fewer rescues | Downs matter less |
| takedown_commit_s | 1.5 (proposed) | 0.8–2.5 | More team interrupts; monster weaker near groups | Commit hard to interrupt; hits ≈ downs |
| post_release_grace_s | 2 (proposed) | 1–4 | Freed victim escapes more easily | Monster can re-grab after stun ends |
| post_rescue_grace_s | 3 (proposed) | 1–5 | Camping punished more | Rescued survivors finished instantly |
| rescue_decay_rate | 0.5 (proposed) | 0–1 | Interruptions hurt more | Partial rescues nearly free to resume |
| rescue_range_m | 1.5 (proposed) | 1–2.5 | Easier, sloppier rescues | Fiddly positioning |
| crawl_speed_mult | 0.25 (proposed) | 0.15–0.4 | Downed can reach safety | Downed nearly static |
| bleedout_s | 60 (proposed; bleed-out itself decided) | 30–120 | More time to organise rescues; slower stalls | Downs become near-eliminations; rescues rushed |
| camp_pause_radius_m | 10 (proposed; pause itself decided) | 5–20 | Monster must leave further before the timer runs; camping costs more | Monster can wait just outside and still bleed the victim out |

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Takedown commit start | Monster true form pinning victim; victim camera shake (reduced-flash safe) | Loud, directional struggle cue | MVP |
| Commit cancelled by stun | Victim released, stumbles free | Stun crack + release gasp | MVP |
| Downed | Victim drops; desaturated, low camera for victim | Collapse + heartbeat for victim | MVP |
| Call for Help | Brief directional marker for survivors | Directional voice cry | MVP |
| Bleed-out running | Draining ring on the Downed marker; victim's vignette darkens as it runs out | Heartbeat slows toward the end | MVP |
| Bled out | Same as Eliminated | Same final sting | MVP |
| Rescue in progress | Kneel animation; progress ring for both | Low, quiet effort loop | MVP |
| Rescued | Stand-up animation; roster shows "Wounded" | Short relief cue | MVP |
| Eliminated | Body collapses; spectator transition | Distinct final sting (respects reduced volume) | MVP |

## Game Feel

### Feel Reference

Should feel like a Dead by Daylight unhook under pressure: a long, exposed hold
where every sound matters. The commit should read like a heavy grab, not an
instant kill. Anti-reference: one-hit deaths with no window.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|------------------------|-------|
| Start/stop Rescue | 100 | 6 | Local progress ring may predict; server confirms |
| Call for Help | 100 | 6 | Local cue immediate |
| Crawl input | 50 | 3 | Standard movement prediction |

### Animation Feel Targets

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|-----------|---------------|--------------|----------------|-----------|-------|
| Takedown commit | 6 | 78 (1.3 s) | 6 | Heavy, readable, interruptible | Totals `takedown_commit_s` |
| Rescue stand-up | 0 | — | 20 | Shaky relief | After completion |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Camera impact (victim) | 200 | Jolt on `SurvivorHit` | Yes (reduced-flash/motion) |
| Screen shake (victim) | 300 | Decaying during commit | Yes |

### Weight and Responsiveness Profile

- **Weight**: heavy and deliberate on both sides.
- **Player control**: victim has low control for 1.5 s; teammates have full control.
- **Snap quality**: state changes are crisp and binary.
- **Failure texture**: a down must read as "I was caught alone / we didn't come"; never "it happened instantly".

### Feel Acceptance Criteria

- [ ] Across ≥10 playtest rounds, at least 80% of downed players answer "yes" to the post-round survey question "Did you understand why you were downed?".
- [ ] Across ≥10 playtest rounds, at least 60% of answers from teammates within 10 m of a hit are "yes" to "Did you notice the takedown in time to act?".

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|-----------------|-----------|
| Teammate state (Healthy / Wounded / Downed / Eliminated) | Survivor roster | On change | Survivors only |
| Downed teammate marker | World marker | Continuous | Living survivors only |
| Bleed-out remaining | Ring on the Downed marker; victim's own HUD | Per tick | Living survivors and the victim; not the monster **(proposed)** |
| Rescue progress | Centre ring, both players | Per tick | During rescue |
| Own Seized/Downed state | Full-screen vignette | On change | Victim |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|-----------|----------------------------|--------|
| Hit resolution produces `SurvivorHit` | `design/gdd/monster-abilities.md` | Predatory Lunge hit validation, lunge timeline, `lunge_cooldown_s` | Data dependency |
| Stun cancels commit | `design/gdd/survivor-defense.md` | `MonsterStunned` | State trigger |
| Item lost on elimination | `design/gdd/survivor-defense.md` | Starting kit | Rule dependency |
| Carried items on down | `design/gdd/survivor-objectives.md` | Drive/fuse drop rule | Ownership handoff |
| Elimination ends match | `design/gdd/match-flow.md` | Win evaluation, disconnect rule, round end | State trigger |
| Commit blocks transformation | `design/gdd/borrowed-face.md` | Transformation cannot cancel an attack | Rule dependency |
| Downed pings | `design/gdd/pings-and-callouts.md` | Ping set, eliminated-player voice rule | Rule dependency |

## Acceptance Criteria

- [ ] A Healthy survivor whose takedown commit completes becomes Downed; a survivor with `downs_taken` 1 whose commit completes becomes Eliminated without entering Downed.
- [ ] A `MonsterStunned` received during Committing cancels the commit; `downs_taken` is unchanged.
- [ ] A `SurvivorHit` on a Downed survivor or a survivor in grace changes nothing.
- [ ] A rescued survivor cannot be taken down for 3 s (±1 tick) after standing up; a survivor freed by a stun cannot for 2 s (±1 tick).
- [ ] With two survivors holding Rescue on the same Downed survivor, the second gets "already being rescued", and the rescue still takes 6 s.
- [ ] A hidden survivor cannot start a rescue.
- [ ] A victim who disconnects while Seized is Downed (or Eliminated, with `downs_taken` 1) when the commit timer ends, and returns in that state on reconnect.
- [ ] Holding Rescue for 6.0 s (±1 tick) uninterrupted rescues; releasing at 4.0 s and resuming 3.0 s later needs 3.5 s more.
- [ ] A client sending a forged "rescue complete" or "survivor downed" message causes no state change.
- [ ] With 5 clients connected, all 5 show the same life state and down count for every survivor after each hit, commit, rescue and elimination, within 250 ms of the server event.
- [ ] A Downed survivor left alone is Eliminated after 60 s (±1 tick) with reason "Bled out", on all 5 clients.
- [ ] Holding a rescue pauses the bleed-out timer; releasing resumes it from the same value.
- [ ] With at least one other survivor Healthy and the shapeshifter (true form or disguised) 9 m from a Downed survivor, the bleed-out timer does not advance; at 11 m it resumes from the same value.
- [ ] With every living survivor Downed and the shapeshifter 5 m from one of them, that survivor's bleed-out timer keeps advancing and they are Eliminated at `bleedout_s`.
- [ ] When all living survivors are Downed and nobody is rescued, each is Eliminated on their own bleed-out timer, and the round ends with "All survivors eliminated" the moment the last one is.
- [ ] After a hit whose commit completes or is cancelled at time T, Monster Abilities accepts the next lunge no earlier than T + `lunge_cooldown_s` (10 s).
- [ ] Every value in Tuning Knobs is loaded from data, not hardcoded.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Is `takedown_commit_s` 1.5 s and victim-cannot-act the right shape for the "commit" the source describes? | SneakKestrel16 | Before Milestone 2 | |
| Should Downed survivors bleed out after a time limit? | SneakKestrel16 | Before Milestone 2 | **Decided 2026-10-12: yes.** Duration `bleedout_s` = 60 s is proposed; tune in playtest |
| Is a team-wipe rule needed when everyone is Downed? | SneakKestrel16 | Before Milestone 2 | **Resolved 2026-10-12:** no; bleed-out eliminates them and the round ends when everyone is eliminated |
| Should the bleed-out timer pause during an active rescue, and should the monster see it? | SneakKestrel16 | Before Milestone 2 | Pausing decided (rule 6, rescue and camping). Proposed: the monster does not see the timer |
| Rescue camping is the dominant monster strategy (cross-review 2026-10-11, blocker 3) | SneakKestrel16 | Before Milestone 2 | **Decided 2026-10-11:** bleed-out pauses while the shapeshifter is within `camp_pause_radius_m` (rule 6) |
| Does the bleed-out ring show the camping pause? A visible pause tells survivors a disguised monster is within 10 m. | SneakKestrel16 | Before Milestone 3 | |
| Can the disguised monster fake a rescue animation (deception) without progress? | SneakKestrel16 | Before Milestone 3 | Proposed: no |
| Does the commit force the monster's true form, or does the disguise drop earlier at lunge wind-up? | SneakKestrel16 | Before Milestone 3 | **Settled:** Predatory Lunge requires True Form (Borrowed Face rule 11, Monster Abilities), so the monster is already in true form at wind-up and the commit never needs to force it |
| Should "Wounded" (one down) be visible on the survivor model, or only on the roster? | SneakKestrel16 | Before Milestone 4 | |
| Can eliminated players communicate with living players? | SneakKestrel16 | Before Milestone 5 | Proposed: no |
