# Borrowed Face

> **Status**: Draft
> **Author**: SneakKestrel16
> **Last Updated**: 2026-10-12
> **Last Verified**: 2026-10-11
> **Implements Pillar**: Human Deception (primary), Fair Fear, Counterplay

## Summary

Borrowed Face lets the shapeshifter take the appearance and basic movement presentation of a survivor it has observed. Changing form takes 2 seconds, makes a nearby audio distortion, and has a 12-second cooldown. It is the game's signature mechanic: survivors can never be fully sure a teammate is a teammate, but they always have learnable ways to check.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Network Authority & Replication, First-Person Controller & Interaction, Survivor Defense`

## Overview

The shapeshifter is a human player. During the round it watches survivors; once the server decides a survivor has been *observed*, the shapeshifter can transform into that survivor. Other players then see a second copy of their friend walking the facility. The copy looks and moves like the survivor but cannot do what a real survivor does: it carries no evidence, cannot progress objectives, and is somewhere the real survivor is not. Survivors catch it by listening for the transformation cue, comparing locations and behaviour, and checking shared objective knowledge. The shapeshifter can drop the disguise and return to its true form; that change, seen up close, is a player-triggered jumpscare (the transformation reveal).

## Player Fantasy

**Shapeshifter:** "I am wearing your friend's face, and you just handed me your back." Patience and acting are rewarded: walking like them, going where they would go, and choosing the moment to stop pretending.

**Survivors:** paranoia that is *solvable*. When a survivor unmasks the monster, it should feel like deduction ("Sam has the drive, and you don't"), never a coin flip. When a survivor is fooled, they should be able to name the clue they missed.

## Detailed Design

### Core Rules

**Observation (the "observed survivor" rule)**

1. The server tracks, for each survivor, an observation timer `obs_time[survivor]` that starts at 0 each round.
2. Each server tick, `obs_time[survivor]` increases by the tick time if all of the following are true (all **(proposed)**):
   - the survivor is within `observe_range_m` = 15 m of the shapeshifter's eye position;
   - the survivor is within the shapeshifter's view cone, `observe_fov_deg` = 90° horizontal, centred on its look direction;
   - an unobstructed line of sight exists from the shapeshifter's eye to any of the survivor's body points (head, chest, pelvis); walls, closed doors and closed hiding spots block it; glass partitions do not;
   - the shapeshifter is not Stunned.
3. When `obs_time[survivor]` reaches `observe_time_s` = 3 s cumulative **(proposed)**, that survivor becomes *observed* for the rest of the round. Progress does not decay **(proposed)**. The shapeshifter may observe in any form, including while disguised.
4. Only the server decides observation; the shapeshifter's client never reports it. The shapeshifter's HUD shows observation progress and which faces are available; survivors receive no indication that they were observed **(proposed)**.

**Starting form**

5. The shapeshifter begins each round in its true form at the monster spawn point authored in the Facility Map, with no observed survivors **(proposed)**. The Infiltration phase is when it "establishes a disguise" (source).

**Transformation**

6. The shapeshifter may request a form change to (a) any observed survivor who is Healthy or Downed, or (b) its true form. It cannot transform into an Eliminated or disconnected survivor **(proposed)**.
7. The server accepts the request only if: the form-change cooldown is not running; the shapeshifter is not Stunned; it is not in Predatory Lunge wind-up, active or takedown commit (`takedown_commit_s`, Downing, Rescue & Elimination); and it is not already transforming. Otherwise the request is rejected with no effect and no cooldown cost.
8. Transformation takes `transform_duration_s` = 2 s (source). During it:
   - a distortion sound plays at the shapeshifter's position, audible to every client within `distortion_radius_m` = 15 m **(proposed)**, spatialised so its direction can be found (source: "nearby audio distortion");
   - the body shows a subtle visual warp over its current appearance **(proposed)**;
   - the shapeshifter can move at walking speed but cannot sprint, interact, or use abilities **(proposed)**.
