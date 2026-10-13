# ADR-0010: Borrowed Face Rendering and Appearance Swap

## Status
Proposed

## Date
2026-10-12

## Last Verified
2026-10-12

## Decision Makers
Designer (SneakKestrel16), with Claude Code (`/architecture-decision`, autonomous mode, AD-38) and `godot-specialist` engine validation. TD-ADR skipped — Lean mode.

## Summary
A disguise must look and move exactly like the copied survivor on every client, and a form change must not leak through the scene tree. Every body on a client is one locally built puppet whose visible appearance is a data-driven child scene (survivors C1–C5 share one humanoid rig and animation set; the true form is its own scene), preloaded at map load and swapped in place on a form change, so a disguised shapeshifter's puppet is structurally identical to a real survivor's.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Animation, Rendering |
| **Knowledge Risk** | MEDIUM: `AnimationMixer` base class (4.3, in reference); `LookAtModifier3D.relative` default changed `true` → `false` in 4.6 (`breaking-changes.md`); IK and `SkeletonModifier3D` restored in 4.6; D3D12 default on Windows (4.6). `modules/animation.md` and `modules/rendering.md` are 4.6 snapshots |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/animation.md`, `modules/rendering.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; ADR-0002, ADR-0004, ADR-0006, ADR-0007, ADR-0009 |
| **Post-Cutoff APIs Used** | `LookAtModifier3D` with `relative` set explicitly (default changed in 4.6); `SkeletonModifier3D` family (4.6) only if head look needs more than one modifier |
| **Verification Required** | A headless or windowed script per item on the greybox, before acceptance. Each is NOT SOURCEABLE from `docs/engine-reference/godot/`: (1) replacing the appearance child of a puppet (remove old instance, add a preloaded `PackedScene.instantiate()`) during movement causes no frame over 16.6 ms on the target PC; (2) `GeometryInstance3D.material_overlay` with a `ShaderMaterial` renders over skinned meshes on D3D12 and can be faded by a shader parameter; (3) `LookAtModifier3D.relative` defaults to `false` on 4.7.2 and the head look works with it set explicitly; (4) six `AnimationTree` instances blending walk/sprint/crouch cost under 0.5 ms CPU per frame together; (5) the client scene tree of a disguised shapeshifter's puppet and a real survivor's puppet of the same character dump identically (node names, types, child order, resource paths); (6) on a survivor-to-survivor swap, `start(state, false)` on the new tree's state-machine playback plus a seek to the same normalised clip time keeps the stride with no visible pop; (7) `cast_shadow = SHADOW_CASTING_SETTING_SHADOWS_ONLY` on the owner's body meshes hides them from its camera while keeping its shadow and leaves its flashlight unaffected |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Proposed): snapshots, interpolation, gait. ADR-0004 (Proposed): per-peer handles, appearance in introduce and snapshot, form change in view keeps the handle, positional footstep events. ADR-0006 (Proposed): knobs for warp timing. ADR-0007 (Proposed): one capsule for every form. ADR-0009 (Proposed): flashlight counts against light and shadow caps |
| **Enables** | Borrowed Face presentation stories; character art production (C1–C5 and true form share the rig contract below) |
| **Blocks** | Borrowed Face epic presentation stories; any story that builds a client body puppet |
| **Ordering Note** | Acceptance waits on Verification Required items 1–5 and on the Foundation ADRs it depends on |

## Context

### Problem Statement
Borrowed Face is the core deception: other players see a second copy of their friend walking the facility (`borrowed-face.md` rule 6, Edge Cases "Two copies of survivor X"). ADR-0004 keeps identity out of the network payload, but nothing yet fixed how a client draws a body, what an "appearance" is, or how a form change is shown. If the disguise uses a different node structure, animation set, material or load timing than the real survivor, a modified client can tell which body is the monster (TR-borrowedface-002, TR-borrowedface-011), and a visible pop or hitch on transform completion is a tell to everyone.

