# Control Manifest

> **Engine**: Godot 4.7.2
> **Last Updated**: 2026-10-12
> **Manifest Version**: 2026-10-12
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011, ADR-0012, ADR-0013
> **Status**: Active, built from **Proposed** ADRs (none Accepted yet; autonomous decision AD-27). Regenerate with `/create-control-manifest update` when any ADR is accepted or revised.

`Manifest Version` is the date this manifest was generated. Story files embed
this date when created. `/story-readiness` compares a story's embedded version
to this field to detect stories written against stale rules. Always matches
`Last Updated` — they are the same date, serving different consumers.

This manifest is a programmer's quick-reference extracted from all ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR. Forbidden-pattern IDs in brackets match
`docs/registry/architecture.yaml`.

---

## Foundation Layer Rules

*Applies to: session and transport (NetAuthority), the server tick (TickRunner), events and state registry, replication scope, data configuration, composition root*

### Required Patterns
- **Key all gameplay and lobby state by player ID; peer IDs are transport addresses only, inside `NetAuthority`** — source: ADR-0001
- **Decode auth payloads with `bytes_to_var` only, after checking payload size and every field's type** — source: ADR-0001
- **Set `auth_callback`, `auth_timeout` and `server_relay = false` on `SceneMultiplayer` before assigning `multiplayer_peer`, on host and client** — source: ADR-0001
- **Send a reject reason with `send_auth`, then `disconnect_peer` only after `reject_close_delay_s` (0.2 s); an immediate disconnect loses the reason** — source: ADR-0001
- **The host's local player submits intent through the same queue as remote players; the server role must run with no local player** — source: ADR-0001
- **On reconnect: evict the stale peer first (no "dropped" notification), re-apply per-peer visibility, send a full snapshot before any delta** — source: ADR-0001
- **Send a session token only to its owner; never log it in telemetry or show it in UI** — source: ADR-0001
- **Run all rule logic from `TickRunner` phases (dequeue, movement, history, feature `server_tick`, flush, snapshots)** — source: ADR-0002
- **Count every rule timer in server ticks, converting with `Knobs.ticks()`** — source: ADR-0002, ADR-0006
- **Set `Engine.physics_ticks_per_second` once at boot from data (`sim_tick_hz` 60)** — source: ADR-0002
- **Validate input RPCs (equal array lengths, at most 3 frames, all floats finite, `seq` ordering and `max_seq_ahead`) before reading any element; drop the whole packet on failure** — source: ADR-0002
- **Use separate transfer channels for input, snapshots and reliable intents/events** — source: ADR-0002
- **State-changing facts travel as reliable events, never in snapshots** — source: ADR-0002
- **Player bodies reach clients only through per-peer snapshots, named by per-peer handles; introduce a handle on the reliable channel before any use; retire it on a form change or transform start during linger** — source: ADR-0004
- **Every catalog event implements `project()`; an event with no projection is never sent** — source: ADR-0004, ADR-0005
- **Sounds are positional events with no handle** — source: ADR-0004
- **Spawned non-body nodes: opaque counter names, identity-free payloads, `public_visibility = false` before `spawn()` returns, `set_visibility_for` grants in the same frame** — source: ADR-0004
- **Per-peer RPCs target fixed-name nodes; puppet nodes carry no RPCs** — source: ADR-0004
- **Relevance (`relevance_near_m`, `relevance_linger_s`) and visibility sets come from data and Facility Map data** — source: ADR-0004
- **Events are `ServerEvent` subclasses named `Ev<EventName>`, implementing `type()` and `project()`, restating each parent return type, with a `return` on every branch** — source: ADR-0005
- **Put `@abstract` on its own line above `class_name`** — source: ADR-0005, ADR-0008
- **Only the emitter named in `systems-index.md` emits an event; handlers are named methods and change only their own module's state** — source: ADR-0005
- **Read other modules' state only through `registry.view(key, ViewClass)`; view classes expose getters only; owners replace collection values whole** — source: ADR-0005
- **Modules receive services through `setup()` from the composition root; the root calls `bus.clear()` and `registry.clear()` at round end** — source: ADR-0005
- **Every GDD tuning knob is an `@export_range` field in its owning `<System>Knobs` section, named exactly as in the GDD, defaulting to `NAN` or `KnobUnset.INT`** — source: ADR-0006
- **Load knob files only from `res://data/knobs/`; a validation error refuses to host** — source: ADR-0006
- **Every cross-knob check cites its source GDD or ADR in a comment** — source: ADR-0006
- **Unit tests build knob sections with `.new()`; one integration test loads the shipped files and asserts `errors()` is empty** — source: ADR-0006
- **Network values (port, `max_clients` headroom, `auth_timeout`, ENet timeout, `reject_close_delay_s`, payload cap, queue depths and cap, starvation thresholds, `intent_timeout_ms`, `max_flush_rounds`) come from data** — source: ADR-0001, ADR-0002, ADR-0005

