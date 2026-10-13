# Epic: Data/Config Loader

> **Layer**: Foundation
> **GDD**: none (every GDD's Tuning Knobs section is its input)
> **Architecture Module**: Data/Config loader (`docs/architecture/architecture.md` Module Ownership)
> **Status**: Ready (governing ADR is Proposed; stories block until it is Accepted)
> **Control Manifest**: 2026-10-12
> **Stories**: Not yet created — run `/create-stories data-config`

## Overview

Loads every tuning knob from data and refuses to host on a bad value. Each system has a typed `<System>Knobs` Resource whose fields are `@export_range` entries named exactly as in its GDD, defaulting to `NAN` or `KnobUnset.INT`. The `.tres` files load only from `res://data/knobs/` under a fixed name list, are validated for range, unset values and cross-knob rules at load, and are frozen for the round. `Knobs.ticks()` converts seconds to server ticks, and a digest of the shipped knobs joins the build version string so a client with different data is rejected at join.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0006: Data-driven configuration | Typed knob sections in `res://data/knobs`; NAN/unset defaults; range, unset and cross-knob validation; refuse to host; frozen per round; digest in version string | MEDIUM |
| ADR-0001: Hosting, session join and reconnect | Version string carries the first 8 hex of `Knobs.digest()` | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-config-003 | Gameplay values data-driven, never hardcoded; gdUnit4 test framework | ADR-0006 (Proposed) |
| TR-config-001 | 60 fps / 16.6 ms frame, 2000 draw calls; memory ceiling unset | ADR-0002 (sim side, Proposed); no client render budget |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- One integration test loads the shipped knob files and asserts `errors()` is empty
- All Logic and Integration stories have passing test files in `tests/`

## Next Step

Run `/create-stories data-config` to break this epic into implementable stories.
