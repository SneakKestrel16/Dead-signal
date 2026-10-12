## Cross-GDD Review Report (since last review)

Date: 2026-10-12 (eighth cross-review, after `gdd-cross-review-2026-10-12e.md`)
Mode: since-last-review (consistency + design theory + scenarios), headless
GDDs Reviewed: 10 of 10 present (changed since the 12e report: borrowed-face, first-person-controller, lobby-role-assignment, monster-abilities, scare-events, survivor-defense, survivor-objectives; downing-and-rescue, match-flow and pings-and-callouts are unchanged and were checked by targeted search only)
Not read: none. (`design/levels/research-facility.md` came in through the DEPS line and was searched for the backup switch; `systems-index.md` and `design/registry/entities.yaml` were also checked.)
Systems Covered: all ten system GDDs plus the Facility Map, the index and the registry.

Pillars: Human Deception, Fair Fear, Counterplay, Readable Objectives, Small Shippable Scope. Anti-pillars: no AI monsters, not a combat game, not procedural, not voice-dependent, no progression or ranked.

Run notes:
- Headless. Phases 2 and 3 were done inline, not by spawned sub-agents: the scope is one fix commit (c66c966, 9 files) and the work was a diff-driven check of what it changed. No phase was skipped.
- Method: `review-scope.sh` gave the changed set; the full c66c966 diff was read, each 12e item was checked against the current text, then each new rule was traced to every other place that states the same fact (flinch model, ranges, footsteps, dependency graph, registry).
- Standard tier (`modes.workflow: standard`): no missing required section in any changed GDD. Advisory carried over: the Controller has no Player Fantasy or Tuning Knobs section; the Lobby has no Player Fantasy section.
- Per instruction, no GDD, the index, the registry or `active.md` was edited, and nothing was committed.

---

## Status of the previous report's items

