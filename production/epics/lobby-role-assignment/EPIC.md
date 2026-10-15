# Epic: Lobby & Role Assignment

> **Layer**: Core
> **GDD**: design/gdd/lobby-role-assignment.md
> **Architecture Module**: Lobby & Role Assignment (`docs/architecture/architecture.md` Core layer)
> **Status**: Ready
> **Control Manifest**: 2026-10-13
> **Stories**: 12 stories (10 Ready, 2 Blocked on Proposed ADR-0014); 001–006 phase M1, 007–012 post-M1

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

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Ready and countdown state machine](story-001-ready-countdown-state-machine.md) | Logic | Ready | ADR-0002 |
| 002 | [Roster lock, Match Flow hand-off and return to Waiting](story-002-roster-lock-handoff.md) | Integration | Ready | ADR-0005, ADR-0002 |
| 003 | [Character data and M1 character assignment](story-003-character-data-m1-assignment.md) | Logic | Ready | ADR-0006 |
| 004 | [Host session setting: proximity voice](story-004-proximity-voice-setting.md) | Integration | Complete | ADR-0001 |
| 005 | [Lobby screen: player list, Ready and countdown](story-005-lobby-screen.md) | UI | Ready | ADR-0014 (Proposed), ADR-0001 |
| 006 | [No name tags or role indicators on bodies](story-006-no-role-indicators.md) | Visual/Feel | In Review | ADR-0004 |
| 007 | [Shapeshifter rotation queue (post-M1)](story-007-rotation-queue.md) | Logic | Ready | N/A |
| 008 | [Queue positions for absent, reconnecting and new players (post-M1)](story-008-queue-absent-reconnect.md) | Logic | Complete | ADR-0001 |
| 009 | [Character preferences and clash resolution (post-M1)](story-009-character-preferences.md) | Logic | Complete | N/A |
| 010 | [Clash fairness and preference changes while Ready (post-M1)](story-010-clash-fairness-preference-lock.md) | Logic | Complete | N/A |
| 011 | [Host kick (post-M1)](story-011-host-kick.md) | Logic | Complete | ADR-0001 |
| 012 | [Lobby queue order and preference display (post-M1)](story-012-queue-order-display.md) | UI | In Review | ADR-0014 |

Covered elsewhere: AC-LB-02/03/04 join validation (network-authority story 001), AC-LB-28/29 disconnect and host left (network-authority story 003).

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/lobby-role-assignment.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` — each screen touched for UI, plus a lead sign-off for Visual/Feel

## Next Step

Run `/story-readiness` on a story, then `/dev-story`. Start with Story 001.
