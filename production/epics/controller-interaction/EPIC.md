# Epic: First-Person Controller & Interaction

> **Layer**: Core
> **GDD**: design/gdd/first-person-controller.md
> **Architecture Module**: First-Person Controller & Interaction, incl. HoldService (`docs/architecture/architecture.md` Core layer)
> **Status**: Ready
> **Control Manifest**: 2026-10-13
> **Stories**: 16 stories (14 Ready, 2 Blocked on Proposed ADRs)

## Overview

The body, view and interaction layer every player shares. The server moves each player's Jolt `CharacterBody3D` capsule through the shared movement step from input frames, in four gaits (walk, sprint, crouch, crawl), and applies the most restrictive of the locks, roots and slows other systems request. The client predicts and replays its own body. The server keeps each player's view direction (client yaw/pitch plus the sanctioned view offset), targets interactables by ray, and runs every hold-to-interact through one `HoldService` with contested locks. Doors are instant interactions whose close is rejected while a capsule overlaps the swing area. Input bindings are `InputMap` actions; footsteps follow the replicated gait.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0007: Movement, physics and collision layers | Jolt `CharacterBody3D` per player, capsule 0.3/1.8 m, ramp colliders, collision layers and masks, rotated move order, analytic doors and interactables, KB+M actions | HIGH |
| ADR-0008: Hold-to-interact protocol | `HoldService` times all holds; interact bit + target in the input frame; contested lock by rotated order; owners get on_start/on_complete/on_cancel | HIGH |
| ADR-0002: Authoritative simulation, tick and input | 60 Hz server tick, input frames, server input buffer, prediction and replay, correction smoothing, view direction | HIGH |
| ADR-0006: Data-driven configuration | Gait speeds, ranges, timeouts from `ControllerKnobs` | MEDIUM |
| ADR-0015: Scare presentation and view offset (Proposed) | Flinch record and view-offset epoch; client-only camera effects | MEDIUM |
| ADR-0013: Spatial audio pipeline (Proposed) | Footstep send radius and pooled 3D players | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-controller-001 | Server-authoritative movement from per-tick intent | ADR-0002 (Accepted) |
| TR-controller-002 | Capsule for every player in every form | ADR-0007 (Accepted) |
| TR-controller-003 | Gait speeds from data | ADR-0006, ADR-0007 (Accepted) |
| TR-controller-004 | Effective speed = most restrictive of lock > root > slow | ADR-0002 §5–6 (Accepted) |
| TR-controller-005 | Hold-to-interact framework | ADR-0008 (Accepted) |
| TR-controller-006 | Server view direction = yaw/pitch + view offset, pitch clamp | ADR-0002, ADR-0007 (Accepted) |
| TR-controller-007 | Interaction targeting by ray | ADR-0007, ADR-0008 (Accepted) |
| TR-controller-008 | Input timeout releases input and cancels holds; RoundEnded freezes | ADR-0002, ADR-0008 (Accepted) |
| TR-controller-009 | Server correction out of geometry; accel ramp | ADR-0002, ADR-0007 (Accepted) |
| TR-controller-010 | Camera effects other than the flinch are client-only | ADR-0015 (Proposed); ADR-0002 §8 (Accepted) |
| TR-controller-011 | Footstep audio from replicated gait and disguise footstep set | ADR-0004 (Accepted); ADR-0010, ADR-0013 (Proposed) |
| TR-controller-012 | Doors instant; close rejected while a capsule overlaps the swing | ADR-0007 (Accepted) |
| TR-controller-013 | Input bindings via InputMap actions | ADR-0007, ADR-0004 (Accepted) |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Player body, capsules and collision layers](story-001-body-capsule-collision.md) | Integration | Ready | ADR-0007 |
| 002 | [Shared movement step and gaits](story-002-movement-step-gaits.md) | Logic | Ready | ADR-0007, ADR-0002, ADR-0006 |
| 003 | [Speed modifier set: lock, root and slow](story-003-speed-modifiers.md) | Logic | Ready | ADR-0002 |
| 004 | [Steps, slopes and the stand-up check](story-004-steps-slopes-stand-up.md) | Integration | Ready | ADR-0007 |
| 005 | [Controller load-time checks](story-005-controller-load-checks.md) | Logic | Ready | ADR-0006 |
| 006 | [View direction, mouse look and input actions](story-006-view-direction-input-actions.md) | Logic | Ready | ADR-0007, ADR-0002 |
| 007 | [Interaction targeting by the server's view ray](story-007-interaction-targeting.md) | Logic | Ready | ADR-0007, ADR-0008 |
| 008 | [HoldService: Start, contested locks and completion](story-008-hold-start-complete.md) | Integration | Ready | ADR-0008 |
| 009 | [Hold continuation, cancels and movement while Holding](story-009-hold-continue-cancel.md) | Integration | Ready | ADR-0008 |
| 010 | [Shapeshifter fake holds](story-010-fake-holds.md) | Integration | Complete | ADR-0008 |
| 011 | [Server authority, input timeout and round-end freeze](story-011-authority-timeout-round-end.md) | Integration | Ready | ADR-0002, ADR-0008 |
| 012 | [Doors: instant toggle and swing-area close check](story-012-doors.md) | Integration | Complete | ADR-0007 |
| 013 | [Flinch view offset and client-only camera effects](story-013-view-offset-camera-effects.md) | Logic | Blocked | ADR-0015 (Proposed), ADR-0002 |
| 014 | [Footstep events from gait and disguise](story-014-footsteps.md) | Integration | Blocked | ADR-0013 (Proposed), ADR-0004, ADR-0010 (Proposed) |
| 015 | [Chase closing check and controller tick budget](story-015-chase-closing-tick-budget.md) | Integration | Ready | ADR-0002, ADR-0007 |
| 016 | [Predicted hold bar responsiveness](story-016-predicted-hold-bar.md) | Visual/Feel | Ready | ADR-0008 |

Cross-system ACs owned by other epics: Borrowed Face parity (borrowed-face), Pings ray and velocity (Pings & Callouts), lunge dodge (Monster Abilities), Facility Map walk times (facility-map), hidden peek view (Survivor Defense), cross-system hold owners (each owner epic).

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/first-person-controller.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` — each screen touched for UI, plus a lead sign-off for Visual/Feel

## Next Step

Run `/story-readiness` on a story, then `/dev-story`. Start with Story 001.
