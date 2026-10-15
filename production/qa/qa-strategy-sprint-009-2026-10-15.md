# QA Strategy: Sprint 009
**Date**: 2026-10-15
**Author**: qa-lead (Phase 2 of /team-qa; qa.level standard, automation autonomous)
**Inputs**: `production/sprint-status.yaml` (33 stories), each story's `> **Type**` line, `production/qa/smoke-2026-10-15-sprint-009.md` (PASS WITH WARNINGS, used as given), `production/qa/qa-plan-sprint-009-2026-10-15.md`, sprint-007 and sprint-008 sign-offs, every evidence md (sign-off rows read), test and evidence trees on disk.

## Gate rules applied (qa.level standard)
- Logic and Integration: a passing automated test under `tests/` is BLOCKING. Smoke: 1551/1551 at `6e487e8`, 0 leak lines.
- UI: a retained screenshot is the gate. Visual/Feel: retained screenshot plus lead sign-off.
- Sign-off rows are read as found. All are unticked except `predicted-hold-bar-evidence.md` (not a sprint-9 story). No sign-off was ticked on the designer's behalf.
- Status words: **READY** (gate met, story may close), **EVIDENCE OK, SIGN-OFF PENDING** (screenshot on disk, designer row unticked; the project has held these In Review, so they stay In Review), **NOT ASSESSED** / **BLOCKED** as stated.
- Presenter and unit tests are support only for UI and Visual/Feel; they are not executed evidence (sprint-007/008 ruling, unchanged).

## Sprint 9 stories (16)

| Story | Status (yaml) | Type | Automated required | Manual required | Blocker |
|---|---|---|---|---|---|
| MF-13 Lobby to round wiring | done | Integration | YES: `tests/integration/match-flow/lobby_to_round_wiring_test.gd` exists, passes | Two-instance step screenshots: 8 png in `evidence/lobby-to-round-wiring/{host,client}/`; evidence row "Lead sign-off" unticked | None for the gate. READY. Designer sign-off advisory. |
| MF-14 Register round stats views | done | Integration | YES: `register_round_stats_views_test.gd` passes | `results.png` retained | None. READY. |
| HUD-1 HudModel, UiLayers, InputContextStack | done | Logic | YES: `tests/unit/hud-results/hud_model_and_ui_layers_test.gd` (plus InputContextStack coverage in the same suite) passes | ADR-0014 verification items 1, 2, 4, 6: NO `evidence/ui-input-focus/` and no `ui-input-focus-evidence.md` on disk | Gate met (Logic = test). CONCERN: the plan's DoD item for ADR-0014 results is open; items 3 and 5 are NOT ASSESSED. |
| HUD-11 Server feeds | done | Integration | YES: `tests/integration/hud-results/hud_server_feeds_test.gd` (real ENet) passes | 2 png in `hud-server-feeds/`; sign-off unticked | None. READY. |
| SD-15 Taser fire input | done | Integration | YES: `tests/integration/survivor-defense/taser_fire_input_test.gd` passes | None required | None. READY. |
| HUD-2 Always-on HUD | review | UI | Support only: `always_on_hud_test.gd` passes | 4 png in `always-on-hud/` (plan asks 3 resolutions); sign-off unticked | Designer sign-off |
| HUD-3 Prompt, ring, reject | review | UI | Support: `prompt_hold_ring_reject_test.gd` | 4 png; unticked | Designer sign-off |
| HUD-4 Own state, state table | review | UI | Support: `own_state_and_hud_states_test.gd` | 4 png; unticked | Designer sign-off |
| HUD-5 Edge cues, taser count, progress | review | UI | Support: `edge_cues_items_progress_test.gd` | 5 png; unticked | Designer sign-off |
| HUD-6 Shapeshifter HUD | review | UI | Support: `shapeshifter_hud_test.gd`; AC-mandated survivor-tree absence: `tests/integration/hud-results/shapeshifter_hud_absence_test.gd` passes | 4 png; unticked | Designer sign-off. BUG-0013 (S4, kit margin 16 px vs 48 px) is a visible defect in this story's screens: its screenshots must be re-captured after the fix. |
| HUD-7 Feed and marker conformance | review | UI | Support: `feed_and_marker_conformance_test.gd` | 3 png; unticked | Designer sign-off |
| HUD-8 Results screen | review | UI | Support: `results_screen_test.gd` | 6 png incl. missing-group; unticked. 500 ms cross-client bound and 150% scale margins noted "not captured" | Designer sign-off |
| HUD-9 Lobby Last round | review | UI | Support: `lobby_last_round_test.gd` | 3 png; unticked | Designer sign-off |
| HUD-10 Budget and accessibility pass | review | UI (measurement) | None | `hud-budget-accessibility-evidence.md` + 44 png. Two sign-off rows unticked (QA lead ruling on font size vs ink height; UX designer accepting BUG-0008..0011) | Designer sign-off. The font-size ruling is mine to make; see Decisions. Item ping shape and 3 text sizes are "not captured" in the evidence. |
| HUD-12 Gamepad bindings | review | UI | Support: `gamepad_bindings_test.gd` | Only 1 png (`prompt-pad.png`); AC2 rests on tested code; unticked | Designer sign-off. Thinnest evidence of the HUD set. |
| MA-11 Client ability input | review | UI | Support: `tests/unit/monster-abilities/client_ability_input_test.gd` | 7 png; unticked | Designer sign-off |
| BF-11 Client form picker | review | UI | Support: `tests/unit/borrowed-face/client_form_picker_test.gd` | 4 png; unticked | Designer sign-off |

