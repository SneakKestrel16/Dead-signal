# Sprint 9 — 2027-02-02 to 2027-02-15

PR-SPRINT skipped — Lean mode. Generated autonomously (AD-235).

## Sprint Goal

Make the shipped build playable end to end. A lobby countdown starts the composed round, the round shows a real HUD, and Results returns everyone to the lobby.

## Capacity

- Total days: 10
- Buffer (20%): 2 days
- Available: 8 days

The plan below is 10.5 agent-days. Agents run in parallel worktrees, as in sprints 6 to 8, so the day count is effort, not calendar time.

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| match-flow-13 | [Lobby countdown starts the composed round; round end returns to the lobby](../epics/match-flow/story-013-lobby-to-round-wiring.md) | network-programmer | 1.5 | MF-10, MF-11, LB-5 | Story ACs; real ENet, 3+ clients; two-instance screenshots |
| hud-1 | [HudModel, UiLayers and the full InputContextStack](../epics/hud-results/story-001-hud-model-and-ui-layers.md) | godot-gdscript-specialist | 1 | MF-9, PC-8 | Story ACs; unit test |
| hud-2 | [Clock, phase, roster, objective checklist and crosshair](../epics/hud-results/story-002-always-on-hud.md) | ui-programmer | 1 | hud-1 | Screenshots at three resolutions |
| hud-3 | [Interaction prompt, hold ring, reject label and input glyphs](../epics/hud-results/story-003-prompt-hold-ring-reject.md) | ui-programmer | 1 | hud-1 | Screenshots |
| hud-4 | [Own-state vignettes, own bleed-out and the HUD state table](../epics/hud-results/story-004-own-state-and-hud-states.md) | ui-programmer | 1 | hud-1, hud-2 | Screenshots |
| hud-8 | [Results screen](../epics/hud-results/story-008-results-screen.md) | ui-programmer | 1.5 | hud-1, match-flow-13 | Screenshots, including a missing-group case |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| hud-5 | [Edge cues, flinch-off pulse, taser count and world progress bars](../epics/hud-results/story-005-edge-cues-items-progress.md) | ui-programmer | 1 | hud-1 | Screenshots |
| hud-6 | [Shapeshifter HUD and survivor-side absence](../epics/hud-results/story-006-shapeshifter-hud.md) | ui-programmer | 1.5 | hud-1 | Screenshots plus a survivor-tree check |
| hud-7 | [Feed cap, opaque backing, marker cap, shapes and wheel stick steering](../epics/hud-results/story-007-feed-and-marker-conformance.md) | ui-programmer | 1 | hud-1, pings-11 | Screenshots |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| hud-9 | [Lobby "Last round" view](../epics/hud-results/story-009-lobby-last-round.md) | ui-programmer | 0.5 | hud-8 | Screenshots |
| hud-10 | [Visual budget and accessibility verification pass](../epics/hud-results/story-010-hud-budget-accessibility-pass.md) | qa-tester | 1 | hud-2 to hud-7 | Measured numbers in an evidence file |

### Added mid-sprint (AD-236)

The shipped client sends no ability, transform or taser requests (only `tests/manual/round_view.gd` does), so the shapeshifter cannot attack or disguise in the playable loop. HUD stories also found missing server feeds and gamepad bindings.

| ID | Task | Priority | Est. Days |
|----|------|----------|-----------|
| monster-abilities-11 | [Client input for Lunge, False Signal and Blackout, with placement preview](../epics/monster-abilities/story-011-client-ability-input.md) | Must Have | 1.5 |
| borrowed-face-11 | [Client form picker and transform input](../epics/borrowed-face/story-011-client-form-picker.md) | Must Have | 1 |
| survivor-defense-15 | [Client fires the taser on use_item](../epics/survivor-defense/story-015-taser-fire-input.md) | Must Have | 0.5 |
| hud-11 | [Server feeds: roster names and hold refusal reasons](../epics/hud-results/story-011-hud-server-feeds.md) | Should Have | 1 |
| hud-12 | [Gamepad bindings for every action](../epics/hud-results/story-012-gamepad-bindings.md) | Nice to Have | 0.5 |

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| pings-11 Warning pings and feed scrollback key | Agent still running at sprint 8 close | 0.5 |
| pings-8, scare-8, scare-9 | Implemented; wait on the designer's sign-off | 0 (designer) |
| scare-6 | Implemented; shipped map has no scare anchors, and the map edit needs the user's OK | 0 (designer) |
| 12 sprint-7 stories in review | Wait on the designer's sign-off | 0 (designer) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Lobby-to-round wiring touches the session and roster handoff, which many suites cover | Medium | High | One agent owns it. Full suite on merge. Tools in `tests/manual` already do the same composition |
| Several HUD stories edit `RoundClient` at once and conflict on merge | High | Medium | hud-1 lands first. Later stories add widgets beside it rather than in it |
| ADR-0014 verification items (dual focus, mouse mode names) are unproven on 4.7.2 | Medium | Medium | hud-1 checks the engine reference and records what it finds |
| Concurrent real-ENet runs make suites flaky | Medium | Low | Fixed port ranges per story. Re-run alone before calling a failure. Never widen bounds |

## Dependencies on External Factors

- The designer signs off the In Review stories, decides the SE-6 map edit, and the stale class cache question.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-009-[date].md`, from `/qa-plan sprint`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

QA plan: run `/qa-plan sprint` before the UI stories start.
