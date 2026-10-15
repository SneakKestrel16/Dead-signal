# Story 007: Lunge cue, coil pose and hit feedback

> **Epic**: Monster Abilities
> **Status**: In Review
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: 1-2 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: —

## Context

Presentation of the Lunge: the audible wind-up cue (20 m, directional), the coil pose, hit sound, miss scrape and the 80 ms hit-stop. Server logic is complete after story 006; this story waits on the spatial audio pipeline.

**GDD**: `design/gdd/monster-abilities.md`
**Requirement**: `TR-monster-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013: Spatial audio pipeline (Proposed); secondary: ADR-0007
**ADR Decision Summary**: A spatial audio pipeline supplies positional cues and attenuation; radii are applied server-side.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Audio buses and positional playback; verify against the engine reference before use.

**Control Manifest Rules (this layer)**:
- Required: run in the MonsterAbilities slot via `server_tick(tick)` registered with `TickRunner` (ADR-0002, ADR-0005); every number from `AbilityKnobs` (ADR-0006)
- Forbidden: never emit an event from a client (ADR-0005); no literal for a tuning knob in ability code
- Guardrail: the dodge-window values are coupled; rerun the steering check after changing wind-up, turn rates, dash, radius or cone

---

## Acceptance Criteria

*From GDD `design/gdd/monster-abilities.md`, scoped to this story:*

- [ ] The wind-up cue plays 0.6 s before the dash; a survivor 20 m away hears it from a bearing within 15 degrees of the monster's true bearing
- [ ] The coil pose is visible during wind-up and a stumble during the miss slow
- [ ] A server-confirmed hit shows an 80 ms presentation-only hit-stop with no simulation pause and no input lock

---

## Implementation Notes

- Cue radius `lunge_cue_radius_m` from data; the cue is triggered from the Lunge state, not from `AbilityUsed` (never replicated).
- The feel acceptance (80% heard the cue) is a playtest item, not part of this story.

---

## Out of Scope

- Playtest survey: Milestone 5

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: retained screenshot of the coil pose in `production/qa/evidence/` + sign-off in `production/qa/evidence/lunge-presentation-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006; ADR-0013 accepted
- Unlocks: None
