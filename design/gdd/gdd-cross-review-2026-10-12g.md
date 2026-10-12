## Cross-GDD Review Report (since last review)

Date: 2026-10-12 (ninth cross-review, after `gdd-cross-review-2026-10-12f.md`)
Mode: since-last-review (consistency + design theory + scenarios), headless
GDDs Reviewed: 10 of 10 present (changed since the 12f report: first-person-controller, monster-abilities, scare-events, survivor-defense, survivor-objectives; borrowed-face, downing-and-rescue, lobby-role-assignment, match-flow and pings-and-callouts are unchanged and were checked by targeted search only)
Not read: none. (`design/levels/research-facility.md` came in through the DEPS line and was not touched by a02041d; `systems-index.md` and `design/registry/entities.yaml` were also checked.)
Systems Covered: all ten system GDDs plus the Facility Map, the index and the registry.

Pillars: Human Deception, Fair Fear, Counterplay, Readable Objectives, Small Shippable Scope. Anti-pillars: no AI monsters, not a combat game, not procedural, not voice-dependent, no progression or ranked.

Run notes:
- Headless. Phases 2 and 3 were done inline, not by spawned sub-agents: the scope is one fix commit (a02041d, 6 files, 27 insertions) and the work was a diff-driven check. No phase was skipped. Every question the skill would ask took its default.
- Method: `review-scope.sh` gave the changed set; the full a02041d diff was read; each 12f item was checked against the current text; every Depends On cell of the index was traced for cycles; each new rule was traced to every other place that states the same fact.
- Standard tier (`modes.workflow: standard`): no missing required section in any changed GDD. Advisory carried over: the Controller has no Player Fantasy or Tuning Knobs section; the Lobby has no Player Fantasy section.
- Per instruction, no GDD, the index, the registry or `active.md` was edited, nothing was committed, and the Phase 6 index-status update and session-state append were skipped.

---

## Status of the previous report's items

| Item | Status |
|---|---|
| 12f W1 dependency loop (Controller -> Scare Events -> Monster Abilities -> Controller) | Resolved in text. `ViewNudge` is gone from every file (only the 12f report mentions it). A "View offset" state row is added; index row 3 lists only Network Authority; the Foundation heading says the arrow runs Scare Events to the Controller. Controller Dependencies row ("Depends on this (writes the view-offset input)") and Scare Events Dependencies row ("This depends on it") agree. Cycle trace below confirms no loop. Follow-on gaps: W1, W3 below |
| 12f W2 offset lifecycle | Resolved in text. Replace not sum, reset points (round end, Downed, Hidden, Seized, reconnect), reset as re-baseline, freeze on lunge wind-up cancel, Hidden peek ignores the offset: stated in Controller rules 7 and 9, Scare Events rules 13-14, Edge Cases (3 new rows), Impact Moments, two ACs (Scare Events and a new Controller AC), the index state row and Survivor Defense rule 20. All of them say the same thing. Follow-on gaps: W1, W2, W4 below |
| 12f W3 `interact_range_m` safe range | Resolved. Objectives Tuning Knobs 1.5-2.3; Controller `max_owner_range_m` row and Monster Abilities `backup_switch_range_m` use the same cap and the same 0.7 reasoning. One small residue: I2 |
| 12f D6 held-view playtest question | Resolved. Appended to the Scare Events Open Question "Are 0.3 s flinch and 45 s major cooldown right?" |
| 12f D2 monster attention load | Still open, advisory, unchanged. Carried |
| 12f D1 sprint/travel, D4 public roles and voice | Carried as Info, unchanged |
| 12f I1 second literal of the fake path length | Resolved (Controller history row now reads `walk_speed` x `false_signal_footstep_duration_s`, 12 m at defaults) |
| 12f I2 path cut by a wall as a tell | Resolved (new Monster Abilities Open Question, Milestone 5 playtest) |
| 12f I3 client-declared flinch toggle | Resolved (new Controller Open Questions row, owner technical-director, Network Authority ADR) |
| 12f scenarios (reveal flinch cancelled by a wind-up; reconnect with a held offset) | Both resolved in text (freeze; server discards offset, client starts fresh) |

### Dependency cycle trace (every Depends On cell of the systems index)

Edges as declared in the Systems Enumeration table:

