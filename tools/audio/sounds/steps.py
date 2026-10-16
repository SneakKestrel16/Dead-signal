"""Footsteps (placeholder, family `foot`). Rebuilt on real recordings in a later batch.

Event ids `c<appearance>@<surface>` play one surface file per survivor at that survivor's pitch (a disguise
plays the copied survivor's id, so it matches exactly); `c0` is the true form.
"""
from sounds._legacy import legacy

CHARS = [1, 2, 3, 4, 5]
# Per-survivor footstep/voice pitch (CharacterDef order). Inference: no GDD gives voices; five steps apart
# by ~6 % so each set is told apart by ear.
CHAR_PITCH = {1: 1.0, 2: 0.93, 3: 1.07, 4: 0.87, 5: 1.13}
SURFACES = ["tile", "concrete", "metal", "rubber"]

SOUNDS = [legacy("foot", "step_" + s, [("c%d@%s" % (k, s), 0.0, CHAR_PITCH[k]) for k in CHARS]) for s in SURFACES]
SOUNDS.append(legacy("foot", "step_true_form", [("c0", 0.0, 1.0)]))
