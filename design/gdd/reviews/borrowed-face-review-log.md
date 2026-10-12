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
