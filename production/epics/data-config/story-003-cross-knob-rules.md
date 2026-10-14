# Story 003: Cross-knob rules

> **Epic**: Data/Config Loader
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] `hold_range_tolerance_m` ≥ `interact_range_m` produces a named error citing ADR-0008.
- [ ] A rewind/interpolation set that breaks the ADR-0003 dodge budget (`max_rewind_ms`, `lunge_windup_s`, interpolation delay) produces a named error citing ADR-0003.
- [ ] Every cross-knob check in the code has a source comment (checked by a test that greps the sections).

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001, Story 002
- Unlocks: None
