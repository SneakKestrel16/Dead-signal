# ADR-0009: Lighting States and Blackout

## Status
Proposed

## Date
2026-10-12

## Last Verified
2026-10-12

## Decision Makers
SneakKestrel16 (designer), with `godot-specialist` engine validation. TD-ADR skipped — Lean mode. Drafted under `automation: autonomous` for this session (decisions logged in the session; acceptance still asks).

## Summary
The Facility Map owns per-volume lighting state (a base phase, overlays, local Blackout and Reset), and Blackout, scares, accessibility and surveillance all depend on it, but nothing fixed how it is held, timed, replicated or drawn. The decision: a compact per-volume state in a Facility Map module with its own tick step, replicated per peer under the ADR-0004 visibility sets like doors, rendered by clients from data-driven presets on grouped dynamic lights; flicker generated on clients from a seeded `ScareTriggered` payload; surveillance as one live `SubViewport` with the viewer's relevance extended by the viewed camera's visibility set.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Rendering, Networking |
| **Knowledge Risk** | HIGH: `Light3D`, Forward+ light and shadow limits and `SubViewport` cost are NOT SOURCEABLE from `docs/engine-reference/godot/`; D3D12 is the Windows default since 4.6; glow runs before tonemapping since 4.6. `modules/rendering.md` is a 4.6 snapshot, so those two facts hold on 4.7.2 only if 4.7 left them alone (the 4.7 migration guide lists no change to either) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/rendering.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; ADR-0002, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008 |
| **Post-Cutoff APIs Used** | None knowingly. `Compositor` / `CompositorEffect` (4.3, in the reference) only if a scare post-effect needs it. Everything about lights and sub-viewports is training data |
| **Verification Required** | A profiling and behaviour spike on the greybox before acceptance, each item NOT SOURCEABLE: (1) `Light3D.visible`, `light_energy` and `light_color` changes take effect on the next rendered frame with no shader recompile hitch on D3D12. (2) Forward+ cost with all 17 volumes' lights present: frame time at 1080p on the target PC with every volume lit, with one volume dark, and with the Evacuation beacons running; the number of shadow-casting lights that fits in the client frame budget sets `max_shadowed_lights`. (3) Glass partitions in B1 and the rack lanes: overdraw cost with lights behind glass. (4) One `SubViewport` sharing the main `World3D` at `feed_resolution` costs within the feed budget while active and nothing measurable with `render_target_update_mode` = `UPDATE_DISABLED`. (5) `RandomNumberGenerator` with the same seed yields the same sequence on two machines (flicker parity). (6) With every light's range clipped to its own volume (Decision 6), no light visibly reaches a neighbouring volume through walls or closed doors; dynamic lights have no occlusion, so shadowless lights would otherwise bleed. (7) Forward+ clustered caps: total `OmniLight3D` and `SpotLight3D` count in the map against the per-cluster and scene limits; shadow atlas size and per-light shadow settings set explicitly in project settings. (8) Shadow cost by type: `max_shadowed_lights` counted separately for omni (cube or dual-paraboloid) and spot shadows. (9) First-use hitch: a light first becoming visible or first casting a shadow compiles no pipeline mid-round after the load-time pre-warm (rule 6) and with the 4.5 Shader Baker on export (`modules/rendering.md`). (10) Feed camera: its own `cull_mask` hides the viewer's body and the monitor; the feed's added light and shadow cost is inside Verification 4's budget. Items 1–4 and 9–10 are measured on D3D12 (the default) and on Vulkan, the fallback, with the backend recorded (`breaking-changes.md`, 4.6) |