### Constraints
- The disguise copies body, outfit, head, colour identity, walk/sprint/crouch animations, footstep set and a cosmetic flashlight; it never copies carried items, held item, Downed or injured presentation, or voice (`borrowed-face.md` "What the disguise copies").
- The true form is a separate model with the same collision capsule (TR-borrowedface-011; ADR-0007 one capsule set per player).
- A form change in view keeps the body's handle; during linger it retires it (ADR-0004 §3).
- Client puppets are named by a client-local counter and carry no RPCs (ADR-0004 §7a).
- Art for C1–C5 must stay distinguishable by silhouette (`design/accessibility-requirements.md` Visual, C1–C5 constraint); no art bible exists yet.

### Requirements
- A disguised body and the real survivor it copies render identically in every frame a viewer can compare them, including animation timing.
- A form change shows a 2 s subtle warp over the current appearance, then the new appearance with no hitch (`borrowed-face.md` rule 8, Transforming state).
- Appearance is data per character so adding or retuning a survivor changes data, not code (TR-borrowedface-005).

## Decision

**1. One puppet per body.** Each body a client knows (by ADR-0004 handle) is one `BodyPuppet` scene: a `Node3D` root named by a client-local counter, with an `AppearanceSlot` child that holds exactly one appearance instance. The puppet lives from the handle's introduce to its retire. A form change never frees or recreates the puppet; it replaces the child of `AppearanceSlot`.

**2. Appearances are data.** An `Appearance` Resource per form: `id` (0 = true form, 1–5 = C1–C5), `scene: PackedScene`, `footstep_set: StringName`, `flashlight_bone: StringName` (empty for the true form), `first_person_scene: PackedScene` for the local view model. `AppearanceSet` is one Resource listing all six, loaded from `res://data/appearances.tres`. The snapshot and introduce message carry the `id` only (ADR-0004 §2 "appearance"); the client maps id to `Appearance`. Map data, not knobs (ADR-0006 §8).

**3. One survivor rig.** C1–C5 share one humanoid `Skeleton3D` bone set and one `AnimationLibrary` (walk, sprint, crouch, crawl, idle, interact, Seized, Downed). Each survivor scene differs only in meshes, materials and the flashlight attachment. A disguise therefore plays the same clips with the same blend as the real survivor by construction. The true form has its own skeleton and library.

**4. Animation from replicated state only.** Each appearance root has an `AnimationTree` whose parameters are set from the snapshot entry: gait, planar speed from interpolated positions, and the presentation flags (Seized, Downed, stagger). The server never sends Downed or Seized for a disguised shapeshifter, so a copy always stands healthy without any client-side rule. Head pitch comes from a `LookAtModifier3D` (a `Skeleton3D` child with `bone_name` and a `Marker3D` target fed the replicated pitch) with `relative` set explicitly (default changed in 4.6). Trees are enabled with `AnimationTree.active`, never the deprecated `playback_active`. No animation state is derived from role.

**5. Preload, swap on completion.** At map load the client loads all six `Appearance.scene` resources and renders each once in front of a camera behind the loading screen (same pass as ADR-0009 §6), because instancing alone compiles no pipelines. On a `FormChanged` appearance update for a handle, in one frame the puppet calls `remove_child` and `queue_free` on its current appearance instance and adds a fresh instance of the new one. The playback object cannot be copied, so the hand-off is explicit (amended after `godot-specialist` review, 2026-10-12): for a survivor-to-survivor swap (same rig and library, the common case) the new tree's playback is started in the same state with `start(state, false)` and seeked to the same normalised clip time; to or from the true form (different rigs) the new tree starts in the gait's state at time 0, under the warp. Every client does the same, whatever the body's role. Both mechanisms are NOT SOURCEABLE; Verification Required item 6 settles the first.

**6. Transform warp.** While the snapshot's Transforming flag is set, the puppet sets one `ShaderMaterial` as `material_overlay` on every `GeometryInstance3D` of the current appearance and drives its `warp` parameter from 0 to 1 over the transform duration (the displacement runs on the skinned `VERTEX` in the vertex function, or in the fragment function only) (from the knob, ADR-0006), then removes it on completion or cancel. With reduced motion on, the warp is a static tint instead of a moving distortion. The audio distortion and the H14 edge cue are positional events (ADR-0004 §6), not part of the puppet.

