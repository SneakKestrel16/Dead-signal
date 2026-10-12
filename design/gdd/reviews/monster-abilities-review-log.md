# Review Log: Monster Abilities

Target: `design/gdd/monster-abilities.md`

## Review — 2026-10-11 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (solo review)
Blocking items: 1 | Recommended: 3
Summary: First review. All five standard sections are present, and the lunge timeline, stun interrupt, shock lock and Blackout zone flags agree with Downing, Survivor Defense, Borrowed Face and the Facility Map. The one blocker is the miss-slow transform conflict from the cross-review. It and two recommended items were revised in the same session.
Prior verdict resolved: First review
Findings:
- [BLOCKING] States table, Cooldown row: "may transform once any miss slow has ended" conflicted with Borrowed Face rule 7, which has no miss-slow block. Resolved: the row defers to Borrowed Face rule 7 (the approved owner), so miss slow does not block a transformation. AC added.
- [RECOMMENDED] Acceptance Criteria: "hears it from the correct direction" was not measurable. Resolved: bearing within ±15° (proposed tolerance), matching Borrowed Face.
- [RECOMMENDED] Acceptance Criteria: the lunge-while-Disguised rejection did not cite its playtest-gated source. Resolved: cites Borrowed Face rule 11.
- [RECOMMENDED] Open Questions: whether False Signal can fake an Eliminated survivor is still open, and Pings & Callouts defers it here. Not changed: designer decision, due before Milestone 3.
- [NICE-TO-HAVE] Dependencies: the Network Authority, Controller and HUD GDDs do not exist yet. These are forward references in design order. The header date of 2026-10-12 is later than this review; left for the project-wide date pass.
Reviewed-Content-Hash: design/gdd/monster-abilities.md 2e90a91a3876a39852bfbfae405e297b01e50a19
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97

Each hash is for the document as it was reviewed, before that entry's revisions. A re-review therefore sees the revised file as CHANGED and runs in full.
