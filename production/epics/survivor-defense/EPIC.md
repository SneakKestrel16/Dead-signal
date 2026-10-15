# Epic: Survivor Defense

> **Layer**: Feature
> **GDD**: design/gdd/survivor-defense.md
> **Architecture Module**: Survivor Defense (`docs/architecture/architecture.md` Feature layer)
> **Status**: Ready
> **Control Manifest**: 2026-10-13
> **Stories**: Not yet created — run `/create-stories survivor-defense`

## Overview

This system gives survivors their answers to the shapeshifter. Each survivor carries a flashlight and a limited-use taser. The flashlight shows the way through dark rooms and Blackout but does nothing to the monster. A taser hit is traced on the server along the shooter's view ray. It stuns a true-form monster, which cancels a lunge, a takedown commit, a transformation, a search or a break, then grants a short immunity. A hit on a disguised monster looks exactly like a hit on a survivor (`PlayerShocked`), so the shot never reveals identity. Hiding spots let a survivor vanish until the monster searches them. Doors close instantly, and barricades take time to build and to break. Every use is a server-validated intent, and every duration, range and charge is data.

Merged stories already depend on this module through stand-ins:
- Borrowed Face 004 and 008 use a `StubDefense` that emits `MonsterStunned` and `PlayerShocked` from the GDD prose.
- Borrowed Face 006 uses fixture hiding, barricade and search interactables.

This epic replaces those stand-ins, and those tests should be re-run against it.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Authoritative simulation, tick rate and input | Fire, hide, barricade and break are client intents; the server owns charges, timers and occupancy | HIGH |
| ADR-0003: Lag compensation and rewind | Taser trace against rewound positions, consistent with the lunge hit test (`LagCompensation`, network-authority story 007) | HIGH |
| ADR-0004: Replication scope and information hiding | Identical `PlayerShocked` for a disguised monster and a survivor; `MonsterStunned` only for a true-form monster; hidden survivors excluded from views | HIGH |
| ADR-0005: Event catalog, state registry and tick order | Emits `MonsterStunned`, `PlayerShocked`, `BarricadeBroken`; publishes hidden, item-use and shock-lock state; a stun beats same-tick completions | HIGH |
| ADR-0006: Data-driven configuration | `DefenseKnobs` (already in `src/foundation/data_config/defense_knobs.gd`) | MEDIUM |
| ADR-0007: Movement, physics and collision layers | Shock lock as owner-keyed movement modifiers; doors and barricades block the lunge dash and line of sight | HIGH |
| ADR-0008: Hold-to-interact protocol | Hide, barricade, remove, search and break as holds; the door as an instant interaction | HIGH |
| ADR-0010: Borrowed Face rendering (Proposed) | Per-form shock presentation and the disguised monster's cosmetic flashlight | HIGH |
| ADR-0013: Spatial audio pipeline (Proposed) | Hiding noise, the shock grunt or pain cry, and the barricade break noise | MEDIUM |

## GDD Requirements

ADR coverage below is mapped by domain: these ADRs do not list TR-IDs by name (inference; `/create-stories` settles it per story). At `workflow: standard` only the Foundation ADRs (0001–0008, all Accepted) are expected; rows on a Proposed ADR are informational and their stories block until it is accepted.

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-defense-001 | Server owns charges, stun/immunity timers, hide occupancy, barricade durability; client intent only | ADR-0002 (Accepted) |
| TR-defense-002 | Taser: 0.2 s use delay, server trace on the view ray (5 m, 10 degrees), first body hit, Seized/Downed pass-through, cartridge always consumed; rewind consistent with Abilities | ADR-0003, ADR-0007 (Accepted) |
| TR-defense-003 | Identity-hiding replication: disguised-monster hit and survivor hit send the same `PlayerShocked`; `MonsterStunned` only in true form | ADR-0004 (Accepted) |
| TR-defense-004 | Shared action lock (2 s: 1 s root, then 0.5 slow), no refresh, 6 s immunity ending early on lunge wind-up or disguise completion | ADR-0007, ADR-0005 (Accepted) |
| TR-defense-005 | A stun cancels lunge wind-up/dash, takedown commit, transformation, search and break; a stun beats same-tick completions | ADR-0005 (Accepted) |
| TR-defense-006 | Hiding spots: 1 s enter/exit, one occupant, peek cone, 8 m noise, cue after 20 s, 1.5 s monster Search ejects; hidden state excluded from lunge, objectives, pings | ADR-0008, ADR-0004 (Accepted) |
| TR-defense-007 | Doors (instant) and barricades (3 s build, 1 s remove, 5 s persistent break, 30 s lockout); server-owned door state; closed doors block dash and LOS | ADR-0008, ADR-0007 (Accepted) |
| TR-defense-008 | Flashlight toggle replicated; cone visible to all; no effect on the monster; cosmetic copy on a disguised monster | ADR-0004 (Accepted); cosmetic copy ADR-0010 (Proposed) |
| TR-defense-009 | Emits `MonsterStunned`, `PlayerShocked`, `BarricadeBroken`; reads form, Transforming and Seized/Downed/Committing; exposes hidden, item-use and shock-lock state | ADR-0005 (Accepted) |
| TR-defense-010 | Interactable contract table (hide, barricade, remove, search, break, door) feeds the hold framework; all values are data | ADR-0008, ADR-0006 (Accepted) |
| TR-defense-011 | Shock/stun presentation per form, chosen by the body shown at that moment | ADR-0010, ADR-0013 (Proposed) |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/survivor-defense.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` — each screen touched for UI, plus a lead sign-off for Visual/Feel
- The stand-in tests in Borrowed Face 004, 006 and 008 are re-run against the real module

## Next Step

Run `/create-stories survivor-defense` to break this epic into implementable stories.
