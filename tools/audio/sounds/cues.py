"""Monster, shock, hiding and objective cues (placeholder, family `cue`)."""
from sounds._legacy import legacy

SOUNDS = [legacy("cue", n, [(n, 0.0, 1.0)]) for n in
          ["lunge_cue", "lunge_scrape", "lunge_hit", "taser_crackle", "taser_fizz", "hide_cue", "distortion"]]
SOUNDS += [
    legacy("cue", "fuse_install", [("fuse_install", 4.0, 1.0)]),  # loudest cue
    legacy("cue", "hide_enter", [("hide_enter", -4.0, 1.0)]),
    legacy("cue", "hide_exit", [("hide_exit", -4.0, 1.0)]),
]
