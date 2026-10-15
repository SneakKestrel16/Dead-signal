# Story 010: Round composer (server composition root)

> **Epic**: Match Flow & Win Conditions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 2 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15


## Context

Every Feature module merged so far exposes injection hooks that only tests wire, so no real round can run. This story adds the one composition root that builds every module for a round and wires every cross-module hook, so a host runs a full server round end to end. Decided by the user (AD-201).

**GDD**: `design/gdd/match-flow.md` (round lifecycle); hooks named in the Completion Notes of Borrowed Face, Downing & Rescue, Survivor Objectives, Survivor Defense and Monster Abilities stories
**Requirement**: `TR-matchflow-001` (round lifecycle), plus every Feature epic's wiring notes

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order (composition root, no gameplay autoloads); secondary: ADR-0002, ADR-0004, ADR-0007, ADR-0008
**ADR Decision Summary**: Services are injected by a composition root, never autoloads; modules register in fixed `TickOrder` slots through `RoundServer.start_round`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Back-references from modules to the composer are WeakRef or Callable; no inner class extends a sibling inner class (exit-leak gotcha, `docs/engine-reference/godot/gotchas.md`).

**Control Manifest Rules (this layer)**:
- Required: modules register with `TickRunner` through `RoundServer.start_round({TickOrder.X: module}, knobs)` (ADR-0005)
- Forbidden: no gameplay autoloads; the composer adds no gameplay rules of its own (ADR-0005)
- Guardrail: every tuning value comes from the loaded knobs

---

## Acceptance Criteria

- [x] One composer (e.g. `src/feature/match_flow/round_composer.gd`) builds every round module from the loaded map and knobs: Doors, HoldService, Downing, Borrowed Face, Survivor Objectives, Match Flow, Survivor Defense, HidingSpots, Barricades (with BarricadeBreak), Monster Abilities, ServerMovement and LagCompensation, and starts them through `RoundServer.start_round`.
- [x] Every cross-module hook is wired, and a test audits that none is left unset. At minimum:
  - `set_form_source`, `set_hit_sources`, `set_position_source`, `set_attack_source` (LungeView), `set_appearance_source`, `set_status_source`, `set_sight_source`;
  - `HoldService.set_barred` combining Borrowed Face's Transforming bar with the shock lock;
  - SurvivorObjectives' `is_healthy` folding in `not is_hidden`;
  - the Barricades `monster` Callable folding in `not locked`;
  - `ServerMovement.flashlight_of`, and every `batch_extras` and `catch_up` provider (ring, objective display, charges, hiding, barricade).
- [x] A scripted headless round runs over real ENet with 5 clients from Loading to `RoundEnded`, with no engine errors and no leak lines. Along the way, real requests produce at least one lunge down, one taser stun, one hide and one barricade, and objective progress. The test is bounded, and its timing bounds are never widened (BUG-0003).
- [x] A host started from `net_check.tscn` `--role=host` (or a new headless entry) runs the composed round. Smoke QA path 4 then has a standalone script, not just a test.

---

## Implementation Notes

- Take the wiring from the tests that already compose these modules. `tests/integration/monster-abilities/lunge_end_to_end_test.gd`, `tests/integration/survivor-defense/five_client_agreement_test.gd` and `tests/integration/borrowed-face/disguise_gates_test.gd` each wire a subset. Move that wiring into the composer and make those tests use it where it fits.
- Doors needs the first net ids (a door's net id is its map index). Allocate the other interactables after the doors.
- Inference: the composer belongs to Match Flow because Match Flow owns the round lifecycle. A designer could move it to `src/core/session/` without changing any rule.

## Out of Scope

- Client rendering of the round: story 011.
- Replaying display state to reconnecting clients: story 012.

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/match-flow/round_composer_test.gd`
**Status**: [x] `tests/integration/match-flow/round_composer_test.gd`; standalone `tests/manual/round_host.gd --self-clients` exit 0, RoundEnded, 0 engine errors, no leak lines (re-run by orchestrator 2026-10-15 at 0bea5c5)

## Dependencies

- Depends on: every merged Feature module (all Complete)
- Unlocks: match-flow story 011 (client round scene), playtests, LB-6, the CI-16 240 fps capture

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-218):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 1189/1189 after the wave merge, no leak warnings.
- The first standalone run produced 48 client errors (Node not found Hidden/Spawner): self-clients built no HiddenSpawner. Fixed in MF-11 (0bea5c5), which also moved round_host to MapGreybox floors, distinct appearances 1 + id % 5 and knobs.join_version.
- Non-door holds were unreachable from real clients until AD-217 (interact_target = map index); the composer's _aim maps the index to the eligible hold.
- Composer lives in Match Flow (inference: Match Flow owns the round lifecycle; moving it to src/core/session changes no rule).
**Test Evidence**: Audit test over every hook; scripted 5-client real-ENet round to RoundEnded with lunge down, taser stun, hide, barricade and objective progress.
**Code Review**: Complete (orchestrator review at merge)
