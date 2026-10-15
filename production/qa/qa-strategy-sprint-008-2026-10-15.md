# QA Strategy: Sprint 8 (Phase 2)
**Date**: 2026-10-15
**Author**: qa-lead (team-qa Phase 2)
**Inputs**: story headers, ACs, Test Evidence and Progress Notes for PC-1..8 and SE-1..9; `qa-plan-sprint-008-2026-10-15.md`; `smoke-2026-10-15-sprint-008.md`
**Scope**: 17 stories. PC-9 (proximity voice) is Blocked and out of scope.
**Config**: `qa.level: standard`. Logic/Integration need passing automated tests. Visual/Feel need a retained screenshot plus lead sign-off. UI needs retained screenshots. Not waived at any level: the screenshots.
**Constraint**: Manual QA cannot run this session (designer away). No sign-off, answer or checkbox is filled in on anyone's behalf.

---

## Strategy Table

Automated Required: the test file must exist and pass (all do, 1393/1393 at `2fe161d`). "Blocker?" means it blocks setting the story Complete.

| Story | Status | Type | Automated Required | Manual Required | Blocker? |
|---|---|---|---|---|---|
| PC-1 Ping validation, token bucket | Complete | Logic | `tests/unit/pings-and-callouts/ping_validation_token_bucket_test.gd` (exists, passes) | None | No |
| PC-2 Sender-state gating | Complete | Logic | `sender_state_gating_test.gd` (exists, passes) | None | No |
| PC-3 Callout limits, attached ping | Complete | Logic | `callout_limits_attached_ping_test.gd` (exists, passes) | None | No |
| PC-4 Ping recipients, delivery | Complete | Integration | `tests/integration/pings-and-callouts/ping_recipients_delivery_test.gd` (real ENet) | Smoke path 5 (done) | No |
| PC-5 Marker lifecycle | Complete | Logic | `marker_lifecycle_test.gd` (exists, passes) | None | No |
| PC-6 Callout recipients | Complete | Integration | `callout_recipients_delivery_test.gd` | Smoke path 5 (done) | No |
| PC-7 Identity and fake parity | Complete | Integration | `identity_fake_parity_test.gd` | Smoke path 5 (done); playtest: is "(not you)" within `callout_range_m` too strong a reveal (GDD rule 28, playtest-gated) | No (playtest is advisory input to a design decision) |
| PC-8 Ping and callout presentation | In Review | UI | `ping_callout_presentation_test.gd` (9 cases, support only; passes) | Retained screenshots of each screen touched (4 png exist) + designer sign-off | **Yes**: sign-off pending; AC-4 (speaker gesture) has no on-screen capture, unit test only |
| SE-1 Scare catalogue and module | Complete | Logic | `tests/unit/scare-events/scare_catalogue_module_test.gd` | None | No |
| SE-2 Per-recipient gating | Complete | Logic | `per_recipient_gating_test.gd` | None | No |
| SE-3 Scoped delivery, hallucinations | Complete | Integration | `tests/integration/scare-events/scoped_delivery_hallucinations_test.gd` (real ENet) | Smoke path 6 (done) | No |
| SE-4 Monster-source scares | Complete | Integration | `monster_source_scares_test.gd` | Smoke path 6 (done) | No |
| SE-5 Ambush lunge and flinch | Complete | Integration | `ambush_lunge_flinch_test.gd` | None | No |
| SE-6 Facility scare state, RoundScript | In Review | Integration | `facility_scare_state_roundscript_test.gd` (5 cases, 2 over real ENet; passes; ACs all ticked) | None for the test. Needs the user's decision on the map edit, then a real-round check that a scare fires at an authored anchor | **Yes**: shipped `research_facility.tres` has no scare anchors (sd1-sd6, sg1-sg3), so RoundScript scares never fire in a real round. The test passes only because it injects anchors in memory |
| SE-7 Presentation-only guarantees | Complete | Integration | `presentation_only_scares_test.gd` | None | No |
| SE-8 Scare audio | In Review | Visual/Feel | `scare_audio_test.gd` (7 cases, support only; passes) | Retained screenshot (`scare-audio/scare.png` exists) + measured levels + headphone listening + designer sign-off | **Yes**: AC-2 (stinger at most +6 dB over bed) is unproven. Same bed read -4.0 dB and -0.4 dB between runs, so the gap was +8.0 or +4.4 dB. A peak meter cannot settle it. Sign-off unchecked |
| SE-9 Scare visuals, flash accessibility | In Review | Visual/Feel | `scare_visuals_accessibility_test.gd` (5 cases, support only; passes) | Retained screenshots (`framed1/`, `framed0/`, `hall/`) + frame-sampled flash rate + designer sign-off | **Yes**: AC-3 partly unmet. Rotating beacons light no floor in H-S1. Exit light off in every shot. Sign-off unchecked |

Summary: 13 Complete with no blocker. 4 In Review (PC-8, SE-6, SE-8, SE-9), all 4 blocked.

---

