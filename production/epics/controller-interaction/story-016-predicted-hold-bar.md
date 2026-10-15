# Story 016: Predicted hold bar responsiveness

> **Epic**: First-Person Controller & Interaction
> **Status**: In Review
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

The hold bar must appear the moment the player presses interact, even at high latency, and quietly vanish if the server rejects the Start.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Hold-to-interact protocol
**ADR Decision Summary**: §8: the owner's client shows a predicted bar on the rising edge if its local target query found a target; its snapshot carries `hold_net_id` and `hold_elapsed_ticks`; the bar cancels if the snapshot acknowledging the press shows no hold, otherwise it follows the server's elapsed time.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Set `mouse_filter = MOUSE_FILTER_IGNORE` on the bar (`docs/engine-reference/godot/gotchas.md`).

**Control Manifest Rules (this layer)**:
- Forbidden: counting hold progress in an owner [owner_timed_hold]

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Feel) and ADR-0008 §8, scoped to this story:*

- [ ] Under 150 ms simulated latency, the predicted hold bar appears ≤ 100 ms after a valid Start press, measured by frame count on a 240 fps capture.
- [ ] A rejected Start cancels the bar when the acknowledging snapshot arrives, with no flash of progress beyond the predicted amount.

---

## Implementation Notes

*Derived from ADR-0008 Decision §8:*

- Use a greybox bar; the final HUD look belongs to the HUD epic.

---

## Out of Scope

- Final HUD art and layout (HUD epic)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: retained screenshot or capture in `production/qa/evidence/` + sign-off in `production/qa/evidence/predicted-hold-bar-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 007, 008; network-authority story 006
- Unlocks: HUD epic

---

## Completion Notes

**Implemented**: 2026-10-14 (worktree agent, squash-merged as 500fab4)
**Criteria**: AC2 passing (automated + capture 02); AC1 automated proxy passing (bar drawn on the press tick, at most one 16.7 ms tick), the 240 fps capture measurement not done
**Test Evidence**: `tests/unit/first-person-controller/predicted_hold_bar_test.gd` (10 tests); captures and write-up in `production/qa/evidence/predicted-hold-bar-evidence.md`
**Open**: lead sign-off (Visual/Feel gate, BLOCKING) and the AC1 240 fps capture, which needs a two-client build with a client scene that wires the bar. Story stays In Review until both are done.
