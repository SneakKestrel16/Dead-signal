# First-Person Controller & Interaction

> **Status**: Approved
> **Creative Director Review (CD-GDD-ALIGN)**: skipped — Lean mode
> **Author**: SneakKestrel16 + agents
> **Last Updated**: 2026-10-12
> **Last Verified**: 2026-10-12
> **Implements Pillar**: Fair Fear, Counterplay, Human Deception

## Summary

First-Person Controller & Interaction is the body, view and "do a thing" layer every player shares. It moves players in four gaits (walk 4.0 m/s; sprint 5.0 with no stamina but loud; crouch; crawl), applies the roots, slows and locks other systems request, and provides the one server-validated hold-to-interact pattern that objectives, rescues, barricades and doors reuse. It keeps the round fair and readable: survivors can dodge a lunge on reaction, a revealed chase eventually ends, and a disguise moves exactly like the survivor it copies.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `Network Authority & Replication` (Match Flow events only)

## Overview

First-Person Controller & Interaction is the movement, view and interaction layer every player uses, survivor or shapeshifter. It moves a player's body through the facility in four gaits: walk, sprint, crouch and, when Downed, crawl. It applies the speed changes other systems request: root, slow and movement lock. It turns the player's view into an aim ray for interactions, pings and items. It also provides the one timed **hold-to-interact** pattern that objectives, rescues, barricades, searches, doors and switches all reuse. The client sends only intent: movement input, view direction, and start or stop of an interaction. The server owns positions and validates every interaction against range, line of sight, the actor's state and elapsed time; each owning system sets its own durations and outcomes. Movement is quiet by default and loud when sprinting, so how a player moves is also what others can hear. Disguised, the shapeshifter moves on survivor numbers, so speed is never a tell. There is no jump and no stamina (designer decisions, 2026-10-12). Without this layer no other system has a body to act on or a shared way to "do a thing in the world".

## Detailed Design

### Core Rules

Values marked **(proposed)** are pinned in Formulas.

**Body and movement**

1. Every player, survivor or shapeshifter in any form, has the same upright capsule: radius `player_radius_m` = 0.3, height 1.8 m standing and 1.2 m crouched **(proposed)**. True form looks bigger but collides the same, so a disguise never fits a gap the real survivor could not, and a transformation never sticks in a corridor. Upright capsules are solid against each other for every pair of players alike, survivor or shapeshifter: any difference between survivor–survivor and survivor–shapeshifter collision would be a disguise tell (designer decision, 2026-10-12, design review). Doorway blocking by a teammate is a playtest risk (Open Questions).
2. Gaits: **walk** (default), **sprint**, **crouch**, and **crawl** (Downed only; `crawl_speed_mult` owned by Downing, Rescue & Elimination). Survivors and the disguised shapeshifter use survivor speeds (Borrowed Face: speed is never a tell). True form walks at survivor walk speed and sprints at `monster_sprint_mult` × survivor sprint, slightly faster, so a revealed chase is a clock that doors, tasers, hiding and teammates break **(designer decision, 2026-10-12)**.
3. **Sprint** requires the sprint input held and forward input within 45° of facing; strafe and backpedal always move at walk speed **(designer decision, 2026-10-12)**. A W+A or W+D diagonal is 45° off facing, so it sprints at full sprint speed (about 3.5 m/s of it lateral). No stamina and no limit **(designer decision, 2026-10-12)**; the cost is noise (rule 8). Unavailable while crouched, Downed, Transforming (Borrowed Face rule 8) or Holding.
4. **Crouch** lowers eye height, moves at `crouch_speed_mult` × walk, and makes the quietest footsteps. It has no traversal use: the prototype map has no crouch-only spaces. If something blocks the head, standing up waits until there is room.
5. **No jump** **(designer decision, 2026-10-12)**. The body auto-climbs steps up to `step_height_m` and slopes up to 40°. No fall damage; the map has no drops that need it.
6. **Speed modifiers** come from their owning systems: root (speed 0), slow (multiplier with a duration), lock (no movement). The controller applies only the **most restrictive** active modifier (lock > root > lowest slow); modifiers never multiply together. Each owner adds and removes only its own modifier. A slow scales the current gait's speed.
7. **Look is never taken.** Mouse look is free in every state (yaw 360°, pitch ±85°), except the restricted peek view of a hidden survivor (Survivor Defense rule 20). The **one sanctioned exception** is the Scare Events camera flinch (Scare Events rules 13-14): a server-applied view nudge of at most `scare_max_control_loss_s` = 0.3 s, accessibility-toggleable, never during a lunge wind-up. The server's view direction (rule 10) follows the flinch, so aim and the client's view stay consistent. Every other camera effect (downing and rescue camera impact and screen shake, survivor-defense camera jitter and stun jolt) is a **visual offset only** that never changes the server's view direction or aim ray. No other system rotates or locks a player's camera (pillar: Fair Fear) **(designer decision, 2026-10-12, cross-review 12d)**.
8. **Footstep noise** follows gait: sprint is loudest, then walk, then crouch and crawl (radii in Formulas). Clients play footsteps from each player's replicated gait. A disguised shapeshifter uses its target's footstep set (Borrowed Face). Only real movement makes footsteps; False Signal fakes are separate (Monster Abilities).

**Authority**

9. Each tick the client sends intent only: move vector, sprint and crouch flags, view yaw and pitch, interaction start/stop. The server simulates movement and owns every position; the owning client predicts and reconciles. The client never sets its own position, speed or interaction progress. The prediction and reconciliation method → becomes a Network Authority ADR.

**View ray**

10. The aim ray starts at the eye position and follows the server's copy of the view direction. Taser aim (Survivor Defense), pings (Pings & Callouts) and interaction targeting all use it, and the server validates against its own copy.

**Hold-to-interact pattern**

