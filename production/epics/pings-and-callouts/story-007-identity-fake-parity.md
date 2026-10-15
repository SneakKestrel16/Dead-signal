# Story 007: Displayed identity, (not you) mark and fake-callout parity

> **Epic**: Pings & Callouts
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Every ping and callout carries the sender's displayed identity from server-side disguise state. A False Signal fake callout uses the same line, voice set and feed format as a real one; the only permitted difference on the wire is the absent speaker gesture. The impersonated survivor sees "(not you)" under the range rules of rule 28.

**GDD**: `design/gdd/pings-and-callouts.md` rules 1, 21, 24, 26-28
**Requirement**: `TR-pings-006`, `TR-pings-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding; secondary: ADR-0005
**ADR Decision Summary**: Identity is server-owned; no real/fake tag is ever sent to a survivor client.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Forbidden: never take sender identity from the client
- Required: the HUD never distinguishes real from fake

---

## Acceptance Criteria

*From GDD `design/gdd/pings-and-callouts.md`, scoped to this story:*

- [x] A disguised monster's ping shows the borrowed survivor's name on every other living survivor client, and its callout shows that name and voice on every survivor client within `callout_range_m`.
- [x] The copied survivor's client shows "(not you)" on a ping only when the sender is within `callout_range_m` (server positions at acceptance), and always on a callout it receives; other survivors see no mark.
- [x] A False Signal fake callout is indistinguishable from a real one in the data received by survivor clients: the callout message has no real/fake field; the gesture event is the only difference. A real callout sends the gesture to every survivor client with line of sight to the speaker.
- [x] No ping or callout changes objective, downing, stun or outcome state on the server.

---

## Implementation Notes

- Test packet parity by serializing a real and a fake callout to the same recipient and diffing the bytes apart from expected fields (origin, time).
- A client spoofing a sender name is ignored (Edge Cases).

---

## Out of Scope

- Story 009: proximity voice distortion.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/pings-and-callouts/identity_fake_parity_test.gd` (real ENet where the AC names clients)

**Status**: [x] `tests/integration/pings-and-callouts/identity_fake_parity_test.gd` (2 cases, real ENet)

---

## Dependencies

- Depends on: Stories 004, 006
- Unlocks: Story 008

## Progress Notes (2026-10-15)

Merged from wt-pc7. Full suite 1372/1372, no leak lines. Mutations caught: ping range check ignored, callout marked on its own sender, `"fake": rec.fake` added to the callout entry (6 failures).

Notes:
- "(not you)": a ping carries `not_you: true` only for the survivor whose displayed id matches the ping's `from`, who did not send it, and who is within `callout_range_m` of the sender (server positions in the accepting tick). A callout carries it for any survivor it is shown under but did not send, real or fake. The key is present only when true.
- Byte parity: a real and a False Signal fake callout at the same spot to the same survivor peer give entries of equal size, differing only in the gesture flag; the raw batches on `peer_packet` are byte-equal once tick and gesture are blanked; no key contains "fake", "real" or "sender". This also settles the packet half of scare-events story 004.
- A snapshot of objective, match, downing, eligibility and stun-lock state is identical before and after pings and callouts. A callout packet carrying an extra `identity` field is rejected.

Deviations (inference):
- The gesture is the entry's `gesture` flag, sent to every survivor in callout range with a clear sight ray. A survivor out of callout range with sight of the speaker gets no gesture. A rule 12 ruling on gesture reach settles it.
- Test pings aim 1 m above the floor; the test disguises the monster by setting `bf._form`.
