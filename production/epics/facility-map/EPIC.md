# Epic: Facility Map (Research Facility greybox)

> **Layer**: Core
> **GDD**: design/levels/research-facility.md
> **Architecture Module**: Facility Map (`docs/architecture/architecture.md` Core layer)
> **Status**: Ready (geometry, doors, zones and visibility stories are unblocked; lighting and camera-feed stories block on ADR-0009, Proposed)
> **Control Manifest**: 2026-10-13
> **Stories**: 12 stories (6 Ready, 6 Blocked on Proposed ADR-0009/0012/0013)

## Overview

The one hand-authored 60 × 40 m Research Facility greybox, loaded whole. It provides geometry within the controller's limits (doorways at least 0.8 m, ramp colliders, large box floors), doors with swing areas, authored candidate points, terminal and exit volumes, hiding points, LOS blockers, the per-volume visibility table that ADR-0004 relevance reads, lighting volumes and their state machine, surveillance cameras and zone ambience.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0007: Movement, physics and collision layers | Geometry and collision authoring limits, layers, analytic zones and doors | HIGH |
| ADR-0004: Replication scope and information hiding | Visibility sets from the map's per-volume table; hidden candidate entities | HIGH |
| ADR-0012: Objective discovery (Proposed) | Candidate points and seeded selection | HIGH |
| ADR-0009: Lighting states and Blackout (Proposed) | Per-volume lighting state machine, reset, camera feeds | HIGH |
| ADR-0013: Spatial audio pipeline (Proposed) | Zone ambience; B3 footstep masking | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-facility-001 | One hand-authored level loaded whole | architecture.md init only (no ADR needed) |
| TR-facility-002 | Geometry limits gameplay depends on | ADR-0007 (Accepted) |
| TR-facility-003 | Server owns candidates, door state, lighting state | ADR-0004 §7 (Accepted); ADR-0009 (Proposed) |
| TR-facility-004 | Per-volume lighting state machine with precedence | ADR-0009 (Proposed) |
| TR-facility-005 | Rendering concerns: rack lanes, glass partitions | ADR-0009 Verification (Proposed) |
| TR-facility-006 | Surveillance: 4 cameras at the C1 monitor | ADR-0009 §8 (Proposed) |
| TR-facility-007 | LOS blockers authored | ADR-0007 (Accepted) |
| TR-facility-008 | Zone-based audio | ADR-0013 (Proposed) |
| TR-facility-009 | Terminal zone and exit volume | ADR-0007 (Accepted) |
| TR-facility-010 | Reduced-flash variants of beacons and lights | ADR-0009 §6 (Proposed) |
| TR-facility-011 | Per-volume visibility table | ADR-0004 (Accepted); table authored 2026-10-13 in the level doc |
| TR-facility-012 | Collision authoring limits (ramps, box floors) | ADR-0007 (Accepted) |

Lighting, camera-feed, zone-audio and reduced-flash requirements rest on ADR-0009 and ADR-0013 (Proposed); their stories will be Blocked until those are accepted.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Facility map data and whole-level load](story-001-map-data-loader.md) | Integration | Ready | ADR-0007 |
| 002 | [Greybox geometry and collision authoring](story-002-greybox-geometry-collision.md) | Integration | Ready | ADR-0007 |
| 003 | [Connectivity checks: no sealed rooms, no single choke](story-003-connectivity-checks.md) | Logic | Ready | N/A |
| 004 | [Analytic zones, terminal zone and exit gating](story-004-analytic-zones-exit.md) | Integration | Complete | ADR-0007, ADR-0004 |
| 005 | [Per-volume visibility table for relevance](story-005-visibility-table.md) | Integration | Ready | ADR-0004 |
| 006 | [Traversal budget walk-through](story-006-traversal-budget.md) | Integration | Complete | ADR-0007 |
| 007 | [Candidate point selection and placement constraints](story-007-candidate-selection.md) | Logic | Complete | ADR-0012 (Proposed) |
| 008 | [Candidate replication and discovery agreement](story-008-candidate-replication.md) | Integration | Ready | ADR-0012 (Proposed), ADR-0004 |
| 009 | [Per-volume lighting state machine and precedence](story-009-lighting-state-machine.md) | Logic | Complete | ADR-0009 (Proposed) |
| 010 | [Lighting replication, Blackout scope and reduced flash](story-010-lighting-render-blackout.md) | Visual/Feel | Ready | ADR-0009 (Proposed) |
| 011 | [Surveillance cameras at the C1 monitor](story-011-surveillance-cameras.md) | Visual/Feel | Ready | ADR-0009 (Proposed) |
| 012 | [Zone ambience and B3 footstep masking](story-012-zone-ambience.md) | Visual/Feel | Ready | ADR-0013 (Proposed) |

Grouping playtest AC 11 belongs to Match Telemetry.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/levels/research-facility.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` — each screen touched for UI, plus a lead sign-off for Visual/Feel

## Next Step

Run `/story-readiness` on a story, then `/dev-story`. Start with Story 001.
