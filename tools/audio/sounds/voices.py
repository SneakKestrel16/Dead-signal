"""Survivor callouts and grunts, true-form pain cry (placeholder, family `voice`)."""
from sounds._legacy import legacy

CHARS = [1, 2, 3, 4, 5]

SOUNDS = []
for k in CHARS:
    SOUNDS.append(legacy("voice", "callout_c%d" % k, [("callout/voice_c%d" % k, 0.0, 1.0)]))
    SOUNDS.append(legacy("voice", "grunt_c%d" % k, [("voice_c%d.shocked_grunt" % k, 0.0, 1.0)]))
SOUNDS.append(legacy("voice", "pain_cry_true_form", [("voice_c0.pain_cry", 0.0, 1.0)]))
