# Art Bible: Dead Signal

> **Status**: Draft (sections 1-6 and 8 authored; 7 and 9 out of scope)
> **Owned By**: art-director
> **Last Updated**: 2026-10-15
> **Art Director Sign-Off (AD-ART-BIBLE)**: SKIPPED 2026-10-15 — solo mode

`/art-bible` writes these nine sections in this order and replaces each
section's `[To be designed]` line as that section is approved. A section still
holding its placeholder is incomplete; a later run fills only those.

Anchor: no pillars exist. Principles come from the pitch ("the shapeshifter walks among them wearing their friends' faces", `design/game-brief.md`) and the feeling it targets: the dread of not trusting the person next to you. Numbers marked "(inference — playtest/profiling settles it)" are judgement calls.

## 1. Visual Identity Statement

- **One-line rule: "A face you trust, in a light you can't."** When ambiguous, make the person readable and the place unreadable: identity is crisp and shared, space is dim and doubtful.
- **P1 — Identity is data, not decoration.** Everything that tells survivors apart lives in one copyable character look (colour, accessory, stripe pattern). Design test: "can the disguise copy this by copying one resource id?" If no, cut it. Serves: the disguise copies appearance.
- **P2 — The body never confesses.** Nothing on a body marks the shapeshifter while disguised (no shader, outline, tint, particle, rim, shadow quirk). Design test: "would a screenshot of the copy and the original differ in any pixel of the body?" If yes, cut it. Serves: LB-6 (no role indicators), `production/epics/lobby-role-assignment/story-006-no-role-indicators.md`.
- **P3 — Light is the only tutor.** The flashlight cone and a few authored emissives show what matters; everything else may fall into shadow but never into black. Design test: "does it read in a 14 m flashlight cone and in ambient near-dark?" If not, raise value or add an emissive cue. Serves: readable objectives, fair fear.
- **P4 — Colour never works alone.** Every semantic colour has a shape or light-pattern backup (Section 4).

## 2. Mood & Atmosphere

Each state is distinct by colour temperature, contrast and motion, not just brightness. Server owns lighting state (`design/levels/research-facility.md`, Lighting States); this section sets the look.

| State | Emotional target | Lighting character | Descriptors | Energy |
|-------|------------------|--------------------|-------------|--------|
| Low Power (round start, default) | Held breath, suspicion | Zone base light at ~25% of full; pools of dark between benches; emergency floor strips always on; cold neutral ambient | stale, humming, institutional, watched | Low |
| Fuse Installed (1/2) | Fragile progress | Indicator + one Core pulse; rest unchanged | tentative, hopeful, loud | Low-med |
| Power Restored (2/2) | Brief relief, exposure | Overheads up in B and C; route lights B1 to terminal; still no flat-bright: keep falloff and shadow | exposed, clinical, too visible | Med |
| Blackout (local, 6 s) | Panic in one room | One volume dark; emergency strips + flashlights only; no ambient fill | claustrophobic, blind, breathing | High |
| Evacuation | Race and holdout | Overheads ~50%; rotating amber beacons toward C4; exit sign bright | alarmed, urgent, stripey | High |
| Terminal Activating | Peak dread | C4 red rotating beacon, alarm lights in terminal room | pulsing, cornered, loud | Peak |
| Exit Open | Release | Green light floods C4 from E; everything else holds | cold relief, last sprint | Med-high |
| Transformation reveal | Shock | Per Scare Events; no scene-wide relight, the monster is lit by whatever light was there | sudden, wet, close | Spike |
| Downed/bleed-out (local player) | Helplessness | Per-player screen treatment only, never on the world | dim, tunnel, slow | Med |

- Rule: lighting never fully darkens the route to the active terminal during Evacuation (level doc).
- Reduced-flash mode turns pulses and rotation into steady colour changes (`design/accessibility-requirements.md`).
- Zone mood: A close suspicion (many dim cool panels), B noisy exposure (amber equipment glow, The Core brightest point on the map), C fragile foothold (red security tones, monitor glow).
- Lobby/Results: out of scope here (UI, Section 7).

## 3. Shape Language

