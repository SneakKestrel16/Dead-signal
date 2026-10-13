# Gate Check: Pre-Production → Production

**Date**: 2026-10-13
**Checked by**: gate-check skill (`workflow: standard`, `review_mode: lean`, `qa.level: standard`)

### Required Artifacts: 8/8 present
- [x] Sprint plan: `production/sprints/sprint-001.md` (U1 two-PC test and U2 ADR acceptance done 2026-10-13)
- [x] Epics with Foundation and Core layers: 3 Foundation epics (21 stories, all Ready), 4 Core epics (stories not yet created); `production/epics/index.md`
- [x] Stories: 21 under `production/epics/`, 0 Blocked
- [x] Master architecture document: `docs/architecture/architecture.md`
- [x] At least 3 Foundation ADRs: ADR-0001 to ADR-0006
- [x] All Foundation and Core ADRs Accepted: ADR-0001 to ADR-0008 Accepted 2026-10-13 (designer)
- [x] MVP GDDs complete: `gdd-structure-check.sh` shows the 5 standard sections in every system GDD (Player Fantasy / Tuning Knobs absent in two, optional at `standard`)
- [x] ADRs carry Engine Compatibility and ADR Dependencies sections (15/15)

### Recommended Artifacts (absent = CONCERNS)
- [x] Control manifest: `docs/architecture/control-manifest.md` (2026-10-13)
- [ ] Art bible: absent (`design/art/art-bible.md`)
- [ ] Entity inventory: absent
- [~] UX specs for key screens: HUD and results exist; no main menu or pause menu spec
- [~] `/ux-review`: HUD reviewed NEEDS REVISION and fixed, re-run not done; results not reviewed
- [ ] Vertical slice build, playtest session and report: none (not built; skipped, not failed)

### Quality Checks
- [ ] Core loop fun validated: no playtest (slice not built) — CONCERNS
- [ ] Core fantasy delivered (playtester description): not assessable without a slice — CONCERNS
- [x] Sprint plan references real story files
- [x] Architecture has no unresolved Foundation/Core open question that blocks: the remaining bullet ("4.7 networking beyond the spike", module doc refresh) is an accepted risk backed by the WAN spike
- [x] Stale lines fixed during the gate: `architecture.md` pursuit-rerun note, `systems-index.md` row 1 status
- Tests: gdUnit4 installed, no tests yet (no code); not required at this gate

### Director Panel Assessment
Panel: 2 of 4 (`workflow: standard`, from `modes.rigor: standard`). Creative and Art perspectives not consulted. Raise `modes.rigor` to `full` for the complete panel.

Technical Director: CONCERNS
- Required set met; WAN results back ADR-0002/0003.
- "4.7 networking beyond the spike" still tagged ADR-0001; refresh the networking module doc or keep it as an accepted risk before NA stories go past the spike.
- Narrow margins: dodge 27 ms (`accel_time_s` ≤ 0.095 s); WAN RTT p95 120 ms above the ~113 ms full-compensation bound. Keep the dodge AC as a regression test.
- Drift and Wi-Fi tests skipped: record in a risk register.
- ADR-0009..0015 must be Accepted before their systems' first stories go Ready.

Producer: CONCERNS
- Sprint 001 realistic (7 of 8 days, buffer kept).
- No milestone, no risk register.
- Core epics need stories before Sprint 2 (2026-10-27).
- No velocity yet; treat Sprint 1 as calibration.
- AD-01..AD-37 still Pending designer review.

### Blockers
None.

### Verdict: CONCERNS

Chain-of-Verification: 5 questions checked — verdict unchanged.
1. Could a concern be a blocker? No: every missing item is recommended at `standard` (gate file tier table); the slice was skipped, not built and failed.
2. Resolvable in the next phase? Yes, apart from compounding risk if no slice is built before Feature work: the producer's recommendation (first milestone = vertical slice) addresses it.
3. A FAIL softened? No: re-scanned blocked stories [TOOL ACTION: grep `Status: Blocked` under `production/epics` → 0].
4. Unchecked artifacts? Re-checked UX spec content [TOOL ACTION: `hud.md` 13 sections, `results.md` 15], and the architecture open-question line [TOOL ACTION: grep line 423].
5. Together blocking? No: required set complete; the concerns cluster on validation of fun and presentation, which a slice milestone covers.

### Accepted Risks
Auto-accepted (recommended option: advance on CONCERNS), 2026-10-13. The designer asked to "continue work until it hits production" and has a standing instruction to auto-accept recommended decisions at gates (AD-54). Each risk below is accepted:
- No art bible or entity inventory — 2026-10-13
- No main menu or pause menu UX spec; HUD ux-review re-run and results ux-review outstanding — 2026-10-13
- No vertical slice, playtest or validated core-loop fun — 2026-10-13
- No milestone or risk register; no velocity — 2026-10-13
- Core epics have no stories yet — 2026-10-13
- Drift and Wi-Fi network tests skipped; 4.7 networking doc not refreshed — 2026-10-13
- Narrow dodge (27 ms) and compensation (~113 ms RTT) margins — 2026-10-13
- AD-01..AD-53 pending designer review — 2026-10-13

### Recommendations
1. Define milestone 1 as the vertical slice (`/vertical-slice` or `/sprint-plan` with a milestone), with a risk register.
2. `/create-stories` for the four Core epics before Sprint 2.
3. `/art-bible`, then `/ux-design` main menu and pause, `/ux-review` hud and results.
