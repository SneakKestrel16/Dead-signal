# Story 004: Composition root and feature tick order

> **Epic**: Event Catalog & State Registry
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-13

Unblocked 2026-10-13: ADR-0001..0008 Accepted. Also needs the network-authority TickRunner story.

## Context

One round-server node builds every service and module, injects them, registers modules in the fixed order and tears everything down at round end. With stub modules, this story proves the order and the flush after each step, and that nothing leaks between rounds.

**GDD**: none
**Requirement**: `TR-index-011`, `TR-index-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event Catalog, State Registry and Tick Order; secondary ADR-0002 (TickRunner phase 4), ADR-0008 (Holds step)
**ADR Decision Summary**: Phase 4 runs MatchFlow.begin, SurvivorDefense, BorrowedFace, MonsterAbilities, FacilityMap, Downing, Holds, SurvivorObjectives, PingsCallouts, ScareEvents, MatchFlow.resolve, each followed by `bus.flush()`; the composition root constructs services and modules, passes them through `setup()`, and calls `bus.clear()` and `registry.clear()` at round end.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification results (4): module and view form a cycle until `registry.clear()`; the bus does not.

**Control Manifest Rules (this layer)**:
- Required: modules receive services through `setup()`; the root clears bus and registry at round end; rules run only from TickRunner phases
- Forbidden: gameplay autoload services [gameplay_autoload_service]; rules in a module's own `_physics_process` [rules_in_own_physics_process]
- Guardrail: server tick max 2.0 ms

---

## Acceptance Criteria

*From ADR-0005 §4, §6 and Validation Criteria, scoped to this story:*

- [x] With stub modules that log calls, one tick runs `server_tick` in the documented order with a `flush()` after each step.
- [x] An event emitted by a stub in step 2 is handled before step 3 runs.
- [x] After round teardown, no module, view or service is still alive and no orphan nodes remain (gdUnit4 orphan count 0).
- [x] No gameplay service is registered as an autoload in `project.godot`.

---

## Implementation Notes

*Derived from ADR-0005 Decision and Implementation Guidelines:*

- `setup(tick_runner, bus, registry, knobs)` on every module; modules subscribe and register views there.
- Register with `TickRunner.register_feature(module, phase_order)`; the order constants live in one file.
- Teardown: `bus.clear()`, `registry.clear()`, drop module references.
- Same-tick rule tests (stun beats transform, hit then stun, extraction on deadline) belong to the Feature epics that own those modules.

---

## Out of Scope

- network-authority epic: `TickRunner` itself (ADR-0002)
- Feature epics: real modules and the same-tick rule tests

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-001-2026-10-12.md` (/qa-plan, 2026-10-12). Implement against these and the Acceptance Criteria above.*

**What to test**:
- Stub modules log calls; one tick runs them in the ADR-0005 order with a flush after each.
- An event emitted in step 2 is handled before step 3 runs.
- After teardown: no live module, view or service; gdUnit4 orphan count 0.
- `project.godot` has no gameplay autoloads.

**Edge cases to cover**:
- A stub that registers out of order is still run by `phase_order`, not registration order.

**Estimated test count**: ~4 integration tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/event_catalog/tick_order_test.gd` — must exist and pass

**Status**: [x] `tests/integration/event_catalog/tick_order_test.gd` — 6 tests; suite 103/103 pass, 0 orphans (2026-10-13)

---

## Dependencies

- Depends on: Stories 002, 003; network-authority TickRunner story; data-config Story 001
- Unlocks: Story 006

---

## Completion Notes
**Completed**: 2026-10-13
**Criteria**: 4/4 passing, each covered by a gdUnit4 integration test (6 tests, 0 failures, 0 orphans)
**Deviations** (advisory):
- The flush after each step comes from a `FeatureStep` wrapper (module `server_tick` then `bus.flush()`); `TickRunner` is unchanged, so phase 5 adds one more flush at the end of phase 4.
- `TickOrder` slots are 100–900 with gaps (4a = 450, 5a = 550).
- `RoundServer.start_round(modules, knobs)` takes the modules from the caller keyed by `TickOrder` slot; it creates no Feature modules itself. `end_round()` clears bus and registry, frees the `TickRunner` child and drops module references.
- The autoload rule flags ANY `[autoload]` entry (no allowlist yet).
- `NetAuthority` is not built by the root yet (network-authority stories 001–003).
**Test Evidence**: Integration: `tests/integration/event_catalog/tick_order_test.gd`; WeakRefs of runner, bus, registry, 11 stub modules and 11 views are freed after teardown. Mutation-checked: flush removed from `FeatureStep`, `registry.clear()` replaced by `pass`, `tick_runner.free()` removed, two `TickOrder` constants swapped: each failed.
**Code Review**: Skipped (lean mode). `round_server.gd` and `feature_step.gd` read in full by the orchestrator; no specialist or QA review ran.
