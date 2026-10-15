# Story 005: Action restrictions while Disguised or Transforming

> **Epic**: Borrowed Face
> **Status**: In Review
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

A disguise is a costume, not a power: the shapeshifter must change to true form to attack, cannot change mid-attack, and is slowed to walking while transforming.

**GDD**: `design/gdd/borrowed-face.md`
**Requirement**: `TR-borrowedface-007`, `TR-borrowedface-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Hold-to-interact protocol (primary); ADR-0005: Event catalog, state registry and tick order
**ADR Decision Summary**: Disguise permissions are `eligible(actor)` gate checks in each owner's `Interactable` and request handlers, reading Borrowed Face's form view; the movement step reads Transforming to cap the gait at walk.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: As controller-interaction story 008.

**Control Manifest Rules (this layer)**:
- Required: resolve body targets through the requesting peer's handle table
- Forbidden: client hold completion [client_hold_complete]

---

## Acceptance Criteria

*From `borrowed-face.md` Acceptance Criteria (Lunge, Transforming), scoped to this story:*

- [x] A Lunge requested while Disguised is rejected; a transformation requested during a Lunge takedown commit is rejected.
- [x] While Transforming, the shapeshifter can walk, but sprint, interact and ability requests are rejected.
- [x] Every client receives the transforming state within 250 ms of acceptance (simulated 150 ms RTT).

---

## Implementation Notes

*Derived from ADR-0008 §2, §7 and `borrowed-face.md` rules 8, 11:*

- Lunge is Monster Abilities; use a stub request handler that reads the form view.

---

## Out of Scope

- Story 006: objective and defense interaction gates

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/borrowed-face/disguise_restrictions_test.gd` — must exist and pass
- Integration (AC3): `tests/integration/borrowed-face/transforming_visibility_test.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003; controller-interaction stories 002, 008
- Unlocks: Monster Abilities epic

---

## Completion Notes

**Implemented**: 2026-10-15 (worktree agent, squash-merged as e128b83). Full suite 895/895 after the borrowed-face wave, no leak warnings.
**Criteria**: AC1 and AC2 passing (automated). AC3 (every client sees the transforming state within 250 ms at 150 ms RTT) **not done**: no transport carries the transforming state to clients. BF-7's snapshot carried only appearance. **AC3 closed 2026-10-15** (worktree wt-bf5ac3): `SnapshotCodec` VERSION 6 adds flag `F_TRANSFORMING` (bit 2 of the existing flags byte, allowed on non-own entries; entry stays 23 B, decoded key `transforming`), filled by `ServerMovement.transforming_of` = `BorrowedFace.transforming_of(player)` (true only for the shapeshifter mid-transformation). `tests/integration/borrowed-face/transforming_visibility_test.gd`: 5 real-ENet clients behind `UdpLink` (75 ms each way + 30 ms jitter = 150 ms RTT), server paced to the wall clock; all 5 see the flag within 250 ms of acceptance and see it clear within 250 ms of completion; no survivor body ever carries it. Mutations caught: flag never set, decoder drops the flag, flag set on every body. Inference: only the flag is replicated, not the target form or start time GDD rule 8 lists (the cue needs only the flag; the target would show the next disguise early); the flag is sent to every client the body is in scope for, since Tell T1's warp is visual (the 15 m distortion radius is a client audio decision). Settle with game-designer/security-engineer.
**Deviations** (AD-167):
- New getter-only `TransformView` registered under `StateKeys.TRANSFORMING` (`get_transforming`, `get_target`, `get_form`); `get_form` on this view is inference until a `SHAPESHIFTER_FORM` view exists.
- `BorrowedFace.set_attack_source(Callable)` rejects a form change while attacking (rule 11); a rejected request starts no cooldown.
- `HoldService.set_barred(Callable)`: a barred actor's Start is rejected (fake holds included) and a running hold cancels `&"ineligible"`. ADR-0008 puts disguise checks in owners' `eligible()`, but fake holds skip it, so the actor-level bar sits in HoldService.
- Lunge and ability gates exist only as `StubAbilities` in the test (Monster Abilities not built). Nothing in production calls `set_barred`/`set_attack_source` or sets `MoveState.transforming` yet.
**Test Evidence**: `tests/integration/borrowed-face/disguise_restrictions_test.gd` (5 tests). Mutations caught: attack gate disabled, barred check at Start disabled, barred check on a running hold disabled.
**Code Review**: Complete (orchestrator review at merge)