**7. Things a disguise never shows.** Carried and held items attach only from the snapshot's visible-items field, which the server leaves empty for a disguise (ADR-0004 §2). There are no body name labels (`lobby-role-assignment.md` rule 11). Voice is not rendered by the puppet.

**8. Flashlight.** Each survivor appearance has a `SpotLight3D` under a `BoneAttachment3D` on `flashlight_bone`, toggled by the snapshot's flashlight flag. Body flashlights are shadowless and count toward the ADR-0009 per-view light budget, so the caps are set with up to five flashlights in view.

**9. The local player.** The owning client sets `cast_shadow = SHADOW_CASTING_SETTING_SHADOWS_ONLY` on its own appearance's meshes, so its body is not drawn by its camera but still casts a shadow, and shows the appearance's `first_person_scene`. Render layers and `cull_mask` are not used for this: a layer hidden from the camera would still need its shadow and the flashlight's own `light_cull_mask` handled separately (`godot-specialist`, 2026-10-12; NOT SOURCEABLE, Verification item 7). The shapeshifter's own first-person model follows its form.

### Architecture Diagram

```
snapshot / introduce (ADR-0004): handle, appearance id, pos, yaw, gait, flags
        │
        ▼
ClientBodies ── handle → BodyPuppet "B17" (client counter)
                          └─ AppearanceSlot
                               └─ <appearance instance>  ← AppearanceSet[id].scene (preloaded)
                                    ├─ Skeleton3D (survivor rig | true-form rig)
                                    │    ├─ MeshInstance3D… (material_overlay = warp while Transforming)
                                    │    ├─ LookAtModifier3D (relative set explicitly)
                                    │    └─ BoneAttachment3D → SpotLight3D (survivors only)
                                    └─ AnimationTree ← gait, speed, flags
FormChanged appearance update → swap child of AppearanceSlot; puppet node unchanged
```

### Key Interfaces

```gdscript
class_name Appearance extends Resource
@export var id: int                       # 0 true form, 1–5 = C1–C5
@export var scene: PackedScene
@export var first_person_scene: PackedScene
@export var footstep_set: StringName
@export var flashlight_bone: StringName   # &"" for the true form

class_name AppearanceSet extends Resource
@export var appearances: Array[Appearance]
func get_by_id(id: int) -> Appearance

class_name BodyPuppet extends Node3D
func apply_snapshot(entry: Dictionary) -> void   # pos, yaw, gait, flags, items
func set_appearance(id: int) -> void             # swap child; keeps puppet and handle
func set_transforming(active: bool, progress: float) -> void
```

### Implementation Guidelines
- A form change **must** swap only the child of `AppearanceSlot`. The `BodyPuppet` node **must never** be freed, renamed or re-parented on a form change.
- Survivor appearances **must** share one skeleton bone set and one `AnimationLibrary`; they **must** differ only in meshes, materials and the flashlight attachment.
- Puppet animation and presentation **must** come only from snapshot fields. Client code **must never** branch on role, player ID or "is monster".
- Every appearance scene **must** be loaded and pre-warmed at map load. Instantiating from disk mid-round **must never** happen.
- `LookAtModifier3D.relative` **must** be set explicitly in every appearance scene.
- Appearance definitions **must** come from `res://data/appearances.tres`, never from code.
- Body flashlights **must** be shadowless.
- Survivor appearances **must** reference the one shared `AnimationLibrary` `.tres`, never a per-scene copy.
- A swap **must** `remove_child` and `queue_free` the outgoing appearance in the same frame the new one is added.
- Trees **must** be enabled with `AnimationTree.active`.

## Alternatives Considered

### Alternative 1: All six models in every puppet, toggling visibility
- **Description**: Each puppet carries every appearance; a form change flips `visible`.
- **Pros**: Zero instantiation at swap time.
- **Cons**: Six skeletons and trees per body; hidden nodes still process unless disabled; memory × 6 per puppet.
- **Rejection Reason**: Cost for no gain once preload removes the swap hitch.

