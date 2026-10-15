# Story 010: Visual budget and accessibility verification pass

> **Epic**: HUD & Results Screen
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Four `hud.md` acceptance criteria measure the HUD as a whole rather than one element: screen coverage (8% in exploration, 12% in the busiest state), colourblind distinguishability under protanopia, deuteranopia and tritanopia simulation, reduced motion, and text sizes. They need every element in place first.

**GDD**: `design/ux/hud.md` Visual Budget; Accessibility; Acceptance Criteria 1, 5, 6, 9, 10
**Requirement**: UX-hud-01, UX-hud-05, UX-hud-06, UX-hud-09, UX-hud-10
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus
**ADR Decision Summary**: Accessibility hooks are client-side and never alter server timing; strings and sizes go through one theme.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: measurements taken from retained screenshots, with the numbers written down
- Forbidden: eyeballed pass verdicts

---

## Acceptance Criteria

*From GDD `design/ux/hud.md`, scoped to this story:*

- [ ] Pixel counts on retained screenshots show the HUD (excluding world markers) at most 8% in exploration and at most 12% in the busiest state.
- [ ] Simulated protanopia, deuteranopia and tritanopia screenshots keep every roster state, checklist state and ping type distinguishable by shape or word.
- [ ] With reduced motion on no HUD element moves or pulses, and measured critical text is at least 20 px and feed text at least 28 px at 1080p.
- [ ] An evidence file lists every measured number and the screenshot it came from.

---

## Implementation Notes

- Write a small measuring script under `tools/` if it saves time; numbers, not impressions.

---

## Out of Scope

- Fixing what fails: file it as a bug or a follow-up story.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/hud-budget-accessibility-pass/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 002-007
- Unlocks: None