9. At the end of the 2 s, the server switches the form, emits `FormChanged` (shapeshifter, previous form, new form, server time), and starts the 12 s cooldown (source value; starting it at *completion* is **(proposed)**).
10. A stun that lands during a transformation interrupts it: the form does not change and the full 12 s cooldown starts **(proposed)**. Transformation cannot be started while Stunned, so it can never be used to escape a stun (source). A stun on a disguised shapeshifter never reveals it (designer decision, 2026-10-11): the stagger plays on the borrowed survivor body with that survivor's shocked grunt, and there is no monster pain cry. In true form the stagger uses the monster body and pain cry.
11. Transformation can never cancel an attack (source). Predatory Lunge requires true form (designer decision for now, 2026-10-12; **test in playtest**, see Open Questions); a disguised shapeshifter must transform first (see `design/gdd/monster-abilities.md`).

**What the disguise copies** (source: "appearance and basic movement presentation")

| Element | Copied? | Notes |
|---|---|---|
| Body, outfit, head, colour identity | Yes | Exact match to the target's survivor appearance |
| Walk, sprint, crouch animations and footstep sound set | Yes | Basic movement presentation |
| Movement speeds | Yes — survivor speeds while disguised **(proposed)** | So speed alone is never a tell |
| Name label (wherever survivor labels are shown) | Yes **(proposed)** | Otherwise the label is a one-glance random tell |
| Flashlight | Cosmetic copy **(proposed)** | Shapeshifter toggles it itself; it has no survivor-defense effect |
| Carried data drive or fuse | **No (proposed)** | Deliberate tell: verify shared objective knowledge |
| Held or carried stun item | **No (proposed)** | |
| Downed / injured presentation | **No (proposed)** | The copy always stands as a healthy survivor |
| Voice | **No** | Whether the monster may use proximity voice is owned by Pings & Callouts |
| Pings and authored callouts as that survivor | Not by this system | Owned by Pings & Callouts |

12. A disguised shapeshifter cannot pick up or carry drives or fuses, cannot add progress to any objective, and cannot rescue a downed survivor **(proposed)**. It may stand at a station and play the hold-to-interact pose, but the server grants no progress; objective state shown to survivors is never altered by a disguise (pillar: Readable Objectives).
13. If the copied survivor is downed or eliminated while the disguise is worn, the disguise stays on **(proposed)**. Walking around as a survivor everyone knows is down is the shapeshifter's risk to take.

**True form and the transformation reveal**

14. Changing from a survivor form to true form is a normal transformation (rule 8: 2 s, distortion, cooldown) **(proposed)**. The 2 s distortion is the fair warning; the reveal lands at its end.
15. On completion into true form, Scare Events reads the `FormChanged` event and plays a *transformation reveal* scare (shared scope) for survivors within `reveal_radius_m` = 10 m with line of sight **(proposed)**. Scare Events decides presentation, emits `ScareTriggered`, and applies scare cooldowns; a suppressed scare never blocks or delays the form change itself.
16. The reveal never locks survivor input (pillar: Fair Fear; owned by Scare Events).

**Learnable tells** (source risk: "never make one random tell the only answer")

No single tell is always available; together they make a disguise beatable by attention, not luck.

| Tell | When it works | Counter it supports |
|---|---|---|
| T1 — Transformation cue | Within 15 m during the 2 s change | Listen for the cue |
| T2 — Two of the same survivor / location contradiction | The real survivor is seen, pings, or is known to be elsewhere | Compare location |
| T3 — Missing carried evidence | The copied survivor is carrying a drive or fuse | Verify shared objective knowledge |
| T4 — No objective progress, no rescue | The copy is asked to help with an interaction | Verify shared objective knowledge |
| T5 — Behaviour and voice | Always, but only as reliable as the group's knowledge of each other | Compare behaviour |

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| True Form | Round start; or transformation into true form completes | Transformation into a survivor form starts | Monster appearance; may use all abilities |
| Transforming | Valid form-change request accepted (rule 7) | 2 s elapse (→ new form) or stun lands (→ previous form) | Distortion audio, visual warp, walk-only, no abilities |
| Disguised (as survivor X) | Transformation into X completes | Transformation starts; round ends | Renders as X to every client; may use False Signal and Blackout |
| Stunned (read from Survivor Defense) | `MonsterStunned` | Stun ends | Form unchanged; disguised stagger uses the borrowed body and survivor grunt (rule 10); cannot start a transformation; interrupts Transforming |

