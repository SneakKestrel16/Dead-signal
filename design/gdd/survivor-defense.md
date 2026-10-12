# Survivor Defense

> **Status**: Approved
> **Author**: SneakKestrel16
> **Last Updated**: 2026-10-12 (cross-review W8, W11: no taser pings; timers run through disconnect; earlier: design review: rule 17 and Formulas name the disguise early end; break in any form; fourth cross-review B1: a change into a disguise ends immunity; W1: rule 11 post-lock wording; earlier cross-review B4 post-lock window)
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
   can never report a stun, a charge, or a completed barricade. A taser hit on
   a survivor always sends survivor clients `PlayerShocked`. While the
   monster is disguised, survivor clients receive one `PlayerShocked` event for a
   taser hit on it (stunned or immune) and on a survivor alike, and never
   receive `MonsterStunned` or any immunity data (designer decision,
   2026-10-11, cross-review re-review R2; same precedent as Pings rule 27).
   While the monster is Transforming, the event follows the body shown at that
   moment (Borrowed Face rule 10): out of a disguise it counts as disguised.
   `MonsterStunned` still reaches the server-side systems that consume it and
   the monster's own client. A stun on the true-form monster is sent to all
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
   `stun_range_m` = 5 m **(proposed)**. Targets are checked where the shooter
   saw them: positions rewound to the shooter's view tick, up to
   `max_rewind_ms` = 180 ms (ADR-0003, 2026-10-12; same path as the lunge).
   A small aim tolerance of `stun_aim_tolerance_deg` = 10° **(proposed)**
   covers aim imprecision only. The shot hits the **first** body in its path (monster or survivor)
   with line of sight **(proposed)**; a body in front shields anyone behind it.
   Seized and Downed survivors are not bodies for the shot: it passes through
   them and never shocks them, so a victim held in a takedown never shields the
   monster from a rescuer (designer decision, 2026-10-11).
   Each use consumes one cartridge whether or not it hits **(proposed)**. Reuse
   delay `stun_item_reuse_s` = 1 s **(proposed)**.
9. **Valid target:** the monster in any form (disguised or true form) **(proposed)**. If the
   shot's first hit is the monster, unstunned and not immune, the server applies
   MonsterStunned and emits `MonsterStunned`.
10. **Immune target:** if the monster is immune, the cartridge is still consumed
    and no stun state is applied. In true form every client shows a "resisted"
    spark **(proposed)**. While disguised, the hit plays the full shock
    presentation, with no new immunity (designer decision, 2026-10-11). It
    applies no root, slow or action lock: immunity starts when a lock ends and
    lasts `stun_immunity_s`, so an immune hit always falls inside the post-lock
    window (rule 14) and looks exactly like a hit on a survivor inside theirs
    (designer decision, 2026-10-12, cross-review B4; replaces the re-review R2
    lock). It cancels any hold in progress, but it does not cancel a
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
    objective hold and a barricade. It never downs or damages. Inside their
    post-lock window (rule 14; designer decision, 2026-10-12, cross-review B4)
    the hit still plays the stagger and grunt and still cancels any hold; only
    the root, slow and action lock are skipped, exactly as for an immune
    disguised monster (rule 10) (fourth cross-review W1). The firer's feedback is identical whether they hit a survivor or a
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
    a shocked survivor (rule 11) and a stunned disguised monster get exactly
    this lock for exactly this time, so "shock them, then ask them to ping or
    open a door" tells nobody anything. **No refresh** (designer decision,
    2026-10-11, second re-review B2): a hit on a player already under the lock
    does not extend or restart it; the charge is still spent and the hit plays
    its normal presentation. **Post-lock window** (designer decision,
    2026-10-12, cross-review B4): after any lock ends, the player, survivor or
    disguised monster alike, ignores new locks for `stun_immunity_s`. A hit in
    that window still spends the charge and plays its full presentation, but
    applies no root, slow or lock. For the monster the window is its immunity
    (rule 16), including the early end on a lunge wind-up. Together, no
    refresh and the post-lock window mean no number of shooters can chain the
    lock, in either form: back-to-back hits lock a player at most
    `stun_duration_s` out of every `stun_duration_s + stun_immunity_s`.
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
    punished again, but one that disengages cannot be locked. Immunity also
    ends when a transformation into a disguise completes (Borrowed Face rule
    9), so a disguise never carries immunity from a stun observers did not see
    on that body; a hit on it stuns and locks it exactly like a survivor
    (designer decision, 2026-10-12, cross-review B1 (2026-10-12b)).
