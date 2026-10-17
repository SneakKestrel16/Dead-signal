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

Pick: E, the failed experiment (designer 2026-10-17: "that can add more variety when we do other maps"), with
"the models are still bad". Art bible §5 rewritten to it. Next: a real human base mesh (anatomy, not primitives)
deformed into the experiment, instead of more primitive tuning.

## Round 4 (2026-10-17): E on a MakeHuman base

`tools/art/build_experiment.py` drops the script primitives for a real human base mesh: MakeHuman's (MPFB 2.0.18,
CC0 output; setup in the script's docstring) adult male, starved with its own targets (muscle and weight 0,
hollow cheeks, sunken eyes, long neck, thin limbs). MakeHuman's rig poses it into our T-pose, our rig's joints move
onto MakeHuman's, and the arms stretch 1.3x past the shoulder. Then:

- The jaw is torn open 26° about a hinge under the ears, by moving the mesh (the rig has no jaw bone). The lip line
  and the hinge come from MakeHuman's `lips` and `ears` groups.
- Uneven teeth sit in both jaws, with a dark mouth behind them.
- A halo ring is ray-cast a finger's width off the skull, with six pins into the bone and posts to the shoulders.
- A stapled Y-incision runs from the collarbones to the navel.
- A wrinkle normal map is baked onto MakeHuman's UVs.

Triangles 14,794 / 6,858 / 2,735.

```bash
BLENDER_USER_RESOURCES=tools/art/.cache/blender_user \
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
    --python tools/art/build_experiment.py          # tools/art/review/true_e2.glb; -- --ship to replace
"$G" --path . --resolution 1600x900 --write-movie <tmp>.avi res://tests/manual/character_lineup.tscn -- \
    --shot=tools/art/review/e3_front.png --dist=4.2 \
    --true=res://tools/art/review/true_e2.glb,res://tools/art/review/true_e.glb \
    [--turn=70 | --dark | --anim=Walk --frame=75 | --anim=Crouch_Fwd --frame=75 |
     --dist=2.0 --cam-x=0.62 --cam-y=2.2 --look-y=2.15 --fov=22 --turn=20]   # last: head close-up
```

Renders: `tools/art/review/e3_{front,side,walk,crouch,dark,head,chest}.png` (line-up: survivor C3, shipped form,
round 4, round 3 E).

Known gaps:

- The scalp falls dark under the front-low lineup spots.
- The eyes are closed lids, not the dark sockets art bible §5 asks for.
- The hands curl into claws.

Pick: (open)

Designer, 2026-10-17: "the models still look bad". Asked for a decent base model to build on.

## Round 5 (2026-10-17): the base model, textured and sculpted

The round 4 model is kept as the base, with three layers added, all baked from the subdivided high copy onto
MakeHuman's UVs:

- **Anatomy in the normal map** (`sculpt()`): ribs, sternum, collarbones, spine knobs, a hollow belly under the ribs,
  a puckered groove along the incision.
- **A painted base colour** (`paint()`, `PAINT`): mottled pale grey with yellow blotches and blue-grey veins,
  darkened in the creases by local ambient occlusion. Bruising sits round the eyes, the incision, the halo pins and
  the mouth corners. The cuts are raw red and the sockets black.
- **Sunken eye sockets** (`SOCKET`): the lids pushed 12 mm into the skull. Eye positions come from MakeHuman's eye
  helpers, carried through the T-pose.

Also fixed: the hardware parts had lost their materials at the join, so metal and teeth drew as skin. Metal is now
half-metallic, so it does not read black in dim light. Triangles 14,794 / 6,858 / 2,735.

Renders: `tools/art/review/e4_{front,back,crouch,dark,head,chest}.png`.

Known gaps:

- The veins read partly as cracks.
- The hands curl into claws.
- The scalp falls dark under the lineup's front-low spots.

Pick: (open)

## Round 6 (2026-10-17): the designer's concept

The designer sent a concept image, generated with a free AI image tool:
`design/art/reference/true-form-concept-01.webp`. It shows:

- a near-black, stringy, long-limbed body;
- a pale domed head that is nothing but a mouth of needle teeth;
- small red eyes;
- tendrils off the skull and back;
- shredded strips trailing off the limbs;
- long claws.

This is a creature, not the round-3 E "former staff member", and its red eyes break art bible §5's "no glowing
eyes". Here they are red but not emissive. §5 is rewritten once the designer accepts a model from this concept.

`tools/art/build_creature.py` reuses `build_experiment.py`'s MakeHuman pipeline:

- **Body:** a lean, sinewy macro (muscle 0.8, weight 0) with the human head cut off. The cut is flat 6 cm under the
  head joint, plus the head-weighted chin underside, within 20 cm of the middle so the fingertips survive.
- **Head:** metaball ellipsoids (`HEAD_BLOBS`): dome, brow, snout, cheeks, and a sleeve over the neck's cut. The
  lower jaw is a second metaball, so the open mouth does not fill in, hanging 32°.
