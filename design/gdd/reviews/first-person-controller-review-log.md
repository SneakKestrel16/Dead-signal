# Review Log: First-Person Controller & Interaction

Target: `design/gdd/first-person-controller.md`

## Review — 2026-10-12 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (lean review)
Blocking items: 2 | Recommended: 7
Summary: All required sections are present and the arithmetic in gait, chase-closing, chase-breaker and dodge formulas checks out. Two defects block: the independent safe ranges of walk_speed, sprint_mult and monster_sprint_mult can combine into a lunge-proof sprint (and the "above 1.3" claim is wrong at walk 4.0), and the Holding state is under-specified (crouch while Holding, range re-check when the capsule centre drops). Dependents, the Match Flow back-reference and two sibling GDD numbers still need follow-up.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Formulas, Gait speed / Chase closing: safe ranges are independent, but catch_gap < 2r (never caught) once v_s > 5.44 m/s; walk 4.5 x 1.25 = 5.63 already breaks it, and at walk 4.0 the lunge-proof threshold is sprint_mult 1.36, not 1.3. Needs a derived constraint plus a load-time check, like interact_ray_max.
- [BLOCKING] Core Rule 14 / States table / gait order: Holding is "walk only" but the gait order lets a crouched actor hold at crouch speed; crouching changes capsule centre (0.9 to 0.6) and so the 3D range check mid-hold. Behaviour undefined.
- [RECOMMENDED] Formulas, Dodge window: `slow` is used in dodge_margin but not defined in the variables table.
- [RECOMMENDED] Formulas, Dodge window: depends on Monster Abilities turn rates (`lunge_windup_turn_deg_s`, `lunge_dash_turn_deg_s`) that are not listed as variables, so the simulation cannot be reproduced from this page.
- [RECOMMENDED] Core Rules 13-14: range is checked at exactly `range_m` every tick while walking is allowed, so one tick of server/client drift cancels a hold; add a maintain-range tolerance or hysteresis.
- [RECOMMENDED] Core Rule 12: unclear whether an out-of-range interactable that is first on the ray hides a valid one behind it.
- [RECOMMENDED] Acceptance Criteria: nothing covers `RoundEnded` freeze, the Out state, or the hidden peek exception to Rule 7; performance AC is a placeholder budget.
- [RECOMMENDED] Dependencies: `match-flow.md` does not name this system (known); Network Authority & Replication and Accessibility Options have no GDD yet; Facility Map is `design/levels/research-facility.md`, not a GDD.
- [RECOMMENDED] Monster Abilities still uses 4.5 m/s and radius 0 in its dodge example and AC (known Open Question); rerun there.
- [ADVISORY] Player Fantasy and Tuning Knobs sections absent (advisory at `standard`; knob ranges live in Formulas).
Reviewed-Content-Hash: design/gdd/first-person-controller.md 6c82d88e2342f7bbeb43187c18967e54f3069295
Reviewed-Content-Hash: design/registry/entities.yaml ed63d1fc163b57e5d837b843b54f13b041c4bbcd

## Review — 2026-10-12 — Verdict: APPROVED
Scope signal: L
Specialists: none (lean review)
Blocking items: 0 | Recommended: 5
Summary: Re-review of the revision in 80114dd. Both prior blockers are resolved: the joint cap (max_survivor_sprint_mps 5.4, load-time asserted, with an AC) and the Holding rules (crouch input ignored while Holding, hold_range_tolerance_m 0.25). All prior recommended items about dodge variables, targeting, range hysteresis and missing ACs are also addressed; arithmetic in gait, chase-closing, chase-breaker and dodge formulas re-checked and correct. Remaining items are polish and sibling-GDD follow-ups.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Formulas, Gait speed joint cap: 5.4 is derived at r 0.3 only; never-caught threshold is (5.2 - r)/0.9, which is 5.39 at r 0.35 (inside the allowed radius range), so the cap should be derived from player_radius_m or lowered to 5.3.
- [RECOMMENDED] Formulas variables tables: max_survivor_sprint_mps, hold_range_tolerance_m and intent_timeout_ms live in prose/registry but have no variable rows (range, source, description).
- [RECOMMENDED] Dependencies: match-flow.md still does not name this system (one-directional); Network Authority & Replication and Accessibility Options GDDs do not exist; Facility Map is design/levels/research-facility.md, not a GDD.
- [RECOMMENDED] Monster Abilities lines 138 and 298 still use a 4.5 m/s strafe and radius 0 (already an Open Question; rerun there).
- [RECOMMENDED] Acceptance Criteria: sprint-cone AC at exactly 45 degrees and the cap AC at exactly 5.4 need an explicit epsilon/float tolerance; performance AC remains a placeholder budget.
- [ADVISORY] Player Fantasy and Tuning Knobs sections absent (advisory at standard; knob ranges live in Formulas).
Reviewed-Content-Hash: design/gdd/first-person-controller.md a48c79e03e581064281cf3ed4e4448a75b1aa274
Reviewed-Content-Hash: design/registry/entities.yaml fa7c9a6cc3b62f60c70fc89463f1b5be66d749b3
