"""The client's state-driven sounds (family `state`, ClientSfx in src/feature/match_flow/client_sfx.gd), cut from
real CC0 recordings (sources/states.toml; the stings also reuse the stinger's orchestral sources, sources/scares.toml,
and the steel door, sources/world.toml). Grounded foley only: no oscillators, no sci-fi (designer).

Timing (source: ClientSfx):
- heartbeat: one beat, retriggered every 0.75 s (most of the bleed-out left) to 1.6 s (near its end): lub, then dub
  ~0.28 s on, done by 0.6 s so the fastest rate still leaves a gap.
- breath_sprint: a loop under the sprint, faded in and out over 0.6 s.
- flashlight_click: the own toggle, at once.
- generator_spinup: once, facility-wide, when power is restored: the start and run-up, 4.5 s.
- terminal_tone: a loop at the terminal while activation runs; ClientSfx pitches it 0.85-1.35 with progress and sags
  it to 0.7 and -12 dB while paused, so the source is a steady hum, never a melody.
- pa_chime: the PA's attention chime at 120 s and 60 s left in Evacuation (the spoken countdown waits for lines).
- phase/investigation: entering Investigation, subtle, 2.5 s.
- phase/tick: each second of the final 30 s; short and dry so 30 in a row do not smear.
- phase/win, phase/loss: the round's end for the own role, 3 s.
The shipped take is candidate A; B and C (name_b, name_c) are the other directions for the review page.
"""
import numpy as np

from lib import dsp
from lib.master import Sound
from sounds.cues import S, at, body, grab, put, reverse, shape, speaker, window

LOOP_S = 6.0  # loop seconds
LOOP_OV = 1.0  # seam crossfade


def _loop(sid, hp, lp, length=LOOP_S, ov=LOOP_OV):
    """A seamless `length`-second loop from the steadiest stretch of `sid`, band-limited as a circle."""
    x = dsp.recording(sid)
    span = min(length + ov + 1.0, len(x) / dsp.SR)
    s = dsp.steady_start(x, span)
    y = dsp.loop_aligned(x[s:s + dsp.samples(span)], length, ov)
    t = dsp.declick(dsp.lowpass(dsp.highpass(np.tile(y, 3), hp), lp))[len(y):2 * len(y)]  # filtered as a circle
    return t / (np.sqrt(np.mean(t ** 2)) + 1e-12)


# ---- heartbeat ----
def heartbeat_a(rng):
    """One beat of a real heartbeat (lub, dub), the highs rolled off as if heard through the body."""
    out = np.zeros(S(0.6))
    put(out, shape(at(369017, 0.0, 0.55), 0.002, 0.08), 0.0, 0, lp=900)
    return out


def heartbeat_b(rng):
    """A contact-mic beat twice: lub, then a softer dub 0.28 s on."""
    out = np.zeros(S(0.6))
    put(out, grab(784658, 0, 0.3), 0.0, 0, lp=1200)
    put(out, grab(784658, 0, 0.3, rate=1.08), 0.28, -5, lp=1200)
    return out


def heartbeat_c(rng):
    """Heavier and lower: the real beat pitched to 0.85 with a body thump under the lub."""
    out = np.zeros(S(0.6))
    put(out, shape(at(369017, 0.0, 0.5, rate=0.85), 0.002, 0.08), 0.0, 0, lp=700)
    put(out, body(rng, 0.25, 70, 0.06), 0.0, -6)
    return out


# ---- sprint breathing (loops) ----
def breath_sprint_a(rng):
    """Heavy breathing while running, the steadiest 6 s."""
    return _loop(456037, 120, 9000)


def breath_sprint_b(rng):
    """Closer and drier: a young adult breathing hard into a condenser mic."""
    return _loop(321669, 120, 9000)


def breath_sprint_c(rng):
    """Two breathers layered (the runner and a heavier man under it), wider and rougher."""
    return _loop(456037, 120, 9000) + 0.45 * np.tile(_loop(163383, 150, 8000, length=3.0, ov=0.5), 2)


# ---- flashlight click ----
def flashlight_click_a(rng):
    """A flashlight's switch, close."""
    out = np.zeros(S(0.18))
    put(out, grab(690300, 0, 0.16), 0.0, 0, hp=300)
    return out


def flashlight_click_b(rng):
    """A small, fast plastic click."""
    out = np.zeros(S(0.15))
    put(out, grab(502506, 0, 0.12), 0.0, 0, hp=300)
    return out


