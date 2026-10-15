# Story 009: Optional proximity voice rules

> **Epic**: Pings & Callouts
> **Status**: Blocked
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 2 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

BLOCKED: voice transport is undecided (TR-pings-010; Godot has no built-in VoIP; capture, encode and relay through the server with positional mixing are needed). The GDD marks voice optional and post-MVP. This story records the rules so they are not lost; it needs an ADR on voice transport before it can be Ready.

**GDD**: `design/gdd/pings-and-callouts.md` rules 18-20, 25
**Requirement**: `TR-pings-007`, `TR-pings-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013: Spatial audio pipeline (voice bus); transport: N/A — no ADR yet
**ADR Decision Summary**: Voice plays on the voice bus, positional; transport is not decided.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Microphone capture (`AudioEffectCapture`), encoding and relay need verifying against the 4.7 docs before any code.

**Control Manifest Rules (this layer)**:
- Required: the lobby setting applies to every player under the same rule
- Forbidden: no game rule may require voice

---

## Acceptance Criteria

*From GDD `design/gdd/pings-and-callouts.md`, scoped to this story:*

- [ ] Proximity voice is a lobby setting, Off by default; when On it applies to every player within `voice_range_m`, positional.
- [ ] An Eliminated or Escaped player's voice is not delivered to any living player.
- [ ] Monster voice in True Form or while Transforming is delivered through the distortion filter; Disguised it is delivered unaltered.

---

## Implementation Notes

- Write the voice transport ADR first (`/architecture-decision voice-transport`).

---

## Out of Scope

- Voice imitation (ruled out by the source).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/pings-and-callouts/proximity_voice_test.gd` (real ENet where the AC names clients)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Voice transport ADR; Story 002
- Unlocks: None
