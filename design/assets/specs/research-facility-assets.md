# Asset Specs — Level: research-facility

> **Source**: `design/levels/research-facility.md`; `design/assets/entity-inventory.md` rows 17-79; Visual/Audio sections of `survivor-objectives.md`, `survivor-defense.md`, `scare-events.md`, `monster-abilities.md`, `first-person-controller.md`
> **Art Bible**: design/art/art-bible.md
> **Generated**: 2026-10-15
> **Status**: 63 assets specced / 0 approved / 0 in production / 0 done

art-director and technical-artist skipped — Solo mode: specs derived in this session from art bible rules; technical constraints not validated beyond the art bible §8 budgets.

**Rules for every asset in this file:**
- **Art bible §6:**
  - stylised PBR-lite (albedo, normal, ORM) on `StandardMaterial3D`;
  - environment texel density 256 px/m and props 256-512 px/m, held within a 2x band per room;
  - albedo sRGB 32-225;
  - wear is baked into shared textures;
  - decals are static.
- **Art bible §8:**
  - `.glb` meshes and PNG sources;
  - VRAM compressed (BC7 for albedo and ORM, BC5 for normals);
  - room shells and trims get no LODs, and props over ~0.5 m get 2;
  - separate simplified colliders.
- **Objectives:** no prop may copy an objective silhouette or use objective cyan `#3FA9D6` or exit green `#4FD18B` (§6 hard rule).
- **Gameplay geometry:** room footprints, door positions and fixture ids are gameplay data in `data/maps/research_facility.tres`. The art replaces greybox visuals only and must not move a marker.

Common negative prompt: `no text, no logo, no people, no blood, no gore, no pure black, no photoreal scan, no neon cyberpunk`.
Common style prompt: `stylised PBR, slightly desaturated hand-painted, late-20th-century government research facility, abandoned not destroyed, utilitarian`.

---

## Trim sheets and tileables (ASSET-015..027)

| ID | Name | Res | Naming | Description |
|----|------|-----|--------|-------------|
| ASSET-015 | Trim: concrete / wall base | 2048 | `tex_trim_concrete_{albedo,normal,orm}_2048.png`, `mat_trim_concrete.tres` | Skirting, wall caps, column edges, kick plates. Grey-beige concrete with chipped edges |
| ASSET-016 | Trim: metal / door frames | 2048 | `tex_trim_metal_*_2048.png` | Door frames, jambs, rails, vents, brackets. Painted steel, worn at touch points |
| ASSET-017 | Trim: glass / mullion | 2048 | `tex_trim_glass_*_2048.png` | Thin dark mullions, blue-green glass tint, see-through at flashlight angle (§3) |
| ASSET-018 | Trim: floor markings / pipes | 2048 | `tex_trim_markings_*_2048.png` | Hazard edge strips, floor arrows, pipe runs, cable trays. Corridor stripes are a separate emissive (ASSET-030) |
| ASSET-019 | Tileable: floor tile | 1024 | `tex_floor_tile_a_*_1024.png` | Off-white vinyl lab tile, grout, scuffs. Footstep surface `tile` |
| ASSET-020 | Tileable: concrete | 1024 | `tex_concrete_a_*_1024.png` | Poured concrete floor or wall, form lines. Footstep surface `concrete` |
| ASSET-021 | Tileable: painted block | 1024 | `tex_painted_block_a_*_1024.png` | Painted cinder block, two-tone (zone colour below 1.2 m, inference) |
| ASSET-022 | Tileable: steel plate | 1024 | `tex_steel_plate_a_*_1024.png` | Riveted plate for B zone walls |
| ASSET-023 | Tileable: ceiling panel | 1024 | `tex_ceiling_panel_a_*_1024.png` | Drop-ceiling tiles with a light-fixture gap |
| ASSET-024 | Tileable: rubber matting | 1024 | `tex_rubber_mat_a_*_1024.png` | Ribbed black-grey matting (albedo ≥32) |
| ASSET-025 | Tileable: checker plate | 1024 | `tex_checker_plate_a_*_1024.png` | Diamond plate for B2/B3 |
| ASSET-026 | Tileable: server rack face | 1024 | `tex_server_rack_a_*_1024.png` | Rack fronts and vents; LED dots dim amber only, never cyan |
| ASSET-027 | Tileable: metal grate | 1024 | `tex_metal_grate_a_*_1024.png` | Footstep surface `metal grate` (first-person-controller V/A). Not in the art bible's list, so this row adds it (AD-247) |

**Generation Prompt (each):** `seamless tileable texture, [description], [common style], top-down flat lighting, no shadows` + common negative.
**Art Bible Anchors:** §6 trim and tileable strategy; §8 tiers XL (trims) and L (tileables).

## Decals, signage, stripes (ASSET-028..030)

