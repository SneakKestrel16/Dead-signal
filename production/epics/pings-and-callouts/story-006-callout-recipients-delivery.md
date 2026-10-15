# Story 006: Callout recipients, range and monster audio-only

> **Epic**: Pings & Callouts
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

A callout reaches every living player within the line's range: `callout_range_m`, or `rescue_callout_range_m` for "Need rescue". Walls attenuate audio but never block delivery. Survivors get audio, feed line and arrow; the monster gets positional audio only.

**GDD**: `design/gdd/pings-and-callouts.md` rules 4, 10, 11, 14a; Formulas: callout recipients
**Requirement**: `TR-pings-004`, `TR-pings-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding; secondary: ADR-0013
**ADR Decision Summary**: Per-peer payloads strip fields a recipient may not see; callout audio is positional with wall attenuation through the audio pipeline.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: per-recipient presentation messages
- Required: callouts are never ducked by scare or ambience sounds (ADR-0013)

---

## Acceptance Criteria

*From GDD `design/gdd/pings-and-callouts.md`, scoped to this story:*

- [x] A player outside the line's range receives neither audio nor feed line; straight-line distance decides, walls do not.
- [x] A survivor's callout within range reaches the monster's client as audio only: no feed line, name or direction field, including "Need rescue" at 40 m through a wall.
- [x] A hidden survivor's callout plays from the hiding spot and carries no speaker gesture; a downed survivor can send "Need rescue".
- [x] With proximity voice Off, each information type of rule 4 (objective found, objective location, rescue needed, danger, distrust, regroup) is sent with only a ping or callout and received by the other 3 survivor clients.

---

## Implementation Notes

- The monster's payload is a different, smaller message type, so a field can never leak by being left filled.
- Spectators receive iff the survivor they watch is a recipient (Formulas).

---

## Out of Scope

- Story 007: fake callouts and identity.
- Story 008: playing the voice line and feed UI.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/pings-and-callouts/callout_recipients_delivery_test.gd` (real ENet where the AC names clients)

**Status**: [x] `tests/integration/pings-and-callouts/callout_recipients_delivery_test.gd` (real ENet, 5 clients)

---

## Dependencies

- Depends on: Stories 002, 003
- Unlocks: Stories 007, 008

## Progress Notes (2026-10-15)

Merged from wt-pc6. Full suite 1359 tests: the only failure was `round_composer_test` counting `batch_extras` (8, now 9 with callout delivery); fixed on merge with an explicit wiring check, then `tests/integration/match-flow` and `pings-and-callouts` 37/37. Mutations caught: always `callout_range_m`, monster given the full survivor entry, hidden senders keeping the gesture.

Notes:
- `CalloutDelivery` (server, `batch_extras`) and `CalloutReceiver` (client). Survivors get `Callout {line, identity, origin, gesture, voice}`; the monster gets `CalloutAudio {line, voice, origin}` only. The fake flag is never sent; rejoin sends nothing; spectators mirror their watched survivor; attached pings stay on `PingDelivery`.
- The test proves every authored line reaches the other 3 survivors with voice off (rule 4's callout half; the ping half is story 004).

Deviations (inference):
- The survivor entry also carries `voice` (story 008 plays it; `identity` already implies it). Voice sets come from `CharacterDef.load_all()` keyed by appearance id.
- A hidden sender's origin is its body position (assumes the body stands in the spot); a hiding-spot anchor settles it.
- A disguised monster is judged by the same range rule, so it hears its own callout as `CalloutAudio` only.
- Test shortcuts: bodies frozen with `sm.set_frozen` (greybox partial floors); story 003's cooldown state cleared between lines.
