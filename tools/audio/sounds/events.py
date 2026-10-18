"""Event and action sounds (family `event`): the drive, install alert, relay, rescue and elimination one-shots of
WorldSfx, the search rattle of HidingSpots, the takedown, gasp and action loops of BodySfx, and the face-unlock and
ping ticks of ClientSfx (src/feature/match_flow/, src/feature/survivor_defense/hiding_spots.gd). Cut from real CC0
recordings (sources/events.toml); reused from other manifests: the USB dock (570611, 551315, world.toml), the alarm
bells (572529, 743963, scares.toml), the contactor (807384, scares.toml), the stinger strings and hits (683256,
373169, 684805, scares.toml), the hammering (811941, 676730, 707525, world.toml), heavy breathing (874174,
cues.toml), clicks (323746, 740253, 213004, ui.toml) and the metal rulers (376204, scares.toml). Grounded foley
only: no oscillators, no sci-fi (designer).

Timing (source: the sfx classes; lengths are inference, playtest settles them):
- drive_clatter: a carried drive dropped (the carrier downed or seized), 0.8 s.
- drive_eject: the drive pulled from the terminal by the shapeshifter, 0.6 s.
- install_alert: the shapeshifter's own cue that an install began somewhere, 2.5 s, heard at the listener.
- relay_clack: at the light switch as the blackout ends and the relays pull in, 0.8 s.
- rescue_relief: the own body back on its feet, 1.5 s, at the listener.
- eliminated_sting: a survivor eliminated, heard by everyone, 3 s.
- search_rattle: a hiding spot searched, at the spot, 1.2 s.
- takedown_struggle: a body Seized, loud, 1.5 s. release_gasp: set free by a stun, 1.0 s.
- interact_loop, barricade_loop, rescue_loop: loops at the body while the action runs.
- face_unlock: a borrowable face becomes available, shapeshifter only, quiet, 0.3 s.
- ping/tick: a ping, 0.15 s. ping/warning: a warning ping, sharper, 0.6 s.
The shipped take is candidate A; B and C (name_b, name_c) are the other directions for the review page.
"""
import numpy as np

from lib import dsp
from lib.master import Sound
from sounds.cues import S, at, body, grab, put, reverse, shape, speaker, window
from sounds.states import _loop


# ---- drive clatter ----
def drive_clatter_a(rng):
    """A hollow plastic case hitting the floor and bouncing once."""
    out = np.zeros(S(0.8))
    put(out, grab(697092, 0, 0.45), 0.0, 0, hp=150)
    put(out, grab(697091, 0, 0.25), 0.22, -9, hp=200)
    return out


def drive_clatter_b(rng):
    """A small plastic thing dropped and skidding."""
    out = np.zeros(S(0.8))
    put(out, shape(grab(505962, 0, 0.75), 0.001, 0.2), 0.0, 0, hp=150)
    return out


def drive_clatter_c(rng):
    """Heavier: a cassette case smashing down, a piece breaking off."""
    out = np.zeros(S(0.8))
    put(out, shape(grab(272065, 0, 0.75, sep=0.6), 0.001, 0.2), 0.0, 0, hp=100)
    return out


# ---- drive eject ----
def drive_eject_a(rng):
    """The drive pulled out of its port."""
    out = np.zeros(S(0.6))
    put(out, grab(570611, 1, 0.5), 0.0, 0, hp=200)
    return out


def drive_eject_b(rng):
    """A flash drive's click out of a port, with the case knocking."""
    out = np.zeros(S(0.6))
    put(out, grab(551315, 0, 0.4), 0.0, 0, hp=200)
    put(out, grab(697091, 0, 0.2), 0.25, -12, hp=300)
    return out


def drive_eject_c(rng):
    """The port's click and a relay dropping out in the terminal."""
    out = np.zeros(S(0.6))
    put(out, grab(570611, 1, 0.4), 0.0, 0, hp=200)
    put(out, grab(740253, 0, 0.1), 0.12, -6, hp=300)
    return out


# ---- install alert ----
def install_alert_a(rng):
    """An alarm bell somewhere far off in the building, behind walls."""
    out = np.zeros(S(2.5))
    put(out, shape(window(572529, 2.4), 0.15, 0.8), 0.0, 0, lp=1200)
    return out


def install_alert_b(rng):
    """A small hammer bell, two short bursts, muffled."""
    out = np.zeros(S(2.5))
    put(out, shape(window(743963, 0.6), 0.02, 0.15), 0.0, 0, lp=2000)
    put(out, shape(window(743963, 0.6), 0.02, 0.15), 0.9, -2, lp=2000)
    return out


