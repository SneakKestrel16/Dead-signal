# Survivor Objectives

> **Status**: Draft
> **Author**: SneakKestrel16
> **Last Updated**: 2026-10-12
> **Last Verified**: 2026-10-11
> **Implements Pillar**: Readable Objectives, Human Deception, Counterplay

## Summary

Survivor Objectives is the survivors' task chain: recover two data drives from secured rooms, find and install two fuses to restore power, then activate the evacuation terminal and hold it for 15 seconds so someone can escape with the evidence. Objective locations are drawn each round from authored candidate points. The server owns every bit of objective progress. The tasks give survivors a clear goal and give the shapeshifter predictable places to hunt and to fake.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `First-Person Controller & Interaction, Facility Map, Match Flow & Win Conditions`

## Overview

Survivors need three things before they can leave: two data drives (evidence), two installed fuses (power), and a completed 15-second evacuation activation at the terminal in Zone C. Drives sit in secured rooms. Each drive is carried by one survivor, so losing that survivor puts the evidence at risk. Fuses are found in the facility and installed at fuse boxes in Zone B. The install is loud, and the shapeshifter learns roughly where it is happening. When the drives are docked and power is restored, the terminal can be activated. The team must then hold the area for 15 seconds, after which the exit opens. Every interaction is a timed hold. The server checks every one of them, and no client can report an objective as complete.

## Player Fantasy

Survivors are a small crew doing dangerous chores in the dark. Every task is a decision about who stands watch and who works, and about whether to trust the "teammate" offering to carry the drive. The shapeshifter sees objectives as a map of where survivors must go: a fuse box is a noise beacon, a drive carrier is a priority target, and the terminal is the last stand it has to break.

## Detailed Design

### Core Rules

**Shared rules for all objective interactions**
1. Every objective interaction is a timed hold-to-interact (pattern owned by First-Person Controller & Interaction). The client only asks to start or stop. The server checks range, line of sight to the object, the actor's role and state, and the elapsed time. Only the server completes the interaction and broadcasts `ObjectiveProgressChanged`. A client message saying "done" is ignored.
2. Only a survivor in the Healthy state can start or continue an objective interaction. Being Downed, being hit, moving out of `interact_range_m` = 2.0 **(proposed)**, or releasing input cancels it.
3. Cancelled hold interactions lose their progress (they reset) **(proposed)**. The evacuation activation is the exception (rule 16).
4. When Match Flow ends the round, all objective state freezes.

