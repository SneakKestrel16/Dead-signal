# Systems Index: Dead Signal

> **Status**: Draft
> **Created**: 2026-10-11
> **Last Updated**: 2026-10-12
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

Dead Signal is a five-player, first-person asymmetric horror game: one human
shapeshifter against four human survivors in one hand-authored research
facility, over a ~9-minute round. Its systems fall into three groups: the round
itself (match flow, objectives, downing and rescue), the two sides' kits
(the shapeshifter's Borrowed Face and abilities; the survivors' defenses and
communication), and the horror presentation (scare events, lighting and audio).
Under all of it sits one technical rule from the source brief: the server is
authoritative for attacks, stuns, cooldowns, objectives, downing, rescue and
match results. There are no AI-controlled monsters or creatures anywhere.


### Server events

Systems talk to each other through these server events, plus the read-only
replicated state listed in the next table (designer decision, 2026-10-11,
cross-review re-review R3). The server emits events after validation; clients
never emit them. Every GDD uses these exact names. A system may read another
system's state only if that state is in the state table; anything else goes
through an event.

| Event | Emitted by | Consumed by | Meaning |
|-------|-----------|-------------|---------|
| `RoundPhaseChanged` | Match Flow & Win Conditions | Survivor Objectives, Monster Abilities, Scare Events, Facility Map (lighting), HUD | Phase moved (Infiltration, Investigation, Evacuation) |
| `RoundEnded` **(proposed)** | Match Flow & Win Conditions | All systems (freeze), HUD & Results Screen | Outcome final; carries outcome, reason and results payload |
| `SurvivorEscaped` **(proposed)** | Match Flow & Win Conditions | Survivor Objectives (carried drives become Extracted, rule 22), Downing, Rescue & Elimination (Escaped players never slow bleed-out or count as Healthy, rule 6), HUD, Match Telemetry | A Healthy survivor entered the exit after evacuation activated; any drives they carry are Extracted (survivors win when both are) |
| `SurvivorHit` | Monster Abilities | Downing, Rescue & Elimination | A validated Predatory Lunge hit; starts the takedown commit |
| `SurvivorDowned` | Downing, Rescue & Elimination | Survivor Objectives (drops), Match Flow, Monster Abilities (lunge resolved), Pings & Callouts, HUD | Takedown commit completed; first down |
| `SurvivorRescued` | Downing, Rescue & Elimination | Pings & Callouts, Match Flow (stats), HUD | Rescue completed |
| `SurvivorEliminated` | Downing, Rescue & Elimination | Match Flow (win check), Monster Abilities (lunge resolved), Survivor Objectives, Pings & Callouts, HUD | Second down completed |
| `MonsterStunned` | Survivor Defense | Monster Abilities, Downing, Rescue & Elimination, Borrowed Face; all clients when the monster is in true form (presentation, Scare Events ducking) | Stun applied; cancels lunge, takedown commit or transformation. While the monster is disguised, survivor clients get `PlayerShocked` instead (Survivor Defense rule 1) |
| `PlayerShocked` | Survivor Defense | All clients (presentation), Scare Events (audio ducking, rule 18) | A taser hit a survivor, or hit the monster while it is disguised (stunned or immune); identical in every case so it carries no identity information (Survivor Defense rules 1, 10, 11) |
| `FormChanged` | Borrowed Face | Pings & Callouts, Scare Events (transformation reveal on change into true form), all clients (rendering) | Shapeshifter form changed |
| `ObjectiveProgressChanged` | Survivor Objectives | Match Flow, Scare Events, Facility Map (lighting), HUD | Any objective state change (carry, drop, dock, install, power restored, armed, activated, drives ejected, drive extracted) |
| `ScareTriggered` | Scare Events | Recipient clients only | A scare; carries scope (shared or single-client) |
| `AbilityUsed` **(proposed)** | Monster Abilities | Scare Events (scare triggers), Pings & Callouts (False Signal fake callout), Match Telemetry | A validated Lunge wind-up, False Signal or Blackout; carries ability, position and, for False Signal, the sound or impersonated callout |
| `BarricadeBroken` **(proposed)** | Survivor Defense | Scare Events, HUD | A barricade was destroyed |
| `PlayerConnectionChanged` **(proposed)** | Match Flow & Win Conditions | Downing, Rescue & Elimination (cancel commit on monster disconnect), Monster Abilities, HUD | A player disconnected, reconnected or ran out of reconnect grace |

### Read-only replicated state

Server-held state that other systems read directly instead of waiting for an
event. Only the owner writes it. Readers never change it.