- **Survivors: soft, upright, rectangular-rounded.** Torso:legs:head approx 3:4:1 mass, chunky padded jumpsuit, one accessory mass per survivor (Section 5). Reads at 30 px tall.
- **Shapeshifter true form: spiked, asymmetric, over-long.** The inverse of survivors: thin trunk, long limbs, no accessory, silhouette taller than any survivor. Never used on a disguise.
- **Environment: hard orthogonal institutional geometry.** 90-degree rooms, repeated bays, flat panels, thin mullions. Curves only on organic wrongness (specimens, cabling) and decon arch. Horror comes from repetition and long straight sightlines, not from tilted walls.
- **Hero vs supporting shapes.** Hero (objectives, exits, landmarks): large, simple, unique silhouette, brightest value, only emissive in the scene. Supporting (furniture, clutter): lower value, broken outline, no emissive, no unique silhouette that could be mistaken for hero.
- **Objective silhouettes (shape backups).** Data drive: flat slab with a lit edge bar. Fuse: cylinder with two rings. Fuse box: tall panel with a vertical indicator bar. Terminal: wide screen with a top hood. Exit: chevron-framed door. Each is the only object of that silhouette in the facility.
- **Landmarks** (level doc): The Core (double-height light column), A7 gallery window, B2 breaker wall, C1 monitor wall, C4 beacon and exit sign, A1 decon arch, corridor stripes.
- **Glass partitions**: thin frames, slight blue-green tint, never opaque at flashlight angle; see-through reads are gameplay (visibility sets).
- UI shape grammar: Section 7 (not authored).

## 4. Color System

### Primary palette (7)

| Role | Name | Hex | Use |
|------|------|-----|-----|
| Shadow base | Void Charcoal | `#14181A` | Darkest allowed light/ambient tint and shadow colour; never a surface albedo |
| Zone A / lab | Lab Green-White | `#A9C4B8` | Cool lab panels, ~6500K with green cast |
| Zone B / equipment | Server Amber | `#D98A2B` | Equipment glow, ~2700K; Evacuation beacons; H-S stripe |
| Zone C / alarm | Security Red | `#B3342E` | Zone C ambience (low energy); alarm beacons (rotating only) |
| Objective / info | Signal Cyan | `#3FA9D6` | Objective items, fuse-box indicators, pings, H-N stripe (darker value) |
| Exit / success | Exit Green | `#4FD18B` | Exit door light, completed objective only |
| Light source | Bone Flashlight | `#F2E6C8` | Flashlight, ~4500K; the player's own "truth" colour |

### Rules

- **Semantic colour and its backup (colour-blind safety):**
  - Objective (cyan): vertical lit bar + slow 1 Hz pulse; item silhouettes per Section 3. Backup: shape + pulse.
  - Exit/success (green): steady light + chevron arrow shape. Never pulses. Backup: steady vs pulsing, arrow.
  - Danger/alarm (red): only as rotating or strobing beacon (triangle lens cap); never a static interactable. Backup: motion + shape. Red (dark, low luminance) and green (bright) also differ in value, so they separate in monochrome.
  - Pings: colour + glyph by type (Pings & Callouts owns the set); pings never rely on hue alone.
  - Corridor stripes: blue (H-N) = solid line; orange (H-S) = dashed line, so they differ without hue.
- **Zone temperature:** A cool (~6500K, green), B warm (~2700K), C red-shifted and desaturated, corridors take the stripe accent over neutral grey. Temperature change at thresholds helps wayfinding in darkness.
- **Survivor identity colours** are a separate set (Section 5) exempt from zone tinting: zone light multiplies them, so the hue-separation must survive amber and red light (inference — playtest settles it).
- **Saturation:** world is desaturated (max ~35% except emitters); emitters and objectives are the only saturated pixels.
- **Value rules (inference — playtest/profiling settles all ranges, sRGB albedo 0-255):**
  - No pure black albedo: minimum 32 (`#202020`); no pure white: maximum 225.
  - Floors 45-90, ceilings 40-80, walls 80-140, props 70-160, interactables 140-200 (at least ~1.5x the surround), character torso/head 110-220.
  - Never rely on emissive to light a surface; use real lights. A small global ambient floor keeps all albedos above ~2-3% screen luminance in Low Power.
  - Emissive is reserved for: objectives, exit, emergency strips, corridor stripes, monitor and terminal screens, beacons, indicators. No decorative emissive.
