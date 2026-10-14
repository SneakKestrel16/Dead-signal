# Epic: Event Catalog & State Registry

> **Layer**: Foundation
> **GDD**: none (contract defined in `design/gdd/systems-index.md` event table and state table)
> **Architecture Module**: Event Catalog + State Registry (`docs/architecture/architecture.md` Module Ownership)
> **Status**: Ready (governing ADRs Accepted 2026-10-13)
> **Control Manifest**: 2026-10-13
> **Stories**: 6 stories

## Overview

The server-side contract every gameplay system talks through. Fifteen named events are `@abstract ServerEvent` subclasses with one declared emitter each and a `project()` that decides what each peer may see. The `EventBus` is drained after each module phase (at most `max_flush_rounds`), and handlers change only their own module's state. Cross-system reads go through typed, getter-only views in the `StateRegistry`, each key with one owner that replaces collection values whole. A per-round composition root builds the services, injects them through `setup()`, registers modules in the fixed tick order, and clears bus and registry at round end; no gameplay service is an autoload.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Event catalog, state registry and tick order | `ServerEvent` with `type()` / `project()`; bus drained per phase; typed views; fixed feature tick order; composition root, no autoloads | HIGH |
| ADR-0004: Replication scope and information hiding | Event projection table (`project()` returns `{}` = hidden) | HIGH |
| ADR-0008: Hold-to-interact protocol | Holds step between Downing and Objectives in the tick order; HoldService emits no events | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-index-002 | Server-side event bus with 15 named events, each with one emitter, emitted after validation | ADR-0005 (Accepted) |
| TR-index-004 | Cross-system reads only through the state table; single writer per key | ADR-0005 (Accepted) |
| TR-index-010 | No upward layer references; Controller consumes only `RoundEnded` and `PlayerConnectionChanged` | ADR-0005 composition root (Accepted); no build check yet |
| TR-index-011 | One deterministic tick pipeline with defined phase order (hits, downs, objectives, then win check) | ADR-0005, ADR-0008 (Accepted) |
| TR-index-012 | Every system exposes stat and telemetry hooks for Results and Telemetry | ADR-0011 (Proposed) |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [ServerEvent base and the 15-event catalog](story-001-server-event-catalog.md) | Logic | Complete | ADR-0005 |
| 002 | [EventBus emit, subscribe and flush](story-002-event-bus.md) | Logic | Ready | ADR-0005 |
| 003 | [StateRegistry and typed views](story-003-state-registry.md) | Logic | Ready | ADR-0005 |
| 004 | [Composition root and feature tick order](story-004-composition-root-tick-order.md) | Integration | Ready | ADR-0005, ADR-0002, ADR-0008 |
| 005 | [ClientEventRouter](story-005-client-event-router.md) | Integration | Ready | ADR-0005, ADR-0004 |
| 006 | [Layer boundary check](story-006-layer-boundary-check.md) | Logic | Ready | ADR-0005 |

TR-index-012 (stat hooks) is now governed by ADR-0011 (Proposed); each Feature epic gets its own stats story.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria tied to the requirements above are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/`

## Next Step

Run `/create-stories event-catalog-state-registry` to break this epic into implementable stories.
