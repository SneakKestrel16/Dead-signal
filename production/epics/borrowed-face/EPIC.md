# Epic: Borrowed Face

> **Layer**: Core
> **GDD**: design/gdd/borrowed-face.md
> **Architecture Module**: Borrowed Face (`docs/architecture/architecture.md` Core layer)
> **Status**: Ready (server logic stories are unblocked; rendering stories block on ADR-0010, Proposed)
> **Control Manifest**: 2026-10-13
> **Stories**: Not yet created — run `/create-stories borrowed-face`

## Overview

The shapeshifter takes the appearance of a survivor it has observed. The server owns form, target and the transforming flag, accumulates observation per survivor each tick, and runs the transform state machine (2 s transform, 12 s cooldown). Other systems gate their actions on form through checks, never by owning disguise state. Survivor clients receive only what they need to render the current appearance; a change to the true form emits `FormChanged` and drives the reveal. The disguise swaps the puppet's appearance child, footstep set and animations; the true form is a separate model with the same capsule.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Replication scope and information hiding | Per-peer handles; appearance in introduce and snapshot; no identity in payloads | HIGH |
| ADR-0005: Event catalog, state registry and tick order | Form state in the registry; `FormChanged`; transform state machine in tick order | HIGH |
| ADR-0007: Movement, physics and collision layers | Observation sight rays on `SIGHT` | HIGH |
| ADR-0008: Hold-to-interact protocol | Disguise permissions as gate checks | HIGH |
| ADR-0006: Data-driven configuration | `BorrowedFaceKnobs` | MEDIUM |
| ADR-0010: Borrowed Face rendering (Proposed) | Appearance-child swap, warp, true-form model | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-borrowedface-001 | Server-owned disguise state | ADR-0004, ADR-0005 (Accepted) |
| TR-borrowedface-002 | Survivor clients get only what rendering needs | ADR-0004, ADR-0005 (Accepted) |
| TR-borrowedface-003 | Per-tick observation accumulator | ADR-0007, ADR-0005 (Accepted) |
| TR-borrowedface-004 | Transform state machine (2 s, 12 s cooldown) | ADR-0005 (Accepted) |
| TR-borrowedface-005 | Disguise copies body, outfit, colour, animations, footsteps | ADR-0010 (Proposed) |
| TR-borrowedface-006 | Transform warp and distortion audio | ADR-0004 (Accepted); ADR-0010, ADR-0013 (Proposed) |
| TR-borrowedface-007 | Disguise permissions are gate checks | ADR-0008 (Accepted) |
| TR-borrowedface-008 | Disguise persists when the copied survivor is downed or gone | ADR-0005 (Accepted) |
| TR-borrowedface-009 | FormChanged to true form drives the reveal | ADR-0005, ADR-0004 (Accepted) |
| TR-borrowedface-010 | Observation, transform and reveal parameters are data | ADR-0006 (Accepted) |
| TR-borrowedface-011 | True-form model is separate with the same capsule | ADR-0004 (Accepted); ADR-0010 (Proposed) |

TR-borrowedface-005, -006 and -011 rest partly on ADR-0010 (Proposed); stories for them will be Blocked until it is accepted.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/borrowed-face.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` — each screen touched for UI, plus a lead sign-off for Visual/Feel

## Next Step

Run `/create-stories borrowed-face` to break this epic into implementable stories.