- **Flashlight:** warm white (Bone Flashlight), 14 m range, ~40 degree cone, soft edge (inference — playtest settles it). Held items and viewmodel catch it with moderate specular so they read as the player's.
- UI palette: Section 7 (not authored); it inherits cyan/green/red/amber roles above.

## 5. Character Design Direction

### Survivors (5 slots; level doc supports S1-S5)

- **Archetype:** facility evacuees in padded work jumpsuits with one carried item each. Anonymous bodies, memorable accessories.
- **Identical bodies.** All survivors share one skeleton, height, proportions and animation set so the disguise needs no scale or rig differences. Identity differs only through the look resource below.
- **Identity kit = one copyable `CharacterLook` resource per survivor (in code: the existing `CharacterDef`, `data/characters/c1..c5.tres`), three redundant traits (hue + silhouette + pattern):**

| Slot | Suit colour | Accessory silhouette | Chest stripe pattern |
|------|-------------|----------------------|----------------------|
| 1 | Bone `#E6E1D3` (lightest) | Hard hat with lamp | One horizontal bar |
| 2 | Safety Yellow `#E3B31C` | Large square backpack | Two bars |
| 3 | Cobalt `#2E63B8` (darkest) | Hood + scarf tail | Chevron |
| 4 | Rust Orange `#C8581E` (mid) | Cross-strap radio with short antenna | Three dots |
| 5 | Violet `#7B4FA0` | Shoulder pad + clipboard | No stripe, plain sleeve band |

- Suit colours separate by value as well as hue (light / light-mid / dark / mid / mid-dark) so they hold in monochrome and in red/amber zone light. Accessory is the primary identifier at distance in the dark (silhouette against emergency strips); stripe pattern is the close-range identifier under the flashlight (retro-reflective stripe material, high albedo, bright when lit, never emissive).
- **Copy rule (LB-6, Borrowed Face):** the disguise swaps the shapeshifter's look resource id to the target's. Everything above is the whole of what the disguise copies: albedo, normal, ORM maps, accessory mesh, stripe mask, footstep set. No per-instance data: no baked dirt, decals, wear or blood that differs per spawn or per round. Wear is baked into the shared texture set only, so the copy and the original are identical.
- No role indicators of any kind on any body (name tag, outline, tint, aura, shader tell, particle) in any form (LB-6, ADR-0004). Carried drive/fuse and held stun item are not part of the look (Borrowed Face): they are the sanctioned tells.
- Downed/injured presentation is a state animation and pose, not a texture or tint, and the copy never shows it.
- **Pose/expression:** neutral shoulders-down walk, shaky flashlight hand, no face detail needed beyond a dark visor/goggles or a covered mouth (cheap, less uncanny, faster to copy). Hold-to-interact pose is a shared animation; the copy plays it too.

### Shapeshifter true form (separate look, shown after Transforming or instantly at lunge wind-up)

- **Silhouette:** about 2.4 m, over-long arms, narrow trunk, no accessory, distinct skeleton shape on the same rig family; never reads as any of the five survivors.
- **Surface:** wet near-black albedo (sRGB ~40-55, not pure black), strong specular/clearcoat so the flashlight lights it up, pale bone-white teeth/ribs/claws at albedo ~190-220 for readable focal points. Eye-shine only as retro-reflection under a flashlight, no emissive eyes.
- **Transformation:** the 2 s warp exists only while Transforming (Borrowed Face tell T1, shown on a relevant body handle), never in the steady disguised state. The reveal frame is silhouette-first: a clean, high-contrast shape at the end of the warp.
- True form uses its own LOD0-LOD2 meshes and materials; the disguise uses the survivor meshes. Nothing carries over between forms except the skeleton.

### Detail and LOD philosophy

- Survivors seen at 2-15 m in the dark: silhouette and large shapes carry identity; fine detail (stitching, buckles) only on LOD0 and only as baked texture.
- LOD0 under 6 m, LOD1 6-15 m, LOD2 beyond (inference — profiling settles it). Accessory silhouette must survive to LOD2.
- Facial animation: none. Head orientation, flashlight sway and posture carry behaviour tells (T5).

