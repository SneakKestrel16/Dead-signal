# Review Log: Match Flow & Win Conditions

Target: `design/gdd/match-flow.md`

## Review — 2026-10-12 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (lean review)
Blocking items: 2 | Recommended: 5
Summary: The round structure, win checks and formulas are complete and implementable. Two rules contradicted sibling GDDs. Evidence-lost and Downed survivors disagreed with Survivor Objectives. Bleed-out during a disconnect disagreed with Downing, Rescue & Elimination. Both were resolved by designer decision and revised in the same session, together with the recommended items.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Core Rules 13: "Evidence lost" counted Downed survivors as inside, but survivor-objectives.md said "no Healthy survivor". Resolved: Downed counts as inside; an all-Downed team waits for bleed-out and ends "All survivors eliminated" (both docs).
- [BLOCKING] Core Rules 19: a disconnected Downed survivor could stall the round, because downing-and-rescue.md froze their state. Resolved: bleed-out keeps running during grace; expiry is Eliminated "Bled out" (both docs).
- [RECOMMENDED] Core Rules 20: "Borrowed Face may restrict whether the disguise is restored" was a hand-wave. Resolved: disguise lost on reconnect, observed list kept (proposed); row added to borrowed-face.md.
- [RECOMMENDED] Core Rules 20: no rule for the deadline passing while the shapeshifter is in grace. Resolved: monster still wins (proposed).
- [RECOMMENDED] Core Rules: no rule for whether an Escaped spectator can ping living players. Resolved: no, the same as Eliminated (proposed).
- [RECOMMENDED] States: the table used literal 120 instead of `infiltration_end_s` and `evac_start_s`, and Infiltration had no exit for an early arm. Fixed.
- [RECOMMENDED] Acceptance Criteria: two criteria were not measurable ("not surprised", "can name the reason"). Rewritten as survey thresholds; 6 criteria added for the new edge cases, the load timeout, an early arm, the post-lock window and a same-tick extraction.
Reviewed-Content-Hash: design/gdd/match-flow.md eae998942ad1a7083acd94a092d73d28a81f5aa6
Reviewed-Content-Hash: design/registry/entities.yaml 882a83438b6118dc29520259d84f868ae97764ae

The hash is for the document as it was reviewed, before the revisions. A re-review therefore sees the revised file as CHANGED and runs in full.
