"""Footsteps (family `foot`): step_tile, step_concrete, step_metal, step_rubber, step_true_form.

Event ids `c<appearance>@<surface>` play one surface sound per survivor at that survivor's pitch (a disguise
plays the copied survivor's id, so it matches exactly); `c0` is the true form. Ids, bus, gait dB and pitches
are the sound bank's (data/audio/sound_bank.tres) and do not change here.

Every step is cut from real recordings of feet (sources/steps.toml: boots on tile, a road, a garage floor and a
metal grate, rubber soles, a dog's claws, a bear), never from oscillators. A step is mostly scrape, the sole over
grit (pipeline-handoff Part 1), so each candidate is layers: the footfall of a recorded step plus, where the
direction asks for it, a scrape or scuff that arrives a few ms ahead of it. Each layer is one recorded step per
take (the onset times below were read off the recordings with the onset and region analysis), cut 3 ms ahead of
its rise, band-limited, varispeeded by a few percent and mixed at its gain. A sound has VARIANTS takes, each on
different recorded steps and its own small rate and gain jitter, and the bank plays them through an
AudioStreamRandomizer (no repeat in a row) so a corridor of steps does not machine-gun. The shipped sound is
option A of OPTIONS; B and C are the other candidates for the review page (tools/audio/review/steps/).
"""
import math
from dataclasses import replace
from functools import partial

import numpy as np
from scipy import signal

from lib import dsp
from lib.master import FAMILIES, Sound

CHARS = [1, 2, 3, 4, 5]
# Per-survivor footstep/voice pitch (CharacterDef order). Inference: no GDD gives voices; five steps apart
# by ~6 % so each set is told apart by ear.
CHAR_PITCH = {1: 1.0, 2: 0.93, 3: 1.07, 4: 0.87, 5: 1.13}
SURFACES = ["tile", "concrete", "metal", "rubber"]
VARIANTS = 4
DRIVE = 2.6  # tanh saturation with the peak kept (dsp.drive)
TAIL = 0.05  # seconds of fade-out at the end of a cut

# Pools: recording id -> {name: [onset seconds]}. Read off each recording (analyze.py events, the 10 ms level
# regions, and its spectrogram): one footfall, scrape or scuff per time.
POOLS = {
    555868: {  # mountain boots on tile: walk x9, run x13, jump x5, scrape x6, scuff x5
        "walk": [0.0, 1.04, 2.13, 3.18, 4.27, 5.37, 6.39, 7.34, 8.35],
        "scrape": [26.03, 27.00, 28.02, 29.01, 29.91, 30.80],
        "scuff": [33.01, 33.73, 34.56, 35.28, 36.01],
    },
    456428: {"road": [0.89, 1.43, 3.55, 5.13, 6.24, 7.96, 9.07, 10.75]},  # boots on a surfaced road
    465299: {"stomp": [0.42, 0.81, 1.26, 1.68, 2.06, 2.53, 2.94, 3.38, 3.77, 4.19, 5.01, 5.45]},  # big boots, garage
    398937: {"grate": [0.66, 1.25, 1.87, 2.48, 3.11, 3.72, 4.35, 4.98, 5.60, 6.22]},  # hard soles on a metal grate
    834029: {"structure": [0.61, 1.12, 1.62, 2.20, 2.70, 3.28, 3.77, 4.43, 5.00]},  # single steps on a metal structure
    786977: {"plate": [2.15, 2.67, 3.15, 4.26, 5.36, 6.46]},  # running on a metal plate
    335760: {"mat": [0.14, 0.73, 1.43, 1.98, 2.78, 3.51, 4.11]},  # moist shoes on a rubber carpet
    613723: {"sole": [0.98, 1.41, 1.66, 4.73, 10.38, 12.25, 13.11]},  # quiet rubber shoes on a hard floor
    635117: {"claw": [0.62, 2.25, 3.10, 3.42, 4.26, 6.41, 6.86]},  # dog claws on hardwood
    199919: {"skitter": [2.70, 6.97, 16.09, 18.49, 20.49, 20.79, 22.22]},  # medium dog on bare wood
    519600: {"paw": [7.00, 7.49, 8.06, 9.10, 9.23]},  # grizzly running past
    834027: {"tile": [0.02, 0.91, 1.84, 2.75, 3.67, 4.59, 5.52]},  # boots on tile, shotgun mic (round 2)
    349865: {"heavy": [2.25, 2.81, 3.84, 4.88, 5.86, 6.45, 7.53, 8.09, 8.67, 9.77, 10.90, 11.93, 13.15]},  # heavy boots on tile (round 2)
}

