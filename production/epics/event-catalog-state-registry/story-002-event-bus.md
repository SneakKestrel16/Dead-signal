# Story 002: EventBus emit, subscribe and flush

> **Epic**: Event Catalog & State Registry
> **Status**: In Progress
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-13

Unblocked 2026-10-13: ADR-0001..0008 Accepted. 

## Context

The bus queues server events and drains them at defined points so that cause and effect resolve on the same tick in a known order. Handlers that emit join the same drain; a runaway cascade is caught.

**GDD**: none
**Requirement**: `TR-index-002`, `TR-index-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event Catalog, State Registry and Tick Order
**ADR Decision Summary**: `emit` appends to a queue (server only); `subscribe` adds a named-method `Callable` to a `Dictionary[StringName, Array]`; `flush` delivers in subscribe order over a copy of the list, skipping invalid callables, with handler-emitted events joining the same drain, up to `max_flush_rounds` = 8; every delivered event is collected for per-peer projection.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification results (6): `Dictionary[StringName, Array[Callable]]` does not parse; use `Dictionary[StringName, Array]` and cast on read. (3): `Callable.is_valid()` is false after the bound Node is freed. (4): a named-method `Callable` does not keep its `RefCounted` alive.

**Control Manifest Rules (this layer)**:
- Required: handlers are named methods and change only their own module's state; `max_flush_rounds` from data
- Forbidden: lambdas as handlers; Godot signals as the bus or synchronous dispatch
- Guardrail: up to 9 flushes per tick, negligible against the 2 ms server tick

---

## Acceptance Criteria

*From ADR-0005 §2–3 and Validation Criteria, scoped to this story:*

- [ ] Two subscribers to one type receive an event in subscribe order; a subscriber whose object was freed is skipped without error.
- [ ] An event emitted by a handler during `flush()` is delivered in the same flush.
- [ ] A cascade that needs more than `max_flush_rounds` rounds asserts in debug (test asserts the assert/log path at round 9).
- [ ] `take_tick_events()` returns every event delivered since the last call, in delivery order; `clear()` empties queue, subscribers and collected events.

---

## Implementation Notes

*Derived from ADR-0005 Decision and Implementation Guidelines:*

- Iterate over a copy of the handler list so a handler that subscribes or unsubscribes mid-flush does not change this delivery.
- `max_flush_rounds` reads from `CoreKnobs` (ADR-0006); in unit tests set it on a `.new()` section.
- `emit` is server only; the client path is story 005.

---

## Out of Scope

- Story 004: when `flush()` is called in the tick

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-001-2026-10-12.md` (/qa-plan, 2026-10-12). Implement against these and the Acceptance Criteria above.*

**What to test**:
- Two subscribers receive in subscribe order.
- A handler that emits during `flush()`: the new event is delivered in the same flush.
- `take_tick_events()` returns delivered events in order and resets.
- `clear()` empties queue, subscribers and collected events.

**Edge cases to cover**:
- Subscriber freed before flush → skipped, no error.
- Handler subscribes another handler mid-flush → not called for the current event (iteration over a copy).
- Cascade needing 9 rounds with `max_flush_rounds` 8 → assert/log path taken.

**Estimated test count**: ~7 unit tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/event_catalog/event_bus_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001; data-config Story 001 (`CoreKnobs`)
- Unlocks: Story 004
