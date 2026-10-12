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

## Review — 2026-10-11 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (solo review)
Blocking items: 1 | Recommended: 6
Summary: Fourth review. All prior blockers held. One new blocker: the dodge window assumed a survivor strafes at the instant of the cue, so at 45°/s only a ~0.1 s reaction dodged, and the doc's own 0.3 s "late strafe" was a realistic reaction that got caught. Designer set the target to 0.25 s reaction plus full 150 ms rewind (0.40 s) and chose the wind-up turn rate as the knob. Revised in the same session; index stays In Review.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Formulas, Dodge window / rule 5: dodge only survived ~0.1 s reaction at 45°/s (recomputed: 0.2 s needs ≤37°/s, 0.3 s ≤27°/s, 0.4 s ≤17.5°/s). Resolved: `survivor_reaction_s` target 0.40 s; `lunge_windup_turn_deg_s` 15°/s (safe 0–17); window reworked (18° reach vs ~19.5° needed); AC uses 150 ms latency and a 0.25 s strafe delay.
- [RECOMMENDED] Rule 2: False Signal and Blackout during Lunge wind-up/Active undefined. Resolved: blocked through wind-up, Active and commit (proposed); AC added.
- [RECOMMENDED] Rule 7: survivor collision radius undefined (Controller GDD). Resolved: Formulas states centre-to-centre and the recompute trigger; Open Question added.
- [RECOMMENDED] Acceptance Criteria: rewind cap untested. Resolved: AC for 150/300 ms rewind and current-state eligibility.
- [RECOMMENDED] Edge Cases: monster disconnect mid-lunge missing. Resolved: row added, defers to Match Flow and Downing.
- [RECOMMENDED] Acceptance Criteria: backup switch hold had no AC. Resolved: added to the Blackout AC. Footsteps duration AC not added.
- [RECOMMENDED] Dependencies: Match Flow row was one-way while this doc supplies results stats. Resolved: Bidirectional.
- [NICE-TO-HAVE] Open Questions: Blackout cooldown row marked proposed-at-activation. Dash over ledges or through ineligible survivors not covered. Header date 2026-10-12 left for the date pass.
Reviewed-Content-Hash: design/gdd/monster-abilities.md fb55fcf42fe6b74d589df056b12c85dd4c8a12e7
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97

## Review — 2026-10-11 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (solo review)
Blocking items: 1 | Recommended: 5
Summary: Fifth review. All prior fixes held. One new blocker: the dodge proof tested the dash end, where the survivor is already behind the monster and outside the cone; the real deciding tick is mid-dash on the cone edge (1.30 m at 18°, a 0.1 m margin), and rule 7's front-of-body attack point would have erased that margin. Designer chose centre-measured hits and accepted survivor RTT inside the reaction budget. Revised in the same session; index stays In Review.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Formulas, Dodge window / rule 7: proof used dash-end distance; attack point offset unaccounted (0.3 m forward catches the 0.40 s strafe). Resolved: attack point and cone measured from the monster centre at chest height; window reworked by per-tick stepping (threshold ~19.5°, caught from 0.42 s at 18°).
- [RECOMMENDED] Tuning Knobs: `lunge_hit_radius_m` up to 2.0 and `lunge_cone_deg` up to 90 broke the dodge (limits ~1.29 m, ~72°). Resolved: ranges 0.8–1.25 and 40–70; coupling note added.
- [RECOMMENDED] Formulas: survivor round trip not in the 0.40 s budget (50–100 ms RTT gets caught). Resolved: designer accepted; documented, Open Question for the Network Authority ADR.
- [RECOMMENDED] Rule 6 / Tuning Knobs: dash time, dash steering, `lunge_cue_radius_m`, `blackout_range_m` were literals outside the knob table. Resolved: `lunge_dash_s`, `lunge_dash_turn_deg_s` named; all four added.
- [RECOMMENDED] Rule 7: cone origin unstated. Resolved: same attack point.
- [RECOMMENDED] Formulas: "on the cue needs ~46°" and "0.45 s caught" used the dash-end check. Resolved: recomputed (~47°, ~15°).
- [NICE-TO-HAVE] Header date 2026-10-12 left for the date pass.
Reviewed-Content-Hash: design/gdd/monster-abilities.md 106dadca5c983282ff2fa2c738c22bbf4d3f1a09
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97

