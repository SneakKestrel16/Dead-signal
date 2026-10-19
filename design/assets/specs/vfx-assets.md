# Asset Specs — System: VFX

> **Source**: `design/assets/entity-inventory.md` rows 80-89; Visual/Audio sections of `borrowed-face.md`, `scare-events.md`, `survivor-defense.md`, `survivor-objectives.md`, `monster-abilities.md`, `downing-and-rescue.md`
> **Art Bible**: design/art/art-bible.md
> **Generated**: 2026-10-15
> **Status**: 10 assets specced / 0 approved / 0 in production / 0 done

art-director and technical-artist skipped — Solo mode: specs derived in this session from art bible rules; technical constraints not validated. The art bible §8 assigns VFX ownership to the technical-artist, who should review these before production.

**Rules for every VFX:**
- `GPUParticles3D` or a shader on the existing mesh, named `vfx_[name]` (`.tscn` plus `.tres` process material). Textures are at most 256 px (§8 tier S).
- Every flash or strobe has a reduced-flash variant, driven by the existing reduced-flash and reduced-motion flags.
- No VFX may tag a disguised body (LB-6). The transformation warp exists only while Transforming.

| ID | Name | Description | Art Bible / GDD anchor |
|----|------|-------------|------------------------|
| ASSET-078 | Transformation warp | 2 s refractive ripple over the current body plus spatial distortion within 15 m. It ends on a clean silhouette frame and plays on the relevant body handle only | borrowed-face V/A rule 8; §5 |
| ASSET-079 | Reveal flare | Short light flare scaled to distance when the true form is revealed (reduced flash: no flare, silhouette only) | scare-events V/A; borrowed-face V/A |
| ASSET-080 | Taser arc | Short blue-white arc at the target with a blue edge on the victim for the stun duration. The reduced-flash variant is a static edge with no flicker | survivor-defense V/A |
| ASSET-081 | Stun-resisted spark | Small spark burst, no stagger (true form immune hit) | survivor-defense V/A |
| ASSET-082 | Fuse install sparks | Brief sparks at the fuse box. They are not the Core pulse, which is a light change (ASSET-060) | survivor-objectives V/A |
| ASSET-083 | Door-burst debris and dust | Dust puff and a few chunks for the door-burst scare | scare-events V/A |
| ASSET-084 | Glass shards | Falling shards for the glass-break scare. The panel stays see-through (ASSET-051 cracked) | scare-events V/A |
| ASSET-085 | Lunge impact | Hit: a short dust and cloth burst on the survivor, no blood. Miss: floor scrape dust | monster-abilities V/A; §5 no gore |
| ASSET-086 | Drive and exit glow | Soft cyan pool under a dropped drive; ejected-drive arc; green flood when Exit Open | survivor-objectives V/A; §4 |
| ASSET-087 | World progress ring | World-space ring or bar over objects for hold interactions (install, hide, barricade, rescue), in the HUD style. hud.md owns its colour | survivor-objectives V/A; downing-and-rescue V/A |

**Status:** ASSET-078..086 Done (81ef3ee, 2a8ba44); ASSET-087 Needed (only the screen-space hold ring exists). See `design/assets/asset-manifest.md`.
