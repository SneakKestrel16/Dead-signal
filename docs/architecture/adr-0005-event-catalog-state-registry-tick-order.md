# ADR-0005: Event Catalog, State Registry and Tick Order

## Status
Proposed

## Date
2026-10-12

## Last Verified
2026-10-12

## Decision Makers
SneakKestrel16 (designer), with `godot-specialist` engine validation. TD-ADR skipped — Lean mode.

## Summary
The systems index defines 15 server events and a table of read-only replicated state, and several GDD rules depend on what happens first within one server tick. The decision: typed `@abstract` event classes each with a mandatory `project()`, an injected EventBus flushed (drained) after every module phase, typed read-only state views registered once per owner, a fixed module order with Match Flow split into `begin` and `resolve`, and a composition root that wires everything with no gameplay autoloads.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (GDScript) |
| **Knowledge Risk** | HIGH (4.7: overrides inherit the parent's typed return; packed-array element writes no longer call the property setter; `@abstract` is 4.5+) |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md` |
| **Post-Cutoff APIs Used** | `@abstract` classes and methods (4.5); 4.7 typed-return override inheritance |
| **Verification Required** | A headless script per item, before acceptance: (1) an `@abstract` class with non-abstract fields and methods, and instantiating it fails; (2) an override of `@abstract func project(...) -> Dictionary` compiles only with a `return` on every branch; (3) `Callable.is_valid()` after the bound Node is freed; (4) which references actually keep a round alive: whether a named-method `Callable` holds a strong reference to its `RefCounted` object or only its object ID (`godot-specialist` expects the ID, which would mean module → bus → Callable → module is not a cycle), and whether module → registry → view → module state is one, freed only by `registry.clear()`; (5) `is_instance_of(view, ViewClass)` with a `class_name` script; (6) `Dictionary[StringName, Array[Callable]]` fails to parse and `Dictionary[StringName, Array]` with a cast on read works |

**API coverage.** In the repo reference: `@abstract` (bodyless abstract methods), the 4.7 typed-return rule, lambda capture by value. Training data only: everything under Verification Required.

**Verification results (2026-10-12, [`prototypes/adr-verification/README.md`](../../prototypes/adr-verification/README.md)).** (1) PASS: constructing an `@abstract` class by name is a parse error in both the own-line and one-line forms; `load(path).new()` at runtime still instantiates, so construct only by class name. (2) PASS: a typed override missing a branch `return` fails, annotated or not. (3) PASS. (4) a named-method `Callable` does **not** keep its `RefCounted` alive, so the bus is not a cycle; module and view do form one until `registry.clear()`. (5) PASS. (6) PASS: the engine reports "Nested typed collections are not supported".

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Proposed): TickRunner phases, `server_tick(tick)`. ADR-0004 (Proposed): `project()` per event, handle table |
| **Enables** | Every Feature system's server code; ADR-0008 (hold protocol) |
| **Blocks** | All Feature implementation (Match Flow, Objectives, Downing, Defense, Borrowed Face, Monster Abilities, Pings, Scare Events) |
| **Ordering Note** | Amends ADR-0004's `project` signature (`Dictionary`, `{}` = hidden) and supersedes the registry and tick-order sketches in `architecture.md` |

## Context

### Problem Statement
`systems-index.md` says systems talk only through named server events plus read-only replicated state, each state with one owner. Nothing yet says how an event is represented, when subscribers receive it, how a reader gets typed state, or in what order modules run. Four GDD rules turn on same-tick ordering:

- a stun on the tick a transformation completes wins (`borrowed-face.md` rule 9);
- a `MonsterStunned` cancels a takedown commit (`downing-and-rescue.md` rule 4.4);
- a `SurvivorHit` starts the commit at once (rule 4);
- an extraction in the same tick as the deadline wins (`match-flow.md` edge cases and rule 16).

The order sketched in `architecture.md` ran the Match Flow clock first and checked wins nowhere, so a deadline-tick extraction would resolve wrongly.

### Constraints
- All rule logic runs in TickRunner phases (ADR-0002); no wall-clock timers.
- Every client-bound event is projected per peer (ADR-0004).
- Coding standard: dependency injection over singletons; public methods unit-testable.
- GDScript static typing.