# A layer: (recording id, pool, gain dB, varispeed, high-pass Hz, low-pass Hz, seconds, offset ms from the layer
# before it: negative = ahead of the footfall). Inference: which recording suits which floor and direction is
# judged from descriptions and spectrograms; what settles it is the designer's ear on the review page.
OPTIONS = {
    "step_tile": [
        # A: the recorded boot, nothing else
        [(555868, "walk", 0, 1.0, 90, 9500, 0.26, 0)],
        # B: scrape first: the sole drags in, the footfall is soft under it
        [(555868, "walk", -7, 1.0, 250, 8000, 0.26, 0), (555868, "scrape", -1, 1.08, 450, 11000, 0.22, -35)],
        # C: heavier and duller (slowed 12 %), a scuff trailing the heel
        [(555868, "walk", 0, 0.88, 60, 5200, 0.30, 0), (555868, "scuff", -9, 0.9, 300, 7500, 0.16, 60)],
    ],
    "step_concrete": [
        # A: boots on a road, gritty and open
        [(456428, "road", 0, 1.0, 100, 8500, 0.24, 0)],
        # B: big boots stomping a garage floor: more weight
        [(465299, "stomp", 0, 1.0, 70, 7000, 0.24, 0)],
        # C: stomp slowed a little, a tile scrape for grit under the sole
        [(465299, "stomp", -4, 0.92, 100, 5200, 0.26, 0), (555868, "scrape", -9, 0.8, 600, 9500, 0.20, -25)],
    ],
    "step_metal": [
        # A: hard soles on a grate
        [(398937, "grate", 0, 1.0, 120, 9500, 0.26, 0)],
        # B: the grate step over the structure's own step: more ring and rattle
        [(398937, "grate", -3, 1.0, 120, 8500, 0.26, 0), (834029, "structure", -4, 1.0, 400, 10000, 0.24, 3)],
        # C: a rattling plate, slowed to a walk, over the grate's low knock
        [(786977, "plate", 0, 0.8, 150, 9000, 0.28, 0), (398937, "grate", -8, 0.9, 80, 3500, 0.24, 0)],
    ],
    "step_rubber": [
        # A: shoes on a rubber carpet
        [(335760, "mat", 0, 1.0, 80, 8000, 0.24, 0)],
        # B: that, over a quiet rubber sole
        [(335760, "mat", -2, 1.0, 100, 7500, 0.24, 0), (613723, "sole", -3, 1.0, 120, 6000, 0.22, -8)],
        # C: a boot step muffled to what a mat leaves of it, under the rubber carpet's squelch
        [(555868, "walk", 0, 0.95, 60, 1800, 0.22, 0), (335760, "mat", -5, 1.0, 250, 6500, 0.20, -6)],
    ],
    "step_true_form": [
        # A: a dog's claws slowed to a heavy animal, a boot stomp slowed to its weight
        [(635117, "claw", 0, 0.62, 120, 7000, 0.36, 0), (465299, "stomp", -3, 0.55, 40, 420, 0.34, -10)],
        # B: a bear's pad slowed a fifth, claws skittering under it
        [(519600, "paw", 0, 0.8, 90, 6500, 0.38, 0), (199919, "skitter", -5, 0.7, 400, 7500, 0.30, 15)],
        # C: a giant's stomp (half speed, dull), claw scrabble at half speed over it
        [(465299, "stomp", 0, 0.5, 35, 900, 0.40, 0), (635117, "claw", -3, 0.5, 200, 5000, 0.36, 20)],
    ],
}
EVENT_OF = {
    "step_tile": [("c%d@tile" % k, 0.0, CHAR_PITCH[k]) for k in CHARS],
    "step_concrete": [("c%d@concrete" % k, 0.0, CHAR_PITCH[k]) for k in CHARS],
    "step_metal": [("c%d@metal" % k, 0.0, CHAR_PITCH[k]) for k in CHARS],
    "step_rubber": [("c%d@rubber" % k, 0.0, CHAR_PITCH[k]) for k in CHARS],
    "step_true_form": [("c0", 0.0, 1.0)],
}


def _onset(x, t):
    """Sample of the rise of the event near `t`: the first 1 ms frame within 22 dB of the loudest one in
    [t - 30 ms, t + 70 ms] (found by the rise, not by a level: a faint scuff ahead of the foot must not start the cut)."""
    f = dsp.samples(0.001)
    a = max(0, dsp.samples(t - 0.03))
    seg = x[a:a + dsp.samples(0.1)]
    n = len(seg) // f
    db = 10 * np.log10(np.mean(seg[: n * f].reshape(n, f) ** 2, axis=1) + 1e-12)
    return a + int(np.argmax(db > db.max() - 22.0)) * f


def _pick(times, k, v):
    """The time of take v, layer k: a stride coprime with the pool size, so no take repeats a step until the pool runs out."""
    n = len(times)
    stride = next(s for s in (2, 3, 5, 7, 11) if math.gcd(s, n) == 1)
    return times[(3 * k + v * stride) % n]