## 6. Environment Design Language

- **Architecture:** a late-20th-century government research facility: poured concrete, painted block, steel doors, glazed partitions, raised-floor server hall, security wing with reinforced glass. Utilitarian, repetitive, no decorative ornament. Aged by abandonment, not by destruction.
- **Texture philosophy: stylised PBR-lite.** Albedo + normal + packed ORM (occlusion/roughness/metallic) via `StandardMaterial3D`, hand-painted or tileable-authored, not photoscanned. Why for a small team: shared tileables and trim sheets produce consistent results with few artists, low texture memory, quick iteration, and visual cohesion that hides inconsistent source. Slightly desaturated painted look keeps values in the legal range and forces silhouette and light to carry the mood. Wear is baked into shared tileables/trims, not authored per object.
- **Texel density (inference — playtest/profiling settles it):** environment 256 px/m, props 256-512 px/m, characters 512 px/m, held items/viewmodel 1024 px/m. Keep within a 2x band across one room; never mix densities on adjacent surfaces.
- **Trim sheets and tileables:** 4 environment trim sheets (concrete/wall base, metal/door frames, glass/mullion, floor markings/pipes) plus 8-12 tileable materials (floor tile, concrete, painted block, steel plate, ceiling panel, rubber matting, checker plate, server rack). All room geometry maps to these; unique texture sets only for hero props (The Core, breaker wall, monitor wall, terminal, exit door). Decals (stains, signage, cracks) are static and placed once in the level scene, identical on every client and every round; they are part of the facility, not of a character.
- **Prop density per zone (inference — playtest settles it):**

| Zone | Density | Rule |
|------|---------|------|
| A labs | Medium (4-6 props per 10 m^2) | Benches create shadow pockets; props at 1.0 m and below leave door swing areas, hide points and exits clear |
| A1 entry/decon | Sparse (1-2) | Orientation, three clear exits |
| A2 lab spine | Sparse (0-1) | Narrow hall, long sightline, glass is the interest |
| B server/power | Low-medium (2-3) | Rack lanes 2-3 m wide are the clutter; The Core must be visible from every B1 doorway |
| C security/evac | Low (1-2) | Exposed on purpose; holdout needs sightlines |
| Corridors H-N/H-S | Very sparse (0-1) | 48-50 m sightlines, stripe floor guide, wall-mounted clutter only |

- **Environmental storytelling:** abandoned desks, sealed specimen fridges, dead monitors, security log screen, evacuation signage. Props tell "someone left in a hurry", never "here is an objective". No collectibles, no readable lore beyond signage (level doc).
- **Wayfinding:** zone colour (A/B/C), corridor stripes (solid blue north / dashed orange south), room-name signage (matches callout IDs), landmark lights. Objective items and exit have unique silhouettes and are the brightest emissives in their rooms.
- **Hard rule: no prop may resemble an objective silhouette or carry the objective cyan.** Decor emissives use dim amber or dim green-white at low energy only, never cyan or exit green.
- **Reduced readability tests:** each room is checked in Low Power with only a flashlight, in Blackout, and in greyscale. If an objective or exit is not found within 3 s of entry (inference — playtest settles it), raise value or add a light.

## 7. UI/HUD Visual Direction

[To be designed]

Not authored 2026-10-15 — outside the chosen scope (UI is specced in design/ux/hud.md).

## 8. Asset Standards

### Formats

- **Models:** glTF 2.0 binary `.glb` imported through Godot's importer. Source files (`.blend`, `.psd`, `.spp`) live outside `res://` assets or under `assets/source/` and are not imported.
- **Textures:** PNG, 8-bit, sRGB for albedo, linear for normal/ORM; no JPEG. Normal maps OpenGL (Y+) with BC5/RG storage. Import: VRAM Compressed (BC7 for albedo and ORM, BC5 for normals), mipmaps on, filter anisotropic.
- **Audio/other:** owned by audio-director; not covered here.
- **Material resources:** `.tres` per material, built from the shared tileable/trim set; characters reference their `CharacterLook` resource (a `.tres`) for albedo/accessory/stripe data.
- **Colour space:** sRGB source; Godot's HDR 2D off; tonemap and exposure set by technical-artist.

