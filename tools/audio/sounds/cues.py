"""Monster, shock, hiding and objective cues (family `cue`), built on real CC0 recordings (sources/cues.toml).

Each sound is cut from recordings (a body hit, a locker door, a stun gun, breathing, cracking bones), pitched,
layered and placed on the beats of the animation or knob it belongs to (BEATS below), never from oscillators.
The one tone, the dock beat in world.py, goes through speaker(). The shipped take is candidate A of each sound;
B and C (name_b, name_c) are the other directions for the review page (tools/audio/review/cues/).

This module also holds the cutting kit that world.py reuses.

Beats and where they come from (frame rate 24: tools/art/build_anims.py comment "14 frames = 0.58 s"):
- lunge_cue: plays when the wind-up starts; the dash follows lunge_windup_s = 0.6 s later (data/knobs/ability.tres),
  Lunge_Coil is 14 frames = 0.58 s. The sound is 0.6 s long and ends on the release.
- lunge_scrape: Lunge_Stumble, 28 frames = 1.17 s: dash ends and the trip at frame 8 (0.33 s), held to 16 (0.67 s).
- lunge_hit: starts on the hit (hit stop 0.08 s, lunge_hit_stop_s); Punch_Cross stands in for the hit.
- taser_crackle: stun_root_s = 1.0 s of jitter (data/knobs/defense.tres); the sound dies inside it.
- distortion: transform_duration_s = 2.0 s (data/knobs/borrowed_face.tres).
- hide_enter / hide_exit: Hide_Enter / Hide_Exit, 20 frames = 0.83 s; the door shuts at the end of the enter and
  opens at the start of the exit. hide_cue: one breath, every hide_cue_interval_s = 5 s.
- fuse_install: fires when the 8 s hold completes (fuse_install_s): the seat of the fuse.
"""
from dataclasses import replace
from math import gcd

import numpy as np
from scipy import signal

from lib import dsp
from lib.master import Sound

S = dsp.samples


# ---- cutting kit (shared with world.py) ----
def _env(x, ms=2.0):
    f = max(1, S(ms / 1000))
    n = len(x) // f
    return 10 * np.log10(np.mean(x[:n * f].reshape(-1, f) ** 2, axis=1) + 1e-12), f


