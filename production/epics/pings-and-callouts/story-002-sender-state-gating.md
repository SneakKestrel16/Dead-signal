# Story 002: Sender-state gating for pings and callouts

> **Epic**: Pings & Callouts
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

What a player may send depends on its state: life state for survivors, form for the monster, and the shock lock for both. The states table and rules 14, 21-23 define it. Read state through the existing views (life state, `BorrowedFaceView`, `StateKeys.SHOCK_STUN_LOCK`, the spectator view in `round_lifecycle.gd`).

**GDD**: `design/gdd/pings-and-callouts.md` rules 14, 21, 22, 23; States and Transitions
**Requirement**: `TR-pings-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0004
**ADR Decision Summary**: Modules read each other's state through getter-only views in the state registry, in tick order; never by calling into another module.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: run after Objectives and before Scare in tick order
- Forbidden: never call into another module's internals; read its published view

---

## Acceptance Criteria

*From GDD `design/gdd/pings-and-callouts.md`, scoped to this story:*

- [ ] A ping or callout from a Seized, Eliminated or Escaped survivor is rejected; a Downed survivor can send pings, "Need rescue" and "Danger" only.
- [ ] In true form and while transforming, the monster's ping and callout requests are rejected.
- [ ] For `stun_duration_s` after a taser hit, a ping or callout from a shocked survivor or a stunned disguised monster is rejected, and the first one after it ends is accepted; after a hit on an immune disguised monster or a survivor inside its post-lock window, it is accepted.
- [ ] A disguised monster whose borrowed survivor is Eliminated or Escaped has its requests rejected; one whose borrowed survivor is Downed or Seized can send any callout (for example "Drive here").

---

## Implementation Notes

- One pure `can_send(player, kind, line)` function makes every branch unit-testable without a scene.
- The borrowed survivor's Downed, Seized or Hidden state never restricts the monster (rule 21).
- Proximity voice is never blocked by these states (story 009).

---

## Out of Scope

- Story 001: target validation and rate limits.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/pings-and-callouts/sender_state_gating_test.gd` must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Stories 003, 004, 006
