# ADR-0011: Round Stats and the Results Payload

## Status
Accepted

Accepted 2026-10-15 by the user ("accept all seven"). Any Verification Required items below are still open: they are follow-up work, not a condition on this status.

## Date
2026-10-12

## Last Verified
2026-10-12

## Decision Makers
Designer (SneakKestrel16), with Claude Code (`/architecture-decision`, autonomous mode, AD-39) and `godot-specialist` engine validation. TD-ADR skipped — Lean mode.

## Summary
Match Flow's results screen needs counts and times owned by six other systems (`match-flow.md` rules 23–26), and telemetry will later want the same hooks. Each owning module keeps its own round counters and exposes them as a getter-only `*StatsView` in the ADR-0005 State Registry; `MatchFlow.resolve` reads those views once when the outcome is final and builds a typed `RoundResults` payload that rides on `RoundEnded`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (GDScript) |
| **Knowledge Risk** | LOW: plain `RefCounted` classes, typed `Dictionary` and `Array`; the 4.7 typed-return override rule applies to view getters (ADR-0005) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `current-best-practices.md`; ADR-0004, ADR-0005, ADR-0006 |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | (1) `var_to_bytes` of the largest `RoundResults.to_dict()` (6 players, all counters, 5 objective times, longest display names) is under 4 KB, so `RoundEnded` costs at most one reliable fragmented send per peer; (2) a unit test asserts `is_typed() == false` on every array and dictionary in `to_dict()`'s output (amended 2026-10-12 for architecture review 12c, AD-44) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005 (Accepted): State Registry views, tick order, `RoundEnded` emitter. ADR-0004 (Accepted): `RoundEnded` projection is Full to every client |
| **Enables** | Match Telemetry (Alpha) consumes the `RoundEnded` payload; results screen data contract (`design/ux/results.md`) |
| **Blocks** | Match Flow results stories; each Feature epic's "stats" story |
| **Ordering Note** | None |

## Context

### Problem Statement
`match-flow.md` rules 23–26 list what the results screen shows: outcome, reason, each survivor's fate with downs taken and rescues performed, objective counts with completion times, match duration, and monster and survivor stats (takedowns, eliminations, lunges landed and missed, times stunned, form changes, False Signals, Blackouts, stuns landed, rescues). Those numbers belong to Monster Abilities, Survivor Defense, Borrowed Face, Downing, Survivor Objectives and Match Flow. ADR-0005 forbids holding a reference to another module, and no ADR said how Match Flow gathers them (TR-matchflow-008, TR-index-012).

### Constraints
- Readers use `registry.view(key, ViewClass)`; owners replace collection values whole (ADR-0005 §5).
- `RoundEnded` is projected Full to every client (ADR-0004 §5); results reveal the shapeshifter's name (rule 24).
- A client never declares a result (rule 17).

### Requirements
- Every rule 24–26 field has exactly one owner.
- The payload is built once, on the tick the outcome is final, and every client gets the same one.
- Telemetry can read the same counters without new hooks.

## Decision

**1. Owners count.** Each owning module keeps private round counters, updated only in its own `server_tick` or its own event handlers. Counters are keyed by player ID (ints) or are round totals.

| Stats key | Owner | Fields |
|---|---|---|
| `stats.downing` | Downing | per survivor: downs taken, rescues performed, fate cause (bled out, takedown); round: takedowns, eliminations |
| `stats.abilities` | Monster Abilities | lunges landed, lunges missed, lunges interrupted (story monster-abilities/008), False Signals used, Blackouts used |
| `stats.defense` | Survivor Defense | times monster stunned; per survivor: stuns landed, resists caused |
| `stats.borrowed_face` | Borrowed Face | form changes |
| `stats.objectives` | Survivor Objectives | per objective line (drives recovered, docked, fuses installed, evacuation activated, drives extracted): count and completion tick; per survivor: drives carried at escape |
| `stats.match` | Match Flow | survivor fates (Escaped, Eliminated, Did not escape, Disconnected), round start and end tick |

**2. Views.** Each owner registers its `*StatsView` under its key in `setup()`, with typed getters only, like every other view (ADR-0005 §5).

**3. Assembly.** In `MatchFlow.resolve`, on the tick the outcome becomes final, Match Flow reads the six views, builds one `RoundResults`, and emits `RoundEnded` carrying it. Times are converted from ticks to seconds once, here. Stats views are read on no other tick by gameplay code.

**4. Payload.** `RoundResults` is a typed `RefCounted` with `to_dict() -> Dictionary` for the wire. Players are named by player ID and display name (public facts, ADR-0004 §5). `RoundEnded.project()` returns the same dictionary to every peer.

**5. Telemetry.** Match Telemetry (Alpha) consumes the `RoundEnded` payload, not the views, because round teardown can free the owners before a later reader runs; it adds its own event logs, and no owner adds telemetry-only counters for results (amended 2026-10-12 for architecture review 12c, AD-44).

### Architecture Diagram

