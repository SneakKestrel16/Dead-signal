# Gate Check: Systems Design → Technical Setup (re-run)

**Date**: 2026-10-12
**Checked by**: gate-check skill (workflow: standard, review_mode: lean, qa.level: standard)
**Previous run**: `2026-10-12-systems-design-to-technical-setup.md` (FAIL: Lobby and Controller GDDs missing)

## Required Artifacts: 3/3 met

- [x] `design/gdd/systems-index.md`: 15 systems, 11 MVP
- [x] All MVP-tier GDDs exist and pass `/design-review`: 9 Approved (Match Flow, Survivor Objectives, Downing Rescue & Elimination, Survivor Defense, Borrowed Face, Monster Abilities, Facility Map, First-Person Controller (re-review, 2026-10-12), Lobby & Role Assignment (2026-10-12)). Network Authority & Replication is designated to ADRs, HUD & Results Screen to `/ux-design`.
- [x] Cross-GDD review report (recommended at `standard`): `design/gdd/gdd-cross-review-2026-10-12c.md`, CONCERNS. It predates both new GDDs and the 4–6 player decision.

## Quality Checks: 5/6 passing

- [x] Every MVP GDD has the 5 standard sections plus Formulas (`gdd-structure-check.sh`)
- [x] Latest `/review-all-gdds` verdict is CONCERNS, not FAIL
- [x] Issues it flagged are resolved (30af36a); advisory D2 tracked for the M5 playtest
- [x] Dependencies mapped and bidirectional, including Lobby and Controller back-references in Match Flow (d373070)
- [x] MVP priority tier defined
- [ ] Stale reference: `monster-abilities.md` dodge example uses a 4.5 m/s strafe and radius 0; the Controller pins 4.0 m/s and r 0.3 (Open Question in both)

## Director Panel Assessment

Technical Director: CONCERNS
  Both new GDDs are enough to architect from. The cross-GDD review predates them and the 4–6 player change; re-run it before the Network ADRs. Up to 6 players moves the replication bandwidth and tick budget envelope to 6. Fix the Monster Abilities dodge example before an ADR relies on it.

Producer: CONCERNS
  Both prior blockers cleared. Re-run `/review-all-gdds`; the Controller's server-cost AC profiles 5 players, worst case is now 6. The 4–6 change does not break Pillar 5's literal test but turns one balance point into three. Recommends 4–6 in code, one tuned configuration for MVP, the rest capped in config until Milestone 5; C5 assets are the one cost that cannot be deferred.

Panel: 2 of 4 (`workflow: standard`). Creative and Art perspectives not consulted. Set `modes.workflow: full` for the complete panel.

## Blockers

None.

## Recommendations

1. Re-run `/review-all-gdds` to cover Lobby, Controller and the 4–6 player propagation.
2. Fix the `monster-abilities.md` dodge example (4.0 m/s, r 0.3) and rerun its check.
3. Size network and performance budgets for 6 players; update the Controller's performance AC (`first-person-controller.md`) from 5 to 6 players.
4. Earlier accepted risks stay open: no concept review, no Visual Identity Anchor, no prototype. A networking spike is the cheapest way to reduce the largest technical risk.

## Verdict: CONCERNS

Chain-of-Verification: 5 questions checked, verdict unchanged. Every concern is resolvable within Technical Setup; no FAIL condition was softened.

## Designer decisions (2026-10-12)

- **Stage**: not advanced. Fix recommendations 1 and 2 first, then re-run this gate. Stage stays at Systems Design.
- **MVP scope**: 4–6 players in code; the MVP config sets `min_players` = `max_players` = 5, so only the tuned 1 vs 4 round is played until Milestone 5. C5 stays budgeted (`lobby-role-assignment.md`).
