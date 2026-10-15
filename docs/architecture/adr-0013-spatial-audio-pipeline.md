# ADR-0013: Spatial Audio Pipeline, Buses and Ducking

## Status
Accepted

Accepted 2026-10-15 by the user ("accept all seven"). Any Verification Required items below are still open: they are follow-up work, not a condition on this status.

## Date
2026-10-12

## Last Verified
2026-10-12

## Decision Makers
Designer (SneakKestrel16), with Claude Code (`/architecture-decision`, autonomous mode, AD-41) and `godot-specialist` engine validation. TD-ADR skipped — Lean mode.

## Summary
Sound is information in Dead Signal (footsteps, lunge cues, callouts), and scares must never mask it, but nothing fixed how clients play positional events, how buses and player volume sliders map, how scare audio ducks under gameplay cues, or how zones and walls shape what is heard. Clients play ADR-0004 positional events from a pooled set of `AudioStreamPlayer3D` nodes routed by a data catalog onto a fixed bus tree; an `AudioDirector` ducks the Scare and Ambience buses by script while any gameplay cue or callout plays; ambience follows the listener's lighting volume; one sight ray per sound picks an occluded sub-bus.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Audio |
| **Knowledge Risk** | MEDIUM: `modules/audio.md` reports no audio breaking changes through 4.6; 4.7 changed the `AudioStreamPlayer3D.area_mask` default to 0 (`breaking-changes.md`) and removed `AudioEffectSpectrumAnalyzer.tap_back_pos` (`breaking-changes.md`). Neither is used here. `modules/audio.md` is a 4.6 snapshot |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/audio.md`, `breaking-changes.md`, `deprecated-apis.md`; official docs `tutorials/audio/audio_buses`; ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0009, ADR-0012 |
| **Post-Cutoff APIs Used** | Typed `Dictionary[K, V]` export (4.4; NOT SOURCEABLE in the reference, already relied on by ADR-0005 Verification 6) |
| **Verification Required** | (1) 24 pooled `AudioStreamPlayer3D` with `max_distance` set and `ATTENUATION_INVERSE_DISTANCE` cost under 0.3 ms per frame with 16 playing; (2) re-routing a playing `AudioStreamPlayer3D` by changing `bus` takes effect without a click; (3) tweening a bus with `AudioServer.set_bus_volume_db` every frame produces no zipper noise at the chosen attack and release; (4) an `AudioEffectLowPassFilter` on a sub-bus keeps 3D panning of players routed to it; (5) after 200 random cue starts, steals and stops the duck counter returns to 0 and both duck buses to 0 dB (amended 2026-10-12 for architecture review 12c, AD-46) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004 (Accepted): sounds are positional events with no handle, sent within the sound's radius; `ScareTriggered` projection. ADR-0005 (Accepted): client event routing (`ClientEventRouter`). ADR-0006 (Accepted): knobs. ADR-0007 (Accepted): `PhysicsLayers.SIGHT`; analytic zones from map data. ADR-0009 (Proposed): lighting volumes as the zone unit. ADR-0012 (Proposed): `SightTest.line_clear` for occlusion |
| **Enables** | Scare Events audio stories; Facility Map ambience; settings volume sliders; proximity voice (TR-pings-007) later routes onto `ProximityVoice` |
| **Blocks** | Any story that plays game audio |
| **Ordering Note** | None |

## Context

### Problem Statement
`scare-events.md` rules 17, 18 and 26 require stingers capped at `stinger_max_db_rel` over the ambient bed, gameplay cues and callouts never masked by scare audio, ducking on `PlayerShocked` / `MonsterStunned`, and separate stinger and scare-master volumes. `research-facility.md` asks for ambience per zone, B3 machinery that masks footsteps, and wall occlusion. The accessibility doc commits to independent volumes for Master, Music, SFX, Voice, Proximity voice, UI, Stinger and Scare master (TR-scare-008, TR-facility-008).

### Constraints
- Sound reaches a client only as a positional event within its radius (ADR-0004 §6); the client cannot know of sounds it was not sent.
- No `Area3D` for zones (ADR-0007); lighting volumes are the zone unit (ADR-0009).
- Masking that changes what a player can learn is gameplay and must be server-side; mixing is presentation.

### Requirements
- Gameplay cues and callouts stay audible under every scare.
- Each player volume slider maps to one bus.
- Audible range on the client matches the server's send radius.

## Decision

**1. Bus tree.** Fixed in `default_bus_layout.tres`:

```
Master
├─ Music
├─ SFX                 (SFX slider)
│   ├─ Ambience        (duck only; no slider writes it)
│   ├─ GameplayCues    (footsteps, lunge cue, distortion, stun, cries, install, barricade, pings)
│   │   └─ GameplayCuesOccluded (low-pass + gain)
│   └─ WorldSFX        (doors, items, machinery)
│       └─ WorldSFXOccluded
├─ Scare               (scare master slider)
│   └─ ScareDuck       (duck only; no slider writes it)
│       ├─ Stinger     (stinger slider)
│       └─ ScareSFX
├─ Voice               (callout voice lines)
├─ ProximityVoice      (reserved; TR-pings-007 deferred)
└─ UI
```

Godot buses are a flat list: "child" here means the bus's `send` targets its parent, and a bus can send only to a bus before it in the list, so a child sits at a higher index than its parent (official docs, `tutorials/audio/audio_buses`) (amended 2026-10-12 for architecture review 12c, AD-46). Sliders: Master, Music, SFX, Voice, ProximityVoice, UI, Stinger, Scare. Ducking writes only `Ambience` and `ScareDuck`, and no slider writes those two, so a slider change and a duck tween never overwrite each other (amended after `godot-specialist` review: the first draft ducked slider buses).

**2. Catalog.** `AudioCatalog` (`res://data/audio_catalog.tres`) maps each sound id to stream(s), bus, `max_distance`, attenuation and a variation list. A positional event's `max_distance` is the gameplay radius knob that the server uses to send it (e.g. sprint footsteps 20 m), so a sound is audible exactly where it is sent. A disguised monster's footsteps use the target's footstep set (ADR-0004 §6, ADR-0010 §2). A footstep's catalog id is `<footstep_set>.<gait>` (e.g. `c3.sprint`), built from the event's set and gait; every set has one entry per gait (amended 2026-10-12 for architecture review 12c, AD-46).