Count note: I tabulated 17 sprint-9 rows and 17 carried rows (16 from sprints 7/8 plus pings-11) = 34, against the brief's 33. Recount `sprint-status.yaml` entries; every story id in the yaml is in one of the two tables.

## Carried stories (carried status, nothing changed)

Source: sprint-007 and sprint-008 sign-offs. I checked each evidence page: all sign-off rows are still unticked, so no carried status moves up. No test file was removed.

| Story | Type | Automated | Manual | Carried status |
|---|---|---|---|---|
| MF-11 Client round scene | Integration | PASS (`client_round_scene_test.gd`) | cases not walked; AD-217 | PASS WITH NOTES |
| SD-14 Barricade input | Integration | PASS (`tests/integration/survivor-defense/barricade_doors_test.gd`) | not required; AD-219 | PASS WITH NOTES |
| SE-6 / scare-6 Facility scare state | Integration | PASS only with anchors injected in memory | `data/maps/research_facility.tres` still holds 0 scare entries (grep), so the user's map decision is still pending | BLOCKED (unchanged; FAIL with no workaround if the edit is declined) |
| BF-9 Disguise rendering | Visual/Feel | PASS | 3 png, unticked | NOT ASSESSED |
| BF-10 Transform warp audio | Visual/Feel | PASS | 4 png, two rows unticked incl. listening test | NOT ASSESSED |
| LB-5 Lobby screen | UI | PASS | 6 png, unticked | NOT ASSESSED |
| LB-6 No role indicators | Visual/Feel | PASS | 4 png, unticked | NOT ASSESSED |
| LB-12 Queue order display | UI | PASS | 4 png, unticked; AD-216 | NOT ASSESSED |
| FM-10 Lighting render | Visual/Feel | PASS | 4 png, unticked | NOT ASSESSED |
| FM-11 Surveillance cameras | Visual/Feel | PASS | 11 png, unticked | NOT ASSESSED |
| FM-12 Zone ambience | Visual/Feel | PASS | 3 png, unticked | NOT ASSESSED |
| MA-7 Lunge presentation | Visual/Feel | PASS | 3 png, unticked | NOT ASSESSED |
| SD-11 Per-form presentation | Visual/Feel | PASS | 7 png, unticked | NOT ASSESSED |
| PC-8 / pings-8 Ping callout presentation | UI | PASS (support) | 4 png; speaker gesture (AC-4) not on screen | NO EVIDENCE |
| SE-8 / scare-8 Scare audio | Visual/Feel | PASS (support) | 1 png; AC-2 (+6 dB) unmeasured; no sign-off | NO EVIDENCE |
| SE-9 / scare-9 Scare visuals | Visual/Feel | PASS (support) | png set exists (5 sets under `scare-visuals-accessibility/`); AC-3 beacon and exit-light shots missing; no sign-off | NO EVIDENCE |
| pings-11 Warning pings, feed scrollback | UI | support `warning_pings_feed_scrollback_test.gd` | 3 png; unticked | EVIDENCE OK, SIGN-OFF PENDING (sprint-8 plan) |

## Bugs
| ID | Sev | System | Effect on gate |
|---|---|---|---|
| BUG-0012 | S3 | network | Suite intermittently red (`disconnect_host_left_test.gd`). Fix in flight. Blocks a clean full-suite run, not a story. Do not widen the bound. |
| BUG-0013 | S4 | hud-results | HUD-6 (and anything showing the shapeshifter kit) re-capture after fix. |
| BUG-0001 S4, BUG-0003 S3, BUG-0004 S3 | | outside | On file, no change. |

No S1 or S2 open.

## Manual QA scope for Phase 5
1. Designer walk of the sprint-9 evidence (HUD-2 to HUD-10, HUD-12, MA-11, BF-11, MF-13 optional) in screenshots, not prose.
2. Re-capture HUD-6 after BUG-0013 lands.
3. HUD-12: add pad captures for AC2 if the designer wants more than one image.
4. Carried: case files in `production/qa/test-cases/` for the 4 sprint-8 stories and 12 sprint-7 stories, as listed in the sprint-8 sign-off.
5. Playtests (advisory): lobby to round to Results to lobby with 4 to 5 players; first-round HUD readability.

## Expected verdict if nothing moves
NOT ASSESSED, NO EVIDENCE (same rule as sprints 7 and 8): no S1/S2, no FAIL, but the sprint's UI stories and the carried Visual/Feel stories lack a designer verdict, and pings-8, scare-8, scare-9 are missing captures and scare-6 is blocked. Sprint 9 on its own would be APPROVED WITH CONDITIONS for the 5 done stories only.

## Decisions and concerns
- HUD-10 text-size ruling (font size set in code vs measured glyph height) is a QA lead call. Recommendation: font size set in code is the spec's measure (UI scale applies to it); keep the measured ink height recorded alongside. Needs the QA-lead row ticked by the user, not by me.
- BUG-0003 (S3, killed-server detection 4.3 s vs 3.0 s) and BUG-0012 (S3, killed-host detection 3.77 s / 4.28 s vs 3.017 s) look like the same flake. Recommend `/bug-triage` check for duplication when the BUG-0012 fix lands.
- ADR-0014 verification results (items 1, 2, 4, 6) are not recorded anywhere on disk. Items 3 and 5 report as NOT ASSESSED, not passed.
- No sprint-9 story is a Logic story without a test; no Integration story lacks a passing test.