### Forbidden Approaches
- **Never store a peer ID as identity outside `NetAuthority`** [peer_id_as_identity] — reconnect rebinds peers — source: ADR-0001
- **Never read the host's input directly on the server** [host_input_shortcut] — host shortcuts leak into rules — source: ADR-0001
- **Never let clients reach each other** [client_to_client_relay] — source: ADR-0001
- **Never use `bytes_to_var_with_objects`** — remote code/object injection — source: ADR-0001
- **Never run rules in a module's own `_physics_process`** [rules_in_own_physics_process] — source: ADR-0002
- **Never read `Time` or the wall clock in a rule timer** [wall_clock_rule_timer] — source: ADR-0002
- **Never accept position, velocity, speed or progress from a client** [client_sent_position] — client-authoritative movement was rejected — source: ADR-0002
- **Never use deterministic lockstep or a 30 Hz simulation** — Jolt determinism undocumented; 30 Hz breaks lunge hit checks — source: ADR-0002
- **Never spawn or sync player bodies with `MultiplayerSpawner` / `MultiplayerSynchronizer`** — no prediction, leaks identity — source: ADR-0002, ADR-0004
- **Never put the shapeshifter's player ID or a stable body ID in a client-bound payload during a round** [shapeshifter_id_in_client_payload] — source: ADR-0004
- **Never broadcast a server event's raw payload** [unprojected_client_event] — source: ADR-0004
- **Never name a node after a player ID, peer ID, handle, role or character** [identifying_node_names] — source: ADR-0004
- **Never use stable per-round handles or handles equal to player IDs** — reopens the disguise leak — source: ADR-0004
- **Never make gameplay services autoloads** [gameplay_autoload_service] — source: ADR-0005
- **Never write another module's state; never hold a reference to another module** [direct_cross_system_state_write] — source: ADR-0005
- **Never set a collection element in place on a view-exposed value** [elementwise_collection_write] — source: ADR-0005
- **Never use Godot signals as the event bus or dispatch events synchronously; never use a generic key-to-Variant registry** — order must be documented and deterministic; views are typed — source: ADR-0005
- **Never use lambdas as event handlers** — source: ADR-0005
- **Never put a tuning literal in gameplay code** [tuning_literal_in_code] — source: ADR-0006
- **Never fall back to defaults on a bad knob file** [knob_default_fallback] — source: ADR-0006
- **Never load `.tres`/`.res` from `user://` or a player-supplied path** [user_path_resource_load] — source: ADR-0006
- **Never write a knob field at runtime** [knob_write] — knobs are frozen per round — source: ADR-0006
- **Never send knob values from host to clients** — the digest in the version string keeps everyone on shipped data — source: ADR-0006

### Performance Guardrails
- **Server tick (all TickRunner phases)**: max 2.0 ms — source: ADR-0002, `docs/registry/architecture.yaml` performance_budgets
- **Network**: about 87 kbps host upload per client at 60 Hz (spike envelope); client upload about 40 kbps — source: ADR-0002
- **Snapshots**: about 200 bytes per peer per snapshot (estimate, unmeasured) — source: ADR-0004
- **Event flushes**: at most `max_flush_rounds` (8) per module phase — source: ADR-0005
- **Knob load and validation**: under 10 ms per boot (inference) — source: ADR-0006

