# Story 008: Results screen

> **Epic**: HUD & Results Screen
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

`results.md` specifies the screen shown at round end: outcome R1, survivor rows with fate, cause, downs, rescues and stuns landed, the shapeshifter row, team and monster stats including lunges interrupted, the Leave session confirm (P29) and the countdown back to the lobby. Only the data exists: `RoundResults` (match-flow 008) and `MatchDisplay.results()`.

**GDD**: `design/ux/hud.md` R1-R9; States & Variants; Interaction Map; Acceptance Criteria
**Requirement**: `TR-ui-001`, UX-results-01, UX-results-02, UX-results-04
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus; secondary: ADR-0011
**ADR Decision Summary**: The screen is a MENU context with stock focus; it presents the RoundResults payload once and decides nothing; a group listed in missing shows Results unavailable.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `accessibility_name` and 4.6 dual focus: check the engine reference.

**Control Manifest Rules (this layer)**:
- Required: MENU context pushed on show and popped on hide
- Required: every row has an accessibility_name from a tr() key; the countdown is never a live region
- Forbidden: a 0 shown for a stats group listed in missing

---

## Acceptance Criteria

*From GDD `design/ux/hud.md`, scoped to this story:*

- [ ] At round end every client shows the outcome, each survivor's fate word and cause, downs, rescues and stuns landed, the shapeshifter row and the team and monster stats, matching the payload field for field.
- [ ] A stats group listed in `missing` shows "Results unavailable" and an empty survivor name shows "Unknown player" (test forces a `missing` entry).
- [ ] Keyboard and gamepad reach every focus stop in the spec's order; Leave session opens the P29 confirm; after `results_duration_s` the client returns to the lobby.
- [ ] The screen opens within 100 ms of RoundEnded; retained screenshots of a survivors-win, a shapeshifter-win and a missing-group case.

---

## Implementation Notes

- The lobby return path is match-flow 013; until it merges, end on the screen and capture there.

---

## Out of Scope

- The lobby Last round view (story 009).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/results-screen/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001; match-flow 013
- Unlocks: Story 009
