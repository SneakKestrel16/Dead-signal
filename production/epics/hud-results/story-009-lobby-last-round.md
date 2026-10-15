# Story 009: Lobby "Last round" view

> **Epic**: HUD & Results Screen
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

`results.md` Entry & Exit Points and `lobby-role-assignment.md` (line 222) give the lobby a "Last round" button that reopens the previous round's results without the countdown, so the 20-second auto-return never costs a player the read (AD-31). `lobby_screen.gd` has no such button.

**GDD**: `design/ux/results.md` Entry & Exit Points; lobby-role-assignment UI Requirements
**Requirement**: `TR-ui-002`, UX-results-03
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus
**ADR Decision Summary**: The view is a MODAL or MENU push with stock focus; it reads the stored payload and sends nothing.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: push and pop the same context
- Required: strings through tr()

---

## Acceptance Criteria

*From GDD `design/ux/results.md`, scoped to this story:*

- [ ] After a round, the lobby shows a "Last round" button that opens the stored results with no countdown and closes back to the lobby with focus restored.
- [ ] Before any round, or after the host leaves, the button is absent.
- [ ] Retained screenshots of the button and the opened view.

---

## Implementation Notes

- Reuse the story 008 screen in a no-countdown mode.

---

## Out of Scope

- Results history beyond the last round.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/lobby-last-round/`

**Status**: [x] production/qa/evidence/lobby-last-round/

---

## Dependencies

- Depends on: Story 008
- Unlocks: None

## Progress Notes (2026-10-15)

- ResultsScreen.last_round(payload, contexts) builds the HUD-8 screen with no countdown, a "Last round" title and Back (R9); LobbyScreen stores the last payload and shows a Last round button.
- Unit test tests/unit/hud-results/lobby_last_round_test.gd (6 cases); four mutations caught.
- Evidence: production/qa/evidence/lobby-last-round/ (lobby.png, view.png, back.png); captured from the shipped LobbyScreen with a recorded payload, not a networked round.
- Full suite on merge: 1528 tests, 0 failures, 0 leak lines.

## Closed (2026-10-15)

Closed on its retained screenshots (UI gate). The designer played the shipped build on 2026-10-15 (lobby to round to Results; survivor, shapeshifter and spectating sessions), then approved closing the sprint-9 UI stories in chat (AD-242). Orchestrator reviewed the evidence images. Earlier shots predate BUG-0010/0011 (fixed in b024355); after-fix shots are in production/qa/evidence/hud-budget-accessibility/after/.
