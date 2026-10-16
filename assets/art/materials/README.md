# Environment materials

Research-facility materials for ASSET-015..030 (`design/assets/specs/research-facility-assets.md`),
built to art bible §4/§6/§8. Rebuild everything from the repo root:

```sh
"$BLENDER" --background --factory-startup --python tools/art/build_textures.py  # textures + CREDITS.md
"$GODOT" --headless --path . --import                                           # VRAM compressed import
"$GODOT" --headless --path . -s res://tools/art/make_materials.gd               # mat_*.tres
"$GODOT" --path . --windowed --resolution 768x512 -s res://tools/art/preview_materials.gd  # opens a window
```

The preview step writes `production/qa/evidence/environment-materials/NN-mat_*.png`
(each material on a cube or quad plus a sphere, near-dark, one warm-white spot at the
game flashlight's energy 4.0). Sources and licences: `assets/art/CREDITS.md`.

## Suggested zone mapping (art bible §6)

For `data/art/surface_materials.tres` (owned by the level-geometry work, not written here).

| Zone | Floor | Wall | Ceiling |
|---|---|---|---|
| A labs (A1-A7) | `mat_floor_tile_a.tres` | `mat_painted_block_zone_a.tres` | `mat_ceiling_panel_a.tres` |
| B server/power (B1-B3) | `mat_checker_plate_a.tres` (B2, B3); `mat_metal_grate_a.tres` (B1 raised floor) | `mat_steel_plate_a.tres` | `mat_steel_plate_a.tres` |
| C security/evac (C1-C5) | `mat_concrete_a.tres` | `mat_painted_block_zone_c.tres` | `mat_concrete_a.tres` |
| Corridors H-N, H-S | `mat_concrete_a.tres` or `mat_rubber_mat_a.tres` | `mat_painted_block_a.tres` | `mat_concrete_a.tres` |

Ceilings for B and C and the B1 grate floor are inference (§6 names only floor and wall
materials for those zones); settle in the greybox. Corridor floors also get the stripe
meshes: `mat_stripe_hn.tres` (H-N, solid blue) and `mat_stripe_hs.tres` (H-S, dashed orange).

## Materials

| Material | Type | Mapping | Notes |
|---|---|---|---|
| `mat_floor_tile_a` .. `mat_metal_grate_a` (9 tileables) | ORMMaterial3D | world triplanar, `uv1_scale` 0.25 (1024 px = 4 m, 256 px/m) | Footstep surfaces: tile, concrete, rubber, metal grate |
| `mat_painted_block_a`, `_zone_a`, `_zone_c` | ORMMaterial3D | world triplanar | Lower 1.2 m band in neutral grey / Lab Green-White / muted Security Red. The band is the bottom 30% of the image, which world triplanar puts at world y 0-1.2 m only when the floor is at y = 0 and the wall is under 4 m (B1's 6 m walls use steel plate) |
| `mat_server_rack_a` | ORMMaterial3D | world triplanar | 1 m bays; LED dots dim amber in the albedo, no emission |
| `mat_trim_concrete`, `mat_trim_metal`, `mat_trim_markings` | ORMMaterial3D | UV (strip layout below), 2048 px = 8 m | |
| `mat_trim_glass` | ORMMaterial3D, alpha | UV | Mullion strips opaque, glass strips alpha ~0.3. One alpha material: sorting artefacts possible where panes overlap |
| `mat_decal_set` | ORMMaterial3D, alpha | UV, 4x4 atlas of 256 cells | For quads placed on surfaces. Godot's `Decal` node has no UV-region setting; using an `AtlasTexture` cell on a `Decal` is unverified |
| `mat_signage` | ORMMaterial3D | UV, 4 x 8 cells of 256 x 128 | Layout below |
| `mat_stripe_hn`, `mat_stripe_hs` | StandardMaterial3D, emission x0.2 (multiply) | UV: U across, V along, 256 px = 1 m | H-S dashed 0.6 m on / 0.4 m off via alpha scissor |

All: normal maps OpenGL (Y+), ORM R occlusion / G roughness / B metallic, anisotropic
filtering, `ao_light_affect` 0.4 (inference; playtest settles it).

### Trim strip layout (all four trim sheets, rows from the top, px of 2048)

| Strip | Rows | Concrete | Metal | Glass | Markings |
|---|---|---|---|---|---|
| 0 | 0-64 | skirting | flat bar | mullion | hazard edge |
| 1 | 64-128 | cap | round rail | mullion | hazard thin |
| 2 | 128-256 | edge | bolt row | mullion | floor arrows (1 m repeat) |
| 3 | 256-384 | grooved cap | flat bar | mullion | painted line |
| 4 | 384-640 | column edge | vent louvres | glass | pipe |
| 5 | 640-896 | grooved kick plate | door jamb with stop | glass | large pipe, flanges every 2 m |
| 6 | 896-1408 | panel | riveted plate | glass | cable tray |
| 7 | 1408-2048 | grooved panel | plain wide plate | glass | cable bundle |

### Signage atlas (row-major, 4 columns)

Rows 0-3: A1-A7, B1-B3, C1-C5, H-N, H-S. Row 4: zone letters A, B, C. Row 5: evacuation
arrows left, right, up, down. Rows 6-7: blank plates A, B, C, H-N, H-S, then 3 neutral.
Every plate carries a shape as the colour backup (§4): A circle, B triangle, C square,
H-N solid bar, H-S dashed bar.

## Import and budget

Imports are VRAM compressed with mipmaps (BC7 high quality for albedo/ORM, normal-map
mode for normals). 49 textures: about 111 MiB estimated VRAM with mips (8 bpp), against the
1.0 GB texture budget (art bible §8).
