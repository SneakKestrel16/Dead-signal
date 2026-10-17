# Shapeshifter true form: review

Designer review of the in-round art pass, 2026-10-17: "the characters look okay and the facility can get more
detail but the monster can be improved a lot." This page holds the true-form options and the designer's pick.

## Round 1 (2026-10-17)

Every option keeps the art bible §5 true-form limits: 2.4 m, over-long arms, narrow trunk, wet near-black skin
with clearcoat, bone-white focal points, no emissive eyes, the same rig and clips. They differ in silhouette:

| Option | Limbs | Head | Body |
|---|---|---|---|
| now | as the survivor rig, stretched | smooth, a short teeth row | six small chest ribs, five back spikes, finger claws |
| A, ribcage | thinned to 62 % radius | a curtain of long upper and lower teeth | an open rib cage round the sides, sternum, collarbones, spine knobs |
| B, hunter | thinned to 55 % | the face pulled 1.7x forward into a long skull, bone cap, snout teeth | sickle claws (22 cm), elbow spurs, shoulder and spine spikes |
| C, split maw | thinned to 70 % | a vertical toothed slit top to bottom | a chest maw of rib-teeth closing over the sternum, shoulder plates, spine ridge |

Build and look (review output in `tools/art/review/`, gitignored):

```bash
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
    --python tools/art/build_characters.py -- --true-options
"$G" --headless --path . --import
"$G" --path . --resolution 1600x800 --write-movie <tmp>.avi res://tests/manual/character_lineup.tscn -- \
    --shot=tools/art/review/front.png --dist=4.2 \
    --true=res://tools/art/review/true_a.glb,res://tools/art/review/true_b.glb,res://tools/art/review/true_c.glb \
    [--turn=60 | --dark | --anim=Crouch_Fwd --frame=75]
```

Line-up left to right: survivor C3 for scale, now, A, B, C. Triangles (LOD0 / LOD1 / LOD2): A 14,943 / 6,859 /
2,919; B 14,111 / 6,859 / 2,923; C 14,407 / 6,859 / 2,921 (budget 15k / 7k / 3k).

Not changed in any option, and the next layer whichever ships: the skin is still one smooth glossy material over
the survivor mannequin's muscles (no wrinkles, veins or wet variation), so up close every option reads partly as
a black mannequin. A skin texture set (normal and roughness detail) is the follow-up.

Pick: (open)