### Alternative 2: Despawn and respawn a new puppet on form change
- **Description**: Retire the old body and introduce a new one in the new appearance.
- **Pros**: Simplest client code.
- **Cons**: Contradicts ADR-0004 §3 (a form change in view keeps the handle); visible pop; the new-handle event itself marks the body as the monster.
- **Rejection Reason**: Leaks identity.

### Alternative 3: One mesh with shader-driven morph between characters
- **Description**: Blend shapes or a shader morph from one appearance to another.
- **Pros**: Smooth visual transformation.
- **Cons**: Constrains every character to one topology; large art cost; the GDD asks only for a subtle warp, then the new form.
- **Rejection Reason**: Art and topology cost beyond the GDD.

### Alternative 4: Per-player tint on a shared survivor model
- **Description**: One survivor model, colour identity by per-instance shader parameter.
- **Pros**: Fewer assets.
- **Cons**: Weak silhouette distinction (accessibility C1–C5 constraint); a tint parameter keyed to a player is a payload that could leak.
- **Rejection Reason**: Fails the silhouette constraint.

## Consequences

### Positive
- A disguise is identical to the real survivor by construction: same rig, clips, materials, scene structure.
- Form changes reuse the same puppet and handle, matching ADR-0004.
- New characters are data plus art; no code change.

### Negative
- C1–C5 are bound to one rig and animation set; a character with different proportions needs retargeting work.
- Six appearance scenes stay in memory all round.

## Risks
- **Swap hitch on first instantiate.** Mitigation: pre-warm at load; Verification 1.
- **Animation phase pop on swap.** Mitigation: explicit `start(state, false)` + seek for same-rig swaps (§5, Verification 6); if that still pops, keep the outgoing instance a few frames and cross-fade.
- **`material_overlay` on skinned meshes behaves differently on D3D12.** Mitigation: Verification 2; fallback is swapping to warp-variant materials.
- **Art produced before this contract.** Mitigation: the rig contract goes into the art bible's asset standards.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| borrowed-face.md | TR-borrowedface-005: disguise copies body, outfit, colour, animations, footsteps, speeds, flashlight; not items, Downed presentation, voice; appearance data-driven per character | §2 data, §3 shared rig, §4 flags from server, §7 never-shown list, §8 flashlight |
| borrowed-face.md | TR-borrowedface-011: true form is a separate model with the same capsule; the swap must not leak through node or scene changes | §1 puppet kept, §3 separate true-form scene, §5 identical swap for every body, Verification 5 |
| borrowed-face.md | TR-borrowedface-002: no marker identifying the monster in anything a survivor client holds | §4 no role branching; Verification 5 tree dump |
| borrowed-face.md | TR-borrowedface-006 (visual half): subtle warp during the 2 s transform | §6 overlay warp; audio and edge cue remain ADR-0004 §6 |

## Performance Implications
- **CPU**: Up to 6 `AnimationTree` instances (Verification 4 target under 0.5 ms together); swap cost one instantiate per form change.
- **Memory**: Six appearance scenes resident (sizes set by the art budget).
- **Load Time**: One pre-warm pass per appearance at map load.
- **Network**: None added; the appearance id is already in ADR-0004's introduce and snapshot.

## Migration Plan
No code exists yet; the networking spike's capsule puppets are throwaway.

## Validation Criteria
- Verification Required items 1–5 pass on the greybox.
- With the monster disguised as C2 next to the real C2, a side-by-side screenshot set at 1080p shows no visible difference over 10 s of walking, sprinting and crouching (retained in `production/qa/evidence/`).
- A tree dump of both puppets on a survivor client is identical.
- A form change in view shows the warp for the transform duration and swaps with no frame over 16.6 ms.

## Related
- ADR-0004 (identity hiding, handles, appearance field), ADR-0002 (snapshots), ADR-0007 (capsule), ADR-0009 (light budget), ADR-0006 (knobs)
- `design/gdd/borrowed-face.md`, `design/accessibility-requirements.md` (C1–C5 silhouettes, reduced motion)