## Smoke verdict

PASS WITH WARNINGS (`production/qa/smoke-2026-10-15-sprint-008.md`). The build is cleared for manual QA. Paths 1-6 pass and path 7 is not applicable. Warnings: `commands.build` and the export preset are unset (EX-1). The tracked `.godot/global_script_class_cache.cfg` is stale, so a fresh checkout needs `--import` before it boots (designer's call whether to track it). Designer decisions AD-216, AD-217 and AD-219 are pending. Some full-suite runs failed once when real-ENet suites ran concurrently (`proximity_voice_replication_test`, `round_composer_test` five-client case). Each passed alone and the full runs with no agents active were clean. Treat that as a load-sensitivity risk, see BUG-0003.

## Open bugs

0 in the scoped systems (Pings & Callouts, Scare Events). On file elsewhere: BUG-0001 S4 (net_check route mode), BUG-0003 S3 (real-ENet timing), BUG-0004 S3 (controller tick budget). No open S1 or S2. At `standard`, open S3/S4 do not block. BUG-0003 is the one to watch, since 5 of the sprint's Integration suites run over real ENet.

---

## Manual session estimate

All of it requires the designer present and is not executable this session. Rough total: **4 to 5 hours** designer-and-QA time, plus 2 short playtests.

| Item | Est. | Notes |
|---|---|---|
| PC-8 UI review | 0.5 h | Review 4 png against 4 ACs; ask for a new capture of the gesture (AC-4). Optionally re-run `round_view --bot=ping` for longer than the earlier run to settle the "5 pending at quit" question |
| SE-8 audio | 1.5 h | Headphone listening (direction/distance, wind-up and distortion at full level) plus a LUFS measurement of recorded audio for AC-2 |
| SE-9 visuals | 0.75 h | Review frame-sampled strobe (at most 3/s), scale 0 pair, hallucination shot. Needs a beacon and exit-open capture |
| SE-6 real-round check | 0.5 h | After the map decision: confirm a scare fires at an anchor in a real round |
| Playtest A (PC-7) | 1 session | Experienced player; "(not you)" reveal strength |
| Playtest B (SE-8/SE-9) | 1 session | New player; do scares land without masking gameplay cues. Notes to `production/session-logs/playtest-sprint-008-[slug].md` |

---

## Blockers

1. **SE-6, user decision**: approve adding the 9 `scare_anchor` markers to `data/maps/research_facility.tres`, plus `&"scare_anchor"` in `MapData.MARKER_TYPES` and the marker counts in `tests/integration/facility-map/map_data_test.gd`. Positions are inferred from the level doc, not sourced. Until then SE-6 cannot be Complete: the feature is dead in a real round even though its test passes. The decision belongs to the user (a prior edit was refused by the permission check). Also correct the PC/SE-6 story file: header says In Review while all ACs are ticked, which is consistent, but record the dependency.
2. **SE-8 AC-2 unproven**: needs a LUFS measurement of recorded audio, or final assets authored to the bed level. Peak meter cannot prove it. Owner: audio/sound designer with the designer's sign-off. Placeholder-audio sign-off must be re-verified when final audio and the AudioDirector land.
3. **SE-9 beacon gap**: Facility Map placement follow-up (`LightingPresenter` beacons clipped by ceiling height and range). Also needs an exit-open capture for the "exit still readable" half of AC-3. Owner: level/lighting designer.
4. **PC-8 AC-4**: gesture is unit-tested only; an on-screen capture is needed for the UI evidence gate.
5. **Sign-off on SE-8, SE-9, PC-8**: designer, pending. Unchecked and left unchecked.

## Concerns (non-blocking)

- Dropped pings (per-tick cap) get no rejection echo, so a modified client's pending marker would stay forever (PC-4/PC-8). Recommend a bug report.
- `SightTest` at 360 degrees can refuse a point exactly behind the sender (PC-4).
- Stinger shows on its bus one frame before the 3D origin sound: rule 17 "covers the origin" question for the designer (SE-8).
- Unsourced constants in SE-8 and SE-9 (tone lengths, `HALLUCINATION_S`, `STROBE_ON_S`). Mark as inference, settle with the designer.
- The SE-9 hallucination's server trigger (viewing the monitor) is not built. Only the `round_host` force fires it.
- PC-8 leftovers: warning pings, feed scrollback key, extra wheel modes, screen-reader live region (accessibility gap).
- Stale class cache plus real-ENet test load-sensitivity are build-health risks for anyone running the suite on a fresh checkout or alongside other agents.
- Four orphaned `.claude/worktrees` directories (`wt-bf9`, `wt-fm12`, `wt-mf11`, `wt-sd4`) remain; deleting them was refused by the permission check.

## Verdict

Sprint 8 cannot be signed off this session. Logic and Integration evidence is complete. The 4 In Review stories need the designer and the items above. Hand-off: run `/smoke-check` again after the map decision, then direct qa-tester through the PC-8, SE-8, SE-9 checklists in the QA plan.
