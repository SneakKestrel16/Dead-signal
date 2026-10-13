# Story 002: All knob sections and the shipped files

> **Epic**: Data/Config Loader
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

Unblocked 2026-10-13: ADR-0001..0008 Accepted. 

## Context

Every tuning knob in the GDDs becomes a field in its owning section, with its value in a `.tres` file under `res://data/knobs/`. Two tests keep it honest: one proves every GDD knob name has a field, one loads the shipped files and expects no errors. The export preset must carry the files, because no scene references them.

**GDD**: none (inputs: the Tuning Knobs sections of all 10 system GDDs)
**Requirement**: `TR-config-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Data-Driven Configuration (Knobs)
**ADR Decision Summary**: One `.tres` per section in `res://data/knobs/<section>.tres`, loaded by a fixed name list (never by enumerating the folder); sections `ControllerKnobs`, `LobbyKnobs`, `MatchFlowKnobs`, `ObjectivesKnobs`, `DowningKnobs`, `DefenseKnobs`, `BorrowedFaceKnobs`, `AbilityKnobs`, `PingKnobs`, `ScareKnobs`, `NetKnobs`, `CoreKnobs`, `FacilityKnobs`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Verification results (3): in a Windows export the files load by their `res://` path through `.remap`, values and NAN intact. (5) a misspelled key loads silently and leaves the real field unset, so the unset check catches typos.

**Control Manifest Rules (this layer)**:
- Required: load knob files only from `res://data/knobs/`
- Forbidden: loading `.tres`/`.res` from `user://` or a player-supplied path [user_path_resource_load]
- Guardrail: knob load and validation under 10 ms per boot (inference)

---

## Acceptance Criteria

*From ADR-0006 §1, §3 and Validation Criteria, scoped to this story:*

- [ ] A test asserts every knob name in every GDD's Tuning Knobs table has a field in its owning section (and ADR-only knobs in `NetKnobs`, `CoreKnobs`, `FacilityKnobs`).
- [ ] An integration test loads the shipped files and gets `errors()` empty.
- [ ] The export preset includes `data/knobs/*`; an exported Windows build loads every section by its `res://` path.

---

## Implementation Notes

*Derived from ADR-0006 Decision and Implementation Guidelines:*

- A knob lives only in its owning GDD's section; other systems read it there (e.g. `interact_range_m` is in `ObjectivesKnobs`; `blackout_duration_s`, `backup_switch_hold_s` in `AbilityKnobs`).
- `FacilityKnobs` holds `light_fade_s`, `max_flashes_per_s`, `max_shadowed_omni`, `max_shadowed_spot`, `feed_resolution` (ADR-0006 §1 amendment, AD-35).
- `Knobs` loads a fixed list of section names; never enumerate `res://data/knobs/` (export converts `.tres` to binary with `.remap` entries).
- Values with "(proposed)" in a GDD ship as proposed; the GDD stays the source of the number.
- The GDD-name coverage test parses the GDD Tuning Knobs tables; if that needs file I/O, it is an integration test, not a unit test.

---

## Out of Scope

- Story 001: the section pattern and range/unset checks
- Story 003: cross-knob rules

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-001-2026-10-12.md` (/qa-plan, 2026-10-12). Implement against these and the Acceptance Criteria above.*

**What to test**:
- Every knob name in each GDD Tuning Knobs table has a field in its owning section; ADR-only knobs in `NetKnobs`, `CoreKnobs`, `FacilityKnobs`.
- `Knobs.load_all()` on the shipped files → `errors()` empty.
- A copy with one misspelled key loads without a fatal error and reports the real field unset.

**Edge cases to cover**:
- A GDD knob marked "(proposed)" still needs a field.
- No file is loaded from outside `res://data/knobs/` (assert the loaded paths).

**Estimated test count**: ~4 integration tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/data_config/shipped_knobs_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 003