**3. Playback.** The `ClientEventRouter` (ADR-0005 §7) hands positional events to an `AudioDirector` client module, which plays them from a pool of `AudioStreamPlayer3D` (`sfx_pool_size`, built once in `_ready`) placed at the event position. `unit_size` comes from the catalog entry (`ATTENUATION_INVERSE_DISTANCE`), tuned so a sound is still audible just inside `max_distance`. When the pool is full, the quietest-at-listener non-cue voice is stolen; gameplay cues are never stolen by non-cues.

**4. Ducking.** While any sound on `GameplayCues` or `Voice` plays, and for `PlayerShocked` and `MonsterStunned` (rule 18), `AudioDirector` ducks `ScareDuck` and `Ambience` by `duck_db` with `duck_attack_s` / `duck_release_s`, by tweening `AudioServer.set_bus_volume_db` from a duck counter. Only non-looping sounds count; the counter goes up when one starts and down when it finishes, is stolen or is stopped, and the two events add a timed hold of `duck_release_s`. The local player's own footsteps never duck. Ducking is scripted, not a sidechain compressor, so it is driven by the same events tests can assert (amended 2026-10-12 for architecture review 12c, AD-46).

**5. Stingers.** Stingers are non-positional players on `Stinger`, authored loudness-normalised to the ambient bed reference and played at no more than `stinger_max_db_rel` above it; a stinger never starts at the same tick as the scare's origin sound, so it cannot cover it (rule 17).

**6. Zone ambience.** The client finds the listener's lighting volume with the same analytic box test as gameplay zones and crossfades two non-positional ambience players on `Ambience` to that volume's bed (map data). Loud sources such as B3 machinery are positional `WorldSFX` loops.

**7. Footstep masking is server-side.** Each lighting volume has a `footstep_radius_scale` in Facility Map data (1.0 default; B3 below 1, value set in playtest, inference). The server multiplies the footstep send radius by it, so masking changes what is sent, not only what is mixed.

**8. Occlusion.** When a positional sound starts (and every `occlusion_recheck_s` for loops), `AudioDirector` queues a check that runs in its next `_physics_process`: `SightTest.line_clear` (ADR-0012 §1: one `SIGHT` ray plus analytic door and barricade boxes, no range or cone) from the listener to the source, with the source lifted `occlusion_floor_lift_m` (0.3) so floor-level footsteps do not hit the floor. Blocked sounds route to the `*Occluded` sub-bus (low-pass at `occlusion_lowpass_hz`, `occlusion_db`). This only colours sound the client was already sent (amended 2026-10-12 for architecture review 12c, AD-46).

**9. Room names.** Room IDs and display names for callout vocabulary come from Facility Map volume data, not from audio.

### Key Interfaces

```gdscript
class_name AudioCatalog extends Resource
@export var entries: Dictionary[StringName, AudioCatalogEntry]

class_name AudioDirector extends Node   # client presentation module
func play_positional(sound_id: StringName, pos: Vector3, variant: int) -> void
func play_stinger(sound_id: StringName) -> void
func on_event(type: StringName, payload: Dictionary) -> void   # PlayerShocked, MonsterStunned → duck
func set_listener_volume(volume_id: int) -> void               # ambience crossfade
```