| Item | Status |
|---|---|
| 12e W1 flinch vs toggle and client yaw | Resolved in text. Controller rules 7 and 9, the camera AC, Scare Events rules 13 and 27, its Dependencies, Impact Moments and a new AC, and the index (`ViewNudge` event, per-player toggle state row) all state the same model: server-known flag, server-held offset added to client yaw/pitch, ramp in within 0.3 s, stays, none when off. Follow-on gaps: W1 and W2 below |
| 12e W2 flinch interface in index, dependency rows | Resolved for the index event row, state row, Controller index row 3, and both Dependencies rows (Controller row now has four cells; the two rows agree on direction and "soft"). The change creates a dependency loop: W1 below |
| 12e W3 Borrowed Face reveal flinch | Resolved. The row now says it is the Scare Events reveal flinch, not a second rotation, and inherits rule 14 and the toggle |
| 12e W4 contract gaps | Resolved except one leftover. 28a uses `interact_range_m` with no second name; one lock per door for the three door actions; Controller `max_owner_range_m` names Objectives, Survivor Defense, Downing and the switch; the switch safe range is 1.5-2.3; `backup_switch_hold_s`, `backup_switch_range_m` and the footstep duration are registered. Leftover: W3 below (Objectives' own safe range) |
| 12e W5 False Signal footstep path | Resolved. Path = `walk_speed` x `false_signal_footstep_duration_s`, stops at the first wall, validated along the path; knobs, Dependencies row, edge case and AC all agree. Small leftovers: I1, I2 |
| 12e D2 monster attention load | Still open, advisory, unchanged. Carried |
| 12e D1 sprint/travel, D4 public roles and voice | Carried as Info, unchanged |
| 12e D5 backup switch unfakeable | Resolved as a decision (kept) and recorded as a playtest question in Monster Abilities Open Questions |
| 12e I1 Objectives omits "hiding" | Resolved (rule 2 and the failure texture now list hiding) |
| 12e I2 index Foundation heading | Heading rewritten, but the new text exposes a real loop: W1 below |
| 12e I3 Lobby Cross-References table | Resolved (template table with Nature column) |
| 12e I4 Lobby post-M1 AC tags | Resolved. AC-LB-07 to 20 and AC-LB-30 carry **(post-M1)** |
| 12e I5 Monster Abilities "Last Updated" | Resolved (header names 12e) |
| 12e scenarios (flinch with toggle off then taser; footsteps into a wall) | Both resolved in text (new Scare Events AC; new edge case and AC) |

---

## Consistency Issues

### Blocking

None.

### Warnings

⚠️ **W1. The 12e flinch fix makes the dependency graph circular** (systems-index rows 3, 9, 12 and the Foundation heading; first-person-controller Dependencies; scare-events Dependencies; monster-abilities Dependencies).
- Index row 3 now lists "Scare Events (`ViewNudge`, soft)" as a dependency of the Controller. Scare Events (row 12) depends on Monster Abilities (`AbilityUsed`, lunge wind-up timing), and Monster Abilities (row 9) depends hard on the Controller (movement, `player_radius_m`, backup switch hold). That is a cycle: Controller -> Scare Events -> Monster Abilities -> Controller. The 12e report counted the Controller as "no longer a loop" (I2); this change reopens it.
- The same edge also makes a Core / MVP system depend on a Presentation / Vertical Slice system, and the new Foundation Layer heading ("the Controller depends only on [Network Authority], plus the soft `ViewNudge` event from Scare Events") names a Presentation-layer dependency under Foundation.
- The cycle is soft (the Controller works without the event), but the Network Authority ADR and `/create-architecture` derive build order from this graph. A soft edge that still points up the layers is the kind of thing that gets read as hard.
- Fix (needs decision D1): either keep the event but model it as Scare Events writing to the Controller's input interface (the Controller exposes a "view offset" input; it does not depend on Scare Events, same as the movement-modifier row), or keep the Controller's soft dependency and annotate the index that soft event edges are excluded from layering.

⚠️ **W2. The flinch offset "stays" but nothing says when it ends, whether it accumulates, or what "a flinch already running ends" means now** (first-person-controller rules 7 and 9; scare-events rules 13, 14, Edge Cases, Impact Moments; downing-and-rescue; survivor-defense rule 20).
- Rule 13: the offset "ramps in over at most 0.3 s and then stays, so the view does not return". The offset is then permanent for the round as written. Two Major scares in one round (45 s Major cooldown) leave a summed offset, each up to the authored size, with no cap except the pitch clamp. No rule resets it at round end, on respawn/return to lobby, on reconnect (the server-held offset is server state; the client's copy is local), or when the player becomes Downed, Hidden or Seized.
- Rule 14: "a flinch already running ends when such a wind-up starts." With a held offset, "ends" has two readings: the offset freezes where it is (view stays rotated), or it is removed (the view snaps back, which is a second rotation and the thing rule 7 forbids). The Scare Events AC (line 291) tests "ends on that tick" without saying which.
- Hidden survivors have a restricted peek view (Survivor Defense rule 20) that rule 7 exempts from free look. How a held offset adds to a restricted peek cone is undefined (it could push the peek view outside its cone).
- Fix (D2): state the reset points, whether offsets sum or replace, and that a cancelled flinch freezes rather than reverts; add the Hidden case.

⚠️ **W3. Objectives' safe range for `interact_range_m` still breaks the Controller ray bound** (survivor-objectives Tuning Knobs, first-person-controller Formulas `max_owner_range_m`, registry).
- 12e W4 asked that the range row cover the safe-range case. Controller `max_owner_range_m` now records that the switch is capped at 2.3 so range + 0.7 <= 3.0, but `interact_range_m` (Objectives, also now the single range for every Survivor Defense interactable) still lists a safe range of 1.5-3, where 3 + 0.7 = 3.7 > `interact_ray_max_m` 3.0 (its own range 2.7-3.5). The Controller says the load-time check catches it, but the two safe ranges together are not satisfiable at their extremes, and one name now drives Objectives, Survivor Defense and (by the 28a note) all door actions.
- Fix: cap `interact_range_m` safe range at 2.3 like the switch, or state that raising it requires raising `interact_ray_max_m`. Mechanical; values stay.

---

## Game Design Issues

### Blocking

None.

### Warnings

⚠️ **D2. Monster attention load (carried).** Unchanged by this diff. Track in the M5 playtest.

⚠️ **D6. A permanently held view offset changes Fair Fear's "0.3 s control loss" promise.** (scare-events rules 13-14, Player Fantasy, Impact Moments; Pillar: Fair Fear.)
- The pillar framing everywhere is "at most 0.3 s of control loss, a jolt not a lock". The 12e decision makes the player's view settle at a new orientation that they did not choose. The player keeps mouse control during and after, so no input is lost, but the survivor is looking somewhere new, and a flinch toward a scare origin that stays (rule 13 Impact Moments: "toward origin") effectively points the camera at the scare. That is likely intended (it is also what makes the aim stay consistent), but no document tests whether it reads as a jolt or as a camera steal. The Open Question "Are 0.3 s flinch and 45 s major cooldown right?" does not ask it.
- Recommendation: add the held-offset read to that Open Question for the M5 playtest. No GDD conflict.

ℹ️ **D1 (carried, advisory)** and ℹ️ **D4 (carried, Info).** Unchanged.

Checks with no finding: 3a (no progression loops), 3d (no new resource), 3e (no scaling curves), 3f (the False Signal and backup-switch decisions serve Human Deception and Counterplay; the 12e fixes keep survivors verifying by sight), 3g (fantasies compatible; no anti-pillar violated).

---

## Cross-System Scenario Issues

Scenarios walked: 6
1. Major scare flinch, toggle on, then a second Major scare 50 s later (Scare Events, Controller, Survivor Defense).
2. Toggle off, Major scare, taser shot inside the 0.3 s window (Scare Events, Controller, Survivor Defense).
3. Reveal flinch running when a lunge wind-up starts 0.1 s after the form change (Borrowed Face, Scare Events, Monster Abilities).
4. Barricade, remove and break on one door at the same time, plus the backup switch range at 2.3 m (Survivor Defense, Monster Abilities, Controller).
5. False Signal footsteps aimed at a wall, then walking away to the far side (Monster Abilities, Controller, Pings).
6. Disconnect and reconnect of a flinched survivor (Scare Events, Controller, Match Flow).

#### Blockers

None.

#### Warnings

⚠️ **Reveal flinch cancelled by a wind-up** — Borrowed Face, Scare Events, Monster Abilities. Step: the reveal flinch ramps toward the reveal origin, a lunge wind-up starts, rule 14 "ends" the flinch. Whether the offset reverts (second rotation, 12e W3 intent broken) or freezes is undefined. Same cause as W2.

⚠️ **Held offset across reconnect** — Scare Events, Controller, Match Flow. Step: a flinched survivor disconnects within reconnect grace and returns. The server held the offset; the client's local copy is gone and the client sends fresh yaw/pitch. Without a stated reset the first tick after rejoin has the server view direction differ from the client's by the stale offset, which is the desync the 12e decision was meant to prevent. Same cause as W2.

#### Info

ℹ️ **Scenario 2 consistent.** With the toggle off the server applies no offset; the new Scare Events AC asserts the same, and the Controller AC mirrors it. Aim ray and view agree.

ℹ️ **Scenario 4 consistent after the fix.** The three door actions share one lock; the switch at 2.0 m (cap 2.3) fits the 3.0 m ray. The only leftover is W3.

ℹ️ **Scenario 5.** The path stops at the first wall and the audible radius is 6 m around the fake's current position. A fake that stops against a wall mid-path ends its footsteps earlier than 3 s; a real walker who reaches a wall turns or opens a door. This is a possible tell for a careful listener, not a conflict (I2).

ℹ️ **Host as shapeshifter** (carried): listen-server latency assumptions in Monster Abilities for the Network Authority ADR.

---

### Housekeeping (Info, not blocking)

- I1. `first-person-controller.md` Open Questions resolution row (line 379) still says "fake path up to ~12 m over 3 s at 4.0 m/s". It is a history row and true at defaults, but it is a second literal of a now-derived number.
- I2. Monster Abilities rule 13 allows the footsteps path end up to 20 m + path length from the monster (marked inferred, with a playtest or room-size question). The path's early stop at a wall is a possible tell (Scenario 5); worth one playtest question.
- I3. The toggle flag is client-sent. A modified client can claim "off" to avoid flinches. This is harmless by design (accessibility) but should be named in the Network Authority ADR scope so it is not read as a cheat vector.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| systems-index.md | W1 dependency loop and layer heading | Consistency | Warning |
| first-person-controller.md | W1 dependency row; W2 reset rules; W3 range row | Consistency | Warning |
| scare-events.md | W1 dependency row; W2 offset lifecycle, rule 14 "ends", Hidden; D6 Open Question | Consistency / Design | Warning |
| survivor-objectives.md | W3 `interact_range_m` safe range | Consistency | Warning |
| survivor-defense.md | W2 Hidden peek with a held offset (rule 20) | Consistency | Warning |

---

## Verdict: CONCERNS

All 12e warnings and housekeeping items are resolved in the text. No blocking issue remains. The c66c966 flinch model introduces three new warnings: a soft dependency loop (W1), an undefined lifecycle for the held offset (W2) and one safe range that still overruns the ray bound (W3). None block `/create-architecture`, but W1 and W2 should be settled before the Network Authority ADR, because the ADR derives view-direction authority and build order from them.

### Designer decisions needed
- D1 (W1). How the flinch reaches the Controller without a loop. Options: (a) Scare Events pushes to a Controller "view offset" input (the Controller does not depend on Scare Events; index row 3 and the Foundation heading go back to Network Authority only) (recommended: removes the cycle, same pattern as movement modifiers); (b) keep the soft Controller -> Scare Events edge and document that soft event edges are excluded from layering and build order; (c) move the offset ownership into the Controller and have Scare Events request it.
- D2 (W2). Offset lifecycle. Options: (a) offsets replace rather than sum (latest scare wins), reset to zero on round end, Downed, Hidden, Seized and reconnect, and a flinch cancelled by a wind-up freezes where it is (recommended: bounded, no second rotation, no desync on reconnect); (b) offsets sum with a cap of N degrees, reset only at round end; (c) the offset decays back over a few seconds (reintroduces a return rotation, reopens 12e D1).
- D3 (W3). `interact_range_m` safe range. Options: (a) cap at 2.3, matching the switch (recommended: keeps the load-time check satisfiable); (b) keep 1.5-3 and say that raising it requires raising `interact_ray_max_m`.
- D4 (D6, advisory). Add the held-offset read ("did the view settling somewhere new feel like a jolt or a camera steal?") to the M5 playtest question. Options: (a) add it (recommended); (b) leave as is.

### Required actions before re-running
None blocking. Recommended: settle D1 and D2, apply D3 and the housekeeping in one pass, then re-run `/review-all-gdds since-last-review` and `/gate-check` for Technical Setup.

### Recommended next
Settle D1 and D2 (they change Controller rule 7, Scare Events rules 13-14 and the index), apply the mechanical pass, re-run this review.
