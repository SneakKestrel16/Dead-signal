# Gate Check: Systems Design → Technical Setup

**Date**: 2026-10-12
**Checked by**: gate-check skill (workflow: standard, review_mode: lean, qa.level: standard)

## Required Artifacts: 2/3 met

- [x] `design/gdd/systems-index.md`: 15 systems, 11 MVP
- [ ] All MVP-tier GDDs exist and pass `/design-review`: **not met**. 7 of 11 MVP systems have an Approved GDD (Match Flow, Survivor Objectives, Downing Rescue & Elimination, Survivor Defense, Borrowed Face, Monster Abilities, Facility Map). Two are designated elsewhere in the index: Network Authority & Replication (ADRs) and HUD & Results Screen (`/ux-design`). Two have no GDD and no designation:
  - Lobby & Role Assignment (#2); Match Flow depends on it
  - First-Person Controller & Interaction (#3); approved GDDs depend on its walk speed, survivor collision radius (Monster Abilities dodge-window formula) and hold-to-interact pattern
- [x] Cross-GDD review report (recommended at `standard`): latest `design/gdd/gdd-cross-review-2026-10-12c.md`, CONCERNS

## Quality Checks: 5/6 passing

- [x] All 8 GDDs have all 8 sections; all Approved in the index
- [x] Latest `/review-all-gdds` verdict is CONCERNS, not FAIL
- [x] Flagged cross-GDD issues resolved (30af36a), except advisory D2 (monster attention load), tracked for the M5 playtest
- [x] Dependencies mapped and bidirectional (30af36a)
- [x] MVP priority tier defined
- [ ] No stale references: GDDs cite walk speed and collision radius as owned by a Controller GDD that does not exist

## Director Panel Assessment

Technical Director: CONCERNS
  The systems index event and state tables plus the 8 GDDs are enough to architect from. Lobby is mostly session plumbing shaped by the Network Authority ADRs. The Controller's authority and prediction model is an architecture decision and can be specified during Technical Setup, but its design values must be pinned before Pre-Production. Neither should block.

Producer: CONCERNS
  Both are Core systems on the Milestone 1 critical path. If the controller numbers stay scattered, the ADRs get written against assumptions. Small fix, about 0.5–1 day each (estimate, no velocity data), before or alongside the ADRs.

Panel: 2 of 4 (`workflow: standard`). Creative and Art perspectives not consulted.

## Blockers

1. No GDD or designation for Lobby & Role Assignment: `/design-system lobby-role-assignment`.
2. No GDD or designation for First-Person Controller & Interaction: `/design-system first-person-controller`.

## Recommendations

- Then `/design-review` each, and re-run `/gate-check technical-setup`.
- The previous gate's accepted risks are still open: no concept review, no Visual Identity Anchor, no prototype. Technical Setup is the cheapest place for a networking spike.

## Verdict: FAIL

Both directors rated these two gaps CONCERNS. The gate file still requires every MVP GDD at `standard`, so the required item is unmet. Stage stays at Systems Design.

Chain-of-Verification: 5 questions checked, verdict unchanged.

Designer decision (2026-10-12): write two lean GDDs (Lobby & Role Assignment, First-Person Controller & Interaction), review them, then re-run this gate.
