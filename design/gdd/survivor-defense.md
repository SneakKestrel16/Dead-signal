# Survivor Defense

> **Status**: Draft
> **Author**: SneakKestrel16
> **Last Updated**: 2026-10-12
> **Last Verified**: 2026-10-11
> **Implements Pillar**: Counterplay; Fair Fear

## Summary

Survivor Defense covers the survivors' non-lethal answers to the shapeshifter:
a flashlight for darkness and Blackout, one limited-use stun item that
interrupts attacks and staggers the monster briefly, hiding spots that buy time
but are never safe, and door barricades the monster eventually breaks. It also
owns the monster's Stunned state, including the immunity window that prevents
stun-locking. Survivors can never kill the monster.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Monster Abilities, First-Person Controller & Interaction, Downing, Rescue & Elimination, Borrowed Face, Facility Map`

## Overview

Each survivor starts with a flashlight and one limited-use defensive item. The
flashlight lets them see through Blackout and dark rooms but does nothing to the
monster. The stun item, if aimed well, interrupts a lunge or a takedown in
progress and staggers the monster for a moment; then the monster is briefly
immune so it cannot be chain-stunned. Hiding spots (cabinets, lockers) let a
survivor vanish from sight, but the monster can search them. Some doors can be
barricaded; the monster can break through, which takes time and makes noise.
All of these trade a resource (charges, time, position) for safety, and none of
them makes a survivor permanently safe. The server validates every use.

## Player Fantasy

**Survivor:** "I'm not helpless." You can't fight it, but you can buy seconds:
the flare that saves a friend mid-grab, the locker you slip into as footsteps
pass, the barricade that holds just long enough.

**Shapeshifter:** survivors' tools are real but finite. You bait out stuns,
check lockers, and listen for a barricade going up. When they've spent their
tools, they're yours.

## Detailed Design

### Core Rules

1. **Server authority.** The server holds item charges, the monster's stun and
   immunity timers, hiding-spot occupancy and barricade durability. Clients send
   intent only (use item with aim direction, enter/exit hide, start/stop
   barricade, start/stop break). The server validates range, line of sight,
   charges, timers and interaction durations, then broadcasts results. A client
   can never report a stun, a charge, or a completed barricade.

#### Flashlight

2. Every survivor carries one flashlight. Toggle on/off; no battery or charge
   limit **(proposed)**.
3. The flashlight lights a cone in front of the survivor that all clients see,
   so using it reveals the holder's position **(proposed)**.
4. **Against Blackout:** Blackout (owned by Monster Abilities) disables room
   lights for `blackout_duration_s`; flashlights keep working inside it. The
   flashlight does not end Blackout early; backup switches (Facility Map) and
   leaving the area are the other answers.
5. The flashlight has no effect on the monster: no damage, stun, slow or
   disguise reveal **(proposed)**.
6. A disguised monster carries a flashlight cosmetically like the survivor it
   copies **(proposed; Borrowed Face owns appearance)**.

#### Stun item (prototype: Arc Flare) — all values (proposed)

7. **Arc Flare** **(proposed)**: a handheld flash-discharge device, the single
   prototype stun item. `stun_item_charges` = 2 per survivor **(proposed)**;
   no pickups or refills in the prototype **(proposed)**.
8. **Use:** press to fire. After `stun_use_delay_s` = 0.2 s **(proposed)** the
   server checks for the monster within a cone of `stun_range_m` = 5 m and
   `stun_cone_deg` = 40° **(proposed)** with line of sight. Each use consumes one
   charge whether or not it hits **(proposed)**. Reuse delay
   `stun_item_reuse_s` = 1 s **(proposed)**.
9. **Valid target:** the monster in any form (disguised or true form) **(proposed)**. If the
   monster is in the cone, unstunned and not immune, the server applies
   MonsterStunned and emits `MonsterStunned`.
10. **Immune target:** if the monster is immune, the charge is still consumed
    and every client shows a "resisted" spark **(proposed)**.
11. **Survivor in the cone (friendly fire):** a real survivor caught in the cone
    is dazzled for `dazzle_s` = 1 s (vision whiteout, 30% slow, no root)
    **(proposed)**. It never downs, damages or interrupts a rescue. The firer's
    local feedback is identical whether they hit a survivor or a disguised
    monster **(proposed)**, so a stun is not a free identity test; what the
    monster's stagger looks like while disguised is owned by Borrowed Face.
12. Survivors cannot kill or permanently disable the monster by any means.
13. Downed, Seized or hidden survivors cannot use the item **(proposed)**. Charges persist
    through a down and rescue **(proposed)** and are lost on elimination.

#### MonsterStunned state — all timings (proposed)

14. **Duration:** `stun_duration_s` = 2.0 s **(proposed)**: rooted for the first
    `stun_root_s` = 1.0 s, then moves at `stun_slow_mult` = 0.5 for the rest
    **(proposed)**. The whole time it cannot attack, use any ability, transform,
    interact (search, break barricades) or use doors.
15. **Cancels on entry:**
    - Predatory Lunge in wind-up or in flight: cancelled; no `SurvivorHit` is
      produced. Whether the lunge cooldown starts is owned by Monster Abilities
      (proposed there: counts as resolved).
    - Takedown commit: cancelled and the victim freed (owned by Downing, Rescue
      & Elimination).
    - Transformation in progress: cancelled (Borrowed Face owns the cooldown
      outcome). The source rule holds: transformation cannot escape a stun.
    - Barricade breaking and hiding-spot search: interrupted; barricade damage
      already dealt is kept **(proposed)**.
    - **Does not cancel** a Blackout or False Signal already active.
16. **Immunity:** when the stun ends, the monster is immune to further stuns for
    `stun_immunity_s` = 6 s **(proposed)**. Immunity ends early if the monster
    starts a lunge wind-up **(proposed)**, so a monster that re-engages can be
    punished again, but one that disengages cannot be locked.
17. **Anti-stun-lock (source risk):** limited charges, a short stun and the
    immunity window together keep the monster stunned at most 25% of any
    sustained stun chain (see Formulas), and always give it a window to retreat.

#### Hiding spots

18. Hiding spots are authored objects (cabinets, lockers) placed sparingly by
    Facility Map. One survivor per spot **(proposed)**.
19. Entering or leaving takes `hide_transition_s` = 1.0 s **(proposed)** and
    makes a soft sound audible within `hide_noise_radius_m` = 8 m
    **(proposed)**. Only Healthy survivors can hide **(proposed)**.
20. While hidden the survivor cannot be seen, cannot be lunged (no valid line of
    sight), cannot interact with objectives, use items or carry out rescues, and
    has a restricted peek view.
21. **Never permanently safe:** after `hide_quiet_s` = 20 s of continuous hiding,
    the spot emits a faint periodic breathing/creak cue every 5 s **(proposed)**.
22. **Monster investigation:** the monster may Search any hiding spot by holding
    for `search_duration_s` = 1.5 s **(proposed)** in any form. If empty, nothing
    happens. If occupied, the survivor is ejected in front of the spot; the
    monster gets no automatic hit. It must still lunge with its normal wind-up,
    which the survivor can dodge or stun. A disguised monster's search may look
    like a survivor checking a cabinet **(proposed)**.
23. Hidden survivors keep their charges and flashlight; carried objective items
    are handled by Survivor Objectives.

#### Doors and barricades

24. Any door can be closed by anyone. A closed door blocks a Predatory Lunge's
    path (the lunge stops at the door and resolves as a miss) **(proposed)**,
    matching the source counter "slam a door".
25. Doors authored as barricadable (Facility Map) can be barricaded by a Healthy
    survivor holding `barricade_duration_s` = 3 s **(proposed)** from either
    side. No consumable is needed **(proposed)**.
26. A barricaded door cannot be opened by anyone until broken or removed. A
    survivor can remove a barricade by holding for 1 s **(proposed)**.
27. **Breaking:** the monster holds Break on the door. The barricade breaks after
    `barricade_break_s` = 5 s of total break time **(proposed)**. Progress
    persists if the monster stops **(proposed)**. Each strike makes loud,
    directional noise heard across the zone **(proposed)**.
28. A broken barricade cannot be rebuilt on that door for
    `rebarricade_lockout_s` = 30 s **(proposed)**.

#### Starting kit

29. Each survivor starts with 1 flashlight + 1 Arc Flare with 2 charges
    **(proposed)**. The monster has no items. No other items exist in the
    prototype **(proposed)**.

### States and Transitions

**Monster stun state** (owned here):

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| Normal | Round start; immunity ends | Valid stun → Stunned | Full kit |
| Stunned | Valid Arc Flare hit while Normal | `stun_duration_s` elapses → Immune | Rooted then slowed; no attacks, abilities, transform, interact |
| Immune | Stun ends | `stun_immunity_s` elapses or lunge wind-up starts → Normal | Full kit; stun hits are "resisted" |

**Hiding spot:** Empty → Entering (1 s) → Occupied → Exiting (1 s) → Empty;
Occupied → (Search completes) → Empty with survivor ejected.

**Barricadable door:** Open/Closed → Barricading (3 s) → Barricaded → (Break
total 5 s) → Broken (lockout 30 s) → Closed; Barricaded → (survivor removes) →
Closed.

### Interactions with Other Systems

| System | In | Out |
|--------|----|-----|
| Monster Abilities | Lunge wind-up/flight state; Blackout zone | `MonsterStunned` (cancels lunge); doors block lunge path; hidden survivors not targetable |
| Downing, Rescue & Elimination | Committing, Seized, Downed states | `MonsterStunned` cancels commit; Downed/Seized cannot use items or hide |
| Borrowed Face | — | `MonsterStunned` (cancels transform; stun-while-disguised presentation owned there) |
| Facility Map | Hiding spot and barricadable door placement, backup switches | — |
| Survivor Objectives | — | Hidden/item-using survivors cannot interact with objectives |
| First-Person Controller & Interaction | Hold-to-interact pattern | Movement lock/slow for dazzle and stun |
| Scare Events | — | Door bursts on barricade break may trigger a scare (owned there) |
| HUD & Results Screen | — | Charges, stun feedback, barricade/hide progress, stun stats |
| Match Telemetry | — | Stun attempts, hits, resists, friendly dazzles, searches, barricade breaks |

## Formulas

### Maximum stun-lock share

```
lock_share = stun_duration_s / (stun_duration_s + stun_immunity_s)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| stun_duration_s | float s | 1.0–3.0 | proposed 2.0 | Stun length |
| stun_immunity_s | float s | 4–10 | proposed 6 | Immunity after stun |

