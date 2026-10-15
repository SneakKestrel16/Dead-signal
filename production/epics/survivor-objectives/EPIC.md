# Epic: Survivor Objectives

> **Layer**: Feature
> **GDD**: design/gdd/survivor-objectives.md
> **Architecture Module**: Survivor Objectives (`docs/architecture/architecture.md` Feature layer)
> **Status**: Ready (point-selection and discovery stories block on ADR-0012, install noise on ADR-0013, HUD display on ADR-0014; all Proposed)
> **Control Manifest**: 2026-10-13
> **Stories**: 10 stories (8 Ready, 2 Blocked on Proposed ADR-0012)

## Overview

Survivor Objectives is the survivors' task chain. Survivors recover two data drives from secured rooms, find and install two fuses at the Zone B fuse boxes, activate the Zone C terminal and hold the area for its 15-second countdown, then carry both drives out through the exit. The server picks the active points each round from the authored candidate sets and owns every piece of objective state: drive and fuse item states, carriers, discovery, and the terminal state machine. Every interaction is a server-completed hold (ADR-0008). The shapeshifter can fake interactions that change nothing. The single outward event is `ObjectiveProgressChanged`. Extraction, a Healthy carrier entering the exit after activation, is what Match Flow's survivor win reads.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Replication scope and information hiding | Discovery and carried-drive visibility per peer; install-noise relevance | HIGH |
| ADR-0005: Event catalog, state registry and tick order | `ObjectiveProgressChanged`; objective and terminal state in the registry; Objectives slot in tick order | HIGH |
| ADR-0006: Data-driven configuration | `ObjectivesKnobs` (timings, counts) | MEDIUM |
| ADR-0008: Hold-to-interact protocol | Extract, pickup, dock, install and activation holds; fake interactions as gate checks | HIGH |
| ADR-0012: Objective discovery (Proposed) | Active point selection and discovery tracking | LOW |
| ADR-0013: Spatial audio pipeline (Proposed) | Install noise for all within 25 m | MEDIUM |
| ADR-0014: UI and input focus (Proposed) | Carried-drive HUD display | MEDIUM |

## GDD Requirements

ADR coverage below is mapped by domain: these ADRs do not list TR-IDs by name (inference; `/create-stories` settles it per story). At `workflow: standard` only the Foundation ADRs (0001–0008, all Accepted) are expected; rows on a Proposed ADR are informational and their stories block until it is accepted.

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-objectives-001 | All objective interactions are server-completed holds | ADR-0008 (Accepted) |
| TR-objectives-002 | Server picks active points from authored candidate sets | ADR-0012 (Proposed) |
| TR-objectives-003 | Discovery visible to all survivors once any survivor sees it | ADR-0012 (Proposed), ADR-0004 (Accepted) |
| TR-objectives-004 | Item model for drives and fuses | ADR-0005 (Accepted) |
| TR-objectives-005 | Terminal state machine with activation countdown | ADR-0005 (Accepted) |
| TR-objectives-006 | Extraction rule; win needs both drives Extracted | ADR-0005 (Accepted) |
| TR-objectives-007 | Shapeshifter fake interactions change no state | ADR-0008 (Accepted) |
| TR-objectives-008 | Install noise within 25 m plus monster-only alert marker | ADR-0004 (Accepted); ADR-0013 (Proposed) |
| TR-objectives-009 | ObjectiveProgressChanged is the single outward event | ADR-0005 (Accepted) |
| TR-objectives-010 | All timings and counts are data; candidates authored in the map | ADR-0006 (Accepted) |
| TR-objectives-011 | Carried drive visible on the carrier model and survivor HUDs | ADR-0004 (Accepted); ADR-0014 (Proposed) |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Drive extract and carry](story-001-drive-extract-and-carry.md) | Integration | Ready | ADR-0008 |
| 002 | [Item drops and pickups](story-002-drops-and-pickups.md) | Integration | Ready | ADR-0005 |
| 003 | [Fuses, fuse boxes and power restored](story-003-fuses-and-power.md) | Integration | Ready | ADR-0008 |
| 004 | [Install alert to the shapeshifter](story-004-install-alert.md) | Logic | Ready | ADR-0004 |
| 005 | [Docking and the evacuation terminal](story-005-docking-and-terminal.md) | Logic | Ready | ADR-0005 |
| 006 | [Drive extraction at the exit](story-006-extraction.md) | Integration | Ready | ADR-0005 |
| 007 | [Shapeshifter fake interactions](story-007-shapeshifter-fake-interactions.md) | Integration | Ready | ADR-0008 |
| 008 | [Active point selection](story-008-active-point-selection.md) | Logic | Blocked | ADR-0012 |
| 009 | [Objective discovery](story-009-discovery.md) | Integration | Blocked | ADR-0012 |
| 010 | [Objective state replication to clients](story-010-objective-state-replication.md) | Integration | Ready | ADR-0004 |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/survivor-objectives.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` — each screen touched for UI, plus a lead sign-off for Visual/Feel

## Next Step

Run `/story-readiness production/epics/survivor-objectives/story-001-drive-extract-and-carry.md`, then `/dev-story`.
