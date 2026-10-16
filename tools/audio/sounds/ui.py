"""UI sounds (family `ui`) on real CC0 recordings (sources/ui.toml): a subtle menu click and the soft local tick of a
ping the server refused as too fast. Short ticks cut from a mouse button, a pen and a small relay; three candidates
each, A ships (tools/audio/review/ui/)."""
from functools import partial

import numpy as np

from lib import dsp
from lib.master import Sound
from sounds.scares import cut, mix


def ui_click(v, rng):
    """A subtle menu click: a mouse button, soft."""
    if v == 0:
        x = cut(213004, 1.03, 0.07, 1.0, lp=6000)
    elif v == 1:
        x = cut(678248, 0.37, 0.07, 1.0, hp=300, lp=7000)
    else:  # a pen's click, lower and rounder
        x = cut(323746, 0.0, 0.07, 0.8, lp=5000)
    return x


def ping_rejected(v, rng):
    """A soft local tick for a ping refused as too fast: small, dry, no pitch."""
    if v == 0:
        return cut(323746, 0.0, 0.08, 1.0, lp=4500)
    if v == 1:
        return cut(740253, 0.08, 0.08, 1.0, lp=5000)
    return mix(0.2, (cut(213004, 1.03, 0.05, 1.0, lp=3500), 0.0, 0), (cut(213004, 1.03, 0.05, 1.0, lp=3500), 0.08, -5))


BUILDERS = {"ui_click": (ui_click, "ui/click"), "ping_rejected": (ping_rejected, "ping/rejected")}


# Short ticks measure quiet (a clip under 400 ms counts as padded with silence) and hit the -1 dBFS ceiling before the
# family's -26 LUFS; the handoff's table puts UI played most at -28 to -30. Inference: set from the export's peak-limited lines.
LEVEL = {"ui_click": -29.5, "ping_rejected": -29.0}


def _build(fn, v, rng):
    return fn(v, rng)


def option(name, i):
    fn, event = BUILDERS[name]
    return Sound(name if i == 0 else f"{name}_{'abc'[i]}", partial(_build, fn, i), "ui", LEVEL[name],
                 ((event, 0.0, 1.0),) if i == 0 else ())


PLAYS = {
    "ui_click": "Plays on every menu button press, quietly.",
    "ping_rejected": "Plays on the pinger's own client only, when a ping is refused as too fast.",
}
SOUNDS = [option(n, 0) for n in BUILDERS]
CANDIDATES = {n: [option(n, i) for i in range(3)] for n in BUILDERS}