### Naming (snake_case, `[category]_[name]_[variant]_[size].[ext]` per project.yaml)

- Categories: `env`, `prop`, `char`, `vfx`, `ui`, `tex`, `mat`.
- Suffixes: `_albedo`, `_normal`, `_orm`, `_emissive` (map type goes in the variant slot); LODs `_lod0`..`_lod2`.
- Examples: `env_wall_concrete_a_albedo_512.png`, `prop_data_drive_lit_small.glb`, `char_survivor_01_albedo_1024.png`, `char_shapeshifter_true_lod0.glb`, `mat_floor_tile_a.tres`, `char_survivor_01_look.tres`.

### Texture resolution tiers (inference — playtest/profiling settles it)

| Tier | Size | Use |
|------|------|-----|
| XL | 2048 | Hero props, viewmodel set, trim sheets |
| L | 1024 | Characters, large props, tileables |
| M | 512 | Normal props, tileable detail |
| S | 256 | Small props, decals, icons |

- Max texture size for any one asset is the tier above; larger requires art-director sign-off.
- Characters: one 1024 set for the shared body, one 512 set for the accessory per survivor (pattern and stripe baked into the albedo/mask).

### Material slots and LOD

- **Material slots:** characters max 2 (body, accessory); props 1; environment pieces 1-2 (trim + tileable); hero props max 3. Fewer slots = fewer draw calls (inference — profiling settles it).
- **LOD:** characters 3 LODs (Section 5 ranges); props over ~0.5 m get 2 LODs; room shell and trims get none (small map, no streaming). Use Godot visibility ranges and `GeometryInstance3D` ranges, not custom scripts. Silhouette must hold at every LOD.
- **Colliders:** separate simplified collision, never the render mesh; no visual-only thin props in the player capsule path (0.8 m min doorway clear width, step 0.35 m, per level doc geometry limits).

### Folder layout (proposed)

```
assets/
  art/
    characters/survivors/        # shared body, per-survivor look resources
    characters/shapeshifter/     # true form meshes, materials
    environment/{trim,tileable,props,decals}/
    materials/                   # shared .tres materials
    vfx/                         # owned by technical-artist
    ui/                          # per Section 7 / hud.md
  source/                        # authoring files, not imported
```

### Engine budgets

Drafted by technical-artist 2026-10-15. Source: technical-preferences (60 fps, 2000 draw calls); every other number is inference until a minimum-spec GPU is chosen.

Status: draft, 2026-10-15. Godot 4.7.2, Forward+, Jolt, Windows PC, 1 map, 5 players.
Sourced = `.claude/docs/technical-preferences.md` (project.yaml has no performance/platform keys) or `docs/engine-reference/godot/`. Everything else is **(inference)**, with what settles it.

#### Sourced
- 60 fps / 16.6 ms frame, 2000 draw calls/frame (technical-preferences; "revise after profiling").
- Memory ceiling is TO BE CONFIGURED (target hardware unset). All VRAM numbers below are inference until set.
- Windows default backend is D3D12 since 4.6; shader baker exists since 4.5; SMAA 1x since 4.5 (rendering.md). Test on the shipping backend, and bake shaders at export.
- Today: characters are a CapsuleMesh + one StandardMaterial3D `material_override` + a child SpotLight3D "Cone" (`round_client.gd`); facility lights are per-cell SpotLight3D + OmniLight3D (`lighting_presenter.gd`); map is BoxMesh greybox. No art assets exist yet.

#### Shared-rig rule (hard constraint)
- ONE survivor mesh/skeleton/UV layout. Survivor identity = material + texture data only (albedo/ORM swap via per-instance params or `material_override`).
- Shapeshifter disguise = swap the same data onto the same rig. No per-survivor geometry, bones, blend shapes, attachments or extra material slots. Accessories become texture detail or are shared by all.
- Same mesh LOD chain, same silhouette, same collider, same footstep/anim set for all, so nothing visibly differs when disguised.
- First-person arms: same rule (skin/sleeve via the same swappable material).

