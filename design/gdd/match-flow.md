# Match Flow & Win Conditions

> **Status**: Approved (2026-10-11 re-review, lean)
> **Author**: SneakKestrel16
> **Last Updated**: 2026-10-11 (re-review after cross-review blockers)
> **Last Verified**: 2026-10-11
> **Implements Pillar**: Readable Objectives, Fair Fear, Small Shippable Scope

## Summary

Match Flow runs one ~9-minute round of Dead Signal: it takes five players from the lobby, runs the round clock through Infiltration, Investigation and Evacuation, decides on the server who won, and hands the result to the results screen. It owns the round timer, the phase windows, the evacuation deadline, win/loss evaluation, results screen contents and the mid-match disconnect rule.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Lobby & Role Assignment, Survivor Objectives, Downing, Rescue & Elimination`

## Overview

Every round has the same shape. Lobby & Role Assignment hands over five connected players (1 shapeshifter, 4 survivors). The server starts a 540-second clock. The first two minutes are Infiltration, the middle five are Investigation, and the final two are Evacuation. Survivors win if, after recovering two data drives, installing two fuses and activating the evacuation terminal, they carry both drives out through the exit. The shapeshifter wins if all survivors are eliminated or the evacuation deadline expires. The server alone decides phase changes and the outcome; clients only display what the server tells them. When the round ends, every player sees the same results screen.

## Player Fantasy

Survivors should feel a clock closing in: an orientation window that turns into a scramble, then a last stand at the terminal with the deadline visible. The shapeshifter should feel time on its side: every minute it keeps the group divided is a minute closer to winning without a single attack. Both sides should finish a round knowing exactly why it ended (Fair Fear: losing must feel understandable).

## Detailed Design

### Core Rules

**Round start**
1. Lobby & Role Assignment delivers exactly `players_per_match` = 5 players with roles fixed (1 shapeshifter, 4 survivors). Match Flow does not assign roles.
2. The server waits until all 5 clients report the map loaded, up to `load_timeout_s` = 60 **(proposed)**. If any client fails to load in time, the round is cancelled and all players return to the lobby; no result is recorded **(proposed)**.
3. When all 5 are loaded, the server spawns players at Facility Map spawn points, sets `elapsed_s = 0`, enters Infiltration and broadcasts `RoundPhaseChanged`.

**Round timer and phases**
4. The round clock runs on the server only. Clients display a replicated value and never advance phase or end the round themselves.
5. Phase windows (source pacing targets, tune in playtests): Infiltration `0:00–2:00`, Investigation `2:00–7:00`, Evacuation = the final 2:00 (`7:00–9:00` at `round_duration_s` = 540).
6. Evacuation begins at whichever comes first **(proposed)**: (a) `elapsed_s` reaches the evacuation start (7:00), or (b) Survivor Objectives reports the terminal armed (both drives docked and both fuses installed). This reconciles the source's two descriptions of Evacuation: a timed final two minutes, and the stage that starts "once requirements are met". The phase never moves backwards.
7. Phases are signals, not locks **(proposed)**. Match Flow broadcasts `RoundPhaseChanged`. Scare Events (emergency mode) and other systems may react to it. Match Flow itself does not enable or disable abilities or objectives by phase. Whether attacks are restricted during Infiltration is an Open Question.

**Evacuation deadline**
8. The evacuation deadline is the end of the round clock: `elapsed_s >= round_duration_s` **(proposed reading of "evacuation deadline")**.
9. The deadline is hard: there is no overtime **(proposed)**. If the 15-second terminal activation, or a survivor's run to the exit, is still in progress when the deadline is reached, it does not finish, and the shapeshifter wins (unless the evidence already escaped; see rule 14).

**Win conditions (source text, verbatim)**
- *Survivors win* by recovering two data drives, restoring power with two fuses, activating evacuation, and having at least one survivor escape with the required evidence.
- *The monster wins* if all survivors are eliminated or the evacuation deadline expires.

**How the server evaluates them**
10. *Escape*: a survivor in the Healthy state (not Downed, not Eliminated) enters the exit volume after Survivor Objectives has reported evacuation activated. The server records them as Escaped, removes them from play (they become a spectator who, like an Eliminated survivor, cannot ping or speak to living players **(proposed)**) and broadcasts `SurvivorEscaped` **(proposed event name)**. Any drives they carry become Extracted (Survivor Objectives).
11. *Evidence escaped* (designer decision, 2026-10-12: evidence is carried to the extract): the survivor win condition is met when Survivor Objectives reports **both drives Extracted**. Survivor Objectives owns what "the required evidence" means (`survivor-objectives.md` rule 22). An escape without drives does not meet it.
12. *All eliminated*: every survivor is Eliminated, or treated as eliminated by the disconnect rule (rule 19). The round ends **at that moment** as a monster win (designer decision, 2026-10-12). Bleed-out (`downing-and-rescue.md`) guarantees an all-Downed team reaches this state instead of stalling.
13. *Evidence lost* **(proposed)**: if no Healthy or Downed survivor remains inside the facility (everyone is Escaped or Eliminated) and the evidence has not escaped, nobody can complete the win, so the round ends at once as a monster win. A Downed survivor still counts as inside (designer decision, 2026-10-12): if only Downed survivors remain, the round waits for rescue or bleed-out, and an all-Downed team ends through rule 12 ("All survivors eliminated"), not this rule. A survivor in reconnect grace also counts as inside, in their last state, so a dropped connection cannot end the round as "Evidence lost" before grace expires.
14. *Outcome lock*: the moment both drives are Extracted, the outcome locks as a survivor win. Later events (eliminations, deadline, the shapeshifter's grace expiring) cannot flip it, not even a shapeshifter forfeit.
15. *After the lock*, the round continues so remaining survivors can try to escape. It ends when every survivor is Escaped or Eliminated, when the deadline is reached, or `post_escape_window_s` = 45 after the lock **(proposed)**, whichever comes first. Survivors still inside at that point are recorded as "Did not escape". The team still wins.
16. *Check timing*: the server runs the win check (a) whenever it processes `SurvivorEliminated`, `SurvivorEscaped`, a drive Extracted, a disconnect-grace expiry, or a clock update that crosses the deadline, and (b) once at the end of every server tick as a safety net. Within one tick, the server processes all gameplay events (hits, downs, eliminations, bleed-outs, objective completions, escapes) in the order it received them, then the win check runs in this order: (1) evidence escaped → survivor win; (2) all eliminated → monster win; (3) evidence lost → monster win; (4) deadline reached → monster win; (5) shapeshifter grace expired → survivor win by forfeit **(proposed ordering)**. A result the players earned beats a forfeit in the same tick.
17. When an outcome is final, the server freezes gameplay input, broadcasts `RoundEnded` **(proposed event name)** with the outcome, reason and results payload, and moves to Results. A client never declares a result; a client that disagrees with the server is wrong by definition.
18. Downed is not eliminated. If every remaining survivor is Downed at once, each bleeds out on their own timer (`bleedout_s`, owned by `downing-and-rescue.md`), and the round ends when the last is Eliminated (rule 12). There is no separate team-wipe rule.

**Disconnect and reconnect (source M1 asks for handling; whole subsection proposed)**
19. *Survivor disconnects* **(proposed)**: the server immediately drops any data drive or fuse they carry at their position (see `survivor-objectives.md`), removes their character from the world, and shows all players "[name]: connection lost". They have `reconnect_grace_s` = 60 to return. On reconnect they respawn at the position where they disconnected, in the same Healthy/Downed state and with the same down count. A Downed survivor's bleed-out timer keeps running while they are disconnected (designer decision, 2026-10-12); if it expires during grace they are Eliminated ("Bled out") at that moment, so disconnecting can never stall the round. If grace expires, they count as eliminated for win evaluation and are listed as "Disconnected" in results. No reconnect is accepted after grace expires.
20. *Shapeshifter disconnects* **(proposed)**: its character is removed from the world, all ability cooldowns keep counting down, the round clock keeps running, and all players see "The shapeshifter lost connection". If it reconnects within `reconnect_grace_s`, it respawns at its disconnect position in its true form; any disguise is lost **(proposed)**, and its observed-survivor list is kept (`borrowed-face.md`). If grace expires, the shapeshifter **forfeits and the survivors win** (designer decision, 2026-10-11): rage-quitting can never void a loss, and results show the reason "Shapeshifter forfeited". The other win checks keep running during its grace: if the deadline is reached while it is away, the monster still wins (rule 16) **(proposed)**. There is no AI or bot replacement, ever.
21. *Everyone on one side disconnects*: the same rules apply per player. If all four survivors are past grace, the monster wins (rule 12).
22. Every disconnect and reconnect is logged for Match Telemetry.

**Results screen contents (Match Flow owns the data; HUD & Results Screen owns presentation)**
23. *Outcome*: Survivors Win / Shapeshifter Wins, plus a reason: "Evidence escaped", "All survivors eliminated", "Evidence lost", "Evacuation deadline expired" or "Shapeshifter forfeited".
24. *Survival*: for each survivor, one of Escaped (with drives carried, if any) / Eliminated (incl. "Bled out") / Did not escape / Disconnected, with downs taken and rescues performed. The shapeshifter's player name is revealed **(proposed)**.
25. *Objective progress*: drives recovered (x/2), drives docked (x/2), fuses installed (x/2), evacuation activated (yes/no), drives extracted (x/2), and the round time of each completion.
26. *Basic match stats*: match duration; monster takedowns, eliminations, lunges landed/missed, times stunned, form changes, False Signals and Blackouts used; survivor stuns landed and rescues completed.
27. Results stay up for `results_duration_s` = 20 **(proposed)**, then everyone returns to the lobby.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| Loading | Lobby hands off 5 players with roles | All 5 loaded → Infiltration; `load_timeout_s` exceeded → Cancelled | No clock; players frozen |
| Infiltration | All loaded; `elapsed_s = 0` | `elapsed_s >= infiltration_end_s` → Investigation; terminal armed → Evacuation | Clock runs; all systems live |
| Investigation | `elapsed_s >= infiltration_end_s` | `elapsed_s >= evac_start_s` OR terminal armed → Evacuation | Clock runs |
| Evacuation | `elapsed_s >= evac_start_s` OR terminal armed **(proposed)** | Outcome final → Ended | Emergency mode signal to Scare Events |
| Ended | Outcome final (rules 11–16, 20) | Immediate → Results | Gameplay input frozen; `RoundEnded` sent |
| Results | Ended | `results_duration_s` elapsed → back to lobby | Results shown on all clients |
| Cancelled | Load timeout | Immediate → back to lobby | No result recorded |

Win checks run in Infiltration, Investigation and Evacuation. If the terminal is armed during Infiltration, the phase still skips straight to Evacuation (Infiltration → Evacuation is a valid transition). Every phase change sends exactly one `RoundPhaseChanged`.

### Interactions with Other Systems

| System | Data in | Data out | Responsibility |
|--------|---------|----------|----------------|
| Lobby & Role Assignment | 5 players + roles | Return-to-lobby on Results/Cancelled | Lobby assigns roles; Match Flow never does |
| Survivor Objectives | `ObjectiveProgressChanged` (terminal armed, evacuation activated, drives extracted, per-objective completion times) | `RoundPhaseChanged`; `SurvivorEscaped`; round end (objectives freeze) | Objectives owns "required evidence"; Match Flow owns the outcome |
| Downing, Rescue & Elimination | `SurvivorDowned`, `SurvivorRescued`, `SurvivorEliminated` (incl. bleed-out), per-survivor down counts | Round end (freezes downs/rescues/bleed-out) | Downing owns survivor states; Match Flow counts eliminations |
| Facility Map | Spawn points, exit volume | — | Map authors where the exit is |
| Monster Abilities, Survivor Defense, Borrowed Face | Stats for results (lunges, stuns, form changes, abilities used) | `RoundPhaseChanged` | Each owns its own validation |
| Scare Events | — | `RoundPhaseChanged` (Evacuation = emergency mode) | Scare Events decides presentation |
| HUD & Results Screen | — | Clock, phase, `RoundEnded` payload | HUD presents; never computes outcome |
| Network Authority & Replication | Connection state | `PlayerConnectionChanged` **(proposed)** (disconnect, reconnect, grace expired) | Server authority for all of the above; Match Flow owns the event |
| Match Telemetry | — | Duration, completion times, escapes, disconnects | Telemetry logs |

## Formulas

### Phase from elapsed time

```
evac_start_s = round_duration_s − evacuation_window_s
phase = Infiltration   if elapsed_s < infiltration_end_s and not terminal_armed
        Evacuation     if elapsed_s >= evac_start_s or terminal_armed
        Investigation  otherwise
