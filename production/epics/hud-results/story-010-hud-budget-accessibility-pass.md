# Story 010: Visual budget and accessibility verification pass

> **Epic**: HUD & Results Screen
> **Status**: In Review
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

**Status**: [x] production/qa/evidence/hud-budget-accessibility-evidence.md

---

## Dependencies

- Depends on: Stories 002-007
- Unlocks: None

## Progress Notes (2026-10-15)

- tools/hud_measure.py (stdlib PNG reader): coverage, Machado CVD simulation, contrast, frame diff. round_view --bot=budget captures exploration and busiest states.
- AC1 PASS: exploration 6.13% (limit 8%), busiest 8.77% (limit 12%), markers excluded.
- AC2 PASS: every roster state, checklist line and ping type differs by word or shape under protanopia, deuteranopia and tritanopia; markers keep at least 3.44:1.
- AC3 FAIL, filed: BUG-0008 (prompt and marker fades ignore reduced motion; no client setting), BUG-0009 (install alert 18 px), BUG-0010 (shapeshifter HUD text 16 px). BUG-0011: a zone-ambience debug label is drawn in the HUD.
- AC4 PASS: production/qa/evidence/hud-budget-accessibility-evidence.md lists every number with its screenshot.
- Text size pass/fail uses the font size set in code; measured glyph height recorded alongside. Ruling on which the spec means is open.
- Full suite on merge: 1551 tests, 0 failures, 0 leak lines.