def peaks(x, sep=0.25, n=8):
    """Starts (seconds) of the n loudest events of `x`, loudest first, at least `sep` apart. The start is the first
    2 ms frame within 20 dB of the event's peak in the 50 ms before it: the foot of the rise, not the peak."""
    db, f = _env(x)
    db = np.convolve(db, np.ones(3) / 3, "same")
    picks = []
    for i in np.argsort(-db):
        if all(abs(i - j) * f / dsp.SR >= sep for j in picks):
            picks.append(int(i))
        if len(picks) == n:
            break
    out = []
    for i in picks:
        lo = max(0, i - S(0.05) // f)
        j = lo + int(np.argmax(db[lo:i + 1] >= db[i] - 20))
        out.append(j * f / dsp.SR)
    return out


def vari(y, r):
    """Varispeed: play `y` at rate r (r < 1 slower and lower)."""
    up, down = round(100 / r), 100
    g = gcd(up, down)
    return signal.resample_poly(y, up // g, down // g)


def shape(y, att=0.001, rel=0.02):
    """Linear fade in/out of `att`/`rel` seconds (exponential-ish through a square): no click at either cut."""
    y = y.copy()
    a, r = min(len(y), S(att)), min(len(y), S(rel))
    if a:
        y[:a] *= np.linspace(0.0, 1.0, a)
    if r:
        y[-r:] *= np.linspace(1.0, 0.0, r) ** 2
    return y


def grab(sid, k=0, dur=0.5, sep=0.25, pre=0.003, rate=1.0, rel=0.03, start=None):
    """The k-th loudest event of recording `sid`, `dur` seconds long from `pre` before its foot, at playback `rate`.
    `start` cuts at a fixed time instead (seconds)."""
    x = dsp.recording(sid)
    if start is None:
        ps = peaks(x, sep, k + 1)
        start = ps[min(k, len(ps) - 1)] - pre
    y = x[max(0, S(start)): max(0, S(start)) + S(dur * rate) + 1]
    y = vari(y, rate) if rate != 1.0 else y
    y = y[:S(dur)]
    return shape(np.pad(y, (0, max(0, S(dur) - len(y)))), 0.001, rel)


def window(sid, dur, rate=1.0, loudest=True):
    """The loudest (or quietest, loudest=False) `dur`-second stretch of `sid` (a breath, a hum), 50 ms hop."""
    x = dsp.recording(sid)
    n, hop = S(dur * rate), S(0.05)
    sq = np.concatenate([[0.0], np.cumsum(x ** 2)])
    e = sq[n::hop] - sq[:len(sq) - n:hop][:len(sq[n::hop])]
    s = int(np.argmax(e) if loudest else np.argmin(e)) * hop
    y = x[s:s + n]
    return shape(vari(y, rate)[:S(dur)] if rate != 1.0 else y, 0.01, 0.05)


def tone(y, hp=None, lp=None, order=2):
    if hp:
        y = dsp.highpass(y, hp, order)
    if lp:
        y = dsp.lowpass(y, lp, order)
    return y


def put(out, y, at, db=0.0, hp=None, lp=None):
    """Add `y` (filtered, scaled by db relative to its own peak = 1) into `out` at `at` seconds."""
    y = tone(y, hp, lp)
    return dsp.place(out, dsp.norm(y) * 10 ** (db / 20), at)


def body(rng, dur, cut, tau, db=0.0):
    """Low weight of a blow: low-passed noise with a decay (dsp.thump), scaled."""
    n = S(dur)
    return dsp.thump(rng, n, cut, tau) * 10 ** (db / 20)


def swell(n, *points):
    """Gain curve through (seconds, linear gain)."""
    return dsp.curve(n, *points)


def speaker(rng, x, lo, hi, drive=2.0):
    """A cheap speaker in a panel (pipeline-handoff.md Part 3): band-limited, cone resonances, lopsided drive, buzz,
    faint hiss and mains hum. Its last 5 ms fade so the floor does not stop dead."""
    n = len(x)
    y = dsp.highpass(dsp.lowpass(x, hi), lo)
    for _ in range(3):
        y = dsp.eq(y, "peak", np.exp(rng.uniform(np.log(lo * 1.5), np.log(hi / 1.5))), rng.uniform(3, 6), rng.uniform(4, 8))
    y = dsp.norm(y)
    y = dsp.highpass(np.tanh(drive * y + 0.3) - np.tanh(0.3), lo / 2)
    buzz = dsp.bandpass(dsp.noise(rng, n), 2000, 7000) * dsp.lowpass(np.abs(y), 40)
    hum = np.sin(dsp.phase(60.0, n)) + 0.3 * np.sin(dsp.phase(180.0, n))
    out = dsp.norm(y) + 0.12 * dsp.norm(buzz) + 0.003 * dsp.highpass(dsp.noise(rng, n), 1000) + 0.004 * hum
    out[-S(0.005):] *= np.linspace(1.0, 0.0, S(0.005))
    return out


def reverse(y):
    return shape(y[::-1].copy(), 0.002, 0.01)


# ---- the sounds ----
def lunge_cue_a(rng):
    """A wet breath-in dragged tight over creaking sinew, a snap of bone as the coil lets go at 0.56 s."""
    out = np.zeros(S(0.6))
    put(out, grab(273979, 0, 0.5, rate=0.9), 0.0, -3, hp=120) * 1.0
    put(out, grab(574751, 1, 0.35, rate=0.7), 0.15, -9, hp=200, lp=3500)
    put(out, grab(574752, 0, 0.12), 0.5, -6, hp=300)
    out *= swell(len(out), (0, 0.15), (0.35, 0.55), (0.56, 1.0), (0.6, 0.0))
    return out


def lunge_cue_b(rng):
    """Backwards: a crushed-celery crackle and strained breath played in reverse swell into one hard hit at 0.57 s."""
    out = np.zeros(S(0.6))
    put(out, reverse(grab(341751, 0, 0.5, rate=0.8)), 0.1, -4, hp=150)
    put(out, reverse(grab(574751, 0, 0.45)), 0.1, -7, hp=250, lp=5000)
    put(out, grab(853588, 0, 0.1, rate=0.8), 0.52, -5)
    out *= swell(len(out), (0, 0.2), (0.5, 0.8), (0.58, 1.0), (0.6, 0.0))
    return out


def lunge_cue_c(rng):
    """Cloth and skin: a dragged body's scrape sped up into a hiss, rising, a low tendon crack to close it."""
    out = np.zeros(S(0.6))
    put(out, grab(578493, 0, 0.5, rate=1.3, sep=0.4), 0.05, -4, hp=500, lp=7000)
    put(out, grab(273979, 0, 0.35, rate=0.8), 0.18, -6, hp=150)
    put(out, grab(574752, 1, 0.1, rate=0.8), 0.52, -3, hp=200)
    out *= swell(len(out), (0, 0.1), (0.4, 0.6), (0.55, 1.0), (0.6, 0.0))
    return out


def lunge_scrape_a(rng):
    """The miss: a sneaker's skid and trip, a body dragging over concrete under it, then the catch step at 0.67 s."""
    out = np.zeros(S(0.9))
    put(out, grab(234807, 0, 0.7), 0.0, 0)
    put(out, grab(578493, 0, 0.45, sep=0.4), 0.0, -6, hp=120, lp=6000)
    put(out, grab(234807, 1, 0.2), 0.67, -8)
    return out


def lunge_scrape_b(rng):
    """Two long scrapes, a skid then a lurch, of a heavy body over concrete; no shoes."""
    out = np.zeros(S(0.9))
    put(out, grab(578493, 1, 0.5, rate=1.15, sep=0.4), 0.0, -2, hp=100, lp=8000)
    put(out, grab(578493, 2, 0.25, rate=1.0, sep=0.4), 0.62, -7, hp=100, lp=6000)
    put(out, body(rng, 0.2, 200, 0.05), 0.65, -10)
    return out


def lunge_scrape_c(rng):
    """A heavier, lower miss: the sneaker trip slowed to 0.8 with a thud as the body hits the floor."""
    out = np.zeros(S(0.9))
    put(out, grab(234807, 0, 0.85, rate=0.8), 0.0, -2, lp=6000)
    put(out, grab(853588, 2, 0.3, rate=0.7), 0.33, -6, lp=1500)
    return out


def lunge_hit_a(rng):
    """The grab: a fist into a body, a wet-cloth slap over it, a low thump under (no gore)."""
    out = np.zeros(S(0.55))
    put(out, grab(853588, 0, 0.4), 0.0, 0)
    put(out, grab(74476, 0, 0.35), 0.0, -5, hp=150)
    put(out, body(rng, 0.3, 160, 0.07), 0.0, -4)
    return out


def lunge_hit_b(rng):
    """Heavier: the blow pitched down to 0.85, a bone knock under it, cloth after."""
    out = np.zeros(S(0.55))
    put(out, grab(853588, 1, 0.45, rate=0.85), 0.0, 0)
    put(out, grab(574752, 0, 0.1, rate=0.85), 0.0, -8, lp=3000)
    put(out, grab(74476, 1, 0.3), 0.04, -9, hp=200)
    put(out, body(rng, 0.3, 120, 0.09), 0.0, -3)
    return out


def lunge_hit_c(rng):
    """Cloth-led: two wet-towel slaps (a tackle, not a punch) with the body weight behind."""
    out = np.zeros(S(0.55))
    put(out, grab(74476, 1, 0.4, rate=0.8), 0.0, 0)
    put(out, grab(74476, 2, 0.25, rate=0.9), 0.1, -5)
    put(out, body(rng, 0.35, 140, 0.1), 0.0, -3)
    return out


def taser_crackle_a(rng):
    """A civilian stun gun's zap: the first 0.75 s of the real recording, dying inside the 1 s jitter."""
    return shape(grab(265247, 0, 0.75, sep=0.1, rate=1.0), 0.001, 0.15)


def taser_crackle_b(rng):
    """A taser being fired: the cut of a taser activation with the short stun-gun pop on top."""
    out = np.zeros(S(0.8))
    put(out, grab(540012, 0, 0.75, sep=0.1), 0.0, 0, hp=150)
    put(out, grab(264779, 0, 0.3), 0.0, -4)
    return shape(out, 0.001, 0.12)


def taser_crackle_c(rng):
    """Dirtier: the stun gun pitched down to 0.85 over crackling fuse-box sparks."""
    out = np.zeros(S(0.8))
    put(out, grab(265247, 2, 0.7, sep=0.1, rate=0.85), 0.0, 0, hp=120)
    put(out, grab(807671, 0, 0.6, sep=0.1), 0.05, -7, hp=1000)
    return shape(out, 0.001, 0.12)


def taser_fizz_a(rng):
    """The monster shrugs it off: pilot-sparker ticks, dulled, dying in 0.4 s."""
    out = np.zeros(S(0.4))
    put(out, window(213613, 0.4), 0.0, 0, hp=300, lp=3500)
    return out * swell(len(out), (0, 1.0), (0.1, 0.8), (0.3, 0.3), (0.4, 0.0))


def taser_fizz_b(rng):
    """A single spark of the fuse box, slowed to 0.85 and low-passed: a flat sputter."""
    out = np.zeros(S(0.4))
    put(out, grab(807671, 0, 0.4, rate=0.85, sep=0.1), 0.0, 0, lp=2500)
    return out


def taser_fizz_c(rng):
    """Dull fizz of the taser's lead-in, low-passed to a hiss, with the stun gun's tail."""
    out = np.zeros(S(0.4))
    put(out, window(540012, 0.4, loudest=False), 0.0, 0, hp=500, lp=4000)
    put(out, grab(264779, 0, 0.25, rate=0.8), 0.0, -9, lp=2500)
    return out * swell(len(out), (0, 1.0), (0.25, 0.5), (0.4, 0.0))


def _box(y):
    """The inside of a metal locker: lowpass, a boxy 350 Hz bump, high end gone."""
    y = dsp.lowpass(y, 1100, 3)
    return dsp.eq(y, "peak", 350, 2.0, 5.0)


def hide_cue_a(rng):
    """One breath of a person in a locker, muffled by the steel box: a quiet room's heavy breath."""
    return _box(window(874174, 1.3)) * 1.0


def hide_cue_b(rng):
    """Shorter, ragged: a held-in heavy breath, higher, shaky."""
    return _box(window(386573, 1.3))


def hide_cue_c(rng):
    """A deeper, slower man's breath pitched down 0.9."""
    return _box(window(844287, 1.3, rate=0.9))


def distortion_a(rng):
    """The 2 s transformation, grounded: wet flesh bed swelling to 1.3 s, joints cracking, a bone creak under."""
    out = np.zeros(S(2.0))
    put(out, window(435896, 2.0, loudest=False), 0, -2, hp=60, lp=1800)
    for t, k in ((0.35, 0), (0.7, 1), (1.05, 2), (1.35, 3), (1.7, 4)):
        put(out, grab(414505, k, 0.18, rate=rng.uniform(0.8, 1.0), sep=0.3), t, -3 - 2 * (k % 2), hp=150)
    put(out, grab(574751, 1, 1.4, rate=0.7), 0.2, -6, hp=100, lp=3000)
    return out * swell(len(out), (0, 0.2), (1.3, 1.0), (1.8, 0.6), (2.0, 0.0))


def distortion_b(rng):
    """Bone-led: many cracks scattered through the 2 s, the lowest groan of a slowed strained breath."""
    out = np.zeros(S(2.0))
    ts = np.sort(rng.uniform(0.1, 1.7, 9))
    for i, t in enumerate(ts):
        put(out, grab(574752 if i % 2 else 414505, i % 6, 0.2, rate=rng.uniform(0.7, 1.1), sep=0.3), float(t), -4 + 3 * (t / 1.7), hp=120)
    put(out, window(341751, 2.0, rate=0.5), 0, -4, hp=60, lp=1200)
    return out * swell(len(out), (0, 0.4), (1.2, 1.0), (2.0, 0.0))


def distortion_c(rng):
    """Wet and soft: towel slaps and the crushed-celery crunch pitched down, over the flesh bed; fewer sharp cracks."""
    out = np.zeros(S(2.0))
    put(out, window(435896, 2.0), 0, 0, hp=60, lp=1500)
    for t in (0.25, 0.6, 1.0, 1.4, 1.65):
        put(out, grab(74476, int(t * 10) % 4, 0.3, rate=0.7), t, -6, hp=100, lp=2500)
    put(out, grab(574751, 0, 1.6, rate=0.6), 0.1, -3, hp=80, lp=2500)
    return out * swell(len(out), (0, 0.3), (1.4, 1.0), (2.0, 0.0))


def fuse_install_a(rng):
    """A heavy fuse seated: a switch's hard clunk, an electrical thunk of the fuse box, the locker door's weight under."""
    out = np.zeros(S(0.9))
    put(out, grab(188194, 0, 0.5), 0.0, 0)
    put(out, grab(352881, 0, 0.5), 0.02, -2)
    put(out, grab(639270, 0, 0.6, rate=0.7), 0.0, -4, lp=1200)
    put(out, body(rng, 0.4, 100, 0.12), 0.0, -3)
    return out


def fuse_install_b(rng):
    """Two-part: the seat, then the contact biting 80 ms later with a spark."""
    out = np.zeros(S(0.9))
    put(out, grab(352881, 1, 0.45, rate=0.9), 0.0, 0)
    put(out, grab(188194, 1, 0.45, rate=0.8), 0.08, -3)
    put(out, grab(807671, 0, 0.3), 0.1, -9, hp=800)
    return out


def fuse_install_c(rng):
    """Heaviest: the steel door's slam pitched down 0.6 as the body, a switch clunk on top, a short spark."""
    out = np.zeros(S(0.9))
    put(out, grab(639270, 0, 0.8, rate=0.6), 0.0, 0)
    put(out, grab(188194, 2, 0.4, rate=0.9), 0.03, -4)
    put(out, grab(264779, 0, 0.12), 0.05, -8, hp=800)
    return out


def hide_enter_a(rng):
    """Into the locker (0.83 s clip): cloth and shoes scuff, then the door shuts at 0.72 s and the latch drops."""
    out = np.zeros(S(0.85))
    put(out, grab(234807, 0, 0.5, rate=1.2), 0.0, -9, lp=4000)
    put(out, grab(232548, 0, 0.4), 0.55, 0, hp=100)
    return out


def hide_enter_b(rng):
    """Door creak first (grill door sliding), then the shut thud of a locker."""
    out = np.zeros(S(0.85))
    put(out, grab(637481, 0, 0.5, rate=1.1), 0.0, -7, hp=200)
    put(out, grab(639270, 0, 0.4), 0.5, -1, hp=100)
    return out


def hide_enter_c(rng):
    """Duller and lower: the locker door shut pitched down 0.85, wrapped in the scuff."""
    out = np.zeros(S(0.85))
    put(out, grab(234807, 0, 0.5, rate=1.2), 0.0, -9, lp=3000)
    put(out, grab(639270, 1, 0.4, rate=0.85), 0.5, 0, hp=80)
    return out


def hide_exit_a(rng):
    """Out of the locker (0.83 s clip): the latch lifts at once, the door knocks open, the grill creaks."""
    out = np.zeros(S(0.8))
    put(out, grab(232548, 1, 0.4), 0.0, 0, hp=100)
    put(out, grab(637481, 0, 0.5, rate=1.1), 0.2, -9, hp=200)
    return out


def hide_exit_b(rng):
    """A louder bang of the door thrown open, short, then the steps."""
    out = np.zeros(S(0.8))
    put(out, grab(639270, 1, 0.5, rate=1.1), 0.0, 0, hp=100)
    put(out, grab(234807, 1, 0.3), 0.3, -9)
    return out


def hide_exit_c(rng):
    """Slow and careful: the creak leads, the latch click at 0.25."""
    out = np.zeros(S(0.8))
    put(out, grab(637481, 1, 0.55, rate=0.9), 0.0, -4, hp=200)
    put(out, grab(232548, 2, 0.3), 0.25, 0, hp=100)
    return out


# name -> (level LUFS, event ids, synced, [A, B, C])
CUES = {
    "lunge_cue": (-20.0, (("lunge_cue", 0.0, 1.0),), True, (lunge_cue_a, lunge_cue_b, lunge_cue_c)),
    "lunge_scrape": (-22.0, (("lunge_scrape", 0.0, 1.0),), True, (lunge_scrape_a, lunge_scrape_b, lunge_scrape_c)),
    "lunge_hit": (-20.0, (("lunge_hit", 0.0, 1.0),), False, (lunge_hit_a, lunge_hit_b, lunge_hit_c)),
    "taser_crackle": (-20.0, (("taser_crackle", 0.0, 1.0),), False, (taser_crackle_a, taser_crackle_b, taser_crackle_c)),
    "taser_fizz": (-24.0, (("taser_fizz", 0.0, 1.0),), False, (taser_fizz_a, taser_fizz_b, taser_fizz_c)),
    "hide_cue": (-24.0, (("hide_cue", 0.0, 1.0),), False, (hide_cue_a, hide_cue_b, hide_cue_c)),
    "distortion": (-20.0, (("distortion", 0.0, 1.0),), True, (distortion_a, distortion_b, distortion_c)),
    "fuse_install": (-20.0, (("fuse_install", 4.0, 1.0),), False, (fuse_install_a, fuse_install_b, fuse_install_c)),
    "hide_enter": (-20.0, (("hide_enter", -4.0, 1.0),), True, (hide_enter_a, hide_enter_b, hide_enter_c)),
    "hide_exit": (-20.0, (("hide_exit", -4.0, 1.0),), True, (hide_exit_a, hide_exit_b, hide_exit_c)),
}

PLAYS = {
    "lunge_cue": "The monster's wind-up: heard within 20 m the moment the coil starts, 0.6 s before the dash (lunge_windup_s).",
    "lunge_scrape": "A missed lunge: the monster stumbles on the floor as the dash ends (Lunge_Stumble, 1.17 s).",
    "lunge_hit": "A lunge that lands: the grab on a survivor, a body hit and cloth, no gore.",
    "taser_crackle": "A survivor tases the monster in its true form: the pop and crackle over the 1 s jitter.",
    "taser_fizz": "The monster resists the taser (disguised): a dull fizz instead of the crackle.",
    "hide_cue": "Every 5 s while a survivor is hiding close by: breathing from inside the locker.",
    "distortion": "The 2 s transformation, heard within 15 m: flesh and bone, not sci-fi.",
    "fuse_install": "A fuse seated in the fuse box when the 8 s hold completes: the loudest objective noise.",
    "hide_enter": "A survivor climbs into a locker (Hide_Enter, 0.83 s): the door shuts at the end.",
    "hide_exit": "A survivor leaves a locker (Hide_Exit, 0.83 s): the door opens at the start.",
}


# Saturation (dsp.drive keeps the peak and lifts what is under it) for the sounds whose spikes would otherwise keep
# them under their loudness target at the -1 dBFS ceiling ("peak-limited"). 0 = none.
DRIVE = {"lunge_cue": 2.5, "lunge_scrape": 3.0, "lunge_hit": 2.5, "taser_crackle": 3.0, "taser_fizz": 3.0, "hide_enter": 3.0, "hide_exit": 3.0, "fuse_install": 2.5}


def finish(fn, amount=0.0, clean=True):
    """fn with the recordings' faults taken out: nothing above 13 kHz (the MP3 previews leave lines at 15-17 kHz),
    lasting lines capped 10 dB over their neighbours (mains hum, a mic's resonance: dsp.deline), then the saturation."""
    def build(rng):
        y = dsp.lowpass(fn(rng), 13000)
        y = dsp.deline(y) if clean else y
        return dsp.drive(y, amount) if amount else y
    return build


def option(name, i):
    level, ids, synced, fns = CUES[name]
    return Sound(name if i == 0 else f"{name}_{'abc'[i]}", finish(fns[i], DRIVE.get(name, 0.0)), "cue", level,
                 ids if i == 0 else (), False, synced)


SOUNDS = [option(n, 0) for n in CUES]
CANDIDATES = {n: [option(n, i) for i in range(3)] for n in CUES}


# ---- round 2 (docs/audio/picks.md) ---------------------------------------------------------------------------
# New recordings: sources/cues.toml round-2 rows. Times below are event feet read with peaks() (cut 3 ms ahead).
def at(sid, t, dur, rate=1.0, rel=0.03):
    """`dur` seconds of `sid` from 3 ms before `t` (an event foot read off the recording)."""
    return grab(sid, dur=dur, rate=rate, rel=rel, start=t - 0.003)


def lunge_cue_d(rng):
    """Lunge round 2 ("they all sound the same and none sound like a lunge"; round 1 was breath and bone each time).
    The creature: a snarl (a rabbit's, slowed to half: a big animal's hiss) rising through the coil, the body
    launching on a low swoosh at the release (0.56 s) with its clothes snapping."""
    out = np.zeros(S(0.6))
    put(out, at(372076, 7.15, 0.3, rate=0.5), 0.08, -3, hp=100, lp=6000)
    put(out, at(475135, 0.17, 0.25), 0.4, -2, hp=60)
    put(out, at(235243, 4.11, 0.1), 0.53, -6, hp=300)
    return out * swell(len(out), (0, 0.3), (0.3, 0.7), (0.56, 1.0), (0.6, 0.0))


def lunge_cue_e(rng):
    """The effort: a fighter's lunge grunt slowed to 0.75 peaking at the release, a stomp pushing off the floor
    under it, the swoosh of the body going."""
    out = np.zeros(S(0.6))
    put(out, at(517848, 2.50, 0.25, rate=0.75), 0.32, -2, hp=90)
    put(out, at(475135, 0.17, 0.25), 0.36, -6, hp=60)
    put(out, grab(465299, 0, 0.2, rate=0.7), 0.5, -4, lp=1500)
    return out * swell(len(out), (0, 0.6), (0.56, 1.0), (0.6, 0.0))


def lunge_cue_f(rng):
    """No voice: the body. Clothes pulled tight as it crouches, a scrape of the push-off, the low swoosh into the dash."""
    out = np.zeros(S(0.6))
    put(out, at(235243, 0.77, 0.3), 0.0, -6, hp=200)
    put(out, at(235243, 1.38, 0.2), 0.25, -4, hp=200)
    put(out, grab(578493, 0, 0.25, rate=1.2, sep=0.4), 0.33, -5, hp=150, lp=6000)
    put(out, at(475135, 0.17, 0.25, rate=0.85), 0.38, -1, hp=50)
    return out * swell(len(out), (0, 0.4), (0.56, 1.0), (0.6, 0.0))


def lunge_hit_d(rng):
    """Lunge hit round 2 ("a survivor being hit: a low thud with cloth being moved"). A punch into a body, the
    thud of the weight under it (an actor's collapse, low-passed), the jacket thrown about after."""
    out = np.zeros(S(0.55))
    put(out, at(250031, 126.00, 0.2), 0.0, -3)
    put(out, at(568799, 4.00, 0.45), 0.0, 0, lp=900)
    put(out, at(235243, 4.11, 0.3), 0.03, -6, hp=250)
    return out


def lunge_hit_e(rng):
    """Thud-led: the collapse thud slowed (heavier), a low body under it, cloth dragged across after."""
    out = np.zeros(S(0.55))
    put(out, at(568799, 0.00, 0.5, rate=0.85), 0.0, 0, lp=700)
    put(out, body(rng, 0.3, 120, 0.08), 0.0, -4)
    put(out, at(250031, 16.63, 0.3), 0.06, -7, hp=300)
    return out


def lunge_hit_f(rng):
    """A blow on a body, dulled (no slap), a thump, and two moves of a jacket as the survivor is thrown."""
    out = np.zeros(S(0.55))
    put(out, at(191659, 13.43, 0.15), 0.0, -2, lp=2500)
    put(out, body(rng, 0.35, 140, 0.1), 0.0, -2)
    put(out, at(235243, 0.03, 0.15), 0.05, -7, hp=250)
    put(out, at(235243, 1.38, 0.2), 0.22, -9, hp=250)
    return out


def distortion_d(rng):
    """Distortion round 2 (on A: "sounds like crunching on a chip, should be flesh and bone moving"). No celery
    crunch and no crisp cracks. Wet sponges squeezed, slowed (flesh pushed about), a back's joints popping deep and
    dull (low-passed), over the flesh bed."""
    out = np.zeros(S(2.0))
    put(out, window(435896, 2.0, loudest=False), 0, -6, hp=60, lp=1500)
    for t, e in ((0.1, 10.53), (0.55, 12.68), (1.0, 16.79), (1.4, 21.41)):
        put(out, at(575332, e, 0.35, rate=0.6), t, -3, hp=80, lp=3000)
    for t, e in ((0.4, 2.96), (0.9, 4.43), (1.3, 5.55)):
        put(out, at(764458, e, 0.15, rate=0.8), t, -5, hp=80, lp=2000)
    return out * swell(len(out), (0, 0.3), (1.2, 1.0), (1.8, 0.6), (2.0, 0.0))


def distortion_e(rng):
    """Bone-led but dull: real joints cracking (back, knees) slowed to 0.7 and rolled off at 1.8 kHz, so they knock
    instead of crunch, over the slowed sponge squelch."""
    out = np.zeros(S(2.0))
    put(out, at(575332, 0.41, 2.0, rate=0.55), 0, 0, hp=60, lp=2500)
    put(out, window(435896, 2.0, loudest=False), 0, -8, hp=60, lp=1500)
    for t, e in ((0.3, 1.66), (0.75, 5.43), (1.1, 6.30), (1.5, 4.16)):
        put(out, at(541081, e, 0.2, rate=0.7), t, -9, hp=70, lp=1800)
    return out * swell(len(out), (0, 0.4), (1.2, 1.0), (2.0, 0.0))


def distortion_f(rng):
    """Wet-led: the flesh bed at full, sponge squelches at half speed, one deep back crack at 1.2 s and a low thud
    as the new shape settles."""
    out = np.zeros(S(2.0))
    put(out, window(435896, 2.0), 0, 0, hp=50, lp=1800)
    for t, e in ((0.2, 18.70), (0.65, 22.77), (1.0, 25.26)):
        put(out, at(575332, e, 0.4, rate=0.5), t, -4, hp=60, lp=2500)
    put(out, at(764458, 4.43, 0.2, rate=0.7), 1.2, -3, hp=60, lp=1600)
    put(out, body(rng, 0.4, 110, 0.12), 1.55, -6)
    return out * swell(len(out), (0, 0.4), (1.3, 1.0), (2.0, 0.0))


def fuse_install_d(rng):
    """Fuse install round 2 ("all bad, redo"; round 1 was switches and a locker door). A fuse pushed into its clips:
    the slide, the snap of the clips at 0.25 s, then the box coming live (a household breaker's clack) at 0.45."""
    out = np.zeros(S(0.9))
    put(out, at(708668, 1.93, 0.2), 0.0, -6, hp=200)
    put(out, at(708668, 2.85, 0.2), 0.25, 0, hp=150)
    put(out, at(130153, 0.10, 0.4), 0.45, -3, hp=80)
    return out


def fuse_install_e(rng):
    """Breaker-led: the fuse clip's snap, then the dual-pole breaker thrown hard 80 ms later, a low body under."""
    out = np.zeros(S(0.9))
    put(out, at(593976, 0.04, 0.15), 0.0, -4, hp=200)
    put(out, at(130153, 0.10, 0.5, rate=0.85), 0.08, 0, hp=60)
    put(out, body(rng, 0.3, 120, 0.08), 0.08, -8)
    return out


def fuse_install_f(rng):
    """The seat with a spark: the clips snap, the kitchen fuse switch clicks home, a short spark as the contact bites."""
    out = np.zeros(S(0.9))
    put(out, at(708668, 2.85, 0.2), 0.0, 0, hp=150)
    put(out, at(593976, 1.75, 0.15), 0.12, -3, hp=200)
    put(out, grab(807671, 0, 0.25), 0.14, -10, hp=1000)
    return out


R2 = {"lunge_cue": (lunge_cue_d, lunge_cue_e, lunge_cue_f), "lunge_hit": (lunge_hit_d, lunge_hit_e, lunge_hit_f),
      "distortion": (distortion_d, distortion_e, distortion_f), "fuse_install": (fuse_install_d, fuse_install_e, fuse_install_f)}
ROUND2 = {n: [replace(option(n, 0), name=f"{n}_{l}", build=finish(fn, DRIVE.get(n, 0.0)), ids=()) for l, fn in zip("def", fns)]
          for n, fns in R2.items()}