Example: 2 / (2 + 6) = 0.25, so a monster that keeps re-engaging is stunned at
most 25% of the time. Expected range 0.1–0.4; above 0.4 the monster risks being
stun-locked.

### Team stun budget

```
team_stuns = survivors * stun_item_charges = 4 * 2 = 8 per round
max_stunned_time = team_stuns * stun_duration_s = 16 s of a 540 s round (~3%)
```

### Barricade delay

```
delay_bought = barricade_break_s + monster_travel_to_alternate_route
```
With `barricade_break_s` 5 s, a survivor spending 3 s to barricade buys at least
5 s, plus whatever alternate routes (Facility Map) cost the monster.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Two survivors stun on the same tick | First processed applies the stun; second is "resisted"; both charges consumed | Immunity applies from the first stun |
| Stun fired while the monster is mid-transformation | Transformation cancelled; monster stunned | Source: transform cannot escape a stun |
| Stun hits monster and a survivor in the same cone | Monster stunned, survivor dazzled | Each target resolved independently |
| Monster Searches the spot a survivor is entering | Entry completes first, then the search ejects | Search resolves on completion |
| Survivor hides while being lunged at | Entry takes 1 s; the survivor is targetable until hidden | No instant escape |
| Downed survivor inside a hiding spot | Cannot happen; hiding requires Healthy. A hidden survivor cannot be hit | Downing owns state |
| Barricade completes while monster is in the doorway | Barricade fails; door must be closed and clear | No trapping the monster |
| Arc Flare used at 0 charges | Input ignored, empty click | Server checks charges |
| Monster stunned during Blackout | Blackout continues | Placed effects are independent |
| Monster immune and a lunge wind-up starts | Immunity ends; next stun applies | Re-engaging is punishable |
| Client reports a stun hit | Ignored; server runs its own cone check | Server authority |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| Monster Abilities | Bidirectional | Reads lunge and Blackout state; Monster Abilities consumes `MonsterStunned` and door blocking |
| Downing, Rescue & Elimination | Bidirectional | Reads Committing/Seized/Downed; Downing consumes `MonsterStunned` |
| Borrowed Face | Borrowed Face depends on this | Reads `MonsterStunned` to cancel/block transformation |
| First-Person Controller & Interaction | This depends on it | Hold-to-interact, movement modifiers |
| Facility Map | This depends on it | Hiding spot, door, backup switch placement |
| Survivor Objectives | Objectives depends on this | Hidden survivors cannot interact |
| Pings & Callouts | Pings depends on this | Hiding spots, barricadable doors and stun items are item-pingable |
| Scare Events | Scare Events depends on this | Barricade break as a scare trigger |
| Network Authority & Replication | This depends on it | Validation and replication |
| HUD & Results Screen | HUD depends on this | Charges, progress, stun results |
| Match Telemetry | Telemetry depends on this | Stun success rate etc. |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| stun_item_charges | 2 (proposed) | 1–3 | Monster attacks less; stun-lock risk | Stuns rare; downs frequent |
| stun_duration_s | 2.0 (proposed) | 1.0–3.0 | More escape time; frustrating for monster | Stun barely matters |
| stun_root_s | 1.0 (proposed) | 0.5–2.0 | Harder chase after stun | Monster recovers fast |
| stun_immunity_s | 6 (proposed) | 4–10 | Less stun-lock; double stuns wasted | Chain-stun risk |
| stun_range_m | 5 (proposed) | 3–7 | Easier stuns, safer rescues | Must be very close |
| stun_cone_deg | 40 (proposed) | 20–60 | Forgiving aim; more friendly fire | Precise aim needed |
| stun_use_delay_s | 0.2 (proposed) | 0–0.5 | Harder to react to lunges | Instant reaction |
| dazzle_s | 1.0 (proposed) | 0.5–1.5 | Misfires punished more | Misfires near free |
| hide_transition_s | 1.0 (proposed) | 0.5–2.0 | Hiding needs planning | Panic-hide too easy |
| hide_quiet_s | 20 (proposed) | 10–40 | Longer safe hides | Hiding barely useful |
| search_duration_s | 1.5 (proposed) | 0.5–3.0 | Searches costly for monster | Spots near useless |
| barricade_duration_s | 3 (proposed) | 2–5 | Barricades need cover | Spammed barricades |
| barricade_break_s | 5 (proposed) | 3–10 | Doors hold longer | Barricades pointless |
| rebarricade_lockout_s | 30 (proposed) | 15–60 | Door chokes less abusable | Repeated stalling |

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Flashlight on/off | Visible beam to all | Click | MVP |
| Arc Flare fire | Bright burst (reduced-flash variant required) | Electric crack | MVP |
| Monster stunned | Stagger animation; true-form treatment owned by Borrowed Face | Monster pain cry | MVP |
| Stun resisted | Small spark, no stagger | Dull fizz | MVP |
| Survivor dazzled | Whiteout fade (reduced-flash variant) | Ringing | MVP |
| Hide enter/exit | Door motion | Soft creak | MVP |
| Long-hide cue | — | Breathing/creak every 5 s | Vertical Slice |
| Search | Monster opens spot | Door rattle | MVP |
| Barricade build/break | Planks/bar; door shakes per strike | Hammering; loud bangs | MVP |

