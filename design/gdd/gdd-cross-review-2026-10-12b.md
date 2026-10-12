# Cross-GDD Review Report (since last review)

Date: 2026-10-12 (fourth cross-review, same day as `gdd-cross-review-2026-10-12.md`)
Mode: since-last-review (consistency + design theory + scenarios, scoped to changes since 7544e44)
GDDs Reviewed: 8 of 8 present (5 changed in full: borrowed-face, monster-abilities, pings-and-callouts, scare-events, survivor-defense; 3 unchanged checked against the changes: match-flow, survivor-objectives, downing-and-rescue)
Not read: none
Systems Covered: all eight system GDDs, plus `design/levels/research-facility.md` (Facility Map), `systems-index.md`, `design/registry/entities.yaml`, and the previous report.

Pillars: Human Deception, Fair Fear, Counterplay, Readable Objectives, Small Shippable Scope.
Anti-pillars: not an AI-monster game, not a combat game, not procedurally generated, not voice-dependent, not a progression or ranked game.

Run notes:
- Headless run. Phases 2 and 3 were done inline in the orchestrating session, not by spawned `game-designer` sub-agents. No phase was skipped.
- Scope: the diff 7544e44..7913dd2 (cross-review B1–B4 fixes in 0ab034c, then the Scare Events design review in 7913dd2). It was checked against every GDD that reads the changed rules (grep for shock lock, immunity, post-lock window, hold cancel, scare triggers).
- The systems index was **not** updated. This run writes only this report and the session extract.
- File name carries a `b` suffix because `gdd-cross-review-2026-10-12.md` already exists. `review-scope.sh` sorts names, so `2026-10-12b` correctly sorts after it.

---

## Status of the previous report's items

| Item | Status |
|---|---|
| B1 scare triggers name nonexistent mechanics | Resolved (0ab034c; slammed-door Survivor trigger also cut in 7913dd2) |
| B2 lighting owner | Resolved (0ab034c) |
| B3 False Signal scare leak | Resolved (0ab034c) |
| B4 back-to-back locks chain a disguised monster | Resolved by the post-lock window (0ab034c), but it opens **B1 below** |
| W6 Scare Events phase model stale | Mostly resolved (7913dd2: phases keyed to `RoundPhaseChanged`). The install-start alarm part is still open (W2 below) |
| W7 flinch overlaps the lunge wind-up | Mostly resolved (7913dd2: rule 14, no flinch near a wind-up; ambush lunge stinger only). One gap left (W3 below) |
| W1–W5, W8–W13, D1, D2 | Still open; not re-raised here. See `gdd-cross-review-2026-10-12.md` |

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

🔴 **B1. Immunity carried into a disguise makes the no-lock shock an identity test** (survivor-defense, borrowed-face).
- Survivor Defense rule 10 (new, B4): an immune hit on a disguised monster plays the full shock "with no root, slow or action lock … so an immune hit always falls inside the post-lock window (rule 14) and looks exactly like a hit on a survivor inside theirs".
- That holds only if the immunity came from a lock that observers saw on the same body. Immunity also comes from a **true-form** stun. Survivor Defense rule 16 and the States table: Stunned → Immune for `stun_immunity_s` = 6 s, ending early only on a lunge wind-up. Borrowed Face rule 10 forbids starting a transformation only while Stunned, not while Immune.
- Sequence: true-form stun (2 s) → Immune → transform into a disguise (2 s) → about 4 s of immunity left on a body nobody saw shocked. A taser hit now plays a shock with no root or lock. A real survivor who was not shocked in the last 8 s would be rooted and locked. "I shot you, you didn't lock, and nobody shot you before" identifies the monster.
- Before B4 the immune hit applied the R2 lock, so this case was hidden. B4 removed it.
- Options (designer decision):
  - (a) Completing a transformation into a disguise ends immunity, like a lunge wind-up does. A hit on the new disguise then stuns and locks, the same as on a survivor. `lock_share` still holds, since the 2 s transformation sits between the locks.
  - (b) A disguised monster's immunity applies only if its last lock was itself taken while disguised. Otherwise a hit stuns normally.
  - Option (a) is the smaller edit: one clause in Survivor Defense rule 16, plus the States table, a Borrowed Face Edge Case row and one AC.

### Warnings