#### Triangles (inference; profiling the 5-player room settles it)
- FP arms: 8k tris (only one set on screen).
- TP character: 15k LOD0, 7k LOD1, 3k LOD2. Up to 4 others visible at once.
- Hero prop: 8k. Small prop: 1.5k. Room module: 20k (including trim).
- Scene target: <=1.5M visible tris, <=1000 draw calls (half the sourced ceiling, for headroom). Settle with the greybox plus placeholder dress pass in the Godot profiler.

#### Textures and VRAM (inference)
- Channel-packed PBR: albedo(+A) / normal / ORM. No separate maps beyond these.
- Characters follow the tier table above (1024 shared body set + 512 accessory set per look; AD-245 resolved the technical-artist's 2k proposal to the art-director tier). FP arms 2k. Hero prop 1k-2k. Small prop 512-1k. Room modules 1k-2k, tiling trim sheets and a shared atlas preferred.
- Texture VRAM budget: 1.0 GB total (inference; assumes mid-range 6-8 GB GPU). Settle with the minimum-spec GPU decision.
- Compression: VRAM Compressed, BC7 on desktop (albedo, ORM), BC5 normals (Normal Map import preset). Mipmaps ON, Fix Alpha Border ON. ASTC is mobile-only, so not used (PC target).
- Texture sources are PNG (lossless). Godot compresses on import; never ship lossy sources.
- Compressed 2k BC7 is about 5.3 MB with mips, so a character set is about 16 MB. Check the 4.4-4.7 import-default changes against the editor before locking (the engine-reference docs list none, UNVERIFIED).

#### Materials
- <=2 material slots per mesh (characters: 2, body + accessory, per Material slots above; AD-245). Room modules share a small material library. Fewer slots means fewer draw calls per instance.
- Prefer StandardMaterial3D. Custom shaders only with a documented parameter list and a cost note.

#### LOD / visibility range
- Manual authored LOD1/LOD2 for characters (the rig is shared, so authoring is paid once). Use Godot's automatic mesh LOD (import-time, glTF) for props and room modules. Characters need manual LODs so the disguise stays pixel-consistent. (inference; verify the auto-LOD silhouette on skinned meshes.)
- Visibility ranges on small props: fade out at about 25 m; the facility is indoor, so rooms and doors occlude. Use occluder nodes only if profiling shows overdraw. (inference.)

#### Lights and shadows (inference; profile on D3D12 with 4 flashlights on)
- Each flashlight is a dynamic shadowed SpotLight3D: 4 survivors, plus the local one is the same light. Cap shadowed lights visible at once to 5 (4 flashlights + 1 spare for events).
- Facility lights: shadows OFF by default (current per-cell overhead spots are unshadowed, keep that). At most 2 shadowed facility lights in view, for hero spaces only.
- Omni lights (strobes, alarm, shock) shadow OFF. Omni shadows cost 6 faces.
- Positional shadow atlas: 4096 (default), quadrants set 1 for subdivision. Flashlight shadow in the top quadrant. Settle with a shadow-atlas overflow check on the 4-flashlight scene.
- Shadow-casting meshes: set `cast_shadow` off on small props and decals; use a lower-detail shadow proxy where cheap.
- Total lights per mesh (Forward+ clustered): keep <=8 overlapping any surface.

#### Import settings
- Meshes: glTF 2.0 `.glb`, one file per asset, meters, Y-up. Generate LODs ON, generate shadow mesh ON, lightmap UVs OFF (no baked GI planned: unconfirmed).
- Character `.glb` has the shared skeleton only; textures are separate PNG resources, not embedded.
- Naming: snake_case per technical-preferences.

#### Frame target
- 60 fps, 16.6 ms (sourced). Render share 10 ms, leaving 6.6 ms for sim and netcode (inference; profiling settles it).

#### Open inputs
- Minimum-spec GPU and RAM/VRAM ceiling, from the user.
- Whether a baked-GI or SDFGI/SSAO look is chosen (art-director), which changes the lighting cost.

### Review checklist (art-director)

- Albedo values inside legal range; no pure black/white.
- No character texture or mesh detail the look resource does not own.
- No emissive on any body; no outline, tint or shader on any body.
- Semantic colour has a shape/pattern backup.
- Naming and folder layout followed.

## 9. Reference Direction

[To be designed]

Not authored 2026-10-15 — outside the chosen scope (designer let the art director propose; references are folded into sections 1–6).
