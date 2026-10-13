# Epic: Facility Map (Research Facility greybox)

> **Layer**: Core
> **GDD**: design/levels/research-facility.md
> **Architecture Module**: Facility Map (`docs/architecture/architecture.md` Core layer)
> **Status**: Ready (geometry, doors, zones and visibility stories are unblocked; lighting and camera-feed stories block on ADR-0009, Proposed)
> **Control Manifest**: 2026-10-13
> **Stories**: Not yet created — run `/create-stories facility-map`

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

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/levels/research-facility.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` — each screen touched for UI, plus a lead sign-off for Visual/Feel

## Next Step

Run `/create-stories facility-map` to break this epic into implementable stories.
