## Cross-GDD Review Report (since last review)

Date: 2026-10-12 (tenth cross-review, after `gdd-cross-review-2026-10-12g.md`)
Mode: since-last-review (consistency + design theory + scenarios), headless
GDDs Reviewed: 10 of 10 present (changed since the 12g report: first-person-controller, scare-events, survivor-defense; the other seven are unchanged and were checked by targeted search only)
Not read: none. (`design/levels/research-facility.md` came in through the DEPS line and was not touched by baf1d8d; `systems-index.md` and `design/registry/entities.yaml` were also checked.)
Systems Covered: all ten system GDDs plus the Facility Map, the index and the registry.

Pillars: Human Deception, Fair Fear, Counterplay, Readable Objectives, Small Shippable Scope. Anti-pillars: no AI monsters, not a combat game, not procedural, not voice-dependent, no progression or ranked.

Run notes:
- Headless. Phases 2 and 3 were done inline, not by spawned sub-agents: the scope is one fix commit (baf1d8d, 5 files, 30 insertions, 15 deletions) and the work was a diff-driven check. No phase was skipped. Every question the skill would ask took its default.
- Method: `review-scope.sh` gave the changed set; the full baf1d8d diff was read; each 12g item was checked against the current text; every Depends On cell of the index was traced for cycles; every place that states the reset actor, the flinch size or the toggle-off reset was grepped and compared.
- Standard tier (`modes.workflow: standard`): no missing required section in any changed GDD. Advisory carried over: the Controller has no Player Fantasy or Tuning Knobs section; the Lobby has no Player Fantasy section.
- Per instruction, no GDD, the index, the registry or `active.md` was edited, nothing was committed, and the Phase 6 index-status update and session-state append were skipped.

---

## Status of the previous report's items

