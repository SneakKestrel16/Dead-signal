# Story 003: Character data and M1 character assignment

> **Epic**: Lobby & Role Assignment
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Five survivor characters C1–C5 are defined in data. In phase M1 each survivor is dealt a distinct one at random; the shapeshifter has none.

**GDD**: `design/gdd/lobby-role-assignment.md`
**Requirement**: `TR-lobby-006`, `TR-lobby-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Data-driven configuration
**ADR Decision Summary**: Typed `Resource` data validated at load, loaded by fixed name; lobby limits (min/max players, countdown, name length) in `LobbyKnobs`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `Resource` and `.tres` stable since 4.0.

**Control Manifest Rules (this layer)**:
- Required: gameplay values from data
- Forbidden: hardcoded gameplay values

---

## Acceptance Criteria

*From `lobby-role-assignment.md` AC-LB-06 and the M1 delivery note in TR-lobby-010, scoped to this story:*

- [ ] The character data defines exactly 5 survivor characters C1–C5, each with a distinct look, colour and voice-set ID; the shapeshifter's true-form model is none of them.
- [ ] With a fixed seed and 3, 4 and 5 survivors, every survivor gets exactly one character and all are distinct; the shapeshifter gets none.
- [ ] `LobbyKnobs` loads `min_players`, `max_players`, `lobby_countdown_s` and name length limits and validates their ranges.

---

## Implementation Notes

*Derived from ADR-0006 and `lobby-role-assignment.md` Character assignment formula:*

- `CharacterDef` resource per character under `res://data/characters/`.
- Preference-based assignment replaces the random deal in Story 009.

---

## Out of Scope

- Story 009: preferences and clash resolution

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-003-2026-10-14.md` (/qa-plan, 2026-10-14). Implement against these and the Acceptance Criteria above.*

**What to test**:
- Character data defines exactly 5 survivor characters C1–C5, each with distinct look, colour and voice-set ID; the true-form model is none of them.
- Fixed seed, 3, 4 and 5 survivors: each survivor gets exactly one character, all distinct; shapeshifter gets none.
- `LobbyKnobs` loads `min_players`, `max_players`, `lobby_countdown_s`, name length limits and rejects out-of-range values.

**Edge cases to cover**:
- Cancelled round: characters are redrawn (lobby-role-assignment Edge Cases); test that a second deal with a new seed is valid.
- `min_players` > `max_players` rejected.

**Estimated test count**: ~6 unit tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/lobby/character_assignment_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: data-config story 002
- Unlocks: Stories 002, 009; borrowed-face epic
