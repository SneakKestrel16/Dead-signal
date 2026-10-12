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

## Review — 2026-10-11 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (solo review)
Blocking items: 1 | Recommended: 6
Summary: Third review. Both prior blockers held. One new blocker: when the hit check runs, and what a hit does to the dash, were undefined, so a programmer had to guess and the 12.4 s cycle quietly assumed the dash stopped on a hit. It and all recommended items were revised in the same session; index stays In Review.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Rules 7–8 / Formulas: hit-check cadence and dash-on-hit undefined. Resolved: designer chose every server tick of Active; first tick with a valid target hits the closest one, and the hit ends the dash.
- [RECOMMENDED] Rule 3a: `AbilityUsed` carries monster position with no replication scope (radar risk, like cross-review R1). Resolved: server-internal; AC added.
- [RECOMMENDED] Acceptance Criteria: the two feel ACs and "values read from data" were not measurable. Resolved: survey thresholds (proposed 80%, 0 "from nowhere") and a data-change/no-literal check.
- [RECOMMENDED] Acceptance Criteria: the 4.5 m/s strafe speed belongs to the Controller GDD, which does not exist yet. Resolved: `survivor_move_speed`, 4.5 kept as example.
- [RECOMMENDED] Acceptance Criteria: missing ACs for hidden target, dash steering, stun during dash, abilities while Disguised, independent cooldowns, flashlights under Blackout. Resolved: added.
- [RECOMMENDED] Impact Moments: hit-stop could be read as an input lock. Resolved: presentation-only.
- [RECOMMENDED] Rule 7: rewound positions vs "hit checks current state" ambiguous. Resolved: positions rewound, eligibility and stun current.
- [NICE-TO-HAVE] Formulas: late-strafe claim unworked. Resolved: 0.3 s strafe caught by a 25° dash (1.19 m). Survivor Defense open question on stun-cancelled cooldown marked settled by rule 12. Header date 2026-10-12 left for the date pass.
Reviewed-Content-Hash: design/gdd/monster-abilities.md a17b1c6ea2f52caae3e0ec22180f3aba1808d69b
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97
