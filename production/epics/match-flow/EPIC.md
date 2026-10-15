# Epic: Match Flow & Win Conditions

> **Layer**: Feature
> **GDD**: design/gdd/match-flow.md
> **Architecture Module**: Match Flow (`docs/architecture/architecture.md` Feature layer)
> **Status**: Ready (results stories block on ADR-0011, Proposed)
> **Control Manifest**: 2026-10-13
> **Stories**: 12 stories, see the Stories table below

## Overview

Match Flow runs one round of about nine minutes. It takes the 4–6 players that Lobby & Role Assignment hands over, waits for every client to load, spawns them, and runs the server-only 540-second clock through Infiltration, Investigation and Evacuation. It evaluates the win conditions once per tick and on relevant events in a fixed order (evidence escaped, all survivors eliminated, deadline), locks the outcome, and sends `RoundEnded` carrying the results payload. It owns the mid-round disconnect grace, the spectator hand-off for eliminated and escaped players, and the return to the lobby with all round state reset. Clients only display the phase and clock the server replicates. This epic is the critical path to a playable round (milestone-01 exit; gate check 2026-10-14).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Hosting, session join and reconnect | Listen server; reconnect grace; host leaving ends the session with no result | HIGH |
| ADR-0002: Authoritative sim tick and input | Server tick drives the clock and phase | HIGH |
| ADR-0004: Replication scope and information hiding | Spectator streams; full state on reconnect | HIGH |
| ADR-0005: Event catalog, state registry and tick order | `RoundPhaseChanged`, `RoundEnded`, `SurvivorEscaped`, `PlayerConnectionChanged`; begin and resolve slots in tick order; round teardown | HIGH |
| ADR-0006: Data-driven configuration | `MatchFlowKnobs` with load-time validation | MEDIUM |
| ADR-0011: Round stats and results payload (Proposed) | `*StatsView` getters read once at resolve into `RoundResults` | LOW |

## GDD Requirements

ADR coverage below is mapped by domain: these ADRs do not list TR-IDs by name (inference; `/create-stories` settles it per story). At `workflow: standard` only the Foundation ADRs (0001–0008, all Accepted) are expected; rows on a Proposed ADR are informational and their stories block until it is accepted.

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-matchflow-001 | Server-only round clock and phase state machine | ADR-0002, ADR-0005 (Accepted) |
| TR-matchflow-002 | Round parameters from data with load-time validation | ADR-0006 (Accepted) |
| TR-matchflow-003 | Loading barrier (60 s) before spawning at S1–S5 / M1–M3 | ADR-0001, ADR-0005 (Accepted) |
| TR-matchflow-004 | Win evaluation in fixed priority order, on events and each tick | ADR-0005 (Accepted) |
| TR-matchflow-005 | Survivor disconnect drops items; 60 s grace; respawn on reconnect | ADR-0001 (Accepted) |
| TR-matchflow-006 | Reconnecting client receives full current state | ADR-0004, ADR-0001 (Accepted) |
| TR-matchflow-007 | Emits PlayerConnectionChanged, SurvivorEscaped, RoundEnded | ADR-0005 (Accepted) |
| TR-matchflow-008 | Results payload aggregates stats from other systems | ADR-0011 (Proposed) |
| TR-matchflow-009 | Spectator mode for Eliminated and Escaped players | ADR-0004 (Accepted) |
| TR-matchflow-010 | Host leaving closes the session; no result | ADR-0001 (Accepted) |
| TR-matchflow-011 | Return to lobby; all gameplay state reset per round | ADR-0005 (Accepted) |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Round clock and phase state machine](story-001-round-clock-phases.md) | Logic | Complete | ADR-0005 |
| 002 | [Win evaluation order and immediate endings](story-002-win-evaluation.md) | Logic | Complete | ADR-0005 |
| 003 | [Escape, evidence extraction and outcome lock](story-003-escape-and-outcome-lock.md) | Logic | Complete | ADR-0005 |
| 004 | [Loading barrier, spawn, round end and return to lobby](story-004-round-lifecycle.md) | Integration | Complete | ADR-0005 |
| 005 | [Survivor disconnect, grace and reconnect](story-005-survivor-disconnect-grace.md) | Integration | Complete | ADR-0001 |
| 006 | [Shapeshifter disconnect and forfeit](story-006-shapeshifter-disconnect-forfeit.md) | Integration | Complete | ADR-0001 |
| 007 | [Spectators and full state on reconnect](story-007-spectators-and-reconnect-state.md) | Integration | Complete | ADR-0004 |
| 008 | [Results payload](story-008-results-payload.md) | Logic | Complete | ADR-0011 |
| 009 | [Clients display server phase and outcome only](story-009-client-display-authority.md) | Integration | Complete | ADR-0005 |
| 010 | [Round composer (server composition root)](story-010-round-composer.md) | Integration | Ready | ADR-0005 |
| 011 | [Client round scene](story-011-client-round-scene.md) | Integration | Ready | ADR-0002 |
| 012 | [Display state catch-up on rejoin](story-012-display-catch-up-on-rejoin.md) | Integration | Complete | ADR-0004 |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/match-flow.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` — each screen touched for UI, plus a lead sign-off for Visual/Feel

## Next Step

Run `/story-readiness production/epics/match-flow/story-001-round-clock-phases.md`, then `/dev-story`.
