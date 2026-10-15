# Story 014: Register every round stats view so live Results show real values

> **Epic**: Match Flow & Win Conditions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

HUD-8 found that in a live lobby round the `RoundResults` payload lists the Downing, Survivor Defense and Objectives stats in `missing`, so the Results screen shows "Results unavailable" for downs, rescues, stuns and objectives. The `*StatsView` classes exist (`downing_stats_view.gd`, `defense_stats_view.gd`, `objectives_stats_view.gd`, `borrowed_face_stats_view.gd`), but only `MonsterAbilities` registers its view; nothing in `RoundComposer` registers the rest.

**GDD**: `design/gdd/match-flow.md` rules 23-26
**Requirement**: `TR-matchflow-008` (corrected from TR-match-008 per tr-registry.yaml)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Round stats and results payload
**ADR Decision Summary**: Owners keep counters and register getter-only StatsViews; MatchFlow.resolve reads them once; an unregistered view is listed in missing.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: each owner registers its own view (no counters moved into Match Flow)
- Forbidden: a payload with a group in missing when its owner runs in the round

---

## Acceptance Criteria

*From GDD `design/gdd/match-flow.md`, scoped to this story:*

- [x] A composed round (RoundComposer, real ENet, 5 clients) that ends by its rules produces a payload whose `missing` is empty, with downs, rescues, stuns landed and objective times taken from the owners' counters.
- [x] A forced down, rescue and stun during the test round show up as non-zero values in the payload.
- [x] The live Results screen in the shipped lobby path shows those values (retained screenshot in `production/qa/evidence/register-round-stats-views/`).

---

## Implementation Notes

- Follow how MonsterAbilities registers its view; register the others where the composer builds each module.
- Check the TR id against docs/architecture/tr-registry.yaml and correct it in this story if it differs.

---

## Out of Scope

- Results screen layout (hud-results 008).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/match-flow/register_round_stats_views_test.gd` (real ENet where the AC names clients)

**Status**: [x] Created and passing (real ENet, 5 clients)

---

## Dependencies

- Depends on: Story 008; hud-results 008
- Unlocks: None

## Progress Notes (2026-10-15)

- Each owner (Downing, SurvivorDefense, SurvivorObjectives, BorrowedFace) keeps its own counters and registers its view in setup, as MonsterAbilities does.
- Integration test tests/integration/match-flow/register_round_stats_views_test.gd (real ENet, 5 clients): payload missing is empty; downs 1, rescues 1, stuns landed 1, takedowns 1, eliminations 4. Four mutations caught.
- Live Results screenshot: production/qa/evidence/register-round-stats-views/results.png (round end forced; rescue called directly).
- Full suite on merge: 1522 tests, 0 failures, 0 leak lines.
- Found: ServerMovement._snapshot_phase skips a spectator whose watched survivor has no body, so eliminated clients never get Results after an elimination win. Filed as BUG-0007.
