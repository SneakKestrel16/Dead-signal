# Story 007: Life state replication and information hiding

> **Epic**: Downing, Rescue & Elimination
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Every client sees the same life states and down counts; the shapeshifter never learns bleed-out timers, and a slowed ring looks the same whoever caused it.

**GDD**: `design/gdd/downing-and-rescue.md`
**Requirement**: `TR-downing-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding; secondary: ADR-0005
**ADR Decision Summary**: Per-peer projection; a peer receives only what it may know (the shapeshifter gets no bleed-out state).
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Real ENet on loopback; extend NA-9's capture test.

**Control Manifest Rules (this layer)**:
- Required: run in the `DOWNING` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel` (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never emit an event from a client; never let `HoldService` emit events (ADR-0005, ADR-0008)
- Guardrail: every timer, range and multiplier comes from `DowningKnobs` (`data/knobs/downing.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/downing-and-rescue.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [x] With 5 clients connected, all 5 show the same life state and down count for every survivor after each hit, commit, rescue and elimination, within 250 ms of the server event.
- [x] The shapeshifter's client receives no bleed-out timer or ring state for any Downed survivor, in true form or disguised; the ring is identical on survivor clients whether a survivor or the monster slows it.
- [x] A client sending a forged "rescue complete" or "survivor downed" message causes no state change.
- [x] Every value this story uses is read from `DowningKnobs`, not hardcoded.

---

## Implementation Notes

- Project the events through NA-9's projection table (bleed-out state survivor-only, AD-107); Eliminated survivors become spectators through Match Flow story 007.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- HUD epic: the Downed marker and ring presentation
- Monster Abilities epic: lunge cooldown after resolution (GDD AC on `lunge_cooldown_s`)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/downing-and-rescue/life_state_replication_test.gd` OR playtest doc

**Status**: [x] `tests/integration/downing-and-rescue/life_state_replication_test.gd` (4 tests)

---

## Dependencies

- Depends on: Stories 001, 003, 004
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-163):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 880/880 after the wave merge, no leak warnings.
- Real ENet, 5 clients: hit, commit, rescue, elimination reach all displays within 250 ms; monster capture has no ring.
- Seized not shown on the roster (body presentation in the snapshot, not built). Downing does not feed catch_up yet: a mid-round reconnect misses earlier ring and life-state changes.
- Forged client batches log `bytes_to_var` ERR_INVALID_DATA twice (expected; counted malformed).
**Test Evidence**: 4 tests. Mutations caught: ring to every viewer, no down on 'Taken down', ring every tick, batch extras dropped.
**Code Review**: Complete (orchestrator review at merge)