| # | System | Depends On (declared) |
|---|---|---|
| 1 | Network Authority | none |
| 2 | Lobby | 1 |
| 3 | Controller | 1 |
| 4 | Match Flow | 1, 2, 5, 6, 8, 11 |
| 5 | Objectives | 1, 3, 4, 11, 6, 7 |
| 6 | Downing | 1, 3, 9, 7, 4, 10 |
| 7 | Survivor Defense | 3, 9, 8, 6 |
| 8 | Borrowed Face | 1, 3, 7, 6, 11, 9 |
| 9 | Monster Abilities | 1, 3, 6, 8, 7, 11, 10, 4 |
| 10 | Pings | 3, 1, 8, 4, 6, 9, 7, 5 |
| 11 | Facility Map | 3 |
| 12 | Scare Events | 9, 8, 11, 4, 1, 7, 5, 10 |
| 13 | HUD | 4, 5, 6 |
| 14 | Accessibility | 12 |
| 15 | Telemetry | 4, all gameplay |

Result:
- **Controller (3) and Network Authority (1) are on no cycle.** Controller -> 1 only; 1 -> nothing. Nothing reached from the Controller leads back to it. Facility Map (11) -> 3 only, and Lobby (2) -> 1 only, so they are acyclic too.
- **Scare Events (12) is on no cycle.** It points at 9, 8, 11, 4, 1, 7, 5, 10 and nothing points at it except Accessibility (14), which is Polish. The 12f loop is closed.
- Feature systems 4, 5, 6, 7, 8, 9, 10 form one strongly connected set through their declared Depends On cells (for example 4 -> 5 -> 4, 4 -> 6 -> 4, 7 -> 9 -> 7, 9 -> 10 -> 9, 6 -> 10 -> 6). The index's "Circular Dependencies" section names only two of these pairs (Downing <-> Monster Abilities, Borrowed Face <-> Survivor Defense). This is pre-existing and was never raised in earlier reviews, which treated the Depends On column as mutual references (the GDD rule "Dependencies must be bidirectional" produces exactly this). See I1.
- State-table read edges (Controller reads Lunge state, Hidden state, Takedown eligibility, Transforming flag) point from the Controller to Feature systems. By the convention fixed in 12d W3 (event and state reads are "not a layer dependency") they are excluded from the graph above. That convention is the reason the claim "the Controller depends only on Network Authority" holds. It is stated per case, not once. See I1.

---

## Consistency Issues

### Blocking

None.

### Warnings