time_remaining_s = max(0, round_duration_s − elapsed_s)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| elapsed_s | float | 0–round_duration_s | server clock | Seconds since Infiltration began |
| round_duration_s | int | 420–720 | data | 540 (~9 min, source) |
| infiltration_end_s | int | 60–180 | data | 120 (source) |
| evacuation_window_s | int | 60–180 | data | 120 (source "final two minutes") |
| terminal_armed | bool | — | Survivor Objectives | Both drives docked and both fuses installed **(proposed trigger)** |

**Expected output**: with defaults, Investigation spans 120–420 s. **Constraint**: `infiltration_end_s < evac_start_s`. A config that breaks this is rejected at load and defaults are used.
**Example**: `elapsed_s` = 300, not armed → Investigation, 240 s left. If the terminal is armed at 300 → Evacuation at 300; the deadline is still 540.

### Post-escape end time

```
round_end_s = min(round_duration_s, evidence_escaped_s + post_escape_window_s, time all survivors are Escaped/Eliminated)
```
Example: the second drive is Extracted at 500 s → the round ends no later than min(540, 545) = 540.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| The last non-downed survivor is downed while rescuing the only other survivor | The rescue is interrupted (Downing owns this). Both bleed out on their own timers; when the second is Eliminated, the round ends at once as a monster win | Bleed-out and immediate end (decided 2026-10-12) |
| Deadline reached during the 15 s activation | Activation does not finish. Monster wins, reason "Evacuation deadline expired" | Hard deadline (rule 9, proposed) |
| Activation completes but the drives don't reach the exit before the deadline | Monster wins | The evidence must escape |
| One drive Extracted; the last survivor inside is eliminated holding the other | Evidence lost: monster wins at once | Rule 13 (proposed) |
| A survivor escapes without drives | Escaped; no win progress; the round continues | Rule 11 |
| The second drive is Extracted in the same tick the last survivor inside is eliminated | Survivors win | Evidence escaped is checked first (rule 16) |
| Second drive Extracted and deadline in the same tick | An extraction processed in a tick at or before the deadline counts. Survivors win | Rule 16 ordering (proposed) |
| Shapeshifter disconnects | Character removed; 60 s grace; clock runs; survivors win by forfeit if it does not return | Rule 20 (proposed); no AI substitute |
| Shapeshifter disconnects at the same time as the evidence escapes | The extraction locks the survivor win first; the disconnect does not change it | Outcome lock (rule 14) |
| A Downed survivor disconnects | Removed; bleed-out keeps running. Returns Downed with the same down count and remaining bleed-out if back in time; Eliminated ("Bled out") if the timer expires first; counted eliminated if grace expires first | Disconnecting must not let a player avoid an elimination or stall the round (rule 19) |
| A Seized survivor disconnects mid-commit | The takedown commit resolves on schedule (Downing owns this); they return Downed or are Eliminated | A disconnect must not dodge a takedown (rule 19) |
| Only Downed survivors left inside, drives not out | No "Evidence lost"; the round waits for bleed-out, then ends "All survivors eliminated" | Rule 13: Downed counts as inside |
| Deadline reached while the shapeshifter is in reconnect grace | Monster wins, reason "Evacuation deadline expired" | Rule 20 (proposed) |
| A drive carrier disconnects | Drive dropped at their position immediately | Team is not blocked for 60 s |
| All four survivors disconnected inside grace | Round continues; monster wins when the last grace expires unless one returns | Rules 19, 21 |
| A client's clock drifts | Client display corrects to the server value; the phase changes only on `RoundPhaseChanged` | Server authority |
| Terminal armed during Infiltration | Phase goes straight to Evacuation | Phase rule 6 |
| A Downed survivor's bleed-out expires at the deadline tick | Events in the tick are processed first, then the win check; either way the monster wins | Rule 16 |
| Downed survivor crawls into the exit volume | Not an escape; only Healthy survivors escape **(proposed)** | Keeps rescue meaningful |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| Lobby & Role Assignment | This depends on it | Needs 5 players with roles; returns players to it |
| Survivor Objectives | Bidirectional | Reads terminal armed / evacuation activated / drives extracted / evidence rule; Objectives reads phase, escapes and round end |
| Downing, Rescue & Elimination | Bidirectional | Reads eliminations (incl. bleed-outs) and down counts; Downing stops at round end |
| Facility Map | This depends on it | Spawn points, exit volume |
| Network Authority & Replication | This depends on it | Server clock, authority, disconnect detection |
| Monster Abilities | It depends on this | Reads `RoundPhaseChanged` (Infiltration attack question); supplies stats |
| Borrowed Face | Bidirectional | Supplies form-change stats; owns disguise restore on monster reconnect |
| Survivor Defense | It depends on this | Supplies stun stats; stops at round end |
| Scare Events | It depends on this | Uses `RoundPhaseChanged` for emergency mode |
| HUD & Results Screen | It depends on this | Displays clock, phase, results payload |
| Match Telemetry | It depends on this | Logs duration, escapes, disconnects |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| round_duration_s | 540 | 420–720 | Easier for survivors; slower pace | Deadline pressure; monster favoured |
| infiltration_end_s | 120 | 60–180 | Longer calm orientation | Earlier pressure |
| evacuation_window_s | 120 | 60–180 | Longer emergency mode | Shorter final act |
| post_escape_window_s **(proposed)** | 45 | 20–90 | More time for others to escape | Faster end after a win |
| reconnect_grace_s **(proposed)** | 60 | 30–120 | Forgives bad connections | Fewer stalled rounds |
| load_timeout_s **(proposed)** | 60 | 30–120 | Tolerates slow machines | Faster cancel |
| results_duration_s **(proposed)** | 20 | 10–45 | More reading time | Faster requeue |

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Phase change to Investigation | Brief HUD phase banner | Subtle facility tone | MVP |
| Phase change to Evacuation | Banner; emergency lighting state (Scare Events) | Alarm sting | MVP |
| Final 30 s | Clock turns urgent colour | Ticking layer | VS |
| Survivor escaped | Name in HUD feed | Exit door sound | MVP |
| Disconnect / reconnect | HUD feed message | None | MVP |
| Round end | Fade to results | Outcome sting (win/loss per role) | MVP |

