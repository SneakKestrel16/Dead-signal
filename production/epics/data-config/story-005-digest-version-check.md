# Story 005: Knob digest in the join version check

> **Epic**: Data/Config Loader
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-12
> **Last Updated**: [set by /dev-story when implementation begins]

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
- [ ] A client with one changed knob is rejected with `version_mismatch`, and both version strings are shown.
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

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/data_config/digest_version_test.gd` — must exist and pass; the cross-machine AC is a documented playtest in `production/qa/evidence/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001, Story 002; network-authority join story
- Unlocks: None