---

## Core Layer Rules

*Applies to: first-person controller, movement and physics, input, hit tests, hold-to-interact*

### Required Patterns
- **One movement step function shared by server and owning client; floor and slide settings from data** — source: ADR-0002, ADR-0007
- **Owner-only prediction: restore acked position and velocity, call `apply_floor_snap()` if on floor, replay unacked frames, correct only beyond `correction_deadzone_m` (0.005)** — source: ADR-0002
- **Corrections under `correction_smooth_max_m` decay on a visual child with `physics_interpolation_mode` OFF; every snap calls `reset_physics_interpolation()`** — source: ADR-0002
- **Predicted movement collides with static geometry and replicated door state; other players are server-corrected** — source: ADR-0002, ADR-0007
- **Restore a player found inside geometry to the last valid position** — source: ADR-0002
- **Jolt `CharacterBody3D` players; each player owns its capsule resources (built with `.new()`)** — source: ADR-0007
- **Climb steps through ramp colliders** — source: ADR-0007
- **Every physics query uses a `PhysicsLayers` mask (`MOVE_SERVER`, `MOVE_PREDICT`, `SIGHT`, `PROJECTILE`)** — source: ADR-0007
- **Gameplay zones and interactables are analytic from map data** — source: ADR-0007
- **Input goes through the named input actions; device checks use event type or `InputEvent.DEVICE_ID_*`** — source: ADR-0007
- **Use `set_deferred` only inside physics callbacks** — source: ADR-0007
- **Every server hit test goes through `LagCompensation`; lunge and taser share it** — source: ADR-0003
- **Rewind only target positions; read eligibility, stun, hiding, grace, door and barricade state at the current tick** — source: ADR-0003
- **Reject a non-finite or future `view_tick`; clamp the rewind by the server-measured RTT bound and `max_rewind_ms` (180); log a dispute when clamped** — source: ADR-0003
- **World rays use `SIGHT` for line of sight and `PROJECTILE` for taser and dash; doors and barricades are tested as analytic boxes from authoritative state** — source: ADR-0003
- **Rewind values (`interp_delay_ms` 50, `max_extrapolation_ms`, `max_rewind_ms`, `history_ticks` 16, `slack_ticks`) come from data** — source: ADR-0003
- **Only `HoldService` times holds; owners keep stored progress between holds** — source: ADR-0008
- **Read the hold target only on the rising edge of `interact`; start range is strict `range_m`, continuation `range_m + hold_range_tolerance_m`** — source: ADR-0008
- **Hold line-of-sight rays use `PROJECTILE` plus the analytic door test and exclude the actor's own RID** — source: ADR-0008
- **Decide contested hold locks by ADR-0007's rotated player order** — source: ADR-0008
- **Resolve body targets through the requesting peer's handle table** — source: ADR-0004, ADR-0008
- **Run `HoldService.server_tick` only inside TickRunner's physics phases** (it queries `direct_space_state`) — source: ADR-0008
- **Pack the input flags byte whole each frame** — source: ADR-0008
- **Every `Interactable` override restates the parent's return type, `void` included** — source: ADR-0005, ADR-0008

### Forbidden Approaches
- **Never write client-only movement code** — source: ADR-0002
- **Never assume the previous floor state carries over after setting position** — source: ADR-0002
- **Never use `RigidBody3D` players or a hand-written kinematic controller** — incompatible with ADR-0002; `move_and_slide` suffices — source: ADR-0007
- **Never write custom step-up code** — source: ADR-0007
- **Never use inline layer or mask numbers** [inline_layer_numbers] — source: ADR-0007
- **Never share a shape between players** [shared_player_shape] — source: ADR-0007
- **Never use `Area3D` for gameplay zones or put interactables on a physics layer** — source: ADR-0007
- **Never use `WorldBoundaryShape3D`** — 4.7 Jolt plane-sign change — source: ADR-0007
- **Never detect keyboard or mouse with `event.device == 0`** [device_zero_check] — source: ADR-0007
- **Never move a physics body or use `intersect_shape` to hit-test players** — source: ADR-0003
- **Never rewind eligibility or door state** [rewound_eligibility] — source: ADR-0003
- **Never take latency from the client's claim alone** [client_claimed_latency] — source: ADR-0003
- **Never test the taser without rewind** — one lag model for every hit test — source: ADR-0003
- **Never count hold progress in an owner** [owner_timed_hold] — source: ADR-0008
- **Never accept a client completion or progress message for a hold** [client_hold_complete] — source: ADR-0008
- **Never use reliable Start/Stop RPCs or EventBus events for holds** — source: ADR-0008