### Requirements
- Exact event names from `systems-index.md`; clients never emit.
- One owner per state; readers never write.
- Deterministic order within a tick.
- Unit tests can build any module with fake services.

## Decision

**1. Events.** `ServerEvent` is an `@abstract` class extending `RefCounted` with `tick` and `server_time` fields and two abstract methods: `type() -> StringName` and `project(peer, handles) -> Dictionary`. `project` returns `{}` when the peer receives nothing. Each catalog event is a subclass named `Ev<EventName>` with typed fields, and its file header names its emitter. Every override restates the parent's return type in its signature and ends every branch with an explicit `return` (4.7 typed-return inheritance, `breaking-changes.md`); restating keeps the type visible where the method is read, rather than inherited silently.

The catalog is the 15 events in `systems-index.md`, with names unchanged:

| Event | Emitter |
|---|---|
| `RoundPhaseChanged` | Match Flow |
| `RoundEnded` | Match Flow |
| `SurvivorEscaped` | Match Flow |
| `PlayerConnectionChanged` | Match Flow |
| `SurvivorHit` | Monster Abilities |
| `AbilityUsed` | Monster Abilities |
| `SurvivorDowned` | Downing |
| `SurvivorRescued` | Downing |
| `SurvivorEliminated` | Downing |
| `MonsterStunned` | Survivor Defense |
| `PlayerShocked` | Survivor Defense |
| `BarricadeBroken` | Survivor Defense |
| `FormChanged` | Borrowed Face |
| `ObjectiveProgressChanged` | Survivor Objectives |
| `ScareTriggered` | Scare Events |

A new event needs a `systems-index.md` row first.

**2. EventBus.** A plain `RefCounted`, injected:
- `emit(e)` appends to a queue. It is server only.
- `subscribe(type, handler)` adds a named method to a `Dictionary[StringName, Array]` of handler lists; readers cast elements to `Callable`. GDScript does not nest typed collections, so `Dictionary[StringName, Array[Callable]]` does not compile (`godot-specialist`, 2026-10-12 review; NOT SOURCEABLE from `current-best-practices.md`, Verification Required item 6 settles it).
- `flush()` drains the queue. Each event is delivered to its subscribers in subscribe order, iterating over a copy of the list and skipping callables that are no longer valid.
- Events emitted by handlers during a flush join the same drain, so the whole cascade resolves on that tick. A flush that needs more than `max_flush_rounds` = 8 rounds asserts in debug and logs in release.
- Every event delivered during the tick is also collected for NetAuthority's per-peer projection at the end of the tick (ADR-0002 phase 6).

**3. Handlers run at flush time.** A handler reacts when the flush delivers, whichever phase its module runs in. It may change only its own module's state; reactions to other modules go through new events. A module's `server_tick` then sees any state its handlers changed.

**4. Tick order (ADR-0002 phase 4).** Each step is followed by `bus.flush()`.

1. `MatchFlow.begin` — advance the round clock; phase changes.
2. `SurvivorDefense` — non-hold timers only: stun, immunity and shock lock, rebarricade lockout, hide cue; taser resolution. Hiding, barricading, removing and breaking barricades are holds, timed only by `HoldService` in step 5a (ADR-0008 §1); Defense receives their `on_start`, `on_complete` and `on_cancel` calls.
3. `BorrowedFace` — observation; transformation progress and completion.
4. `MonsterAbilities` — lunge wind-up, dash and hit test (ADR-0003); False Signal; Blackout.
5. `Downing` — takedown commit; bleed-out; rescue.
5a. `Holds` — every hold is checked, started, advanced and completed here (added by ADR-0008), so the same tick's interrupts beat completions.
6. `SurvivorObjectives` — countdown, extraction.
7. `PingsCallouts` — rate limits; delivery.
8. `ScareEvents` — gating; view-offset writes.
9. `MatchFlow.resolve` — win checks in the order evidence escaped, then eliminations, then deadline; then the outcome lock.

How the four same-tick rules hold:
- **Stun beats transform.** Defense runs before Borrowed Face, so the stun state is set when Borrowed Face checks completion.
- **Stun cancels a commit.** The `MonsterStunned` flushed after Defense cancels the commit in Downing's handler.
- **A hit starts the commit at once.** The `SurvivorHit` flushed after Monster Abilities starts the commit in Downing's handler on the same tick.
- **Extraction beats the deadline.** `resolve` runs after extraction, and evidence escaped is checked before the deadline.