17. **Anti-stun-lock (source risk):** limited charges, a short lock and the
    post-lock window (rule 14) together keep any player, survivor or monster in
    either form, locked at most 25% of any sustained chain (`lock_share`, see
    Formulas) while it disengages after each lock, and always give it
    `stun_immunity_s` to retreat (designer decision, 2026-10-12, cross-review B4). A monster that winds up a lunge inside
    immunity, or completes a transformation into a disguise, ends it early
    (rule 16) and can be stunned again: that share is its own choice.

#### Hiding spots

18. Hiding spots are authored objects (cabinets, lockers) placed sparingly by
    Facility Map. One survivor per spot **(proposed)**.
19. Entering or leaving takes `hide_transition_s` = 1.0 s **(proposed)** and
    makes a soft sound audible within `hide_noise_radius_m` = 8 m
    **(proposed)**. Only Healthy survivors can hide **(proposed)**.
20. While hidden the survivor cannot be seen, cannot be lunged (no valid line of
    sight), cannot interact with objectives, use items or carry out rescues, and
    has a restricted peek view. A held Scare Events flinch offset is reset to 0 by the Controller on entering
    the hide (a re-baseline, no visible rotation) and the peek view ignores it, so it
    cannot push the peek outside its cone (designer decision, 2026-10-12, cross-review 12f).
21. **Never permanently safe:** after `hide_quiet_s` = 20 s of continuous hiding,
    the spot emits a faint periodic breathing/creak cue every
    `hide_cue_interval_s` = 5 s **(proposed)**.
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
    survivor can remove a barricade by holding for `barricade_remove_s` = 1 s
    **(proposed)**.
27. **Breaking:** the monster holds Break on the door, in any form **(proposed)**. Survivors cannot break a barricade, so, like a search (rule 22), a break is a visible monster action even while disguised. The barricade breaks after
    `barricade_break_s` = 5 s of total break time **(proposed)**. Progress
    persists if the monster stops **(proposed)**. Each strike makes loud,
    directional noise heard across the zone **(proposed)**.
28. A broken barricade cannot be rebuilt on that door for
    `rebarricade_lockout_s` = 30 s **(proposed)**.

28a. **Interactable contract** (`first-person-controller.md` rule 11; every field below is **(proposed)**, cross-review 12d W2). `range_m` for all of them is `interact_range_m` = 2.0 m, owned by Survivor Objectives (no second name; tune it there), measured to the object's interaction point. Barricade, Remove barricade and Break on one door share that door's single exclusive lock, so only one of the three runs at a time (designer decision, 2026-10-12, cross-review 12e):

| Interactable | Who | `duration_s` | `roots_actor` | Progress on cancel | Exclusive lock | Shapeshifter may fake |
|---|---|---|---|---|---|---|
| Hide enter / exit | Healthy survivor | `hide_transition_s` 1.0 | Yes | Reset (stay out / stay in) | One occupant per spot | No (survivors only) |
| Barricade | Healthy survivor | `barricade_duration_s` 3 | No | Reset | One actor per door | No |
| Remove barricade | Survivor | `barricade_remove_s` 1 | No | Reset | One actor per door | No |
| Search | Monster, any form | `search_duration_s` 1.5 | Yes | Reset | One actor per spot | n/a (a real, visible monster action) |
| Break | Monster, any form | `barricade_break_s` 5 total | Yes | Keep (rule 27) | One actor per door | n/a (a real, visible monster action) |
| Door toggle (open / close) | Anyone | 0 (instant) | No | n/a | None | n/a (a real action in any form) |

