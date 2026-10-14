# Story 003: Cross-knob rules

> **Epic**: Data/Config Loader
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 0.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

Unblocked 2026-10-13: ADR-0001..0008 Accepted. 

## Context

Some knobs are only valid relative to others: a hold tolerance must stay below the interaction range, and the lunge dodge budget depends on the rewind cap and interpolation delay. Each section validates its own relations, and `Knobs` validates the ones that span sections.

**GDD**: none (rules cited from the owning GDDs and ADRs)
**Requirement**: `TR-config-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Data-Driven Configuration (Knobs)
**ADR Decision Summary**: Each section's `validate_cross()` and `Knobs.validate_cross()` add errors for broken relations, each check citing its GDD or ADR; errors are collected like range errors.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: None beyond story 001.

**Control Manifest Rules (this layer)**:
- Required: every cross-knob check cites its source GDD or ADR in a comment
- Forbidden: falling back to defaults on a broken rule [knob_default_fallback]
- Guardrail: none specific

---

## Acceptance Criteria

*From ADR-0006 §4 and Validation Criteria, scoped to this story:*

- [x] `hold_range_tolerance_m` ≥ `interact_range_m` produces a named error citing ADR-0008.
- [x] A rewind/interpolation set that breaks the ADR-0003 dodge budget (`max_rewind_ms`, `lunge_windup_s`, interpolation delay) produces a named error citing ADR-0003.
- [x] Every cross-knob check in the code has a source comment (checked by a test that greps the sections).

---

## Implementation Notes

*Derived from ADR-0006 Decision and Implementation Guidelines:*

- `validate_cross() -> PackedStringArray` per section returns `[]` when valid; `Knobs.validate_cross()` covers rules spanning sections.
- Collect the rule list from the GDDs' Formulas and Edge Cases sections and ADR-0003/0008; each rule cites its source.
- The dodge-budget rule: `survivor_reaction_s` 0.43 s with a 27 ms measured margin at `accel_time_s` 0.05 (ADR-0003 Verification results (4)); encode the inequality, not the margin.

---

## Out of Scope

- Story 004: what happens to the host when errors exist

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-002-2026-10-13.md` (/qa-plan, 2026-10-13). Implement against these and the Acceptance Criteria above.*

**What to test**:
- `hold_range_tolerance_m` >= `interact_range_m` gives a named error that cites ADR-0008; strictly less passes.
- A rewind and interpolation set that breaks the ADR-0003 dodge budget (`max_rewind_ms`, `lunge_windup_s`, interpolation delay) gives a named error that cites ADR-0003; a set at the boundary passes.
- Source-comment guard: the test reads the cross-knob check source and fails if any check has no source comment.

**Edge cases to cover**:
- Equal values (the boundary is exclusive or inclusive exactly as the ADR states).
- An unset (NaN) knob reports the unset error, not a cross-knob error.
- Two rules broken at once produce two errors.

**Estimated test count**: ~7 unit tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/data_config/cross_knob_rules_test.gd` — must exist and pass

**Status**: [x] `tests/unit/data_config/cross_knob_rules_test.gd` passes (10 tests); 3 mutations caught; suite 163/163; review fixes add citation checks (2026-10-14)

---

## Dependencies

- Depends on: Story 001, Story 002
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-10-14
**Criteria**: 3/3 passing in `tests/unit/data_config/cross_knob_rules_test.gd`
- AC1: `test_hold_tolerance_at_or_above_interact_range_is_named_error_citing_adr_0008` (equal fails, +1 mm passes). Under the shipped ranges (tolerance 0.1-0.4, range 1.5-2.3) the rule cannot fire; it guards future range changes. The strict bound is ADR-0006 §4's example; ADR-0008 itself gives only `range_m + tolerance`.
- AC2: `test_rewind_not_covering_interpolation_plus_tick_...` (66 ms fails, 67 passes) and `test_reaction_reaching_windup_breaks_dodge_budget_...` (equal fails; the story's "boundary passes" read as just past the bound). The dodge rule is a necessary condition only (inference, AD-74).
- AC3: `test_every_cross_check_has_a_source_comment` (the comment must name an ADR or GDD; commented-out checks ignored; count pinned at 7).
**Deviations** (advisory): AD-74: rule set and inference; extra section rules (net, scare) beyond the two named ACs. Cross rules run only when no section has a load, range or unset error (story wording; per-rule gating considered, not done).
**Test Evidence**: Logic: `tests/unit/data_config/cross_knob_rules_test.gd`, 10 tests; 3 mutations caught.
**Run result**: N/A: no screen; load-time validation only (the boot scene's "0 problems" line still reads from errors()).
**Code Review**: Complete: `/code-review` 2026-10-14, APPROVED WITH SUGGESTIONS; applied: citation check in the guard, exact unset assertion, section rule through errors(), two-rule citations, shadowed name, clearer dodge error text.
