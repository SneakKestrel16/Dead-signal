# Manual test cases: SD-11 shock presentation per form, cosmetic flashlight

**Story**: `production/epics/survivor-defense/story-011-per-form-presentation.md` | **Type**: Visual/Feel | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/per-form-presentation-evidence.md` (captures 01-07, sign-off open)
**Tester**: designer with headphones, Git Bash at the repo root, `G` set as in `client-round-scene-cases.md`. Run without `--write-movie` so the placeholder beeps are heard.

## Already automated

- Survivor shock and disguised hit equal once position is removed: `test_survivor_shock_and_disguised_hit_look_and_sound_the_same`.
- `test_true_form_stun_plays_the_pain_cry_stagger_and_arc`, `test_resisted_true_form_hit_plays_the_spark_and_fizz_only`.
- `test_disguised_monster_toggles_a_cosmetic_cone_hidden_in_true_form`. Reduced flash and reduced motion: unit tests.

Host for each case: `"$G" --headless --path . -s res://tests/manual/round_host.gd -- --port=<p> --players=5`.

---

## Test Case: SD11-01: A shocked survivor and a shocked disguise look and sound the same

**Preconditions**: Run r1 on port 30271: `"$G" --path . res://tests/manual/round_view.tscn --windowed -- --port=30271 --count=5 --view=survivor --bot=stage --stun=survivor`. Run r2 on port 30272: the same with `--disguise --stun`.

**Steps**:
1. In r1, watch and listen to the shocked survivor: the arc, the stagger and the beeps.
2. In r2, watch and listen to the shocked disguised copy.
3. Compare the two `CUE` sets in the console.

**Expected Result**: Both show the same blue arc and tilt and play the same beeps (`shocked_grunt` plus `taser_crackle`). Neither plays `pain_cry`. An observer could not tell which one was the monster.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: SD11-02: A true-form stun, then a resisted hit

**Preconditions**: Port 30273: `... --port=30273 --count=5 --view=survivor --bot=stage --stun --twice`

**Steps**:
1. At the first hit, watch the red body and listen.
2. About 3 s later, at the second hit, watch and listen again.

**Expected Result**: First hit: the arc, the stagger, and `pain_cry` plus `taser_crackle`. Second hit: only a small orange spark and `taser_fizz`, with no stagger and no arc.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: SD11-03: A disguised monster shows a flashlight cone like a survivor's

**Preconditions**: Port 30274: `... --port=30274 --count=5 --view=survivor --bot=stage --disguise --monster-light`

**Steps**:
1. After the disguise, compare the copy's cone with a real survivor's cone. If needed, rerun with `--light` and look at your own cone.

**Expected Result**: The copy casts a cone of the same shape, colour and brightness as a survivor's. The true form never shows one.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: SD11-04: The own shock shows the blue edge and the jitter

**Preconditions**: Port 30275: `... --port=30275 --count=5 --view=survivor --bot=stage --stun=me`

**Steps**:
1. When a line survivor fires at the shown client, watch the screen edge and the camera.

**Expected Result**: A blue screen edge and the crackle play. The camera jitters and then settles.
**Actual Result**:
**Pass/Fail**:
