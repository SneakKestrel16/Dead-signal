"""Doors, barricades, objective dock and alarm (family `world`), built on real CC0 recordings (sources/world.toml).

Cut, pitched and layered with the kit in sounds/cues.py. The dock's one beep goes through speaker(); the alarm is a
recorded building siren heard at a distance, never an oscillator. The shipped take is candidate A of each sound;
B and C (name_b, name_c) are the other directions for the review page (tools/audio/review/world/).

Timing (source: WorldSfx plays on the state flip, so these start at the event):
- door_open / door_close: the door state flips at once in game (no door clip found in src/); a heavy latch and swing.
- barricade_build: plays when the barricade appears, after barricade_duration_s = 3.0 s of building (defense.tres):
  the last blows of the nailing, 1.6 s.
- barricade_break: plays when it falls, after barricade_break_s = 5.0 s of breaking: the final splintering, 0.9 s.
- objective_dock: dock_s = 2.0 s hold (objectives.tres); the drive seats at the end.
- objective_alarm: plays once, facility-wide (WorldSfx.ALARM): 2.4 s of a siren in the distance.
"""
import numpy as np

from lib import dsp
from lib.master import Sound
from sounds.cues import S, body, finish, grab, put, reverse, speaker, window


def door_open_a(rng):
    """A heavy steel door: the bolt's clunk, then the leaf swinging on dry hinges."""
    out = np.zeros(S(1.0))
    put(out, grab(385192, 0, 0.9, sep=0.5), 0.0, 0, hp=60)
    return out


def door_open_b(rng):
    """Slower and lower: the same door pitched to 0.85 with the fire door's latch kick."""
    out = np.zeros(S(1.0))
    put(out, grab(385192, 1, 0.95, rate=0.85, sep=0.5), 0.0, 0, hp=60)
    put(out, grab(475313, 0, 0.2), 0.0, -9, lp=3000)
    return out


def door_open_c(rng):
    """Backwards: the fire door slam reversed into a sucking draw-in, then the swing of the steel door."""
    out = np.zeros(S(1.0))
    put(out, reverse(grab(475313, 0, 0.5)), 0.0, -5, lp=4000)
    put(out, grab(385192, 2, 0.6, sep=0.5), 0.4, -2, hp=60)
    return out


def door_close_a(rng):
    """The fire door shutting: one heavy slam and its rattle."""
    out = np.zeros(S(0.8))
    put(out, grab(475313, 0, 0.8), 0.0, 0, hp=50)
    put(out, body(rng, 0.4, 110, 0.1), 0.0, -4)
    return out


def door_close_b(rng):
    """Off-mic thud of a big steel door: room behind it, lower."""
    out = np.zeros(S(0.8))
    put(out, grab(406197, 0, 0.8, sep=0.5), 0.0, 0, hp=50)
    return out


def door_close_c(rng):
    """Both: the steel door's slam under the fire door's crack, 20 ms behind."""
    out = np.zeros(S(0.8))
    put(out, grab(385192, 3, 0.75, sep=0.5), 0.0, 0, hp=50)
    put(out, grab(475313, 0, 0.5, rate=0.85), 0.02, -5)
    return out


def barricade_build_a(rng):
    """Planks nailed across a door: four hammer blows on nails, irregular, the last firm; a plank thud first."""
    out = np.zeros(S(1.6))
    put(out, grab(676730, 0, 0.3), 0.0, -4, hp=80)
    for i, t in enumerate((0.25, 0.62, 0.95, 1.3)):
        put(out, grab(707525, i, 0.25, sep=0.1), t + rng.uniform(-0.03, 0.03), -4 + 4 * (i == 3), hp=150)
    return out


def barricade_build_b(rng):
    """Faster, more blows: the hammering recording's strokes in a run of five, then a dropped plank."""
    out = np.zeros(S(1.6))
    for i, t in enumerate((0.1, 0.4, 0.65, 0.9, 1.1)):
        put(out, grab(811941, i, 0.25, sep=0.1), t + rng.uniform(-0.02, 0.02), -3, hp=150)
    put(out, grab(676730, 1, 0.4), 1.15, -2, hp=80)
    return out


def barricade_build_c(rng):
    """Heavy mallet blows on a timber beam, nails ringing between."""
    out = np.zeros(S(1.6))
    for i, t in enumerate((0.0, 0.45, 0.9, 1.25)):
        put(out, grab(676730, i, 0.35, sep=0.3, rate=0.9), t, -2, hp=80)
        put(out, grab(707525, i + 4, 0.2, sep=0.1), t + 0.18, -8, hp=200)
    return out


def barricade_break_a(rng):
    """The planks give: plywood cracking and splintering with a tail of falling pieces."""
    out = np.zeros(S(0.9))
    put(out, grab(873248, 0, 0.9, sep=0.4), 0.0, 0, hp=80)
    return out


def barricade_break_b(rng):
    """Rotten boards: one long snap and a tear, lower."""
    out = np.zeros(S(0.9))
    put(out, grab(400645, 0, 0.7, sep=0.4), 0.0, 0, hp=70)
    put(out, grab(774268, 0, 0.5), 0.15, -5, hp=200)
    return out


def barricade_break_c(rng):
    """Two boards go, a beat apart, and a heavy thud of timber on the floor."""
    out = np.zeros(S(0.9))
    put(out, grab(873248, 1, 0.5, sep=0.4), 0.0, 0, hp=80)
    put(out, grab(400645, 1, 0.5, sep=0.4, rate=0.9), 0.2, -3, hp=70)
    put(out, grab(676730, 2, 0.3, rate=0.8), 0.45, -4, hp=60)
    return out