**API coverage.** In the repo reference: Forward+ is the default renderer; D3D12 on Windows; `Compositor` for post-processing; glow before tonemapping. Training data only: everything in Verification Required.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Proposed): tick-counted timers. ADR-0004 (Proposed): visibility sets, per-peer relevance, re-send on re-entry, `ScareTriggered` projection. ADR-0005 (Proposed): registry views, event handlers, tick order. ADR-0006 (Proposed): knobs and `Knobs.ticks()`. ADR-0007 (Proposed): analytic lighting volumes (`MapQueries.volume_at`). ADR-0008 (Proposed): backup switch and monitor interactables |
| **Enables** | Spatial audio ADR (Blackout and Evacuation audio follow these states); UI and accessibility ADR (reduced-flash setting consumer) |
| **Blocks** | Facility Map lighting implementation; Monster Abilities Blackout (Vertical Slice); Scare Events client presentation; surveillance monitor |
| **Ordering Note** | Amends ADR-0005 §4 (adds a `FacilityMap` step after `MonsterAbilities`) and ADR-0004 §4 (lighting state follows the door rule; a viewer's relevance grows by the viewed camera's set). Acceptance waits on the Verification Required spike |

## Context

### Problem Statement
`research-facility.md` (Lighting States) defines a precedence of a base phase (Low Power → Power Restored → Evacuation), fixture overlays (Fuse Installed, Terminal Activating, Exit Open), a 6 s local Blackout and a Reset, and says the server owns it and every client shows the same state. Monster Abilities (rules 17–20) needs `blackout_able` and a backup switch; Scare Events (rules 22–25) adds flicker under a flash-rate cap and a flash scale; the C1 monitor shows four live cameras that may show a disguised monster. `architecture.md` lists this as a should-have ADR with HIGH engine risk, and seven registry requirements (TR-index-009, TR-scare-007, TR-scare-012, TR-facility-004, -005, -006, -010) have no ADR.

### Constraints
- Server-authoritative, tick-counted (ADR-0002); one owner per state (ADR-0005).
- No client may learn what its player could not perceive (ADR-0004). A Blackout zone is within 15 m of the monster (`monster-abilities.md` rule 17), so a remote Blackout is a location leak.
- 17 lighting volumes: rooms, four segments each of H-N and H-S, three of A2 (`research-facility.md`).
- Greybox first; the horror look comes in the M4 pass. One developer.

### Requirements
- Every client that can see a volume shows its state within 1 s of the change (`research-facility.md` AC 8, 12).
- Blackout darkens exactly one volume; emergency strips stay faintly on (AC 9).
- At most 3 luminance flashes per second; a flash scale 0–1, with 0 meaning a non-flashing change (`scare-events.md` rules 24–25).
- Reduced-flash variants of beacons and pulses (`research-facility.md`, TR-facility-010).
- Surveillance feed content is server-truth and may show a disguised monster; the single-client hallucination frame appears only on its target's monitor.

## Decision

**1. Owner and state.** A `FacilityMap` server module owns lighting. It holds:
- `base`: one of `LOW_POWER`, `POWER_RESTORED`, `EVACUATION` for the whole facility; it only moves forward, except on Reset;
- per volume: an overlay bitmask (`FUSE_INSTALLED`, `TERMINAL_ACTIVATING`, `EXIT_OPEN`), `blackout_until_tick` (0 = none) and `blackout_able`.

The look of each base state in each volume (Zone B dimmest, route lights to the terminal) is preset data (rule 5), not state.

**2. Transitions** (handlers at flush, ADR-0005 §3):
- `RoundPhaseChanged` to Evacuation: `base = EVACUATION`; the active terminal volume gets `blackout_able = false` and any Blackout in it ends.
- `ObjectiveProgressChanged`: a fuse installed sets `FUSE_INSTALLED` on its fuse box volume; both fuses raise `base` to `POWER_RESTORED` if it is lower; activation started sets `TERMINAL_ACTIVATING`; activation complete sets `EXIT_OPEN`.
- `AbilityUsed` (Blackout, volume): `blackout_until_tick = tick + Knobs.ticks(blackout_duration_s)`. Monster Abilities validates the target first through the lighting view (`blackout_able`, not already dark).
- Backup switch: each room's switch is a Facility Map `Interactable` (ADR-0008) with `backup_switch_hold_s` and its range from Monster Abilities' knobs; `on_complete` ends the Blackout in the switch's volume.
- `RoundEnded`, and round start: Reset (every overlay and Blackout cleared, `base = LOW_POWER`, `blackout_able` restored).

