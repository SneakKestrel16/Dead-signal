# Story 005: Knob digest in the join version check

> **Epic**: Data/Config Loader
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

Unblocked 2026-10-13: ADR-0001..0008 Accepted. Also needs the network-authority join story.

## Context

Host and every predicting client must run the same numbers. A hash of the loaded knobs joins the build version string, so a client with one changed value is turned away at join with both strings shown.

**GDD**: none
**Requirement**: `TR-config-003`, `TR-lobby-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Data-Driven Configuration (Knobs); secondary ADR-0001 §3
**ADR Decision Summary**: `Knobs.digest()` is SHA-256 over `var_to_bytes` of every section's field names and values in sorted field order (script variables only, never file bytes); the auth `version` becomes `"<build_version>+<digest first 8 hex>"`, so a mismatch is `version_mismatch`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Verification results (4): digest stable across loads and two runs; **cross-machine NOT RUN** — run it with the two-PC network test.

**Control Manifest Rules (this layer)**:
- Required: decode auth payloads with `bytes_to_var` only, after size and type checks (ADR-0001)
- Forbidden: sending knob values from host to clients
- Guardrail: 9 more characters in the auth version string

---

## Acceptance Criteria

*From ADR-0006 §7 and Validation Criteria, scoped to this story:*

- [ ] The same knob set gives the same digest on two loads and two runs; an editor `.tres` and an exported binary build give the same digest.
- [x] A client with one changed knob is rejected with `version_mismatch`, and both version strings are shown.
- [ ] The digest is identical on two machines (two-PC test).

---

## Implementation Notes

*Derived from ADR-0006 Decision and Implementation Guidelines:*

- Hash only properties with `PROPERTY_USAGE_SCRIPT_VARIABLE`, in sorted field order, per section in a fixed section order.
- Use `HashingContext` SHA-256; take the first 8 hex characters for the version suffix.
- The reject path is ADR-0001's existing `version_mismatch`; no new reason code.

---

## Out of Scope

- The join validation itself (network-authority epic)

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-002-2026-10-13.md` (/qa-plan, 2026-10-13). Implement against these and the Acceptance Criteria above.*

**What to test**:
- The same knob set gives the same digest across two loads in one run and across two runs (fixed expected value checked into the test).
- A client with one changed knob is rejected with `version_mismatch`, and both version strings appear in `last_reject_details`.
- The version string has the form `<build_version>+<first 8 hex of the digest>`.

**Edge cases to cover**:
- Changing a knob that is not saved (private var) leaves the digest unchanged.
- A float stored as 1.0 and as 1.00 gives the same digest (serialization is canonical).
- Section order does not change the digest.

**Estimated test count**: ~6 integration tests

**Manual checks**:
- Editor `.tres` against an exported binary: the digests are the same. BLOCKED until an export preset exists (`commands.build` is unset). Add a preset first, or move this item to the sprint that adds one.
- Two-PC: the digest is identical on two machines. Run it with NA-V on the same Tailscale session.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/data_config/digest_version_test.gd` — must exist and pass; the cross-machine AC is a documented playtest in `production/qa/evidence/`

**Status**: [x] `tests/integration/data_config/digest_version_test.gd` passes (7 tests, 2 runs, same digest); 3 mutations caught; suite 198/198 (2026-10-14)

---

## Dependencies

- Depends on: Story 001, Story 002; network-authority join story
- Unlocks: None

---

## Completion Notes
**Completed**: 2026-10-14
**Criteria**: 1/3 passing, 2 DEFERRED (need an export preset or a second PC)
- AC1 partly: same digest on two loads and two runs (`test_digest_is_stable_across_loads_and_runs`, value pinned at `908cc535...`). DEFERRED: editor `.tres` against an exported binary: no export preset exists (TD-004).
- AC2: `test_client_with_one_changed_knob_is_rejected_with_both_versions` (real ENet join; both strings in `last_reject_details`).
- AC3 DEFERRED: digest identical on two machines: run with NA-V (Sprint 2 Should Have) on the same Tailscale session.
- Edge cases: a non-saved property and Knobs bookkeeping leave the digest unchanged; -0.0 and 0.0 hash the same (normalized; gotchas.md); an array knob reorder changes it. Section order is sorted by construction.
**Deviations**: none from ADR-0006 §7; -0.0 is mapped to +0.0 before hashing (equal values, different bytes). The pinned digest must be re-pinned with any shipped knob change (the failure message says so).
**Test Evidence**: Integration: `tests/integration/data_config/digest_version_test.gd`, 7 tests; 3 mutations caught.
**Run result**: N/A: no screen; the version string is not shown until the join UI exists.
**Code Review**: Complete: `/code-review` 2026-10-14, APPROVED WITH SUGGESTIONS; applied: -0.0 normalization with a real negative-zero test, re-pin message, array-knob test, renamed loop variable. Not applied: also filtering on PROPERTY_USAGE_EDITOR (KnobValidator uses the same SCRIPT_VARIABLE + STORAGE rule, so the two stay consistent).