The Controller's load-time check (`interact_ray_max_m` >= largest owner range + 0.7) therefore sees 2.0 m from this system, the same value Objectives owns.

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
| Immune | Stun ends | `stun_immunity_s` elapses, lunge wind-up starts, or a transformation into a disguise completes → Normal | Full kit; stun hits are "resisted" in true form, a full shock presentation with no root, slow or lock while disguised (rules 10 and 14) |

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
| Borrowed Face | Disguised form, Transforming flag (picks shock presentation and network event, rules 1 and 10) | `MonsterStunned` (cancels transform; stun-while-disguised presentation owned there); shock lock blocks starting a transformation |
| Pings & Callouts | — | Shock/stun lock blocks pings and callouts (Pings rule 23) |
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
| stun_immunity_s | float s | 4–10 | proposed 6 | Monster immunity after a stun, and every player's post-lock window (rule 14) |

Example: 2 / (2 + 6) = 0.25, so any player, survivor or monster in either form,
that disengages after each lock is locked at most 25% of the time (post-lock
window, rule 14; designer decision, 2026-10-12, cross-review B4). A monster that winds up a lunge inside
immunity, or completes a transformation into a disguise, ends it early (rule 16) and can exceed this share by its own choice. Expected range 0.1–0.4; above 0.4 the monster risks being
stun-locked.

### Team stun budget

