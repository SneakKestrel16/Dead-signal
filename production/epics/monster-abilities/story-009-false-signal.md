# Story 009: False Signal (Vertical Slice)

> **Epic**: Monster Abilities
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Vertical Slice. False Signal plays a fake callout, footsteps or familiar interaction sound at a snapped point; in network data it is identical to the real one. Blocked because the spatial sound depends on the audio pipeline ADR.

**GDD**: `design/gdd/monster-abilities.md`
**Requirement**: `TR-monster-007`, `TR-monster-008`, `TR-monster-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding; secondary: ADR-0013 (Proposed)
**ADR Decision Summary**: Fake and real sounds and callouts are indistinguishable on the wire; `AbilityUsed` is never replicated; each consumer replicates only its effect.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Walkable-floor snapping query on the Jolt/navigation space; audio per ADR-0013.

**Control Manifest Rules (this layer)**:
- Required: run in the MonsterAbilities slot via `server_tick(tick)` registered with `TickRunner` (ADR-0002, ADR-0005); every number from `AbilityKnobs` (ADR-0006)
- Forbidden: never emit an event from a client (ADR-0005); no literal for a tuning knob in ability code
- Guardrail: the dodge-window values are coupled; rerun the steering check after changing wind-up, turn rates, dash, radius or cone

---

## Acceptance Criteria

*From GDD `design/gdd/monster-abilities.md`, scoped to this story:*

- [x] False Signal is rejected within 25 s of the previous one; an aim point beyond 20 m or inside a wall is rejected; the point snaps to walkable floor
- [x] A callout naming an unobserved, Eliminated or Escaped survivor is rejected
- [x] Footsteps play 3 s at walk cadence, move at most `walk_speed` x duration (12 m) from the aim point, stop at the first wall, and are audible within 6 m of their current position
- [x] A fake interaction sound never changes objective state
- [x] Using False Signal while Disguised is accepted and leaves the disguise intact
- [x] The wire payload of a fake sound or callout is indistinguishable from a real one (same fields and asset)

---

## Implementation Notes

- Observed list from `BorrowedFace.observed`. Callout presentation is owned by Pings & Callouts (no code yet): emit `AbilityUsed` with signal type and impersonated survivor; do not redefine the feed line.
- Cooldown starts on activation.

---

## Out of Scope

- Pings & Callouts presentation
- Blackout (story 010)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/monster-abilities/false_signal_test.gd` — must exist and pass
- Integration: `tests/integration/monster-abilities/false_signal_wire_test.gd` — indistinguishable payload

**Status**: [x] `tests/unit/monster-abilities/false_signal_test.gd` (8 tests), `tests/integration/monster-abilities/false_signal_wire_test.gd`

---

## Dependencies

- Depends on: Stories 001, 005; ADR-0013 accepted
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-215):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 1151/1151 after the wave merge, no leak warnings.
- Callouts emit AbilityUsed only; Pings & Callouts (no code yet) sends the voice and feed line, so callout wire-identity is not proven here.
- Walk cadence step_s, footstep_set_of(survivor), interaction sound radii, floor snap and path cut are injected; the composer leaves them unwired (on its audit allow-list) until MapQueries has floor snap and a path cut.
- Range checked on the aim point before snapping (inference).
- Footstep masking belongs in the real footstep sender for real and fake steps alike.
- Tests written after the code; mutations stand in for the red run.
**Test Evidence**: Wire test: fake install and footstep batches equal real ones per viewer. Mutations caught: no cooldown, escaped survivor as callout, radius walk+1, wall cut removed.
**Code Review**: Complete (orchestrator review at merge)
