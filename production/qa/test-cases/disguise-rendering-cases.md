# Manual test cases: BF-9 disguise and true-form rendering

**Story**: `production/epics/borrowed-face/story-009-disguise-rendering.md` | **Type**: Visual/Feel | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/disguise-rendering-evidence.md` (captures 01-03, sign-off open)
**Tester**: designer, Git Bash at the repo root, `G` set as in `client-round-scene-cases.md`.

## Already automated / N/A

- Cue choice by shown appearance: `tests/unit/borrowed-face/disguise_presenter_test.gd`.
- Footstep set copies the target: `test_disguised_walking_monster_sounds_like_its_target_to_remote_clients` (controller-interaction/014).
- Name label: N/A, because no body labels exist. Drive carrier and Downed copy: no items or Downed pose are drawn yet, so nothing can be observed. The evidence page records this as a gap to retest.

---

## Test Case: BF9-01: Two copies of one survivor render identically

**Preconditions**:
1. `"$G" --headless --path . -s res://tests/manual/round_host.gd -- --port=30211 --players=5`
2. `"$G" --path . res://tests/manual/round_view.tscn --windowed -- --port=30211 --count=5 --view=survivor --bot=stage --disguise`

**Steps**:
1. Wait for the line of four bodies 3.5 m ahead and for the second-from-left body (the shapeshifter, red) to change form.
2. Compare the two bodies of the same colour.

**Expected Result**: The shapeshifter becomes the colour of its neighbour. The two copies have the same size, colour and pose, and nothing tells them apart.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: BF9-02: A stunned disguise staggers as the borrowed survivor with that survivor's grunt

**Preconditions**: Host on port 30212. Client: same as BF9-01 plus `--stun`.

**Steps**:
1. After the disguise, the shown client fires its taser at the copy.
2. Watch the copy and the real survivor next to it. Read the console `CUE` lines.

**Expected Result**: The copy tilts in the stagger and the real survivor stays upright. The console prints `CUE voice_c<n>.shocked_grunt`, where `<n>` is the copied survivor, and no `pain_cry`.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: BF9-03: A true-form stun plays the monster stagger and the pain cry, and the true form is readable

**Preconditions**: Host on port 30213. Client: `... --port=30213 --count=5 --view=survivor --bot=stage --stun` (no `--disguise`).

**Steps**:
1. Watch the red body when the taser hits it. Read the `CUE` line.
2. Judge whether the red true form is clearly visible against the floor. The slice REPORT said it was too dark.

**Expected Result**: The red body staggers. The console prints `CUE voice_c0.pain_cry`. The red body reads clearly and is not lost in darkness.
**Actual Result**:
**Pass/Fail**:

Note: the cues are console ids at this story's scope. SD-11's `PlaceholderAudio` adds a beep, but not the final voice.