## Game Feel

### Feel Reference

The Arc Flare should feel like Dead by Daylight's flashlight save: a
high-skill, high-reward timing play. Anti-reference: a spammable weapon that
keeps the monster permanently stuck.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|------------------------|-------|
| Arc Flare fire (local burst) | 50 | 3 | Local effect immediate; stun confirmed by server |
| Flashlight toggle | 50 | 3 | Predicted locally |
| Hide / barricade start | 100 | 6 | Progress predicted, server confirms |

### Animation Feel Targets

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|-----------|---------------|--------------|----------------|-----------|-------|
| Arc Flare | 12 (0.2 s) | 3 | 30 | Snappy, punchy | |
| Monster stagger | 0 | 60 root | 60 slowed | Clear, short | Totals `stun_duration_s` |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Flash bloom | 150 | Burst at flare origin | Yes (reduced flash) |
| Camera impact (monster) | 200 | Jolt on stun | Yes |

### Weight and Responsiveness Profile

- **Weight**: flare is light and instant; hide and barricade are deliberate holds.
- **Player control**: survivors keep full control; the monster loses it for 1 s.
- **Failure texture**: a missed or resisted stun must clearly show why (out of cone, immune).

### Feel Acceptance Criteria

- [ ] Monster players do not describe being stun-locked in post-round surveys.
- [ ] Survivors can tell from feedback whether a stun hit, missed or was resisted.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|-----------------|-----------|
| Arc Flare charges | Survivor HUD item slot | On change | Survivors |
| Stun/immunity remaining | Monster HUD | Per tick | Monster while stunned/immune |
| Hide/barricade/break progress | Centre ring | Per tick | During hold |
| Stun hits/resists per player | Results screen | End of round | All |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|-----------|----------------------------|--------|
| Blackout counterplay | `design/gdd/monster-abilities.md` | Blackout, `blackout_duration_s` | Rule dependency |
| Lunge cancellation and door blocking | `design/gdd/monster-abilities.md` | Predatory Lunge wind-up, `lunge_cooldown_s` | State trigger |
| Stun cancels commit | `design/gdd/downing-and-rescue.md` | Takedown commit, Seized/Downed | State trigger |
| Transform cannot escape stun | `design/gdd/borrowed-face.md` | Transformation, `form_change_cooldown_s`, disguise presentation | Rule dependency |
| Placement of spots and doors | `design/levels/research-facility.md` | Hiding spots, barricadable doors, backup switches | Data dependency |
| No objective use while hidden | `design/gdd/survivor-objectives.md` | Objective interactions | Rule dependency |
| Pingable defenses | `design/gdd/pings-and-callouts.md` | Item pings | Data dependency |
| Barricade burst scare | `design/gdd/scare-events.md` | Door burst scare, reduced-flash hooks | State trigger |

