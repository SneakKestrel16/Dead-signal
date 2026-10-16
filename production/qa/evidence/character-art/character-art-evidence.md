# Character art evidence (ASSET-001..010)

Spec: `design/assets/specs/characters-assets.md`; art bible §3, §5, §8; AD-248. Godot 4.7.2, Forward+, Windows,
captured 2026-10-15 with `--write-movie` (fixed 60 fps).

## Line-up (`tests/manual/character_lineup.tscn`)

`<godot> --path . --resolution 1600x800 --write-movie <tmp>.avi res://tests/manual/character_lineup.tscn -- --shot=<png> --dist=3.4 [args]`

Order left to right: C1, C2, C3, C3 again (what a disguise copying C3 draws), C4, C5, true form. One Bone
Flashlight spot (`#F2E6C8`) per body.

| PNG | Args | Shows |
|-----|------|-------|
| `lineup_front.png` | (none) | Idle, front: suit tint, accessory, stripe (bar, two bars, chevron, three dots, sleeve band); the two C3 bodies are identical |
| `lineup_dark.png` | `--dark` | Same, ambient near black: flashlight only |
| `lineup_back.png` | `--turn=180` | Backs: backpack, radio cross-strap, hood, true-form back spikes |
| `lineup_walk.png` | `--anim=Walk --frame=75` | Walk clip mid-stride |
| `lineup_crouch.png` | `--anim=Crouch_Fwd --frame=75` | Crouch-walk clip; true form crouched with claws |

## In a round (`tests/manual/round_view.tscn`, against `round_host.gd --players=5`, ports 30415-30417)

`round_view.tscn -- --count=5 --view=survivor --bot=stage --light [--disguise] --shots=<dir> --shot-at=<n>`

| PNG | Shows |
|-----|-------|
| `round_trueform.png` | Staged line in the greybox: three survivors and the shapeshifter's true form (2.4 m, long arms, ribs) |
| `round_disguise.png` | After `--disguise`: the shapeshifter wears C3 and is drawn exactly as the real C3 beside it (LB-6) |
| `round_warp.png` | Mid-Transforming: the greybox capsule with the TransformPresenter warp stands in for the art (deviation, see below) |

## Notes

- Tri counts: survivor LOD0 13,831 / LOD1 6,859 / LOD2 2,939; accessories 328 / 84 / 372 / 104 / 148; true form
  LOD0 14,185 / LOD1 6,859 / LOD2 2,930 (budget 15k / 7k / 3k, accessories <= 2k).
- While a body is Transforming the art hides and the capsule with the warp overlay shows; moving the overlay onto
  the art meshes is open work.
- Known: windowed round_view exits with "10 ObjectDB instances were leaked at exit" with and without the art (A/B
  on port 30418), so it predates this change.

## Sign-off

- [ ] art-director: looks C1-C5 and true form read as specified
- [ ] lead-programmer: BodyVisual hook in `round_client.gd`
