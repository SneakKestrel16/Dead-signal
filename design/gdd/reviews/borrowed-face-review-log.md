# Review Log: Borrowed Face

Target: `design/gdd/borrowed-face.md`

## Review — 2026-10-11 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (lean review)
Blocking items: 3 | Recommended: 5
Summary: First review, run after the cross-review blocker fixes in efbdd84 and the Survivor Defense mirror-shock decision. The rules agree with Monster Abilities (Lunge needs True Form), Match Flow rule 20 (disguise lost on reconnect) and Survivor Defense (a stun never reveals a disguise). Three blockers were found: one cross-document signal gap, one missing AC and one stale decision. All were mechanical and were revised in the same session with the recommended items.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Pings & Callouts' state table entered Transforming on "`FormChanged` begins", but `FormChanged` fires only at completion (rule 9). Resolved: rule 8 now names the replicated transforming state (flag, target, start time) as the start signal. The Pings & Callouts Disguised, Transforming and True form rows now use it, including the stun-interrupt exit.
- [BLOCKING] Rule 10, the designer decision that a disguised stun plays the borrowed body and the survivor grunt, had no acceptance criterion. Neither did Survivor Defense rule 10's immune-while-disguised shock. Resolved: ACs added for both, and the Interactions row now says the immune root and slow is not the Stunned state.
- [BLOCKING] The Open Question and Interactions row still treated the "stun test" as undecided. Survivor Defense rule 11 settles it: a shocked survivor looks the same as a stunned disguised monster. Updated.
- [RECOMMENDED] Missing ACs added for: no observation while Stunned; Transforming is walk-only; a disguised monster cannot rescue; reconnect returns in true form with the observed list kept.
- [RECOMMENDED] Formulas covered only completed changes. The stun-interrupt cooldown formula and an example were added.
- [RECOMMENDED] Both Feel ACs were unmeasurable. Rewritten as playtest thresholds (proposed).
- [RECOMMENDED] Scare Events did not cite `reveal_radius_m`. Its Borrowed Face interaction now does.
- [RECOMMENDED] Downing's Open Question on whether the commit forces true form was already settled by the Lunge True Form rule. Marked settled.
- [NICE-TO-HAVE] Systems-index row 8 "Depends On" omitted Survivor Defense, Downing and Facility Map. Added. Header and decision dates of 2026-10-12 are later than this review; they were left as written, and the header now reads 2026-10-11.
Reviewed-Content-Hash: design/gdd/borrowed-face.md b3589907f1289546744f4d11adf4c8cab4564af0
Reviewed-Content-Hash: design/registry/entities.yaml 9a53d370b099be924f289e01bdf96338801d7883

Each hash is for the document as it was reviewed, before that entry's revisions. A re-review therefore sees the revised file as CHANGED and runs in full.

## Review — 2026-10-11 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (lean review)
Blocking items: 1 | Recommended: 5
Summary: Re-review. All three prior blockers held. The one new blocker is a cross-document gap. Survivor Defense rule 1 says which stun event survivor clients get only for the Disguised state. Transforming is a separate state, so a stun while changing out of a disguise had no defined event. The blocker and the recommended items were revised in the same session.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Rule 10: a stun during a transformation had no defined survivor-client event or presentation. Resolved: both follow the body shown, which is the previous form. Mirrored in Survivor Defense rule 1, with an AC added.
- [RECOMMENDED] Header: the header read Approved while the index and the log read Needs Revision. Set to In Review.
- [RECOMMENDED] Edge Cases: an immune hit during a transformation roots the shapeshifter, but rule 8 allows walking. Resolved: the root wins and the change still completes. Edge case and AC added.
- [RECOMMENDED] Rule 2: was observation blocked under the shock lock? Designer decision: yes (one lock for all). Rule 2, the formula and the Interactions row were updated.
- [RECOMMENDED] Acceptance Criteria: added ACs for the edge of the view cone, Downed and disconnected targets, the disguise surviving a target down, and the `FormChanged` payload and reveal trigger.
- [RECOMMENDED] Open Questions: `FormChanged` and the replicated transforming state mark the monster entity. Both were added to the Network ADR question.
- [NICE-TO-HAVE] Dependencies: `design/accessibility-requirements.md` and the Network Authority, Controller and HUD GDDs do not exist yet. These are forward references in design order.
Reviewed-Content-Hash: design/gdd/borrowed-face.md 4920f56b6d26875a3b80148f77b650f0b4cd4810
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97

## Review — 2026-10-11 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (solo review)
Blocking items: 1 | Recommended: 2
Summary: Third review. The prior blocker held: the stun event during a transformation agrees with Survivor Defense rules 1 and 10. The new blocker is an over-broad edge case. It said every immune hit during a transformation roots the shapeshifter, but Survivor Defense rule 10 gives the true form a "resisted" spark with no lock. The blocker and both recommended items were revised in the same session.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Edge Cases, Acceptance Criteria: an immune hit during a transformation out of true form was given the disguised root and lock. Resolved: split into an out-of-disguise row (full shock, lock) and an out-of-true-form row (spark, no lock, walk continues). The AC covers both.
- [RECOMMENDED] Rule 12, tells table: hiding, barricading and searching were real tells (Survivor Defense rules 19, 22, 25 and 26) but went unnamed. Resolved: added to rule 12 and T4.
- [RECOMMENDED] Rule 3: it did not say whether observation continues while Transforming. Resolved: it does.
- [NICE-TO-HAVE] Rule 11 and Open Questions: the 2026-10-12 decision dates are later than this review. Left as written.
Reviewed-Content-Hash: design/gdd/borrowed-face.md f62b3a15e16021633b43d6365def2243e6b0d812
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97