## Acceptance Criteria

- [ ] An Arc Flare fired at the monster in range, in cone and with line of sight applies a 2.0 s stun and emits `MonsterStunned`; out of range or blocked, nothing happens and one charge is consumed.
- [ ] A stun during lunge wind-up produces no `SurvivorHit`; a stun during a takedown commit frees the victim.
- [ ] A second stun within `stun_immunity_s` after a stun ends is "resisted" and does not stun.
- [ ] Each survivor starts with exactly 2 charges; a third fire attempt does nothing.
- [ ] A forged client "stun hit" or "barricade complete" message causes no state change.
- [ ] Searching an occupied hiding spot ejects the survivor without a down.
- [ ] A barricade breaks after exactly 5 s of total monster break time, with progress kept across interruptions.
- [ ] With 5 clients connected, all 5 agree on stun state, charges remaining, hiding-spot occupancy (as visible to their role) and barricade state after each event.
- [ ] Every value in Tuning Knobs is loaded from data, not hardcoded.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Exact defensive item types and starting charges (source open decision). Is the single Arc Flare with 2 charges right, or 1 charge, or several item types? | SneakKestrel16 | Before Milestone 3 | Proposed: Arc Flare, 2 charges |
| Should stun items be refillable or found in the map? | SneakKestrel16 | Before Milestone 5 | Proposed: no |
| Does stunning a disguised monster reveal it? | SneakKestrel16 | Before Milestone 3 | Owned by Borrowed Face |
| Should friendly fire dazzle real survivors? | SneakKestrel16 | Before Milestone 3 | Proposed: 1 s dazzle |
| Does the lunge cooldown start when a stun cancels it? | SneakKestrel16 | Before Milestone 3 | Owned by Monster Abilities |
| Does the flashlight need a battery limit? | SneakKestrel16 | Before Milestone 4 | Proposed: no |
| Should the long-hide cue exist, or is Search enough? | SneakKestrel16 | Before Milestone 5 | |
