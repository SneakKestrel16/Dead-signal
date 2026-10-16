# Asset Specs — Character: survivors, shapeshifter, held items

> **Source**: `design/art/art-bible.md` §3, §4, §5, §8; `design/assets/entity-inventory.md` rows 1-16; `design/gdd/borrowed-face.md`, `monster-abilities.md`, `survivor-defense.md`, `downing-and-rescue.md`, `first-person-controller.md` (Visual/Audio sections)
> **Art Bible**: design/art/art-bible.md
> **Generated**: 2026-10-15
> **Status**: 14 assets specced / 0 approved / 0 in production / 0 done

art-director and technical-artist skipped — Solo mode: specs derived in this session from art bible rules; technical constraints not validated beyond the art bible §8 budgets the technical-artist drafted.

**Look resource:** the art bible's `CharacterLook` is the existing `CharacterDef` (`src/core/lobby/character_def.gd`, files `data/characters/c1.tres`..`c5.tres`, ids C1-C5, `appearance_id` 1-5, 0 = true form). Wiring the textures, accessory mesh and stripe mask into it is code work for the art-pass story, not part of these specs.

**Generation prompts** are text for concept and texture reference only. 3D meshes are modelled, or taken from CC0 sources with the licence recorded per asset (AD-247). Common negative prompt for every character prompt: `no text, no logo, no name tag, no glowing outline, no aura, no blood, no gore close-up, no photoreal face, no pure black`.

---

## ASSET-001 — Survivor shared body

| Field | Value |
|-------|-------|
| Category | 3D character |
| Polycount | LOD0 15k / LOD1 7k / LOD2 3k tris (§8 engine budgets, inference) |
| Texture Res | 1024 body set: albedo, normal, ORM (§8 tier L) |
| Format | `.glb` (skinned, one skeleton), PNG sources |
| Naming | `char_survivor_body_lod0.glb`, `char_survivor_body_albedo_1024.png` (albedo is a neutral greyscale base tinted per look) |
| Material slots | 1 of the character's 2 (body) |

**Visual Description:** A padded work jumpsuit on a plain adult body, 3:4:1 mass split, shoulders slightly down. The face is hidden behind a dark visor or a covered mouth, so no facial animation is needed. The suit albedo is a light neutral that the look tints, and wear is baked into this one shared texture.

**Art Bible Anchors:**
- §5: identical body, height and skeleton for all five; no per-instance dirt, decals or blood.
- §3: rounded padded forms that read as human against the true form's long angular silhouette.
- §6: albedo kept within sRGB 32-225.

**Generation Prompt:** `stylised PBR game character, facility evacuee in padded work jumpsuit, dark visor, neutral pose T-pose front and side orthographic, light grey suit, subtle baked wear, matte, soft studio light, clean silhouette`

**Status:** Needed

## ASSET-002..006 — Survivor looks C1-C5

| Field | Value |
|-------|-------|
| Category | Character look (data + accessory mesh + tint/stripe mask) |
| Polycount | Accessory ≤2k tris each, LOD to 3 levels; silhouette must survive to LOD2 (§5) |
| Texture Res | 512 accessory set (§8); suit tint is a colour on the body material, stripe from a shared mask |
| Format | `.tres` (`CharacterDef`) + `.glb` accessory |
| Naming | `char_survivor_01_look.tres` (= `data/characters/c1.tres`), `char_survivor_01_accessory_lod0.glb`, `char_survivor_01_accessory_albedo_512.png` |

| ID | Slot | Suit | Accessory | Stripe |
|----|------|------|-----------|--------|
| ASSET-002 | C1 | Bone `#E6E1D3` | Hard hat with lamp (lamp not emissive) | One horizontal bar |
| ASSET-003 | C2 | Safety Yellow `#E3B31C` | Large square backpack | Two bars |
| ASSET-004 | C3 | Cobalt `#2E63B8` | Hood and scarf tail | Chevron |
| ASSET-005 | C4 | Rust Orange `#C8581E` | Cross-strap radio, short antenna | Three dots |
| ASSET-006 | C5 | Violet `#7B4FA0` | Shoulder pad and clipboard | Plain sleeve band |

**Visual Description:** Each look is one suit colour, one accessory that reads as a silhouette at 15 m in the dark, and one stripe pattern that reads under the flashlight at close range. The disguise copies the whole look by id, so everything that tells survivors apart lives here and nowhere else.

**Art Bible Anchors:**
- §5: three redundant traits (hue, silhouette, pattern); value-separated so they hold in monochrome and in red or amber zone light.
- §4: colour never works alone; the accessory and the stripe are the backups.
- LB-6: no role indicator; the copy is identical.

**Generation Prompt:** `stylised game character turnaround, padded work jumpsuit in [suit colour hex], [accessory], retro-reflective chest stripe [pattern], dark visor, dim industrial corridor, single flashlight from front, silhouette readable`

**Status:** Needed

## ASSET-007 — Retro-reflective stripe material

| Field | Value |
|-------|-------|
| Category | Material |
| Texture Res | 256 mask, shared (§8 tier S) |
| Naming | `mat_survivor_stripe.tres`, `tex_survivor_stripe_mask_256.png` |

**Visual Description:** A pale, high-albedo stripe that brightens sharply when a flashlight hits it and stays dull grey in darkness. It is never emissive, so it cannot be seen without light. One mask carries all five patterns, selected by the look.

**Art Bible Anchors:** §5 (close-range identifier, never emissive); §6 (light is the only tutor).

**Generation Prompt:** n/a (flat mask; author by hand).

