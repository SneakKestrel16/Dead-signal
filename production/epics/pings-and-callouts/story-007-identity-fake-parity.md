# Story 007: Displayed identity, (not you) mark and fake-callout parity

> **Epic**: Pings & Callouts
> **Status**: Ready
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

- [ ] A disguised monster's ping shows the borrowed survivor's name on every other living survivor client, and its callout shows that name and voice on every survivor client within `callout_range_m`.
- [ ] The copied survivor's client shows "(not you)" on a ping only when the sender is within `callout_range_m` (server positions at acceptance), and always on a callout it receives; other survivors see no mark.
- [ ] A False Signal fake callout is indistinguishable from a real one in the data received by survivor clients: the callout message has no real/fake field; the gesture event is the only difference. A real callout sends the gesture to every survivor client with line of sight to the speaker.
- [ ] No ping or callout changes objective, downing, stun or outcome state on the server.

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 004, 006
- Unlocks: Story 008