Form-change cooldown runs independently of these states from each completed or interrupted transformation.

### Interactions with Other Systems

- **Network Authority & Replication**: the server owns the disguise state (current form, transforming flag, target, start time, cooldown end). Every client renders the shapeshifter only from that replicated state; clients never decide form. `FormChanged` is sent to all clients; a reconnecting client receives the current form on join. Survivor clients should receive only what is needed to render the presented form, with no marker identifying the entity as the monster, as far as the network layer allows **(proposed)**.
- **Survivor Defense**: reads the Stunned state (`MonsterStunned`). Whether a stun item used on a real survivor does anything (a costly "stun test") is owned there.
- **Monster Abilities**: Lunge requires True Form; False Signal and Blackout are allowed while Disguised and do not break it. False Signal's fake callout voice uses observed survivors (this system supplies the observed list).
- **Downing, Rescue & Elimination**: supplies Healthy/Downed/Eliminated status for rule 6 and 13.
- **Survivor Objectives**: rejects carry, install and progress requests from the shapeshifter in any form (rule 12).
- **Scare Events**: reads `FormChanged` into true form for the reveal scare (rule 15).
- **Pings & Callouts**: owns monster voice rules and whether a disguised monster can ping or call out as the copied survivor.
- **Match Flow & Win Conditions**: round start resets observation and form; `RoundPhaseChanged` has no effect on disguise.
- **HUD & Results Screen**: shapeshifter HUD shows available faces, observation progress, current form, cooldown.

## Formulas

### Observation accumulation

