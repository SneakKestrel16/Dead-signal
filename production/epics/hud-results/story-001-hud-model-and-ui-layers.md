# Story 001: HudModel, UiLayers and the full InputContextStack

> **Epic**: HUD & Results Screen
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

ADR-0014 names a client `HudModel` as the HUD's only source, fixed `UiLayers`, and an `InputContextStack` with five contexts. Sprint 8 shipped a minimal `InputContextStack` (`src/core/ui/input_context_stack.gd`) for the callout wheel only, and the ping HUD reads its own receivers. Every later HUD story needs one model to read.

**GDD**: `design/ux/hud.md` HUD Element Specifications; Information Architecture
**Requirement**: `TR-ui-001`, UX-hud-02
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus
**ADR Decision Summary**: InputContextStack is the sole writer of mouse mode and the input mask; UI on fixed UiLayers; HudModel fed by the snapshot handler and ClientEventRouter is the HUD's only source.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Dual focus (4.6) and `Input.mouse_mode` names are ADR-0014 Verification items 2 and 6; check `docs/engine-reference/godot/` before use.

**Control Manifest Rules (this layer)**:
- Required: InputContextStack is the only writer of Input.mouse_mode
- Required: a pop of a context that is not on top raises an error
- Required: HUD widgets read only HudModel

---

## Acceptance Criteria

*From GDD `design/ux/hud.md`, scoped to this story:*

- [ ] `InputContextStack` supports GAMEPLAY, WHEEL, OVERLAY, MENU and MODAL with the ADR-0014 flag table; it resets to GAMEPLAY at round start and to MENU at round end; a stale pop is an error; the existing wheel behaviour is unchanged.
- [ ] `UiLayers` holds WORLD_MARKERS 1, HUD 2, SCARE_FX 3, CAPTIONS 4, OVERLAY 10, MODAL 20, and every existing CanvasLayer in `src` uses it.
- [ ] `HudModel` exposes phase, clock, roster, objective lines, own state, cooldowns, feed lines and markers through typed getters and the five ADR-0014 signals, fed only by the snapshot handler and `ClientEventRouter`; a unit test drives each signal from a recorded payload.

---

## Implementation Notes

- Grow the existing stack; do not add a second one.
- `MatchDisplay` already holds phase, clock and outcome: HudModel reads it rather than duplicating it.
- Migrating `PingCalloutHud` and `PingMarkers` onto HudModel is story 008, not this one.

---

## Out of Scope

- Any visible HUD widget (stories 002 onward).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hud-results/hud_model_and_ui_layers_test.gd` must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: match-flow 009; pings-and-callouts 008
- Unlocks: Stories 002-008