def install_alert_c(rng):
    """The far bell through the facility's cheap ceiling speaker."""
    out = np.zeros(S(2.5))
    put(out, speaker(rng, shape(window(572529, 2.4), 0.15, 0.8), 400, 3500, drive=1.5), 0.0, 0)
    return out


# ---- relay clack ----
def relay_clack_a(rng):
    """Large relays pulling in, close."""
    out = np.zeros(S(0.8))
    put(out, grab(870770, 0, 0.7), 0.0, 0, hp=80)
    return out


def relay_clack_b(rng):
    """A rotary switch and its relay, a double click."""
    out = np.zeros(S(0.8))
    put(out, grab(112844, 0, 0.7, sep=0.5), 0.0, 0, hp=100)
    return out


def relay_clack_c(rng):
    """Heavier: the contactor slamming in with a knocker relay on top."""
    out = np.zeros(S(0.8))
    put(out, grab(807384, 0, 0.6), 0.0, 0, hp=60)
    put(out, grab(384701, 0, 0.4), 0.02, -6, hp=200)
    return out


# ---- rescue relief ----
def rescue_relief_a(rng):
    """A gasp of relief."""
    out = np.zeros(S(1.5))
    put(out, shape(at(618526, 0.0, 1.4), 0.01, 0.3), 0.0, 0, hp=100)
    return out


def rescue_relief_b(rng):
    """A short sigh with relief."""
    out = np.zeros(S(1.5))
    put(out, shape(at(348288, 0.0, 0.9), 0.01, 0.2), 0.0, 0, hp=100)
    return out


def rescue_relief_c(rng):
    """A longer relieved breath out."""
    out = np.zeros(S(1.5))
    put(out, shape(window(724232, 1.4), 0.05, 0.4), 0.0, 0, hp=100)
    return out


# ---- eliminated sting ----
def eliminated_sting_a(rng):
    """A low orchestral hit, the contrabass trembling under it, fading."""
    out = np.zeros(S(3.0))
    put(out, shape(grab(683256, 1, 1.5, sep=2.0, rate=0.75), 0.002, 0.6), 0.0, 0, lp=3500)
    put(out, shape(window(373169, 2.8, rate=0.9), 0.2, 1.2), 0.05, -4)
    return out


def eliminated_sting_b(rng):
    """A deep percussion hit in reverb, the strings swelling after."""
    out = np.zeros(S(3.0))
    put(out, shape(grab(684805, 0, 2.8, sep=2.0), 0.002, 1.0), 0.0, 0)
    put(out, shape(window(374487, 2.4, rate=0.8), 0.6, 1.0), 0.4, -8, lp=3000)
    return out


def eliminated_sting_c(rng):
    """Backwards strings swelling into the hit."""
    out = np.zeros(S(3.0))
    put(out, shape(reverse(window(373169, 1.6)), 0.05, 0.02), 0.0, -4)
    put(out, shape(grab(683256, 1, 1.4, sep=2.0, rate=0.75), 0.002, 0.6), 1.6, 0, lp=3500)
    return out


# ---- search rattle ----
def search_rattle_a(rng):
    """An iron locker shaken hard."""
    out = np.zeros(S(1.2))
    put(out, shape(window(403540, 1.15), 0.01, 0.2), 0.0, 0, hp=80)
    return out


def search_rattle_b(rng):
    """Loose metal rattling, lighter."""
    out = np.zeros(S(1.2))
    put(out, shape(window(849797, 1.15), 0.01, 0.2), 0.0, 0, hp=100)
    return out


def search_rattle_c(rng):
    """A locker door yanked: the slam's rattle, then the shake."""
    out = np.zeros(S(1.2))
    put(out, grab(450792, 0, 0.6, sep=1.0), 0.0, 0, hp=80)
    put(out, shape(window(403540, 0.7), 0.01, 0.2), 0.45, -4, hp=80)
    return out


# ---- takedown struggle ----
def takedown_struggle_a(rng):
    """A struggle: bodies and clothing thrashing, a grunt in it."""
    out = np.zeros(S(1.5))
    put(out, shape(window(527744, 1.45), 0.005, 0.3), 0.0, 0, hp=80)
    return out


def takedown_struggle_b(rng):
    """Cloth in a fight with a man's strained grunt over it."""
    out = np.zeros(S(1.5))
    put(out, shape(window(852785, 1.45), 0.005, 0.3), 0.0, 0, hp=100)
    put(out, shape(grab(481753, 0, 0.8, sep=0.6), 0.005, 0.2), 0.15, -3, hp=120)
    return out


