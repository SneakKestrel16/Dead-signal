# Story 001: Scare catalogue data and the server Scare module

> **Epic**: Scare Events
> **Status**: Complete
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

- [x] The scare catalogue loads from a `.tres` resource; an entry missing scare_id, source, scope or intensity is a load problem, not a silent default.
- [x] `ScareTriggered` carries scare_id, scope, origin and intensity to its recipient; every server-side event has a source of Monster, Survivor or RoundScript, and every Monster or Survivor source names a player.
- [x] A survivor peer's projection of `ScareTriggered` contains no source and no player identity field.
- [x] Nothing but the Scare module emits `ScareTriggered`; there is no ambient timer.

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

**Status**: [x] `tests/unit/scare-events/scare_catalogue_module_test.gd` (8 cases); `tests/integration/network/event_projection_test.gd`

---

## Dependencies

- Depends on: None
- Unlocks: Stories 002-009

## Progress Notes (2026-10-15)

Merged from wt-se1. Full suite 1301/1301, no leak lines. Mutations caught: source-equals-entry check skipped, `source` added to the projection, intensity-missing check skipped.

Deviations (inference):
- `fire(scare_id, origin, recipients, source, player)` refuses, emitting nothing, on an unknown id, a source that differs from the entry, a Monster or Survivor source with no player, no recipients, or a single-client scare without exactly one recipient (rule 20).
- One source per entry: the fuse alarm and the recording each have a Survivor and a RoundScript entry (`alarm_fuse`/`alarm_evacuation`, `recording_room`/`recording_script`); recordings fire once per round.
- Every audible range and flash or shake value in `data/scare_events/scare_catalogue.tres` is a placeholder; the GDD gives no numbers. Story 003 and the M4 horror pass settle them.
- The monster's own peer gets the same stripped projection as a survivor.
- Not done: `round_client.gd` still gives `ScarePresenter` an empty catalog; wiring `ScareCatalogue.load_shipped().presenter_catalog()` is left for stories 008/009.
