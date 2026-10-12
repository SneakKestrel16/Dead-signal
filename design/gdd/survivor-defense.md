# Survivor Defense

> **Status**: Approved
> **Author**: SneakKestrel16
> **Last Updated**: 2026-10-11 (design review: friendly shock mirrors a disguised stun)
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
the taser shot that saves a friend mid-grab, the locker you slip into as footsteps
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
   can never report a stun, a charge, or a completed barricade. While the
   monster is disguised, survivor clients receive one "shocked" event for a
   taser hit on it (stunned or immune) and on a survivor alike, and never
   receive `MonsterStunned` or any immunity data (designer decision,
   2026-10-11, cross-review re-review R2; same precedent as Pings rule 27).
   `MonsterStunned` still reaches the server-side systems that consume it and
   the monster's own client. A stun on the true-form monster may be sent to all
   clients as `MonsterStunned`.

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

#### Stun item (prototype: Taser) — item type decided 2026-10-12; values (proposed)

7. **Taser** (designer decision, 2026-10-12: a taser fits an indoor research
   facility better than a flare): a dart-firing stun gun, the single prototype
   stun item. Each charge is one cartridge. `stun_item_charges` = 2 cartridges
   per survivor **(proposed)**; no pickups or refills in the prototype
   **(proposed)**.
8. **Use:** press to fire one cartridge. After `stun_use_delay_s` = 0.2 s
   **(proposed)** the server traces the shot from the survivor's view: range
   `stun_range_m` = 5 m **(proposed)**, with a small aim tolerance of
   `stun_aim_tolerance_deg` = 10° **(proposed)** so latency does not punish a
   fair aim. The shot hits the **first** body in its path (monster or survivor)
   with line of sight **(proposed)**; a body in front shields anyone behind it.
   Each use consumes one cartridge whether or not it hits **(proposed)**. Reuse
   delay `stun_item_reuse_s` = 1 s **(proposed)**.
9. **Valid target:** the monster in any form (disguised or true form) **(proposed)**. If the
   shot's first hit is the monster, unstunned and not immune, the server applies
   MonsterStunned and emits `MonsterStunned`.
10. **Immune target:** if the monster is immune, the cartridge is still consumed
    and no stun state is applied. In true form every client shows a "resisted"
    spark **(proposed)**. While disguised, the hit plays the full shock
    presentation and applies the same root, slow and action lock as a stun
    (rule 14), with no new immunity (designer decision, 2026-10-11; lock added
    in re-review R2). It cancels any hold in progress, but it does not cancel a
    transformation already in progress. Immunity is therefore never visible on
    a borrowed body. If the hit lands while Transforming, the presentation
    follows the body shown at that moment: the full shock on the borrowed body,
    the "resisted" spark on the true form **(proposed)**.
11. **Survivor hit (friendly fire):** a real survivor hit by the shot is shocked
    exactly as a disguised monster is stunned, as every observer sees it
    (designer decision, 2026-10-11): the same stagger on their body, rooted for
    `stun_root_s`, then `stun_slow_mult` until `stun_duration_s` ends, with the
    shocked grunt and no whiteout. For `stun_duration_s` they get the same
    action lock as a stunned monster (rule 14): no doors, interact, items
    (including their own taser), pings or callouts (designer decision,
    2026-10-11, re-review R2). The shock counts as being hit: it cancels any
    hold in progress, including a rescue (progress kept, decaying), an
    objective hold and a barricade. It never downs or damages. The firer's feedback is identical whether they hit a survivor or a
    disguised monster, so a stun is not an identity test: Borrowed Face rule 10
    keeps the stunned monster disguised, and this rule makes the survivor look
    the same. The cost is that a misfire roots a teammate for a full second.
12. Survivors cannot kill or permanently disable the monster by any means.
13. Downed, Seized or hidden survivors cannot use the item **(proposed)**. Charges persist
    through a down and rescue **(proposed)** and are lost on elimination.

#### MonsterStunned state — all timings (proposed)

14. **Duration:** `stun_duration_s` = 2.0 s **(proposed)**: rooted for the first
    `stun_root_s` = 1.0 s, then moves at `stun_slow_mult` = 0.5 for the rest
    **(proposed)**. The whole time it cannot attack, use any ability, transform,
    interact (search, break barricades), use items, ping or call out, or use
    doors. **One lock for all** (designer decision, 2026-10-11, re-review R2):
    a shocked survivor (rule 11) and an immune disguised monster (rule 10) get
    exactly this lock for exactly this time, so "shock them, then ask them to
    ping or open a door" tells nobody anything.
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
    sustained stun chain (see Formulas) while it disengages after each stun, and
    always give it a window to retreat. A monster that winds up a lunge inside
    immunity ends it early (rule 16) and can be stunned again: that share is its
    own choice.

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
    which the survivor can dodge or stun. Survivors cannot search, so a search
    is a visible monster action even while disguised **(proposed)**.
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

