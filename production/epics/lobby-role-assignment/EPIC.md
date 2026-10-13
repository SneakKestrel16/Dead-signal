# Epic: Lobby & Role Assignment

> **Layer**: Core
> **GDD**: design/gdd/lobby-role-assignment.md
> **Architecture Module**: Lobby & Role Assignment (`docs/architecture/architecture.md` Core layer)
> **Status**: Ready
> **Control Manifest**: 2026-10-13
> **Stories**: Not yet created — run `/create-stories lobby-role-assignment`

## Overview

Brings 4–6 players together by direct join (over Tailscale for MVP, ADR-0001) and starts a round once everyone is Ready. The server validates names, keys each player by a per-session token, runs the Waiting → Countdown → In Match → Closed state machine on its clock, picks the shapeshifter from a shuffled rotation queue and gives each survivor a distinct character. At lock it hands Match Flow the read-only roster. Lobby limits come from data.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Hosting, session join and reconnect | Listen server over ENet direct IP; `auth_callback` join validation; token to player ID; evict-and-rebind reconnect | HIGH |
| ADR-0002: Authoritative simulation, tick and input | Countdown on the server clock (tick-counted timers) | HIGH |
| ADR-0005: Event catalog, state registry and tick order | Roster published as read-only registry state | HIGH |
| ADR-0006: Data-driven configuration | `LobbyKnobs`: min/max players, countdown, name length | MEDIUM |
| ADR-0004: Replication scope and information hiding | No role flag on bodies | HIGH |
| ADR-0014: UI and input focus (Proposed) | Lobby screen focus and input contexts | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-lobby-001 | Listen-server direct join; host leaving closes the session | ADR-0001 (Accepted) |
| TR-lobby-002 | Server validates every join; reject reason sent | ADR-0001 (Accepted) |
| TR-lobby-003 | Display names 1–16 chars, unique by suffix | ADR-0001 (Accepted) |
| TR-lobby-004 | Per-session player token keys queue, preference, reconnect | ADR-0001 (Accepted) |
| TR-lobby-005 | Server-only role assignment from a rotation queue | No ADR needed (pure server logic) |
| TR-lobby-006 | Server-side character assignment, distinct survivors | No ADR needed (pure server logic) |
| TR-lobby-007 | Ready/countdown state machine on the server clock | ADR-0002 (Accepted) |
| TR-lobby-008 | Locked roster handed to Match Flow, read-only | ADR-0005 (Accepted) |
| TR-lobby-009 | Lobby config in a data file | ADR-0006, ADR-0001 (Accepted) |
| TR-lobby-010 | Roles public; no tags or role indicators on bodies | ADR-0004 (Accepted); lobby UI under ADR-0014 (Proposed) |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/lobby-role-assignment.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` — each screen touched for UI, plus a lead sign-off for Visual/Feel

## Next Step

Run `/create-stories lobby-role-assignment` to break this epic into implementable stories.