## Game Feel

### Feel Reference
The escalating final minutes of a Dead by Daylight endgame, where the clock is always visible and the threat converges on the exit. Anti-reference: a hidden timer that ends the round without warning.

### Input Responsiveness
| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|------------------------|-------|
| Phase banner after server change | 200 | 12 | Network delivery included |
| Results shown after outcome | 500 | 30 | Same moment on all clients |

### Animation Feel Targets
Not applicable: Match Flow has no character animation.

### Impact Moments
| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Evacuation onset | 1500 | Lighting shift and alarm sting | Yes (reduced flash/volume) |
| Round end freeze | 1000 | Input frozen, fade to results | Yes |

### Weight and Responsiveness Profile
- **Weight**: The clock is steady and impartial.
- **Player control**: Phases never take control away; only the round end freezes input.
- **Snap quality**: Phase changes are crisp, single events.
- **Acceleration model**: Pressure rises in steps (phases), not continuously.
- **Failure texture**: The results reason line always says why the round ended.

### Feel Acceptance Criteria
- [ ] Across ≥10 playtest rounds, 0 players answer "yes" to the post-round question "Did the round end without warning?".
- [ ] Across ≥10 playtest rounds, every player names the end reason that matches the results screen in the post-round survey.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|-----------------|-----------|
| Time remaining | HUD, top centre | 1 Hz (server-corrected) | Infiltration–Evacuation |
| Current phase | HUD, under clock | On `RoundPhaseChanged` | Always in round |
| Escape / disconnect feed | HUD feed | On event | Always in round |
| Results payload (rules 23–26) | Results screen | Once | Results |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|-----------|----------------------------|--------|
| Terminal armed and evacuation activated | `design/gdd/survivor-objectives.md` | `ObjectiveProgressChanged` states | State trigger |
| "Escape with the required evidence" | `design/gdd/survivor-objectives.md` | Evidence rule | Rule dependency |
| Drop of carried items on disconnect | `design/gdd/survivor-objectives.md` | Carried-item drop rule | Ownership handoff |
| Elimination counts | `design/gdd/downing-and-rescue.md` | `SurvivorEliminated`, `downs_to_eliminate` | State trigger |
| Rescue interruption | `design/gdd/downing-and-rescue.md` | Rescue interaction rules | Rule dependency |
| Disguise on monster reconnect | `design/gdd/borrowed-face.md` | Disguise state rules | Rule dependency |
| Emergency mode | `design/gdd/scare-events.md` | Response to `RoundPhaseChanged` | State trigger |
| Exit volume, spawns | `design/levels/research-facility.md` | Zone C exit, spawn points | Data dependency |
| Results stats | `design/gdd/monster-abilities.md`, `design/gdd/survivor-defense.md` | Ability/stun counts | Data dependency |