- **Teeth:** needles found by rays from inside the mouth.
- **Parts:** a tongue, red eyes, skull tendrils, back tendrils, strips on the forearms and shins, finger and toe
  claws.
- **Bakes:** a normal map and a painted base colour each, for the body (sinew noise) and the head.

Triangles 14,808 / 6,834 / 2,802.

```bash
BLENDER_USER_RESOURCES=tools/art/.cache/blender_user "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup     --python tools/art/build_creature.py          # tools/art/review/true_creature.glb; -- --ship to replace
```

Renders: `tools/art/review/c7_{front,side,head,crouch,walk,dark}.png` (line-up: survivor C3, shipped form, this,
round 5).

Gaps against the concept:

- The body reads grey-green under the lineup spots, not near-black.
- The torso and arms lack the concept's muscle definition.
- The limb strips and back tendrils are too small to read.
- The claws hide in the clips' clenched fists.
- A ledge shows where the head's neck sleeve meets the neck.

Pick: (open)

## Round 7 (2026-10-17): more detail, closer to the concept

Designer, 2026-10-17: "add more detail and make it most like the concept art". Changes in `tools/art/build_creature.py`:

- **Head:** longer and bigger. A crest swells out behind the dome, the snout runs further forward, and the jaw hangs
  at 40° (was 32°). There are 22 teeth per jaw (was 16), 3-7.5 cm long. Three mouth strands per side, and a longer
  tongue.
- **Mane:** 24 skull tendrils spread over the back half of the skull and swept back, every seventh one raw red.
  Round 6 had 12 in one clump.
- **Back:** 16 tendrils off the shoulders and upper back, 30-50 cm long. Round 6 had 6 at about 25 cm.
- **Strips:** five per bone on the upper arms, forearms, thighs and shins, 14-26 cm long. Round 6 had three per
  bone, forearms and shins only.
- **Hands:** the source clips' finger curls are dropped, so the fingers hang open. Claws are 11 cm (thumb 8 cm).
- **Torso:** ribs slant down the flanks, and abs with a centre line, in the normal map. The sinew noise is shallower
  (2.4 mm, was 3.5 mm in an intermediate pass).
- **Colour:** darker body paint (sRGB 26-34 base, 54-66 sheen), clearcoat 0.15 (was 0.4). The head's paint runs
  dark down the neck sleeve, which hides the ledge.
- **Neck:** MakeHuman's neck-lengthening targets are dropped.

Triangles 14,896 / 6,729 / 2,630.

Renders: `tools/art/review/c8_{front,side,head,crouch,walk,dark}.png` (line-up: survivor C3, shipped form, this).
Round 6's GLB was overwritten by this build; its renders `c7_*.png` remain.

Gaps against the concept:

- The head is still smoother and more rounded than the concept's bony, ridged dome.
- The pale jaw-hinge bulb sits low on the neck.
- The strips are tubes, not flat torn ribbons.
- The body reads dark grey-green, not the concept's blue-black.

Pick: (open)

## Round 8 (2026-10-17): head and body detail

Designer, 2026-10-17: "its gonna need more detail on the head and body, use more complex shapes if needed".

Head (`sculpt_head`, displaced on the high copy before decimation, so the bigger forms also reach the silhouette;
`HEAD_TRIS` 3600, was 2600):

- Fluting fans back over the dome, with a crest down the middle.
- Brow ridges and cheekbone ridges.
- Sunken eye sockets with the red eyes set in them, and nostril slits on the snout.
- Folds over the jaw hinge.
- The grooves are painted darker (`crease`, from the relief, not the noise), so they read under flat light.
- An inner row of 14 shorter teeth behind the 22 front teeth, with swollen red gums along each jaw.
- The pale jaw-hinge bulb is smaller.

Body:

- The limb strips are flat torn ribbons (`ribbon`) that narrow raggedly and twist, six per limb bone (round 7 had
  five round tubes).
- A ridge of nine vertebra spurs runs down the back, and two bone spikes stick out of each elbow.
- Raised cords spiral down every limb bone, for the concept's stringy limbs.
- Pecs with a crease under them; the ribs stay on the flanks, so the chest no longer looks corrugated.
- The body paint is bluer (sRGB 22-34 base, 46-66 sheen).

Triangles 14,930 / 6,741 / 2,626.

Renders: `tools/art/review/c9_{front,side,back,body,head,headf,walk,crouch,dark}.png` (line-up: survivor C3,
shipped form, round 8, round 7).

Gaps against the concept:

- The belly still shows faint horizontal lines where the concept has clean abs.
- The dome's fluting shows from the side and back, but from the front the dome reads smooth.
- The neck is thinner than the concept's.

Pick: shipped as a placeholder. Designer, 2026-10-17: "its still bad but just continue with it and fix it later".
`build_creature.py -- --ship` wrote `assets/art/characters/shapeshifter/char_shapeshifter_true.glb`. The full suite
passed (1731/1731). Evidence: `production/qa/evidence/true-form-round8-shipped-2026-10-17.png`. The model needs a
later quality pass: the designer still rates it bad, on top of the gaps listed above.

