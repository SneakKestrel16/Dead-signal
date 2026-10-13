# Dead Signal — Master Architecture

## Document Status

- Version: 1
- Last Updated: 2026-10-12
- Engine: Godot 4.7.2 (GDScript)
- GDDs Covered: `lobby-role-assignment`, `first-person-controller`, `match-flow`, `survivor-objectives`, `downing-and-rescue`, `survivor-defense`, `borrowed-face`, `monster-abilities`, `pings-and-callouts`, `scare-events`, plus the Facility Map in `design/levels/research-facility.md`. Not covered (no GDD yet): HUD & Results Screen, Accessibility Options, Match Telemetry.
- ADRs Referenced: none. No ADRs exist yet (see [ADR Audit](#adr-audit)).
- Evidence beyond the GDDs: `prototypes/networking-spike/README.md` (single-machine results, 2026-10-12).
- TD-ARCHITECTURE: 2026-10-12 — skipped — Lean mode
- LP-FEASIBILITY: 2026-10-12 — skipped — Lean mode

TR IDs used in this document (`TR-net-*`, `TR-core-*`, ...) are provisional working IDs keyed by domain. `/architecture-review` re-keys them by system when it bootstraps `docs/architecture/tr-registry.yaml`. Nothing has been written to the registry.

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
│ CORE           First-Person Controller & Interaction · Borrowed Face │
│                Lobby & Role Assignment · Facility Map                │
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
2. **The event catalog lives in Foundation and Feature systems only emit.** The Controller is Foundation-level yet consumes `RoundEnded` and `PlayerConnectionChanged`, which Match Flow emits. With the catalog in Foundation, the Controller subscribes to the bus and never imports Match Flow, so dependencies still point down. This is an inference; the GDDs say only "event-only, not a layer dependency".
3. **Borrowed Face stays in Core.** It reads Feature-layer state (stun lock, takedown commit, lunge state) through the State Registry, not by import. The systems index treats event and state reads as non-layer dependencies (cross-review 12d W3).

**Engine awareness (Foundation and Core)**

| System | Engine domain | Risk |
|---|---|---|
| Network Authority | SceneMultiplayer, ENet, `MultiplayerSynchronizer` visibility | NOT SOURCEABLE for 4.7; spike-backed |
| Controller | Jolt `CharacterBody3D`, input device IDs | HIGH |
| Facility Map | Lighting states, audio `area_mask`, `Area3D` zones | HIGH |
| Event Catalog / State Registry | GDScript typed overrides, packed-array setters | HIGH |
| Borrowed Face | Animation, `LookAtModifier3D` if used | MEDIUM |

## Module Ownership

Engine API tags: **V** = covered by the engine reference or proven by the networking spike. **NV** = not covered; verify before an ADR relies on it.

### Platform and Foundation

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| Network Authority & Replication | Session and peer table, server tick and clock, per-player input queue (1–2 tick buffer), snapshot history for rewind, per-peer visibility rules, reconnect tokens, join auth | `submit_intent`, `server_time`, `rewound_positions`, `set_entity_visible_to`, `send_event` | Event Catalog (transport), Data/Config | `ENetMultiplayerPeer` V · `SceneMultiplayer.auth_callback` V (spike) · `@rpc` V · `MultiplayerSynchronizer.set_visibility_for` V (spike) · `MultiplayerSpawner` V · `set_multiplayer_authority` V |
| Event Catalog + State Registry | The 15 named server events and the read-only replicated state table; one declared owner per state key | `emit` (server only), `subscribe`, `read` | Network (transport to clients) | GDScript signals and typed `Resource`s. HIGH: 4.7 typed-return override and packed-array setter changes |
| Data/Config loader | Every tuning knob, loaded from data files and validated at load | `get_float`, `get_int` | none | `Resource` / `FileAccess` V |

### Core

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| First-Person Controller & Interaction | Capsule, gaits, effective speed, modifier stack (lock > root > slow), server view direction and view offset, hold protocol, doors | `add_root`/`add_slow`/`add_lock`/`remove`, `view_ray`, interactable definition, hold start/cancel | Network (intent, tick), Registry (`RoundEnded`, `PlayerConnectionChanged`, flinch toggle), Data | `CharacterBody3D.move_and_slide` V · `PhysicsRayQueryParameters3D` V · `Input.get_vector` V · HIGH: Jolt default, `InputEvent.DEVICE_ID_*` |
| Borrowed Face | Observation timers, observed list, form, Transforming flag, form-change cooldown | `FormChanged`, form and Transforming state, `displayed_identity(player)` | Controller (speeds, rejection), Facility Map (line of sight), Registry (stun lock, Committing, Lunge state) | Server line of sight via `intersect_ray` V · skeleton/animation copy NV |
| Lobby & Role Assignment | Roster, rotation queue, preferences, ready flags, countdown, proximity-voice setting | Locked roster handed to Match Flow, `PlayerRoster` state | Network (join, peers), Data | `SceneMultiplayer` V, `ENetMultiplayerPeer` V · UI `Control` nodes (dual focus) V |
| Facility Map | Level geometry, door state, lighting-volume state, `blackout_able`, active candidate set, camera feeds, exit state, spawn points | Door, volume and exit state, `candidates_for(peer)`, line-of-sight geometry | Registry (`RoundPhaseChanged`, `ObjectiveProgressChanged`), Network (visibility) | `Light3D` / `WorldEnvironment` NV · `Compositor` V · `Area3D` zones HIGH · `AudioStreamPlayer.area_mask` HIGH |

### Feature

| Module | Owns | Exposes | Consumes |
|---|---|---|---|
| Match Flow | Round clock, phase, win evaluation, outcome lock, disconnect grace, results payload | `RoundPhaseChanged`, `RoundEnded`, `SurvivorEscaped`, `PlayerConnectionChanged` | Lobby roster, Objectives (armed, extracted), Downing (eliminated) |
| Survivor Objectives | Active points, drive/fuse/terminal state, carry, discovery, activation countdown | `ObjectiveProgressChanged` | Controller holds, Facility Map candidates, Downing drops, Defense hidden state |
| Downing, Rescue & Elimination | Life state, `downs_taken`, takedown commit, bleed-out, rescue progress | `SurvivorDowned`, `SurvivorRescued`, `SurvivorEliminated`; takedown eligibility, Committing | `SurvivorHit`, `MonsterStunned`, positions |
| Survivor Defense | Charges, stun and immunity, shock lock, hiding spots, barricades, flashlight | `MonsterStunned`, `PlayerShocked`, `BarricadeBroken`; hidden and shock-lock state | Controller view ray, Borrowed Face form, Lunge state |
| Monster Abilities | Lunge, False Signal and Blackout state, cooldowns, hit resolution | `SurvivorHit`, `AbilityUsed` (server-only); Lunge state | Network rewind, Borrowed Face, Downing eligibility, Facility Map volumes |
| Pings & Callouts | Ping tokens, callout cooldowns, markers, displayed-identity attribution | Per-recipient presentation messages | Borrowed Face identity, `AbilityUsed`, Controller view ray |
| Scare Events (server half) | Scare gating, cooldowns, budgets, recipients, view-offset writes | `ScareTriggered`, view offset | Many events; Facility Map lighting requests |

Feature modules are mostly GDScript over Foundation and Core. Exceptions: `intersect_ray` hit-scan (V), `AudioStreamPlayer3D` spatial cues (V), and proximity voice (NOT SOURCEABLE).

### Presentation

HUD & Results, Scare Events client half, Accessibility Options and Match Telemetry consume events and registry state only and own no gameplay state. `Control` and `RichTextLabel` carry the 4.7 renames (`UPDATE_WIDTH_UNIT`) and the 4.6 dual-focus change.

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
  ▶ Monster Abilities (hit test on rewound positions) ▶ Downing (commit, bleed, rescue)
  ▶ Objectives (holds, countdown, extraction) ▶ Pings ▶ Scare gating
  ▶ Match Flow resolve (evidence escaped, then eliminations, then deadline)
   ▼
Network: per-peer snapshot + event projection ─▶ send
```

Client frame: sample input, predict locally, send intent, receive snapshot, reconcile (under 1 m smoothed over 100 ms, larger snaps), interpolate remote players 100 ms behind, render.

The fixed order is a requirement. Four GDD rules are tick-order rules: a stun on the tick a transform completes wins (`borrowed-face.md` rule 9); `SurvivorHit` starts the commit and `MonsterStunned` cancels it on the same tick (`downing-and-rescue.md` rule 4); an extraction in the same tick as the deadline wins (`match-flow.md` edge cases); a stun since wind-up cancels the hit (`monster-abilities.md` rule 7). ADR-0005 shows how the order satisfies each.

### Event and signal path

| Flow | Producer → Consumer | Mode | Notes |
|---|---|---|---|
| Server-internal event | emitter module → subscribers | Queue drained after each module phase (ADR-0005) | Clients can never emit |
| Registry state read | owner → reader | Shared state, read-only | Only the owner writes |
| Client intent | client → Network → owning module | Reliable RPC (`any_peer`), server validates | A forged "done" message is dropped |
| Event to clients | emitter → Network → each recipient | Reliable RPC, per-recipient payload projection | See below |
| Position and state stream | server → clients | Unreliable snapshots | State-changing facts never travel unreliably |

**Payload projection.** The emitting module supplies `project(event, recipient)` and Network executes it. This keeps `PlayerShocked` identical for a shocked survivor, a stunned disguised monster and an immune disguised monster; sends `MonsterStunned` to survivors only for a true-form monster; strips `source` from `ScareTriggered`; and withholds bleed-out state from the shapeshifter's client. Per-entity hiding (undiscovered drives, hallucinations) uses `MultiplayerSynchronizer` visibility, verified by the spike (H4).

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

```gdscript
class_name NetAuthority extends Node

func is_server() -> bool
func server_time() -> float                         # server clock, seconds since round start
func submit_intent(kind: StringName, payload: Dictionary) -> void   # client -> server, reliable
func rewound_positions(at_time: float, max_rewind_s: float) -> Dictionary  # {player_id: Vector3}
func set_entity_visible_to(entity: Node, peers: PackedInt32Array) -> void
func send_event(event: ServerEvent, project: Callable) -> void      # project(event, peer_id) -> Dictionary or null
```

- Invariants: intent handlers treat payloads as untrusted; `send_event` is server-only; `project` returning `null` means the peer receives nothing.
- Guarantees: one player's intents are consumed in order; reliable events arrive in emit order per recipient; `rewound_positions` clamps to `max_rewind_s` and reports the clamp so disputes can be logged.
- Open: the value of `max_rewind_s` is ADR 3.

### Event Catalog and State Registry (Foundation)

Superseded in detail by ADR-0005 (typed read-only views, drain-flush after each module phase, composition-root wiring).

```gdscript
@abstract class_name ServerEvent extends RefCounted   # one Ev<EventName> subclass per catalog event
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

@abstract class_name Interactable extends Resource
@export var range_m: float
@export var duration_s: float                        # 0 = instant
@abstract func can_start(actor: int) -> bool
@abstract func on_complete(actor: int) -> void       # owner emits its event here
@abstract func on_cancel(actor: int, cause: StringName) -> void
```

- Invariants: the effective modifier is the most restrictive, never a product; one hold per actor; Start is checked on the server against range, line of sight and the exclusive lock.
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
class_name Knobs extends Node
func get_float(key: StringName) -> float            # asserts key exists; no silent default
func get_int(key: StringName) -> int
```

- Invariants: no gameplay literal in code; cross-knob constraints are validated at load, and a bad config falls back to defaults with a logged error.

### Not specified here

Per-event payload schemas (15 events) belong to the Event Catalog ADR. Borrowed Face's render interface waits on its rendering ADR.

## ADR Audit

`docs/architecture/` contains no ADRs. The ADR quality check (engine compatibility, version, GDD linkage, conflicts, validity) was **not run** because there is nothing to check.

**Traceability coverage: 0 of 41 baseline requirements covered, 41 gaps.** The baseline was extracted from 10 system GDDs plus the Facility Map level doc. `first-person-controller.md` has no `## Tuning Knobs` heading, so it was read from Formulas and Dependencies. The table below is the condensed baseline (the architecture-driving requirements, not all roughly 200 acceptance criteria).

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

Once the ADRs below exist, every row above names the ADR that is expected to cover it. Until then the status of all rows is a gap.

## Required ADRs

At `workflow: standard` only critical ADRs are required. The "before coding" list is the critical set.

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

- Borrowed Face rendering and replication (shared rig or separate models, footstep-set copy) — rend-003 — MEDIUM
- Lighting states and Blackout (volumes, reset, reduced-flash, camera feeds) — rend-001, rend-002, map-003, map-004 — HIGH, and `Light3D` is not in the engine reference
- Spatial audio and cue pipeline (buses, `area_mask`, ducking, bearing accuracy) — audio-001, audio-002, audio-004 — HIGH
- Objective candidate selection and discovery filter (seeded RNG) — core-006 — Low
- Scare replication scoping and view offset — net-008, input-002 — Low
- UI and input-focus framework (lobby, HUD, hold bar, dual focus, AccessKit) — ui-001, ui-002 — HIGH
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

- **Rewind budget.** Needed rewind is one-way latency plus 100 ms interpolation: about 160 ms at 50 ms RTT and 260 ms at 150 ms RTT, against the 150 ms cap in `monster-abilities.md`. Raise the cap to about 250–300 ms, cut interpolation to about 50 ms, or both, then rerun the dodge-window check. Accepting any value reopens that GDD. [ADR 3]
- **Hosting model and real networks.** Listen vs dedicated server is undecided. Real WAN latency and loss, home upload, NAT and port forwarding, clock drift and Wi-Fi spikes are untested (the spike's deferred list). [ADR 1]
- **Monster identity leak.** Can survivor clients be kept from learning which entity is the monster? `FormChanged` names the shapeshifter and the Transforming flag sits on its entity (`borrowed-face.md` Open Questions). [ADR 4]
- **Spectator scope.** Eliminated and Escaped players should receive exactly what the survivor they watch receives (`pings-and-callouts.md`), but no GDD defines the replication mechanism. [ADR 4]
- **Borrowed Face rendering.** Shared rig or separate models is in no GDD. [Should-have ADR]
- **NOT SOURCEABLE gaps.** `Light3D` and lighting volumes, proximity voice transport, engine-internal threading, 4.7 networking beyond the spike. The networking module doc needs a 4.7 refresh. [lighting, voice and ADR 1]
- **Dedicated-server support.** `lobby-role-assignment.md` rule 1 defers it to the Network Authority ADR and no acceptance criterion covers it. [ADR 1]
- **Missing GDDs.** HUD & Results Screen (`/ux-design`), Accessibility Options and Match Telemetry have no design doc, so their requirements are not in the baseline.
