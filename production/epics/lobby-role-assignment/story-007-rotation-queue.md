# Story 007: Shapeshifter rotation queue (post-M1)

> **Epic**: Lobby & Role Assignment
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Post-M1 phase. Instead of a random pick, a shuffled queue of session tokens decides who is the shapeshifter, so turns are fair. It advances on Ended, not Cancelled.

**GDD**: `design/gdd/lobby-role-assignment.md`
**Requirement**: `TR-lobby-005`, `TR-lobby-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR: N/A — pure server logic, no architectural pattern required (EPIC.md GDD Requirements)
**ADR Decision Summary**: N/A.
**ADR Version**: N/A

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Plain GDScript with a seeded `RandomNumberGenerator`.

**Control Manifest Rules (this layer)**:
- Required: tests are deterministic (seeded RNG)

---

## Acceptance Criteria

*From `lobby-role-assignment.md` AC-LB-13, AC-LB-15, AC-LB-16, scoped to this story:*

- [ ] With N connected tokens and a seeded RNG before the first round, Q_1 holds each token exactly once, its order is reproducible from the seed, and its head is the shapeshifter.
- [ ] With a stable roster of N = 4, 5 and 6, over 2N rounds reaching Ended (one by forfeit), `shapeshifter(r) = Q_1[(r − 1) mod N]` and every token is the shapeshifter exactly twice.
- [ ] After a Cancelled round the queue is unchanged, the same token is the shapeshifter, and character assignment runs again.

---

## Implementation Notes

*Derived from `lobby-role-assignment.md` Formulas (rotation queue) and rule 10:*

- Replaces Story 002's M1 random pick behind the same function.

---

## Out of Scope

- Story 008: absent and reconnecting tokens

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/lobby/rotation_queue_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002; network-authority story 002 (tokens)
- Unlocks: Stories 008, 012
