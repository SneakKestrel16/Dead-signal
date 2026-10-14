# Story 002: All knob sections and the shipped files

> **Epic**: Data/Config Loader
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-13

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

- [x] A test asserts every knob name in every GDD's Tuning Knobs table has a field in its owning section (and ADR-only knobs in `NetKnobs`, `CoreKnobs`, `FacilityKnobs`).
- [x] An integration test loads the shipped files and gets `errors()` empty.
- [x] The export preset includes `data/knobs/*`; an exported Windows build loads every section by its `res://` path.

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

**Status**: [x] `tests/integration/data_config/shipped_knobs_test.gd` — 8 tests; suite 25/25 pass (2026-10-13)

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 003

---

## Completion Notes
**Completed**: 2026-10-13
**Criteria**: 3/3 closed with noted gaps (designer chose close-with-debt)
- AC1 met for every GDD Tuning Knobs table (136 knobs, 13 sections). Not met for 15 ADR-only knobs with no sourced number (TD-001, TD-002).
- AC2 met: `Knobs.load_all()` on the shipped files gives `errors()` empty.
- AC3 verified in a scratch Windows export (13 sections load from the .pck, errors empty; negative check without the filter fails). No `export_presets.cfg` in the repo (gitignored), so only the README documents it (TD-004).
**Deviations** (advisory): `intent_timeout_ms`, `hold_range_tolerance_m`, `interact_ray_max_m` live in ControllerKnobs and `max_rewind_ms` in AbilityKnobs (one home per knob, GDD owner); several knobs ship a value with no sourced range (plain `@export`: unset still caught); `eye_height_m`, `capsule_height_m` have no field (two values each, names undecided); lobby ships its Default 4–6 players, not the MVP 5/5; shipped values are not compared with the GDD (TD-003).
**Test Evidence**: Integration: `tests/integration/data_config/shipped_knobs_test.gd`; coverage test mutation-checked (deleted `rescue_decay_rate`, test failed); empty-array check watched failing.
**Code Review**: Complete (godot-gdscript-specialist and qa-tester, 2026-10-13); fixes in 8fcecdc.
**Tech debt**: TD-001..TD-004 in `docs/tech-debt-register.md`.