⚠️ **W1. Nobody is named as the one who performs the offset resets** (systems-index state row "View offset"; first-person-controller rules 7 and 9; scare-events rule 13, Edge Cases, ACs; survivor-defense rule 20).
- The index state row says "Scare Events writes it; the Controller owns the input and applies it", and the state-table preamble says "Only the owner writes it". The reset points are round end, Downed, Hidden, Seized and reconnect. Controller rule 7 says "the offset resets to 0 ... on reconnect (the server discards it and the client starts fresh)", and Survivor Defense rule 20 says the offset "is reset to 0 on entering the hide", but none says which system does the reset.
- If Scare Events resets, it must read Downed and Seized (Takedown eligibility state), Hidden state, `RoundEnded` and `PlayerConnectionChanged`. None of those index rows or events lists Scare Events as a reader or consumer (Scare Events' declared Depends On also omits Downing, Rescue & Elimination). If the Controller resets, it is a write by a non-owner of the row, and the Controller already reads all five of these (it is a listed reader of Takedown eligibility, Hidden state, and a consumer of `RoundEnded` and `PlayerConnectionChanged`), so this reading is the natural one.
- Fix (needs decision D1): name the Controller as the party that re-baselines on those five triggers (Scare Events writes new flinches only), and say so in the index state row, Controller rule 7 and Scare Events rule 13.

⚠️ **W2. "Bounded by one authored size" has no authored size** (scare-events Edge Cases row 178, Tuning Knobs, rule 13; first-person-controller rule 7; registry).
- The Edge Case row justifies "replace, no stacking" with "the offset is bounded by one authored size". The Scare Events Tuning Knobs list `scare_max_control_loss_s` (time) but no flinch angle, and rule 13 and Impact Moments say only "toward origin". Without a size the bound is the ±85 degree pitch clamp plus 360 degrees of yaw, so a flinch toward a scare origin behind the player could rotate the view up to 180 degrees within 0.3 s.
- Replace also changes the size of one ramp: with an old offset of +20 and a new target of -20, the second ramp rotates the view 40 degrees in 0.3 s, twice the authored size. The 12f text says the ramp "starts from the current offset toward the new target", so this is what it specifies.
- This is the piece that D6 (held view reads as jolt or camera steal) will be judged on, and a tester cannot write the AC "offset equals X" without it.
- Fix (needs decision D2): add a `flinch_max_angle_deg` knob (proposed value to be set in playtest) and state whether the target is absolute (face the origin, capped) or relative, and whether a replacing flinch is also capped at one authored size of rotation.

⚠️ **W3. The index still does not record the arrow from Scare Events to the Controller** (systems-index rows 3, 12 and the Dependency Map Presentation Layer).
- The fix moved the edge to "Scare Events depends on the Controller" (Controller Dependencies row: "Depends on this"; Scare Events Dependencies row: "This depends on it"). Index row 12 Depends On still reads "Monster Abilities, Borrowed Face, Facility Map, Match Flow, Network Authority, Survivor Defense, Survivor Objectives, Pings & Callouts", and the Presentation Layer entry reads "Monster Abilities, Borrowed Face, Facility Map, Match Flow". Neither lists Controller & Interaction. The new Foundation heading says the arrow runs "Scare Events to the Controller", but the graph itself does not contain it.
- The graph is what the Network Authority ADR and `/create-architecture` read build order from; the arrow is soft but the graph was the place W1 was raised.
- Fix: add "Controller & Interaction (soft: writes the view-offset input)" to row 12 and the Presentation entry. Mechanical, no decision.

⚠️ **W4. The toggle can change while an offset is held** (scare-events rules 13 and 27; first-person-controller rule 7; accessibility).
- The toggle flag is sent "on join and on change". Rule 27 and Controller rule 7 say that with the toggle off "the server applies no offset at all and the player's server view direction never changes during a scare". The reset list (round end, Downed, Hidden, Seized, reconnect) does not include a toggle change to off. A player who turns the flinch off from a pause menu mid-round, while holding an offset, either keeps the held rotation (the accessibility promise is broken until the next reset) or has it removed (which must be a re-baseline, since a snap-back is a second rotation).
- Fix (D3): add "flinch toggle switched off" as a re-baseline reset point in the same four places that list the others.

---

## Game Design Issues

### Blocking

None.

### Warnings

⚠️ **D2. Monster attention load (carried).** Unchanged by this diff. Track in the M5 playtest.

ℹ️ **D6 resolved as a playtest question; W2 above is what makes it measurable.**

ℹ️ **D1 (carried, advisory)** and ℹ️ **D4 (carried, Info).** Unchanged.

Checks with no finding: 3a (no progression loops), 3d (no new resource), 3e (no scaling curves), 3f (the lifecycle decisions keep the offset bounded and the Hidden peek intact, serving Fair Fear and Counterplay), 3g (fantasies compatible; no anti-pillar violated). Replace-not-sum is the lower-risk choice for Fair Fear than summing.

---

## Cross-System Scenario Issues

Scenarios walked: 6
1. Major scare flinch (toggle on), then a second Major scare 50 s later toward a different origin (Scare Events, Controller).
2. Survivor holding an offset hides in a locker, peeks, and leaves (Scare Events, Survivor Defense, Controller).
3. Reveal flinch running when a lunge wind-up starts 0.1 s after the form change (Borrowed Face, Scare Events, Monster Abilities).
4. Held offset, then Seized by a lunge hit, Downed, rescued (Scare Events, Monster Abilities, Downing, Controller).
5. Disconnect and reconnect of a flinched survivor within grace (Scare Events, Controller, Match Flow).
6. Backup switch at 2.3 m and Objectives interaction at the new 2.3 m cap with the ray at its default and at its minimum (Objectives, Monster Abilities, Controller).

#### Blockers

None.

#### Warnings

⚠️ **Toggle switched off while an offset is held** — Scare Events, Controller, Accessibility. Step: the player turns the flinch off in settings with a held offset. No rule says whether the offset stays. Same cause as W4.

⚠️ **Second flinch toward the opposite side** — Scare Events, Controller. Step: held +20 degrees, new target -20 degrees; the replacing ramp rotates the view 40 degrees in 0.3 s. Same cause as W2.

#### Info

ℹ️ **Scenario 2 consistent.** The offset is reset on entering the hide as a re-baseline and the peek ignores it, so the peek cannot leave its cone. On leaving, the offset is 0. Who performs the reset is W1.

ℹ️ **Scenario 3 consistent.** Rule 14 and the AC now say freeze, and the Borrowed Face row still says it is the Scare Events reveal flinch and inherits rule 14.

ℹ️ **Scenario 4 consistent.** Seized resets the offset before the takedown commit; Downed and rescue start from 0, so the Downed camera impact (visual only) never meets a held offset.

ℹ️ **Scenario 5 consistent.** The server discards the offset and the client starts fresh. The text does not say which yaw the fresh client starts from (the last server view direction would be the natural answer, otherwise the reconnected view could jump); this is a Network Authority ADR detail alongside the ramp-sync note in the gate check.

ℹ️ **Scenario 6 consistent at defaults.** 2.3 + 0.7 = 3.0 <= `interact_ray_max_m` 3.0. See I2 for the ray's own minimum.

ℹ️ **Host as shapeshifter** (carried): listen-server latency assumptions in Monster Abilities for the Network Authority ADR.

---

### Housekeeping (Info, not blocking)

- I1. Two small index notes: (a) the "Circular Dependencies" section lists two pairs, but the declared Depends On cells put seven Feature systems into one connected set (trace above); a single sentence saying "Depends On is a mutual-reference list among Feature systems; layering is by event and state, and event and state reads do not count as layer dependencies (12d W3)" would stop the next reader re-deriving a cycle. (b) The registry entry for `interact_range_m` does not record the new 1.5-2.3 safe range (the switch entry does).
- I2. `interact_ray_max_m` has its own safe range 2.7-3.5. At 2.7 an `interact_range_m` of 2.3 gives 2.3 + 0.7 = 3.0 > 2.7. The Controller's load-time check (formula under `interact_ray_max_m`) catches it, and the Tuning Knob cap text now says "so range + 0.7 <= interact_ray_max_m 3.0" (true at the default ray). No change needed; the ranges are satisfiable at their defaults and the check is the guard.
- I3. Typo: `first-person-controller.md` Dependencies, Scare Events row, "This does not depend on Scare Events Every other camera effect is a visual offset only" is missing a full stop after "Scare Events".

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| systems-index.md | W1 state row reset owner; W3 row 12 and Presentation entry lack the Controller edge; I1 | Consistency | Warning |
| first-person-controller.md | W1 reset owner; W2 flinch size; W4 toggle change; I3 typo | Consistency | Warning |
| scare-events.md | W1 reset owner; W2 flinch angle knob; W4 toggle change | Consistency / Design | Warning |
| survivor-defense.md | W1 (rule 20 reset wording names no actor) | Consistency | Warning |

---

## Verdict: CONCERNS

All 12f warnings, the decision items D1 to D3, the playtest question D6 and the housekeeping items I1 to I3 are resolved in the text, and the files changed in a02041d agree with each other on the model (replace, reset points, freeze, Hidden). The index has no cycle through the Controller or Scare Events. No blocking issue remains. Four new warnings are follow-ons of the same fix: the reset has no named actor (W1), the flinch has no authored size (W2), the index graph lacks the new Scare Events -> Controller arrow (W3) and a toggle change mid-hold is unspecified (W4). None block `/create-architecture`, but W1 and W2 should be settled before the Network Authority ADR, because that ADR derives who writes server view state from them.

### Designer decisions needed
- D1 (W1). Who performs the offset resets. Options: (a) the Controller re-baselines on its five triggers; Scare Events only writes new flinches (recommended: the Controller already reads all five signals, no new Scare Events dependency, keeps the "owner writes" rule for new offsets, and the re-baseline is a view concept the Controller owns); (b) Scare Events performs the resets and gains reads of Takedown eligibility, Hidden state, `PlayerConnectionChanged` and `RoundEnded` plus a Downing dependency; (c) the server round loop clears it generically with no system named (not recommended: the Network Authority ADR then inherits an unowned rule).
- D2 (W2). Flinch size. Options: (a) add `flinch_max_angle_deg` as a Scare Events knob, flinch target capped at that angle toward the origin, and a replacing flinch also capped at one authored size of rotation, value set in the M5 playtest (recommended: gives the "bounded" claim a number and the AC a threshold); (b) cap the target only, accept up to two sizes of rotation on replacement; (c) leave the size to implementation and playtest feel.
- D3 (W4). Toggle switched off mid-hold. Options: (a) re-baseline to 0 on the change (recommended: matches the accessibility promise, no visible rotation, one more reset point in the same list); (b) leave the held offset until the next reset and say so; (c) disallow changing the toggle during a round.
- W3 and I1 to I3 are mechanical; no decision needed.

### Required actions before re-running
None blocking. Recommended: settle D1 to D3, apply W3 and the housekeeping in one pass, then re-run `/review-all-gdds since-last-review`.

### Recommended next
Settle D1 and D2 (they change Controller rule 7, Scare Events rule 13, the index state row and add one knob), apply the mechanical pass, re-run this review, then proceed to `/create-architecture` starting with the Network Authority ADR.
