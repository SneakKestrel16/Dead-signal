# Dead Signal — Master Architecture

## Document Status

- Version: 2
- Last Updated: 2026-10-12
- Engine: Godot 4.7.2 (GDScript)
- GDDs Covered: `lobby-role-assignment`, `first-person-controller`, `match-flow`, `survivor-objectives`, `downing-and-rescue`, `survivor-defense`, `borrowed-face`, `monster-abilities`, `pings-and-callouts`, `scare-events`, plus the Facility Map in `design/levels/research-facility.md`. Not covered (no GDD yet): HUD & Results Screen, Accessibility Options, Match Telemetry.
- ADRs Referenced: ADR-0001 to ADR-0013, all Proposed (see [ADR Audit](#adr-audit)). Where this document and an ADR differ, the ADR wins.
- Evidence beyond the GDDs: `prototypes/networking-spike/README.md` (single-machine results, 2026-10-12).
- TD-ARCHITECTURE: 2026-10-12 — skipped — Lean mode
- LP-FEASIBILITY: 2026-10-12 — skipped — Lean mode

TR IDs in the [ADR Audit](#adr-audit) baseline (`TR-net-*`, `TR-core-*`, ...) are the provisional domain-keyed IDs from version 1. `/architecture-review` re-keyed them by system into [`tr-registry.yaml`](tr-registry.yaml) (138 requirements); use the registry IDs for stories.

## Engine Knowledge Gap Summary

The model's training data covers Godot to about 4.3. The project is pinned to 4.7.2, so four releases are post-cutoff. Sources: `docs/engine-reference/godot/` (breaking changes, deprecated APIs, best practices, module docs).

**HIGH RISK — verify against the engine reference before deciding**

| Domain | What changed | Why it matters here |
|---|---|---|
| Physics | Jolt is the 3D default since 4.6; 4.7 changed `Area3D` overlap reporting and `SoftBody3D` | Player capsules, lunge hit tests, line of sight, door overlap checks |
| Core / GDScript | 4.7: overrides inherit the parent's typed return and need an explicit `return`; `arr_prop[i] = x` no longer fires the property setter | Event Catalog, State Registry, any replicated state held in packed arrays |
| Input | 4.7: mouse and keyboard device IDs are no longer `0`; compare with `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` or test the event type | Controller input handling |
| Audio | 4.7: `AudioStreamPlayer` `area_mask` default is `0` | Per-room audio overrides and Blackout audio |
| Rendering | D3D12 is the Windows default (4.6); glow runs before tonemapping (4.6); reflection and sRGB changes in 4.7 | Lighting states, Blackout, flash caps |
| UI | Dual focus (4.6); AccessKit screen reader support (4.5); `RichTextLabel` renames (4.7) | Lobby, HUD, accessibility |

**MEDIUM RISK:** Animation (`LookAtModifier3D.relative` default flipped in 4.7; restored IK is unused).

**LOW RISK / not needed:** Navigation (there are no AI agents, so the module is not used).

**NOT SOURCEABLE** — the repo's engine reference does not cover these, and nothing in this document fills the gap from training data:

- Networking on 4.7. `modules/networking.md` is a 4.6 snapshot (verified 2026-02-12); the 4.7 migration guide lists no multiplayer changes. The networking spike ran on 4.7.2 and is the only 4.7 evidence.
- `Light3D` and lighting-volume APIs.
- Proximity voice capture and transport.
- Engine-internal threading (ENet service, audio mixer, render threads).
- New 4.7 features beyond the migration guide.
- Dedicated-server export.

## System Layer Map

```
┌──────────────────────────────────────────────────────────────────────┐
│ PRESENTATION   Scare Events (client half) · HUD & Results · Lobby UI │
│                Accessibility Options · Match Telemetry (Alpha)       │
├──────────────────────────────────────────────────────────────────────┤
│ FEATURE        Match Flow · Survivor Objectives · Downing/Rescue     │
│                Survivor Defense · Monster Abilities · Pings/Callouts │
│                Scare Events (server half: gating, recipients)        │
├──────────────────────────────────────────────────────────────────────┤
│ CORE           First-Person Controller & Interaction (HoldService)   │
│                Borrowed Face · Lobby & Role Assignment · Facility Map│
├──────────────────────────────────────────────────────────────────────┤
│ FOUNDATION     Network Authority & Replication (session, tick,       │
│                  intent, snapshots, rewind buffer, per-peer          │
│                  visibility, reconnect tokens, join auth)            │
│                Event Catalog + Replicated-State Registry             │
│                Data/Config loader (all tuning knobs)                 │
├──────────────────────────────────────────────────────────────────────┤
│ PLATFORM       Godot 4.7.2: SceneTree, SceneMultiplayer/ENet, Jolt,  │
│                AudioServer, RenderingServer (D3D12 on Windows)       │
└──────────────────────────────────────────────────────────────────────┘
```

Three structural decisions govern the map (approved 2026-10-12):

1. **Every gameplay system has a server half and a client half.** The server half runs in the authoritative simulation, which on a listen server is the host's process. The client half is view, prediction and input. Many GDD rules state what a role must never receive (TR-net-007 to TR-net-012), so the split is a module boundary rather than a convention.
2. **The event catalog lives in Foundation and Feature systems only emit.** The Controller is Core-level (ADR-0008 §1) yet consumes `RoundEnded` and `PlayerConnectionChanged`, which Match Flow emits. With the catalog in Foundation, the Controller subscribes to the bus and never imports Match Flow, so dependencies still point down. This is an inference; the GDDs say only "event-only, not a layer dependency". (`systems-index.md` files the Controller under its "Core" category, which that document defines as "foundation systems everything depends on"; its category names are not this map's layers. Version 1 of this decision called the Controller Foundation-level, contradicting the map.)
3. **Borrowed Face stays in Core.** It reads Feature-layer state (stun lock, takedown commit, lunge state) through the State Registry, not by import. The systems index treats event and state reads as non-layer dependencies (cross-review 12d W3).

**Engine awareness (Foundation and Core)**

| System | Engine domain | Risk |
|---|---|---|
| Network Authority | SceneMultiplayer, ENet, `MultiplayerSynchronizer` visibility | NOT SOURCEABLE for 4.7; spike-backed |
| Controller | Jolt `CharacterBody3D`, input device IDs | HIGH |
| Facility Map | Lighting states, audio `area_mask`; zones are analytic boxes, no `Area3D` (ADR-0007 §9) | HIGH |
| Event Catalog / State Registry | GDScript typed overrides, packed-array setters | HIGH |
| Borrowed Face | Animation, `LookAtModifier3D` if used | MEDIUM |

## Module Ownership

Engine API tags: **V** = covered by the engine reference or proven by the networking spike. **NV** = not covered; verify before an ADR relies on it.

### Platform and Foundation

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| Network Authority & Replication | Session and peer table, server tick and clock, per-player input queue (1–2 tick buffer), snapshot history for rewind, per-peer relevance and handles, reconnect tokens, join auth | `TickRunner`, `InputFrame` / `InputQueue` (ADR-0002), `RewindHistory` / `LagCompensation` (ADR-0003), `Relevance` / `HandleTable` (ADR-0004) | Event Catalog (transport), Data/Config | `ENetMultiplayerPeer` V · `SceneMultiplayer.auth_callback` V (spike) · `@rpc` V · `MultiplayerSynchronizer.set_visibility_for` V (spike) · `MultiplayerSpawner` V · `set_multiplayer_authority` V |
| Event Catalog + State Registry | The 15 named server events and the read-only replicated state table; one declared owner per state key | `EventBus.emit` (server only), `subscribe`, `flush`; `StateRegistry.view` (ADR-0005) | Network (transport to clients) | `@abstract` `RefCounted` event classes, `Callable` handler lists. HIGH: 4.7 typed-return override and packed-array setter changes |
| Data/Config loader | Every tuning knob, loaded from data files and validated at load | `Knobs` with one typed section per system, `ticks(seconds)` (ADR-0006) | none | `Resource` / `FileAccess` V |

### Core

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| First-Person Controller & Interaction | Capsule, gaits, effective speed, modifier stack (lock > root > slow), server view direction and view offset, `HoldService` (ADR-0008) | `add_root`/`add_slow`/`add_lock`/`remove`, `view_ray`, `Interactable`, `HoldService.register`/`cancel` | Network (intent, tick), Registry (`RoundEnded`, `PlayerConnectionChanged`, flinch toggle), Data | `CharacterBody3D.move_and_slide` V · `PhysicsRayQueryParameters3D` V · `Input.get_vector` V · HIGH: Jolt default, `InputEvent.DEVICE_ID_*` |
| Borrowed Face | Observation timers, observed list, form, Transforming flag, form-change cooldown | `FormChanged`, form and Transforming state, `displayed_identity(player)` | Controller (speeds, rejection), Facility Map (line of sight), Registry (stun lock, Committing, Lunge state) | Server line of sight via `intersect_ray` V · skeleton/animation copy NV |
| Lobby & Role Assignment | Roster, rotation queue, preferences, ready flags, countdown, proximity-voice setting | Locked roster handed to Match Flow, `PlayerRoster` state | Network (join, peers), Data | `SceneMultiplayer` V, `ENetMultiplayerPeer` V · UI `Control` nodes (dual focus) V |
| Facility Map | Level geometry, door open/closed state, lighting-volume state, `blackout_able`, active candidate set, camera feeds, exit state, spawn points, visibility sets (ADR-0004), analytic zones (ADR-0007) | Door, volume and exit state, `candidates_for(peer)`, `MapQueries`, line-of-sight geometry | Registry (`RoundPhaseChanged`, `ObjectiveProgressChanged`), Network (visibility) | `Light3D` / `WorldEnvironment` NV · `Compositor` V · `AudioStreamPlayer.area_mask` HIGH |

### Feature

| Module | Owns | Exposes | Consumes |
|---|---|---|---|
| Match Flow | Round clock, phase, win evaluation, outcome lock, disconnect grace, results payload | `RoundPhaseChanged`, `RoundEnded`, `SurvivorEscaped`, `PlayerConnectionChanged` | Lobby roster, Objectives (armed, extracted), Downing (eliminated) |
| Survivor Objectives | Active points, drive/fuse/terminal state, carry, discovery, activation countdown | `ObjectiveProgressChanged` | Controller holds, Facility Map candidates, Downing drops, Defense hidden state |
| Downing, Rescue & Elimination | Life state, `downs_taken`, takedown commit, bleed-out, rescue progress | `SurvivorDowned`, `SurvivorRescued`, `SurvivorEliminated`; takedown eligibility, Committing | `SurvivorHit`, `MonsterStunned`, positions |
| Survivor Defense | Charges, stun and immunity, shock lock, hiding spots, barricade state (barricaded, break progress, lockout), door interaction rules, flashlight | `MonsterStunned`, `PlayerShocked`, `BarricadeBroken`; hidden and shock-lock state | Controller view ray, Borrowed Face form, Lunge state |
| Monster Abilities | Lunge, False Signal and Blackout state, cooldowns, hit resolution | `SurvivorHit`, `AbilityUsed` (server-only); Lunge state | Network rewind, Borrowed Face, Downing eligibility, Facility Map volumes |
| Pings & Callouts | Ping tokens, callout cooldowns, markers, displayed-identity attribution | Per-recipient presentation messages | Borrowed Face identity, `AbilityUsed`, Controller view ray |
| Scare Events (server half) | Scare gating, cooldowns, budgets, recipients, view-offset writes | `ScareTriggered`, view offset | Many events; Facility Map `LightingView` (ambush test, Blackout blocking); requests no lighting (ADR-0009 §7) |

Feature modules are mostly GDScript over Foundation and Core. Exceptions: `intersect_ray` hit-scan (V), `AudioStreamPlayer3D` spatial cues (V), and proximity voice (NOT SOURCEABLE).

### Presentation

`BodyPuppet`/`ClientBodies` and `AudioDirector` (client modules from ADR-0010 and ADR-0013), HUD & Results, Scare Events client half, Accessibility Options and Match Telemetry consume events and registry state only and own no gameplay state. Round stats are getter-only `*StatsView`s registered by their owners and read once by `MatchFlow.resolve` (ADR-0011); objective discovery and Borrowed Face observation share one server `SightTest` (ADR-0012). `Control` and `RichTextLabel` carry the 4.7 renames (`UPDATE_WIDTH_UNIT`) and the 4.6 dual-focus change.

### Dependency direction

```
Presentation ─▶ Feature ─▶ Core ─▶ Foundation ─▶ Platform
  (upward reads go through the Event Catalog / State Registry, never direct imports)
Feature ⇄ Feature: events and registry reads only (no direct module references)
```

## Data Flow

### Server tick (60 Hz)

The spike measured about 0.15 ms of simulation for 6 capsules plus about 0.1 ms to send.

```
Network.poll ─▶ dequeue 1 input per player (1–2 tick buffer, last-3 redundancy)
   ▼
Controller: apply modifier stack ─▶ move_and_slide (Jolt) for every capsule
   ▼
Network: push positions into snapshot history (rewind source)
   ▼
Feature tick, FIXED ORDER (ADR-0005), event queue drained after each step:
  Match Flow begin (clock, phase) ▶ Defense (stun/immunity) ▶ Borrowed Face (observe, transform)
  ▶ Monster Abilities (hit test on rewound positions) ▶ Facility Map (Blackout expiry, ADR-0009) ▶ Downing (commit, bleed, rescue)
  ▶ Holds (every hold timed, ADR-0008) ▶ Objectives (countdown, extraction) ▶ Pings ▶ Scare gating
  ▶ Match Flow resolve (evidence escaped, then eliminations, then deadline)
   ▼
Network: per-peer snapshot + event projection ─▶ send
```

Client frame: sample input, predict locally, send intent, receive snapshot, reconcile (restore position, velocity and floor snap, replay; under 1 m smoothed over 100 ms, larger snaps; ADR-0002), interpolate remote players 50 ms behind (ADR-0003), render.

The fixed order is a requirement. Four GDD rules are tick-order rules: a stun on the tick a transform completes wins (`borrowed-face.md` rule 9); `SurvivorHit` starts the commit and `MonsterStunned` cancels it on the same tick (`downing-and-rescue.md` rule 4); an extraction in the same tick as the deadline wins (`match-flow.md` edge cases); a stun since wind-up cancels the hit (`monster-abilities.md` rule 7). ADR-0005 shows how the order satisfies each.

### Event and signal path

| Flow | Producer → Consumer | Mode | Notes |
|---|---|---|---|
| Server-internal event | emitter module → subscribers | Queue drained after each module phase (ADR-0005) | Clients can never emit |
| Registry state read | owner → reader | Shared state, read-only | Only the owner writes |
| Client intent | client → Network → owning module | Input frames (move, view, hold bit and target): unreliable, last 3 frames redundant. Item use, ping, callout: reliable RPC tagged with the frame's `seq` (ADR-0002, ADR-0008). Server validates both | No completion message exists to forge; holds are timed on the server |
| Event to clients | emitter → Network → each recipient | Reliable RPC, per-recipient payload projection | See below |
| Position and state stream | server → clients | Unreliable snapshots | State-changing facts never travel unreliably |

**Payload projection.** Each event class implements `project(peer, handles) -> Dictionary` (`{}` = not sent) and Network batches the results per peer (ADR-0004 §5, ADR-0005 §1). This keeps `PlayerShocked` identical for a shocked survivor, a stunned disguised monster and an immune disguised monster; sends `MonsterStunned` to survivors only for a true-form monster; strips `source` from `ScareTriggered`; and withholds bleed-out state from the shapeshifter's client. Bodies reach clients only through per-peer snapshots, named by per-peer handles re-issued on re-entry and filtered by the authored room PVS (ADR-0004 §2–4). Per-entity hiding of non-body entities (undiscovered drives, hallucinations) uses `MultiplayerSynchronizer` visibility, verified by the spike (H4); the spawner-leak case is still open (ADR-0004 Verification Required 1).

### Save and load

None. `TR-save-001`: no progression and no persistence. In memory only: rotation queue, character preferences and session tokens (lost when the host exits, which closes the session). Read-only data files (tuning knobs, character table, candidate points) load at boot. Nothing is serialised, so no module owns serialisation.

### Initialisation order

```
1 Platform (engine boot)  2 Data/Config  3 Event Catalog + Registry
4 Network (host: create_server / client: create_client + auth_callback)
5 Lobby (roster, ready, countdown)
-- countdown 0: roster locked --
6 Match Flow: Loading (wait for all clients, 60 s timeout, else Cancelled)
7 Facility Map load, candidate selection (seeded), spawn placement
8 Controller spawns capsules; Feature modules init round state
9 Match Flow ▶ Infiltration, first RoundPhaseChanged
```

A reconnect re-enters at step 6's state: the server sends the current registry and visibility-filtered entities and replays no missed scare.

### Thread boundaries

No module-level threading is planned; simulation, replication and presentation run on the main loop. Engine-internal threads are NOT SOURCEABLE from the engine reference, so nothing is asserted about them.

## API Boundaries

Typed GDScript. Engine types used (`Resource`, `StringName`, `Callable`, `Vector3`, `Node`) are stable since 4.0; `@abstract` is 4.5+ and listed in `current-best-practices.md`. Every override of a typed method ends in an explicit `return` (4.7).

### Network Authority (Foundation)

Version 1's `NetAuthority.submit_intent`, `rewound_positions` and `set_entity_visible_to` are superseded. Full signatures live in the ADRs; the main types:

```gdscript
class_name InputFrame extends RefCounted     # ADR-0002 §3; ADR-0003 and ADR-0008 add fields
var seq: int; var move: Vector2; var sprint: bool; var crouch: bool; var yaw: float; var pitch: float
var view_tick: float; var ack_snapshot_tick: int
var interact: bool; var interact_target: int; var target_is_body: bool

class_name TickRunner extends Node           # ADR-0002 §2: the only server tick loop
func current_tick() -> int
func register_feature(module: Object, phase_order: int) -> void

class_name RewindHistory extends RefCounted  # ADR-0003 §4
func sample(player_id: int, tick: float) -> Dictionary   # ok = false when out of history

class_name LagCompensation extends RefCounted   # ADR-0003 §6: every server hit test
func rewind_ticks(attacker_id: int, tick: int) -> float  # clamped; logs disputes

class_name HandleTable extends RefCounted    # ADR-0004 §3: per-peer opaque body handles
func handle_for(peer: int, player_id: int) -> int
func retire(peer: int, player_id: int) -> void
```

- Invariants: input packets are validated (lengths, ≤ 3 frames, finite) before any element is read; clients never send position, speed or progress; rule timers count ticks, never the wall clock; client payloads name bodies by handle, never by the shapeshifter's player ID.
- Guarantees: one player's frames are consumed in `seq` order; reliable events arrive in emit order per recipient; the rewind is clamped to `max_rewind_ms` = 180 and the server-measured RTT bound, and every clamp is logged (ADR-0003).

### Event Catalog and State Registry (Foundation)

Superseded in detail by ADR-0005 (typed read-only views, drain-flush after each module phase, composition-root wiring).

```gdscript
@abstract
class_name ServerEvent extends RefCounted   # one Ev<EventName> subclass per catalog event
var tick: int
var server_time: float
@abstract func type() -> StringName
@abstract func project(peer: int, handles: HandleTable) -> Dictionary   # {} = not sent (ADR-0004)

class_name EventBus extends RefCounted
func emit(e: ServerEvent) -> void                   # server only; queued
func subscribe(type: StringName, handler: Callable) -> void
func flush() -> void                                # drained after each module phase, ≤ 8 rounds

class_name StateRegistry extends RefCounted
func register_view(key: StringName, owner: StringName, view: Object) -> void   # one owner per key
func view(key: StringName, expected: Script) -> Object                         # asserts type; getters only
```

- Invariants: a second registration for a key asserts; views expose getters only; owners replace collection values whole (4.7: packed-array element writes no longer fire setters); services are injected by the composition root, never autoloads.
- Guarantees: a handler reacts on the same tick its event is emitted; delivery is in emit order, subscribers in subscribe order.

### Controller modifiers and interactables (Core)

```gdscript
class_name MovementModifiers extends RefCounted
func add_root(player: int, owner: StringName) -> void
func add_slow(player: int, owner: StringName, mult: float, duration_s: float) -> void
func add_lock(player: int, owner: StringName) -> void
func remove(player: int, owner: StringName) -> void   # removes only that owner's modifiers

@abstract
class_name Interactable extends RefCounted          # ADR-0008 §2; was Resource with can_start
var net_id: int
var range_m: float
var duration_s: float                                # 0 = instant
var lock_key: StringName                             # &"" = no lock
@abstract func eligible(actor: int) -> bool
@abstract func start_progress_s() -> float
@abstract func on_complete(actor: int) -> void       # owner emits its event here
@abstract func on_cancel(actor: int, progress_s: float, reason: StringName) -> void
```

- Invariants: the effective modifier is the most restrictive, never a product; the owning client predicts it from its own snapshot entry (ADR-0002 §5); one hold per actor; only `HoldService` times holds; Start is checked on the server against range, line of sight and the exclusive lock.
- Guarantees: `on_complete` fires exactly once, on the server, never from a client message.

### Lobby to Match Flow roster handoff (Core to Feature)

```gdscript
class_name RosterEntry extends Resource
var peer_id: int; var display_name: String; var role: StringName   # &"shapeshifter" | &"survivor"
var character: StringName                                           # &"C1".."C5", empty for the shapeshifter

class_name Roster extends Resource
var session_id: String; var round_index: int; var player_count: int; var entries: Array[RosterEntry]
```

- Invariants: 4 ≤ `player_count` ≤ 6; exactly one shapeshifter; survivor characters distinct; immutable for the round.

### Data/Config (Foundation)

```gdscript
class_name Knobs extends RefCounted                 # ADR-0006; was Node with get_float(key)
var defense: DefenseKnobs                           # one typed Resource section per system
static func load_all() -> Knobs
func errors() -> PackedStringArray                  # [] = valid
func digest() -> String                             # joins the build version in ADR-0001's join check
func ticks(seconds: float) -> int
```

- Invariants: no gameplay literal in code; ranges and cross-knob constraints are validated at load, and a bad config refuses to host (ADR-0006; was fall back to defaults). Frozen per round.

### Not specified here

Per-event payload schemas (15 events) belong to the Event Catalog ADR. Borrowed Face's render interface waits on its rendering ADR.

## ADR Audit

Thirteen ADRs exist, all **Proposed**; none is Accepted, so no requirement is yet covered by an accepted decision.

| ADR | Decision | Acceptance waits on ([verification results](../../prototypes/adr-verification/README.md)) |
|---|---|---|
| [ADR-0001](adr-0001-hosting-session-join-reconnect.md) | Listen server over direct ENet, separable server role, `auth_callback` join check, session-token reconnect | Spike's deferred real-network tests (single-machine items done) |
| [ADR-0002](adr-0002-authoritative-sim-tick-input.md) | 60 Hz `TickRunner`, redundant unreliable input frames, adaptive 1–2 frame queue, per-peer snapshots, owner-only prediction and replay | Real-network tests (replay, floor restore and interpolation OFF verified) |
| [ADR-0003](adr-0003-lag-compensation-rewind.md) | 50 ms interpolation, 180 ms rewind cap bounded by measured RTT, analytic hit tests on rewound capsules | Real-network tests (pursuit rerun passed, 27 ms margin) |
| [ADR-0004](adr-0004-replication-scope-information-hiding.md) | Bodies only through per-peer snapshots, per-peer handles re-issued on re-entry, authored room PVS, per-event projection | Authored visibility table (spawner-leak case passed) |
| [ADR-0005](adr-0005-event-catalog-state-registry-tick-order.md) | `@abstract` event classes with `project()`, drain-flush after each module phase, typed read-only views, fixed module order, composition root | Nothing outstanding; verification passed |
| [ADR-0006](adr-0006-data-driven-configuration.md) | Typed knob `Resource` sections, load-time validation, refuse to host on a bad config | Digest on a second machine (export load verified) |
| [ADR-0007](adr-0007-movement-physics-collision-layers.md) | Jolt `CharacterBody3D`, ramp colliders, four collision layers with named masks, analytic zones and interactables | Nothing outstanding; verification passed (floor angle and same-tick queries amended) |
| [ADR-0008](adr-0008-hold-to-interact-protocol.md) | One `HoldService` times every hold from the input frame's hold bit, as one tick step | Nothing outstanding beyond the lock test written with `HoldService` |
| [ADR-0009](adr-0009-lighting-states-and-blackout.md) | Facility Map owns per-volume lighting (base, overlays, Blackout) with its own tick step; replicated under visibility sets like doors; dynamic lights from presets; seeded client flicker; one live surveillance feed with relevance extended | Greybox rendering and profiling spike (Verification 1–10) |
| [ADR-0010](adr-0010-borrowed-face-rendering.md) | One `BodyPuppet` per handle; appearance is a data child scene swapped in place; shared survivor rig; overlay warp | Verification 1-7 on the greybox |
| [ADR-0011](adr-0011-round-stats-and-results-payload.md) | Owners keep counters, expose `*StatsView`s; `MatchFlow.resolve` builds `RoundResults` once | Verification 1 (payload size) |
| [ADR-0012](adr-0012-objective-discovery.md) | One server `SightTest`; discovery grants the hidden entity to survivor peers | Verification 1-2 |
| [ADR-0013](adr-0013-spatial-audio-pipeline.md) | Fixed bus tree, catalog-driven pooled 3D players, scripted ducking, server-side footstep masking, client occlusion ray | Verification 1-4 |

**Traceability coverage** (from [`architecture-review-2026-10-12.md`](architecture-review-2026-10-12.md), 138 registry requirements): 0 covered by an Accepted ADR, 114 covered by a Proposed ADR, 19 partial, 2 gaps (deferred voice), 3 need no ADR (third review, `architecture-review-2026-10-12c.md`). Full matrix: [`requirements-traceability.md`](requirements-traceability.md).

The table below is version 1's condensed baseline of 41 architecture-driving requirements, kept because the ADR column shows which planned ADR each was assigned to. The baseline was extracted from 10 system GDDs plus the Facility Map level doc; `first-person-controller.md` has no `## Tuning Knobs` heading, so it was read from Formulas and Dependencies.

| Req ID | Source | Requirement | Domain | ADR |
|---|---|---|---|---|
| TR-net-001 | all GDDs | Server authoritative for hits, stuns, cooldowns, objectives, downs, rescue, outcomes; clients send intent only | Networking | 2 |
| TR-net-002 | controller | Server-owned movement with prediction and reconciliation; 500 ms intent timeout | Networking | 2 |
| TR-net-003 | monster-abilities | Lag-compensated lunge check; rewind of positions only; cap `max_rewind_ms` | Networking | 3 |
| TR-net-004 | lobby | Listen server, direct ENet join, version and lobby-cap validation | Networking | 1 |
| TR-net-005 | match-flow, lobby | Reconnect token restores the slot for 60 s; host leaving closes the session | Networking | 1 |
| TR-net-006 | borrowed-face | Disguise and Transforming state reach all clients within 250 ms, including reconnect mid-disguise | Networking | 4 |
| TR-net-007 | survivor-defense, borrowed-face | Identical `PlayerShocked` payload for survivor, stunned and immune disguised monster | Networking | 4 |
| TR-net-008 | scare-events | `ScareTriggered` strips source and identity; hallucinations go to one client | Networking | 4 |
| TR-net-009 | survivor-objectives | Undiscovered drive rooms and fuse spawns never sent to survivor clients | Networking | 4 |
| TR-net-010 | downing | Shapeshifter client never receives bleed-out state | Networking | 4 |
| TR-net-011 | monster-abilities, pings | `AbilityUsed` stays server-side; fake callout packets match real ones | Networking | 4 |
| TR-net-012 | pings | Monster client gets survivor pings only in its line of sight; callouts as audio only | Networking | 4 |
| TR-core-001 | systems-index | 15 server events plus a read-only state table, one owner per state | Core | 5 |
| TR-core-002 | controller | Modifier arbitration: lock > root > lowest slow | Core | 7 |
| TR-core-003 | controller | Hold-to-interact protocol | Core | 8 |
| TR-core-004 | match-flow | Server clock, phases, outcome lock, tick-ordered win checks | Core | 5 |
| TR-core-005 | all GDDs | All tuning knobs loaded from data | Core | 6 |
| TR-core-006 | survivor-objectives | Seeded random selection of active points with placement constraints | Core | Should: candidate selection |
| TR-core-007 | lobby | Rotation queue and character assignment (post-M1) | Core | none needed (pure logic) |
| TR-phys-001 | controller | Capsule r 0.30, h 1.8 / 1.2; step 0.35 m; slope 40°; no jump | Physics | 7 |
| TR-phys-002 | monster-abilities | Per-tick lunge hit test (1.2 m, 60° cone, chest-to-chest line of sight) | Physics | 7 |
| TR-phys-003 | borrowed-face, pings | Server line-of-sight queries against level geometry | Physics | 7 |
| TR-phys-004 | survivor-defense | Taser hit-scan with aim tolerance; pass-through of Seized/Downed survivors | Physics | 7 |
| TR-phys-005 | survivor-defense | Doors and barricades block dash and line of sight; close rejected on overlap | Physics | 7 |
| TR-audio-001 | pings, controller | Spatial audio; footstep radii 2 / 6 / 20 m; bearing within ±15° | Audio | Should: audio |
| TR-audio-002 | scare-events | Stinger cap +6 dB; ducking on `PlayerShocked`; gameplay cues never masked | Audio | Should: audio |
| TR-audio-003 | pings | Optional proximity voice, host toggle, distortion filter | Audio | Deferred |
| TR-audio-004 | pings, lobby | One voice set per character C1–C5 | Audio | Should: audio |
| TR-rend-001 | scare-events, facility | Lighting volumes, Blackout, Low Power and Emergency states | Rendering | Should: lighting |
| TR-rend-002 | scare-events | At most 3 flashes per second; flash scale 0; flinch toggle | Rendering | Should: lighting |
| TR-rend-003 | borrowed-face | Disguise renders the copied model, animations and footsteps | Rendering | Should: Borrowed Face |
| TR-input-001 | controller, pings | Input actions: move, sprint, crouch, interact, item, ping wheel; no jump | Input | 7 |
| TR-input-002 | controller, scare-events | Server-held view offset capped at `flinch_max_angle_deg` | Input | Should: scare scoping |
| TR-ui-001 | pings, HUD | Ping markers, callout wheel and feed, hold bar, results screen | UI | Should: UI |
| TR-ui-002 | lobby | Lobby screen: host/join, ready, picker, queue, countdown | UI | Should: UI |
| TR-perf-001 | spike | 60 Hz simulation, 6 players, about 87 kbps up per client | Performance | 2 |
| TR-perf-002 | all GDDs | 250 ms agreement across 5 clients on life, form and objective state | Performance | 4 |
| TR-save-001 | match-flow | No persistence | Persistence | none needed |
| TR-map-001 | research-facility | Server owns door, lighting-volume and exit state | Networking | 4 |
| TR-map-002 | research-facility | Candidate points replicated per peer (monster all; survivors only discovered) | Networking | 4 |
| TR-map-003 | research-facility | 17 lighting volumes with `blackout_able` | Rendering | Should: lighting |
| TR-map-004 | research-facility | Server-driven camera feed content | Rendering | Should: lighting |

A number in the ADR column is the ADR with that number (2 = ADR-0002). Per-requirement status is tracked in the traceability matrix, not here.

## Required ADRs

At `workflow: standard` only critical ADRs are required. The "before coding" list is the critical set. All eight are written as ADR-0001 to ADR-0008 (Proposed); each must be accepted, parents first, before code that depends on it is written.

### Must have before coding starts (Foundation and Core)

| # | ADR | Covers | Engine risk |
|---|---|---|---|
| 1 | Hosting model, session, join auth and reconnect (listen vs dedicated, direct ENet, token reconnect, host-leave) | net-004, net-005 | NOT SOURCEABLE for 4.7. The deferred WAN/NAT tests can follow the draft but must precede acceptance |
| 2 | Authoritative simulation, tick rate and input handling (60 Hz, 1–2 tick input buffer, prediction, correction smoothing) | net-001, net-002, perf-001 | Spike-backed |
| 3 | Lag compensation and rewind budget (rewind = one-way latency + interpolation delay; cap vs 50 ms interpolation; rerun the dodge check) | net-003 | Spike H3 contradicts the 150 ms assumption. Design-relevant |
| 4 | Replication scope and information hiding (per-peer visibility, per-recipient payload projection, whether survivors can learn which entity is the monster, spectator scope) | net-006 to net-012, map-001, map-002, perf-002 | `MultiplayerSynchronizer` visibility spike-verified |
| 5 | Event Catalog, State Registry and tick order | core-001, core-004 | HIGH: GDScript 4.7 typed overrides, packed-array setters |
| 6 | Data-driven configuration (knob format, load-time validation) | core-005 | Low |
| 7 | Player movement, physics and collision layers (Jolt `CharacterBody3D`, capsule, hit-test queries, door overlap) | phys-001 to phys-005, core-002, input-001 | HIGH: Jolt default, 4.7 device IDs and `Area3D` changes |
| 8 | Interaction (hold-to-interact) protocol | core-003 | Low |

### Should have before the relevant system is built

- **Written: [ADR-0010](adr-0010-borrowed-face-rendering.md) (Proposed).** Borrowed Face rendering and appearance swap — rend-003 — MEDIUM
- **Written: [ADR-0009](adr-0009-lighting-states-and-blackout.md) (Proposed).** Lighting states and Blackout (volumes, reset, reduced-flash, camera feeds) — rend-001, rend-002, map-003, map-004 — HIGH, and `Light3D` is not in the engine reference
- **Written: [ADR-0013](adr-0013-spatial-audio-pipeline.md) (Proposed).** Spatial audio and cue pipeline (buses, ducking, occlusion) — audio-001, audio-002, audio-004 — HIGH
- **Written: [ADR-0012](adr-0012-objective-discovery.md) (Proposed).** Objective discovery and seeded candidate selection (§6, TR-objectives-002) — core-006 — Low
- **Written: [ADR-0011](adr-0011-round-stats-and-results-payload.md) (Proposed).** Round stats and results payload — Low
- Scare replication scoping and view offset — net-008, input-002 — Low
- **Written: [ADR-0014](adr-0014-ui-and-input-focus.md) (Proposed).** UI and input-focus framework (lobby, HUD, hold bar, dual focus, AccessKit) — ui-001, ui-002 — HIGH
- Server-sim testability (injectable clock and RNG, headless server), which the unit-test acceptance criteria in the GDDs assume — Low

### Can defer

- Proximity voice transport (Off by default; NOT SOURCEABLE) — audio-003
- Match Telemetry log format (Alpha)
- Accessibility hooks implementation (Vertical Slice)

## Architecture Principles

1. **The server decides; clients ask.** Clients send intent and render results. No client message reports a hit, a completion or an outcome.
2. **Hiding information is a module boundary, not a convention.** Each gameplay system has a server half and a client half. Anything a role must not know is never sent, via per-recipient payload projection and per-peer visibility.
3. **Ordering is explicit.** One fixed tick order and a deferred event queue make same-tick rules deterministic (stun beats transform, extraction beats deadline).
4. **State has one owner; layers point down.** Reads across systems go through the State Registry or the Event Catalog, never direct imports.
5. **Data over code.** Every tuning knob lives in data and is validated at load. A gameplay literal in code is a bug.

## Open Questions

Each blocks the ADR named in brackets.

- **Real networks.** Real WAN latency and loss, home upload, NAT and port forwarding, clock drift and Wi-Fi spikes are untested (the spike's deferred list). They gate acceptance of ADR-0001 to ADR-0003. [ADR-0001]
- **Borrowed Face rendering.** Shared rig or separate models is in no GDD. [Should-have ADR]
- **NOT SOURCEABLE gaps.** `Light3D` and lighting volumes, proximity voice transport, engine-internal threading, 4.7 networking beyond the spike. The networking module doc needs a 4.7 refresh. [lighting, voice, ADR-0001]
- **Missing GDDs.** HUD & Results Screen (`/ux-design`), Accessibility Options and Match Telemetry have no design doc, so their requirements are not in the baseline.

Resolved since version 1:
- **Rewind budget**: 50 ms interpolation and a 180 ms cap bounded by measured RTT (ADR-0003); the pursuit simulation still needs its rerun at 0.43 s.
- **Hosting model**: listen server for MVP with a separable server role; dedicated hosting stays possible but is not built (ADR-0001).
- **Monster identity leak**: per-peer handles re-issued on re-entry and per-event projection (ADR-0004).
- **Spectator scope**: a spectator receives the stream projected for the watched survivor; switching re-issues every handle (ADR-0004 §8).
