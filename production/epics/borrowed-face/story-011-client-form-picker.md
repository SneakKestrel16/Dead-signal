# Story 011: Shipped client form picker and transform input

> **Epic**: Borrowed Face
> **Status**: Ready
> **Layer**: Feature
> **Type**: UI
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

`BorrowedFace.request_packet(form)` exists and the server runs the 2 s transformation, but no shipped client code sends it; only `round_view` does. The shapeshifter cannot disguise in the shipped build. The HUD-6 face list (S1) already shows which survivors are observed and available.

**GDD**: `design/gdd/borrowed-face.md` rules 6-9, 14
**Requirement**: `TR-bf-001`, `TR-ui-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus; secondary: ADR-0004
**ADR Decision Summary**: The picker is a WHEEL-like context that keeps movement live; it reads the HudModel face list and sends one request; the server validates.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: the picker reads HudModel only
- Required: requests gated by the InputContextStack
- Forbidden: offering a form the server says is unavailable as if it were available

---

## Acceptance Criteria

*From GDD `design/gdd/borrowed-face.md`, scoped to this story:*

- [ ] A shapeshifter opens the form picker, sees each observed survivor plus true form with availability from the face list, and choosing one sends `request_packet`; the server starts the transformation.
- [ ] A request while on cooldown, stunned or mid-lunge is refused by the server and the picker shows the refusal through the HUD-3 label.
- [ ] Retained screenshots of the picker and of a completed disguise in the shipped lobby-to-round path.

---

## Implementation Notes

- The binding is inference; mark it.
- Check the TR id against docs/architecture/tr-registry.yaml and correct it in this story if it differs.

---

## Out of Scope

- Transformation visuals (stories 009, 010).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/client-form-picker/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: match-flow 013; hud-results 006
- Unlocks: None