| ID | Name | Res | Naming | Description |
|----|------|-----|--------|-------------|
| ASSET-028 | Decal set | 256 atlas cells | `tex_decal_set_*_1024.png` (4x4 atlas of 256 cells) | Water stains, cracks, scuffs, taped notes without legible text. Static, placed once in the level |
| ASSET-029 | Room and zone signage | 256 | `tex_signage_*_1024.png` atlas | Room callout IDs (A1..C5), zone letter, evacuation arrows. IDs must match callout names; a shape backup for colour (§4) |
| ASSET-030 | Corridor floor stripes | 256 | `mat_stripe_hn.tres`, `mat_stripe_hs.tres` | H-N solid blue, H-S dashed orange; low emissive (wayfinding is an allowed emissive use) |

## Room modules (ASSET-031..047)

Each room is built from the trim and tileable set above plus the dressing sets (ASSET-067..069), with no unique texture sets. The polycount is at most 20k tris per room module (§8 engine budgets, inference). Naming follows `env_room_[id].glb`, for example `env_room_a1.glb`. Footprints come from the level doc and `research_facility.tres`.

| ID | Room | Zone light | Key read |
|----|------|------------|----------|
| ASSET-031 | A1 Entry / Decon | Lab green-white | Curved decon arch landmark; three clear exits; sparse |
| ASSET-032 | A2 Lab Spine | Lab green-white, 3 segments | 3x32 hall with glass walls to A3/A4; sparse; glass is the interest |
| ASSET-033 | A3 Wet Lab | Lab green-white | Benches making shadow pockets; hiding cabinet |
| ASSET-034 | A4 Specimen Lab | Lab green-white | Glass on two sides, overlooked by A7; lab door into B1 |
| ASSET-035 | A5 Cold Storage | Lab green-white, cooler | Sealed specimen fridges, hiding locker |
| ASSET-036 | A6 Director's Office | Lab green-white, warmer desk lamp (dim amber) | Desk dressing, hiding cabinet |
| ASSET-037 | A7 Observation Gallery | Lab green-white | Floor-to-ceiling window down into A4 (landmark) |
| ASSET-038 | H-N North Service Corridor | Neutral, 4 segments | 48x4, solid blue stripe, wall-mounted clutter only |
| ASSET-039 | H-S South Service Corridor | Neutral, 4 segments | 50x4, dashed orange stripe, camera c2 |
| ASSET-040 | B1 Server Hall | Amber equipment | Double height, rack lanes 2-3 m wide, The Core visible from every doorway |
| ASSET-041 | B2 Power Room | Amber | Breaker wall landmark (ASSET-055) |
| ASSET-042 | B3 Cooling Plant | Amber | Loud machinery, pipes, locker |
| ASSET-043 | C1 Security Office | Security red | Monitor wall station; barricadable doors |
| ASSET-044 | C2 Checkpoint | Security red | Checkpoint gate between B and C; archway into C4 |
| ASSET-045 | C3 Records Archive | Security red | Shelving rows, low prop density |
| ASSET-046 | C4 Evacuation Hall | Security red, exit green at Exit Open | Exit door hero prop, red beacon, exposed holdout |
| ASSET-047 | C5 Backup Control | Security red | Backup controls panel, locker |

**Generation Prompt (concept per room):** `interior concept, [room and key read], [zone light colour], first-person eye height 1.6 m, single flashlight cone, near-dark, [common style]` + common negative.
**Art Bible Anchors:** §2 mood per zone; §6 prop density table; §4 zone temperatures. Zone C red will wash survivor hues, so its tuning is a playtest item (active.md).

## Doors and openings (ASSET-048..051)

| ID | Name | Polycount | Naming | Description |
|----|------|-----------|--------|-------------|
| ASSET-048 | Ordinary door | 2k | `env_door_standard.glb` (+ `_burst` variant) | Steel door with a small wire-glass window. It does not swing for the slam scare: it shudders in place. The burst variant is buckled for the door-burst scare |
| ASSET-049 | Barricadable door | 2.5k + barricade 1.5k | `env_door_barricade.glb`, `prop_barricade_planks.glb` | Zone C heavy door. The barricade has build, strain and break states (3 meshes or blend shapes, inference) and shakes per strike |
| ASSET-050 | Open archway | 1k | `env_archway.glb` | A trim-sheet frame only (A1 to H-S, C2 to C4) |
| ASSET-051 | Glass partition | 500 per panel | `env_glass_panel.glb` (+ `_cracked`) | The cracked variant stays see-through (glass-break scare). The A7 window is 3 panels |

## Props: hiding, objectives, hero (ASSET-052..066)

