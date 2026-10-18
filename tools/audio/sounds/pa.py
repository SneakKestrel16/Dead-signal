"""The facility PA's spoken lines (family `state`, ClientSfx in src/feature/match_flow/client_sfx.gd). Script and
triggers: docs/audio/pa-lines.md (designer, 2026-10-18: keep the pause line, keep the final count, "go with a
generated voice for now"). The voice is Windows text-to-speech, rendered once by tools/audio/tts.py into
sources/tts/ and committed, so the build stays offline and deterministic. It is a stand-in until a recorded read
replaces it (README rule: voices on real recordings).

Every announcement opens on the shipped PA chime (pa_chime A); the countdown words (30, 10, 5-1) come bare so they
keep time. The voice goes through a ceiling horn (cues.speaker) and a hall tail: an old building PA, not a radio.

Candidates: A Zira through the horn, B David through the horn, C Zira through a smaller, harsher speaker.
"""
import numpy as np
from scipy import signal

from lib import dsp
from lib.master import Sound
from sounds.cues import S, put, speaker
from sounds.states import pa_chime_a

# id -> (line, chime first). Text is docs/audio/pa-lines.md; change both together.
LINES = {
    "pa_evac_timed": ("Attention. Facility evacuation is now in effect. All personnel proceed to the evacuation terminal.", True),
    "pa_evac_armed": ("Attention. Power restored. Evacuation terminal is armed.", True),
    "pa_t_120": ("Two minutes to facility lockdown.", True),
    "pa_t_60": ("One minute to facility lockdown.", True),
    "pa_t_30": ("Thirty seconds.", False),
    "pa_t_10": ("Ten seconds.", False),
    "pa_count_5": ("Five.", False),
    "pa_count_4": ("Four.", False),
    "pa_count_3": ("Three.", False),
    "pa_count_2": ("Two.", False),
    "pa_count_1": ("One.", False),
    "pa_lockdown": ("Lockdown complete. Evacuation is closed.", True),
    "pa_activation_start": ("Evacuation sequence initiated. Remain at the terminal.", True),
    "pa_activation_paused": ("Sequence paused. Operator absent.", False),
    "pa_activation_done": ("Evacuation sequence complete. Exit doors open.", True),
}
# candidate letter -> (SAPI voice, rate -10..10); tools/audio/tts.py renders sources/tts/<voice key>_<id>.wav
VOICES = {"zira": ("Microsoft Zira Desktop", -1), "david": ("Microsoft David Desktop", -1)}
CHIME_GAP_S = 0.25  # silence between the chime's ring-out and the first word
LEVEL = -24.0  # as loud as the chime it follows (states.py pa_chime)


def tail(rng, x, secs=0.9, mix=0.35):
    """A hall's tail: the dry line plus itself through decaying band-passed noise (a stairwell of concrete)."""
    ir = dsp.bandpass(dsp.noise(rng, S(secs)), 200, 4000) * np.exp(-np.arange(S(secs)) / S(secs / 5))
    wet = signal.fftconvolve(x, ir)
    out = np.concatenate([x, np.zeros(len(wet) - len(x))])
    return dsp.norm(out) + mix * dsp.norm(wet)


def line(pid, voice, lo, hi, drive):
    def build(rng):
        x = dsp.recording(f"tts/{voice}_{pid}")
        x = dsp.deline(tail(rng, speaker(rng, x, lo, hi, drive=drive)))  # the horn's mains hum, capped
        if not LINES[pid][1]:
            return dsp.lowpass(x, 13000)
        chime = pa_chime_a(rng)
        out = np.zeros(len(chime) + S(CHIME_GAP_S) + len(x))
        put(out, chime, 0.0, -3)
        put(out, x, (len(chime) / dsp.SR) + CHIME_GAP_S, 0)
        return dsp.lowpass(out, 13000)
    return build


def option(pid, i):
    voice, lo, hi, drive = (("zira", 250, 5000, 1.5), ("david", 250, 5000, 1.5), ("zira", 400, 3500, 2.5))[i]
    ids = ((f"pa/{pid.removeprefix('pa_')}", 0.0, 1.0),) if i == 0 else ()
    return Sound(pid if i == 0 else f"{pid}_{'abc'[i]}", line(pid, voice, lo, hi, drive), "state", LEVEL, ids)


PLAYS = {pid: f'"{text}"' for pid, (text, _) in LINES.items()}
SOUNDS = [option(p, 0) for p in LINES]
CANDIDATES = {p: [option(p, i) for i in range(3)] for p in LINES}
