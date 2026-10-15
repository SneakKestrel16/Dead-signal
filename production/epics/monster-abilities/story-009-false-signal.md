# Story 009: False Signal (Vertical Slice)

> **Epic**: Monster Abilities
> **Status**: Blocked — BLOCKED: ADR-0013 is Proposed — accept it with `/architecture-decision accept ADR-0013` once decided
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: —

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

- [ ] False Signal is rejected within 25 s of the previous one; an aim point beyond 20 m or inside a wall is rejected; the point snaps to walkable floor
- [ ] A callout naming an unobserved, Eliminated or Escaped survivor is rejected
- [ ] Footsteps play 3 s at walk cadence, move at most `walk_speed` x duration (12 m) from the aim point, stop at the first wall, and are audible within 6 m of their current position
- [ ] A fake interaction sound never changes objective state
- [ ] Using False Signal while Disguised is accepted and leaves the disguise intact
- [ ] The wire payload of a fake sound or callout is indistinguishable from a real one (same fields and asset)

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 005; ADR-0013 accepted
- Unlocks: None