```
team_stuns = survivor_count * stun_item_charges = 4 * 2 = 8 per round at 4 survivors (6 at 3, 10 at 5; the MVP config of 5 players has 4)
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
| A disguised monster (immune) or a survivor is hit again while already under the shock lock | Lock is not extended or restarted; charge spent; normal hit presentation | Rule 14 no-refresh: overlapping hits cannot extend the lock (second re-review B2) |
| A player is hit again just as their lock ends, or at any time in the next `stun_immunity_s` | No root, slow or lock; charge spent; full presentation. The monster's immunity is the same window | Rule 14 post-lock window: back-to-back hits cannot chain the lock, so `lock_share` and rule 17 hold in every form (designer decision, 2026-10-12, cross-review B4) |
| Stun fired while the monster is mid-transformation | Transformation cancelled; monster stunned | Source: transform cannot escape a stun |
| A survivor stands between the shooter and the monster | The survivor is shocked; the monster is not stunned | The shot hits the first body in its path |
| A defender fires past a Healthy survivor holding a rescue and clips them, or the monster sets that up | The rescuer is shocked: rooted, rescue cancelled (progress kept, decaying), taser locked | Accepted (second re-review W7): any rule that spares the rescuer or prefers the monster turns the shot into an identity test; playtest counts it |
| A survivor deliberately shocks a teammate to reset their objective hold | Hold cancelled and reset as for any hit; feedback identical to a monster hit | Accepted (second re-review W8): bounded by 2 charges per survivor; a shock on a suspected disguise gives no information (Survivor Objectives rule 26 is the better test); playtest counts it |
| A Seized or Downed survivor is between the shooter and the monster | The shot passes through them; the monster is stunned if valid | A held victim must never shield the monster (rule 8) |
| Monster Searches the spot a survivor is entering | Entry completes first, then the search ejects | Search resolves on completion |
| Survivor hides while being lunged at | Entry takes 1 s; the survivor is targetable until hidden | No instant escape |
| Downed survivor inside a hiding spot | Cannot happen; hiding requires Healthy. A hidden survivor cannot be hit | Downing owns state |
| Barricade completes while monster is in the doorway | Barricade fails; door must be closed and clear | No trapping the monster |
| Taser used with 0 cartridges | Input ignored, empty click | Server checks charges |
| Monster stunned during Blackout | Blackout continues | Placed effects are independent |
| Monster immune and a lunge wind-up starts | Immunity ends; next stun applies | Re-engaging is punishable |
| Client reports a stun hit | Ignored; server runs its own shot trace | Server authority |
| Monster disconnects while Stunned, Immune or locked | Stun and immunity timers keep running on the server; on reconnect within grace it returns in whatever state remains, in true form (Match Flow rule 20) | A disconnect never escapes a stun (designer decision, 2026-10-12, cross-review W11) |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| Monster Abilities | Bidirectional | Reads lunge and Blackout state; Monster Abilities consumes `MonsterStunned` and door blocking |
| Downing, Rescue & Elimination | Bidirectional | Reads Committing/Seized/Downed; Downing consumes `MonsterStunned` |
| Borrowed Face | Bidirectional | Borrowed Face reads `MonsterStunned` to cancel/block transformation; this reads disguised and Transforming state to pick the shock presentation, and `FormChanged` into a disguise to end immunity (rule 16) |
| Match Flow & Win Conditions | Bidirectional | Supplies stun stats for results; stun and immunity timers keep running through a monster disconnect (Match Flow rule 20) |
| First-Person Controller & Interaction | This depends on it | Hold-to-interact, movement modifiers |
| Facility Map | This depends on it | Hiding spot, door, backup switch placement |
| Survivor Objectives | Objectives depends on this | Hidden survivors cannot interact; a shock cancels a hold and the shock lock blocks interaction |
| Pings & Callouts | Pings depends on this | Hiding spots and barricadable doors are item-pingable (tasers are never world objects, so they are not; designer decision, 2026-10-12, cross-review W8); the shock lock blocks pings and callouts |
| Scare Events | Scare Events depends on this | Barricade break (`BarricadeBroken`) as a scare trigger; `PlayerShocked` ducks scare audio |
| Network Authority & Replication | This depends on it | Validation and replication |
| HUD & Results Screen | HUD depends on this | Charges, progress, stun results |
| Match Telemetry | Telemetry depends on this | Stun success rate etc. |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| stun_item_charges | 2 (proposed) | 1–3 | Monster attacks less; stun-lock risk | Stuns rare; downs frequent |
| stun_duration_s | 2.0 (proposed) | 1.0–3.0 | More escape time; frustrating for monster | Stun barely matters |
| stun_root_s | 1.0 (proposed) | 0.5–2.0 | Harder chase after stun | Monster recovers fast |
| stun_slow_mult | 0.5 (proposed) | 0.3–0.8 | Monster recovers faster after root | Longer effective escape window |
| stun_item_reuse_s | 1 (proposed) | 0.5–2 | Double shots harder | Panic double-fire wastes cartridges |
| stun_immunity_s | 6 (proposed) | 4–10 | Less stun-lock; double stuns wasted | Chain-stun risk |
| stun_range_m | 5 (proposed) | 3–7 | Easier stuns, safer rescues | Must be very close |
| stun_aim_tolerance_deg | 10 (proposed) | 0–20 | Forgiving aim under latency | Pure aim; more misses |
| stun_use_delay_s | 0.2 (proposed) | 0–0.5 | Harder to react to lunges | Instant reaction |
| hide_transition_s | 1.0 (proposed) | 0.5–2.0 | Hiding needs planning | Panic-hide too easy |
| hide_noise_radius_m | 8 (proposed) | 4–15 | Hiding easier to hear | Silent panic-hides |
| hide_quiet_s | 20 (proposed) | 10–40 | Longer safe hides | Hiding barely useful |
| hide_cue_interval_s | 5 (proposed) | 3–10 | Long hides harder to find | Long hides easy to find |
| search_duration_s | 1.5 (proposed) | 0.5–3.0 | Searches costly for monster | Spots near useless |
| barricade_duration_s | 3 (proposed) | 2–5 | Barricades need cover | Spammed barricades |
| barricade_remove_s | 1 (proposed) | 0.5–2 | Own barricades trap survivors longer | Barricades cheap to undo |
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
| Survivor shocked | Same stagger as a stunned disguised monster for observers; camera jitter and brief blue edge for the victim (reduced-motion/flash variant); the jitter is a visual offset only: view direction and aim unchanged (`first-person-controller.md` rule 7; designer decision, 2026-10-12, cross-review 12d) | Crackle and shocked grunt | MVP |
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
| Camera impact (monster) | 200 | Jolt on stun; visual offset only, view direction and aim unchanged (designer decision, 2026-10-12, cross-review 12d) | Yes |

### Weight and Responsiveness Profile

- **Weight**: the taser is light and instant; hide and barricade are deliberate holds.
- **Player control**: survivors keep full control unless shocked; a stunned monster or shocked survivor is rooted for `stun_root_s` (1 s).
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
- [ ] A shot whose path crosses a Seized or Downed survivor before the monster stuns the monster and does not shock the survivor.
- [ ] A second stun on the true-form monster within `stun_immunity_s` after a stun ends is "resisted" and does not stun. On a disguised monster it plays the full shock presentation and applies no root, slow, lock, new stun or immunity (rule 14 post-lock window).
- [ ] Each survivor starts with exactly 2 charges; a third fire attempt does nothing.
- [ ] A forged client "stun hit" or "barricade complete" message causes no state change.
- [ ] Searching an occupied hiding spot ejects the survivor without a down.
- [ ] A barricade breaks after exactly 5 s of total monster break time, with progress kept across interruptions.
- [ ] With 5 clients connected, all 5 agree on stun state (as visible to their role), charges remaining, hiding-spot occupancy (as visible to their role) and barricade state after each event.
- [ ] A survivor hit by a taser is rooted for `stun_root_s` and slowed until `stun_duration_s`; a recording of it is indistinguishable from a recording of a stunned disguised monster. A recording of a disguised monster hit while immune is indistinguishable from one of a survivor hit inside their post-lock window.
- [ ] For `stun_duration_s` after a taser hit, a shocked survivor and a stunned disguised monster each fail every attempt to open a door, interact, use an item, ping or call out; both succeed on the first attempt after it ends.
- [ ] Four taser hits 0.5 s apart on a disguised monster leave it locked for exactly `stun_duration_s` from the first hit; four charges are spent. The same holds for a shocked survivor.
- [ ] Eight taser hits 2 s apart (at 0, 2, 4, …, 14 s) on a disguised monster that is Normal at 0 s: it is locked from 0 to 2 s and from 8 to 10 s only; the hits at 2, 4, 6, 10, 12 and 14 s each play the full presentation and spend a charge but apply no root, slow or lock; eight charges are spent and the monster can start a transformation at 2 s and at 10 s if Borrowed Face rule 7 otherwise allows. The same eight hits on a survivor lock them for exactly the same intervals (designer decision, 2026-10-12, cross-review B4).
- [ ] A taser hit on a survivor holding a rescue, an objective hold or a barricade cancels that hold, including inside their post-lock window; an immune hit on a disguised monster mid-transformation does not cancel the transformation.
- [ ] A true-form monster stunned at 0 s, transforming into a disguise from 2 s to 4 s, and hit by a taser at 5 s is stunned and locked for `stun_duration_s`, exactly as a survivor not shocked in the last 8 s would be (designer decision, 2026-10-12, cross-review B1 (2026-10-12b)).
- [ ] While the monster is disguised, a packet capture on a survivor client shows one identical `PlayerShocked` event for a hit on a survivor, a stunned monster and an immune monster, and no `MonsterStunned` or immunity data.
- [ ] A stun on a true-form monster, then a lunge wind-up 2 s into immunity, ends immunity; a stun on that wind-up applies.
- [ ] A lunge whose path crosses a closed door stops at the door and resolves as a miss.
- [ ] After a barricade breaks, a survivor cannot start a barricade on that door for 30 s.
- [ ] A survivor hidden for 20 s makes the long-hide cue, then again every 5 s.
- [ ] Playtest: across at least 10 rounds, Match Telemetry records friendly shocks, split into shocks on a survivor holding a rescue and shocks on a survivor holding an objective. The designer reviews both counts before Milestone 2; if either shows rescues failing or holds griefed, revisit rule 8 (W7) or rule 11 (W8).
- [ ] Every value in Tuning Knobs is loaded from data, not hardcoded.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Exact defensive item types and starting charges (source open decision). | SneakKestrel16 | Before Milestone 3 | **Item type decided 2026-10-12: Taser.** Cartridges (2), range (5 m) and aim tolerance (10°) proposed; playtest |
| Should stun items be refillable or found in the map? | SneakKestrel16 | Before Milestone 5 | Proposed: no |
| Does stunning a disguised monster reveal it? | SneakKestrel16 | Before Milestone 3 | **Decided 2026-10-11: no.** Borrowed Face rule 10 |
| Should a taser shot that hits a real survivor shock them? | SneakKestrel16 | Before Milestone 3 | **Decided 2026-10-11:** yes, identical to a disguised stun as observers see it (rule 11) |
| Does the lunge cooldown start when a stun cancels it? | SneakKestrel16 | Before Milestone 3 | **Settled in Monster Abilities rule 12:** yes, the interrupted lunge counts as resolved and the cooldown starts (proposed) |
| Does the flashlight need a battery limit? | SneakKestrel16 | Before Milestone 4 | Proposed: no |
| Should the long-hide cue exist, or is Search enough? | SneakKestrel16 | Before Milestone 5 | |
