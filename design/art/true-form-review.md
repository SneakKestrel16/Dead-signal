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

Pick: none. Designer, 2026-10-17: "can you do a better model for the monster" (all four still read as the
mannequin).

## Round 2 (2026-10-17): option D, a new body

`tools/art/build_true_form.py` builds the body from scratch instead of reshaping the survivor mannequin: tubes
grown along the rig's DEF bones (Blender skin modifier: starved shafts, knobbed elbows and knees, narrow pelvis,
starved waist, deep narrow chest), a long eyeless skull with brow ridges and a hanging jaw, ribs and vertebrae
pressing through the skin, shoulder blades, all voxel-remeshed into one surface with flesh noise. That high mesh
(about 105k faces) bakes a 1024 normal map onto the 15k LOD0. Bone white only on the teeth, finger and toe claws
and the spine tips between the shoulder blades. Same rig and clips; weights by distance to the DEF bones
(Blender's bone-heat weighting failed silently on this mesh).

```bash
# tools/art/review/true_d.glb; add -- --ship to replace the shipped one
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
    --python tools/art/build_true_form.py
"$G" --path . --resolution 1600x800 --write-movie <tmp>.avi res://tests/manual/character_lineup.tscn -- \
    --shot=tools/art/review/d_front.png --dist=6.5 --true=res://tools/art/review/true_d.glb \
    [--turn=70 | --dark | --anim=Walk --frame=75 | --anim=Crouch_Fwd --frame=75]
```

Triangles 14,693 / 6,853 / 2,933. Line-up: survivor C3, shipped form, D.

Pick: (open)

## Round 3 (2026-10-17): one concept per creature direction

The designer asked what the monster is; no design document says (the brief and Borrowed Face define what it
does, not what it is). Three directions were offered and the designer asked for "one for all three". Same
pipeline as D (`build_true_form.py -- --all`, or `-- --concept=e|f|g`), each its own `CONCEPTS` entry:

| Concept | Direction | Look |
|---|---|---|
| E | Failed experiment: a former staff member | Pale clammy grey skin, a human skull and face, a surgical halo bolted to the skull with posts to the shoulders, an autopsy Y-incision held with staples, a dislocated hanging jaw, split fingertips |
| F | Mimic organism: built to take other shapes | Wet black, a smooth head with only the start of a nose and brow, a toothed seam down the chest, unfinished faces budding from the side and back, a half-grown hand reaching out of the waist |
| G | Something the lab dug up or contained | Stone-grey and craggy, a long skull swept back, a bone antler crown, a long toothed muzzle, a hump and tall bone plates down the spine, long claws |

E and G break the art bible §5 skin rule (near-black, sRGB 40-55) on purpose: E's pale skin is the "it was one of
us" read, G's stone grey the "old thing" read. Whichever direction is picked, the art bible §5 true-form section
is rewritten to it. Triangles: E 14,694, F 14,693, G 14,686 at LOD0 (budget 15k).

Renders: `tools/art/review/efg_{front,side,back,walk,crouch,dark}.png` (line-up: survivor C3, shipped form, E, F,
G).

Pick: (open)