**3. Tick step (amends ADR-0005 §4).** `FacilityMap` runs after `MonsterAbilities` and before `Downing`, followed by a flush. Its `server_tick` only expires Blackouts whose `blackout_until_tick` has passed. A Blackout activated this tick is set by the handler in the flush after Monster Abilities, so Scare Events' later step sees it.

**4. Registry view.** `FacilityMap` registers a `LightingView` under the `lighting` key (a new `systems-index.md` state row; `blackout_able` stays its own row and is served by the same view): `base()`, `overlays(volume)`, `is_dark(volume)`, `blackout_able(volume)`. Readers: Monster Abilities (rule 17), Scare Events (ambush test, RoundScript blocking under Blackout).

**5. Replication (follows ADR-0004 §4's door rule).** Per peer, the server remembers the last lighting record sent for each volume. In the send phase, for each volume in the peer's current visibility set whose record differs, it sends `{volume, base, overlays, dark, dark_until_tick}` in that tick's reliable batch. Volumes outside the set are not sent; on re-entry the current record goes out. Reconnect and spectator switch reset the memory, so every visible volume is re-sent (ADR-0004 §8–9). `base` is public (it follows `RoundPhaseChanged`); the Blackout is the part this rule protects.

**6. Client rendering.**
- Each volume is a `LightVolume` node holding its `Light3D` children in named fixture groups: `overhead`, `emergency_strip`, `route`, `beacon`, `fuse_indicator`, `terminal_alarm`, `exit_light`.
- A `LightingPresets` resource (data, ADR-0006 style) gives, per base state and overlay, per volume class and group: on/off, energy, colour, and an animation (none, rotate, pulse) with a reduced-flash variant (steady colour).
- The client resolves a volume's record by the map's precedence (base, then overlays on their own fixtures, then dark: every group off except `emergency_strip`) and applies it by setting `visible`, `light_energy` and `light_color` directly. Phase changes may fade over `light_fade_s`; Blackout and its end are instant.
- Lights are dynamic. Overheads and beacons are `SpotLight3D`; strips, indicators and alarm lights are `OmniLight3D` with small ranges. Only lights flagged `shadow` cast shadows, and no more than `max_shadowed_omni` and `max_shadowed_spot` (set by the spike, Verification 8) may be in any one visibility set.
- Every light's range (`omni_range`, `spot_range`) is authored to stay inside its own volume, so a volume whose state is stale on this client cannot light a visible one (Verification 6). A build-time check flags a light whose range crosses its volume's box.
- At map load the client pre-warms every fixture group in every preset state, including shadows, for one frame each, so the first Blackout or first beacon does not hitch (Verification 9).
- Glow runs before tonemapping (4.6), so emergency strips and beacons bloom under the `WorldEnvironment` glow settings. Their "faint" look is tuned in presets and the environment, never in code, and verified by a screenshot per lighting state in `production/qa/evidence/`.
- Survivor flashlights are body presentation (ADR-0004 §2), not lighting state, and stay on in a Blackout.

**7. Flicker.** Scare Events adds no lighting state. A flicker scare's projected `ScareTriggered` payload (ADR-0004 §5) carries `{volume, start_tick, duration_ticks, seed, intensity}`. Each recipient computes the light level as a pure function of `(seed, elapsed_ticks)`, where `elapsed_ticks` is the client's estimated server tick (ADR-0002 §7) minus `start_tick`: the pattern is precomputed once into per-tick steps with a `RandomNumberGenerator` seeded from `seed`, so a late packet joins the same pattern and the frame rate never changes the RNG call order. It is evaluated in `_process` (energy is a property, not a transform, so physics interpolation does not smooth it), scaled by the player's flash scale, and clamped to `max_flashes_per_s` = 3; at flash scale 0 it becomes one steady dim change for the same duration. The cap here is per flicker; whether the 3-per-second rule must cap the sum of every luminance change in view (flicker, beacons, glow) is left to the UI and accessibility ADR. Flicker never touches `emergency_strip`, and Scare Events does not send one for a volume under Blackout (`scare-events.md` edge cases). Phase moods (Low, Rising, Emergency) come from the same `RoundPhaseChanged` both systems receive; Scare Events requests nothing from the map.

**8. Surveillance (amends ADR-0004 §4).**
- The C1 monitor is a Facility Map `Interactable` with `duration_s` 0. Each press cycles camera 1 → 4 → off; leaving the monitor's range, starting another hold or being shocked or downed turns it off **(proposed; the GDD fixes only "one at a time")**.
- While a peer views camera N, its relevance set is its own visibility set plus camera N's authored visibility set. Bodies and lighting on the feed are therefore real, and nothing beyond what the camera sees is sent.
- The client renders the feed with one `SubViewport` sharing the main `World3D` (`own_world_3d` off; code uses `get_world_3d()`, `deprecated-apis.md`) and a `Camera3D` at camera N's authored transform with its own `cull_mask` (hiding the viewer's body and the monitor model), at `feed_resolution`, `UPDATE_ALWAYS` while viewing and `UPDATE_DISABLED` otherwise.
- Lighting records for the camera's extra volumes are applied to those volumes' lights like any other record, even though the main camera does not draw them, so the feed shows their true state.
- The impossible surveillance frame is a single-client `ScareTriggered` to the viewer; that client overlays its authored image on the feed for the scare's duration.
- Viewing is a location trigger for any player, shapeshifter included (`scare-events.md` rule 2a).