def flashlight_click_c(rng):
    """A rubber-capped button: softer, with the switch's spring."""
    out = np.zeros(S(0.3))
    put(out, grab(187335, 0, 0.28), 0.0, 0, hp=200)
    return out


# ---- generator spin-up ----
def generator_spinup_a(rng):
    """A 400 kW diesel generator cranking over and running up to speed, fading as it settles."""
    out = np.zeros(S(4.5))
    put(out, shape(at(169940, 0.5, 4.5), 0.05, 1.2), 0.0, 0, hp=30)
    return out


def generator_spinup_b(rng):
    """A small diesel generator's start: rattier, higher, nearer."""
    out = np.zeros(S(4.5))
    put(out, shape(at(516759, 1.0, 4.5), 0.05, 1.2), 0.0, 0, hp=40)
    return out


def generator_spinup_c(rng):
    """Both together: the big set's run-up with the small one's crank on top, and a relay clunk to start it."""
    out = np.zeros(S(4.5))
    put(out, shape(at(169940, 0.5, 4.5), 0.05, 1.2), 0.0, 0, hp=30)
    put(out, shape(at(516759, 1.0, 4.0), 0.05, 1.2), 0.3, -8, hp=80)
    put(out, grab(475313, 0, 0.3), 0.0, -10, lp=2500)
    return out


# ---- terminal activation tone (loops) ----
def terminal_tone_a(rng):
    """An electric transformer humming in a large room."""
    return _loop(453445, 40, 6000, ov=2.0)


def terminal_tone_b(rng):
    """A power transformer in a basement: lower, closer."""
    return _loop(648726, 40, 6000, ov=2.0)


def terminal_tone_c(rng):
    """Electrical hum with a buzz on top."""
    return _loop(721812, 40, 7000, ov=2.0)


# ---- PA chime ----
def pa_chime_a(rng):
    """A station PA's attention chime."""
    out = np.zeros(S(1.4))
    put(out, at(720565, 0.003, 1.2), 0.0, 0, hp=150)
    return out


def pa_chime_b(rng):
    """A metro station's PA chime."""
    out = np.zeros(S(1.2))
    put(out, at(720566, 0.003, 1.0), 0.0, 0, hp=150)
    return out


def pa_chime_c(rng):
    """The station chime through the facility's own cheap ceiling speaker."""
    out = np.zeros(S(1.4))
    put(out, speaker(rng, at(720565, 0.003, 1.2), 300, 5000, drive=1.5), 0.0, 0)
    return out


# ---- phase stings ----
def investigation_a(rng):
    """Subtle: a metal groan somewhere in the building, slowed and dulled."""
    out = np.zeros(S(2.5))
    put(out, shape(grab(496836, 0, 2.4, rate=0.8), 0.2, 0.8), 0.0, 0, lp=2500)
    return out


def investigation_b(rng):
    """A crank groaning, low."""
    out = np.zeros(S(2.5))
    put(out, shape(grab(453333, 0, 2.4, rate=0.7), 0.15, 0.8), 0.0, 0, lp=3000)
    return out


def investigation_c(rng):
    """Backwards: the groan swelling in and stopping."""
    out = np.zeros(S(2.5))
    put(out, shape(reverse(grab(496836, 0, 2.3, rate=0.8)), 0.05, 0.1), 0.1, 0, lp=2500)
    return out


def tick_a(rng):
    """One clock tick."""
    out = np.zeros(S(0.12))
    put(out, grab(534094, 0, 0.1), 0.0, 0, hp=400)
    return out


def tick_b(rng):
    """A wall clock's tick, a little room around it."""
    out = np.zeros(S(0.15))
    put(out, grab(434841, 0, 0.14, sep=0.4), 0.0, 0, hp=400)
    return out


def tick_c(rng):
    """An old clock's heavier tick."""
    out = np.zeros(S(0.2))
    put(out, grab(42139, 0, 0.18, sep=0.4), 0.0, 0, hp=250)
    return out


def win_a(rng):
    """The heavy door swinging open and violas sustaining over it, fading."""
    out = np.zeros(S(3.0))
    put(out, grab(385192, 0, 1.2, sep=0.5), 0.0, -2, hp=60)
    put(out, shape(window(374487, 2.6), 0.4, 1.2), 0.3, -4)
    return out


def win_b(rng):
    """Violas alone, lifted a little, a long breath out."""
    out = np.zeros(S(3.0))
    put(out, shape(window(374487, 2.9, rate=1.12), 0.3, 1.4), 0.0, 0)
    return out


