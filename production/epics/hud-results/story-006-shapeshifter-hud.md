# Story 006: Shapeshifter HUD and survivor-side absence

> **Epic**: HUD & Results Screen
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

S1-S7 are the shapeshifter's elements: face list with observation progress, form and form cooldown, ability cooldowns, transforming bar, stun or immunity remaining, the install alert and the placement preview. A survivor client must never render any of them, which ADR-0004 makes true at the data level and this story proves at the tree level.

**GDD**: `design/ux/hud.md` S1-S7
**Requirement**: `TR-ui-001`, UX-hud-04
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus; secondary: ADR-0004
**ADR Decision Summary**: Shapeshifter-only state never reaches a survivor client; HUD widgets read HudModel only.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: S1-S7 are not instanced on a survivor client
- Forbidden: hiding S1-S7 with visibility while instanced on a survivor client

---

## Acceptance Criteria

*From GDD `design/ux/hud.md`, scoped to this story:*

- [ ] The shapeshifter sees S1-S3 always and S4-S7 in their trigger states, values matching server state (cooldowns within 0.1 s).
- [ ] An automated check on a survivor client's HUD tree finds no S1-S7 node in any state.
- [ ] Retained screenshots of the shapeshifter HUD in true form, disguised and transforming.

---

## Implementation Notes

- Placement preview for False Signal and Blackout may already exist in monster-abilities client code: reuse it.

---

## Out of Scope

- Ability balance.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/shapeshifter-hud/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: None
