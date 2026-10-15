# Story 008: HoldService: Start, contested locks and completion

> **Epic**: First-Person Controller & Interaction
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

Every hold in the game runs through one server service. This story builds Start validation, locks and timing; owners only register interactables and receive callbacks.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Hold-to-interact protocol
**ADR Decision Summary**: `HoldService` (Core, injected via `setup()`) is the only hold timer; `InputFrame` carries `interact`, `interact_target`, `target_is_body`; target read only on the rising edge; `Holds` tick step between `Downing` and `SurvivorObjectives`, players in rotated order: stop/cancel, checks, Start (eligibility, strict `range_m`, LOS, lock), advance; instant interactables complete at once with no lock; owners get `on_start`, `on_complete`, `on_cancel` and emit their own events.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: 4.5 `@abstract` on `Interactable`. Verification (1): a `void` override needs no `return`; a typed override missing a branch `return` fails to compile. Verification (3) NOT RUN until `HoldService` exists — this story runs it.

**Control Manifest Rules (this layer)**:
- Required: only `HoldService` times holds; owners keep stored progress between holds
- Required: decide contested hold locks by ADR-0007's rotated player order
- Required: run `HoldService.server_tick` only inside TickRunner's physics phases
- Required: every `Interactable` override restates the parent's return type, `void` included
- Forbidden: counting hold progress in an owner [owner_timed_hold]; accepting a client completion or progress message [client_hold_complete]

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Hold-to-interact) and ADR-0008 Validation Criteria, scoped to this story:*

- [x] A Start is rejected, and the client bar cancels, when the actor is ineligible (shocked, hidden, Downed, wrong role), line of sight is blocked, or another actor holds the exclusive lock.
- [x] Two Starts on one exclusive target in one tick: the first in rotated player order is accepted and the second rejected (ADR-0008 Verification 3).
- [x] Stop arriving before acceptance: the hold is accepted and cancelled on that tick with progress 0.
- [x] With `duration_s` D held continuously, completion fires once on the first server tick where elapsed ≥ D (±1 tick); `duration_s` 0 completes on the Start tick and takes no lock.

---

## Implementation Notes

*Derived from ADR-0008 Decision §1–4 and Key Interfaces:*

- Test with stub `Interactable` subclasses that log callbacks; no owner epic is needed.
- Elapsed counts in ticks via `Knobs.ticks`; `start_progress_s()` seeds elapsed for keep rules.
- Body targets resolve through the requesting peer's handle table (network-authority story 008); stub it.

---

## Out of Scope

- Story 009: continuation checks and cancels
- Story 010: fake holds

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-004-2026-10-14.md` (/qa-plan, 2026-10-14). Implement against these and the Acceptance Criteria above.*

**Test file path**: `tests/integration/first-person-controller/hold_service_start_test.gd`
**What to test**:
- Start rejected (and the client bar cancels) when the actor is shocked, hidden, Downed or the wrong role; when line of sight is blocked; when another actor holds the exclusive lock.
- Two Starts on one exclusive target in one tick: the first in rotated player order wins (ADR-0008 Verification 3).
- Stop arriving before acceptance: accepted and cancelled on that tick, progress 0.
- `duration_s` D held: completion fires once on the first tick with elapsed ≥ D (±1 tick); `duration_s` 0 completes on the Start tick with no lock.

**Edge cases to cover**:
- Target net id out of range or -1 rejected.
- A Start from a client-claimed view direction uses the server's (CI-7 targeting).

**Estimated test count**: ~8 integration tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/first-person-controller/hold_service_start_test.gd` — must exist and pass

**Status**: [x] Created, 23 tests passing (suite 388/388)

---

## Dependencies

- Depends on: Story 007; event-catalog story 004 (tick order); network-authority story 005 (input frames)
- Unlocks: Stories 009, 010, 016; every owner epic with an interaction

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: 4/4 passing (`tests/integration/first-person-controller/hold_service_start_test.gd`, 23 tests). Every rule was also checked by mutation (20 mutations, each caught by a named test, run with gdUnit `-c` so fail-fast cannot hide a later test).
**ADR-0008 Verification**: (1) PASS: a `void` override with no `return` compiles (`Stub.on_start`). (3) PASS: two Starts on one lock in one tick go to the first actor in rotated order, on even and odd ticks.
**Deviations**:
- `HoldService.new(knobs, players, frames, centre_of, sight, aim, body_target)` takes Callables, not the ADR's `setup(tick_runner, map, bodies, knobs)`. `BodyIndex` does not exist yet, and Callables keep the service unit-testable (ADR-0005 §6). On the server, `sight` is the new `MapQueries.clear_line`, `aim` is `MapQueries.interactable_on_ray` with `ViewState.server_dir`, and `frames` is the new `ServerMovement.frames_of`.
- Net-id Starts are checked against the server's own view ray (GDD rule 10 and the AC "resolves against the server's ray"). ADR-0008 §3 only says the client sends the target, so the two do not conflict.
- A held exclusive lock also rejects an instant interactable on the same key (AC1). The ADR says only that instants take no lock.
- A press, release and press in one tick start on the last press.
**Not wired yet**: no composition root registers HoldService at `TickOrder.HOLDS`. It is registered when the first owner epic adds an interactable.
**Deferred**:
- Body targets resolve through the handle table, but are not yet checked against the server ray. The Downing epic adds the body aim check.
- Dynamic interactables (a Dropped drive) are not in the map's ray list, so the aim check would reject them. They must join the aim query when the objectives epic adds them.
- An `on_start` that unregisters an instant interactable still gets `on_complete` (S4, re-entrancy). Owners must not unregister from `on_start`.