## Review — 2026-10-11 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (solo review)
Blocking items: 1 | Recommended: 5
Summary: Sixth review. The lunge dodge proof holds (re-stepped: 1.298 m at 18°, hit from ~19.5°). One new blocker: rule 19 put backup switches "in or near" blackout-able zones while the Facility Map has none in corridors, so which zone a switch restores was undefined. Designer chose own-zone only and dash-stops-at-body. Revised in the same session; index stays In Review.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Rule 19 / Counters: switch-to-zone mapping undefined and contradicted the Facility Map. Resolved: a switch restores only its own zone; corridor Blackouts have no switch; AC updated.
- [RECOMMENDED] Rule 14: Escaped survivors could be impersonated. Resolved: rejected like Eliminated; edge case and AC.
- [RECOMMENDED] Edge Cases: Blackout active in the terminal room when Evacuation starts was missing. Resolved: row deferring to the Facility Map.
- [RECOMMENDED] Rule 6: dash against an ineligible survivor's body undefined. Resolved: designer chose stop at the body, miss with slow; edge case and AC.
- [RECOMMENDED] Dependencies: Pings & Callouts, Borrowed Face, Survivor Defense were one-way. Resolved: Bidirectional here; Borrowed Face and Pings rows mirrored.
- [RECOMMENDED] Acceptance Criteria: footsteps had no AC. Resolved: added to the False Signal AC.
- [NICE-TO-HAVE] Header date 2026-10-12 left for the date pass. Rule 7 stun bullet redundant with rule 12. Blackout reveals the monster within ~15 m; not noted in the doc.
Reviewed-Content-Hash: design/gdd/monster-abilities.md 74af479140e2a2a4188f301293beb05d888fb42e
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97

## Review — 2026-10-11 — Verdict: APPROVED
Scope signal: L
Specialists: none (solo review)
Blocking items: 0 | Recommended: 5
Summary: Seventh review. All prior fixes held and cross-document references (shock lock rule 14, Borrowed Face rules 7 and 11, Pings rules 26-29, Facility Map blackout_able, per-room switches, Downing eligibility) match. No blocking defects; remaining items are implementability notes for the Network Authority and Controller GDDs.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Rule 7 / Formulas: server tick rate is undefined; the dodge proof is continuous (0.5 ms steps) while hits are per tick. Fix: state the tick rate or sweep the dash path between ticks.
- [RECOMMENDED] Rule 6: dash body-block uses current or rewound positions is unstated, and order between a body block and an eligible hit on the same tick is undefined; a hidden survivor's body inside a hiding prop is ambiguous.
- [RECOMMENDED] Rule 15: fake footsteps and interaction sounds need the same replication channel and format as real ones (Pings rule 27 covers callouts only); add an AC like the packet-capture one.
- [RECOMMENDED] Rule 20 / AC: "Blackout on an already-dark zone is rejected" is unreachable in play (6 s duration < 45 s cooldown, one monster); drop it or test by forced state.
- [RECOMMENDED] Formulas: "Fastest lunge cycle after a miss" 10.9 s is not the fastest; a dash blocked at once or a wind-up stun resolves earlier.
- [NICE-TO-HAVE] Header Last Updated 2026-10-12 is later than today; Blackout reveals the monster within ~15 m, not noted.
Reviewed-Content-Hash: design/gdd/monster-abilities.md 09b9230cb70e2a1c3b3623b34b5f58eaab6631c5
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97

## Review — 2026-10-12 (after cross-review B1–B4) — Verdict: APPROVED
Scope signal: L
Specialists: none (lean review, headless)
Blocking items: 0 | Recommended: 0
Summary: The B1–B4 edits (ambush test, Facility Map lighting, False Signal emits no scare, immune hits no longer lock) are consistent with Scare Events, Survivor Defense and the Facility Map. The dodge-window formulas are unchanged and still hold, and Scare Events rule 14 now keeps the flinch out of the wind-up.
Prior verdict resolved: Yes (cross-review changes reviewed)
Findings:
- [NICE-TO-HAVE] Acceptance Criteria: the shock-lock AC lists a lunge from a disguised shapeshifter, which rule 4 always rejects anyway.
- [INFO] Open from cross-reviews: the 200 ms survivor camera impact is defined here and in Downing (W9).
Reviewed-Content-Hash: design/gdd/monster-abilities.md bee9a9cbf03c659ef4f41b5a640cf0c8bfa91c79
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97