def _layer(sid, pool, gain, rate, hp, lp, length, k, v, rng):
    """One recorded step of `pool`, as a float array peaking at `gain` dB under 1 (+- 1.2 dB per take)."""
    x = dsp.recording(sid)
    r = rate * (1 + 0.03 * rng.uniform(-1, 1))  # a few percent of varispeed per take
    i = max(0, _onset(x, _pick(POOLS[sid][pool], k, v)) - dsp.samples(0.003))  # the cut rises into the event
    seg = x[i: i + dsp.samples(length * r)]
    if abs(r - 1) > 1e-3:
        seg = signal.resample_poly(seg, 1000, round(1000 * r))
    seg = dsp.lowpass(dsp.highpass(seg - np.mean(seg), hp), lp)
    m = dsp.samples(TAIL)
    seg[-m:] *= np.linspace(1.0, 0.0, m)
    return dsp.norm(seg) * 10 ** ((gain + rng.uniform(-1.2, 1.2)) / 20)


def _untone(x, over_db=6.0):
    """A recording's ringing line (the wood under a claw, a hum under a mat) is a note in a dry take: cut every line
    standing over_db over its neighbourhood in the take's own long-term spectrum (the measure analyze.py uses),
    by peaking cuts a few Hz wide, three passes."""
    for _ in range(3):
        f, _, sp = signal.spectrogram(x, dsp.SR, nperseg=8192, noverlap=4096)
        ls = np.median(10 * np.log10(sp + 1e-20), axis=1)
        prom = ls - signal.medfilt(ls, 41)
        for i in signal.find_peaks(prom, height=over_db, distance=3)[0]:
            if 60 < f[i] < 17000 and ls[i] > ls.max() - 50:
                x = dsp.eq(x, "peak", f[i], min(60.0, max(8.0, f[i] / 25)), -(prom[i] - over_db + 4))
    return x


def _build(layers, rng, v):
    out = np.zeros(dsp.samples(1.6))
    for k, (sid, pool, gain, rate, hp, lp, length, off) in enumerate(layers):
        dsp.place(out, _layer(sid, pool, gain, rate, hp, lp, length, k, v, rng), 0.3 + off / 1000.0)  # master trims the lead
    live = np.nonzero(np.abs(out) > 1e-4 * np.max(np.abs(out)))[0]  # the take itself, not the silence round it
    out[live[0]:live[-1] + 1] = _untone(out[live[0]:live[-1] + 1])
    return dsp.drive(out, DRIVE)  # a footfall is a spike over a body: lift the body so the take reaches its level under the ceiling


def option(name, i):
    return Sound(name if i == 0 else f"{name}_{'abc'[i]}", partial(_build, OPTIONS[name][i]), "foot", FAMILIES["foot"][0],
                 tuple(EVENT_OF[name]) if i == 0 else (), variants=VARIANTS)


# What happens in the game when each plays (a footstep plays at the walker's feet on the floor of their zone).
PLAYS = {
    "step_tile": "A survivor's boot step on the tile floor of zone A (labs); one of 4 takes, never the same twice in a row, at that survivor's pitch.",
    "step_concrete": "A survivor's boot step on the concrete of zone C (security) and of the service corridors that link the zones.",
    "step_metal": "A survivor's boot step on the checker-plate grating of zone B (server rooms).",
    "step_rubber": "A survivor's step on rubber matting.",
    "step_true_form": "The shapeshifter's step in its true form (event c0): a heavy clawed animal, the one footstep that is never a boot.",
}

SOUNDS = [option(n, 0) for n in OPTIONS]
# Review-page candidates: A is the shipped sound, `<name>_b` and `<name>_c` are the others (not shipped).
CANDIDATES = {n: [option(n, i) for i in range(3)] for n in OPTIONS}


# Round 2 (docs/audio/picks.md: no pick and no note on step_tile, so three new directions on new tile recordings).
ROUND2_OPTIONS = {
    "step_tile": [
        # D: boots on tile, a cleaner close recording, nothing else
        [(834027, "tile", 0, 1.0, 80, 10000, 0.24, 0)],
        # E: heavy boots on tile, more weight and a harder heel
        [(349865, "heavy", 0, 1.0, 70, 9000, 0.24, 0)],
        # F: D with the first recording's scrape just ahead of it: grit under the sole
        [(834027, "tile", 0, 1.0, 80, 10000, 0.24, 0), (555868, "scrape", -10, 1.05, 500, 10000, 0.18, -30)],
    ],
}
ROUND2 = {n: [replace(option(n, 0), name=f"{n}_{l}", build=partial(_build, layers), ids=()) for l, layers in zip("def", opts)]
          for n, opts in ROUND2_OPTIONS.items()}