def takedown_struggle_c(rng):
    """Heavier: the struggle with a thump as the body is pinned."""
    out = np.zeros(S(1.5))
    put(out, shape(window(527744, 1.45), 0.005, 0.3), 0.0, -2, hp=80)
    put(out, body(rng, 0.3, 80, 0.08), 0.0, -4)
    put(out, shape(grab(481753, 0, 0.8, sep=0.6), 0.005, 0.2), 0.3, -6, hp=120)
    return out


# ---- release gasp ----
def release_gasp_a(rng):
    """A sharp gasp for air."""
    out = np.zeros(S(1.0))
    put(out, shape(grab(436781, 0, 0.9, sep=0.6), 0.005, 0.25), 0.0, 0, hp=100)
    return out


def release_gasp_b(rng):
    """A gasp, then breath let out."""
    out = np.zeros(S(1.0))
    put(out, shape(at(618526, 0.0, 0.95), 0.005, 0.25), 0.0, 0, hp=100)
    return out


def release_gasp_c(rng):
    """Ragged breathing, the first breath free."""
    out = np.zeros(S(1.0))
    put(out, shape(window(638611, 0.95), 0.01, 0.25), 0.0, 0, hp=100)
    return out


# ---- action loops ----
def interact_loop_a(rng):
    """Hands working through a toolbox: metal clinks and shifting."""
    return _loop(860292, 120, 10000)


def interact_loop_b(rng):
    """Desk handling: objects picked up, set down, paper."""
    return _loop(631823, 120, 10000)


def interact_loop_c(rng):
    """Keys typed on an old keyboard, a terminal being worked."""
    return _loop(685984, 150, 10000, length=4.0, ov=0.8)


def barricade_loop_a(rng):
    """Nails hammered into wood at a working pace."""
    return _loop(811941, 60, 10000, length=5.0, ov=0.6)


def barricade_loop_b(rng):
    """Hammers and mallets on beams and planks."""
    return _loop(676730, 60, 10000)


def barricade_loop_c(rng):
    """One hammer on a nail, slower, in a loop of its blows."""
    return _loop(707525, 60, 10000, length=3.0, ov=0.4)


def rescue_loop_a(rng):
    """Cloth grabbed and pulled, someone hauled up."""
    return _loop(237047, 100, 9000)


def rescue_loop_b(rng):
    """Clothes rustling with heavy breathing under them."""
    return _loop(481075, 100, 9000) + 0.5 * _loop(874174, 120, 8000)


def rescue_loop_c(rng):
    """The cloth grabs with the breathing, rougher."""
    return _loop(237047, 100, 9000) + 0.6 * _loop(874174, 120, 8000)


# ---- face unlock ----
def face_unlock_a(rng):
    """A camera shutter, soft: a face taken."""
    out = np.zeros(S(0.3))
    put(out, grab(824848, 0, 0.25), 0.0, 0, hp=300)
    return out


def face_unlock_b(rng):
    """A DSLR's focus tick and shutter."""
    out = np.zeros(S(0.3))
    put(out, grab(515147, 0, 0.25), 0.0, 0, hp=300)
    return out


def face_unlock_c(rng):
    """A tiny relay tick, barely there."""
    out = np.zeros(S(0.3))
    put(out, grab(740253, 0, 0.1), 0.0, 0, hp=300)
    put(out, grab(740253, 0, 0.1, rate=1.2), 0.09, -6, hp=300)
    return out


# ---- ping ticks ----
def ping_tick_a(rng):
    """A pen click."""
    out = np.zeros(S(0.15))
    put(out, grab(323746, 0, 0.1), 0.0, 0, hp=300)
    return out


def ping_tick_b(rng):
    """A mouse click, a little room around it."""
    out = np.zeros(S(0.15))
    put(out, grab(213004, 0, 0.12), 0.0, 0, hp=300)
    return out


def ping_tick_c(rng):
    """A relay tick."""
    out = np.zeros(S(0.15))
    put(out, grab(740253, 0, 0.1), 0.0, 0, hp=300)
    return out


def ping_warning_a(rng):
    """A small metal bell struck with a spoon."""
    out = np.zeros(S(0.6))
    put(out, shape(grab(549897, 0, 0.58), 0.001, 0.2), 0.0, 0, hp=300)
    return out


def ping_warning_b(rng):
    """A metal ruler struck on a staircase."""
    out = np.zeros(S(0.6))
    put(out, shape(grab(376204, 0, 0.58, sep=0.4), 0.001, 0.2), 0.0, 0, hp=300)
    return out