29. Each survivor starts with 1 flashlight + 1 Taser with 2 cartridges
    **(proposed)**. The monster has no items. No other items exist in the
    prototype **(proposed)**.

### States and Transitions

**Monster stun state** (owned here):

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| Normal | Round start; immunity ends | Valid stun → Stunned | Full kit |
| Stunned | Valid Taser hit while Normal | `stun_duration_s` elapses → Immune | Rooted then slowed; no attacks, abilities, transform, interact |
| Immune | Stun ends | `stun_immunity_s` elapses or lunge wind-up starts → Normal | Full kit; stun hits are "resisted" in true form, a root, slow and action-lock shock while disguised (rule 10) |

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
| First-Person Controller & Interaction | Hold-to-interact pattern | Root and slow for friendly shock and stun |
| Scare Events | — | Door bursts on barricade break may trigger a scare (owned there) |
| HUD & Results Screen | — | Charges, stun feedback, barricade/hide progress, stun stats |
| Match Telemetry | — | Stun attempts, hits, resists, friendly shocks, searches, barricade breaks |

## Formulas

### Maximum stun-lock share

```
lock_share = stun_duration_s / (stun_duration_s + stun_immunity_s)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| stun_duration_s | float s | 1.0–3.0 | proposed 2.0 | Stun length |
| stun_immunity_s | float s | 4–10 | proposed 6 | Immunity after stun |

Example: 2 / (2 + 6) = 0.25, so a monster that disengages after each stun is
stunned at most 25% of the time. A monster that winds up a lunge inside
immunity ends it early (rule 16) and can exceed this share by its own choice. Expected range 0.1–0.4; above 0.4 the monster risks being
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
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| barricade_break_s | float s | 3–10 | proposed 5 | Total break time |
| monster_travel_to_alternate_route | float s | 0+ | Facility Map layout | Extra time for the monster to go around instead of breaking |

With `barricade_break_s` 5 s, a survivor spending 3 s to barricade buys at least
5 s, plus whatever alternate routes (Facility Map) cost the monster.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Two survivors stun on the same tick | First processed applies the stun; second is "resisted" in true form, or a full shock presentation while disguised (rule 10); both charges consumed | Immunity applies from the first stun |
| Stun fired while the monster is mid-transformation | Transformation cancelled; monster stunned | Source: transform cannot escape a stun |
| A survivor stands between the shooter and the monster | The survivor is shocked; the monster is not stunned | The shot hits the first body in its path |
| Monster Searches the spot a survivor is entering | Entry completes first, then the search ejects | Search resolves on completion |
| Survivor hides while being lunged at | Entry takes 1 s; the survivor is targetable until hidden | No instant escape |
| Downed survivor inside a hiding spot | Cannot happen; hiding requires Healthy. A hidden survivor cannot be hit | Downing owns state |
| Barricade completes while monster is in the doorway | Barricade fails; door must be closed and clear | No trapping the monster |
| Taser used with 0 cartridges | Input ignored, empty click | Server checks charges |
| Monster stunned during Blackout | Blackout continues | Placed effects are independent |
| Monster immune and a lunge wind-up starts | Immunity ends; next stun applies | Re-engaging is punishable |
| Client reports a stun hit | Ignored; server runs its own shot trace | Server authority |

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
| Scare Events | Scare Events depends on this | Barricade break (`BarricadeBroken`) as a scare trigger |
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
| stun_aim_tolerance_deg | 10 (proposed) | 0–20 | Forgiving aim under latency | Pure aim; more misses |
| stun_use_delay_s | 0.2 (proposed) | 0–0.5 | Harder to react to lunges | Instant reaction |
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
| Taser fire | Darts and wires, short blue arc at the target (reduced-flash variant required) | Pop of the cartridge, then electric crackle | MVP |
| Monster stunned | Stagger animation; while disguised it plays on the borrowed body (Borrowed Face rule 10) | Monster pain cry in true form; survivor grunt while disguised | MVP |
| Stun resisted (true form) | Small spark, no stagger | Dull fizz | MVP |
| Stun resisted (disguised) | Identical to Survivor shocked | Identical to Survivor shocked | MVP |
| Survivor shocked | Same stagger as a stunned disguised monster for observers; camera jitter and brief blue edge for the victim (reduced-motion/flash variant) | Crackle and shocked grunt | MVP |
| Hide enter/exit | Door motion | Soft creak | MVP |
| Long-hide cue | — | Breathing/creak every 5 s | Vertical Slice |
| Search | Monster opens spot | Door rattle | MVP |
| Barricade build/break | Planks/bar; door shakes per strike | Hammering; loud bangs | MVP |

## Game Feel

### Feel Reference

The Taser should feel like Dead by Daylight's flashlight save: a
high-skill, high-reward timing play. Anti-reference: a spammable weapon that
keeps the monster permanently stuck.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|------------------------|-------|
| Taser fire (local shot) | 50 | 3 | Local effect immediate; stun confirmed by server |
| Flashlight toggle | 50 | 3 | Predicted locally |
| Hide / barricade start | 100 | 6 | Progress predicted, server confirms |

### Animation Feel Targets

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|-----------|---------------|--------------|----------------|-----------|-------|
| Taser | 12 (0.2 s) | 3 | 30 | Snappy, punchy | |
| Monster stagger | 0 | 60 root | 60 slowed | Clear, short | Totals `stun_duration_s` |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Arc flash | 150 | Brief arc at the target | Yes (reduced flash) |
| Camera impact (monster) | 200 | Jolt on stun | Yes |

### Weight and Responsiveness Profile

- **Weight**: the taser is light and instant; hide and barricade are deliberate holds.
- **Player control**: survivors keep full control; the monster loses it for 1 s.
- **Failure texture**: a missed or resisted stun must clearly show why (missed, blocked by a body, out of range, immune).

### Feel Acceptance Criteria

- [ ] Across ≥10 playtest rounds, at most 1 monster player answers "yes" to the post-round question "Did you feel stun-locked?".
- [ ] In a playtest of ≥20 shots on the true-form monster, firers correctly name hit, miss, blocked or resisted for ≥90% of them.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|-----------------|-----------|
| Taser cartridges | Survivor HUD item slot | On change | Survivors |
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

- [ ] A Taser shot whose first hit is the monster within 5 m applies a 2.0 s stun and emits `MonsterStunned`; out of range, missed, or blocked by a survivor, the monster is not stunned and one cartridge is consumed.
- [ ] A stun during lunge wind-up produces no `SurvivorHit`; a stun during a takedown commit frees the victim.
- [ ] A second stun on the true-form monster within `stun_immunity_s` after a stun ends is "resisted" and does not stun. On a disguised monster it plays the full shock presentation and applies the rule 14 lock, but no new stun or immunity.
- [ ] Each survivor starts with exactly 2 charges; a third fire attempt does nothing.
- [ ] A forged client "stun hit" or "barricade complete" message causes no state change.
- [ ] Searching an occupied hiding spot ejects the survivor without a down.
- [ ] A barricade breaks after exactly 5 s of total monster break time, with progress kept across interruptions.
- [ ] With 5 clients connected, all 5 agree on stun state (as visible to their role), charges remaining, hiding-spot occupancy (as visible to their role) and barricade state after each event.
- [ ] A survivor hit by a taser is rooted for `stun_root_s` and slowed until `stun_duration_s`; a recording of it is indistinguishable from a recording of a stunned disguised monster, and from a disguised monster hit while immune.
- [ ] For `stun_duration_s` after a taser hit, a shocked survivor, a stunned disguised monster and an immune disguised monster each fail every attempt to open a door, interact, use an item, ping or call out; all three succeed on the first attempt after it ends.
- [ ] A taser hit on a survivor holding a rescue, an objective hold or a barricade cancels that hold; an immune hit on a disguised monster mid-transformation does not cancel the transformation.
- [ ] While the monster is disguised, a packet capture on a survivor client shows one identical "shocked" event for a hit on a survivor, a stunned monster and an immune monster, and no `MonsterStunned` or immunity data.
- [ ] A stun on a true-form monster, then a lunge wind-up 2 s into immunity, ends immunity; a stun on that wind-up applies.
- [ ] A lunge whose path crosses a closed door stops at the door and resolves as a miss.
- [ ] After a barricade breaks, a survivor cannot start a barricade on that door for 30 s.
- [ ] A survivor hidden for 20 s makes the long-hide cue, then again every 5 s.
- [ ] Every value in Tuning Knobs is loaded from data, not hardcoded.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Exact defensive item types and starting charges (source open decision). | SneakKestrel16 | Before Milestone 3 | **Item type decided 2026-10-12: Taser.** Cartridges (2), range (5 m) and aim tolerance (10°) proposed; playtest |
| Should stun items be refillable or found in the map? | SneakKestrel16 | Before Milestone 5 | Proposed: no |
| Does stunning a disguised monster reveal it? | SneakKestrel16 | Before Milestone 3 | **Decided 2026-10-11: no.** Borrowed Face rule 10 |
| Should a taser shot that hits a real survivor shock them? | SneakKestrel16 | Before Milestone 3 | **Decided 2026-10-11:** yes, identical to a disguised stun as observers see it (rule 11) |
| Does the lunge cooldown start when a stun cancels it? | SneakKestrel16 | Before Milestone 3 | Owned by Monster Abilities |
| Does the flashlight need a battery limit? | SneakKestrel16 | Before Milestone 4 | Proposed: no |
| Should the long-hide cue exist, or is Search enough? | SneakKestrel16 | Before Milestone 5 | |