| State | Owner | Read by | Meaning |
|-------|-------|---------|---------|
| Shapeshifter form (true form or disguised, and whose body) | Borrowed Face | Survivor Defense (rules 1 and 10: which shock presentation and which events survivor clients receive), all clients (rendering) | The form the shapeshifter currently shows; `FormChanged` announces each change |
| Transforming flag (target form, start time) | Borrowed Face (rule 8) | Pings & Callouts, Survivor Defense, all clients (rendering) | A transformation is in progress |
| Takedown eligibility (Seized, Downed, grace) | Downing, Rescue & Elimination | Monster Abilities (rule 7 hit validation), Survivor Defense (rule 8 shot pass-through, rule 13 item use) | Whether a survivor can be lunged |
| Player positions and life states | Network Authority & Replication; life state from Downing, Rescue & Elimination | Downing, Rescue & Elimination (camping slow, rule 6), Survivor Objectives (zone counts) | Where each player is and whether they are Healthy, Seized, Downed or Eliminated |
| `blackout_able` per lighting volume | Facility Map (`research-facility.md`); flips to false for the active terminal room on `RoundPhaseChanged` to Evacuation | Monster Abilities (rule 17 Blackout target validation) | Whether a lighting volume may be blacked out |
| Hidden and item-use state | Survivor Defense | Survivor Objectives (hidden survivors cannot interact or hold the zone) | Whether a survivor is hidden or using an item |
| Shock/stun lock | Survivor Defense (rule 14) | Pings & Callouts, Survivor Objectives, Borrowed Face, Monster Abilities, Downing, Rescue & Elimination (rule 7 rescue interrupt), First-Person Controller & Interaction (root, slow, doors) | A player is under the taser action lock |

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Network Authority & Replication | Core | MVP | Not Started | — (architecture/ADR, after `/setup-engine`) | — |
| 2 | Lobby & Role Assignment | Core | MVP | Not Started | — | Network Authority |
| 3 | First-Person Controller & Interaction (inferred) | Core | MVP | Not Started | — | Network Authority |
| 4 | Match Flow & Win Conditions | Gameplay | MVP | Approved | design/gdd/match-flow.md | Lobby & Role Assignment, Survivor Objectives, Downing, Rescue & Elimination |
| 5 | Survivor Objectives | Gameplay | MVP | Approved | design/gdd/survivor-objectives.md | Network Authority, Controller & Interaction, Match Flow, Facility Map, Downing, Rescue & Elimination, Survivor Defense |
| 6 | Downing, Rescue & Elimination | Gameplay | MVP | Approved | design/gdd/downing-and-rescue.md | Controller & Interaction, Monster Abilities (Predatory Lunge) |
| 7 | Survivor Defense (flashlight, stun items, hiding, barricades) | Gameplay | MVP | Approved | design/gdd/survivor-defense.md | Controller & Interaction, Monster Abilities, Borrowed Face, Downing, Rescue & Elimination |
| 8 | Borrowed Face (disguise) | Gameplay | MVP | Approved | design/gdd/borrowed-face.md | Network Authority, Controller & Interaction, Survivor Defense, Downing, Rescue & Elimination, Facility Map |
| 9 | Monster Abilities (Predatory Lunge, False Signal, Blackout) | Gameplay | MVP (Lunge) / Vertical Slice (False Signal, Blackout) | Needs Revision | design/gdd/monster-abilities.md | Downing, Rescue & Elimination, Borrowed Face, Facility Map |
| 10 | Pings & Callouts (voice-free communication) | Gameplay | Vertical Slice | Needs Revision | design/gdd/pings-and-callouts.md | Controller & Interaction, Network Authority, Borrowed Face |
| 11 | Facility Map (Research Facility greybox) | Gameplay | MVP | In Design | design/levels/research-facility.md | Controller & Interaction |
| 12 | Scare Events (jumpscares, lighting & audio states) | Audio | Vertical Slice | In Design | design/gdd/scare-events.md | Monster Abilities, Borrowed Face, Facility Map, Match Flow, Network Authority |
| 13 | HUD & Results Screen | UI | MVP | Not Started | — (`/ux-design`) | Match Flow, Survivor Objectives, Downing, Rescue & Elimination |
| 14 | Accessibility Options (reduced flash, reduced volume) | Meta | Vertical Slice | Not Started | — (`design/accessibility-requirements.md`) | Scare Events |
| 15 | Match Telemetry (balancing logs) | Meta | Alpha | Not Started | — | Match Flow, all gameplay systems |

---

## Categories

| Category | Description | Systems here |
|----------|-------------|--------------|
| **Core** | Foundation systems everything depends on | Network Authority, Lobby & Role Assignment, Controller & Interaction |
| **Gameplay** | The systems that make the game fun | Match Flow, Objectives, Downing & Rescue, Survivor Defense, Borrowed Face, Monster Abilities, Pings & Callouts, Facility Map |
| **UI** | Player-facing information displays | HUD & Results Screen |
| **Audio** | Sound and presentation systems | Scare Events |
| **Meta** | Systems outside the core loop | Accessibility Options, Match Telemetry |

