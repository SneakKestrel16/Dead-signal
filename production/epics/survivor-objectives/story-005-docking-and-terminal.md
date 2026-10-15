# Story 005: Docking and the evacuation terminal

> **Epic**: Survivor Objectives
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Drives are docked at the terminal; with two drives docked and two fuses installed the terminal is armed, and the team must hold its zone through a 15-second countdown that pauses but never resets.

**GDD**: `design/gdd/survivor-objectives.md`
**Requirement**: `TR-objectives-005`, `TR-objectives-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0008
**ADR Decision Summary**: Server-only typed events on the `EventBus`; owner-written state in the `StateRegistry`; Objectives runs in the `SURVIVOR_OBJECTIVES` (600) slot after Holds.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Terminal zone from the map data; no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: run in the `SURVIVOR_OBJECTIVES` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel`; fake holds take no lock, change no progress and never call the owner (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never let `HoldService` emit events; never emit an event from a client; never decide discovery from a client report, proximity alone or room entry (ADR-0005, ADR-0008, ADR-0012)
- Guardrail: every `duration_s` and `range_m` comes from `ObjectivesKnobs` (`data/knobs/objectives.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-objectives.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] A carrier docks a drive with a `dock_s` hold; a docked drive cannot be removed before activation; the terminal is Armed exactly when 2 drives are docked and 2 fuses installed, and accepts activation only then (rules 14, 18).
- [ ] After an `activation_start_s` hold, the countdown takes 15 s with a Healthy survivor in the terminal zone and pauses with progress kept when the zone holds no Healthy, non-hidden survivor; a hidden survivor or the shapeshifter alone does not run it (rule 19, Formulas "Effective activation time").
- [ ] At 0 the terminal is Activated: the exit opens and both docked drives eject at the terminal as Dropped items that any Healthy survivor can pick up (rule 20).
- [ ] Every value this story uses is read from `ObjectivesKnobs`, not hardcoded.

---

## Implementation Notes

- The countdown sums ticks in Activating with at least one Healthy, non-hidden survivor inside the authored terminal zone; read life state and hidden state from the registry (Downing, Defense) — absent owners read as Healthy, not hidden, and tests set them.
- Publish `terminal_armed` and `evacuation_activated` for Match Flow (match-flow stories 001, 003).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: carrying the ejected drives out

---

## QA Test Cases

*From `/qa-plan sprint` (production/qa/qa-plan-sprint-005-2026-10-14.md). Implement against these cases.*

- **AC-1**: Docking and arming
  - Given: drives and fuses in each combination
  - When: docks and installs complete
  - Then: Armed exactly at 2 docked + 2 installed; activation refused before; docked drive not removable
  - Edge cases: docking before power restored is allowed
- **AC-2**: Countdown holds the zone
  - Given: Activating with one Healthy survivor in the zone
  - When: the survivor leaves for 6 s after 9 s, then returns
  - Then: activated after 21 s real time; hidden survivor or shapeshifter alone does not run it
  - Edge cases: last Healthy survivor downed mid-countdown pauses it
- **AC-3**: Activation
  - Given: countdown at 0
  - When: the tick runs
  - Then: Activated, exit open, both drives Dropped at the terminal
  - Edge cases: deadline on the same tick (Match Flow decides)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/survivor-objectives/docking-and-terminal_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 003
- Unlocks: Story 006
