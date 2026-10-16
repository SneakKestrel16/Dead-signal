# Art credits

All third-party sources are CC0 1.0 (public domain); no attribution is required,
it is recorded here for provenance (AD-248). Processed by `tools/art/build_textures.py`
(desaturated, value-clamped, ORM packed, composited with procedural detail).
Everything not listed is procedural from that script.

| Asset | Source | URL | Licence | Fetched | Used in |
|---|---|---|---|---|---|
| Dirty Tiles | Poly Haven | https://polyhaven.com/a/dirty_tiles | CC0 1.0 | 2026-10-15 | tex_floor_tile_a |
| Concrete Floor Worn 001 | Poly Haven | https://polyhaven.com/a/concrete_floor_worn_001 | CC0 1.0 | 2026-10-15 | tex_concrete_a, tex_trim_concrete, tex_trim_markings |
| Concrete Block Wall 03 | Poly Haven | https://polyhaven.com/a/concrete_block_wall_03 | CC0 1.0 | 2026-10-15 | tex_painted_block_* (surface detail under procedural block grid) |
| Blue Metal Plate | Poly Haven | https://polyhaven.com/a/blue_metal_plate | CC0 1.0 | 2026-10-15 | tex_steel_plate_a, tex_server_rack_a, tex_trim_metal, tex_trim_markings (pipes) |
| Office Ceiling 006 | ambientCG | https://ambientcg.com/view?id=OfficeCeiling006 | CC0 1.0 | 2026-10-15 | tex_ceiling_panel_a |
| Diamond Plate 008 A | ambientCG | https://ambientcg.com/view?id=DiamondPlate008A | CC0 1.0 | 2026-10-15 | tex_checker_plate_a |
| Metal Walkway 010 | ambientCG | https://ambientcg.com/view?id=MetalWalkway010 | CC0 1.0 | 2026-10-15 | tex_metal_grate_a |

## Characters

| Asset | Source | Author | URL | Licence | Retrieved |
|-------|--------|--------|-----|---------|-----------|
| Survivor body and true-form base mesh, skeleton, animations (`assets/art/characters/survivors/char_survivor_body.glb`, `assets/art/characters/shapeshifter/char_shapeshifter_true.glb`) | Universal Animation Library (Standard), glTF mirror of the itch.io release of 2025-06-10 | Quaternius | https://quaternius.itch.io/universal-animation-library (licence stated as CC0 on the itch.io page and https://quaternius.com/packs/universalanimationlibrary.html); files fetched from https://github.com/J-Ponzo/gltf-universal-animation-library | CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) | 2026-10-15 |

Modified in `tools/art/build_characters.py`: the mannequin is smoothed and padded into a jumpsuit, given a
visor, re-unwrapped and baked to new textures; the true form has stretched arm bones, a narrowed trunk and
added ribs, claws, teeth and spikes. Kept clips: Idle, Idle_Torch, Walk, Jog_Fwd, Sprint, Crouch_Idle,
Crouch_Fwd, Interact, PickUp_Table, Fixing_Kneeling, Push, Hit_Chest, Hit_Head, Death01, Punch_Enter,
Punch_Cross, Sword_Attack (reused for ASSET-008/010 rows: Death01 = Eliminated collapse, Hit_Chest = survivor
shocked stagger, Hit_Head = true-form stun stagger, Fixing_Kneeling = kneel rescue, Push = barricade build, Interact =
interact, Punch_Cross = lunge hit). Accessories, stripe mask and all textures are made for this project. Clips
Downed, Crawl, Call_Help, Stand_Up, Seized, Hide_Enter, Hide_Exit, Lunge_Coil, Lunge_Dash, Lunge_Stumble and
Takedown_Pin are keyed for this project on the same rig by `tools/art/build_anims.py` (poses start from library frames).

## Props

No third-party sources. Every prop in `assets/art/props/` (ASSET-052..064) is modelled procedurally from
primitives by `tools/art/build_props.py`; the hiding cabinet, hiding locker and breaker wall bodies use the
shared `mat_steel_plate_a.tres` (sources above), remapped in their `.glb.import` files.

## Viewmodel

| Asset | Source | Licence |
|-------|--------|---------|
| First-person arms (`assets/art/characters/viewmodel/char_viewmodel_arms.glb`) | Cut from this project's survivor body (`char_survivor_body.glb`, Quaternius Universal Animation Library base, see "## Characters"); poses made for this project | CC0 1.0 base; modifications are this project's |
| Flashlight, taser, taser dart (`assets/art/props/prop_flashlight.glb`, `prop_taser.glb`, `prop_taser_dart.glb`) | Procedural, made for this project | Project-owned |

Built by `tools/art/build_viewmodel.py` (arms cut to the forearms, hands and the elbow end of the upper arm,
decimated to the 8k budget, three poses baked with IK).
