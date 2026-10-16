"""Zone beds (family `ambience`): amb_a labs, amb_b server rooms, amb_c security, amb_link service corridors.

Each bed is a 12 s seamless loop cut from real CC0 recordings (sources/ambience.toml: room tone, fluorescent
hum, server room, HVAC, air vents), never from oscillators. A layer is the steadiest 17.5 s stretch of a
recording (no knocks), looped at a seam where the overrun correlates best with the head (so a hum meets itself
in phase), band-limited and de-lined (lasting lines capped at 10 dB over their neighbours), de-clicked (HF ticks pulled to the running median) as a circle, levelled to RMS 1, then mixed at its gain. The shipped bed is option A of
OPTIONS; B and C are the other candidates for the review page (tools/audio/review/ambience/).
"""
from functools import partial

import numpy as np

from lib import dsp
from lib.master import Sound

LEN = 12.0  # loop seconds
OV = 1.5  # seam crossfade seconds
PAD = 2.0  # extra recording at the end for the seam search

# (recording id, gain dB, high-pass Hz, low-pass Hz) per layer. Inference: which recording suits which zone is
# judged from the descriptions and spectrograms; what settles it is the designer's ear on the review page.
OPTIONS = {
    "amb_a": [
        [(451918, 0, 60, 9000), (870708, -12, 150, 6000)],
        [(870708, 0, 100, 7000), (119910, -10, 300, 8000)],
        [(451918, 0, 50, 8000), (119910, -6, 200, 7000), (870708, -16, 120, 5000)],
    ],
    "amb_b": [
        [(776267, 0, 40, 9000)],
        [(536529, 0, 40, 9000), (637377, -8, 100, 6000)],
        [(637377, 0, 150, 7000), (776267, -4, 40, 5000)],
    ],
    "amb_c": [
        [(144046, 0, 35, 9000)],
        [(744447, 0, 40, 9000), (144046, -9, 60, 3000)],
        [(144046, 0, 60, 3500), (744447, -3, 40, 8000)],
    ],
    "amb_link": [
        [(864882, 0, 35, 2500)],
        [(339322, 0, 60, 6000)],
        [(864882, -2, 35, 1800), (339322, -3, 150, 7000)],
    ],
}
EVENT_OF = {"amb_a": "ambience/A", "amb_b": "ambience/B", "amb_c": "ambience/C", "amb_link": "ambience/link"}


def _layer(sid, hp, lp):
    x = dsp.recording(sid)
    span = LEN + OV + PAD
    s = dsp.steady_start(x, span)
    y = dsp.loop_aligned(x[s:s + dsp.samples(span)], LEN, OV)
    t = dsp.declick(dsp.deline(dsp.lowpass(dsp.highpass(np.tile(y, 3), hp), lp)))[len(y):2 * len(y)]  # filtered as a circle
    return t / (np.sqrt(np.mean(t ** 2)) + 1e-12)


def _build(layers, rng):
    return sum(_layer(sid, hp, lp) * 10 ** (g / 20) for sid, g, hp, lp in layers)


def option(name, i):
    return Sound(name if i == 0 else f"{name}_{'abc'[i]}", partial(_build, OPTIONS[name][i]), "ambience", -30.0,
                 ((EVENT_OF[name], 0.0, 1.0),) if i == 0 else (), True)


# What happens in the game when each plays (src/feature zone ambience: the bed of the zone the listener stands in).
PLAYS = {
    "amb_a": "Loops under the whole of zone A (labs, tile floor) from round start; quiet room under every footstep and cue, the stinger rides 6 dB over it.",
    "amb_b": "Loops under zone B (server rooms, metal grate) when the listener walks in; crossfades with the neighbouring zone's bed.",
    "amb_c": "Loops under zone C (security) and the objective rooms; the bed the shapeshifter's disguise scenes are heard against.",
    "amb_link": "Loops in the service corridors that link the zones: the quietest, most exposed bed; footsteps carry furthest here.",
}

SOUNDS = [option(n, 0) for n in OPTIONS]
# Review-page candidates: A is the shipped bed, `<name>_b` and `<name>_c` are the others (not shipped).
CANDIDATES = {n: [option(n, i) for i in range(3)] for n in OPTIONS}