```
Downing ─┐  Abilities ─┐  Defense ─┐  BorrowedFace ─┐  Objectives ─┐  MatchFlow ─┐
 counters│   counters  │  counters │   counters     │   counters   │  fates      │
         ▼             ▼           ▼                ▼              ▼             ▼
   StateRegistry: stats.downing  stats.abilities  stats.defense  stats.borrowed_face  stats.objectives  stats.match
                                         │ (read once, outcome tick)
                                         ▼
                         MatchFlow.resolve → RoundResults → EvRoundEnded → all peers (Full)
```

### Key Interfaces

```gdscript
class_name DowningStatsView extends RefCounted   # one *StatsView per owner; example
func downs_taken(player_id: int) -> int
func rescues_performed(player_id: int) -> int
func takedowns() -> int
func eliminations() -> int

class_name RoundResults extends RefCounted
var outcome: StringName          # &"survivors" | &"shapeshifter"
var reason: StringName           # rule 23 reason codes
var duration_s: float
var shapeshifter_player_id: int
var survivors: Array[Dictionary] # {player_id, name, fate, drives_carried, downs, rescues, stuns_landed}
var objectives: Array[Dictionary]# {line, count, of, completed_s or -1.0}
var monster: Dictionary[StringName, int]  # takedowns, eliminations, lunges_landed, lunges_missed, lunges_interrupted, times_stunned, form_changes, false_signals, blackouts
func to_dict() -> Dictionary     # fresh untyped containers built field by field, so the wire never depends on typed-container encoding
```

### Implementation Guidelines
- Each results field **must** have exactly one owner from the table above, counted in that owner's code.
- Owners **must** expose stats only through a registered `*StatsView`. Match Flow **must never** hold a reference to another module.
- `RoundResults` **must** be built once, in `MatchFlow.resolve`, on the tick the outcome is final.
- Counters **must** count ticks for times; conversion to seconds happens only in `RoundResults`.
- Clients **must never** compute or alter results; they display `RoundEnded`'s payload.
- Every view getter **must** return on every branch; an unknown `player_id` returns 0 (4.7 typed-return rule, ADR-0005 §1).
- `to_dict()` **must** build fresh untyped containers (`var out: Array = []` then `out.assign(survivors)`; `var m := {}` then `m.merge(monster)`); `Array(typed)` and `duplicate()` keep the element type. The `RoundResults` object itself is never sent (amended 2026-10-12 for architecture review 12c, AD-44).

## Alternatives Considered

### Alternative 1: Match Flow counts everything from events
- **Description**: Match Flow subscribes to every event and tallies stats itself.
- **Pros**: One place to read.
- **Cons**: Several stats have no event (lunge misses, False Signals are server-internal `AbilityUsed`, resists); Match Flow would duplicate other systems' rules.
- **Rejection Reason**: Breaks single ownership.

### Alternative 2: A `collect_stats()` method on each module
- **Description**: Match Flow calls each module directly at round end.
- **Pros**: Simple.
- **Cons**: Match Flow holds module references, forbidden by ADR-0005.
- **Rejection Reason**: Violates `direct_cross_system_state_write` / no-module-reference rule.

### Alternative 3: A shared stats dictionary every module writes
- **Description**: One mutable store keyed by stat name.
- **Pros**: Least code.
- **Cons**: Many writers to one structure; generic Variant registry rejected by ADR-0005.
- **Rejection Reason**: Violates single-writer state.

## Consequences

### Positive
- Results and telemetry share one source; each number has one owner.
- No new mechanism: stats are ordinary registry views.

### Negative
- Six more view classes.

## Risks
- **A stat changes owner later.** Mitigation: the owner table lives here and as `stats.*` rows of the `systems-index.md` state table (ADR-0005 §5); changing it is an ADR amendment (amended 2026-10-12 for architecture review 12c, AD-44).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| match-flow.md | TR-matchflow-008: results payload aggregates stats from other systems through a stats interface | §1–3 owner views read by `MatchFlow.resolve` |
| systems-index.md | TR-index-012: every system exposes stat hooks for Results and Telemetry | §2 views; §5 telemetry consumes the payload |
| survivor-defense.md | Stun hits/resists per player on the results screen | `stats.defense` |
| monster-abilities.md, borrowed-face.md | Attack counts, form changes in results | `stats.abilities`, `stats.borrowed_face` |

## Performance Implications
- **CPU**: Counter increments; one assembly per round.
- **Memory**: A few ints per player per system.
- **Load Time**: None.
- **Network**: One reliable `RoundEnded` per peer per round (Verification 1).

## Migration Plan
No code exists yet.

## Validation Criteria
- A scripted round with known events produces a `RoundResults` whose every field matches the scripted counts.
- All clients receive byte-identical `RoundEnded` payloads (`match-flow.md` AC on identical results).
- A test fails if any `*StatsView` declares a setter.

## Related
- ADR-0005 (registry, tick order), ADR-0004 (projection), `design/gdd/match-flow.md` rules 23–27, `design/ux/results.md`