Progression, Economy, Persistence and Narrative are intentionally absent:
the source brief excludes progression and economy from the prototype.

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required to test "is the round fun?" | Milestones 1–3 (networked greybox, round loop, core monster and counterplay) | Design FIRST |
| **Vertical Slice** | One complete, polished facility and round | Milestone 4 (horror pass) | Design SECOND |
| **Alpha** | Everything present in rough form, measurable | Milestone 5 (closed playtest) | Design THIRD |
| **Full Vision** | Only after the first map is fun and stable | Post-playtest | As needed |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. Network Authority & Replication — every rule (hits, stuns, cooldowns, objectives, downs, outcomes) is validated on the server.
2. First-Person Controller & Interaction — movement and the timed "hold to interact" pattern used by objectives, rescues and barricades.

### Core Layer (depends on foundation)

1. Lobby & Role Assignment — depends on: Network Authority
2. Facility Map — depends on: Controller & Interaction
3. Borrowed Face — depends on: Network Authority, Controller & Interaction

### Feature Layer (depends on core)

1. Survivor Objectives — depends on: Controller & Interaction, Facility Map
2. Monster Abilities — depends on: Borrowed Face, Facility Map
3. Downing, Rescue & Elimination — depends on: Monster Abilities (Predatory Lunge), Controller & Interaction (owns the takedown commit that sits between a lunge hit and the lunge cooldown)
4. Survivor Defense — depends on: Monster Abilities, Controller & Interaction
5. Match Flow & Win Conditions — depends on: Lobby & Role Assignment, Survivor Objectives, Downing, Rescue & Elimination
6. Pings & Callouts — depends on: Controller & Interaction, Network Authority, Borrowed Face

### Presentation Layer (depends on features)

1. Scare Events — depends on: Monster Abilities, Borrowed Face, Facility Map, Match Flow
2. HUD & Results Screen — depends on: Match Flow, Survivor Objectives, Downing, Rescue & Elimination

### Polish Layer (depends on everything)

1. Accessibility Options — depends on: Scare Events, HUD
2. Match Telemetry — depends on: Match Flow and all gameplay systems

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Match Flow & Win Conditions | MVP | Feature | game-designer | M |
| 2 | Survivor Objectives | MVP | Feature | game-designer, level-designer | M |
| 3 | Downing, Rescue & Elimination | MVP | Feature | systems-designer | S |
| 4 | Borrowed Face | MVP | Core | game-designer, network-programmer | L |
| 5 | Monster Abilities | MVP / VS | Feature | systems-designer | M |
| 6 | Survivor Defense | MVP | Feature | systems-designer | M |
| 7 | Facility Map | MVP | Core | level-designer | M |
| 8 | Pings & Callouts | VS | Feature | game-designer, ux-designer | S |
| 9 | Scare Events | VS | Presentation | audio-director, sound-designer | M |
| 10 | Network Authority (ADRs) | MVP | Foundation | technical-director, network-programmer | M |

Network Authority is listed last in *design* order only because it needs an
engine choice first; it must be settled before any gameplay code is written.

---

## Circular Dependencies

- **Downing, Rescue & Elimination ↔ Monster Abilities**: Predatory Lunge produces downs; the
  down state limits what the monster can do next (committing to a down).
  Resolution: Monster Abilities owns *hit resolution* and the lunge cooldown;
  Downing, Rescue & Elimination owns *what a hit does to a survivor*, including
  the takedown commit. They talk through `SurvivorHit`. One shared timeline in
  both GDDs: hit → takedown commit → lunge resolved (commit completes or is
  cancelled) → 10 s lunge cooldown.
- **Borrowed Face ↔ Survivor Defense**: stuns interrupt transformation;
  transformation cannot escape a stun. Resolution: Survivor Defense owns the
  stun state; Borrowed Face reads it.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Borrowed Face | Design + Technical | Impersonation may feel arbitrary or be trivially detectable; disguise state must replicate correctly to every client | Prototype early in greybox; learnable tells, not one random tell |
| Network Authority | Technical | Lunges and stuns disputed under latency | Server-side validation from the first build; log latency-related disputes |
| Scare Events | Design | Jumpscares become annoying or unfair | Cooldowns, variation, no control lock that guarantees a hit, accessibility options |
| Survivor Defense | Design | Stun-locking the monster | Limited charges, short stuns, disengage opportunities |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 15 |
| Design docs started | 9 |
| Design docs reviewed | 5 |
| Design docs approved | 4 |
| MVP systems with a GDD | 7/11, 4 approved (Monster Abilities counted as MVP) |
| Vertical Slice systems with a Draft GDD (none approved) | 2/3 |

---

## Next Steps

- [ ] Review and approve this systems enumeration
- [ ] Review each Draft GDD (`/design-review design/gdd/<file>.md`)
- [ ] Run `/review-all-gdds` once the MVP set is reviewed
- [ ] Choose the engine (`/setup-engine`), then write the Network Authority ADRs (`/create-architecture`)
- [ ] Run `/gate-check` when MVP systems are designed
