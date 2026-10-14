# Story 004: Refuse to host on bad knobs; freeze per round

> **Epic**: Data/Config Loader
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

Unblocked 2026-10-13: ADR-0001..0008 Accepted. Also needs `NetAuthority.host()` from the network-authority epic.

## Context

A validation error must be visible at once: the game refuses to host and lists every error. Once a round starts, its knobs never change; a debug reload applies at the next round start.

**GDD**: none
**Requirement**: `TR-config-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Data-Driven Configuration (Knobs); secondary ADR-0005 (composition root passes knobs through `setup()`)
**ADR Decision Summary**: Any error means the game refuses to host and shows the list; debug builds also assert. The composition root takes the loaded `Knobs` at round start and passes it to every module's `setup()`; modules never write it; debug `reload` applies at the next round start.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: None beyond story 001.

**Control Manifest Rules (this layer)**:
- Required: a validation error refuses to host; modules receive services through `setup()`
- Forbidden: runtime knob writes [knob_write]; gameplay autoload services [gameplay_autoload_service]
- Guardrail: none specific

---

## Acceptance Criteria

*From ADR-0006 §4, §5 and Validation Criteria, scoped to this story:*

- [ ] An out-of-range value, a missing value and a broken cross-knob rule each block hosting and show the error by name in the host UI.
- [ ] A debug `reload` during a round changes nothing in that round; the next round uses the reloaded values.
- [ ] Modules hold the round's `Knobs` from `setup()`; no gameplay code writes a knob field (test greps for assignments to `knobs.`).

---

## Implementation Notes

*Derived from ADR-0006 Decision and Implementation Guidelines:*

- Host flow: `Knobs.load_all()` → if `errors()` non-empty, show the list and do not call `create_server`.
- Debug builds also `assert` on errors; release builds only refuse.
- The composition root (ADR-0005) owns the frozen reference for the round.

---

## Out of Scope

- Story 005: the digest and version string

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-003-2026-10-14.md` (/qa-plan, 2026-10-14). Implement against these and the Acceptance Criteria above.*

**What to test**:
- Three bad knob sets (one out-of-range value, one missing value, one broken cross-knob rule): each blocks hosting, `create_server` is never called, and the error list returned to the host UI contains the rule or field name.
- Debug `reload` during a round: the round's `Knobs` reference is unchanged; the next round start passes the reloaded values to `setup()`.
- Grep test: no `knobs.<field> =` assignment anywhere under `src/` outside the loader.

**Edge cases to cover**:
- All three errors at once: all are listed, not only the first.
- Release builds refuse without asserting; debug builds also assert (test the refusal path; the assert is debug-only and is not run in the suite).

**Estimated test count**: ~6 integration tests

**Manual checks**:

**Verification method**: Screenshot
**Who must sign off**: qa-lead
**Evidence to capture**: harness window showing the refusal list with a bad knob file

- [ ] Each error is listed by name; hosting does not start.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/data_config/refuse_to_host_test.gd` — must exist and pass

**Status**: [x] `tests/integration/data_config/refuse_to_host_test.gd` passes (9 tests); full suite 272/272 (2026-10-14). The refusal tests fail with the guard disabled. Screenshot: `production/qa/evidence/data-config-004-refuse-to-host.png` (harness `--role=host --knob=controller.walk_speed=9.0`).

**Implementation**: `NetAuthority.host()` refuses while `knobs.errors()` is non-empty (`host_refused(errors)`, `ERR_INVALID_DATA`, no `create_server`; debug builds assert unless `fail_hard` is false). `KnobStore` (Foundation) holds the next round's set; `reload()` (debug only) replaces it only when valid. The "host UI" is the NH-1 harness until lobby-role-assignment story 005.

**Deviations**:
- The refusal lives in `NetAuthority.host()` rather than a separate host-flow function, so no host path can skip it.
- The knob-write grep catches `knobs.`/`_knobs.` chains; a write through a local alias (`var c := knobs.controller; c.x = 1`) is not caught (inference: no such code exists; code review owns the rest).

---

## Dependencies

- Depends on: Story 001, Story 003; network-authority host story
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-10-14
**Criteria**: 3/3 passing (AC1's host-UI half verified by the harness screenshot; lobby-role-assignment story 005 owns the real host screen)
**Deviations**: refusal inside `NetAuthority.host()`; `KnobStore` stages debug reloads; knob-write grep cannot see writes through a local alias (AD-91, AD-92)
**Test Evidence**: Integration: `tests/integration/data_config/refuse_to_host_test.gd` (9 tests); screenshot `production/qa/evidence/data-config-004-refuse-to-host.png`
**Code Review**: Complete (APPROVED WITH SUGGESTIONS after widening the knob-write regex to every compound operator, indexed writes and `.set(`). Open suggestions: `#` inside a string hides the rest of a line from the grep; harness `--knob=` with an unknown section crashes; `KnobValidator` prints float32 range hints (3.70000004768372)