⚠️ **W1. Survivor Defense rule 11 reads as if a survivor hit inside the post-lock window gets no stagger and no hold cancel** (survivor-defense, survivor-objectives, downing-and-rescue).
- Rule 11: "shocked exactly as a disguised monster is stunned … unless they are inside their post-lock window (rule 14): the same stagger on their body, rooted …". The "unless" clause sits in front of the stagger and the hold cancel, so the clause excludes both.
- Rule 14 says a hit in the window "plays its full presentation", and rule 10 says an immune monster hit "cancels any hold in progress". Survivor Objectives rule 2 and Downing rule 7 say any taser shock cancels a hold.
- If an in-window survivor kept their hold while an immune monster's fake hold was cancelled, that would be a tell.
- Fix: reword rule 11 to say that inside the window the hit still plays the stagger and grunt and still cancels holds; only root, slow and lock are skipped. Add the in-window case to the AC at line 444.

⚠️ **W2. The fuse-install alarm still has no event** (scare-events, survivor-objectives, systems-index). This is the remaining part of the previous W6.
- Scare Events lists Alarm with source "Survivor (fuse install)".
- Survivor Objectives rule 16 makes the install *start* noisy, but `ObjectiveProgressChanged` does not list "install started".
- Say whether the alarm fires on install start or on install completion. If it fires on start, add that to the index event row.

⚠️ **W3. A flinch already running when a wind-up starts is not cut** (scare-events, borrowed-face, monster-abilities).
- New Scare Events rule 14 suppresses any flinch that would *start* within `lunge_cue_radius_m` of a wind-up.
- Every disguised attack runs transform → reveal (Major, flinch) → lunge. A wind-up can start on the tick the form changes, so up to 0.3 s of the reveal flinch still runs into the 0.6 s wind-up.
- Fix: a running flinch ends when a wind-up within `lunge_cue_radius_m` starts. This is one clause in rule 14 plus the AC.

---

## Game Design Issues

### Blocking
None new.

### Warnings
None new. D1 (group cohesion) and D2 (monster attention load) remain open from the previous report.

The post-lock window and rule 2a (any player fires location triggers) both strengthen Human Deception and Counterplay. The B1 case above is the only regression found.

---

## Cross-System Scenario Issues

Scenarios walked: 4
1. True-form stun → disguise → taser test (Survivor Defense, Borrowed Face): **B1**.
2. Eight-hit chain on a survivor holding a fuse install (Survivor Defense, Survivor Objectives): **W1**.
3. Transform → reveal → immediate lunge with ambush test (Borrowed Face, Scare Events, Monster Abilities): **W3**. The ambush scare itself no longer flinches.
4. Disguised monster walks into an authored recording room and then views the C1 monitors (Scare Events rule 2a, Facility Map): consistent. The same scares and gating apply as for a survivor, and the hallucination stays single-client.

### Blockers
🔴 Scenario 1: see B1.

### Warnings
⚠️ Scenario 2: see W1. ⚠️ Scenario 3: see W3.

### Info
ℹ️ Scare Events lists the reveal and "Disguised teammate transforms" as two entries on one `FormChanged` (the previous W9, still open). The new Intensity column marks both Major, so one form change could still fire two Major scares. The second becomes Minor under rule 9 but still plays.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|---|---|---|---|
| survivor-defense.md | B1 immunity carried into a disguise; W1 rule 11 wording | Consistency | Blocking |
| borrowed-face.md | B1 transformation-ends-immunity Edge Case and AC | Consistency | Blocking |
| scare-events.md | W2 alarm trigger; W3 running flinch; previous W9 duplicate reveal entries | Consistency | Warning |
| survivor-objectives.md | W2 install-start event | Consistency | Warning |
| systems-index.md | W2 `ObjectiveProgressChanged` row | Consistency | Warning |

---

## Verdict: FAIL

### Required actions before re-running
1. Designer decides B1, option (a) or (b). Then edit Survivor Defense rule 16 and the States table, Borrowed Face Edge Cases and ACs, and the Survivor Defense ACs.
2. Reword Survivor Defense rule 11 (W1). Add the running-flinch clause to Scare Events rule 14 (W3). Settle the alarm trigger event (W2).
3. Re-run `/design-review` on survivor-defense, monster-abilities and scare-events (all In Review), then `/review-all-gdds since-last-review`.

---

## Resolution (2026-10-12)

- B1: designer chose option (a). Completing a transformation into a disguise ends immunity (Survivor Defense rule 16 and States table, Borrowed Face Edge Cases, ACs in both).
- W1: Survivor Defense rule 11 reworded. Inside the post-lock window the hit still plays the stagger and still cancels holds; only root, slow and lock are skipped.
- W2: designer chose install completion. The alarm fires on the existing `ObjectiveProgressChanged` install event, so the index needs no change.
- W3: Scare Events rule 14 now ends a running flinch when a wind-up starts nearby.
- Borrowed Face goes back to In Review. Next: `/design-review` on survivor-defense, borrowed-face, monster-abilities and scare-events.
