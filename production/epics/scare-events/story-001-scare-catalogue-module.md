# Story 001: Scare catalogue data and the server Scare module

> **Epic**: Scare Events
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Creates the server Scare Events module at the Scare slot in tick order (after Pings) and the authored scare catalogue as data. Each entry has scare_id, category, source, scope, intensity, audible range, per-phase and per-zone lists and anchors. `EvScareTriggered` already exists (`src/foundation/events/ev_scare_triggered.gd`) but carries only scope and recipient; the client `ScarePresenter` already reads entry keys (flash, flash_s, shake_deg). Knobs exist in `src/foundation/data_config/scare_knobs.gd`.

**GDD**: `design/gdd/scare-events.md` rules 1-3, 8; Formulas
**Requirement**: `TR-scare-001`, `TR-scare-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0004, ADR-0006, ADR-0015
**ADR Decision Summary**: `ScareTriggered` is a server event projected per peer; source and player identity are stripped before any survivor peer sees it. The catalogue is data.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: implement `server_tick(tick)` and register with `TickRunner` after Pings
- Forbidden: never emit an event from a client
- Required: catalogue values come from data, validated at load

---

## Acceptance Criteria

*From GDD `design/gdd/scare-events.md`, scoped to this story:*

- [ ] The scare catalogue loads from a `.tres` resource; an entry missing scare_id, source, scope or intensity is a load problem, not a silent default.
- [ ] `ScareTriggered` carries scare_id, scope, origin and intensity to its recipient; every server-side event has a source of Monster, Survivor or RoundScript, and every Monster or Survivor source names a player.
- [ ] A survivor peer's projection of `ScareTriggered` contains no source and no player identity field.
- [ ] Nothing but the Scare module emits `ScareTriggered`; there is no ambient timer.

---

## Implementation Notes

- Extend `EvScareTriggered` with the missing fields; keep `project()` stripping source and identity.
- Re-pin `SHIPPED_DIGEST` in `tests/integration/data_config/digest_version_test.gd` if a knobs `.tres` changes.

---

## Out of Scope

- Story 002: gating.
- Story 003: recipients.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/scare-events/scare_catalogue_module_test.gd` must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Stories 002-009
