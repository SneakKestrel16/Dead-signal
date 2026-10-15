# Story 005: Marker lifecycle: static position, lifetime and max active

> **Epic**: Pings & Callouts
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Markers are static: a player warning ping stays where the target stood at ping time. Each sender has at most `ping_max_active` markers, the newest replacing the oldest, and each expires after `ping_lifetime_s`. Markers keep the identity they were sent under until expiry.

**GDD**: `design/gdd/pings-and-callouts.md` rules 5, 8; States and Transitions (last paragraph)
**Requirement**: `TR-pings-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus; secondary: ADR-0004
**ADR Decision Summary**: Clients hold a projected marker list fed only by server messages; the HUD reads that list.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: UI and HUD read only projected client state
- Required: `ping_lifetime_s` and `ping_max_active` come from data

---

## Acceptance Criteria

*From GDD `design/gdd/pings-and-callouts.md`, scoped to this story:*

- [ ] A survivor's player warning ping appears at the target's position at ping time and does not move for its lifetime, even if the target moves or transforms.
- [ ] With `ping_max_active` = 2, other clients display only the newest 2 markers of one sender.
- [ ] A marker expires `ping_lifetime_s` after acceptance; a sender's disconnect leaves its markers to expire normally.
- [ ] Two bodies sharing a name that both ping show two markers under that name; nothing merges them.

---

## Implementation Notes

- A client-side marker list keyed by sender handle, not by name, so duplicate names stay separate.
- Expiry runs on server ticks carried in the message, not local wall time.

---

## Out of Scope

- Story 008: drawing markers through walls.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/pings-and-callouts/marker_lifecycle_test.gd` must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004
- Unlocks: Story 008
