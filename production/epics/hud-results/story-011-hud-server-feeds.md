# Story 011: Server feeds the HUD still lacks: round roster names and hold refusal reasons

> **Epic**: HUD & Results Screen
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

HUD-2 and HUD-3 found values no server message carries: the round roster with display names (HUD-2 seeds it only in round_view) and the reason a hold was refused or cancelled (labels read "Not now" and "Interrupted"). HUD-5 added a WorldProgress feed that covers the activation countdown; wire HUD-2's activation label to it. Each HudModel handler exists and is unit-tested.

**GDD**: `design/ux/hud.md` H3, H4, H8, H9
**Requirement**: `TR-ui-001`, UX-hud-02
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding; secondary: ADR-0005, ADR-0014
**ADR Decision Summary**: Per-peer projection; a survivor never learns hidden identity from these feeds; HudModel is the only reader.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: per-peer projection, nothing a recipient may not know
- Required: HudModel handlers fed through ClientEventRouter

---

## Acceptance Criteria

*From GDD `design/ux/hud.md`, scoped to this story:*

- [ ] At round start every client's HudModel receives the survivor roster with display names, and the shipped lobby-to-round path shows names in H4 with no round_view seeding.
- [ ] While the terminal activates, every survivor sees the H3 countdown seconds and "Paused" when nobody holds, driven by the server feed.
- [ ] A refused or cancelled hold shows its server reason in H9 instead of the generic text (real ENet test with at least one refusal and one cancel).

---

## Implementation Notes

- Names: the lobby has player names; carry them through the roster handoff rather than inventing a new source.
- A reason byte in the own snapshot entry is the HUD-3 suggestion; weigh it against an event.

---

## Out of Scope

- Visual changes to H3, H4, H9.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/hud-results/hud_server_feeds_test.gd` (real ENet where the AC names clients)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 002, 003, 005; match-flow 013
- Unlocks: None
