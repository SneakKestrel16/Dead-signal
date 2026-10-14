# Story 010: Clash fairness and preference changes while Ready (post-M1)

> **Epic**: Lobby & Role Assignment
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Post-M1 phase. Clash resolution must be uniformly fair over many trials, and a Ready player cannot change preference.

**GDD**: `design/gdd/lobby-role-assignment.md`
**Requirement**: `TR-lobby-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR: N/A — pure server logic, no architectural pattern required (EPIC.md GDD Requirements)
**ADR Decision Summary**: N/A.
**ADR Version**: N/A

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Seeded `RandomNumberGenerator`; keep the 10,000-trial tests under a second each.

**Control Manifest Rules (this layer)**:
- Required: tests are deterministic (seeded RNG)

---

## Acceptance Criteria

*From `lobby-role-assignment.md` AC-LB-10, AC-LB-11, AC-LB-20, scoped to this story:*

- [ ] Over 1,000 seeded preference sets at each of 3, 4 and 5 survivors (including all prefer C1), every result is distinct, a sole claimant always keeps their pick, and every survivor holds exactly one character.
- [ ] For k = 2, 3 and 5 claimants of one character over 10,000 fixed-seed trials, each keeps it in 1/k ± 0.02 of trials, and a loser is dealt each free character in 1/|free| ± 0.02 of their losses.
- [ ] A Ready player's preference change is rejected; after un-readying it is accepted.

---

## Implementation Notes

*Derived from `lobby-role-assignment.md` Formulas (Character assignment) and rule 8:*

- ±0.02 is over 4σ at these counts (GDD), so the seeded test is stable.

---

## Out of Scope

- Preference UI (Story 012)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/lobby/character_fairness_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 009
- Unlocks: none