def win_c(rng):
    """Relief: the door open and the generator winding down."""
    out = np.zeros(S(3.0))
    put(out, grab(385192, 0, 1.2, sep=0.5), 0.0, 0, hp=60)
    put(out, shape(at(169940, 58.0, 2.8), 0.2, 1.0), 0.2, -6, hp=30)
    return out


def loss_a(rng):
    """A low orchestral hit with the contrabass trembling under it, and a metal groan fading."""
    out = np.zeros(S(3.0))
    put(out, shape(grab(683256, 0, 1.5, sep=2.0, rate=0.8), 0.002, 0.6), 0.0, 0, lp=4000)
    put(out, shape(window(373169, 2.8), 0.2, 1.2), 0.1, -5)
    put(out, shape(grab(496836, 0, 2.0, rate=0.6), 0.3, 0.8), 0.8, -10, lp=1500)
    return out


def loss_b(rng):
    """A fire door slammed shut and the contrabass under it."""
    out = np.zeros(S(3.0))
    put(out, grab(475313, 0, 1.0), 0.0, 0, hp=50)
    put(out, shape(window(373169, 2.6), 0.3, 1.2), 0.2, -6)
    return out


def loss_c(rng):
    """The building groaning, slowed hard, with a thump."""
    out = np.zeros(S(3.0))
    put(out, body(rng, 0.6, 60, 0.15), 0.0, 0)
    put(out, shape(grab(496836, 0, 2.8, rate=0.5), 0.05, 1.0), 0.0, -3, lp=1500)
    return out


# name -> (LUFS, bank ids, loop, (A, B, C))
STATES = {
    "heartbeat": (-26.0, (("heartbeat", 0.0, 1.0),), False, (heartbeat_a, heartbeat_b, heartbeat_c)),
    "breath_sprint": (-30.0, (("breath_sprint", 0.0, 1.0),), True, (breath_sprint_a, breath_sprint_b, breath_sprint_c)),
    "flashlight_click": (-33.0, (("flashlight_click", 0.0, 1.0),), False,
                         (flashlight_click_a, flashlight_click_b, flashlight_click_c)),
    "generator_spinup": (-24.0, (("generator_spinup", 0.0, 1.0),), False,
                         (generator_spinup_a, generator_spinup_b, generator_spinup_c)),
    "terminal_tone": (-30.0, (("terminal_tone", 0.0, 1.0),), True, (terminal_tone_a, terminal_tone_b, terminal_tone_c)),
    "pa_chime": (-24.0, (("pa_chime", 0.0, 1.0),), False, (pa_chime_a, pa_chime_b, pa_chime_c)),
    "phase_investigation": (-28.0, (("phase/investigation", 0.0, 1.0),), False,
                            (investigation_a, investigation_b, investigation_c)),
    "phase_tick": (-30.0, (("phase/tick", 0.0, 1.0),), False, (tick_a, tick_b, tick_c)),
    "phase_win": (-24.0, (("phase/win", 0.0, 1.0),), False, (win_a, win_b, win_c)),
    "phase_loss": (-24.0, (("phase/loss", 0.0, 1.0),), False, (loss_a, loss_b, loss_c)),
}

PLAYS = {
    "heartbeat": "While your own body bleeds out (Downed): one beat every 0.75 s, slowing to 1.6 s near the end. Only you hear it.",
    "breath_sprint": "Loops under your own sprint, fading in and out over 0.6 s. Only you hear it.",
    "flashlight_click": "Your flashlight turning on or off, at once.",
    "generator_spinup": "Once, facility-wide, when the last fuse restores power.",
    "terminal_tone": "Loops at the terminal while activation runs, pitched up with progress; sags lower and quieter while paused.",
    "pa_chime": "The PA's chime at 2:00 and 1:00 left in Evacuation (the spoken countdown comes later).",
    "phase_investigation": "Once, entering Investigation. Meant to be subtle.",
    "phase_tick": "Each second of the final 30 s of the round.",
    "phase_win": "The round ends and your side won.",
    "phase_loss": "The round ends and your side lost.",
}


def option(name, i):
    level, ids, loop, fns = STATES[name]
    # nothing above 13 kHz (the MP3 previews' lines); a loop is band-limited as a circle in _loop instead
    build = fns[i] if loop else (lambda rng, fn=fns[i]: dsp.lowpass(fn(rng), 13000))
    return Sound(name if i == 0 else f"{name}_{'abc'[i]}", build, "state", level, ids if i == 0 else (), loop, False)


SOUNDS = [option(n, 0) for n in STATES]
CANDIDATES = {n: [option(n, i) for i in range(3)] for n in STATES}
