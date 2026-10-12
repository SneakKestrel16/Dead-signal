# Cross-GDD Review Report (since last review)

Date: 2026-10-12 (fifth cross-review, after `gdd-cross-review-2026-10-12b.md`)
Mode: since-last-review (consistency + design theory + scenarios, scoped to changes since 6f7270a)
GDDs Reviewed: 8 of 8 present (4 changed: borrowed-face, monster-abilities, scare-events, survivor-defense; 4 unchanged checked against the changes: match-flow, survivor-objectives, downing-and-rescue, pings-and-callouts)
Not read: none
Systems Covered: all eight system GDDs, plus `design/levels/research-facility.md`, `systems-index.md` and `design/registry/entities.yaml`.

Pillars: Human Deception, Fair Fear, Counterplay, Readable Objectives, Small Shippable Scope.

Run notes:
- Headless run. Phases 2 and 3 were done inline, not by spawned sub-agents. No phase was skipped.
- Scope: the diff 6f7270a..5fb89ae. It holds the fourth cross-review fixes (769e58f: disguise completion ends immunity, rule 11 wording, alarm on install completion, running flinch) and the four design-review approvals (5fb89ae: break in any form, reveal rows merged, Low → Emergency transition).
- The systems index was not updated; all eight GDDs are already Approved.

---

## Status of the previous report's items

| Item | Status |
|---|---|
| B1 immunity carried into a disguise | Resolved (769e58f, option a) |
| W1 rule 11 post-lock wording | Resolved (769e58f) |
| W2 alarm trigger | Resolved (769e58f, install completion) |
| W3 running flinch | Resolved (769e58f) |
| Earlier W6 (Scare Events phase model) | Resolved (Low → Emergency added, 5fb89ae) |
| Earlier W9, second half (duplicate reveal scare entries) | Resolved (merged, 5fb89ae) |
| Earlier W12 (disguised barricade break) | Resolved (Survivor Defense rule 27: any form, visible monster action, 5fb89ae) |
| Earlier W1–W5, W8, W9 first half (200 ms camera impact in two docs), W10, W11, W13, D1, D2 | Not touched by this diff and not re-checked; still open per `gdd-cross-review-2026-10-12.md` |

---

## Consistency Issues

### Blocking
None.

### Warnings

⚠️ **W1. Survivor Defense now consumes `FormChanged`, but no table says so** (systems-index, survivor-defense, borrowed-face).
- Survivor Defense rule 16 ends immunity "when a transformation into a disguise completes (Borrowed Face rule 9)". The States table also lists it as an Immune exit. That completion is the `FormChanged` event.
- The index event table row for `FormChanged` lists only Pings & Callouts, Scare Events and all clients.
- The Borrowed Face row in Survivor Defense Dependencies says it reads "disguised and Transforming state to pick the shock presentation", with no mention of immunity. Borrowed Face Dependencies has the same gap.
- Fix (30-second edit): add Survivor Defense (immunity ends on change into a disguise, rule 16) to the `FormChanged` consumers, and to both Dependencies rows.

⚠️ **W2. The registry comment for `stun_immunity_s` is stale** (`design/registry/entities.yaml`).
- It reads "(proposed) ends early if the monster starts a lunge wind-up".
- It omits the disguise-completion early end, and it omits the post-lock window that the same value now sets for every player (Survivor Defense rule 14).
- Fix (30-second edit): update the comment.

---

## Game Design Issues

### Blocking
None.

### Warnings
None new.
- Break in any form adds a visible monster action, which strengthens tell T4.
- The disguise-completion end of immunity removes the last stun-based identity test found.
- Re-stunning after a re-disguise is the monster's own choice and stays inside `lock_share` reasoning (Survivor Defense rule 17).

---

## Cross-System Scenario Issues

Scenarios walked: 4
1. Stunned while disguised as A, then a change into disguise B during immunity (Survivor Defense, Borrowed Face): immunity ends at completion, so B is stunned and locked like an unshocked survivor. No tell.
2. Stunned while disguised, then a change into true form during immunity: immunity continues and hits show the "resisted" spark in true form. No tell; the true form is already open.
3. Disguised monster breaks a barricade (Survivor Defense rule 27, Scare Events door burst, Borrowed Face T4): the break is loud and visible, the door burst scare is shared, and `source` is stripped. Consistent.
4. Terminal armed during Infiltration (Match Flow rule 6, Scare Events States table, Facility Map Evacuation state): Low → Emergency, with the Emergency budget applying from that moment. Consistent.

### Blockers
None. ### Warnings: none beyond W1. ### Info: none.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|---|---|---|---|
| systems-index.md | W1 `FormChanged` consumers | Consistency | Warning |
| survivor-defense.md | W1 Dependencies row | Consistency | Warning |
| borrowed-face.md | W1 Dependencies row | Consistency | Warning |
| entities.yaml (registry) | W2 stale comment | Consistency | Warning |

---

## Verdict: CONCERNS

Nothing blocks. Two warnings are 30-second edits. Older open warnings (W1–W5, W8, W9 camera impact, W10, W11, W13, D1, D2 from `gdd-cross-review-2026-10-12.md`) remain open and should be cleared or accepted before `/create-architecture`.

---

## Resolution (2026-10-12)

Designer decisions (asked in session):
- W13 (earlier report): a RoundScript slammed door is presentation only and never changes the door's state (Scare Events rule 7 and AC, Facility Map scare anchors).
- W8 (earlier report): stun items removed from item pings, since tasers are never world objects (Pings rule 5, Interactions, Dependencies, Cross-References; Survivor Defense Dependencies).
- W11 (earlier report): stun and immunity timers keep running through a monster disconnect (Match Flow rule 20, Survivor Defense Edge Cases and Dependencies).
- D1 (earlier report): a worst-case grouped route estimate (inference, ~2–3 min against 420 s) and a grouping playtest AC added to the Facility Map (AC 11). Redesign only if never-split teams win more often.

Mechanical fixes:
- This report's W1 (`FormChanged` consumer and Dependencies rows) and W2 (registry comment).
- Earlier W1: index Progress Tracker and the `game-concept.md` engine row.
- Earlier W2: index Depends On column; Borrowed Face rows for Match Flow and Survivor Objectives made Bidirectional; Survivor Defense gains a Match Flow row.
- Earlier W3: index event and state tables now list every read the GDDs make, including the new Lunge state and Committing rows.
- Earlier W4: Escaped added to Borrowed Face rules 6 and 13, plus an edge row.
- Earlier W5: Facility Map candidate replication and AC 4 now follow Objectives' discovery rule.
- Earlier W9: the 200 ms victim camera impact is owned by Downing; Monster Abilities points to it.
- Earlier W10: Downing's 1.5 s stun window now states it assumes a teammate within 5 m.

Still open: D2 (monster attention load; advisory, track in the M5 playtest).

The affected GDDs stay Approved. Every change is either a designer decision taken here or a table and wording alignment. Their review receipts no longer match, so the next `/design-review` of any of them runs a full review.