| ID | Name | Polycount | Res | Naming | Description |
|----|------|-----------|-----|--------|-------------|
| ASSET-052 | Hiding lab cabinet | 2k | 512 | `prop_hide_cabinet.glb` | Tall steel cabinet with an openable door and vent slits a survivor could peer through |
| ASSET-053 | Hiding storage locker | 2k | 512 | `prop_hide_locker.glb` | Full-height locker, same behaviour |
| ASSET-054 | Data drive | 800 | 512 | `prop_data_drive.glb` | Flat slab with a lit cyan edge bar (the only cyan object family). Bright when dropped on the floor |
| ASSET-055 | Breaker wall | hero 8k | 2048 unique | `prop_breaker_wall.glb` | B2 landmark: rows of breakers, warning plates, dim amber pilot lights |
| ASSET-056 | Fuse | 600 | 256 | `prop_fuse.glb` | Cylinder with two rings, a silhouette distinct from the drive |
| ASSET-057 | Fuse box | 2k | 512 | `prop_fuse_box.glb` | Tall panel with a vertical indicator bar: dark in Low Power, lit when active |
| ASSET-058 | Evacuation terminal (T1-T3) | hero 8k | 2048 unique | `prop_terminal.glb` | Wide screen under a top hood with drive dock slots. The screen shows the activation, countdown and paused states. Cyan accents for the drive dock only |
| ASSET-059 | Exit door E and chevron frame | hero 8k | 2048 unique | `prop_exit_door.glb` | Chevron-framed blast door with an Exit Green light; its open animation matches the door cycle |
| ASSET-060 | The Core | hero 8k | 2048 unique | `prop_core.glb` | B1 double-height light column and the brightest point on the map; pulses on fuse install. Warm white, not cyan or green |
| ASSET-061 | Monitor wall and C1 station | hero 8k | 2048 unique | `prop_monitor_wall.glb` | Bank of CRT-style monitors; one live feed at a time, the rest dim static |
| ASSET-062 | Backup controls panel | 2k | 512 | `prop_backup_panel.glb` | C5 panel. Its function is an open question in the level doc, so build it as dressing until that is decided |
| ASSET-063 | Backup light switch | 300 | 256 | `prop_light_switch.glb` | Chunky lever in a box with a small dim amber pilot light; hold to end a Blackout |
| ASSET-064 | Surveillance camera | 800 | 256 | `prop_camera.glb` | Wall or ceiling camera with a small red recording LED (dim) |
| ASSET-065 | Monitor feed screen material | n/a | render target | `mat_monitor_feed.tres` | Viewport texture with a scanline overlay; the impossible-image scare frame is a separate texture |
| ASSET-066 | PA speaker with light | 400 | 256 | `prop_pa_speaker.glb` | Horn speaker with a small lamp that lights during the Recording scare |

**Generation Prompt (each):** `game prop concept, [description], [common style], orthographic three views, neutral grey background` + common negative.
**Art Bible Anchors:**
- §3 shape language: the objective silhouettes are a slab, a ringed cylinder, a hooded wide screen and a chevron.
- §4: cyan is reserved for objectives and green for the exit.
- §6: unique texture sets are reserved for hero props.

## Dressing sets (ASSET-067..069)

| ID | Name | Polycount | Res | Naming | Contents |
|----|------|-----------|-----|--------|----------|
| ASSET-067 | Lab dressing set | ≤1.5k each | 512 | `prop_lab_*.glb` | Benches, abandoned desks, office chairs, sealed specimen fridges, dead monitors, binders. At or below 1.0 m where they sit near doors, hides or exits |
| ASSET-068 | Server, power and cooling dressing | ≤1.5k each | 512 | `prop_server_*.glb`, `prop_cooling_*.glb` | Server racks, cable bundles (the organic-curve exception, §3), pipes, B3 pumps and fans |
| ASSET-069 | Security dressing | ≤1.5k each | 512 | `prop_security_*.glb` | Checkpoint gate arm, security log screen, records shelving, file boxes |

## Lights and lighting states (ASSET-070..077)

These are light rigs and fixture meshes, not textures. The greybox `lighting_presenter.gd` and `lighting_presets.gd` already drive the states, so the art pass swaps fixture meshes and tunes energy and colour. The art pass can add at most 1 shadowed facility light per view beyond the 4 flashlights (§8 engine budgets).

| ID | Name | Fixture mesh | Light |
|----|------|--------------|-------|
| ASSET-070 | Lab panel lights (Zone A) | `prop_light_panel.glb` (300 tris) | `#A9C4B8`, about 6500 K, low energy, unshadowed |
| ASSET-071 | Equipment glow (Zone B) | rack LEDs on ASSET-026 | `#D98A2B`, about 2700 K |
| ASSET-072 | Security lights (Zone C) | `prop_light_cage.glb` | `#B3342E`, low energy, desaturated |
| ASSET-073 | Emergency floor strips and exit signage | `prop_emergency_strip.glb` | Faint, always on in every volume, including in a Blackout |
| ASSET-074 | Evacuation beacons (amber) | `prop_beacon.glb` (amber lens) | Rotating amber along H-N, H-S and C2 toward C4. Steady when reduced flash is on. Missing from the art bible §4 (inventory concern) |
| ASSET-075 | C4 evacuation beacon (red) | `prop_beacon.glb` (red lens, triangle cap) | Rotating red; spins on Terminal Activating. The triangle cap is its shape backup (§4) |
| ASSET-076 | Alarm strobe | `prop_strobe.glb` | Rate-capped strobe for the Alarm scare; obeys reduced flash |
| ASSET-077 | Lighting presets | n/a | Low Power, Restored, Evacuation, Blackout and Exit Open values per volume. Tuning happens on the textured build, and the 3 s find test applies (§6) |
