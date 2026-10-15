# Story 009: Character preferences and clash resolution (post-M1)

> **Epic**: Lobby & Role Assignment
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

Post-M1 phase. Each player keeps a preferred character for the session. Distinct picks are honoured; clashes are settled at random and losers are dealt free characters.

**GDD**: `design/gdd/lobby-role-assignment.md`
**Requirement**: `TR-lobby-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR: N/A — pure server logic, no architectural pattern required (EPIC.md GDD Requirements)
**ADR Decision Summary**: N/A.
**ADR Version**: N/A

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Seeded `RandomNumberGenerator`.

**Control Manifest Rules (this layer)**:
- Required: tests are deterministic (seeded RNG)

---

## Acceptance Criteria

*From `lobby-role-assignment.md` AC-LB-07, AC-LB-08, AC-LB-09, AC-LB-12, scoped to this story:*

- [x] A new player gets a preference from C1–C5 chosen by the seeded RNG, unchanged after 3 rounds.
- [x] Distinct preferences: every survivor gets their pick.
- [x] Preferences C1, C1, C2, C4, C4 with a fixed seed: C2 keeps C2, one C1 claimant keeps C1, one C4 claimant keeps C4, the two losers get {C3, C5}; all five distinct.
- [x] A shapeshifter preferring C3 gets no character, a survivor may get C3, and the preference is still C3 next round.

---

## Implementation Notes

*Derived from `lobby-role-assignment.md` Formulas (Character assignment):*

- Replaces Story 003's random deal behind the same function.

---

## Out of Scope

- Story 010: fairness statistics and preference-change rule

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/lobby/character_preferences_test.gd` — must exist and pass

**Status**: [x] `tests/unit/lobby/character_preferences_test.gd` (8 tests)

---

## Dependencies

- Depends on: Story 003
- Unlocks: Story 010

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: all passing (automated)
**Deviations** (AD-141):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 748/748 after the wave merge, no leak warnings.
- `LobbyState` takes an optional RNG and draws a joiner's preference on first join; `set_preference` is the bare setter (Ready lock is story 010).
- A rejoiner keeps their preference: inference from TR-lobby-004; a designer ruling on rule 17 settles it.
- `LobbyState.new(knobs)` without an RNG is unseeded; production must pass a seeded one. `rotation_queue_test` now seeds its lobby.
**Test Evidence**: 8 tests. Mutations caught: first claimant always wins, losers dealt from all characters, preference redrawn on rejoin.
**Code Review**: Complete (orchestrator review at merge)