**Status:** Needed

## ASSET-008 — Survivor animation set

| Field | Value |
|-------|-------|
| Category | Animation |
| Format | `.glb` animation library on the shared skeleton |
| Naming | `char_survivor_anim_[name].glb` or one library `char_survivor_anims.glb` |

**Contents:**
- **Locomotion:** idle, walk, sprint, crouch-walk, crawl; shaky flashlight hand.
- **Interaction:** interact loop, hold-start and hold-end (fake holds identical), hide enter and exit, barricade build.
- **State:** shocked stagger, seized or pinned, Downed pose, Call for Help, kneel rescue, stand-up, Eliminated collapse.

These merge inventory rows 8-10.

**Visual Description:** The animations are grounded and slightly hunched, and posture carries the tells, not faces (§5 T5). The disguise borrows the whole set, so it has no monster variant. Injury shows as a pose, never as a tint.

**Art Bible Anchors:** §5 (pose-only injury, shared animations, no facial animation).

**Generation Prompt:** n/a (motion; reference video or mocap library, licence recorded).

**Status:** Needed

## ASSET-009 — Shapeshifter true form

| Field | Value |
|-------|-------|
| Category | 3D character |
| Polycount | LOD0 15k / LOD1 7k / LOD2 3k tris (same budget as survivors, inference) |
| Texture Res | 1024 set, albedo + normal + ORM; clearcoat via material |
| Format | `.glb` on the same rig family |
| Naming | `char_shapeshifter_true_lod0.glb`, `char_shapeshifter_true_albedo_1024.png` |

**Visual Description:** About 2.4 m tall, with a narrow trunk, over-long arms and no accessory, so it never reads as any survivor. The skin is wet near-black (sRGB 40-55) with strong clearcoat, so the flashlight catches it. Pale bone-white teeth, ribs and claws (albedo 190-220) are the focal points, and eye-shine is retro-reflection only, never emissive.

**Art Bible Anchors:** §3 (long and angular against round survivors); §5 (separate look; reveal is silhouette-first); §6 (no pure black).

**Generation Prompt:** `stylised horror creature concept, 2.4 m tall emaciated humanoid, over-long arms, narrow trunk, wet glossy near-black skin, bone-white exposed ribs teeth and claws, lit by a single flashlight from below-front, dark industrial corridor, high-contrast silhouette, orthographic turnaround` + common negative prompt and `no glowing eyes`

**Status:** Needed

## ASSET-010 — True form animations

**Contents:** idle and walk, lunge coil wind-up (the telegraph; it starts instantly from a disguise per AD-243), lunge hit, miss stumble, stun stagger, takedown pin, and a reveal turn toward viewers. Format and naming as ASSET-008 (`char_shapeshifter_anims.glb`).

**Visual Description:** The movement is fast, with long limbs and a readable wind-up of at least the GDD wind-up time. The wind-up must read as a threat from behind and from the side.

**Art Bible Anchors:** §3 and §5; monster-abilities rule 4 (wind-up telegraph).

**Status:** Needed

## ASSET-011 — First-person arms (viewmodel)

| Field | Value |
|-------|-------|
| Polycount | 8k tris (§8 engine budgets, inference) |
| Texture Res | 2048 (§8 tier XL, viewmodel set) |
| Naming | `char_viewmodel_arms.glb`, `char_viewmodel_arms_albedo_2048.png` |

**Visual Description:** Gloved arms in the padded suit sleeve with a neutral-grey glove. The sleeve is tinted to the local player's own look colour, which the player can only see on themselves. The arms hold the flashlight and the taser, and pose for interact and hold. The inventory marks this row as inference: the art bible names only a "viewmodel set".

**Art Bible Anchors:** §5, §8.

**Status:** Needed

## ASSET-012 — Flashlight

| Field | Value |
|-------|-------|
| Polycount | 1.5k tris (small prop) |
| Texture Res | 512 (tier M) |
| Naming | `prop_flashlight.glb` |

**Visual Description:** A chunky industrial torch with a rubber grip. Its beam is Bone Flashlight `#F2E6C8`, about 14 m long with a cone of about 40°, and the beam is part of the light setup, not this mesh. It is visible in third person in the hand of every survivor, including a disguised shapeshifter.

**Art Bible Anchors:** §4 (Bone Flashlight); survivor-defense V/A.

**Generation Prompt:** `stylised PBR prop, industrial rubber-grip flashlight, scuffed dark grey, orthographic three views`

**Status:** Needed

## ASSET-013 — Taser

| Field | Value |
|-------|-------|
| Polycount | 1.5k tris |
| Texture Res | 512 |
| Naming | `prop_taser.glb` |

**Visual Description:** A blocky yellow-and-black stun gun with a visible cartridge window that shows the remaining count as physical cartridges, not as text. It replaces the deprecated `arc_flare` registry entry.

**Art Bible Anchors:** §4 (yellow/black hazard pairing reads in the dark); survivor-defense V/A.

**Generation Prompt:** `stylised PBR prop, compact yellow and black stun gun, visible cartridge window, orthographic three views`

**Status:** Needed

## ASSET-014 — Taser darts and wires

**Visual Description:** A pair of small darts trailing thin bright wires to the target, which retract after the shot. The wire is a VFX line, so this asset is mesh-free apart from the darts (≤200 tris, sharing the taser's material).

**Naming:** `prop_taser_dart.glb`; the wire belongs to technical-artist VFX (`vfx_taser_wire`).

**Art Bible Anchors:** survivor-defense V/A.

**Status:** Needed
