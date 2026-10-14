# Epic: Network Authority & Replication

> **Layer**: Foundation
> **GDD**: none (system #10 is defined by its ADRs; requirements from `design/gdd/systems-index.md` and `design/gdd/lobby-role-assignment.md`)
> **Architecture Module**: Network Authority & Replication (`docs/architecture/architecture.md` Module Ownership)
> **Status**: Ready (governing ADRs Accepted 2026-10-13)
> **Control Manifest**: 2026-10-13
> **Stories**: 10 stories

## Overview

The authoritative server that every rule depends on. It hosts a listen-server session over ENet with direct IP join, validates every join in `auth_callback`, issues reconnect tokens keyed to stable player IDs, and runs the 60 Hz `TickRunner` that dequeues per-player input frames, steps movement, records rewind history, runs feature modules in order and sends per-peer snapshots. Owners predict and reconcile their own movement; remote players render 50 ms behind with lag-compensated hit tests. Replication is scoped per peer: bodies travel only as handle-named snapshot entries, events reach clients only through their projection, and per-peer visibility hides what a role must never receive. The server role must also run headless with no local player.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Hosting, session join and reconnect | Listen server with separable server role; ENet direct IP; `auth_callback` join validation; token to player ID; evict-and-rebind reconnect | HIGH |
| ADR-0002: Authoritative simulation, tick and input | One server tick at 60 Hz; TickRunner phases; unreliable last-3 input frames; adaptive input queue; owner-only prediction and reconciliation | HIGH |
| ADR-0003: Lag compensation and rewind | 50 ms interpolation; client-reported `view_tick` clamped by server RTT and 180 ms cap; 16-tick history; analytic hit tests | HIGH |
| ADR-0004: Replication scope and information hiding | Per-peer snapshots under opaque per-peer handles; authored room PVS + 6 m + 0.5 s linger; event projection; hidden non-body entities | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-index-001 | Server authoritative for attacks, stuns, cooldowns, objectives, downing, rescue, results; clients send intent only | ADR-0002, ADR-0005 (Accepted) |
| TR-index-003 | Event replication scoped per event, not broadcast | ADR-0004 (Accepted) |
| TR-index-005 | Shapeshifter form and Transforming flag are server-owned replicated state | ADR-0004 (Accepted) |
| TR-index-006 | Per-player state rows read across systems (life state, eligibility, hidden, lunge, commit, stun, roster, positions) | ADR-0004, ADR-0005 (Accepted) |
| TR-config-004 | PC first; 4–6 players, MVP 5; ~9 min rounds; no AI actors | ADR-0001, ADR-0002 (Accepted) |
| TR-lobby-001 | Listen-server direct join over ENet; no matchmaking, no host migration | ADR-0001 (Accepted) |
| TR-lobby-002 | Server validates every join (full, in progress except reconnect, version) and sends the reason | ADR-0001 (Accepted) |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Host, join and join validation](story-001-host-join-auth.md) | Integration | Ready | ADR-0001 |
| 002 | [Session tokens and reconnect rebinding](story-002-tokens-reconnect.md) | Integration | Ready | ADR-0001 |
| 003 | [Disconnect detection and host leaving](story-003-disconnect-host-left.md) | Integration | Ready | ADR-0001 |
| 004 | [TickRunner and the server clock](story-004-tick-runner.md) | Logic | Complete | ADR-0002 |
| 005 | [Input frames and the server input queue](story-005-input-frames-queue.md) | Logic | Complete | ADR-0002 |
| 006 | [Snapshots, owner prediction and reconciliation](story-006-snapshots-prediction.md) | Integration | Ready | ADR-0002, ADR-0007 |
| 007 | [Rewind history and lag compensation](story-007-rewind-lag-compensation.md) | Logic | Ready | ADR-0003 |
| 008 | [Per-peer handles and relevance](story-008-handles-relevance.md) | Integration | Ready | ADR-0004 |
| 009 | [Event projection batches and positional sounds](story-009-event-projection-sounds.md) | Integration | Ready | ADR-0004, ADR-0005 |
| 010 | [Hidden entities, RPC paths, spectators and reconnect re-issue](story-010-hidden-entities-spectators.md) | Integration | Ready | ADR-0004 |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria tied to the requirements above are verified, including the real-network list in `prototypes/networking-spike/README.md`
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/`

## Next Step

Run `/create-stories network-authority` to break this epic into implementable stories.