```
each server tick:
  if dist(monster_eye, survivor) <= observe_range_m
     and angle(look_dir, to_survivor) <= observe_fov_deg / 2
     and line_of_sight(monster_eye, survivor_body_points)
     and not monster_stunned:
       obs_time[survivor] += tick_dt
  observed[survivor] = obs_time[survivor] >= observe_time_s
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| observe_range_m | float | 8–25 | data | Max observation distance **(proposed 15)** |
| observe_fov_deg | float | 60–120 | data | Horizontal view cone **(proposed 90)** |
| observe_time_s | float | 1–6 | data | Cumulative seen time to unlock a face **(proposed 3)** |
| tick_dt | float | server tick | server | Time since previous tick |

**Example**: survivor in view at 10 m for 1.5 s, then behind a wall, then in view 1.5 s → 3.0 s → observed.

### Form-change timing

```
form_ready_time = transform_end_time + form_change_cooldown_s
earliest next completed change = form_ready_time + transform_duration_s
```

Example: transform completes at 60.0 s → next request accepted at 72.0 s → next form at 74.0 s. Minimum spacing between completed form changes: 14 s.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|---|---|---|
| Two copies of survivor X are visible at once | Allowed; both render as X | Core deduction moment (T2) |
| Target becomes Eliminated mid-transformation | Transformation completes into X | Target was valid at request time; becomes tell T2 |
| Target disconnects while worn | Disguise stays; no new transforms into them | Mid-match disconnect rule owned by Match Flow |
| Shapeshifter disconnects while disguised | Disguise lost; on reconnect within grace it returns in true form with its observed list kept **(proposed)** | Match Flow rule 20 |
| Stunned during transformation | Interrupted; previous form kept; 12 s cooldown starts | Stun is the counter; no free retry |
| Lunge requested while Disguised | Rejected; must transform first | Lunge requires True Form (kept for now; playtest) |
| Transform requested during a Lunge takedown commit | Rejected | Transformation cannot cancel an attack (source) |
| Disguised monster tries to pick up a drive | Server rejects; no item, no progress | Readable Objectives; tell T3/T4 |
| Round ends mid-transformation | Transformation discarded; results use final state | Match Flow owns end |
| Reconnecting survivor client | Receives current form before rendering the monster | Every client must see the right form |
| Disguised as a survivor who is Downed | Copy stands healthy | Tell T2; deliberate risk |
| Reveal scare suppressed by scare cooldown | Form still changes on time | Scares never gate gameplay |

## Dependencies

| System | Direction | Nature of Dependency |
|---|---|---|
| Network Authority & Replication | This depends on it | Server-owned disguise state, `FormChanged` replication |
| First-Person Controller & Interaction | This depends on it | Movement speeds, animation set, interaction rejection |
| Survivor Defense | This depends on it | Stunned state blocks/interrupts transformation |
| Downing, Rescue & Elimination | This depends on it | Survivor status for valid targets |
| Facility Map | This depends on it | Monster spawn point; line-of-sight blockers |
| Monster Abilities | Depends on this | Form gates Lunge; observed list for False Signal |
| Scare Events | Depends on this | Transformation reveal (`FormChanged`) |
| Pings & Callouts | Depends on this | Disguise state for monster voice/ping rules |
| Survivor Objectives | Depends on this | Rejects carry/progress from the shapeshifter |
| Match Flow & Win Conditions | Depends on this | Round reset of observation and form |
| HUD & Results Screen | Depends on this | Shapeshifter disguise HUD |
| Accessibility Options | Depends on this | Non-audio alternative for the distortion cue |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| transform_duration_s | 2 (source) | 1–4 | Longer warning; disguises harder to use reactively | Reactive swaps; cue easier to miss |
| form_change_cooldown_s | 12 (source) | 6–30 | Commits monster to a face | Face-hopping; T2 weakens |
| distortion_radius_m | 15 (proposed) | 8–25 | Cue more reliable | Monster changes near survivors safely |
| observe_range_m | 15 (proposed) | 8–25 | Faces unlock faster | Monster must get close |
| observe_fov_deg | 90 (proposed) | 60–120 | Easier observation | Must look directly |
| observe_time_s | 3 (proposed) | 1–6 | Infiltration matters more | Faces nearly free |
| reveal_radius_m | 10 (proposed) | 5–15 | More survivors get the scare | Reveal only point-blank |

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|---|---|---|---|
| Transformation (2 s) | Subtle body warp | Spatial distortion within 15 m | MVP |
| Reveal into true form | Monster form completes facing viewers | Reveal sting (Scare Events) | VS |
| Face unlocked (monster only) | HUD portrait unlocks | Quiet UI tick, monster only | MVP |
| Form-change rejected (monster only) | HUD cooldown flashes | None | MVP |

## Game Feel

### Feel Reference

*The Thing* (1982) blood-test scene: everyone looks normal; the truth arrives as a sudden, earned reveal. Anti-reference: a social-deduction "glitch" tell that gives the monster away at random.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|---|---|---|---|
| Request form change | 100 | 6 | Monster hears distortion start locally after server accept |
| Face-select HUD | 50 | 3 | Local only |

### Animation Feel Targets

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|---|---|---|---|---|---|
| Transformation | 0 | 120 (2 s) | 0 | Uneasy, readable | Walk allowed |
| Reveal (into true form) | — | last 12 of the 120 | 0 | Sharp payoff | Presentation by Scare Events |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|---|---|---|---|
| Camera impact (viewers of reveal) | ≤ 300 | Small flinch, no input lock | Yes (reduced flash) |

### Weight and Responsiveness Profile

- **Weight**: deliberate. A form change is a commitment.
- **Player control**: the monster keeps walking control during the change.
- **Snap quality**: the swap at 2 s is crisp; the build-up is gradual.
- **Failure texture**: a caught monster can name the cue it gave away; a fooled survivor can name the tell they missed.

### Feel Acceptance Criteria

- [ ] In playtest, a fooled survivor can name at least one missed tell when asked.
- [ ] No playtester describes catching or missing the monster as "random".

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|---|---|---|---|
| Available faces + observation progress | Shapeshifter HUD | On change | Shapeshifter only |
| Current form and cooldown | Shapeshifter HUD | Each second | Shapeshifter only |
| Transforming progress | Shapeshifter HUD | Continuous | During Transforming |

Survivors get no disguise UI.

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|---|---|---|---|
| Stun blocks/interrupts transformation | `design/gdd/survivor-defense.md` | Stunned state, `MonsterStunned` | State trigger |
| Valid targets | `design/gdd/downing-and-rescue.md` | Healthy/Downed/Eliminated | Data dependency |
| Lunge needs true form | `design/gdd/monster-abilities.md` | Predatory Lunge activation | Rule dependency |
| Reveal scare | `design/gdd/scare-events.md` | `ScareTriggered`, scare cooldowns, shared scope | Ownership handoff |
| Monster voice and pings | `design/gdd/pings-and-callouts.md` | Monster voice rules | Rule dependency |
| No carry/progress by monster | `design/gdd/survivor-objectives.md` | Carry and progress validation | Rule dependency |
| Round reset; disconnect rule | `design/gdd/match-flow.md` | Round start, mid-match disconnect | State trigger |
| Spawn point, LOS blockers | `design/levels/research-facility.md` | Monster spawn, glass partitions | Data dependency |
| Cue alternative | `design/accessibility-requirements.md` | Non-audio cue indicator | Rule dependency |

## Acceptance Criteria

- [ ] Server marks a survivor observed only after 3 s cumulative valid observation within 15 m and the view cone; a survivor behind a wall or closed door accumulates nothing.
- [ ] A form-change request into an unobserved or Eliminated survivor is rejected by the server.
- [ ] A form change completes exactly 2 s (±1 server tick) after acceptance; the next request is rejected until 12 s after completion.
- [ ] A survivor client within 15 m hears the distortion from the correct direction; one at 20 m does not.
- [ ] A stun during transformation leaves the previous form and starts the 12 s cooldown; transformation cannot start while Stunned.
- [ ] Lunge requested while Disguised is rejected; transformation requested during Lunge is rejected.
- [ ] **Multi-client**: with 5 clients connected, after each of 10 form changes, all 5 clients render the shapeshifter in the same form within 250 ms of `FormChanged`, including a client that reconnects mid-disguise.
- [ ] A disguised copy of a drive carrier shows no drive; a pickup or install request from the shapeshifter is rejected and objective state is unchanged on all clients.
- [ ] The copied name label (where labels exist) and footstep set match the target exactly.
- [ ] All values above are read from data, not hardcoded.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Is the observation rule (15 m, 90°, 3 s cumulative, no decay) right, or should observation require a continuous look? | SneakKestrel16 | Before Milestone 3 | — |
| Should Lunge be usable from disguise (instant reveal at wind-up) instead of requiring true form? | SneakKestrel16 | Before Milestone 5 | **Kept True Form only for now (2026-10-12). Playtest note:** in the M5 closed playtest, compare monster win rate, average time from disguise to attack, and whether survivors call the 2 s transform cue a fair warning or too much of a giveaway. Revisit if disguised monsters rarely convert trust into takedowns. |
| Where does the shapeshifter spawn, and is starting in true form right for Infiltration? | SneakKestrel16 | Before Milestone 1 | — |
| Can the monster use proximity voice, preset lines, or both while disguised? (source open decision) | SneakKestrel16 | Before Milestone 3 | **Decided 2026-10-12: both.** Rules in `pings-and-callouts.md` rule 25; the disguise does not copy voice |
| Can survivor clients be kept from learning which entity is the monster? Needs a Network Authority ADR. | SneakKestrel16 | Before Milestone 1 | — |
| What non-audio indicator represents the distortion cue for deaf or hard-of-hearing players? | SneakKestrel16 | Before Milestone 4 | — |
| Does a stun item used on a real survivor do anything (a "stun test")? | SneakKestrel16 | Before Milestone 3 | Owned by Survivor Defense |