**Randomization (owned here; candidate points authored in Facility Map)**
5. At round start the server picks the active points uniformly at random from the authored candidates and replicates only the active ones to clients **(proposed: the shapeshifter is told all active points; survivors discover them)**:
   - 2 drive rooms from `drive_candidates` = 6 secured-room candidates (5 in Zone A, 1 in Zone C's Records Archive) **(proposed counts)**.
   - 2 fuse spawns from `fuse_candidates` = 7 candidates across all zones and corridors **(proposed)**.
   - 2 active fuse boxes from `fuse_box_candidates` = 3 candidates, all in Zone B **(proposed)**.
   - 1 evacuation terminal from `terminal_candidates` = 3 candidates in Zone C, randomized **(proposed; the Facility Map authors 3 terminal candidates; see Open Questions)**.
   - 1 exit, fixed in Zone C (Evacuation Hall) **(proposed)**; it does not move with the terminal.
6. Placement constraints **(proposed)**: two active points of the same type are never in the same room; the two active fuse spawns are in different zones (each service corridor counts as its own zone); no drive or fuse candidate is in the survivor spawn room; an active terminal and an active drive are never in the same room. Exact placements are authored in `design/levels/research-facility.md`. Placement uses only authored points; no geometry is generated.
7. Discovery **(proposed)**: fuse boxes and the terminal are always marked on survivor HUDs. A drive room or fuse spawn is marked for all survivors once any survivor has had it in view within `discover_range_m` = 8. This keeps the "what next" readable without handing out the whole route.

**Data drives**
8. `data_drives_required` = 2. Each drive is retrieved from its secured room by a `drive_extract_s` = 5 **(proposed)** hold at the room's drive console. On completion the drive goes to the extracting survivor.
9. "Each drive is carried by one player" means a survivor can carry at most one drive at a time **(proposed reading)**. Two different survivors must carry the two drives. A survivor already carrying a drive cannot extract or pick up a second one.
10. A carried drive is visible on the carrier's model and shown on every survivor's HUD next to the carrier's name **(proposed)**. Carrying a drive does not slow the carrier **(proposed)**.
11. A survivor can drop a drive on purpose (instant) **(proposed)**. Any Healthy survivor without a drive can pick a dropped drive up with a `pickup_s` = 1 **(proposed)** hold.
12. *Carrier downed* **(proposed)**: when the server processes `SurvivorDowned` for a carrier, the drive drops at the downed position, is marked for all survivors as "Drive dropped", and can be picked up by another survivor. If the carrier is rescued, the drive is not returned automatically; they must pick it up again.
13. *Carrier eliminated or disconnected* **(proposed)**: the drive drops at their last position (it is already on the ground if they were Downed). A dropped drive stays where it fell for the rest of the round. It never despawns or respawns, and it cannot be destroyed.
14. *Docking* **(proposed)**: a carrier places a drive into one of the terminal's two drive slots with a `dock_s` = 2 hold. A docked drive is permanent: it cannot be removed and no longer has a carrier. Drives can be docked before power is restored.

**Fuses**
15. `fuses_required` = 2. Picking up a fuse is a `pickup_s` = 1 hold. A survivor can carry one fuse at a time **(proposed)**, and can carry a fuse and a drive together **(proposed)**. Installing a fuse at an active fuse box is a `fuse_install_s` = 8 **(proposed)** hold. A carried fuse drops on down, elimination or disconnect, the same way as a drive (rules 12–13) **(proposed)**.
16. *Noise and monster alert* (source: "alerts the monster to the general area"): when an install starts, the server (a) plays a loud, spatialized install sound audible to everyone within `install_noise_radius_m` = 25 **(proposed)**, and (b) sends only the shapeshifter's client an area marker: a circle of radius `alert_area_radius_m` = 10 **(proposed)**, whose centre is offset by a random amount up to that radius so it never pinpoints the box. The marker lasts `alert_duration_s` = 5 **(proposed)**. A cancelled and restarted install raises a new alert. Installed fuses are permanent.
17. Power is restored when both fuses are installed. This is broadcast as `ObjectiveProgressChanged` (power restored).

**Evacuation terminal**
18. The terminal is **armed** when both drives are docked and both fuses are installed. Match Flow reads this state (it may start Evacuation early; see `match-flow.md`).
19. Any Healthy survivor starts activation at the armed terminal with an `activation_start_s` = 1 **(proposed)** hold. After that, the source's 15-second activation runs as a **hold-the-area countdown** **(proposed)**: `evac_activation_s` = 15 counts down only while at least one Healthy survivor is inside the authored terminal zone (Facility Map). If no Healthy survivor is in the zone, the countdown **pauses** and keeps its progress **(proposed)**. It does not reset. The shapeshifter's presence, disguised or not, neither counts toward holding the zone nor blocks it **(proposed)**.
20. When the countdown reaches 0 the server marks **evacuation activated**, opens the exit, and broadcasts `ObjectiveProgressChanged`. From then on, Match Flow treats a Healthy survivor entering the exit volume as a qualifying escape.

**The "escape with the required evidence" rule**
21. *The ambiguity*: the source says survivors must "use the recovered evidence and restored power at the evacuation terminal", and also that at least one survivor must "escape with the required evidence". It never says whether the drives are consumed at the terminal (so any escape counts) or must be physically carried out through the exit after activation.
22. *Recommended reading* **(proposed)**: the drives are docked into the terminal and consumed. Activation transmits the evidence. The "required evidence" is satisfied when evacuation is activated. **"At least one survivor escapes with the required evidence" therefore means: evacuation has been activated (which required both drives docked and both fuses installed) AND at least one Healthy survivor enters the exit volume before the evacuation deadline.**
23. *Why*: it keeps the endgame readable (one terminal, one hold, then run). It avoids a second "who has the drives" scramble after the holdout. It ties the 15-second holdout directly to the win. And it fits the title (the signal goes out).
24. *Alternative reading (not recommended)*: after activation the drives are ejected, and an escaping survivor must carry at least one (or both) drives through the exit. This adds a final carrier hunt for the shapeshifter, but it makes the outcome hinge on one player's position. Logged as an Open Question.

**The shapeshifter and objectives**
25. *Recommended rule* **(proposed)**: the shapeshifter can **fake** an objective interaction but can never make real progress. In any form it can play the interact animation and the authentic interaction sound at any objective point (drive console, fuse box, terminal). The server makes no state change, and the progress bar shown to survivors above the object does not move. The shapeshifter cannot pick up, carry, dock, install, drop, move or destroy drives or fuses, cannot start activation, and does not count toward holding the terminal zone.
26. *Why*: Human Deception gets a strong, cheap bluff ("I'm on the fuse box, cover me"). Counterplay and Readable Objectives get a learnable, verifiable tell: a survivor who looks at the progress bar can catch the fake. Real objective state is never corrupted, so the HUD checklist is always true. A fake fuse install does not trigger the install noise or the alert in rule 16 **(proposed)**; the progress bar and the missing loud install sound are both tells.
27. All objective progress bars and the HUD checklist come from server state only.

### States and Transitions

**Data drive**

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| Secured | Round start at an active drive room | Extract completes → Carried | Console interactable by Healthy survivors |
| Carried | Extract or pickup completes | Drop / carrier Downed / Eliminated / Disconnected → Dropped; dock completes → Docked | Shown on carrier and HUD |
| Dropped | See above | Pickup completes → Carried | World-marked for survivors |
| Docked | Dock completes | — (permanent) | Fills a terminal slot |

**Fuse**: Unfound → Carried → (Dropped ↔ Carried) → Installed (permanent). Same drop rules as drives.

**Evacuation terminal**

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| Locked | Round start | 2 drives docked and 2 fuses installed → Armed | Drive slots accept docking |
| Armed | Requirements met | Activation start completes → Activating | Match Flow notified |
| Activating | Start hold done | Countdown 0 → Activated | Counts down while ≥1 Healthy survivor in zone; pauses otherwise |
| Activated | Countdown 0 | Round end | Exit open; escapes qualify |

### Interactions with Other Systems

| System | Data in | Data out | Responsibility |
|--------|---------|----------|----------------|
| First-Person Controller & Interaction | Start/stop interact requests | Hold durations, cancel rules | Controller provides the hold pattern; this doc sets durations |
| Facility Map | Candidate points, terminal zone, exit volume | Chosen active points | Map authors points; this system picks them |
| Match Flow & Win Conditions | `RoundPhaseChanged`, round end | `ObjectiveProgressChanged` (armed, activated, completion times); evidence rule | Match Flow decides the outcome |
| Downing, Rescue & Elimination | `SurvivorDowned`, `SurvivorEliminated` | — | Triggers carried-item drops |
| Borrowed Face | Disguise state | Fake-interact permission | Borrowed Face decides what a disguise copies |
| Monster Abilities | — | Install alert to the shapeshifter | False Signal may imitate interaction sounds (its rule) |
| Pings & Callouts | — | Objective point identities for pings | Pings let survivors mark objectives |
| Survivor Defense | Hidden / item-use state | — | Hidden survivors cannot interact |
| Scare Events | — | `ObjectiveProgressChanged` (install, power restored) | Scare Events decides presentation |
| HUD & Results Screen | — | Checklist, carriers, progress bars, completion times | HUD presents |
| Match Telemetry | — | Completion times, drops, fake interactions | Logs |

## Formulas

### Effective activation time

```
activation_elapsed_s = Σ ticks where (state = Activating AND healthy_survivors_in_zone ≥ 1) × tick_length_s
activated when activation_elapsed_s ≥ evac_activation_s
real_time_to_activate_s = evac_activation_s + total_paused_s
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| evac_activation_s | float | 10–25 | data | 15 (source) |
| healthy_survivors_in_zone | int | 0–4 | server | Shapeshifter never counted |
| total_paused_s | float | ≥ 0 | server | Time the zone held no Healthy survivor |

**Example**: the team holds 9 s, everyone is driven out for 6 s, then they return and hold 6 s → activated after 21 s of real time.

### Minimum objective time (no travel, no interruptions)

```
min_work_s = 2×drive_extract_s + 2×pickup_s + 2×fuse_install_s + 2×dock_s + activation_start_s + evac_activation_s
           = 10 + 2 + 16 + 4 + 1 + 15 = 48 s (proposed values)
```
With the work spread across four survivors, the minimum is dominated by travel. This must stay well below the 300 s Investigation window so that the round time goes to travel, caution and deception, not to holding buttons.

### Install alert placement

```
alert_centre = fuse_box_position + random_point_in_disc(alert_area_radius_m)
```
The real box is always within `alert_area_radius_m` of the centre, so the marked circle of radius `alert_area_radius_m` always contains it. Example: radius 10 m, offset 7 m north → the box is inside the circle but not at its centre.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Drive carrier downed while docking | Dock cancels (resets); drive drops at their position | Rules 2, 3, 12 |
| Drive carrier downed in the same tick a teammate starts rescuing them | Drive drops anyway; the rescuer can't pick it up while rescuing | One interaction at a time |
| Drive dropped in a spot the shapeshifter camps | Stays there; survivors must contest it | Creates counterplay, no despawn |
| Both drives with one survivor | Not possible: max one drive per survivor | Rule 9 |
| Last Healthy survivor in the terminal zone is downed mid-countdown | Countdown pauses with progress kept | Rule 19 |
| Round deadline hits during activation | Activation never completes; Match Flow ends the round as a monster win | Owned by Match Flow (hard deadline) |
| Disguised shapeshifter "installs" a fuse | Animation and quiet interact sound only; no progress, no install noise, no alert | Rules 25–26 |
| Shapeshifter stands in the terminal zone alone | Countdown is paused | Rule 19 |
| Two survivors try to install at the same fuse box | Second request refused; one interaction per point | Server check |
| A survivor holding a fuse rescues a teammate | Allowed; carried items do not block rescue | Carrying is passive |
| A client claims an extract completed early | Ignored; the server completes it only after the duration | Server authority |
| A dropped item lands somewhere it can't be reached (physics) | The server places dropped items at the nearest valid floor point at the carrier's position, no physics | Prevents a soft-lock |
| A carrier disconnects | Items drop at once, before the reconnect grace | Matches Match Flow rule 17 |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| First-Person Controller & Interaction | This depends on it | Timed hold-to-interact |
| Facility Map | Bidirectional | Needs candidate points, terminal zone, exit; Map must author enough candidates |
| Match Flow & Win Conditions | Bidirectional | Reads round end and phase; Match Flow reads armed/activated and the evidence rule |
| Downing, Rescue & Elimination | This depends on it | Down/elimination triggers drops; Downed survivors can't interact |
| Network Authority & Replication | This depends on it | Server validation and replication of objective state |
| Borrowed Face | Bidirectional | Fake-interaction rule while disguised; Borrowed Face decides whether carried items show on a disguise |
| Monster Abilities | It depends on this | False Signal may imitate objective interaction sounds |
| Pings & Callouts | It depends on this | Objective points as ping targets |
| Survivor Defense | It depends on this | Hidden survivors and survivors using items cannot interact with objectives; hiding does not drop carried items |
| Scare Events | It depends on this | Fuse install alarm and power restored (`ObjectiveProgressChanged`) drive scare and lighting states |
| HUD & Results Screen | It depends on this | Displays checklist and progress |
| Match Telemetry | It depends on this | Completion times |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| evac_activation_s | 15 (source) | 10–25 | Longer holdout; monster favoured | Shorter holdout |
| drive_extract_s **(proposed)** | 5 | 3–10 | More exposure in secured rooms | Drives trivial |
| fuse_install_s **(proposed)** | 8 | 5–12 | Longer noisy exposure | Alert matters less |
| dock_s **(proposed)** | 2 | 1–4 | More terminal exposure | — |
| pickup_s **(proposed)** | 1 | 0.5–2 | Dropped items riskier | Instant swaps |
| activation_start_s **(proposed)** | 1 | 0.5–3 | — | — |
| interact_range_m **(proposed)** | 2.0 | 1.5–3 | Easier interaction | Tighter positioning |
| alert_area_radius_m **(proposed)** | 10 | 5–20 | Vaguer alert | Pinpoints survivors |
| alert_duration_s **(proposed)** | 5 | 3–10 | Monster tracks longer | Easier to miss |
| install_noise_radius_m **(proposed)** | 25 | 15–40 | More players hear it | Quieter |
| discover_range_m **(proposed)** | 8 | 4–15 | Faster discovery | More searching |
| drive_candidates / fuse_candidates / fuse_box_candidates / terminal_candidates **(proposed)** | 6 / 7 / 3 / 3 | 4–8 / 4–9 / 2–4 / 1–3 | More variety | Rounds feel the same |

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Interaction in progress | World-space progress bar over the object (survivors) | Per-type interact loop | MVP |
| Fake interaction | Same animation; bar does not move | Quiet interact loop, no install noise | VS |
| Fuse install | Sparks | Loud spatialized install sound | MVP |
| Monster install alert | Offset circle on monster HUD | Monster-only cue | MVP |
| Drive dropped | Glowing drive on floor, HUD marker | Clatter | MVP |
| Power restored | Facility lights step up | Generator spin-up | MVP |
| Activation countdown | Terminal display and HUD countdown; pause state shown | Rising tone; stalls when paused | MVP |
| Exit opens | Exit lights, HUD marker | Door alarm | MVP |

## Game Feel

### Feel Reference
Dead by Daylight generator repair: committed, exposed, and audible. Anti-reference: instant pickups that make objectives feel like checkboxes.

### Input Responsiveness
| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|------------------------|-------|
| Interact start (local bar appears) | 100 | 6 | Client predicts the bar; server confirms or cancels |
| Completion shown | 200 | 12 | Only after server confirms |

### Animation Feel Targets
| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|-----------|---------------|--------------|----------------|-----------|-------|
| Interact loop | 6 | Hold duration | 6 | Grounded, committed | Fake version must match |

### Impact Moments
| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Power restored | 1500 | Lights flare up across the facility | Yes (reduced flash) |
| Evacuation activated | 1000 | Terminal flash, exit alarm | Yes (reduced flash/volume) |

### Weight and Responsiveness Profile
- **Weight**: Deliberate. Every hold is a commitment.
- **Player control**: The player can cancel at any time by releasing.
- **Snap quality**: Progress is smooth; completion is a crisp event.
- **Acceleration model**: Linear progress.
- **Failure texture**: A reset bar always has a visible cause (hit, moved, released).

### Feel Acceptance Criteria
- [ ] Playtesters describe fuse installs as "risky" or "loud" without prompting.
- [ ] No playtester reports an objective completing or failing without a visible reason.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|-----------------|-----------|
| Checklist: drives x/2 (carried/docked), fuses x/2, terminal state | HUD side panel | On `ObjectiveProgressChanged` | Survivors and shapeshifter |
| Drive carriers | Next to teammate names | On change | Survivors |
| Discovered points, dropped items | World markers | On change | Survivors |
| Progress bars | World space over objects | Continuous | Visible to nearby survivors |
| Activation countdown and pause | HUD and terminal | Continuous | Activating |
| Install alert | Monster HUD | On alert | Shapeshifter |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|-----------|----------------------------|--------|
| Outcome and deadline | `design/gdd/match-flow.md` | Win evaluation, evacuation deadline | Rule dependency |
| Phase start of Evacuation | `design/gdd/match-flow.md` | `RoundPhaseChanged` | State trigger |
| Disconnect drops | `design/gdd/match-flow.md` | Disconnect rule | State trigger |
| Carrier downed/eliminated | `design/gdd/downing-and-rescue.md` | `SurvivorDowned`, `SurvivorEliminated` | State trigger |
| Healthy-only interaction | `design/gdd/downing-and-rescue.md` | Survivor states | Rule dependency |
| Disguise copying carried items | `design/gdd/borrowed-face.md` | Disguise appearance rules | Rule dependency |
| Fake interaction sounds | `design/gdd/monster-abilities.md` | False Signal | Rule dependency |
| Objective pings | `design/gdd/pings-and-callouts.md` | Ping targets | Data dependency |
| Hidden survivors cannot interact | `design/gdd/survivor-defense.md` | Hiding spots | Rule dependency |
| Install alarm, power restored scare state | `design/gdd/scare-events.md` | Environment scares, Power Restored overlay | State trigger |
| Candidate points, terminal zone, exit | `design/levels/research-facility.md` | Authored objective points | Data dependency |

## Acceptance Criteria

- [ ] Over 20 rounds, active drive rooms, fuse spawns, fuse boxes and the terminal vary, all come from authored candidates (6 drive, 7 fuse, 3 fuse box, 3 terminal), and no round breaks a rule 6 placement constraint.
- [ ] A survivor holding interact at a drive console for 5 s receives the drive. Releasing at 4 s gives nothing and resets the bar.
- [ ] A survivor carrying a drive cannot pick up or extract a second drive.
- [ ] Downing a carrier drops the drive at their position on all 5 clients within 200 ms, and another Healthy survivor can pick it up.
- [ ] Starting a fuse install plays the install sound for players within 25 m and shows the shapeshifter an area circle that contains the box. The circle is not centred on the box in at least 90% of 50 tests.
- [ ] The terminal accepts activation only when 2 drives are docked and 2 fuses installed. The countdown takes 15 s with a survivor in the zone and pauses when the zone holds no Healthy survivor.
- [ ] A shapeshifter (disguised or not) interacting with any objective changes no objective state on any client, and does not count toward the terminal zone.
- [ ] A modified client sending a "complete" message for any interaction causes no state change.
- [ ] All 5 clients show identical objective state (checklist, carriers, docked/installed counts, terminal state) at every `ObjectiveProgressChanged`.
- [ ] After activation, a Healthy survivor entering the exit is reported to Match Flow as a qualifying escape without carrying any drive.
- [ ] All values in Tuning Knobs are read from data, not hardcoded.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Are drives consumed at the terminal (any escape after activation counts) or must they be carried out through the exit? | SneakKestrel16 | Before Milestone 2 | Recommended: consumed (proposed) |
| Can the disguised shapeshifter interact with objectives? | SneakKestrel16 | Before Milestone 3 | Recommended: fake-only, no progress, no carrying (proposed) |
| Does a disguise show the copied survivor's carried drive or fuse? (affects tells) | SneakKestrel16 | Before Milestone 3 | Owned by Borrowed Face |
| Is the 15 s activation a held button by one survivor, or a hold-the-area countdown (recommended), and does it pause or reset when the area is lost? | SneakKestrel16 | Before Milestone 2 | Recommended: zone countdown that pauses (proposed) |
| What makes a "secured room" secured: just a location, or a locked door, keycard or code? | SneakKestrel16 | Before Milestone 2 | Open |
| How are survivors told where objectives are (always marked, discovered on sight, or found through "first clues")? | SneakKestrel16 | Before Milestone 2 | Proposed: discovered on sight |
| All proposed interaction durations (5/1/8/2/1 s) | SneakKestrel16 | Before Milestone 5 | Playtest |
| Should a downed carrier keep the drive instead of dropping it? | SneakKestrel16 | Before Milestone 2 | Proposed: drop |
| Is the evacuation terminal randomized among 3 Zone C candidates (current proposal, matches the Facility Map) or fixed in the Evacuation Hall for a more readable endgame? | SneakKestrel16 | Before Milestone 2 | Proposed: randomized 1 of 3 |
| Are fuse boxes randomized (2 of 3) or fixed? | SneakKestrel16 | Before Milestone 2 | Proposed: 2 of 3 |