def ping_warning_c(rng):
    """A knocker relay's loud click, twice."""
    out = np.zeros(S(0.6))
    put(out, grab(384701, 0, 0.25), 0.0, 0, hp=200)
    put(out, grab(384701, 0, 0.25), 0.18, -3, hp=200)
    return out


# name -> (LUFS, bank ids, loop, (A, B, C))
EVENTS = {
    "drive_clatter": (-24.0, (("drive_clatter", 0.0, 1.0),), False, (drive_clatter_a, drive_clatter_b, drive_clatter_c)),
    "drive_eject": (-24.0, (("drive_eject", 0.0, 1.0),), False, (drive_eject_a, drive_eject_b, drive_eject_c)),
    "install_alert": (-26.0, (("install_alert", 0.0, 1.0),), False,
                      (install_alert_a, install_alert_b, install_alert_c)),
    "relay_clack": (-22.0, (("relay_clack", 0.0, 1.0),), False, (relay_clack_a, relay_clack_b, relay_clack_c)),
    "rescue_relief": (-26.0, (("rescue_relief", 0.0, 1.0),), False,
                      (rescue_relief_a, rescue_relief_b, rescue_relief_c)),
    "eliminated_sting": (-24.0, (("eliminated_sting", 0.0, 1.0),), False,
                         (eliminated_sting_a, eliminated_sting_b, eliminated_sting_c)),
    "search_rattle": (-22.0, (("search_rattle", 0.0, 1.0),), False,
                      (search_rattle_a, search_rattle_b, search_rattle_c)),
    "takedown_struggle": (-20.0, (("takedown_struggle", 0.0, 1.0),), False,
                          (takedown_struggle_a, takedown_struggle_b, takedown_struggle_c)),
    "release_gasp": (-22.0, (("release_gasp", 0.0, 1.0),), False, (release_gasp_a, release_gasp_b, release_gasp_c)),
    "interact_loop": (-32.0, (("interact_loop", 0.0, 1.0),), True, (interact_loop_a, interact_loop_b, interact_loop_c)),
    "barricade_loop": (-26.0, (("barricade_loop", 0.0, 1.0),), True,
                       (barricade_loop_a, barricade_loop_b, barricade_loop_c)),
    "rescue_loop": (-30.0, (("rescue_loop", 0.0, 1.0),), True, (rescue_loop_a, rescue_loop_b, rescue_loop_c)),
    "face_unlock": (-32.0, (("face_unlock", 0.0, 1.0),), False, (face_unlock_a, face_unlock_b, face_unlock_c)),
    "ping_tick": (-30.0, (("ping/tick", 0.0, 1.0),), False, (ping_tick_a, ping_tick_b, ping_tick_c)),
    "ping_warning": (-26.0, (("ping/warning", 0.0, 1.0),), False, (ping_warning_a, ping_warning_b, ping_warning_c)),
}

PLAYS = {
    "drive_clatter": "A carried drive hits the floor when its carrier goes down or is seized. Heard nearby.",
    "drive_eject": "The shapeshifter pulls the drive out of the terminal. Heard nearby.",
    "install_alert": "Only the shapeshifter hears it: a drive install began somewhere in the facility.",
    "relay_clack": "At the light switch as a blackout ends and the lights come back.",
    "rescue_relief": "Your own body helped back to its feet. Only you hear it.",
    "eliminated_sting": "A survivor is eliminated. Everyone hears it.",
    "search_rattle": "The shapeshifter searches a hiding spot, empty or not. Heard at the spot.",
    "takedown_struggle": "A survivor is seized by the shapeshifter. Loud, at the victim.",
    "release_gasp": "A seized survivor set free by a taser stun.",
    "interact_loop": "Loops at a body while it works an objective (fuse box, terminal, a fake hold). Quiet.",
    "barricade_loop": "Loops at a body while it builds or breaks a barricade.",
    "rescue_loop": "Loops at a body kneeling to rescue a downed survivor.",
    "face_unlock": "Only the shapeshifter hears it: a face becomes available to borrow. Quiet.",
    "ping_tick": "At the point of every ping.",
    "ping_warning": "At the point of a warning ping, sharper than the plain tick.",
}


def option(name, i):
    level, ids, loop, fns = EVENTS[name]
    # nothing above 13 kHz (the MP3 previews' lines); a loop is band-limited as a circle in _loop instead
    build = fns[i] if loop else (lambda rng, fn=fns[i]: dsp.lowpass(fn(rng), 13000))
    return Sound(name if i == 0 else f"{name}_{'abc'[i]}", build, "event", level, ids if i == 0 else (), loop, False)


SOUNDS = [option(n, 0) for n in EVENTS]
CANDIDATES = {n: [option(n, i) for i in range(3)] for n in EVENTS}