**5. State Registry.** A plain `RefCounted`, injected:
- **Register.** An owner calls `register_view(key, owner, view)` once per key; a second registration for a key asserts.
- **The view.** It is an object of a `*View` class with typed getters and no setters, reading the owner's private state.
- **Read.** Readers call `view(key, ViewClass)`, which asserts `is_instance_of(view, ViewClass)` and returns the view.
- **Values.** Owners replace collection values whole, never by element, because packed-array element writes no longer fire setters on 4.7.

The registry's keys are the rows of the `systems-index.md` state table.

**6. Composition root.** One round-server node constructs the services (`TickRunner`, `EventBus`, `StateRegistry`, `Knobs`, `NetAuthority`) and every module, passing services in through `setup()`. There are no gameplay autoloads. Modules subscribe and register views in `setup()`. At round end the root calls `bus.clear()` and `registry.clear()` and drops its module references. That breaks every cycle RefCounted cannot collect: certainly module → registry → view → module (a view reads its owner's state), and module → bus → Callable → module if a `Callable` holds a strong reference (Verification Required item 4; the original premise named only the bus cycle, which the 2026-10-12 review doubts).

**7. Client side.** A `ClientEventRouter` receives ADR-0004's projected per-peer batches and dispatches each payload by its type to client presentation modules. Clients never construct `ServerEvent` objects.

### Architecture Diagram

```
Composition root (round server)
  ├─ services: TickRunner · EventBus · StateRegistry · Knobs · NetAuthority
  └─ modules (setup(services)): MatchFlow · Defense · BorrowedFace · MonsterAbilities
                                Downing · Objectives · Pings · ScareEvents

TickRunner phase 4, one tick:
  MatchFlow.begin ─flush─▶ Defense ─flush─▶ BorrowedFace ─flush─▶ MonsterAbilities ─flush─▶
  Downing ─flush─▶ Holds ─flush─▶ Objectives ─flush─▶ Pings ─flush─▶ ScareEvents ─flush─▶ MatchFlow.resolve ─flush
  flush = drain queue (≤ 8 rounds) → subscribers in subscribe order → collect for projection
phase 6: NetAuthority projects collected events per peer (ADR-0004)
```

### Key Interfaces

```gdscript
@abstract
class_name ServerEvent extends RefCounted
var tick: int
var server_time: float
@abstract func type() -> StringName
@abstract func project(peer: int, handles: HandleTable) -> Dictionary   # {} = not sent to this peer

class_name EventBus extends RefCounted
func emit(e: ServerEvent) -> void
func subscribe(type: StringName, handler: Callable) -> void
func flush() -> void                       # drains; asserts after max_flush_rounds
func take_tick_events() -> Array[ServerEvent]
func clear() -> void

class_name StateRegistry extends RefCounted
func register_view(key: StringName, owner: StringName, view: Object) -> void
func view(key: StringName, expected: Script) -> Object   # asserts is_instance_of
func clear() -> void

# Every Feature module
func setup(tick_runner: TickRunner, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void
func server_tick(tick: int) -> void
```

### Implementation Guidelines
- `@abstract` **must** sit on its own line above `class_name`, as in `current-best-practices.md` and ADR-0008.
- Every catalog event **must** be a `ServerEvent` subclass named `Ev<EventName>`, implementing `type()` and `project()`, restating each parent return type, with a `return` on every branch.
- Only the emitter named in `systems-index.md` **must** emit an event. Clients **must never** emit.
- A handler **must** change only its own module's state. Cross-module effects **must** go through events.
- Handlers **must** be named methods, not lambdas.
- Readers **must** obtain state through `registry.view(key, ViewClass)`. They **must never** hold a reference to another module.
- View classes **must** expose getters only.
- Owners **must** replace collection values whole.
- Modules **must** receive services through `setup()`. Gameplay services **must never** be autoloads.
- The composition root **must** call `bus.clear()` and `registry.clear()` at round end.
- `max_flush_rounds` **must** come from data.

## Alternatives Considered

### Alternative 1: Deliver events only at the end of the tick
- **Description**: Queue all events and deliver after the last module.
- **Pros**: Simplest ordering story.
- **Cons**: Every reaction lands one tick late; same-tick rules would need extra state reads.
- **Rejection Reason**: Breaks "a hit starts the commit at once" and "stun cancels a commit" without workarounds.

### Alternative 2: Immediate synchronous dispatch
- **Description**: `emit` calls subscribers immediately.
- **Pros**: No queue.
- **Cons**: Re-entrant calls mid-phase; outcome depends on call depth.
- **Rejection Reason**: Non-deterministic in practice; hard to test.

### Alternative 3: Godot signals as the bus
- **Description**: One signal per event type.
- **Pros**: Engine-native.
- **Cons**: Signal names are static; connection-order guarantees not documented in the repo reference.
- **Rejection Reason**: An explicit Callable list makes the order a documented property.

### Alternative 4: Autoload singletons for services
- **Description**: Services as autoloads, read by name.
- **Pros**: No wiring.
- **Cons**: Global state across rounds; modules untestable in isolation; against the coding standard.
- **Rejection Reason**: Designer decision 2026-10-12: composition root.

### Alternative 5: Generic key-to-Variant registry
- **Description**: `registry.read(key) -> Variant`.
- **Pros**: One store.
- **Cons**: Loses static typing; misspelled keys fail at runtime.
- **Rejection Reason**: Designer decision 2026-10-12: typed views.

## Consequences

### Positive
- The four same-tick GDD rules hold by construction.
- Every event's projection is enforced at compile time by `@abstract`.
- Any module can be unit-tested with a fake bus, registry and knobs.
- No global state leaks between rounds.

### Negative
- 15 event classes and roughly 10 view classes to maintain.
- Handlers may run while another module's phase has not yet run, so handlers must stay small and only touch their own state.
- A cascade longer than 8 rounds is treated as a bug.

## Risks
- **Hidden ordering assumptions.** A new rule may need a different order. Mitigation: any order change is an ADR amendment; tick-order tests encode the four rules above.
- **Reference cycles.** Mitigation: `clear()` on bus and registry at round end; an orphan-node and object-count check in the round-teardown test (gdUnit4 reports orphans); Verification Required item 4 names which cycles exist.
- **`@abstract` behaviour on 4.7.2.** Mitigation: Verification Required items 1–2.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| systems-index.md | Systems talk through the named server events plus read-only replicated state; only the owner writes; clients never emit | Decisions 1, 2, 5 |
| borrowed-face.md | Rule 9: a stun on the tick the 2 s elapse is processed first | Decision 4: Defense before Borrowed Face |
| downing-and-rescue.md | Rule 4: `SurvivorHit` starts the commit; `MonsterStunned` cancels it | Decisions 3–4: flush after Monster Abilities and after Defense |
| match-flow.md | Rule 16 and edge cases: evidence escaped is checked first; an extraction at or before the deadline tick counts | Decision 4: `MatchFlow.resolve` last, evidence before deadline |
| match-flow.md | Rule 4: the round clock runs on the server only | Decision 4: `MatchFlow.begin` |
| All GDDs | Every tuning value read from data | `Knobs` injected through `setup()` |

## Performance Implications
- **CPU**: Up to 9 flushes per tick; most deliver nothing. Negligible against the 2 ms server-tick budget.
- **Memory**: One queue and one list of events per tick.
- **Load Time**: None.
- **Network**: None directly; projection is ADR-0004's.

## Migration Plan
No production code exists. Amends ADR-0004's `project` return type to `Dictionary` (`{}` = not sent). Updates `architecture.md`'s API Boundaries §2 and Data Flow tick order.

## Validation Criteria
- Unit tests for each same-tick rule: stun and transform completion in one tick; hit then stun in one tick; extraction on the deadline tick.
- A test fails if any `ServerEvent` subclass in the catalog lacks `type()` or `project()`.
- A cascade test asserts after 8 flush rounds.
- A round-teardown test shows no leaked modules or orphan nodes.
- Each Verification Required script passes on 4.7.2.

## Related
- ADR-0002 — TickRunner phases (depends on)
- ADR-0004 — `project()` (depends on; amended)
- `docs/architecture/architecture.md` — API Boundaries §2, Data Flow (updated)
- `design/gdd/systems-index.md`, `design/gdd/match-flow.md`, `design/gdd/borrowed-face.md`, `design/gdd/downing-and-rescue.md`