## Acceptance Criteria

- [ ] With 5 clients connected, a round starts, passes through Infiltration (0:00), Investigation (2:00) and Evacuation (7:00), and ends at 9:00 with "Shapeshifter Wins — Evacuation deadline expired" if no objectives are done.
- [ ] All 5 clients show the same phase within 200 ms of each `RoundPhaseChanged`, and the same outcome, reason and results payload at round end.
- [ ] Arming the terminal at 5:00 switches all 5 clients to Evacuation at 5:00; the deadline remains 9:00.
- [ ] When all 4 survivors are eliminated (including by bleed-out), the round ends at that moment with "All survivors eliminated".
- [ ] Survivors win only when both drives have been carried through the open exit; one drive out is not a win.
- [ ] A survivor escaping without drives is recorded as Escaped and the round continues.
- [ ] If nobody is left inside and a drive was not extracted, the round ends at once with "Evidence lost".
- [ ] A Downed survivor in the exit volume is not recorded as escaped.
- [ ] Starting the 15 s activation at 8:50 results in a monster win at 9:00.
- [ ] A modified client that sends a fake "round won" or "phase change" message has no effect on any client's state.
- [ ] Disconnecting a survivor drops their carried items at once. Reconnecting within 60 s restores their position, state and down count. Staying away 60 s counts them as eliminated.
- [ ] A Downed survivor who disconnects with 20 s of bleed-out left is Eliminated ("Bled out") 20 s later, while still disconnected.
- [ ] With the drives not out and only Downed survivors inside, the round does not end until the last bleeds out, then ends "All survivors eliminated".
- [ ] Disconnecting the shapeshifter for more than 60 s ends the round as a survivor win, reason "Shapeshifter forfeited", on all clients; one that reconnects within 60 s appears in true form.
- [ ] Disconnecting the shapeshifter at 8:30 with no drives out ends the round at 9:00 as a monster win, reason "Evacuation deadline expired", not a forfeit.
- [ ] If one client fails to load within `load_timeout_s`, the round is cancelled, all 5 return to the lobby and no result is recorded.
- [ ] Arming the terminal at 1:00 moves all clients from Infiltration straight to Evacuation with one `RoundPhaseChanged`.
- [ ] After both drives are Extracted at 8:00, eliminating every survivor still inside does not change the outcome, and the round ends no later than 8:45 (`post_escape_window_s`).
- [ ] When the second drive is Extracted in the same tick as the deadline, the survivors win.
- [ ] The results screen lists outcome, reason, every survivor's status, objective progress (x/2 drives, x/2 fuses, activation, x/2 extracted) and the stats in rule 26.
- [ ] All values in Tuning Knobs are read from data, not hardcoded.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Should Evacuation start early when the terminal is armed (rule 6), or only at 7:00? | SneakKestrel16 | Before Milestone 2 | Recommended: early (proposed) |
| Is the hard deadline (no overtime, activation can be cut off) too harsh? Alternative: freeze the clock once activation completes, with an escape window | SneakKestrel16 | Before Milestone 5 | Playtest |
| Should "all remaining survivors Downed with no one able to rescue" end the round early as a monster win? | SneakKestrel16 | Before Milestone 2 | **Resolved 2026-10-12:** bleed-out eliminates them; the round ends when everyone is eliminated |
| Should "Evidence lost" (nobody left inside, drives not out) end the round immediately? | SneakKestrel16 | Before Milestone 2 | Proposed: yes |
| Should the shapeshifter be prevented from attacking during Infiltration? | SneakKestrel16 | Before Milestone 3 | Open |
| Confirm the disconnect rule (60 s grace, survivor counted as eliminated, monster → survivor win by forfeit) | SneakKestrel16 | Before Milestone 1 | Monster forfeit **decided 2026-10-11** (was No Contest; cross-review blocker 4); the rest proposed |
| Should the results screen reveal the shapeshifter player's name? | SneakKestrel16 | Before Milestone 2 | Proposed: yes |
| Can survivors who are Downed escape by crawling to the exit? | SneakKestrel16 | Before Milestone 2 | Proposed: no |
| Cooldowns keep counting down while the shapeshifter is disconnected (rule 20), so a mid-chase disconnect and reconnect within grace refreshes its abilities at the cost of its disguise. Should cooldowns pause instead? | SneakKestrel16 | Before Milestone 3 | Open (design review 2026-10-11) |