### Performance Guardrails
- **Movement**: 6 `move_and_slide` calls per tick on the server (about 0.055 ms in the spike); prediction replays up to about 15 steps per snapshot — source: ADR-0002, ADR-0007
- **Hit tests**: a dash is about 18 ticks × (up to 5 capsule tests + 1 ray); a taser shot is 1 ray + up to 5 capsule tests — source: ADR-0003
- **Holds**: at most 5 rays per tick — source: ADR-0008
- **Rewind history**: 6 players × 16 ticks × about 40 bytes — source: ADR-0003

---

## Feature Layer Rules

*Applies to: Monster Abilities, Survivor Defense, Borrowed Face, Downing and Rescue, Survivor Objectives, Pings and Callouts, Scare Events*

### Required Patterns
- **Run in ADR-0005's tick order: MatchFlow.begin > Defense > BorrowedFace > MonsterAbilities > Downing > Holds > Objectives > Pings > Scare > MatchFlow.resolve** — source: ADR-0005, ADR-0008
- **Implement `server_tick(tick)` and register with `TickRunner`; never rely on `_physics_process`** — source: ADR-0002
- **Hold owners emit their own catalog events from `on_complete` and `on_cancel`** — source: ADR-0008
- **Fake holds (shapeshifter) take no lock, change no progress and never call the owner** — source: ADR-0008
- **Monster Abilities validates a Blackout target through `LightingView` before emitting `AbilityUsed`** — source: ADR-0009
- **Every `duration_s`, `range_m`, `hold_range_tolerance_m` and `interact_ray_max_m` comes from data** — source: ADR-0008
- **Each results field has one owner that counts it and exposes a getter-only `*StatsView` under `stats.<system>`; `MatchFlow.resolve` reads them once on the outcome tick into `RoundResults` on `RoundEnded`** — source: ADR-0011
- **`RoundResults.to_dict()` builds fresh untyped containers (`assign`, `merge`); telemetry consumes the `RoundEnded` payload, never the views** — source: ADR-0011
- **Objective discovery and Borrowed Face observation use the one server `SightTest` (distance, then cone, then `SIGHT` rays + analytic doors), only in TickRunner physics phases; sample points sit ≥ 5 cm off surfaces** — source: ADR-0012
- **An undiscovered point stays ungranted on every survivor peer until discovery; the shapeshifter and hidden survivors never discover** — source: ADR-0012
- **Footstep masking scales the server's send radius by the volume's `footstep_radius_scale`** — source: ADR-0013

### Forbidden Approaches
- **Never let `HoldService` emit events** [hold_service_events] — source: ADR-0008
- **Never let a fake hold take a lock** [fake_hold_lock] — source: ADR-0008
- **Never have each owner run its own hold logic** — copies drift — source: ADR-0008
- **Never emit an event from a client** — source: ADR-0005
- **Never let Match Flow tally other systems' stats or call into their modules; never compute results on a client** — source: ADR-0011
- **Never decide discovery from a client report, proximity alone or room entry** — source: ADR-0012

---

## Presentation Layer Rules

*Applies to: rendering, lighting, audio, UI, HUD, VFX, camera*

