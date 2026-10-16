"""Scare events (family `scare`) and the stinger (family `stinger`), on real CC0 recordings (sources/scares.toml).

Each sound is a few cut recordings laid on a timeline (a door kick, a breaker, a slammed fire door, ice cracking for
glass, an alarm bell, a PA announcement smeared past understanding, a CRT scan, orchestral hits). A cut starts 3 ms
before its own onset and is faded at the end. Three candidates per sound (A ships, B and C are on the review page,
tools/audio/review/scares/); which direction suits the game is the designer's ear to settle. Timings inside a sound
are read from the recordings (onsets probed at 10 ms) and chosen by ear-less rules, so they are inference: what
settles them is the review page. Nothing here is tied to an animation clip (a scare is heard at its origin when the
server says so), so no beat comes from a clip or a knob.
"""
from fractions import Fraction
from functools import partial

import numpy as np
from scipy import ndimage, signal

from lib import dsp
from lib.master import Sound

SR = dsp.SR


# ---- building blocks -------------------------------------------------------------------------------------------

def cut(sid, t0, dur, speed=1.0, hp=None, lp=None, onset=True, fade=0.03):
    """`dur` seconds of recording `sid` from `t0`, varispeeded by `speed`, filtered, peak 1. With `onset` the cut
    starts 3 ms before the first sample above 15 % of its peak (a cut must rise into its event)."""
    x = dsp.recording(sid, t0, t0 + dur * speed)
    if speed != 1.0:
        r = Fraction(1 / speed).limit_denominator(40)
        x = signal.resample_poly(x, r.numerator, r.denominator)
    if hp:
        x = dsp.highpass(x, hp)
    if lp:
        x = dsp.lowpass(x, lp)
    x = x / (np.max(np.abs(x)) + 1e-12)
    if onset:
        i = int(np.argmax(np.abs(x) > 0.15))
        x = x[max(0, i - dsp.samples(0.003)):]
    m = min(len(x) // 2, dsp.samples(fade))
    x[-m:] *= np.cos(np.linspace(0, np.pi / 2, m)) ** 2
    k = dsp.samples(0.0008)
    x[:k] *= np.linspace(0, 1, k)
    return x


def mix(length, *layers):
    """Sum of (signal, at seconds, gain dB) laid on a timeline of `length` seconds."""
    out = np.zeros(dsp.samples(length))
    for x, at, g in layers:
        dsp.place(out, x * 10 ** (g / 20), at)
    return out


def rush(rng, seconds, f0, f1, peak_at):
    """Air or cloth moving fast: pink-ish noise, low-passed upward from f0 to f1, swelling to `peak_at`."""
    n = dsp.samples(seconds)
    x = dsp.colored(rng, n, 1.0)
    y = np.zeros(n)
    k = 6
    edges = np.geomspace(f0, f1, k)
    env = dsp.curve(n, (0, 0), (peak_at, 1), (seconds, 0))
    for i in range(k - 1):  # a low pass that climbs: crossfade the band-limited copies along the sweep
        w = np.clip(1 - np.abs(np.linspace(0, k - 2, n) - i), 0, 1)
        y += dsp.lowpass(x, edges[i + 1], 2) * w
    return dsp.norm(y * env)


def thud(rng, seconds, cutoff, tau):
    """Low weight of a body or a door: low-passed noise with a decay (never a falling sine)."""
    return dsp.thump(rng, dsp.samples(seconds), cutoff, tau)


def specks(rng, seconds, rate, lo, hi, tau_s):
    """Debris, shards and grit: Poisson specks of octave-wide noise, thinning as the sound dies."""
    n = dsp.samples(seconds)
    env = np.exp(-dsp.clock(n) / tau_s)
    out = np.zeros(n)
    for i in np.nonzero(rng.random(n) < rate * env / SR)[0]:
        c = np.exp(rng.uniform(np.log(lo), np.log(hi)))
        m = dsp.samples(rng.uniform(0.002, 0.012))
        g = dsp.bandpass(rng.standard_normal(m), c / 1.41, min(c * 1.41, 0.45 * SR)) * np.exp(-np.arange(m) / (m / 4))
        j = min(len(g), n - i)
        out[i:i + j] += g[:j] * rng.uniform(0.3, 1.0)
    return out


def speaker(rng, x, lo, hi, drive=2.0):
    """A cheap horn or panel speaker (pipeline-handoff.md Part 3, speaker()): band-limited, cone resonances,
    lopsided overdrive, a buzz where loud, faint hiss. The 60 Hz hum is left out (a lasting line in a dry file)."""
    n = len(x)
    y = dsp.highpass(dsp.lowpass(x, hi), lo)
    for _ in range(3):
        y = dsp.eq(y, "peak", np.exp(rng.uniform(np.log(lo * 1.5), np.log(hi / 1.5))), rng.uniform(3, 6), rng.uniform(4, 8))
    y = dsp.norm(y)
    y = dsp.highpass(np.tanh(drive * y + 0.3) - np.tanh(0.3), lo / 2)
    buzz = dsp.bandpass(rng.standard_normal(n), 2000, 7000) * dsp.lowpass(np.abs(y), 40)
    y = dsp.norm(y) + 0.12 * dsp.norm(buzz) + 0.003 * dsp.highpass(rng.standard_normal(n), 1000)
    m = min(n // 2, dsp.samples(0.02))
    y[-m:] *= np.linspace(1, 0, m)  # the hiss floor must not stop dead
    return y


def smear(x, ms):
    """Smear each frequency's level over `ms` (STFT magnitude, phase kept): pitch and cadence survive, words do not
    (pipeline-handoff.md Part 4, voices behind a radio)."""
    _, _, z = signal.stft(x, SR, nperseg=1024, noverlap=768)
    mag = ndimage.uniform_filter1d(np.abs(z), size=max(1, int(ms / 1000 * SR / 256)), axis=1)
    _, y = signal.istft(mag * np.exp(1j * np.angle(z)), SR, nperseg=1024, noverlap=768)
    return y[:len(x)]


def unrecognisable(rng, x, ms, crush=6000, lo=300, hi=3400, drive=3.0):
    """A recorded voice made into something a wall speaker mumbles: smear, compress, hard lopsided clip, drop the
    sample rate with no anti-alias filter (fold-back grit), then the speaker. The band limit comes last."""
    y = smear(x, ms)
    y = dsp.norm(y)
    y = np.tanh(3 * y) / np.tanh(3)
    step = max(1, int(SR / crush))
    y = np.repeat(y[::step], step)[:len(x)]
    y = np.pad(y, (0, len(x) - len(y)))
    y = speaker(rng, y, lo, hi, drive)
    return dsp.highpass(dsp.lowpass(y, hi), lo)


def fit(x, seconds, tail=0.05):
    """Trim or pad to `seconds`, with an exponential-ish fade over the last `tail`."""
    n = dsp.samples(seconds)
    y = np.zeros(n)
    m = min(n, len(x))
    y[:m] = x[:m]
    f = min(n, dsp.samples(tail))
    y[-f:] *= np.cos(np.linspace(0, np.pi / 2, f)) ** 2
    return y


# ---- sounds: each takes the candidate index v (0 = A, 1 = B, 2 = C) and the rng ---------------------------------

def transformation_reveal(v, rng):
    """The true form tears out of the disguise: bone cracks, a wet tearing, a low body under them."""
    if v == 0:  # cracks in a cluster, wet tear, a dark low hit
        j = rng.uniform(-0.02, 0.02, 4)
        return mix(1.6, (cut(145363, 0.22, 0.4), 0.05 + j[0], 0), (cut(414505, 4.7, 0.3), 0.19 + j[1], -3),
                   (cut(414505, 1.55, 0.3, 0.8), 0.38 + j[2], -2), (cut(234236, 2.2, 1.3, 0.8, hp=150, onset=False), 0.1, -8),
                   (cut(684805, 0.4, 1.4, 0.6, hp=70, lp=500), 0.2, -2), (thud(rng, 0.6, 140, 0.15), 0.2, -4))
    if v == 1:  # all tear and drag, slowed: one long ripping with the cracks inside it
        return mix(2.0, (cut(234236, 6.8, 1.9, 0.7, hp=120, onset=False), 0, -3), (cut(414505, 4.7, 0.3, 0.7), 0.5, -2),
                   (cut(145363, 0.22, 0.4, 0.7), 0.9, -4), (cut(684805, 0.4, 1.8, 0.5, hp=70, lp=400), 0.15, -4))
    # C: dry and brutal, a flurry of cracks and a low thud, no dark hit
    t = np.sort(rng.uniform(0.0, 0.5, 6))
    cr = [(cut(sid, s, 0.25, rng.uniform(0.7, 1.1)), float(a), -rng.uniform(0, 6))
          for a, (sid, s) in zip(t, [(414505, 4.7), (145363, 0.22), (414505, 1.55), (414505, 2.35), (145363, 0.22), (414505, 5.8)])]
    return mix(1.4, *cr, (thud(rng, 0.9, 200, 0.2), 0.25, -2),
               (cut(234236, 2.0, 0.9, 1.0, hp=200, onset=False), 0.3, -6))


def door_burst(v, rng):
    """The monster smashes through a barricaded door: wood splintering, the door hitting its stop, debris falling."""
    if v == 0:
        return mix(2.0, (cut(452609, 0.0, 2.0), 0, 0), (cut(536777, 0.0, 1.0), 0.0, -2),
                   (thud(rng, 0.7, 130, 0.18), 0.0, -3), (specks(rng, 1.8, 90, 800, 5000, 0.5), 0.25, -14))
    if v == 1:  # heavier, slower: the kick without rattle, dropped in speed
        return mix(2.0, (cut(452609, 2.1, 1.9, 0.8), 0, 0), (cut(411694, 0.1, 0.5, 0.8), 0.0, -3),
                   (thud(rng, 0.9, 100, 0.25), 0.0, -2), (specks(rng, 1.8, 60, 600, 4000, 0.6), 0.3, -14))
    return mix(2.0, (cut(536777, 0.0, 1.0, 0.85), 0, 0), (cut(411694, 0.1, 0.5), 0.12, -2),
               (cut(452609, 0.0, 1.9, 1.15), 0.2, -4), (thud(rng, 0.7, 160, 0.15), 0.0, -3))


def ambush_lunge(v, rng):
    """The monster lunges at a survivor: a rush of air, then the body arrives (a stinger plays over it)."""
    if v == 0:  # rush, body on a wooden floor
        return mix(0.8, (rush(rng, 0.35, 300, 5000, 0.28), 0.0, -5), (cut(128103, 21.15, 0.5, 1.0, hp=40), 0.3, 0),
                   (thud(rng, 0.3, 120, 0.08), 0.3, -4))
    if v == 1:  # a body into metal, the rattle after
        return mix(0.8, (rush(rng, 0.3, 500, 7000, 0.24), 0.0, -6), (cut(474008, 4.1, 0.5), 0.26, 0),
                   (thud(rng, 0.3, 110, 0.09), 0.26, -4))
    return mix(0.8, (rush(rng, 0.25, 200, 3000, 0.2), 0.0, -4), (cut(128103, 18.9, 0.5, 0.9, hp=40), 0.22, 0),
               (cut(474008, 34.0, 0.4, 1.0), 0.24, -5))


def blackout(v, rng):
    """The power drops: a big breaker thrown, relays dropping out one after another, a transformer hum dying."""
    def dying_hum(seconds, f0, f1):  # mains buzz as dense noise in a band, its pitch falling and its level with it
        n = dsp.samples(seconds)
        y = dsp.bandpass(dsp.colored(rng, n, 1.0), f0, f0 * 2.2) * dsp.decay(n, seconds / 4)
        return dsp.norm(dsp.lowpass(y, f1))
    if v == 0:
        return mix(1.2, (cut(465696, 0.05, 0.6, 0.8), 0.0, 0), (cut(451933, 1.58, 0.5), 0.05, -3),
                   (cut(807384, 14.1, 0.5, 1.0, hp=200), 0.2, -4), (cut(807384, 16.0, 0.4, 1.0, hp=200), 0.45, -6),
                   (dying_hum(1.0, 100, 900), 0.0, -8))
    if v == 1:  # one heavy clunk and a long low decay
        return mix(1.4, (cut(451933, 0.15, 1.0, 0.75), 0.0, 0), (cut(807384, 34.3, 0.5, 0.8, hp=100), 0.25, -4),
                   (thud(rng, 1.0, 90, 0.35), 0.0, -3), (dying_hum(1.2, 80, 500), 0.0, -8))
    t = np.cumsum(rng.uniform(0.07, 0.16, 6))  # a bank of relays dropping out in a rattle
    rl = [(cut(807384, s, 0.3, rng.uniform(0.85, 1.1), hp=150), float(a), -g)
          for a, s, g in zip(t, (14.1, 16.0, 17.1, 19.0, 21.8, 14.1), (0, 2, 4, 3, 6, 8))]
    return mix(1.2, (cut(465696, 0.05, 0.6, 0.9), 0.0, -2), *rl, (dying_hum(1.0, 90, 700), 0.0, -8))


def slammed_door(v, rng):
    """A door slams shut where it stands and shudders: one hard bang and the frame, no swing."""
    if v == 0:
        return mix(0.7, (cut(724123, 0.0, 0.7), 0, 0), (thud(rng, 0.4, 150, 0.1), 0.0, -4))
    if v == 1:  # a heavy fire door
        return mix(0.8, (cut(341176, 15.8, 0.8), 0, 0), (thud(rng, 0.5, 100, 0.14), 0.0, -3))
    return mix(0.7, (cut(406641, 1.45, 0.7, 0.9), 0, 0), (cut(724123, 0.0, 0.5, 0.8), 0.0, -3),
               (thud(rng, 0.4, 130, 0.1), 0.0, -3))


def glass_break(v, rng):
    """A glass panel cracks and stays in its frame: sharp crack ticks spreading, no fall of shards."""
    if v == 0:
        return mix(0.9, (cut(262635, 0.1, 0.5, 1.3, hp=1200), 0.0, 0), (cut(177224, 0.22, 0.5, 1.2, hp=1500), 0.08, -3),
                   (cut(262635, 0.5, 0.4, 1.5, hp=2000), 0.35, -6), (specks(rng, 0.7, 25, 3000, 9000, 0.25), 0.1, -16))
    if v == 1:  # real breaking glass, only its first pieces: cracks and small ticks, cut before it falls
        return mix(0.9, (cut(379015, 0.42, 0.4, 1.0, hp=800), 0.0, 0), (cut(379015, 1.0, 0.3, 1.0, hp=800), 0.3, -4),
                   (cut(262635, 0.1, 0.4, 1.4, hp=1500), 0.05, -4))
    return mix(0.9, (cut(177224, 0.22, 0.6, 1.0, hp=1000), 0.0, 0), (cut(177224, 0.22, 0.4, 1.4, hp=2000), 0.18, -4),
               (cut(262635, 0.5, 0.4, 1.0, hp=1000), 0.4, -3))


def _bell(sid, t0, seconds, speed=1.0):
    return cut(sid, t0, seconds, speed, hp=200, onset=False, fade=0.1)


def alarm_fuse(v, rng):
    """The fuse-box alarm: a bell rung hard through a small panel speaker, two seconds of it."""
    if v == 0:
        x = speaker(rng, _bell(743963, 11.2, 2.0), 400, 5000, 2.0)
    elif v == 1:
        x = speaker(rng, _bell(572529, 10.0, 2.0), 250, 3500, 2.5)
    else:  # both bells, hard overdriven
        x = speaker(rng, 0.7 * _bell(743963, 11.2, 2.0, 0.8) + _bell(572529, 20.0, 2.0), 300, 4500, 4.0)
    return dsp.deline(fit(x, 2.0, 0.1), 14.0)


def alarm_evacuation(v, rng):
    """The evacuation alarm: a big bell through the facility's horns, four seconds."""
    if v == 0:
        x = speaker(rng, _bell(572529, 5.0, 4.0), 200, 3500, 2.0)
    elif v == 1:  # a bigger, slower bell
        x = speaker(rng, _bell(743963, 4.0, 4.0, 0.6), 200, 4000, 2.0)
    else:  # bell with a PA hiss-and-mumble under it
        v1 = unrecognisable(rng, cut(450154, 5.2, 4.0, onset=False), 160)
        x = speaker(rng, _bell(572529, 15.0, 4.0), 200, 3500, 2.5) + 0.35 * v1
    return dsp.deline(fit(x, 4.0, 0.15), 14.0)


def _voice(rng, sid, t0, v, ms):
    """Two and a half seconds of a PA voice made unrecognisable, rising from the speaker's click."""
    x = cut(sid, t0, 2.5, [1.0, 0.85, 1.15][v], onset=False)
    y = unrecognisable(rng, x, ms)
    click = dsp.highpass(rng.standard_normal(dsp.samples(0.02)), 1500) * np.exp(-dsp.clock(dsp.samples(0.02)) / 0.004)
    y = fit(y, 2.5, 0.12)
    y[:len(click)] += 0.5 * click
    return y


def recording_room(v, rng):
    """A recording plays in a room: a voice from a wall speaker, distorted until the words are gone."""
    sid, t0 = [(450154, 5.2), (637521, 11.0), (450154, 26.5)][v]
    return dsp.deline(_voice(rng, sid, t0, v, [130, 150, 110][v]), 12.0)


def recording_script(v, rng):
    """The scripted recording (a RoundScript scare): a voice from a wall speaker, another phrase, same treatment."""
    sid, t0 = [(450154, 13.1), (637521, 85.0), (450154, 20.0)][v]
    return dsp.deline(_voice(rng, sid, t0, v, [140, 120, 150][v]), 12.0)


def surveillance_image(v, rng):
    """An impossible image on a monitor: the static of a real CRT, a pop as the tube switches on."""
    if v == 0:  # tuner scan, the hiss and crackle of the tube
        x = cut(756799, 0.85, 1.2, 1.0, hp=150, onset=False)
    elif v == 1:  # a TV switched on to static: the click and the hiss
        x = cut(616850, 0.28, 1.2, 1.0, hp=100)
    else:  # microphone behind a set on a dead channel, with the switch-on pop
        x = mix(1.2, (cut(542635, 3.0, 1.2, 1.0, hp=200, onset=False), 0, 0), (cut(616850, 0.28, 0.4, 0.8), 0.0, 3))
    x = x * dsp.curve(len(x), (0, 0.0), (0.02, 1.0), (1.0, 0.8), (1.2, 0.0))
    return fit(x, 1.2, 0.1)


def scare_stinger(v, rng):
    """Non-diegetic stinger on a Major scare: orchestral hit and tremolo strings, tonal on purpose."""
    if v == 0:  # full orchestra hit on C minor, slowed a little
        x = mix(1.5, (cut(683256, 4.75, 1.5, 0.85), 0, 0), (cut(684805, 0.4, 1.5, 0.7, hp=70, lp=500), 0.0, -4))
    elif v == 1:  # string tremolo swell over a low bass
        x = mix(1.5, (cut(374487, 1.0, 1.5, 1.0, onset=False, fade=0.4), 0, 0), (cut(373169, 1.4, 1.5, 1.0, onset=False, fade=0.4), 0.0, -3),
                (cut(683256, 14.4, 1.0, 1.0), 0.0, -9))
    else:  # col legno strings and a metal hit, hard
        x = mix(1.4, (cut(683256, 14.4, 1.4, 0.9), 0, 0), (cut(376204, 0.0, 0.8, 0.8), 0.0, -3), (cut(684805, 0.4, 1.4, 0.55, hp=70, lp=400), 0.0, -3))
    return fit(x * dsp.curve(len(x), (0, 1.0), (1.0, 0.6), (1.5, 0.3)), len(x) / SR, 0.15)


BUILDERS = {
    "scare_transformation_reveal": transformation_reveal, "scare_door_burst": door_burst,
    "scare_ambush_lunge": ambush_lunge, "scare_blackout": blackout, "scare_slammed_door": slammed_door,
    "scare_glass_break": glass_break, "scare_alarm_fuse": alarm_fuse, "scare_alarm_evacuation": alarm_evacuation,
    "scare_recording_room": recording_room, "scare_recording_script": recording_script,
    "scare_surveillance_image": surveillance_image, "scare_stinger": scare_stinger,
}
# Target LUFS where the default (-20, lib/master.py FAMILIES) cannot be reached under the -1 dBFS ceiling (spiky glass, a
# static pop, a lunge) or would be too much (sustained bells, whose energy sits at 2-4 kHz). Inference: set from the
# peak-limited lines of the export and the ear-less rule that a sustained alarm is louder than its LUFS says.
LEVEL = {"scare_transformation_reveal": -21.0, "scare_ambush_lunge": -20.5, "scare_glass_break": -21.5,
         "scare_surveillance_image": -22.0, "scare_alarm_fuse": -23.0, "scare_alarm_evacuation": -23.0}
EVENT_OF = {n: "scare/" + n[len("scare_"):] for n in BUILDERS}


def _build(fn, v, rng):
    return fn(v, rng)


def option(name, i):
    fam, level = ("stinger", -30.5) if name == "scare_stinger" else ("scare", LEVEL.get(name, -20.0))
    # The stinger is levelled at the bed's level less a margin: the shipped file plus stinger_max_db_rel (6 dB) stays
    # at most 6 dB over every bed (SE-8 AC-2, tests/unit/audio/sound_bank_test.gd; loudness.md). Unchanged.
    return Sound(name if i == 0 else f"{name}_{'abc'[i]}", partial(_build, BUILDERS[name], i), fam, level,
                 ((EVENT_OF[name], 0.0, 1.0),) if i == 0 else ())


PLAYS = {
    "scare_transformation_reveal": "The shapeshifter's disguise comes off in front of a survivor (Major scare, with the stinger): distortion at the origin.",
    "scare_door_burst": "The monster smashes through a barricaded door (Major): the impact at the door, debris falling.",
    "scare_ambush_lunge": "The monster lunges from cover (Major, stinger only, no flinch): the rush and the body, over the lunge cue.",
    "scare_blackout": "A zone loses power: the power-down at its origin as the lights go out.",
    "scare_slammed_door": "A door slams shut in place and shudders (Medium): at the door, no swing.",
    "scare_glass_break": "A glass panel cracks but stays (Medium): at the panel.",
    "scare_alarm_fuse": "The fuse alarm: a positional bell from the fuse box, two seconds.",
    "scare_alarm_evacuation": "The evacuation alarm: bells through the facility horns, with the amber beacons.",
    "scare_recording_room": "A recording plays from a wall speaker in the room: a distorted voice, unrecognisable.",
    "scare_recording_script": "A scripted recording plays from a wall speaker: another unrecognisable voice.",
    "scare_surveillance_image": "The impossible image flashes on a monitor (single client): CRT static at the monitor.",
    "scare_stinger": "Rides over a Major scare, non-positional, at most 6 dB over the zone bed.",
}
SOUNDS = [option(n, 0) for n in BUILDERS]
CANDIDATES = {n: [option(n, i) for i in range(3)] for n in BUILDERS}
