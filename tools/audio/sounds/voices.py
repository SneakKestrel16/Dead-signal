"""Survivor radio callouts and grunts, true-form pain cry (family `voice`), built on recorded people and animals.

Recordings (sources/voices.toml, all CC0): real speakers, never speech synthesizers. A callout is a stretch of
one speaker with the words taken away (docs/audio/pipeline-handoff.md Part 4, "Voices behind a radio": every
frequency's level smeared over 110-150 ms with the phase kept, so pitch and cadence survive and the words do not;
then compression, a lopsided clip, a sample-rate drop with no anti-alias filter, the band limit, static that
rises into the speaker's pauses, a squelch tick and a closing "kshh", and the band limit again). A grunt is a
recorded person's grunt or gasp matched to the survivor's voice. The pain cry is a recorded scream played along a
designed pitch contour (so the held note is lost) with its formants set apart from its pitch, layered with a
recorded animal.

Per-survivor pitch: the sound bank gives every voice entry pitch_scale 1.0 (only the footstep sets are pitched
per survivor, data/audio/sound_bank.tres), so the voices differ in the files: a different speaker per survivor, and
a speed ratio per set here. Nothing is pitched again in game, so there is no double pitching.

The shipped take is option A of each sound; B and C are the other candidates for the review page
(tools/audio/review/voices/).
"""
from dataclasses import replace
from fractions import Fraction
from functools import partial

import numpy as np
from scipy import signal
from scipy.ndimage import uniform_filter1d

from lib import dsp
from lib.master import Sound

CHARS = [1, 2, 3, 4, 5]
SR = dsp.SR

# ---- the people ------------------------------------------------------------------------------------------
# Callout speakers. Inference: the speakers' sex and pitch are judged from the descriptions and a pitch estimate
# (592595 ~113 Hz, 394631 ~144 Hz, 350442 ~160 Hz, 546065 ~188 Hz, 165348 ~206 Hz); what settles it is the
# designer telling the five apart on the review page. cuts = three (start, end) lists in seconds, one per
# candidate, each joined by a short gap (counted numbers, a phrase): never the same words twice per speaker.
SPEAKER = {
    1: dict(sid=592595, speed=0.95, cuts=[[(28.06, 29.10)], [(36.33, 37.40)], [(47.33, 48.40)]]),  # calm deep man reading
    2: dict(sid=350442, speed=1.08, cuts=[[(8.81, 9.43), (9.89, 10.33)], [(0.77, 1.31), (1.94, 2.28)], [(4.82, 5.42), (5.87, 6.43)]]),  # a man announcing, counting
    3: dict(sid=546065, speed=0.97, cuts=[[(4.12, 5.15)], [(1.78, 2.64)], [(8.03, 8.98)]]),  # an Australian woman counting
    4: dict(sid=165348, speed=1.10, cuts=[[(1.56, 2.66)], [(5.48, 6.58)], [(10.23, 11.33)]]),  # a woman, a wistful line
    5: dict(sid=394631, speed=0.92, cuts=[[(3.00, 4.10)], [(6.10, 7.20)], [(12.00, 13.10)]]),  # a man reading, thin close mic
}
# Grunt events per candidate: (source id, start, end s, pitch ratio, formant ratio). Pitch and formants are set apart
# (handoff Part 4): the pitch goes to ~1.25x the survivor's speech (a shock is higher), the formants stay the size of
# the survivor's throat. Inference: the pitches come from an autocorrelation estimate of each event, which doubles
# on strong second harmonics: unfa's grunts read 160-410 Hz, all taken as ~165 Hz (the cluster of the low readings);
# Kodack's 0.28 s grunt (238 or 119 Hz) is the uncertain one. What settles it is the designer's ear.
GRUNT = {
    1: [(610998, 1.10, 2.32, 0.78, 0.92), (610998, 10.35, 11.35, 0.85, 0.92), (610998, 16.16, 17.58, 0.60, 0.92)],
    2: [(610998, 4.87, 6.13, 1.20, 1.00), (610998, 16.16, 17.58, 1.00, 1.00), (256603, 0.28, 0.89, 0.87, 1.05)],
    3: [(427430, 0.11, 0.52, 0.97, 1.00), (427430, 15.66, 16.22, 1.10, 1.00), (427430, 19.05, 19.57, 0.92, 1.00)],
    4: [(427430, 21.44, 21.78, 1.00, 1.10), (427430, 22.47, 22.91, 1.03, 1.10), (547344, 0.03, 0.49, 1.12, 1.10)],
    5: [(610998, 19.27, 20.47, 0.97, 0.95), (610998, 7.12, 8.50, 1.02, 0.95), (610998, 1.10, 2.32, 0.95, 0.95)],
}