### Architecture Diagram

```
SERVER                                                     CLIENT (per peer P)
events ─flush─▶ FacilityMap handlers                        reliable batch
  RoundPhaseChanged / ObjectiveProgressChanged / AbilityUsed   {volume, base, overlays, dark, until}
  backup switch on_complete (HoldService, ADR-0008)            │
FacilityMap.server_tick: expire Blackouts (after MonsterAbilities) ▼
LightingView ◀── MonsterAbilities (blackout_able), ScareEvents  LightVolume[v]: groups ← LightingPresets
send phase: for v in visible_set(P) [+ camera set if viewing]   precedence: base → overlays → dark
            if record(v) != last_sent[P][v]: send               flicker: seeded RNG, ≤ 3/s, × flash scale
ScareTriggered projection: flicker params / hallucination frame  monitor: SubViewport (live only while viewing)
```

### Key Interfaces

```gdscript
class_name LightingView extends RefCounted     # registry key &"lighting"
func base() -> int                             # FacilityMap.Base
func overlays(volume: int) -> int              # bitmask
func is_dark(volume: int) -> bool
func blackout_able(volume: int) -> bool

class_name FacilityMap extends RefCounted      # server module, ADR-0005 shape
enum Base { LOW_POWER, POWER_RESTORED, EVACUATION }
const OVERLAY_FUSE_INSTALLED := 1
const OVERLAY_TERMINAL_ACTIVATING := 2
const OVERLAY_EXIT_OPEN := 4
func setup(tick_runner: TickRunner, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void
func server_tick(tick: int) -> void            # Blackout expiry only
func lighting_record(volume: int) -> PackedByteArray   # what the send phase compares and sends
func viewed_camera(peer: int) -> int           # -1 when not viewing; read by Relevance

# Client
class_name LightVolume extends Node3D
@export var volume_id: int
func apply(record: Dictionary, presets: LightingPresets, reduced_flash: bool) -> void
func flicker(start_tick: int, duration_ticks: int, seed: int, intensity: float, flash_scale: float) -> void
```

