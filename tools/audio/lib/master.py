"""Catalogue entry, seeding, mastering and WAV bytes (pipeline-handoff.md Parts 2 and 6)."""
import io
import struct
import wave
import zlib
from collections.abc import Callable
from dataclasses import dataclass

import numpy as np
from scipy import signal

from lib import dsp

CEILING_DB = -1.0  # hearing protection: nothing ships above -1 dBFS
# Family (assets/audio/<family>/) -> (target LUFS over the loudest 400 ms, default bus).
# Inference: no GDD gives numbers; the order follows the GDDs' priorities (objective noise loudest, ADR-0013 s1
# gameplay cues never masked, beds quiet under everything). The stinger is levelled at the bed's level minus a
# margin so ScareAudio's +stinger_max_db_rel (6 dB, data/knobs/scare.tres) puts it at most 6 dB over the bed
# (scare-events rule 26 / SE-8 AC-2).
FAMILIES = {
    "foot": (-24.0, "GameplayCues"),
    "cue": (-20.0, "GameplayCues"),
    "world": (-22.0, "WorldSFX"),
    "voice": (-22.0, "Voice"),
    "scare": (-20.0, "ScareSFX"),
    "stinger": (-30.5, "Stinger"),
    "ambience": (-30.0, "Ambience"),
    "ui": (-26.0, "SFX"),
    "state": (-26.0, "SFX"),  # ClientSfx: breathing, heartbeat, flashlight, generator, terminal tone, PA, stings
    "event": (-22.0, "WorldSFX"),  # WorldSfx, BodySfx, HidingSpots and ClientSfx event and action sounds
}


@dataclass(frozen=True)
class Sound:
    name: str
    build: Callable[..., np.ndarray]  # rng -> mono float array at 44.1 kHz (rng, variant -> ... when variants > 1)
    family: str
    level: float | None  # target LUFS over the loudest 400 ms; None = ship as built (legacy placeholder)
    ids: tuple = ()  # sound bank events: (event id, volume_db, pitch_scale)
    loop: bool = False  # seamless loop: never trimmed, smpl chunk in the WAV
    synced: bool = False  # timed to a clip: keep the lead-in silence
    variants: int = 1  # takes, each from its own seed; the bank plays them through an AudioStreamRandomizer
    heard_as: str = ""  # a kept candidate seeds from the name it was picked under (handoff Part 9), so it keeps its bytes

    def file(self, variant=0):
        return f"{self.name}_{variant}.wav" if self.variants > 1 else f"{self.name}.wav"

    def path(self, variant=0):
        return f"assets/audio/{self.family}/{self.file(variant)}"


@dataclass
class Take:
    sound: Sound
    x: np.ndarray
    lufs: float
    peak_db: float
    limited: bool
    variant: int = 0

    def file(self):
        return self.sound.file(self.variant)

    def path(self):
        return self.sound.path(self.variant)


def seed(name, variant=0):
    # crc32, not hash(): Python salts str hashes per run
    return np.random.default_rng([zlib.crc32(name.encode()), variant])


def loudness(x):
    """Momentary loudness at its loudest, LUFS: K-weighted mean square over the loudest 400 ms (BS.1770)."""
    k = signal.sosfilt(np.vstack([dsp.biquad("highshelf", 1681.97, 0.7072, 4.0), dsp.biquad("high", 38.13, 0.5003)]), x)
    w = dsp.samples(0.4)
    sq = np.concatenate([[0.0], np.cumsum(np.pad(k ** 2, (0, max(0, w - len(k)))))])
    return -0.691 + 10 * np.log10(np.max(sq[w:] - sq[:-w]) / w + 1e-20)


def trim(x, floor_db=-60.0, head=True):
    loud = np.nonzero(np.abs(x) > np.max(np.abs(x)) * 10 ** (floor_db / 20))[0]
    start = max(0, loud[0] - dsp.samples(0.001)) if head else 0
    y = x[start: loud[-1] + dsp.samples(0.02)].copy()
    m = min(len(y), dsp.samples(0.01))
    y[-m:] *= np.linspace(1.0, 0.0, m)
    return y


def render(sound, variant=0):
    rng = seed(sound.heard_as or sound.name, variant)
    x = np.asarray(sound.build(rng, variant) if sound.variants > 1 else sound.build(rng), float)  # takes know their index
    if sound.level is None:
        peak = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
        y = x * 10 ** (min(0.0, CEILING_DB - peak) / 20)  # as built; only a resampling overshoot is pulled under the ceiling
    else:
        if sound.loop:
            x = dsp.highpass(np.tile(x, 2), 25)[len(x):]  # filtered as a circle: the seam sees what every sample does
        else:
            x = trim(dsp.highpass(x, 25), head=not sound.synced)
        gain_db = sound.level - loudness(x)
        peak_db = 20 * np.log10(np.max(np.abs(x))) + gain_db
        if peak_db > CEILING_DB:
            gain_db -= peak_db - CEILING_DB
        y = x * 10 ** (gain_db / 20)
    peak = 20 * np.log10(np.max(np.abs(y)) + 1e-12)
    limited = sound.level is not None and loudness(y) < sound.level - 0.05
    return Take(sound, y, loudness(y), peak, limited, variant)


def wav_bytes(x, loop=False):
    """Mono 16-bit PCM; `wave` writes no timestamp, so same samples = same bytes. A loop carries a `smpl`
    chunk with one forward loop over the whole file (Godot's importer reads it, loop mode 'Detect From WAV')."""
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(dsp.SR)
        w.writeframes((np.clip(x, -1.0, 1.0) * 32767).round().astype("<i2").tobytes())
    data = buf.getvalue()
    if loop:
        body = struct.pack("<9I", 0, 0, round(1e9 / dsp.SR), 60, 0, 0, 0, 1, 0) + struct.pack("<6I", 0, 0, 0, len(x) - 1, 0, 0)
        chunk = b"smpl" + struct.pack("<I", len(body)) + body
        data = data[:4] + struct.pack("<I", len(data) + len(chunk) - 8) + data[8:] + chunk
    return data


def pcm(data):
    """int16 samples of WAV bytes (for --check, which tolerates 1-step wheel differences between machines)."""
    with wave.open(io.BytesIO(data)) as w:
        return np.frombuffer(w.readframes(w.getnframes()), "<i2")