### Required Patterns
- **Render remote players `interp_delay_ms` (50) behind the estimated server tick; extrapolate at most `max_extrapolation_ms`, then hold** — source: ADR-0003
- **The local body uses physics interpolation; camera yaw and pitch render at frame rate from local input** — source: ADR-0002
- **Only `FacilityMap` writes lighting state; everything else reads `LightingView`** — source: ADR-0009
- **Send lighting records only for volumes in the peer's visibility set (plus a viewed camera's set); re-send on re-entry, reconnect and spectator switch** — source: ADR-0009
- **Clients render lighting only from received records and `LightingPresets`; flicker is a pure function of payload seed and elapsed server ticks, clamped to `max_flashes_per_s` and the player's flash scale** — source: ADR-0009
- **`emergency_strip` lights stay on in every state, Blackout included** — source: ADR-0009
- **Set the surveillance `SubViewport` to `UPDATE_DISABLED` whenever its client is not viewing** — source: ADR-0009
- **Keep each light's range inside its own volume; pre-warm every preset at load with a camera sweep through each volume** — source: ADR-0009
- **Apply the `max_flashes_per_s` clamp in the per-tick flicker precompute; apply only the flash scale at render time** — source: ADR-0009
- **Count `max_shadowed_omni` / `max_shadowed_spot` per rendered view (the feed is a second view)** — source: ADR-0009
- **The feed `SubViewport` sets its own `positional_shadow_atlas_size`; the feed `Camera3D` has its own cheap `Environment`** — source: ADR-0009
- **Lighting values (`blackout_duration_s`, `backup_switch_hold_s`, `light_fade_s`, `max_flashes_per_s`, `max_shadowed_omni`, `max_shadowed_spot`, `feed_resolution`) come from data; looks come from `LightingPresets`; the five ADR-only lighting knobs live in `FacilityKnobs`** — source: ADR-0009, ADR-0006
- **Each body is one `BodyPuppet` per handle; a form change swaps only the `AppearanceSlot` child (remove + `queue_free` + add in one frame); appearances come from `res://data/appearances.tres`, preloaded and render-warmed at load** — source: ADR-0010
- **C1–C5 share one skeleton bone set and one `AnimationLibrary` `.tres`; animation comes only from snapshot fields; `LookAtModifier3D.relative` set explicitly; trees enabled with `AnimationTree.active`** — source: ADR-0010
- **Own body: `cast_shadow = SHADOWS_ONLY` plus the first-person model; a lit body flashlight casts shadows, and per view only the own flashlight and the nearest `max_shadowed_flashlights` others emit light** — source: ADR-0010, ADR-0009
- **Survivor-to-survivor swap: `start(state, false)`, an `AnimationNodeTimeSeek` to the same fraction of the dominant clip, then `advance(0.0)`; the warp overlay is fragment-only and never displaces `VERTEX`** — source: ADR-0010
- **All audio goes through `AudioDirector` and `AudioCatalog`; the pool is built once in `_ready`; a positional sound's `max_distance` equals its server send radius** — source: ADR-0013
- **Ducking writes only `Ambience` and `ScareDuck`; gameplay cues and callouts are never ducked or stolen by scare or ambience sounds** — source: ADR-0013
- **UI and HUD read only projected client state; the HUD never distinguishes real from fake** — source: ADR-0004 (projection), `design/ux/hud.md`

### Forbidden Approaches
- **Never broadcast lighting state to every peer** [lighting_state_broadcast] — source: ADR-0009
- **Never change lighting state locally on a client** (seeded flicker on top is allowed) [client_local_lighting_state] — source: ADR-0009
- **Never send flicker steps as individual messages; never replicate per-light values; never use baked lightmaps per state (revisit in M4)** — source: ADR-0009
- **Never set light looks from code** — source: ADR-0009
- **Never branch presentation on role, player ID or "is monster"** [role_branch_in_presentation] — source: ADR-0010
- **Never free, rename or re-parent a `BodyPuppet` on a form change** [puppet_recreated_on_form_change] — source: ADR-0010
- **Never instantiate an appearance from disk mid-round** — source: ADR-0010
- **Never use sidechain ducking, `Area3D` audio overrides, or mix-only masking of information** — source: ADR-0013
- **Never rely on Shader Baker to prevent mid-round hitches** — the reference only says it shortens startup — source: ADR-0009