| Item | Status |
|---|---|
| 12g W1 reset actor | Resolved. Controller rule 7, Scare Events rule 13 and Edge Cases, the Scare Events Camera-flinch paragraph in its Dependencies prose (line 126), the Controller Dependencies row, the index "View offset" state row and Survivor Defense rule 20 all say the Controller performs every reset and Scare Events only writes new flinches. No file still says Scare Events resets (grep for view-offset and flinch-offset wording across all GDDs). Follow-on gap: W1 below (the toggle row's reader list) |
| 12g W2 flinch size | Resolved in text. `flinch_max_angle_deg` = 10 (proposed placeholder, inferred, safe range set in the M5 playtest) is in Scare Events rule 13, Edge Cases, Tuning Knobs, the AC, Controller rule 7 and its AC, the index state row and the registry. The 180-degree worst case and the "40 degrees in 0.3 s" case are closed. One small residue: I1 |
| 12g W3 index row 12 and Presentation entry | Resolved. Row 12 and the Presentation Layer entry both add "First-Person Controller & Interaction (soft: writes the view-offset input)". Residue: I2 |
| 12g W4 toggle off mid-hold | Resolved in text. "Switched off while an offset is held" is a re-baseline reset point in Controller rule 7, its AC, Scare Events rule 13, its AC, and the index state row. Follow-on gap: W1 below |
| 12g I1 (a) circular-dependencies note | Resolved. One sentence under Circular Dependencies says the Feature systems' Depends On cells are a mutual-reference web by convention, not build order, and that event and state reads are not layer dependencies (12d W3) |
| 12g I1 (b) `interact_range_m` registry comment | Resolved ("safe range 1.5-2.3 m" is on the entry) |
| 12g I2 ray-max safe range | Unchanged, no change needed (load-time check is the guard) |
| 12g I3 missing full stop in the Controller Dependencies row | Resolved ("This does not depend on Scare Events. Every other camera effect...") |
| 12g D2 monster attention load, D1 sprint/travel, D4 public roles and voice | Carried, unchanged, advisory/Info |

### Dependency cycle trace (every Depends On cell of the systems index)

Edges as declared in the Systems Enumeration table (only row 12 changed in baf1d8d):

| # | System | Depends On (declared) |
|---|---|---|
| 1 | Network Authority | none |
| 2 | Lobby | 1 |
| 3 | Controller | 1 (plus Match Flow events, an event read) |
| 4 | Match Flow | 1, 2, 5, 6, 8, 11 |
| 5 | Objectives | 1, 3, 4, 11, 6, 7 |
| 6 | Downing | 1, 3, 9, 7, 4, 10 |
| 7 | Survivor Defense | 3, 9, 8, 6 |
| 8 | Borrowed Face | 1, 3, 7, 6, 11, 9 |
| 9 | Monster Abilities | 1, 3, 6, 8, 7, 11, 10, 4 |
| 10 | Pings | 3, 1, 8, 4, 6, 9, 7, 5 |
| 11 | Facility Map | 3 |
| 12 | Scare Events | 9, 8, 11, 4, 1, 7, 5, 10, 3 (new, soft) |
| 13 | HUD | 4, 5, 6 |
| 14 | Accessibility | 12 |
| 15 | Telemetry | 4, all gameplay |

Result:
- **Edge 12 -> 3 closes no loop.** The Controller (3) points at Network Authority (1) only, and 1 points at nothing, so nothing reachable from 3 leads back to 12. The Controller does not list Scare Events anywhere as a dependency (Controller Dependencies row: "Depends on this"; Scare Events row: "This depends on it"). Nothing but Accessibility (14, Polish) points at 12.
- **Accessibility (14) -> 12 does not loop either.** Scare Events reads the flinch toggle as state owned by Accessibility but declares no dependency on it (Scare Events Dependencies table lists Accessibility as "Accessibility depends on this").
- Network Authority (1), Lobby (2), Facility Map (11), Controller (3) and Scare Events (12) are on no cycle by declared edges.
- Feature systems 4 to 10 still form one strongly connected set through their Depends On cells (for example 4 -> 5 -> 4, 7 -> 9 -> 7). The new Circular Dependencies sentence now states that this is a mutual-reference web and not build order, which is what 12g I1 asked for.
- Event and state reads that point from the Controller at Feature systems (Match Flow events, Lunge state, Hidden state, Takedown eligibility, Transforming flag, and now the flinch toggle) are excluded by the 12d W3 convention, restated once in the new sentence. The claim "the Controller depends only on Network Authority" therefore holds under that convention.

### Check of the files changed in baf1d8d for new conflicts

- first-person-controller.md (rules 7, 9, Dependencies row, AC): consistent with scare-events.md rule 13 on actor, size, reset list (round end, Downed, Hidden, Seized, reconnect, toggle off), re-baseline and freeze-on-wind-up. The Dependencies-row full stop is fixed.
- scare-events.md (rule 13, Edge Cases rows 178 to 180, Camera-flinch dependency prose, Tuning Knobs row 214, AC row 297): consistent with the Controller. Rule 14 (freeze, no revert) is untouched and still agrees.
- survivor-defense.md rule 20: names the Controller as the reset actor; consistent with the Hidden peek view ignoring the offset.
- systems-index.md (state row, row 12, Presentation entry, Circular Dependencies sentence): consistent with the GDDs except the toggle row (W1) and the Presentation entry list (I2).
- design/registry/entities.yaml: `flinch_max_angle_deg` value 10, unit deg, source scare-events.md, referenced by scare-events.md and first-person-controller.md, matching the GDD text. The `interact_range_m` comment matches Objectives Tuning Knobs.

---

## Consistency Issues

### Blocking

None.

### Warnings

⚠️ **W1. The Controller now needs the flinch toggle, but no table lists it as a reader** (systems-index state row "Camera flinch toggle (per player)"; first-person-controller Dependencies table).
- The baf1d8d fix makes the Controller re-baseline "when the player switches the flinch toggle to off while an offset is held" (Controller rule 7; Scare Events rule 13). To do that the Controller must see the toggle flag (or its change). The index state row for the toggle still reads "Read by: Scare Events (rule 13: no view offset written when off)". The Controller Dependencies table has no row for the flag or for Accessibility Options. The 12g W1 argument for choosing the Controller as reset actor was that it "already reads all five signals"; that holds for round end, Downed, Hidden, Seized and reconnect, but the sixth trigger (toggle off) is a read the Controller did not have before. Rule 7 does say the server knows the flag, so a programmer can guess, but the contract table the Network Authority ADR reads is silent.
- Fix (mechanical, no decision): add "First-Person Controller & Interaction (re-baselines a held view offset when the flag goes off)" to the toggle row's "Read by", and a one-line state-read mention in the Controller Dependencies prose. Same class as 12g W3; the Controller still depends on nothing new by layer (state read, 12d W3).

---

## Game Design Issues

### Blocking

None.

### Warnings

⚠️ **D2. Monster attention load (carried).** Unchanged by this diff. Track in the M5 playtest.

ℹ️ **D1 (carried, advisory)** and ℹ️ **D4 (carried, Info).** Unchanged.

Checks with no finding: 3a (no progression loops), 3d (no new resource), 3e (no scaling curves; the one new constant is a clamp), 3f (a 10-degree cap, a Controller-owned re-baseline and the toggle-off reset all serve Fair Fear and the accessibility promise; no snap-back rotation anywhere), 3g (fantasies compatible; no anti-pillar violated). The cap makes the D6 playtest question (held view reads as jolt or camera steal) measurable.

---

## Cross-System Scenario Issues

Scenarios walked: 6
1. Held +10 degree offset, a second Major scare toward the opposite side (Scare Events, Controller).
2. Player turns the flinch toggle off in the pause menu with a held offset, then a later Major scare plays (Scare Events, Controller, Accessibility).
3. Hidden survivor with a held offset: the Controller re-baselines on entering Hidden, peek view ignores the offset, offset is 0 on leaving (Survivor Defense, Controller).
4. Held offset, then Seized, Downed, rescued (Scare Events, Monster Abilities, Downing, Controller).
5. Disconnect and reconnect within grace with a held offset (Scare Events, Controller, Match Flow).
6. Reveal flinch running when a lunge wind-up starts: freeze, no revert; then the round ends and the Controller re-baselines (Borrowed Face, Scare Events, Monster Abilities, Controller).

#### Blockers

None.

#### Warnings

None. Scenario 2 depends on the Controller seeing the toggle change; that is W1 (table gap only, the rule text is clear).

#### Info

ℹ️ **Scenario 1 resolves to a defined result.** With "target at most 10" and "total rotation of a replacing flinch at most 10" both stated, a held +10 and a new -10 target means the target is clipped so the ramp moves at most 10 (ends near 0, not at -10). Text states both caps but not the clipping order. See I1.

ℹ️ **Scenarios 3, 4, 6 consistent.** Single actor (Controller), re-baseline, no snap-back, freeze on wind-up.

ℹ️ **Scenario 5 consistent**, with the carried note that the yaw a fresh client starts from after reconnect is a Network Authority ADR detail.

ℹ️ **Host as shapeshifter** (carried): listen-server latency assumptions in Monster Abilities for the Network Authority ADR.

---

### Housekeeping (Info, not blocking)

- I1. `flinch_max_angle_deg` is stated as two caps (target magnitude, and total rotation of a replacing flinch) without saying how a target is reduced when both cannot be met (for example held +10, new -10), or whether 10 degrees is the combined angle or a per-axis limit on the yaw and pitch offset. The AC thresholds are testable as written; one sentence in Scare Events rule 13 ("the new target is clipped to the intersection of both caps") would remove the guess. Placeholder value is explicitly M5-tunable.
- I2. The Presentation Layer entry for Scare Events lists five dependencies, while index row 12 lists nine (the entry omits Network Authority, Survivor Defense, Survivor Objectives and Pings & Callouts). This predates baf1d8d and was not raised before; baf1d8d added the Controller to both. Align the entry to row 12 in the next index pass.
- I3. The Controller Dependencies row says Scare Events "writes" the offset and the same row now says the Controller resets it; the index row for the state says "Scare Events ... writes new flinches only". Wording agrees; no change needed.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| systems-index.md | W1 toggle row lacks the Controller as a reader; I2 Presentation entry list shorter than row 12 | Consistency | Warning |
| first-person-controller.md | W1 Dependencies prose does not mention the toggle read | Consistency | Warning |
| scare-events.md | I1 clipping order for the two caps | Consistency | Info |

---

## Verdict: CONCERNS

All 12g warnings (W1 to W4) and housekeeping (I1 to I3) are resolved in the text, and the five files changed in baf1d8d agree with each other on actor, size, reset list, re-baseline and freeze. No dependency cycle exists through the Controller or Scare Events; the new Scare Events -> Controller edge is soft and one-way. One new mechanical warning remains: the sixth reset trigger (toggle off) makes the Controller a reader of the flinch toggle, and the index toggle row and Controller Dependencies do not say so. It blocks nothing and needs no designer decision. `/create-architecture` may start; the Network Authority ADR should take the corrected reader list.

### Designer decisions needed
None are required. Optional, for I1:
- D1 (I1). How the two flinch caps combine when they conflict. Options: (a) clip the new target into the range allowed by both caps, so a replacing flinch ends closer to 0 than its origin direction (recommended: smallest rule, keeps the "10 degrees in total" promise literally); (b) let the target win and the total rotation be up to 2 x `flinch_max_angle_deg` (reverts the 12g decision); (c) leave to playtest. Also confirm 10 degrees is a combined angle, not per axis.

### Required actions before re-running
None blocking. Recommended: apply W1 and I2 in one mechanical pass, optionally settle D1, then proceed to `/create-architecture` starting with the Network Authority ADR. A further re-run is only worthwhile after other GDD changes.

### Recommended next
Mechanical pass for W1/I2, then `/create-architecture` (Network Authority ADR first).