def _beep(rng, f, dur, lo, hi):
    n = S(dur)
    x = np.sin(dsp.phase(f * (1 + 0.01 * dsp.wander(rng, n, 30)), n)) * (1 + 0.5 * dsp.wander(rng, n, 80))
    x = (x + 0.3 * dsp.bandpass(dsp.noise(rng, n), f / 1.4, f * 1.4)) * dsp.curve(n, (0, 0), (0.004, 1.0), (dur - 0.01, 1.0), (dur, 0.0))
    return speaker(rng, x, lo, hi)


def objective_dock_a(rng):
    """A drive seated in a terminal: the click of the port, a heavy clunk of the dock, one beep through a cheap speaker."""
    out = np.zeros(S(0.6))
    put(out, grab(551315, 0, 0.25, sep=0.1), 0.0, -3, hp=200)
    put(out, grab(188194, 0, 0.35, rate=0.8), 0.04, 0, hp=60)
    put(out, _beep(rng, 1800.0, 0.09, 600, 4500), 0.38, -14)
    return out


def objective_dock_b(rng):
    """No beep: the USB disk pushed home, the clunk of a latch locking it."""
    out = np.zeros(S(0.6))
    put(out, grab(570611, 0, 0.3, sep=0.1), 0.0, -2, hp=150)
    put(out, grab(188194, 1, 0.4, rate=0.75), 0.12, 0, hp=60)
    return out


def objective_dock_c(rng):
    """Two low beeps through the speaker after the clunk: a terminal accepting the drive."""
    out = np.zeros(S(0.6))
    put(out, grab(551315, 0, 0.25, sep=0.1), 0.0, -4, hp=200)
    put(out, grab(188194, 0, 0.35, rate=0.7), 0.03, 0, hp=60)
    put(out, _beep(rng, 900.0, 0.07, 400, 3500), 0.30, -10)
    put(out, _beep(rng, 1200.0, 0.07, 400, 3500), 0.43, -10)
    return out


def objective_alarm_a(rng):
    """The evacuation alarm in the next hall: a real building siren, the high end rolled off, faded in and out."""
    out = np.zeros(S(2.4))
    put(out, window(405592, 2.4), 0.0, 0, hp=200, lp=3200)
    return out * dsp.curve(len(out), (0, 0), (0.25, 1.0), (2.1, 1.0), (2.4, 0))


def objective_alarm_b(rng):
    """Farther: a siren heard muffled through a building, the real recording of a test."""
    out = np.zeros(S(2.4))
    put(out, window(772971, 2.4), 0.0, 0, hp=150, lp=2500)
    return out * dsp.curve(len(out), (0, 0), (0.3, 1.0), (2.0, 1.0), (2.4, 0))


def objective_alarm_c(rng):
    """Both sirens at once, near and far, low-passed: a thicker, dirtier alarm."""
    out = np.zeros(S(2.4))
    put(out, window(405592, 2.4, rate=0.9), 0.0, 0, hp=200, lp=2000)
    put(out, window(772971, 2.4), 0.0, -4, hp=150, lp=2500)
    return out * dsp.curve(len(out), (0, 0), (0.3, 1.0), (2.0, 1.0), (2.4, 0))


# name -> (level LUFS, event ids, [A, B, C]); none is tied to a clip, so none is synced.
WORLD = {
    "door_open": (-22.0, (("door_open", 0.0, 1.0),), (door_open_a, door_open_b, door_open_c)),
    "door_close": (-22.0, (("door_close", 0.0, 1.0),), (door_close_a, door_close_b, door_close_c)),
    "barricade_build": (-22.0, (("barricade_build", 0.0, 1.0),), (barricade_build_a, barricade_build_b, barricade_build_c)),
    "barricade_break": (-22.0, (("barricade_break", 0.0, 1.0),), (barricade_break_a, barricade_break_b, barricade_break_c)),
    "objective_dock": (-24.0, (("objective_dock", 0.0, 1.0),), (objective_dock_a, objective_dock_b, objective_dock_c)),
    "objective_alarm": (-24.0, (("objective_alarm", 0.0, 1.0),), (objective_alarm_a, objective_alarm_b, objective_alarm_c)),
}

PLAYS = {
    "door_open": "A facility door opens (round state flip), heard in the room it opens into.",
    "door_close": "A facility door closes behind a survivor or the monster.",
    "barricade_build": "A survivor finishes barricading a door (after 3 s of building).",
    "barricade_break": "The monster breaks a barricade down (after 5 s of breaking).",
    "objective_dock": "A drive is docked in a terminal at the end of the 2 s hold.",
    "objective_alarm": "The facility-wide evacuation alarm, once, non-directional, at the listener.",
}

# Saturation for the sounds whose spikes would keep them under their loudness target ("peak-limited").
DRIVE = {"door_close": 3.0, "barricade_build": 3.0, "objective_dock": 3.0}


def option(name, i):
    level, ids, fns = WORLD[name]
    return Sound(name if i == 0 else f"{name}_{'abc'[i]}", finish(fns[i], DRIVE.get(name, 0.0), name not in ("objective_alarm", "objective_dock")), "world", level,
                 ids if i == 0 else (), False, False)


SOUNDS = [option(n, 0) for n in WORLD]
CANDIDATES = {n: [option(n, i) for i in range(3)] for n in WORLD}
