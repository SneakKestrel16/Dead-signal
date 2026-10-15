# Epic: Scare Events

> **Layer**: Feature
> **GDD**: design/gdd/scare-events.md
> **Architecture Module**: Scare Events (server half) (`docs/architecture/architecture.md` Feature layer)
> **Status**: Ready
> **Stories**: 9 stories, see the Stories table below

## Overview

This epic dresses up what humans and the round script already do; it invents no threats. Each scare is a named, authored catalogue entry with a source, a scope, an intensity class and a cooldown. The server decides when a scare fires and who receives it, gates it per recipient (last Major, last any, per-location repeat, phase budget), and broadcasts `ScareTriggered`. Clients only present it. Sources are monster actions (door burst, disguise drop, lunge ambush), Blackout, and the round script at authored anchors; there is no free-running ambient timer. Single-client hallucinations go to one client only. The module owns gating, cooldowns, budgets, recipients and view-offset writes. Presentation pieces already merged and reused here: CI-13 view offset and camera FX, SD-11 shock presenter and flash limiter, FM-10 lighting presenter, FM-11 surveillance feed.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Replication scope and information hiding | Per-peer delivery; source and identity fields stripped for survivors | HIGH |
| ADR-0005: Event catalog, state registry and tick order | `ScareTriggered`; reads `AbilityUsed`, `RoundPhaseChanged`, `ObjectiveProgressChanged` | HIGH |
| ADR-0006: Data-driven configuration | Scare catalogue and gating knobs as data | MEDIUM |
| ADR-0009: Lighting states and Blackout | Facility Map owns lighting; scares request none and add only flicker | HIGH |
| ADR-0013: Spatial audio pipeline | Positional diegetic scares, stinger bus, ducking priority | MEDIUM |
| ADR-0015: Scare presentation and view offset | Camera flinch as server-held view offset; accessibility hooks | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-scare-001 | Server decides every scare and sends `ScareTriggered` with scope; source and identity stripped for survivors | ADR-0004, ADR-0005 (inferred; registry untraced) |
| TR-scare-002 | Scoped delivery; single-client hallucinations to one client only; per-peer visibility | ADR-0004 (inferred; registry untraced) |
| TR-scare-003 | Per-recipient gating state; Major reduced to Minor; reset per round; Monster-source never blocked | ❌ No ADR |
| TR-scare-004 | Scare catalogue is data; RoundScript fires only at authored anchors; no ambient timer | ADR-0006 (inferred; registry untraced) |
| TR-scare-005 | Ambush test at lunge wind-up (per-survivor last-seen time, LOS, blackout volume) | ❌ No ADR |
| TR-scare-006 | Camera flinch: server-held offset, ramp, cap, replace not stack, per-player toggle | ADR-0015 ✅ |
| TR-scare-007 | Facility scare state machine (Low, Rising, Emergency, Results + overlays); adds only flicker | ADR-0009 ✅ |
| TR-scare-008 | Positional diegetic audio, stingers on Major only, ducking priority, separate bus | ADR-0013 ✅ |
| TR-scare-009 | Client-side accessibility hooks; never alter server timing or recipients | ADR-0015 ✅ |
| TR-scare-010 | No scare produces footsteps, voice, ping or callout; door scares never change door state; False Signal never scares | ❌ No ADR |
| TR-scare-011 | Reconnect receives current facility scare state; missed scares not replayed | ❌ No ADR |
| TR-scare-012 | Visual effects (stinger flash, strobe, beacons, impossible surveillance frame) | ADR-0009, ADR-0015 ✅ |

Untraced requirements are informational at `workflow: standard`. The ADR column's "inferred" rows are the orchestrator's reading of which accepted ADR governs them; the TR registry does not list them yet.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/scare-events.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` — each screen touched for UI, plus a lead sign-off for Visual/Feel

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Scare catalogue data and the server Scare module | Logic | Complete | ADR-0005 |
| 002 | Per-recipient scare gating, budgets and repeat block | Logic | Complete | ADR-0015 |
| 003 | Scoped delivery: shared relevance and single-client hallucinations | Integration | Ready | ADR-0004 |
| 004 | Monster-source scares: door burst, reveal and Blackout | Integration | In Review | ADR-0005 |
| 005 | Ambush lunge scare and flinch suppression near a lunge | Integration | Complete | ADR-0015 |
| 006 | Facility scare state machine and RoundScript anchors | Integration | In Review | ADR-0009 |
| 007 | Presentation-only guarantees: slammed doors and no fake teammates | Integration | Ready | ADR-0005 |
| 008 | Scare audio: positional origin, stingers, ducking and volume scales | Visual/Feel | Ready | ADR-0013 |
| 009 | Scare visuals and flash accessibility | Visual/Feel | Ready | ADR-0015 |

## Next Step

Run `/create-stories scare-events` to break this epic into implementable stories.
