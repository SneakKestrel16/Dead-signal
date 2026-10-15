# Epic: Monster Abilities

> **Layer**: Feature
> **GDD**: design/gdd/monster-abilities.md
> **Architecture Module**: Monster Abilities (`docs/architecture/architecture.md` Feature layer)
> **Status**: Ready
> **Control Manifest**: 2026-10-13
> **Stories**: 10 stories — see table below

## Overview

This system owns the shapeshifter's three tools.
- **Predatory Lunge (MVP):** a telegraphed true-form attack: a 0.6 s wind-up root, then a 0.3 s, 4 m dash. The server hit-tests every Active tick against rewound survivor positions. A confirmed hit emits `SurvivorHit`, which starts Downing's takedown commit.
- **False Signal (Vertical Slice):** plays a fake callout, footsteps or interaction sound at a nearby spot. Survivors cannot tell it from a real one in the network data.
- **Blackout (Vertical Slice):** kills the lights in one blackout-able volume for 6 seconds.

The server owns all ability state: cooldowns, wind-up, hit resolution and placement. A client sends only an activation request and an aim point. An invalid request has no effect and costs no cooldown. `AbilityUsed` is server-internal; each consumer replicates only its own effect.

The Downing epic drives `SurvivorHit` directly in its tests, because this module did not exist. Borrowed Face 005 injects an attack source (`set_attack_source`) and a `StubAbilities` handler that this module replaces.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Authoritative simulation, tick rate and input | Activation request and aim point only; server-owned cooldowns and hit resolution; fixed tick for the dodge-window simulation | HIGH |
| ADR-0003: Lag compensation and rewind | Lunge hit test on rewound positions, capped at `max_rewind_ms` 180 and an RTT bound (`RewindHistory`/`LagCompensation`, network-authority story 007) | HIGH |
| ADR-0004: Replication scope and information hiding | `AbilityUsed` never replicated; fake and real sounds and callouts indistinguishable on the wire | HIGH |
| ADR-0005: Event catalog, state registry and tick order | Emits `SurvivorHit` and `AbilityUsed`; publishes Lunge state; reads form, Transforming and takedown eligibility | HIGH |
| ADR-0006: Data-driven configuration | `AbilityKnobs` (already in `src/foundation/data_config/ability_knobs.gd`), all numbers with safe ranges | MEDIUM |
| ADR-0007: Movement, physics and collision layers | Wind-up root and turn cap, dash steering, the miss slow as a controller modifier; walls, closed doors and other bodies block the dash | HIGH |
| ADR-0009: Lighting states and Blackout (Proposed) | Blackout targeting, `blackout_able`, server lighting state | MEDIUM |
| ADR-0011: Round stats and results payload (Proposed) | `stats.abilities` counters for the results screen | LOW |
| ADR-0013: Spatial audio pipeline (Proposed) | Lunge wind-up cue within 20 m; False Signal spatial sounds | MEDIUM |

## GDD Requirements

ADR coverage below is mapped by domain: these ADRs do not list TR-IDs by name (inference; `/create-stories` settles it per story). At `workflow: standard` only the Foundation ADRs (0001–0008, all Accepted) are expected; rows on a Proposed ADR are informational and their stories block until it is accepted.

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-monster-001 | Server owns all ability state; client sends activation request and aim point only; invalid requests have no effect and no cooldown cost | ADR-0002 (Accepted) |
| TR-monster-002 | Lunge state machine (Ready, Wind-up 0.6 s, Active 0.3 s dash 4 m, Takedown Commit, Resolved, Cooldown 10 s); true form only; cooldown from resolution | ADR-0005, ADR-0007 (Accepted) |
| TR-monster-003 | Server hit test every Active tick: eligibility, ≤ 1.2 m, 60 degree cone, chest LOS, not stunned since wind-up; dash blocked by walls, closed doors, other bodies | ADR-0003, ADR-0007 (Accepted) |
| TR-monster-004 | Lag compensation: rewind to the viewed tick, capped at 180 ms and by server RTT; 16-tick history | ADR-0003 (Accepted) |
| TR-monster-005 | Dodge-window values are coupled; tick rate and integration step must be fixed for the steering simulation | ADR-0002, ADR-0007 (Accepted) |
| TR-monster-006 | `AbilityUsed` is server-internal, never replicated to survivors | ADR-0004, ADR-0005 (Accepted) |
| TR-monster-007 | False Signal: snapped aim point within 20 m, 12 m footsteps path, callout from the observed list, familiar sounds | ADR-0004 (Accepted); audio ADR-0013 (Proposed) |
| TR-monster-008 | Fake and real sounds and callouts indistinguishable in network data | ADR-0004 (Accepted) |
| TR-monster-009 | Blackout: target volume, `blackout_able`, 6 s, 45 s cooldown, one zone at a time, backup switch | ADR-0009 (Proposed) |
| TR-monster-010 | Miss slow (0.5x for 1.5 s) as a controller modifier; a stun-interrupted lunge counts as resolved; disconnect ends the lunge without a hit | ADR-0007 (Accepted) |
| TR-monster-011 | Lunge wind-up cue within 20 m; coil pose; stats exported to results | ADR-0013, ADR-0011 (Proposed) |
| TR-monster-012 | MVP is Lunge only; False Signal and Blackout are Vertical Slice; all numbers in data with safe ranges | ADR-0006 (Accepted) |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Ability requests and Lunge state machine](story-001-request-validation-and-lunge-states.md) | Logic | Complete | ADR-0002 |
| 002 | [Lunge wind-up root and dash](story-002-wind-up-and-dash.md) | Integration | Complete | ADR-0007 |
| 003 | [Lunge hit test with lag compensation](story-003-hit-test-and-survivor-hit.md) | Logic | Complete | ADR-0003 |
| 004 | [Lunge resolution, cooldown and miss slow](story-004-resolution-cooldown-miss-slow.md) | Logic | Complete | ADR-0007 |
| 005 | [AbilityUsed emission and Lunge state publishing](story-005-ability-used-and-state.md) | Integration | Complete | ADR-0004 |
| 006 | [Integrate with Downing and Borrowed Face](story-006-integrate-downing-borrowed-face.md) | Integration | Complete | ADR-0005 |
| 007 | [Lunge cue, coil pose and hit feedback](story-007-lunge-presentation.md) | Visual/Feel | Ready | ADR-0013 (Proposed) |
| 008 | [Ability stats for results](story-008-ability-stats.md) | Logic | Complete | ADR-0011 (Proposed) |
| 009 | [False Signal (Vertical Slice)](story-009-false-signal.md) | Logic | Complete | ADR-0004; ADR-0013 (Proposed) |
| 010 | [Blackout (Vertical Slice)](story-010-blackout.md) | Integration | Complete | ADR-0009 (Proposed) |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/monster-abilities.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` — each screen touched for UI, plus a lead sign-off for Visual/Feel
- The Borrowed Face 005 `StubAbilities` path and the Downing tests that drive `SurvivorHit` directly are re-checked against the real module

## Next Step

Run `/story-readiness production/epics/monster-abilities/story-001-request-validation-and-lunge-states.md`, then `/dev-story`.