### Performance Guardrails
- **Lighting network**: about 6 bytes per changed visible volume, on change only; one flicker message per scare — source: ADR-0009
- **Shadowed lights**: capped by `max_shadowed_omni` / `max_shadowed_spot` (Forward+ limits NOT SOURCEABLE; verify in the lighting spike) — source: ADR-0009

---

## Global Rules (All Layers)

### Naming Conventions
| Element | Convention | Example | Source |
|---------|-----------|---------|--------|
| Classes | PascalCase | `HoldService` | `naming.classes` in project.yaml |
| Variables | snake_case | `server_tick` | `naming.variables` in project.yaml |
| Signals/Events | past_tense | `player_rejoined`, `EvFormChanged` | `naming.signals` in project.yaml; event classes per ADR-0005 |
| Files | snake_case | `hold_service.gd` | `naming.files` in project.yaml |
| Scenes | snake_case | `research_facility.tscn` | `naming.scenes` in project.yaml |
| Constants | SCREAMING_SNAKE | `MOVE_SERVER` | `naming.constants` in project.yaml |

### Performance Budgets
| Target | Value | Source |
|--------|-------|--------|
| Framerate | 60 fps | technical-preferences.md |
| Frame budget | 16.6 ms (server tick 2.0 ms within it) | technical-preferences.md; `docs/registry/architecture.yaml` |
| Draw calls | 2000 per frame (starting point; revise after profiling) | technical-preferences.md |
| Memory ceiling | Not set (target hardware unknown) | technical-preferences.md |

### Approved Libraries / Addons
- gdUnit4 — approved for unit and integration tests — source: technical-preferences.md (Testing: Framework)

### Forbidden APIs (Godot 4.7.2)
These APIs are deprecated for Godot 4.7.2 (3D project; 2D-only rows omitted):
- `VisibilityNotifier3D` → `VisibleOnScreenNotifier3D`
- `Navigation3D` → `NavigationServer3D` (if navigation is ever used)
- `EditorSceneFormatImporterFBX` → `EditorSceneFormatImporterFBX2GLTF`
- `yield()` → `await signal`
- `connect("signal", obj, "method")` → `signal.connect(callable)`
- `instance()` / `PackedScene.instance()` → `instantiate()`
- `get_world()` → `get_world_3d()`
- `OS.get_ticks_msec()` → `Time.get_ticks_msec()` (and never in a rule timer, see Foundation)
- `duplicate()` for nested resources → `duplicate_deep()`
- `Skeleton3D.bone_pose_updated` → `skeleton_updated`
- `AnimationPlayer.method_call_mode` / `playback_active` → `AnimationMixer.callback_mode_method` / `active`
- `RichTextLabel.UPDATE_WIDTH_IN_PERCENT` → `UPDATE_WIDTH_UNIT`
- `AudioEffectSpectrumAnalyzer.tap_back_pos` — removed in 4.7, no replacement
- `DisplayServer.AccessibilityLiveMode` → `AccessibilityServer.AccessibilityLiveMode`
- `Texture2D` in `Shader.set_default_texture_parameter()` → `Texture` base type
- Manual post-process viewport chains → `Compositor` + `CompositorEffect`
- GodotPhysics3D → Jolt Physics 3D (project default)
- Source: `docs/engine-reference/godot/deprecated-apis.md`

### Cross-Cutting Constraints
- **Static typing everywhere: no untyped `Array` / `Dictionary`; cache node references with `@onready`, never `$NodePath` in `_process`** — source: `docs/engine-reference/godot/deprecated-apis.md` (Patterns)
- **4.7 typed overrides inherit the parent's return type and need an explicit `return` on every branch** — source: ADR-0005, `breaking-changes.md`
- **Writing a `PackedByteArray` / packed-array property by index no longer fires its setter (4.7); assign whole values** — source: ADR-0005, ADR-0008
- **Engine knowledge risk is HIGH for networking, physics, rendering and lighting; any API listed under an ADR's Verification Required is unverified until its item runs** — source: ADR-0001–0004, ADR-0007–0009 Engine Compatibility
