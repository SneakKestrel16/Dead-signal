# Story 003: Callout acceptance limits and attached item ping

> **Epic**: Pings & Callouts
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Callouts have a per-player global cooldown and a per-line repeat block. "Drive here" and "Fuse here" may attach an item ping, which spends a ping token. A False Signal fake callout touches no limit state at all.

**GDD**: `design/gdd/pings-and-callouts.md` rules 9, 13, 16, 17; Formulas: callout acceptance
**Requirement**: `TR-pings-003`, `TR-pings-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative simulation, tick rate and input; secondary: ADR-0006
**ADR Decision Summary**: Callouts are client intents validated on the server; limits are data.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: `callout_global_cooldown_s` and `callout_repeat_block_s` come from `PingKnobs`
- Forbidden: never let a fake callout write limit state

---

## Acceptance Criteria

*From GDD `design/gdd/pings-and-callouts.md`, scoped to this story:*

- [x] The same callout sent twice within 8 s is delivered once; after a callout at t=0, a different callout at t=1 is rejected and one at t=3 is accepted. Only accepted callouts update `last_callout_any` and `last_callout[line]`.
- [x] "Drive here" with an attached item ping spends one ping token in addition to the callout; with 0 tokens the callout plays without the attached ping.
- [x] A fake callout leaves the impersonated survivor's and the monster player's callout cooldowns and ping tokens unchanged: the survivor's same-line callout sent 1 s after the fake is accepted.
- [x] A False Signal fake callout never carries an attached item ping.

---

## Implementation Notes

- The 8 lines are authored data (rule 9); store them as a data resource, not string literals in code.
- A fake callout arrives as `AbilityUsed` with signal type CALLOUT from Monster Abilities (`monster_abilities.gd` line 437 says Pings & Callouts owns its voice and feed line).
- Initial `last_callout_*` values are minus infinity, so the first callout is always accepted.

---

## Out of Scope

- Story 006: who receives a callout.
- Story 007: identity and (not you) marking.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/pings-and-callouts/callout_limits_attached_ping_test.gd` must exist and pass

**Status**: [x] `tests/unit/pings-and-callouts/callout_limits_attached_ping_test.gd` (15 cases)

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: Story 006

## Progress Notes (2026-10-15)

Merged from wt-pc3. Full suite 1343/1343, no leak lines. Mutations caught: repeat block removed, fake callout writing the impersonated survivor's repeat timestamp, attached ping accepted without spending a token, global-cooldown timestamp written before the acceptance check.

Notes:
- The 8 lines live in `data/callouts/callout_set.tres` (`CalloutSet`, validated at load); `drive_here`, `fuse_here`, `need_rescue` and `danger` stay as constants because rules name them.
- `callouts()` returns a `CalloutRecord` (sender, identity, line, origin, fake flag, attached ping, tick) for delivery story 006.
- Callout packet cap 96 bytes (64 was smaller than a real `drive_here` packet with an attachment).

Deviations (inference):
- `AbilityUsed` gained a `line` field, filled by Monster Abilities from the request's `sound` field; rule 26 needs the line.
- Monster Abilities does not check the fake line, so a modified client's unknown line spends the False Signal cooldown and is then dropped here. Adding the check to False Signal validation settles it.
- An item attached to a line other than "Drive here" or "Fuse here" rejects the whole packet as malformed.
- A fake callout is picked up on the next Pings & Callouts tick; its identity is the impersonated survivor's appearance id and its origin the point False Signal chose. Line ids are mine; the GDD names lines by text only.