11. Each interactable is defined by its owning system: action, eligible roles and states, `range_m`, `duration_s` (0 = instant, e.g. doors), `roots_actor`, progress on cancel (reset, keep, or keep and decay), whether it takes an exclusive one-actor lock, and whether the shapeshifter may fake it.
12. **Target:** the nearest interactable along the view ray, within `interact_ray_max_m`, that is also within its own `range_m`. Interactables out of their own range are skipped and do not hide one behind them; world geometry still blocks the ray (designer decision, 2026-10-12, design review). A prompt shows only for a valid target.
13. **Start:** the client sends Start(target). The server checks actor eligibility (shock lock, hidden, Downed, role, per the owner), range (actor capsule centre to the object's interaction point), line of sight (eye to interaction point) and the lock. Rejected: the client's bar cancels. Accepted: **Holding**. The client shows its predicted bar within 100 ms (Survivor Objectives, Game Feel).
14. **While Holding**, the server checks every tick: input still held, range (to `range_m` + `hold_range_tolerance_m` = 0.25, so one tick of prediction drift does not cancel; Start stays strict at `range_m`) (designer decision, 2026-10-12, design review), line of sight, eligibility, and any owner interrupt (e.g. `SurvivorHit`, `PlayerShocked`). Looking away does **not** cancel, so the actor can watch their back. The actor may walk but not sprint, unless the owner sets `roots_actor` (Rescue does, `downing-and-rescue.md` rule 7) **(designer decision, 2026-10-12: owner decides)**. Crouch input is ignored while Holding: a hold started crouched stays crouched and one started standing stays standing, so the capsule centre and the range check never change mid-hold (designer decision, 2026-10-12, design review).
15. **Completion:** when elapsed time reaches `duration_s`, the server completes the hold and notifies the owner; the owner emits its event. A client "done" message is ignored.
16. One hold per actor. Starting another hold, using an item or hiding cancels the current one. A disconnect cancels it; the owner's cancel rule then applies.
17. **Fake holds:** where the owner allows, the shapeshifter's hold plays the same animation and quiet loop, makes no progress and never takes the lock (Survivor Objectives rule 25).
18. **Doors** (rules owned by Survivor Defense, placement by Facility Map) are instant interactions that toggle open and closed. A close is rejected while any capsule overlaps the door's swing area, so a door cannot be closed through a player.

### States and Transitions

| State | Entered by | Move | Look | Interact |
|---|---|---|---|---|
| Free | Default | Walk / sprint / crouch | Free | Yes |
| Holding | Accepted Start | Walk only (crouch speed if started crouched; crouch input ignored); none if `roots_actor` | Free | Current hold only |
| Rooted | Owner root (stun root, rescue, takedown commit, lunge wind-up) | None | Free | Per owner |
| Slowed | Owner slow (stun slow, miss slow) | Gait × multiplier | Free | Per owner |
| Locked | Seized (Downing, Rescue & Elimination) | None | Free | No |
| Downed | `SurvivorDowned` | Crawl only | Free | No (Call for Help per Downing) |
| Hidden | Hide accepted (Survivor Defense) | None | Peek view | Exit hide only |
| Transforming | Borrowed Face rule 8 | Walk only | Free | No |
| Out | Eliminated, Escaped or disconnected | No body | Spectator (Match Flow) | No |

The owning system decides entry and exit; the controller only reads the state and applies its movement, look and interact limits. States can overlap (e.g. Holding + Slowed, Downed + Locked): each column takes the most restrictive value among the active states, and speed follows Effective speed with modifiers.

### Interactions with Other Systems

| System | Flows in | Flows out |
|---|---|---|
| Network Authority & Replication | Server tick; replication of positions | Intent in; authoritative position and gait out |
| Survivor Objectives | Interactable definitions, durations, cancel rules | Start, complete and cancel hold callbacks |
| Downing, Rescue & Elimination | Seized lock, Downed crawl, rescue root, commit root | Hold callbacks for Rescue |
| Survivor Defense | Stun root and slow, shock lock, hidden state, door and barricade definitions | View ray (taser aim); hold callbacks (barricade, hide, search, break) |
| Monster Abilities | Miss slow, wind-up and dash root | True-form speeds; capsule radius (dodge window) |
| Borrowed Face | Form, Transforming flag | Survivor speeds while disguised; footstep set in use |
| Pings & Callouts | — | View ray, input bindings; pinging never changes velocity |
| Facility Map | Step and slope geometry, door swing areas | Walk speed for traversal times |

## Formulas

Every number here is **(proposed)**. Proposed by `systems-designer`, chosen by the designer on 2026-10-12 (option A: sprint 1.25×). The dodge figures come from a stepped pursuit simulation run during authoring: the monster steers toward the survivor's current position at its maximum turn rate; the survivor stands 3 m ahead, then strafes perpendicular from 0.40 s after the cue.

### Gait speed

The gait_speed formula is defined as:

`gait_speed = walk_speed × gait_mult[gait] × form_mult`

`gait_mult` = {walk: 1, sprint: `sprint_mult`, crouch: `crouch_speed_mult`, crawl: `crawl_speed_mult`}. `form_mult` = `monster_sprint_mult` only for a true-form shapeshifter sprinting, otherwise 1. The gait is chosen in this order: **crawl** if Downed; **crouch** if crouched; **sprint** if sprint is held, the angle between move input and facing is ≤ 45°, and the player is not Holding, Transforming or crouched; **walk** otherwise.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| walk_speed | float m/s | 3.7–4.5 | data file | **4.0**: the Facility Map's reference speed, so its traversal times need no rescaling. Also the strafe and backpedal speed |
| sprint_mult | float | 1.15–1.3 | data file | **1.25 → 5.0 m/s**: the highest value at which a straight-line chase still ends in a lunge (Chase closing) |
| crouch_speed_mult | float | 0.4–0.6 | data file | **0.5 → 2.0 m/s**: clearly slow, which pays for the quiet |
| crawl_speed_mult | float | 0.15–0.4 | owned by Downing, Rescue & Elimination | 0.25 → 1.0 m/s |
| monster_sprint_mult | float | 1.1–1.2 | data file | **1.15 → 5.75 m/s**: a 10 m chase lasts about 12 s |
| sprint_cone_deg | float | 45 | constant (designer decision) | Half-angle from facing within which sprint is allowed |
| max_survivor_sprint_mps | float m/s | 5.4 | data file | Joint cap on `walk_speed × sprint_mult`; see the joint cap below |
| hold_range_tolerance_m | float m | 0.25 (safe 0.1–0.4) | data file | Extra keep-range once Holding (Core Rule 14); Start stays strict |
| intent_timeout_ms | int ms | 500 (proposed) | data file | No intent for this long → input released, hold cancelled (Edge Cases) |
| move_input | float | 0–1 | calculated | Length of the stick or key input, capped at 1, multiplied into the speed |

**Output Range:** 0–5.75 m/s in normal play: crawl 1.0, crouch 2.0, walk and strafe 4.0, survivor sprint 5.0, true-form sprint 5.75. Safe-range edges:
- `walk_speed` below about 3.7 (3.68) drops the dodge margin under 1.15 and stretches the map's 20 s room-to-room target by 4.0/walk. Above 4.5 shrinks the map and needs the chase limit rechecked.
- `sprint_mult` below 1.15 makes sprint not worth its noise. Above it, the joint cap below decides.
- **Joint cap (designer decision, 2026-10-12, design review):** the ranges above are safe one at a time, not together. Survivor sprint `walk_speed × sprint_mult` must stay ≤ `max_survivor_sprint_mps` = 5.4, because above about 5.44 m/s `catch_gap` < 2 × `player_radius_m` (at r 0.3) and an open-ground chase becomes lunge-proof; at walk 4.0 that is `sprint_mult` ≤ 1.35. The exact limit depends on the radius, `v_s` ≤ (`lunge_distance_m` + `lunge_hit_radius_m` − `player_radius_m`) / (`lunge_windup_s` + `lunge_dash_s`): 5.44 at r 0.3, 5.39 at r 0.35. So the load-time check asserts both the 5.4 cap and `catch_gap` ≥ 2 × `player_radius_m` from the live data (design re-review, 2026-10-12). True-form sprint must also exceed survivor sprint (`monster_sprint_mult` > 1). All are asserted when the data loads, like the `interact_ray_max_m` check. Example: walk 4.5 × 1.25 = 5.63 is inside both ranges but fails the cap.
- `crouch_speed_mult` above 0.6 competes with walk while staying quiet. Below 0.4 makes crouch a trap.
- `monster_sprint_mult` below 1.1 makes a 10 m chase take more than 18 s. Above 1.2 gives tasers and doors under 9 s to break it.

**Example:** a disguised shapeshifter holding sprint with input 30° off facing moves at 4.0 × 1.25 = 5.0 m/s, the same as any survivor. At 60° off facing it walks at 4.0. In true form it sprints at 4.0 × 1.25 × 1.15 = 5.75.

### Effective speed with modifiers

The effective_speed formula is defined as:

`effective_speed = 0 if (locked or rooted) else gait_speed × move_input × min({1} ∪ active_slow_mults)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| locked | bool | — | owned by Downing, Rescue & Elimination (Seized) | Movement lock |
| rooted | bool | — | owned by Survivor Defense (stun root), Downing, Rescue & Elimination (rescue, takedown commit), Monster Abilities (wind-up) | Root |
| active_slow_mults | set of float | each 0–1 | owned by Survivor Defense (`stun_slow_mult` 0.5), Monster Abilities (`miss_slow_multiplier` 0.5) | Only the lowest applies; slows never multiply together |

**Output Range:** 0 to `gait_speed`. Never negative or above the gait speed, because each slow is clamped to 0–1.

**Example:** a true-form shapeshifter sprinting at 5.75 is tased. For the 1.0 s root it moves at 0; for the remaining 1.0 s at 5.75 × 0.5 = 2.875. With a 0.7 slow also active it is still 2.875.

### Chase closing

The chase_close_time formula is defined as:

`catch_gap = lunge_distance_m + lunge_hit_radius_m + player_radius_m − v_s × (lunge_windup_s + lunge_dash_s)`

`chase_close_time = max(0, gap − catch_gap) / (v_m − v_s)`

It is infinite if `catch_gap` < 2 × `player_radius_m`: two capsules can never be that close, so no straight-line catch is possible. The shapeshifter is rooted during the wind-up, so its own sprint speed does not change `catch_gap`.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| gap | float m | 0–30 | calculated | Centre-to-centre distance when the chase starts |
| v_s | float m/s | 4.3–5.4 | calculated | Survivor sprint, `walk_speed × sprint_mult`, capped by `max_survivor_sprint_mps` (Gait speed) |
| v_m | float m/s | 1.1–1.2 × v_s | calculated | True-form sprint |
| lunge_distance_m, lunge_hit_radius_m, lunge_windup_s, lunge_dash_s | float | 4, 1.2, 0.6, 0.3 | owned by Monster Abilities | Dash and reach |
| player_radius_m | float m | 0.25–0.35 | data file | Capsule radius; the hit is measured to the survivor's body |
| catch_gap | float m | — | calculated | Largest centre gap at wind-up start from which a straight-line lunge still connects |

**Output Range:** `catch_gap` = 5.5 − 0.9 × v_s at r 0.3: 1.18 m at v_s 4.8, 1.0 at 5.0, 0.55 at 5.5 (never), 0.1 at 6.0 (never). The never-catch threshold is v_s ≈ 5.44 m/s, which is why survivor sprint is capped at 5.4 (Gait speed joint cap). Corners cost the survivor time, so the straight-line time is an upper bound.

**Example:** v_s 5.0, v_m 5.75: catch gap 1.0 m; a 10 m gap closes in (10 − 1) / 0.75 = 12 s (18 s at ×1.1, 9 s at ×1.2). A survivor who only walks (4.0) gives a 1.9 m catch gap and is caught from 10 m in 4.6 s, so sprinting pays in a chase.

**Chase breakers:** `gap_gain = v_s × t_root + (v_s − slow × v_m) × t_slow`.
- A taser stun gains 5.0 × 1.0 + (5.0 − 2.875) × 1.0 = 7.1 m, about 9.5 s more chase.
- A miss slow gains (5.0 − 2.875) × 1.5 = 3.2 m.
- After a miss, the 10 s lunge cooldown limits the shapeshifter more than distance does; it re-closes the gap in about 6 s.

### Footstep audible radius

The footstep_radius formula is defined as:

`audible = distance(listener, source) ≤ footstep_radius[gait]`

The attenuation curve that reaches zero at that radius and occlusion through walls are owned by audio implementation (Scare Events' mix rules).

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| footstep_radius_sprint_m | float | 12–25 | data file | **20**: as loud as the lunge cue (`lunge_cue_radius_m` 20), below install noise (25), so objective noise stays the loudest |
| footstep_radius_walk_m | float | 4–8 | data file | **6**: below the hide sound (`hide_noise_radius_m` 8), so walking stays quiet by default |
| footstep_radius_crouch_m | float | 1–3 | data file | **2**: only someone next to you hears it |
| footstep_radius_crawl_m | float | 1–3 | data file | **2**: as quiet as crouch; Downing's Call for Help is the loud option |

**Output Range:** 1–25 m. Fixed order: crouch = crawl < walk < hide (8) < sprint ≤ lunge cue (20) ≤ install (25). The same radii apply in every form, so a true-form shapeshifter is heard at the same distance it hears others. Sprint above 25 is louder than an install; below 12 sprint is nearly free. Walk above 8 makes walking never safe. Crouch above 3 loses its purpose.

**Example:** a survivor sprinting 18 m from the shapeshifter is heard through a wall. Walking at 18 m, or even 7 m, they are not.

### Dodge window consequence

The dodge_margin formula is defined as:

`dodge_margin = strafe_speed / v_dodge_min(player_radius_m)`, where `strafe_speed = walk_speed × slow` (strafing is always at walk speed, Core Rule 3).

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| slow | float | 0–1 | calculated (Effective speed with modifiers) | Lowest active slow multiplier on the survivor; 1 when none |
| lunge_windup_turn_deg_s, lunge_dash_turn_deg_s | float deg/s | 15, 30 | owned by Monster Abilities | Monster's maximum turn rate during wind-up and dash; inputs to the pursuit simulation |
| v_dodge_min | float m/s | 2.65–3.6 | calculated (pursuit simulation) | Slowest strafe that dodges when started 0.40 s after the cue: r 0 → 2.65, 0.3 → 3.2, 0.35 → 3.3, 0.5 → 3.6 |
| player_radius_m | float m | 0.25–0.35 | data file | **0.3**: standard human capsule that still dodges with margin |
| accel_time_s | float s | 0–0.1 | data file | **0.05**: time to reach full ground speed. A linear ramp delays displacement by `accel_time_s` / 2 |

**Output Range:** 1.25 at walk 4.0 and r 0.3; keep it at or above 1.15. Below 1 when crouched (2.0 / 3.2 = 0.63) or at walk ≤ 3.2. A rooted actor (e.g. rescuing) has 0, by design.

**Example:** 4.0 / 3.2 = 1.25, so a walking strafe dodges. A crouched strafe at 2.0 does not: crouch trades the dodge for quiet.

**Acceleration limit (inference):** the critical moment is about 0.37 s into the strafe, and 4.0 m/s leaves about 0.07 s of slack, so `accel_time_s` should stay at or below 0.1. To settle it, rerun the simulation with the strafe starting at 0.40 + `accel_time_s` / 2. Monster Abilities now uses this same steering model (designer decision, 2026-10-12).

### Interaction targeting and body geometry

The interact_ray_max formula is defined as:

`interact_ray_max_m ≥ max_owner_range_m + (eye_height_m − capsule_height_m / 2)`

Range is measured in 3D from the capsule centre to the interaction point. The ray starts at the eye, so by the triangle inequality it must reach this far to see every in-range point.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| max_owner_range_m | float m | 1.5–3 | owned by Survivor Objectives (`interact_range_m` 2.0), Downing, Rescue & Elimination (`rescue_range_m` 1.5) | Largest owner `range_m` |
| eye_height_m | float m | standing 1.5–1.7, crouched 0.9–1.1 | data file | **1.6 / 1.0**: about 0.2 m below the capsule top |
| capsule_height_m | float m | 1.8 / 1.2 | data file (Core Rule 1) | Standing / crouched |
| interact_ray_max_m | float m | 2.7–3.5 | data file | **3.0**: covers 2.0 + 0.7 with 0.3 spare |
| step_height_m | float m | 0.2–0.45 | data file | **0.35**: climbs stairs (~0.18) and kerbs. Below 0.2 the body snags on stairs; above 0.5 it climbs crates, an implied jump |
| player_radius_m | float m | 0.25–0.35 | data file | Doorways at least 2r + 0.2 = 0.8 m clear (inference: margin for collision jitter). Above 0.35 the dodge margin shrinks and 0.9 m doors get tight; below 0.25 bodies visibly clip |

**Output Range:** the required ray length runs from 2.4 (owner range 1.5, eye 1.5) to 3.8 (owner range 3, eye 1.7); crouched, 3.5 at most. 3.0 covers every owner range up to 2.3 m; a larger owner range needs a longer ray.

**Example:** a standing survivor (eye 1.6, capsule centre 0.9) needs 2.0 + 0.7 = 2.7 ≤ 3.0, so a terminal 2.0 m away is always targetable. The Start check measures capsule centre to point, finds 2.0 ≤ 2.0, and accepts. Once Holding, walking out to 2.2 keeps the hold (tolerance 0.25); walking out to 2.3 cancels it on that tick.

## Edge Cases

`systems-designer` was not consulted for this section (Lean mode). Review it manually before production.

- **If a survivor is Downed**: their capsule becomes the crouched 1.2 m one, and it does not block other players' walking, so a Downed body cannot plug a doorway. Monster Abilities rule 6's dash block is its own check and is unchanged.
- **If a player is Eliminated or Escaped**: the body has no collision and the player has no movement (Out state).
- **If two upright players meet**: their capsules block each other (Monster Abilities' dash-block rule relies on solid bodies). A player standing in a door's swing area keeps the door from closing (Core Rule 18). A disguised shapeshifter can hold a door open this way; that is visible behaviour, not a hidden power.
- **If sprint is held while crouched**: crouch wins (gait order, Formulas). The player must uncrouch to sprint.
- **If standing up is blocked** (crouch release, rescue, leaving a hiding spot): the player stays crouched until there is head room.
- **If a speed modifier ends while sprint is held**: the gait resumes on the next tick; no re-press needed.
- **If two players start the same exclusive hold on the same tick**: the server processes them in arrival order. The first is accepted; the second is rejected.
- **If Stop arrives before the server accepted Start**: the hold is accepted and cancelled on the same tick with zero progress.
- **If no intent packet arrives for `intent_timeout_ms` = 500 (proposed)**: the server treats the input as released, cancels any hold and stops movement. A stalled connection cannot keep a hold running.
- **If the hold's target changes mid-hold** (a drive is picked up by someone else; the Downed target is rescued or eliminated): the owner cancels the hold, and its cancel rule applies.
- **If a client's predicted position disagrees with the server**: the server wins. The correction method belongs to the Network Authority ADR.
- **If the server finds a player inside geometry**: it moves them back to their last valid position.
- **If a hidden survivor leaves or is ejected and the spot's front is blocked**: they are placed at the nearest free point within 1 m. If there is none, the exit waits.
- **If a shapeshifter rooted by a takedown commit is also tased**: most restrictive modifier wins. Downing, Rescue & Elimination already cancels the commit on a stun.
- **If a door close is requested during a lunge dash**: it is rejected only if the shapeshifter's capsule is already in the swing area. Otherwise the door closes and the dash stops (Monster Abilities).
- **If a survivor carries drives**: speed is unchanged. Survivor Objectives defines no carry slow.
- **If move input is longer than 1 (diagonal keys)**: it is capped at 1, so a diagonal is never faster.

## Dependencies

| System | Direction | Hard/soft | Interface |
|---|---|---|---|
| Network Authority & Replication | This depends on it | Hard | Server tick, intent transport, position replication, prediction and reconciliation (ADR not yet written; provisional) |
| Match Flow & Win Conditions | Event-only | Soft | Consumes the `RoundEnded` and `PlayerConnectionChanged` events (no other Match Flow state): `RoundEnded` freezes movement and holds; `PlayerConnectionChanged` cancels holds; spectating in the Out state. Not a layer dependency, so Foundation does not depend on Feature (designer decision, 2026-10-12, cross-review 12d) |
| Survivor Objectives | Depends on this | Hard | Hold pattern, view ray, range and line-of-sight checks |
| Downing, Rescue & Elimination | Depends on this | Hard | Hold (Rescue), Seized lock, roots, crawl gait, `walk_speed` |
| Survivor Defense | Depends on this | Hard | Holds (barricade, hide, search, break), root and slow, view ray (taser aim), doors |
| Borrowed Face | Depends on this | Hard | Survivor speeds and footstep set while disguised; interaction rejection while Transforming |
| Monster Abilities | Depends on this | Hard | True-form speeds, `player_radius_m` (dodge window), root and slow, doors |
| Pings & Callouts | Depends on this | Soft | View ray, input bindings |
| Facility Map (`design/levels/research-facility.md`) | Depends on this | Hard | `walk_speed` (traversal times), step and slope limits, capsule (doorways ≥ 0.8 m clear) |
| Scare Events | Soft | The camera flinch is the single sanctioned view rotation (Core Rule 7; Scare Events rules 13-14): a server-applied nudge, so the server's view direction follows it. Every other camera effect is a visual offset only |

## Visual/Audio Requirements

`art-director` was not consulted (Lean mode; `Core` system). No art bible exists yet; review when it does.

- **Gait animation set**: walk, sprint, crouch-walk, crawl, idle, interact loop, hold-start and hold-end poses. Borrowed Face copies the whole set for a disguise.
- **Footsteps**: a per-survivor footstep set, with one surface variant per floor type (concrete, metal grate, tile). A disguise uses its target's set (Core Rule 8).
- **Sprint breathing**: a breathing layer heard only by the sprinting player.
- **Fake holds** use the same interact loop as real ones (Survivor Objectives rule 25).
- **Camera**: head-bob no larger than 2 cm, with a reduced-motion option (Accessibility Options).

## Game Feel

- **Reference**: Dead by Daylight survivor movement: grounded and readable. **Anti-reference**: floaty arena-shooter strafing.
- **Latency targets**: move input to local motion within 1 frame (client-predicted); hold bar within 100 ms (Survivor Objectives, Game Feel); door toggle shown locally within 100 ms, then server-confirmed.
- **Acceleration**: full speed in `accel_time_s` = 0.05 s; deceleration the same. Snappy enough that a dodge started on reaction lands (Formulas, Dodge window).
- **Sprint**: FOV widens by 5° over 0.2 s; Accessibility Options provides an off switch **(proposed)**.
- **Corrections**: a server correction under 1 m is smoothed over 100 ms; larger ones snap (inference; the Network Authority ADR settles it).

## UI Requirements

- **Interaction prompt**: action name and bound key, shown only for a valid target (Core Rule 12).
- **Hold bar**: radial bar around the crosshair, predicted locally, cancelled by the server. A reset always shows its cause (hit, moved, released), per Survivor Objectives' failure texture.
- **Crosshair**: a minimal dot.
- These feed the HUD spec (`design/ux/hud.md`, via `/ux-design`).

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|-----------|----------------------------|--------|
| Crawl gait | `design/gdd/downing-and-rescue.md` | `crawl_speed_mult` | Data dependency |
| Rescue hold and root, Seized lock | `design/gdd/downing-and-rescue.md` | Rule 7, `rescue_range_m`; Seized state | Rule dependency |
| Objective holds and fakes | `design/gdd/survivor-objectives.md` | Rules 1–3, 25; `interact_range_m` | Rule dependency |
| Stun root and slow, shock lock, hiding, doors | `design/gdd/survivor-defense.md` | Rules 14, 18–27; `stun_root_s`, `stun_slow_mult`, `hide_noise_radius_m` | State trigger |
| Lunge timing, reach and miss slow | `design/gdd/monster-abilities.md` | Rules 5–10; `lunge_distance_m`, `lunge_hit_radius_m`, `lunge_windup_s`, `lunge_dash_s`, `miss_slow_multiplier`, `lunge_cue_radius_m`; Dodge window | Data dependency |
| Disguise speed parity, Transforming | `design/gdd/borrowed-face.md` | Rule 8; movement speeds and footstep set | Rule dependency |
| Install noise ordering | `design/gdd/survivor-objectives.md` | Rule 16, `install_noise_radius_m` | Data dependency |
| Traversal reference speed | `design/levels/research-facility.md` | Reference walk speed 4.0 m/s; AC 7 traversal budget | Data dependency |
| Round end and disconnects | `design/gdd/match-flow.md` | `RoundEnded`, `PlayerConnectionChanged` | State trigger |
| View ray and inputs | `design/gdd/pings-and-callouts.md` | Ping and callout wheel input | Data dependency |

## Acceptance Criteria

Drafted by `qa-lead`. Defaults are the **(proposed)** values in Formulas. **[U]** = automated unit test in `tests/unit/first-person-controller/`. **[I]** = automated integration test in `tests/integration/first-person-controller/`. **[M]** = manual or playtest, with a retained screenshot or recording in `production/qa/evidence/`.

**Body and gaits**

- [ ] **[U]** **GIVEN** any player (survivor, disguised shapeshifter, true-form shapeshifter, Downed survivor), **WHEN** its capsule is read, **THEN** radius = 0.30 m in every form; height = 1.8 m standing and 1.2 m crouched or Downed. (Rule 1)
- [ ] **[U]** **GIVEN** `walk_speed` 4.0 and full input on flat ground, **WHEN** each gait is held for 1 s of simulated ticks, **THEN** measured speeds are within ±0.05 m/s of: crawl 1.0, crouch 2.0, walk 4.0, survivor sprint 5.0, true-form sprint 5.75. (Rule 2, gait_speed)
- [ ] **[U]** **GIVEN** sprint held, **WHEN** move input is 30°, 45° (≤ 45° + 1e-4 counts as inside), 46° and 180° off facing, **THEN** speed is 5.0, 5.0, 4.0 and 4.0 m/s. **WHEN** the player is crouched, Downed, Transforming or Holding with sprint held, **THEN** the gait is not sprint (crouch 2.0, crawl 1.0, walk 4.0, walk 4.0). (Rules 3, 4, gait order)
- [ ] **[U]** **GIVEN** a diagonal key input of length 1.41, **WHEN** the player walks, **THEN** speed is 4.0 m/s, not 5.66. (move_input cap)
- [ ] **[I]** **GIVEN** a crouched player under a 1.5 m ceiling, **WHEN** crouch is released, **THEN** the capsule stays 1.2 m until the player reaches open floor, then stands within 1 tick. (Rule 4, edge case)
- [ ] **[I]** **GIVEN** test geometry with steps of 0.18, 0.35 and 0.40 m and ramps of 40° and 41°, **WHEN** a player walks into each, **THEN** it climbs the 0.18 and 0.35 m steps and the 40° ramp, and is blocked by the 0.40 m step and the 41° ramp. No jump action exists in the input map. (Rule 5)

**Modifiers**

- [ ] **[U]** **GIVEN** a true-form sprint (5.75), **WHEN** these modifiers are active, **THEN** effective speed = slow 0.5 → 2.875; slows 0.5 and 0.7 → 2.875 (not 2.01); root → 0; lock and slow → 0. When the last modifier is removed with sprint still held, the next tick → 5.75 with no re-press. (Rule 6, effective_speed)
- [ ] **[U]** **GIVEN** two owners each adding a modifier, **WHEN** owner A removes its modifier, **THEN** owner B's modifier stays active. (Rule 6)

**Look and view ray**

- [ ] **[U]** **GIVEN** any state except Hidden, **WHEN** the player looks, **THEN** yaw covers 360°, pitch clamps at ±85°, and no system call changes camera orientation, except the Scare Events flinch (a server-applied nudge of at most 0.3 s, never during a lunge wind-up) **(designer decision, 2026-10-12, cross-review 12d)**. Test: apply every root, slow, lock, Downed, Seized, Transforming and Holding state and assert the view direction follows input only; then play the downing camera impact and shake and the survivor-defense jitter and jolt and assert the view direction and aim ray are unchanged, and play a flinch and assert the server view direction moves with it for at most 0.3 s. (Rule 7)
- [ ] **[I]** **GIVEN** the server's yaw and pitch differ from a client-claimed value, **WHEN** a taser shot, a ping and an interaction Start are made, **THEN** all three resolve against the server's ray from the eye position. (Rule 10)

**Footsteps**

- [ ] **[U]** **GIVEN** a listener at 1.9, 2.1, 5.9, 6.1, 19.9 and 20.1 m, **WHEN** the source crouches, crawls, walks and sprints, **THEN** it is audible only at ≤ 2 m (crouch, crawl), ≤ 6 m (walk) and ≤ 20 m (sprint), with the same radii in every form. (Rule 8, footstep_radius)
- [ ] **[I]** **GIVEN** a stationary player and an active False Signal elsewhere, **WHEN** 5 s pass, **THEN** that player emits no footstep events. **GIVEN** a disguised shapeshifter walking, **THEN** remote clients play the target survivor's footstep set. (Rule 8)
- [ ] **[M]** **GIVEN** two testers in separate rooms 18 m apart through one wall, **WHEN** one sprints, then walks, **THEN** the listener reports hearing the sprint and not the walk in at least 9 of 10 trials. (footstep_radius example)

**Authority**

- [ ] **[I]** **GIVEN** a modified client sending a position, a speed above 5.75 m/s, a hold-progress value or a "done" message, **WHEN** the server processes it, **THEN** server position, speed and hold progress are unchanged and no completion event fires. (Rules 9, 15)
- [ ] **[I]** **GIVEN** a player moving and Holding, **WHEN** no intent packet arrives for 500 ms, **THEN** on the first tick after 500 ms (±1 tick) the server stops their movement and cancels the hold under the owner's cancel rule; at 450 ms neither has happened. (Edge case, intent timeout)
- [ ] **[I]** **GIVEN** a player found inside geometry, **WHEN** the next tick runs, **THEN** the player is at their last valid position. (Edge case)

**Hold-to-interact**

- [ ] **[U]** **GIVEN** standing eye height 1.6 m, capsule centre 0.9 m, `interact_ray_max_m` 3.0 and an interactable with `range_m` 2.0 whose point is 2.0 m from the capsule centre, **WHEN** the player aims at it, **THEN** a prompt shows and Start is accepted. **WHEN** the point is 2.05 m away, **THEN** no prompt shows and Start is rejected. A load-time check fails if `interact_ray_max_m` < max owner `range_m` + (`eye_height_m` − `capsule_height_m` / 2) for either posture. (Rules 12, 13, interact_ray_max)
- [ ] **[I]** **GIVEN** a Start, **WHEN** the actor is ineligible (shocked, hidden, Downed, wrong role), line of sight is blocked, or another actor holds the exclusive lock, **THEN** it is rejected and the client bar cancels. **GIVEN** two Starts on the same exclusive target in one tick, **THEN** the first to arrive is accepted and the second rejected. **GIVEN** Stop arriving before acceptance, **THEN** the hold is accepted and cancelled on that tick with progress 0. (Rule 13, edge cases)
- [ ] **[I]** **GIVEN** an accepted hold, **WHEN** the actor turns 180°, **THEN** it continues. **WHEN** the actor walks to `range_m` + 0.2, **THEN** it continues; **WHEN** the actor walks beyond `range_m` + 0.25, loses line of sight, releases input, receives an owner interrupt (`SurvivorHit`, `PlayerShocked`), starts another hold, uses an item, hides or disconnects, **THEN** it cancels on that tick with the owner's reset, keep or decay rule applied. While Holding, sprint input gives 4.0 m/s; with `roots_actor` it gives 0. While Holding, crouch input leaves posture and capsule height unchanged. (Rules 14, 16)
- [ ] **[U]** **GIVEN** an out-of-range interactable 1.0 m along the view ray and an in-range one 1.8 m along it, **WHEN** the player aims, **THEN** the prompt shows for the 1.8 m one. **GIVEN** a wall between the player and an in-range interactable, **THEN** no prompt shows. (Rule 12)
- [ ] **[U]** **GIVEN** data with `walk_speed` 4.5 and `sprint_mult` 1.25 (5.63 m/s), or `monster_sprint_mult` 1.0, **WHEN** the data loads, **THEN** the load-time check fails and names the joint cap. 4.0 × 1.35 = 5.4 passes (compared with a 1e-4 m/s epsilon). With `player_radius_m` 0.35 and v_s 5.4, the `catch_gap` assertion fails. (Gait speed joint cap)
- [ ] **[I]** **GIVEN** players moving and Holding, **WHEN** `RoundEnded` arrives, **THEN** on that tick all movement stops, every hold cancels, and further intent is ignored. **GIVEN** a player who becomes Eliminated, Escaped or disconnected, **THEN** their body is removed (Out) and they get the Match Flow spectator view. (States table, Dependencies)
- [ ] **[I]** **GIVEN** a hidden survivor, **WHEN** they look, **THEN** look is limited to the Survivor Defense peek view and restored to free look on exit. (Rule 7 exception)
- [ ] **[I]** **GIVEN** a hold with `duration_s` D, **WHEN** input is held continuously, **THEN** completion fires once, on the first server tick where elapsed ≥ D (±1 tick), and the owner emits its event. `duration_s` 0 completes on the Start tick. (Rule 15)
- [ ] **[I]** **Cross-system:** **GIVEN** the Survivor Objectives fuse install, Rescue and barricade interactables built from their owners' definitions, **WHEN** each is held to completion and, separately, cancelled midway, **THEN** each owner gets start, complete and cancel callbacks through this pattern with its own duration, range, `roots_actor` and cancel rule (Rescue roots the actor at 0 m/s). No owner runs its own hold timer.
- [ ] **[I]** **GIVEN** a shapeshifter faking an allowed hold on a free exclusive target, **WHEN** it holds longer than `duration_s`, **THEN** progress stays 0, the lock is never taken (a survivor can Start on the same target), and remote clients see the same animation and audio loop as a real hold. A disallowed target rejects the fake Start. (Rule 17)
- [ ] **[I]** **GIVEN** a door with a capsule overlapping its swing area, **WHEN** close is requested, **THEN** it is rejected; with the area clear, the door toggles on the same tick. During a lunge dash, close is rejected only if the shapeshifter's capsule is already in the swing area. (Rule 18, edge case)

**Cross-system movement**

- [ ] **[I]** **Borrowed Face parity:** **GIVEN** a survivor and a disguised shapeshifter copying them, **WHEN** both walk, sprint, crouch and strafe-sprint for 3 s each on identical inputs from mirrored starts, **THEN** their displacements match within 0.01 m every tick and their footstep sets and radii are identical.
- [ ] **[I]** **Pings & Callouts:** **GIVEN** a player moving at each gait, **WHEN** they ping, **THEN** velocity on the ping tick and the next tick equals velocity without the ping, and the ping uses the server's view ray.
- [ ] **[I]** **Monster Abilities dodge:** **GIVEN** a true-form lunge (wind-up 0.6 s, dash 0.3 s, 4 m, hit radius 1.2 m) aimed at a survivor 3 m ahead, with the server steering at maximum turn rate, **WHEN** the survivor strafes perpendicular at walk speed (4.0) from 0.40 s after the cue, **THEN** the lunge misses. **WHEN** the same strafe is crouched (2.0), **THEN** it hits. Run over 20 deterministic seeds; all must pass. (dodge_margin)
- [ ] **[I]** **Chase closing:** **GIVEN** a survivor sprinting at 5.0 m/s straight ahead and a true-form shapeshifter at 5.75 m/s 10 m behind, **WHEN** the shapeshifter lunges at the first moment the gap is ≤ `catch_gap` (1.0 m), **THEN** the lunge connects at 12 s ± 0.5 s. For a walking survivor (4.0), `catch_gap` is 1.9 m and the catch takes 4.6 s ± 0.3 s. (chase_close_time)
- [ ] **[M]** **Facility Map:** **GIVEN** the greybox facility and walk speed 4.0, **WHEN** a tester walks A1 to the C4 exit and A6 to C3 along the route-table paths, **THEN** each stopwatch time is ≤ 20 s (expected about 17 s and 18 s), and every doorway on both routes passes the 0.3 m capsule without snagging.
- [ ] **[I]** **Collision:** **GIVEN** two upright players walking into each other, **THEN** neither passes through. **GIVEN** a Downed survivor in a 0.9 m doorway, **WHEN** an upright player walks through, **THEN** they pass. **GIVEN** an Eliminated or Escaped player, **THEN** the body has no collision and accepts no movement.

**Performance (proposed)**

- [ ] **[I]** **GIVEN** 6 players moving (the `max_players` worst case, `lobby-role-assignment.md`), 2 Holding and 1 slowed, on the target server hardware, **WHEN** 600 server ticks are profiled, **THEN** the controller's server cost (movement, hold checks, ray casts) is ≤ 0.5 ms per tick at p95. Placeholder: no performance budget exists yet; technical-director pins it with the Network Authority ADR's tick rate.

**Feel**

- [ ] **[M]** **GIVEN** a valid Start under 150 ms simulated latency, **WHEN** the input is pressed, **THEN** the predicted hold bar appears ≤ 100 ms later, measured by frame count on a 240 fps capture. (Rule 13)

Not covered here: reconciliation smoothness (waits on the Network Authority ADR), attenuation and occlusion (audio mix), the hidden peek view (Survivor Defense rule 20), and real chases with corners (playtest only).

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Monster Abilities' dodge example (lines 138, 142; AC at line 298) uses a 4.5 m/s strafe and zero radius. Update it to the 4.0 m/s walk strafe and `player_radius_m` 0.3, and rerun its straight-line check | SneakKestrel16 | Before Monster Abilities' next review | Resolved 2026-10-12: updated; the straight-line model catches the strafe, so Monster Abilities adopts this GDD's steering pursuit model, which dodges (designer decision) |
| False Signal footsteps need a gait for their audible range. Proposed: walk (6 m) | SneakKestrel16 | Before Monster Abilities' next review | Resolved 2026-10-12: walk gait, `footstep_radius_walk_m` 6 m, fake path up to ~12 m over 3 s at 4.0 m/s (designer decision, cross-review 12d); `monster-abilities.md` rules 14-15 |
| Does `accel_time_s` up to 0.1 s keep the dodge? Rerun the pursuit simulation with the strafe starting at 0.40 + `accel_time_s` / 2 | SneakKestrel16 | Before Milestone 3 | — |
| Prediction and reconciliation method, and the controller's server performance budget | technical-director | Network Authority ADR | — |
| Match Flow dependency direction (the Controller's link is event-only) | SneakKestrel16 | Phase 5 of this authoring session | Resolved 2026-10-12: row added to `match-flow.md` Dependencies |
| Crouch as toggle or hold: offer both as a setting? | SneakKestrel16 | Accessibility Options GDD | — |
| Is a 1.0 m/s sprint gain over walk worth its noise? | SneakKestrel16 | Milestone 5 closed playtest | — |
| Solid capsules let a player (or a disguised shapeshifter) plug a doorway. Watch for griefing and body-blocking | SneakKestrel16 | Milestone 5 closed playtest | — |
