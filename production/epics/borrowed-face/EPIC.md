# Epic: Borrowed Face

> **Layer**: Core
> **GDD**: design/gdd/borrowed-face.md
> **Architecture Module**: Borrowed Face (`docs/architecture/architecture.md` Core layer)
> **Status**: Ready (server logic stories are unblocked; rendering stories block on ADR-0010, Proposed)
> **Control Manifest**: 2026-10-13
> **Stories**: 10 stories (8 Ready, 2 Blocked on Proposed ADR-0010/0013)

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

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Observation accumulator](story-001-observation-accumulator.md) | Logic | Complete | ADR-0007, ADR-0005, ADR-0006 |
| 002 | [Form-change request validation and target persistence](story-002-form-change-requests.md) | Logic | Complete | ADR-0005 |
| 003 | [Transform state machine, cooldown and FormChanged](story-003-transform-state-machine.md) | Logic | Complete | ADR-0005, ADR-0006 |
| 004 | [Stun immunity during and after transformation](story-004-immunity-interactions.md) | Logic | Complete | ADR-0005 |
| 005 | [Action restrictions while Disguised or Transforming](story-005-action-restrictions.md) | Integration | Complete | ADR-0008, ADR-0005 |
| 006 | [Disguise gates on objectives, rescue and defense interactions](story-006-interaction-gates.md) | Integration | Complete | ADR-0008 |
| 007 | [Form replication and reconnect](story-007-form-replication-reconnect.md) | Integration | Complete | ADR-0004, ADR-0005 |
| 008 | [Stun events projected by the form shown](story-008-stun-projection-by-form.md) | Integration | Complete | ADR-0004, ADR-0005 |
| 009 | [Disguise and true-form rendering](story-009-disguise-rendering.md) | Visual/Feel | In Review | ADR-0010, ADR-0004 |
| 010 | [Transformation warp and distortion audio](story-010-transform-warp-audio.md) | Visual/Feel | Ready | ADR-0010 (Proposed), ADR-0013 (Proposed), ADR-0004 |

Stun, taser, lunge, objective and defense owners are Feature epics; stories 004–006 and 008 test against stubs and re-run when those land.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/borrowed-face.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` — each screen touched for UI, plus a lead sign-off for Visual/Feel

## Next Step

Run `/story-readiness` on a story, then `/dev-story`. Start with Story 001.