### Implementation Guidelines
- Lighting state **must** be written only by `FacilityMap`. Other systems **must** read it through `LightingView`.
- Monster Abilities **must** validate a Blackout target through `LightingView` before emitting `AbilityUsed`.
- Lighting records **must** be sent only for volumes in the peer's visibility set (plus a viewed camera's set), and re-sent on re-entry, reconnect and spectator switch. Broadcasting lighting state to every peer is forbidden.
- Clients **must** render lighting only from received records and presets. They **must never** change lighting state locally, except flicker on top of it.
- `emergency_strip` lights **must** stay on in every state, Blackout included.
- Flicker **must** be generated from the payload seed and clamped to `max_flashes_per_s` and the player's flash scale. Flicker on/off **must never** be sent as individual messages.
- The surveillance `SubViewport` **must** be `UPDATE_DISABLED` whenever its client is not viewing.
- Every light's range **must** stay inside its own volume. Lights **must** be pre-warmed at load.
- Flicker **must** be a pure function of seed and elapsed server ticks.
- `blackout_duration_s`, `backup_switch_hold_s`, `light_fade_s`, `max_flashes_per_s`, `max_shadowed_omni`, `max_shadowed_spot` and `feed_resolution` **must** come from data. Light looks **must** come from `LightingPresets`, never from code.

## Alternatives Considered

### Alternative 1: Broadcast lighting state to every client
- **Description**: Every client receives every volume's state.
- **Pros**: Simplest; matches the "all 5 clients" AC literally.
- **Cons**: A modified client learns where every Blackout is, so roughly where the monster is.
- **Rejection Reason**: Designer decision 2026-10-12: PVS-scoped, same rule as doors.

### Alternative 2: Server replicates per-light values
- **Description**: The server sends energy and colour per light.
- **Pros**: Clients need no presets.
- **Cons**: The server owns rendering detail; far more data; looks change need server changes.
- **Rejection Reason**: State is small and semantic; looks belong to client data.

### Alternative 3: Baked lightmaps per state
- **Description**: `LightmapGI` bakes swapped per state, dynamic lights for overlays.
- **Pros**: Better look at low runtime cost.
- **Cons**: A per-volume Blackout needs a bake per combination; long bakes during greybox iteration.
- **Rejection Reason**: Designer decision 2026-10-12: dynamic lights with presets. Revisit in the M4 horror pass if the spike shows the budget is tight.

### Alternative 4: Server sends each flicker step
- **Description**: The server sends every on/off of a flicker.
- **Pros**: Exact parity.
- **Cons**: Chatty; network jitter shows as uneven flicker.
- **Rejection Reason**: Designer decision 2026-10-12: seeded client generation.

### Alternative 5: Server-chosen stills on the monitor
- **Description**: No live feed; authored frames only.
- **Pros**: No render cost; no relevance change.
- **Cons**: A disguised monster cannot appear on a feed as the map intends.
- **Rejection Reason**: Designer decision 2026-10-12: live feed with relevance extended by the camera's set.

## Consequences

### Positive
- One owner, one view and one replication rule for all lighting, matching doors.
- A modified client learns of a Blackout only where its player could see it.
- Light looks are data; the M4 horror pass changes presets, not code.
- Engine validation (`godot-specialist`, 2026-10-12): no blocking findings; 12 minor findings folded into Decisions 6–8, Verification 6–10 and Risks.
- Flicker costs one message per scare and looks identical on every recipient.

### Negative
- Per-peer "last sent" memory per volume (17 × peers) and a comparison each send phase.
- Viewing a camera widens that peer's relevance: the feed sends more bodies while it is on.
- Dynamic lights for 17 volumes: performance is unknown until the spike.
- A volume outside the visibility set keeps its last state on the client; if its light can bleed into a visible volume, the bleed is stale (Verification 6).

