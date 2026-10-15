# Story 008: Results screen

> **Epic**: HUD & Results Screen
> **Status**: In Review
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

`results.md` specifies the screen shown at round end: outcome R1, survivor rows with fate, cause, downs, rescues and stuns landed, the shapeshifter row, team and monster stats including lunges interrupted, the Leave session confirm (P29) and the countdown back to the lobby. Only the data exists: `RoundResults` (match-flow 008) and `MatchDisplay.results()`.

**GDD**: `design/ux/results.md` R1-R9; States & Variants; Interaction Map; Acceptance Criteria
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

*From GDD `design/ux/results.md`, scoped to this story:*

- [ ] At round end every client shows the outcome, each survivor's fate word and cause, downs, rescues and stuns landed, the shapeshifter row and the team and monster stats, matching the payload field for field.
- [ ] A stats group listed in `missing` shows "Results unavailable" and an empty survivor name shows "Unknown player" (test forces a `missing` entry).
- [ ] Keyboard and gamepad reach every focus stop in the spec's order; Leave session opens the P29 confirm; after `results_duration_s` the client returns to the lobby.
- [ ] The screen opens within 100 ms of RoundEnded; retained screenshots of a survivors-win, a shapeshifter-win and a missing-group case.
- [ ] All five clients show the screen within 500 ms of each other; at 150% UI scale menu text measures at least 24 px and nothing clips; a corrupted payload field shows the payload error state, never a crash.

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

**Status**: [x] production/qa/evidence/results-screen-evidence.md (10 png: fixtures + live host/client); tests/unit/hud-results/results_screen_test.gd (14)

---

## Dependencies

- Depends on: Story 001; match-flow 013
- Unlocks: Story 009

## Progress Notes (2026-10-15)

Merged 738b9cf..816e67e. ResultsScreen (CanvasLayer on UiLayers.OVERLAY; static present(payload)); LobbyScreen builds it when MatchDisplay.is_ended() and frees it in _drop_round; Leave session uses P29 confirm. FOUND: in a live lobby round the payload lists Downing, Survivor Defense and Objectives stats in missing (round composition does not register those StatsViews), so downs, rescues, stuns and objectives read "Results unavailable" (AD-229 behaviour; gap filed as match-flow 014). DEVIATIONS: no enter fade or stagger (no reduced-motion setting; everyone gets the cut); countdown on local time (server decides the return); Z4 totals summed from survivor rows (inference, rule 26 settles); "Taken down" wording inferred; no initial focus (first Down/Tab enters the stops); backdrop opaque (0.94 let the frozen HUD show a 0 through). NOT MEASURED: 100 ms and 500 ms timings, 2560x1080 and 1920x1200 margins; 150% is theme size 36 px, not a measured glyph. accessibility_name unverified against docs (runs on 4.7.2). 14 unit tests (watched fail first); 3 mutations caught. Full suite 1488/1488 including lobby_to_round_wiring_test.
