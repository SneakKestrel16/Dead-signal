# Story 004: Install alert to the shapeshifter

> **Epic**: Survivor Objectives
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

Starting a fuse install alerts the shapeshifter to the general area: an offset circle that always contains the box, sent to the shapeshifter's client only.

**GDD**: `design/gdd/survivor-objectives.md`
**Requirement**: `TR-objectives-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding; secondary: ADR-0005
**ADR Decision Summary**: Per-peer handles and relevance; a peer receives only what it may know; dropped and carried items replicate through the projection, never with identity leaks.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Seeded `RandomNumberGenerator` for the offset; no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: run in the `SURVIVOR_OBJECTIVES` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel`; fake holds take no lock, change no progress and never call the owner (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never let `HoldService` emit events; never emit an event from a client; never decide discovery from a client report, proximity alone or room entry (ADR-0005, ADR-0008, ADR-0012)
- Guardrail: every `duration_s` and `range_m` comes from `ObjectivesKnobs` (`data/knobs/objectives.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-objectives.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [x] When an install starts the shapeshifter's client alone receives an area marker of radius `alert_area_radius_m` lasting `alert_duration_s`, whose circle contains the box (rule 16, Formulas "Install alert placement").
- [x] With a fixed seed, in at least 90% of 50 tests the circle's centre is more than 1 m from the box.
- [x] A cancelled and restarted install raises a new alert; a fake install raises none (rules 16, 26).
- [x] Every value this story uses is read from `ObjectivesKnobs`, not hardcoded.

---

## Implementation Notes

- `alert_centre = box + random_point_in_disc(alert_area_radius_m)` with the injected seeded RNG; keep it a static helper for the unit test.
- Deliver the marker through the existing per-peer projection (NA-9) so no survivor peer receives it. The install sound's send radius (`install_noise_radius_m`) uses NA-9's sound projection; playback is presentation (ADR-0013, Proposed) and out of scope.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Audio playback of the install sound (ADR-0013, Proposed)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/integration/survivor-objectives/install_alert_test.gd` — must exist and pass

**Status**: [x] `tests/integration/survivor-objectives/install_alert_test.gd` (6 tests)

---

## Dependencies

- Depends on: Story 003
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: all passing (automated)
**Deviations** (AD-146):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 748/748 after the wave merge, no leak warnings.
- `ObjectiveProgressChanged` gains `alert_centre`, `alert_radius_m`, `alert_duration_s`; with a radius it projects only to the monster and omits the box id.
- New `FuseState.INSTALLING` (last); Match Flow ignores it.
- `rng` and `emit_sound` are public, not yet wired into a live round.
- Merge: resolved a doc-comment conflict with SO-2.
**Test Evidence**: 6 tests. Mutations caught: monster-only check removed, zero offset, offset beyond radius, on_start not raising the alert.
**Code Review**: Complete (orchestrator review at merge)
