# Story 012: Gamepad bindings for every action

> **Epic**: HUD & Results Screen
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

`project.godot` binds no gamepad event to any action, so the HUD-3 glyphs show "?" on a pad and the HUD-7 stick steering of the wheel cannot be reached in game. hud.md Platform Adaptation commits to Partial gamepad support.

**GDD**: `design/ux/hud.md` Platform Adaptation; H7
**Requirement**: `TR-ui-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus
**ADR Decision Summary**: InputGlyphs reads the live InputMap and switches device class by event type.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: every action in the view_direction_test list has a joypad event
- Forbidden: device == 0 checks

---

## Acceptance Criteria

*From GDD `design/ux/hud.md`, scoped to this story:*

- [ ] Every gameplay and UI action has a gamepad binding; the prompt shows the pad glyph after a pad input and the key glyph after a key input.
- [ ] The callout wheel opens and steers with the right stick on a pad.
- [ ] Retained screenshot of a prompt showing a pad glyph.

---

## Implementation Notes

- Bindings are inference; mark them, a controls pass settles them.

---

## Out of Scope

- Remapping UI.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/gamepad-bindings/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 003, 007
- Unlocks: None
