# Story 001: Knob sections, range and unset validation

> **Epic**: Data/Config Loader
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

Unblocked 2026-10-13: ADR-0001..0008 Accepted. 

## Context

The core of the loader: a typed `Resource` per system whose fields cannot ship with a code default, and a `Knobs` service that loads the sections, checks every field against its `@export_range` and against the unset sentinels, and collects all errors instead of stopping at the first.

**GDD**: none (epic input: every GDD's Tuning Knobs section)
**Requirement**: `TR-config-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Data-Driven Configuration (Knobs)
**ADR Decision Summary**: Typed `<System>Knobs` Resources with `@export_range` fields defaulting to `NAN` / `KnobUnset.INT`; `Knobs.load_all()` validates range (from the hint string) and unset values and collects every error.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Verification results (1) PASS: the range hint string is `"min,max"` (int fields also report floats); (3) a `NAN` field is written as `= nan` and loads as NAN. Load with `ResourceLoader.CACHE_MODE_IGNORE` (result (2) PASS).

**Control Manifest Rules (this layer)**:
- Required: every GDD tuning knob is an `@export_range` field in its owning section, defaulting to `NAN` or `KnobUnset.INT`
- Forbidden: tuning literal in gameplay code [tuning_literal_in_code]; falling back to defaults [knob_default_fallback]
- Guardrail: knob load and validation under 10 ms per boot (inference)

---

## Acceptance Criteria

*From ADR-0006 §1, §2, §4, §6 and Validation Criteria, scoped to this story:*

- [ ] A section built with `.new()` and every field set inside its range validates with `errors()` empty.
- [ ] A float field left at `NAN` or an int field left at `KnobUnset.INT` produces a named error ("<section>.<field> unset"); a value outside the `@export_range` produces a named error with the value and range.
- [ ] Three bad fields in one section produce three errors, not one.
- [ ] `Knobs.ticks(seconds)` returns `roundi(seconds * net.sim_tick_hz)` (e.g. 0.5 s at 60 Hz = 30).

---

## Implementation Notes

*Derived from ADR-0006 Decision and Implementation Guidelines:*

- `KnobUnset` is a standalone `class_name` holding `const INT := -2147483648`, so sections never reference `Knobs` (no cyclic class reference).
- Each section is `class_name <System>Knobs extends Resource`; field names are the GDD names unchanged; the range is the GDD's Safe Range, written once in `@export_range`.
- The range check reads `PROPERTY_HINT_RANGE` from `get_property_list()`, `split(",")`, first two entries; ignore trailing flags such as `or_greater`. Only properties with `PROPERTY_USAGE_SCRIPT_VARIABLE`.
- `load_all()` never returns a partial set; callers read `errors()` (`PackedStringArray`, `[]` = valid).
- Unit tests build sections with `.new()` and set fields directly; no file I/O in unit tests.
- Use `NetKnobs` plus one gameplay section (e.g. `DefenseKnobs` from the ADR example) to prove the pattern; the full section list is story 002.

---

## Out of Scope

- Story 002: every section and the shipped `.tres` files
- Story 003: cross-knob rules
- Story 004: refusing to host, round freeze
- Story 005: digest and version string

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-001-2026-10-12.md` (/qa-plan, 2026-10-12). Implement against these and the Acceptance Criteria above.*

**What to test**:
- A `.new()` section with every field in range: `errors()` empty.
- Float field left `NAN` → error names `<section>.<field>` as unset; int field left `KnobUnset.INT` → same.
- Value below min and above max → error names value and range, read from the `@export_range` hint.
- Three bad fields → three errors.
- `Knobs.ticks(0.5)` at `sim_tick_hz` 60 → 30; `ticks(0.0)` → 0.

**Edge cases to cover**:
- Value exactly at min and exactly at max: valid.
- Int field hint reported as floats (`"1.0,3.0"`, Verification result 1).
- Hint string with trailing `or_greater` flag: only first two entries used.

**Estimated test count**: ~8 unit tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/data_config/knob_section_validation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Stories 002, 003, 004, 005