## Risks
- **Light count and shadows exceed the budget.** Mitigation: the spike sets `max_shadowed_lights`; most fixtures shadowless; baked base light (Alternative 3) as the fallback.
- **Light bleed from non-visible volumes.** Dynamic lights have no occlusion, so walls and closed doors do not stop a shadowless light. Mitigation: light ranges clipped to their volume with a build-time check (Decision 6); Verification 6.
- **Flicker drift between clients.** Mitigation: Verification 5; the pattern derives only from seed, start tick and duration.
- **Feed cost.** Mitigation: one `SubViewport`, low `feed_resolution`, disabled when not viewing; the feed redraws every light and shadow it sees (Verification 10).
- **Forward+ light caps.** Many small fixtures across 17 volumes could reach the cluster or scene limit. Mitigation: Verification 7; merge strip lights into fewer, emissive geometry for strips if needed.
- **Pipeline hitches on first light use.** Mitigation: load-time pre-warm; Shader Baker on export (Verification 9).
- **Glow changes the look of bright small fixtures (4.6).** Mitigation: tune in presets and `WorldEnvironment`; screenshot evidence per state.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| research-facility.md | Lighting States table and precedence; server owns lighting per volume; Reset on `RoundEnded` and round start (TR-facility-004) | Decisions 1–3 |
| research-facility.md | AC 8, 12: clients enter the new state within 1 s; precedence after Blackout | Decision 5: reliable batch in the same tick; Decision 6 precedence |
| research-facility.md | AC 9: Blackout darkens exactly one volume; emergency strips stay visible | Decisions 2, 6 |
| research-facility.md | Reduced-flash variants (TR-facility-010) | Decision 6: preset variants |
| research-facility.md | 17 switchable volumes, glass overdraw: profile (TR-facility-005) | Verification 2–3; `max_shadowed_lights` |
| research-facility.md | Surveillance: 4 cameras one at a time, server-owned content, hallucination frame (TR-facility-006) | Decision 8 |
| systems-index.md | `blackout_able` per volume, flips for the active terminal room at Evacuation (TR-index-009) | Decisions 1, 2, 4 |
| monster-abilities.md | Rules 17–20: target validation, 6 s effect, backup switch, one zone per Blackout | Decisions 2, 4 |
| scare-events.md | Rule 22: map owns lighting; Scare Events adds flicker only (TR-scare-007) | Decision 7 |
| scare-events.md | Rules 24–25: flash scale and ≤ 3 flashes/s; stingers, flash, monitor frame (TR-scare-012) | Decisions 7, 8 |
| survivor-defense.md | Flashlights keep working in Blackout | Decision 6: flashlights are body presentation |

## Performance Implications
- **CPU**: Server: one comparison per visible volume per peer per tick (at most 17 × 6). Client: preset application only on change; flicker evaluation for active flickers only.
- **GPU**: Unknown until the spike (Verification 2–4). Budget targets: lighting state changes cause no frame spike; the active feed stays within a budget the spike sets.
- **Memory**: Presets resource; one `SubViewport` texture at `feed_resolution`.
- **Load Time**: Lights load with the map.
- **Network**: About 6 bytes per changed visible volume, on change only; one flicker message per scare.

## Migration Plan
No production code exists. Amends ADR-0005 §4 (tick step) and ADR-0004 §4 (lighting follows the door rule; camera relevance). Adds a `lighting` row to the `systems-index.md` state table.

## Validation Criteria
- Facility Map ACs 8, 9 and 12 pass with 5 clients.
- A survivor client whose visibility set excludes a blacked-out volume receives no lighting record for it during the Blackout (packet capture), and receives the current state on entering view of it.
- Flicker on two clients with the same payload produces identical on/off timings; no client exceeds 3 flashes per second; flash scale 0 produces no flash.
- While viewing a camera, bodies in its set appear on the feed; after leaving, the peer's relevance returns to its own set within one tick.
- Every Verification Required item passes on the greybox.

## Related
- ADR-0004 — visibility sets and projection (depends on; amended)
- ADR-0005 — registry, events, tick order (depends on; amended)
- ADR-0007 — analytic volumes (depends on)
- ADR-0008 — switch and monitor interactables (depends on)
- `design/levels/research-facility.md`, `design/gdd/scare-events.md`, `design/gdd/monster-abilities.md`, `design/gdd/survivor-defense.md`, `design/gdd/systems-index.md`