# ---- building blocks (local to this family) ---------------------------------------------------------------
def _fade(x, ms=6.0, tail_ms=None):
    x = x.copy()
    m = min(len(x) // 2, dsp.samples(ms / 1000))
    x[:m] *= np.linspace(0.0, 1.0, m)
    t = min(len(x) // 2, dsp.samples((tail_ms or ms) / 1000))
    x[-t:] *= np.linspace(1.0, 0.0, t) ** 2  # through the halving points: a straight fade to zero is a cliff
    return x


def _join(sid, parts, gap=0.09):
    """Slices (start, end) of a recording joined with `gap` s of silence."""
    out = []
    for a, b in parts:
        out += [_fade(dsp.recording(sid, a, b)), np.zeros(dsp.samples(gap))]
    return np.concatenate(out[:-1])


def vari(x, ratio):
    """Play at `ratio` speed (varispeed): pitch and formants move together."""
    f = Fraction(ratio).limit_denominator(200)
    return signal.resample_poly(x, f.denominator, f.numerator)


def contour(x, seconds, *points):
    """Play x along a speed curve through (seconds, speed) points for `seconds` out (or until x runs out):
    a pitch that leaps and collapses instead of holding, which is what makes a recorded voice a note."""
    up = signal.resample_poly(x, 2, 1)
    n = dsp.samples(seconds)
    pos = np.cumsum(dsp.curve(n, *points)) * 2.0
    pos = pos[pos < len(up) - 1]
    return np.interp(pos, np.arange(len(up)), up)


def formants(x, ratio, nfft=2048, hop=512, lift=90):
    """Move the formants by `ratio` (above 1 up) with pitch and phase untouched (handoff Part 4): each frame's
    cepstral envelope is stretched by `ratio` and applied as a gain."""
    _, _, s = signal.stft(x, SR, nperseg=nfft, noverlap=nfft - hop)
    cep = np.fft.irfft(np.log(np.abs(s) + 1e-9), n=nfft, axis=0)
    cep[lift:nfft - lift + 1] = 0.0
    env = np.exp(np.fft.rfft(cep, axis=0).real)
    src = np.clip(np.arange(env.shape[0]) / ratio, 0, env.shape[0] - 1.001)
    i0 = src.astype(int)
    w = (src - i0)[:, None]
    gain = np.clip((env[i0] * (1 - w) + env[i0 + 1] * w) / env, 0.1, 10.0)
    return signal.istft(s * gain, SR, nperseg=nfft, noverlap=nfft - hop)[1][:len(x)]


def smear(x, ms):
    """Each frequency's level averaged over `ms` (phase kept: pitch and cadence stay, the words go)."""
    _, _, s = signal.stft(x, SR, nperseg=1024, noverlap=768)  # hop 256 = 5.8 ms
    mag = uniform_filter1d(np.abs(s), max(1, round(ms / 1000 * SR / 256)), axis=1)
    return signal.istft(mag * np.exp(1j * np.angle(s)), SR, nperseg=1024, noverlap=768)[1][:len(x)]


def scramble(rng, x, grain_ms):
    """Grains of the speech in a new order, overlapped at half: pitch and syllable length stay, no word survives."""
    g = dsp.samples(grain_ms / 1000) // 2 * 2
    h = g // 2
    win = np.hanning(g + 1)[:-1]
    n = max(1, (len(x) - g) // h)
    order = rng.permutation(n)
    out = np.zeros(h * (n + 1))
    for k, j in enumerate(order):
        out[k * h:k * h + g] += x[j * h:j * h + g] * win
    return out


def radio(rng, x, smear_ms, band, drive, crush, hiss, muffle):
    """The walkie-talkie: see the module docstring. `crush` holds every crush-th sample (no anti-alias filter)."""
    x = dsp.highpass(x, 160)
    x = smear(x, smear_ms)
    x = x / (np.sqrt(np.mean(x ** 2)) + 1e-9)
    x = np.tanh(drive * x + 0.25) - np.tanh(0.25)  # compression, then a lopsided clip
    x = np.repeat(x[::crush], crush)[:len(x)]
    x = dsp.bandpass(x, band[0], band[1], 3)
    x = x / (np.max(np.abs(x)) + 1e-9)
    lead, tail = dsp.samples(0.07), dsp.samples(0.17)
    n = lead + len(x) + tail
    y = np.zeros(n)
    y[lead:lead + len(x)] = x
    env = dsp.lowpass(np.abs(x), 14)
    env = np.clip(env / (np.percentile(env, 95) + 1e-9), 0.0, 1.0)
    gate = np.full(n, 0.35 * hiss)  # static: a floor, rising into the pauses
    gate[lead:lead + len(x)] = hiss * (0.35 + 0.65 * (1.0 - env))
    gate[lead + len(x):] = 0.35 * hiss * np.exp(-np.arange(tail) / dsp.samples(0.05))
    stat = dsp.bandpass(dsp.colored(rng, n, 1.0), band[0], band[1], 2)
    y += gate * stat / (np.std(stat) + 1e-9)
    t = dsp.clock(tail)
    kshh = dsp.highpass(dsp.noise(rng, tail), 1600) * np.exp(-t / 0.032) * (1 - np.exp(-t / 0.003))
    y[lead + len(x):] += 0.55 * kshh / (np.std(kshh) + 1e-9) * 0.35
    tick = dsp.noise(rng, dsp.samples(0.012)) * np.exp(-dsp.clock(dsp.samples(0.012)) / 0.0008)
    y[:len(tick)] += 1.1 * tick / (np.max(np.abs(tick)) + 1e-9) * 0.5  # the squelch opening
    y = dsp.lowpass(dsp.bandpass(y, band[0], band[1], 2), muffle, 3)  # the band again, after the last thing that distorts
    return y


# ---- callouts -----------------------------------------------------------------------------------------------
# (smear ms, band Hz, drive, crush, hiss, muffle Hz) of each direction
RADIO = {
    0: (120, (300, 3000), 2.5, 4, 0.06, 2700),  # A: a walkie-talkie, muffled and gritty
    1: (150, (450, 2200), 5.0, 6, 0.10, 1800),  # B: buried: deeper smear, harder clip, narrower and dull
    2: (60, (300, 3300), 3.0, 4, 0.045, 3000),  # C: mumble: the speech's grains shuffled, lighter chain
}
PER_CHAR_BAND = {1: 0.78, 2: 0.92, 3: 1.05, 4: 1.15, 5: 0.96}  # the set's own radio colour, a few percent either way


def _callout(k, i, rng):
    sp = SPEAKER[k]
    x = vari(_join(sp["sid"], sp["cuts"][i]), sp["speed"])
    sm, band, drv, crush, hiss, muffle = RADIO[i]
    if i == 2:  # a wandering pitch, so no grain holds a note, then the grains in a new order
        t = np.arange(0.0, len(x) / SR + 0.3, 0.12)
        x = contour(x, len(x) / SR, *zip(t, 1 + 0.10 * rng.uniform(-1, 1, len(t))))
        x = scramble(rng, x, 95)
    c = PER_CHAR_BAND[k]
    return radio(rng, x, sm, (band[0] * c, band[1] * c), drv, crush, hiss, muffle * c)


# ---- grunts -------------------------------------------------------------------------------------------------
def _event(sid, a, b, seconds):
    """A recorded grunt from its onset (the first frame within 20 dB of the cut's peak, 3 ms before it)."""
    x = dsp.recording(sid, a, b)
    f = dsp.samples(0.002)
    env = 20 * np.log10(np.sqrt(np.mean(x[:len(x) // f * f].reshape(-1, f) ** 2, axis=1)) + 1e-9)
    on = max(0, int(np.argmax(env > env.max() - 20)) * f - dsp.samples(0.003))
    return x[on:on + dsp.samples(seconds)]


def _shake(rng, x, depth, rate):
    """A body convulsing under a shock: the voice's level tremors at a wandering `rate` Hz."""
    n = len(x)
    r = rate * (1 + 0.18 * dsp.wander(rng, n, 6))
    return x * (1 - depth * (0.5 + 0.5 * np.sin(dsp.phase(r, n) + rng.uniform(0, 6.28))))


def _grunt(k, i, rng):
    sid, a, b, r, form = GRUNT[k][i]
    pts = ((0, 0.90 * r), (0.05, 1.15 * r), (0.16, 1.0 * r), (0.55, 0.70 * r))  # a jolt up, then the voice sags: no held note
    x = contour(_event(sid, a, b, 0.75), 0.55, *pts)
    x = formants(x, form / np.mean([p[1] for p in pts]))  # the throat stays this survivor's size, only the pitch moves
    x = x / (np.max(np.abs(x)) + 1e-9)
    if i == 0:  # A: the recorded grunt, a light tremor
        y = _shake(rng, x, 0.35, 28)
    elif i == 1:  # B: the jolt twice, the second hit short and a touch up, the body shaking hard
        second = vari(x[:dsp.samples(0.22)], 1.06)
        y = np.zeros(len(x) + dsp.samples(0.15))
        y[:len(x)] += _shake(rng, x, 0.6, 35)
        dsp.place(y, 0.7 * _fade(second, 6, 60), 0.15)
    else:  # C: strangled: the throat tight (formants up), driven, the tremor fast
        y = _shake(rng, dsp.drive(formants(x, 1.12), 2.5), 0.45, 44)
    y = _fade(dsp.lowpass(dsp.highpass(y, 90), 7000), 3, 50)
    return y


# ---- the true-form pain cry -----------------------------------------------------------------------------------
def _layer(sid, a, b, seconds, pts, fmt, gain_db=0.0):
    """A recording slice played along a speed contour, formants set by `fmt` against its own (pitch and throat apart)."""
    x = contour(dsp.recording(sid, a, b), seconds, *pts)
    x = formants(x, fmt / np.mean([p[1] for p in pts]))
    return _fade(x / (np.sqrt(np.mean(x ** 2)) + 1e-9), 25, 220) * 10 ** (gain_db / 20)


def _rasp(rng, x, amount):
    """Torn, chattering voice: its level breaks up at a random 50-120 Hz (noise, not a tone), over breath."""
    n = len(x)
    chat = 1 - 0.40 * np.clip(0.5 + 0.9 * dsp.wander(rng, n, 90), 0, 1)
    env = dsp.lowpass(np.abs(x), 30)
    breath = dsp.bandpass(dsp.noise(rng, n), 700, 4500) * env
    return x * chat + amount * breath / (np.std(breath) + 1e-9) * np.std(x)


def _sum(*layers):
    out = np.zeros(max(len(x) for x in layers))
    for x in layers:
        out[:len(x)] += x
    return out


def _pain_cry(i, rng):
    # Timing: it plays at the stagger, which lasts stun_duration_s = 2.0 (data/knobs/defense.tres), so the cry runs
    # ~1.9 s: it leaps in at once (the hit) and falls away across the stagger.
    # Slices are the steady stretches of each source (no breath dips): 325548 10.31-12.0, 19.16-20.35, 14.95-16.25.
    if i == 0:  # A: a man's scream in a throat much larger than his: leaps up, collapses
        y = _layer(325548, 10.31, 12.00, 1.9, ((0, 0.62), (0.25, 0.80), (0.9, 0.66), (1.9, 0.50)), 0.80)
        y = _rasp(rng, y, 0.18)
    elif i == 1:  # B: the same man with a pig's squeal in the same throat: two voices at once, neither right
        h = _layer(325548, 19.16, 20.35, 1.8, ((0, 0.58), (0.3, 0.72), (1.0, 0.60), (1.8, 0.50)), 0.82)
        p = _layer(344972, 3.50, 4.25, 1.8, ((0, 0.50), (0.3, 0.50), (1.0, 0.42), (1.8, 0.34)), 0.85, -3.0)
        y = _rasp(rng, _sum(h, p), 0.15)
    else:  # C: a bear's bellow under a lower human cry: heavy and animal, the highs rolled off
        b = _layer(439441, 0.20, 2.30, 2.0, ((0, 0.78), (1.2, 0.70), (2.0, 0.62)), 0.88)
        h = _layer(325548, 14.95, 16.25, 2.0, ((0, 0.56), (0.3, 0.64), (2.0, 0.46)), 0.78, -4.0)
        y = dsp.lowpass(_rasp(rng, _sum(b, h), 0.12), 4200)
    y = dsp.lowpass(dsp.highpass(y, 60), 6500)
    return _fade(y, 8, 120)


# ---- catalogue -----------------------------------------------------------------------------------------------
LEVEL = {"callout": -22.0, "grunt": -22.0, "pain_cry_true_form": -19.5}  # the placeholders measured -22.5 / -19.7


def _make(name, i, build, level, event):
    nm = name if i == 0 else f"{name}_{'abc'[i]}"
    return Sound(nm, partial(_run, build, i), "voice", level, ((event, 0.0, 1.0),) if i == 0 else ())


def _run(build, i, rng):
    return build(i, rng)


def _opts(name, build, level, event):
    return [_make(name, i, build, level, event) for i in range(3)]


CANDIDATES = {}
PLAYS = {}
for k in CHARS:
    CANDIDATES[f"callout_c{k}"] = _opts(f"callout_c{k}", partial(_callout, k), LEVEL["callout"], f"callout/voice_c{k}")
    CANDIDATES[f"grunt_c{k}"] = _opts(f"grunt_c{k}", partial(_grunt, k), LEVEL["grunt"], f"voice_c{k}.shocked_grunt")
    PLAYS[f"callout_c{k}"] = ("Survivor %d's radio callout: heard from the speaker's position by every living player in range (25 m) "
                              "when they ping or call out; the words are gone on purpose, only the voice, the cadence and the "
                              "radio are left. One voice set per survivor, told apart by ear." % k)
    PLAYS[f"grunt_c{k}"] = ("Survivor %d's grunt when tased (PlayerShocked): the stagger, and the same sound when the shapeshifter is "
                            "shocked in a borrowed body, so it must match this survivor's voice." % k)
CANDIDATES["pain_cry_true_form"] = _opts("pain_cry_true_form", _pain_cry, LEVEL["pain_cry_true_form"], "voice_c0.pain_cry")
PLAYS["pain_cry_true_form"] = ("The monster's cry when stunned in true form (not while disguised: there it plays the borrowed survivor's "
                               "grunt). A grounded creature, big and hurt: no dog, nothing sci-fi.")

SOUNDS = [c[0] for c in CANDIDATES.values()]


# ---- round 2 (docs/audio/picks.md) ---------------------------------------------------------------------------
# Grunts: "more like where it's a grunt but more audible and less muffled". Round 1 bent each grunt along a pitch
# contour, moved its formants, shook it and low-passed it at 7 kHz: that is the muffle. Round 2 plays a clean recorded
# grunt (sources/voices.toml round-2 rows) as it was recorded, varispeeded a few percent toward the survivor's voice,
# band 80 Hz-12 kHz. D: as recorded. E: a presence lift at 2.5 kHz and a light drive, to cut through a mix.
# F: a different take with a jolt (a quick rise, then a sag) and no other processing.
# (source id, start s, varispeed). Inference: the varispeeds come from an autocorrelation pitch estimate of each take
# (524558 grunts ~175-230 Hz, the women's takes ~307-416 Hz) against the survivor's speech (voices.py SPEAKER);
# what settles it is the designer telling the five apart.
GRUNT_R2 = {
    1: [(524558, 29.60, 0.85), (524558, 9.33, 0.80), (524558, 48.03, 0.80)],
    2: [(524558, 31.35, 0.95), (524558, 49.84, 0.92), (524558, 15.95, 0.88)],
    3: [(188363, 0.85, 0.95), (464674, 0.0, 0.90), (188363, 2.55, 1.00)],
    4: [(464675, 0.0, 0.90), (188363, 0.0, 1.00), (427430, 21.44, 1.03)],
    5: [(524558, 33.01, 1.00), (524558, 11.51, 0.95), (464486, 0.0, 0.88)],
}


def _grunt_r2(k, i, rng):
    sid, t, r = GRUNT_R2[k][i]
    x = vari(_event(sid, max(0.0, t - 0.05), t + 0.8, 0.7), r)
    if i == 2:
        x = contour(x, len(x) / SR, (0, 1.0), (0.04, 1.08), (0.15, 1.0), (0.6, 0.94))
    y = dsp.lowpass(dsp.highpass(x, 80), 12000)
    if i == 1:
        y = dsp.drive(dsp.eq(y, "peak", 2500, 0.9, 5.0), 1.6)
    return _fade(y, 3, 60)


ROUND2 = {f"grunt_c{k}": [replace(CANDIDATES[f"grunt_c{k}"][0], name=f"grunt_c{k}_{l}", build=partial(_run, partial(_grunt_r2, k), i), ids=())
                          for i, l in enumerate("def")] for k in CHARS}