### Implementation Guidelines
- Every sound **must** be played through `AudioDirector` from the catalog. The pool is built once in `_ready`; creating `AudioStreamPlayer*` nodes after that **must never** happen.
- Ducking **must** write only the `Ambience` and `ScareDuck` buses; slider code **must never** write those two.
- A positional sound's `max_distance` **must** equal the gameplay radius the server sends it with, except that footsteps keep their unscaled radius when §7 masking shrinks the send radius.
- Scare and ambience audio **must** duck while any gameplay cue or callout plays; gameplay cues **must never** be ducked or stolen by scare or ambience sounds.
- Masking that changes what a player can learn **must** be done on the server's send radius, never only in the mix.
- Bus names and slider mapping **must** come from `default_bus_layout.tres`; code **must** look buses up by name.
- `duck_db`, `duck_attack_s`, `duck_release_s`, `sfx_pool_size`, `occlusion_lowpass_hz`, `occlusion_db`, `occlusion_recheck_s` and `occlusion_floor_lift_m` **must** come from `ScareKnobs`; their Safe Ranges are in `scare-events.md` Tuning Knobs. They ride in the knob digest like every knob (ADR-0006) (amended 2026-10-12 for architecture review 12c, AD-46).
- Occlusion rays **must** run only in `AudioDirector._physics_process`, through `SightTest.line_clear`.
- The duck counter **must** count only non-looping sounds and **must** decrement on finish, steal and stop; the local player's own footsteps **must never** duck.

## Alternatives Considered

### Alternative 1: Sidechain compressor ducking
- **Description**: `AudioEffectCompressor` on Scare with `sidechain` from GameplayCues.
- **Pros**: No script.
- **Cons**: Threshold-driven, so a quiet footstep may not duck; cannot react to `PlayerShocked` with no sound playing; behaviour NOT SOURCEABLE in the reference.
- **Rejection Reason**: Rule 18 is event-driven; scripted ducking is testable.

### Alternative 2: Area3D audio bus overrides per zone
- **Description**: `Area3D` with `audio_bus_override` for ambience and reverb.
- **Pros**: Built-in.
- **Cons**: ADR-0007 bans `Area3D` for zones; 4.7 changed `area_mask` default to 0.
- **Rejection Reason**: Conflicts with ADR-0007.

### Alternative 3: Mix-only footstep masking in B3
- **Description**: Machinery simply plays loud.
- **Pros**: No server rule.
- **Cons**: A player with a low SFX or high footstep focus still hears steps the room should hide.
- **Rejection Reason**: Masking that hides information must be server-side.

## Consequences

### Positive
- Gameplay cues are protected by construction (bus tree + duck rule).
- One sound per event, audible exactly where sent.

### Negative
- New knobs and a per-volume map field.

## Risks
- **Pool exhaustion in a chaotic moment.** Mitigation: steal non-cues first; Verification 1 sizes the pool.
- **Occlusion ray cost.** Mitigation: one ray per sound start, loops rechecked slowly.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| scare-events.md | TR-scare-008, rules 17, 18, 26: stinger cap, ducking priority, separate stinger and scare volumes, positional diegetic scares | §1 buses, §4 ducking, §5 stingers, §3 positional |
| research-facility.md | TR-facility-008: zone ambience, B3 masks footsteps, wall occlusion, room IDs | §6, §7, §8, §9 |
| accessibility-requirements.md | Independent volumes for Master, Music, SFX, Voice, Proximity voice, UI, Stinger, Scare master | §1 slider mapping |
| borrowed-face.md | TR-borrowedface-006 (audio half): directional distortion within 15 m | §2–3 positional `GameplayCues` sound at 15 m |

## Performance Implications
- **CPU**: Pooled 3D players (Verification 1); one ray per sound start.
- **Memory**: Catalog streams.
- **Load Time**: Catalog streams loaded at map load.
- **Network**: None beyond ADR-0004's positional events.

## Migration Plan
No code exists yet.

## Validation Criteria
- With a scare stinger and a lunge cue overlapping, a capture of the mix shows the Scare bus at least `duck_db` lower for the cue's duration.
- A sprint footstep at 19 m is audible, at 21 m is not sent (and so silent).
- Behind a wall or a closed door, a footstep plays through the occluded sub-bus.
- Every slider changes only its bus.

## Related
- ADR-0004 (positional events), ADR-0005 (client routing), ADR-0007 (sight mask, no Area3D zones), ADR-0009 (volumes)
- `design/gdd/scare-events.md` rules 17–18, 26; `design/levels/research-facility.md`; `design/accessibility-requirements.md` Auditory
