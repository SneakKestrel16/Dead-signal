# Epic: Downing, Rescue & Elimination

> **Layer**: Feature
> **GDD**: design/gdd/downing-and-rescue.md
> **Architecture Module**: Downing, Rescue & Elimination (`docs/architecture/architecture.md` Feature layer)
> **Status**: Ready
> **Control Manifest**: 2026-10-13
> **Stories**: Not yet created — run `/create-stories downing-and-rescue`

## Overview

This system decides what happens to a survivor when the shapeshifter lands a takedown. The server holds each survivor's life state (Healthy, Seized, Downed, Eliminated) and `downs_taken`. A `SurvivorHit` starts a 1.5-second takedown commit, which a stun cancels. The first completed takedown downs the survivor; the second eliminates them. A downed survivor crawls at a quarter speed and bleeds out over 60 seconds. The timer pauses during a rescue and slows while another player is near. Teammates rescue with a six-second hold whose progress persists and decays. Grace windows after a rescue or release make a survivor ineligible for a new takedown. The system emits `SurvivorDowned`, `SurvivorRescued` and `SurvivorEliminated`, and eliminated survivors become spectators through Match Flow. The trigger, `SurvivorHit`, comes from Monster Abilities, which has no epic yet; this epic's tests drive it directly.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Hosting, session join and reconnect | Disconnected survivors keep bleeding out | HIGH |
| ADR-0004: Replication scope and information hiding | Life state per peer; spectator hand-off | HIGH |
| ADR-0005: Event catalog, state registry and tick order | Life state and takedown eligibility in the registry; down, rescue and eliminate events | HIGH |
| ADR-0006: Data-driven configuration | `DowningKnobs` (already in `src/foundation/data_config/downing_knobs.gd`) | MEDIUM |
| ADR-0007: Movement, physics and collision layers | Downed crawl speed and rooting through the controller modifier stack | HIGH |
| ADR-0008: Hold-to-interact protocol | Rescue hold (6 s, range 1.5, both rooted) | HIGH |

## GDD Requirements

ADR coverage below is mapped by domain: these ADRs do not list TR-IDs by name (inference; `/create-stories` settles it per story). At `workflow: standard` only the Foundation ADRs (0001–0008, all Accepted) are expected; rows on a Proposed ADR are informational and their stories block until it is accepted.

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-downing-001 | Server-held life state, downs_taken, timers, rescue progress | ADR-0005 (Accepted) |
| TR-downing-002 | Takedown commit (1.5 s) from SurvivorHit; a stun cancels it | ADR-0005 (Accepted) |
| TR-downing-003 | Grace windows publish ineligibility | ADR-0005 (Accepted) |
| TR-downing-004 | Bleed-out timer (60 s), paused by rescue, slowed nearby | ADR-0005 (Accepted) |
| TR-downing-005 | Rescue as a hold with persisting, decaying progress | ADR-0008 (Accepted) |
| TR-downing-006 | Downed state: crawl 0.25x, restricted actions | ADR-0007 (Accepted) |
| TR-downing-007 | Emits SurvivorDowned/Rescued/Eliminated; eliminated become spectators | ADR-0005, ADR-0004 (Accepted) |
| TR-downing-008 | Disconnected players keep bleeding out | ADR-0001 (Accepted) |
| TR-downing-009 | Tuning knobs are data; downs_to_eliminate fixed at 2 | ADR-0006 (Accepted) |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/downing-and-rescue.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` — each screen touched for UI, plus a lead sign-off for Visual/Feel

## Next Step

Run `/create-stories downing-and-rescue` to break this epic into implementable stories.
