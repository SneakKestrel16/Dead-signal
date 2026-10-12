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

## Review — 2026-10-11 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (lean review)
Blocking items: 2 | Recommended: 5
Summary: Re-review. The prior blocker and both recommended items held. Two new blockers: the doc never emitted `AbilityUsed`, which the systems-index event table, Scare Events and Pings & Callouts all expect from it, and the wind-up turn rate was unspecified while the dodge-window math assumed no turning. Both, plus all five recommended items, were revised in the same session; index set to In Review.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Core Rules: `AbilityUsed` never emitted (cross-review second re-review note). Resolved: rule 3a defines emission and payload; AC added.
- [BLOCKING] Rule 5 / Formulas: "turn at reduced rate" had no value, and the dodge window ignored turning (~20°/s plus dash steering defeated the stated dodge). Resolved: designer chose `lunge_windup_turn_deg_s` = 45°/s (safe 0–60); dodge window reworked (36° reachable vs ~48° needed at 3 m); knob, variable and AC added.
- [RECOMMENDED] Formulas: hit check used `state == Healthy`, missing hidden, grace and commit exclusions. Resolved: `is_valid_takedown_target` per Downing rule 3; grace AC added.
- [RECOMMENDED] Rule 7: attack point undefined. Resolved: front of collision body at chest height (proposed).
- [RECOMMENDED] Rule 15: fake-sound hearing range undefined. Resolved: the imitated asset's audible range.
- [RECOMMENDED] States: "Active → Cooldown" contradicted cooldown-on-activation. Resolved: reworded as overlapping.
- [RECOMMENDED] Acceptance Criteria: no AC for closest-target, False Signal range/wall rejection, Blackout `blackout_able`/already-dark rejection. Resolved: added.
- [NICE-TO-HAVE] Edge case "Downed by another cause" named an impossible cause; animation table listed 90 recovery frames for a movement slow. Resolved both. Header dates of 2026-10-12 left for the project-wide date pass.
Reviewed-Content-Hash: design/gdd/monster-abilities.md f99d03c7bfb3867537488c3be5fe682f0f6bd047
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97
