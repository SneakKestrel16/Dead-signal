# Story 008: Scare audio: positional origin, stingers, ducking and volume scales

> **Epic**: Scare Events
> **Status**: Ready
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Diegetic scare sounds play from their true origin. Stingers play only on Major scares, at most `stinger_max_db_rel` over the ambient bed. Gameplay cues and callouts are never masked; scares duck only `Ambience` and `ScareDuck`. Stinger and scare master volume scales are separate player settings. There is no AudioDirector yet; sounds are placeholders.

**GDD**: `design/gdd/scare-events.md` rules 16-18, 26
**Requirement**: `TR-scare-008`, `TR-scare-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013: Spatial audio pipeline; secondary: ADR-0015
**ADR Decision Summary**: All audio routes through the bus layout; ducking writes only `Ambience` and `ScareDuck`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No AudioDirector or AudioCatalog exists; use `placeholder_audio.gd` and the 15 buses in `default_bus_layout.tres`. Sign-off covers placeholder audio and must be re-verified when final audio lands.

**Control Manifest Rules (this layer)**:
- Required: ducking writes only `Ambience` and `ScareDuck`
- Required: gameplay cues and callouts are never ducked or stolen

---

## Acceptance Criteria

*From GDD `design/gdd/scare-events.md`, scoped to this story:*

- [ ] Lunge wind-up and transform distortion cues play at full level during any scare and with any accessibility setting.
- [ ] A stinger plays only on a Major scare and at most `stinger_max_db_rel` (+6 dB) above the ambient bed.
- [ ] A diegetic scare sound comes from its true origin, with correct direction and distance for the listener; stinger and scare master scales change level only, never timing.

---

## Implementation Notes

- Measure bus peak levels in a capture run and record the numbers in the evidence page.
- Standalone presenter with a one-line hook in `round_client.gd`.

---

## Out of Scope

- Final sound design.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: retained screenshot in `production/qa/evidence/scare-audio/` + lead sign-off in `production/qa/evidence/scare-audio-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 003
- Unlocks: None
