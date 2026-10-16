"""Building blocks for the sound pipeline (docs/audio/pipeline-handoff.md Part 3).

Everything is mono float64 at SR = 44100 (the engine's mix rate, so nothing is resampled in game).
Textbook recipes (a falling sine for weight, few clean modes for metal, a swept narrow band) make
instruments, not objects: build from noise bands, dense modes and recordings. See docs/audio/gotchas.md.
"""
import functools
import math
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SR = 44100
SOURCES = Path(__file__).resolve().parent.parent / "sources"


def samples(s):
    return int(round(s * SR))


def clock(n):
    return np.arange(n) / SR


def norm(x):
    return x / (np.max(np.abs(x)) + 1e-12)


def noise(rng, n):
    return rng.standard_normal(n)


def colored(rng, n, slope):
    """1/f**slope noise (1 pink, 2 brown), shaped in the frequency domain (circular by construction)."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    spec[0] = 0.0
    spec[1:] /= f[1:] ** (slope / 2)
    x = np.fft.irfft(spec, n)
    return x / (np.std(x) + 1e-12)


def phase(freq, n):
    return 2 * np.pi * np.cumsum(np.broadcast_to(np.asarray(freq, float), (n,))) / SR


# Filters: Butterworth via scipy sos, designs cached (a grain is cheaper to filter than to design for).
@functools.lru_cache(maxsize=4096)
def _design(kind, f, order):
    return signal.butter(order, list(f) if isinstance(f, tuple) else f, btype=kind, fs=SR, output="sos")


def lowpass(x, f, order=2):
    return signal.sosfilt(_design("lowpass", float(f), order), x)


def highpass(x, f, order=2):
    return signal.sosfilt(_design("highpass", float(f), order), x)


def bandpass(x, lo, hi, order=2):
    return signal.sosfilt(_design("bandpass", (float(lo), float(hi)), order), x)


def biquad(kind, f0, q=0.7071, gain_db=0.0):
    """One RBJ audio-EQ cookbook section as an sos row: high, band, peak or highshelf."""
    a_ = 10 ** (gain_db / 40)
    w = 2 * np.pi * min(f0, 0.45 * SR) / SR
    cw, alpha = np.cos(w), np.sin(w) / (2 * q)
    a = [1 + alpha, -2 * cw, 1 - alpha]
    if kind == "high":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
    elif kind == "band":
        b = [alpha, 0.0, -alpha]
    elif kind == "peak":
        b = [1 + alpha * a_, -2 * cw, 1 - alpha * a_]
        a = [1 + alpha / a_, -2 * cw, 1 - alpha / a_]
    elif kind == "highshelf":
        s = 2 * np.sqrt(a_) * alpha
        b = [a_ * ((a_ + 1) + (a_ - 1) * cw + s), -2 * a_ * ((a_ - 1) + (a_ + 1) * cw), a_ * ((a_ + 1) + (a_ - 1) * cw - s)]
        a = [(a_ + 1) - (a_ - 1) * cw + s, 2 * ((a_ - 1) - (a_ + 1) * cw), (a_ + 1) - (a_ - 1) * cw - s]
    else:
        raise ValueError(kind)
    b, a = np.asarray(b), np.asarray(a)
    return np.hstack([b / a[0], a / a[0]])[None, :]


def eq(x, kind, f0, q=0.7071, gain_db=0.0):
    return signal.sosfilt(biquad(kind, f0, q, gain_db), x)


def notch(x, f0, q=8.0):
    """Narrow notch (a recording's hidden note, a mains line)."""
    b, a = signal.iirnotch(f0, q, fs=SR)
    return signal.filtfilt(b, a, x)


# Envelopes
def curve(n, *points):
    """Piecewise linear through (seconds, value)."""
    ts, vs = zip(*points)
    return np.interp(clock(n), ts, vs)


def decay(n, tau, at=0.0):
    t = clock(n) - at
    return np.where(t >= 0, np.exp(-np.maximum(t, 0) / tau), 0.0)


def wander(rng, n, rate):
    """Smooth random control signal in [-1, 1]."""
    x = lowpass(rng.standard_normal(n), rate)
    return x / (np.max(np.abs(x)) + 1e-12)


# Bodies
def bands(rng, n, lo, hi, level, tau, per_octave=3):
    """White noise split into fractional-octave bands, each at level(centre), dying in tau(centre)."""
    t = clock(n)
    w = rng.standard_normal(n)
    out = np.zeros(n)
    edges = lo * 2 ** (np.arange(int(np.log2(hi / lo) * per_octave) + 1) / per_octave)
    for a, b in zip(edges[:-1], edges[1:]):
        if a < 0.44 * SR:
            fc = np.sqrt(a * b)
            out += level(fc) * bandpass(w, a, min(b, 0.45 * SR)) * np.exp(-t / tau(fc))
    return out


def octaves(points):
    """{Hz: value} table read between points by octave."""
    fs = sorted(points)
    return lambda f: float(np.interp(np.log2(f), np.log2(fs), [points[k] for k in fs]))


def thump(rng, n, cutoff, tau):
    """Low weight of an impact: low-passed noise. NOT a falling sine (that is a kick drum)."""
    return norm(lowpass(noise(rng, n), cutoff, 4) * decay(n, tau))


# Mixing
def place(into, sound, at):
    """Add `sound` into `into` from `at` seconds."""
    i = samples(at)
    m = min(len(sound), len(into) - i)
    if m > 0:
        into[i:i + m] += sound[:m]
    return into


def drive(x, amount):
    """tanh saturation with the peak kept: loud without peaking."""
    peak = np.max(np.abs(x)) + 1e-12
    return np.tanh(amount * x / peak) / np.tanh(amount) * peak


def loop(x, overlap):
    """Seamless loop for NOISY textures: crossfade the overrun into the head at equal power."""
    m = samples(overlap)
    length = len(x) - m
    u = np.arange(m) / m
    y = x[:length].copy()
    y[:m] = x[:m] * np.sin(0.5 * np.pi * u) + x[length:] * np.cos(0.5 * np.pi * u)
    return y


def loop_aligned(x, length, overlap):
    """Loop of exactly `length` seconds cut from `x` (at least length + overlap + 1 s long). The start is searched
    (first second, hop 16 samples) for the best normalised correlation between the head and the overrun, so a hum
    or a pipe tone meets itself in phase at the seam; the crossfade is linear when the two correlate (equal-power
    would swell the shared tone 3 dB) and equal-power when they do not."""
    n, m = samples(length), samples(overlap)
    best, best_c = 0, -2.0
    for s in range(0, min(SR, len(x) - n - m), 16):
        head, tail = x[s:s + m], x[s + n:s + n + m]
        c = float(np.dot(head, tail) / (np.linalg.norm(head) * np.linalg.norm(tail) + 1e-12))
        if c > best_c:
            best, best_c = s, c
    u = np.arange(m) / m
    c = max(0.0, best_c)
    fin = (1 - u) * c + np.cos(0.5 * np.pi * u) * (1 - c)
    fout = u * c + np.sin(0.5 * np.pi * u) * (1 - c)
    y = x[best:best + n].copy()
    y[:m] = y[:m] * fout + x[best + n:best + n + m] * fin
    return y


# Recordings and files
def read_wav(path):
    """(float array mono, sample rate) of a 16-bit WAV; stereo is averaged."""
    with wave.open(str(path)) as w:
        sr, ch = w.getframerate(), w.getnchannels()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2") / 32768.0
    return (x.reshape(-1, ch).mean(axis=1) if ch > 1 else x), sr


def to_sr(x, sr):
    """Resample to the mix rate (polyphase)."""
    if sr == SR:
        return x
    g = math.gcd(SR, sr)
    return signal.resample_poly(x, SR // g, sr // g)


@functools.cache
def _recording(sound_id):
    x, sr = read_wav(SOURCES / f"{sound_id}.wav")
    x = to_sr(x, sr)
    x.flags.writeable = False
    return x


def recording(sound_id, start=0.0, end=None):
    """A committed recording (sources/ID.wav), as deterministic as noise."""
    x = _recording(sound_id)
    return x[samples(start): None if end is None else samples(end)].copy()


def deline(x, cap_db=10.0):
    """Cap every lasting spectral line at `cap_db` over its neighbourhood (long-term spectrum, 5 Hz bins): a hum
    or fan whine left at full strength is a note in a dry file, further out than it ever stands in a room.
    Peaking cuts, Q 15, by the excess over the cap. A recording heard at distance sits ~8-17 dB over its noise."""
    for _ in range(3):  # a Q-15 cut lands a few dB short of its target at the measuring resolution: repeat
        f, _, s = signal.spectrogram(x, SR, nperseg=8192, noverlap=4096)
        ls = np.median(10 * np.log10(s + 1e-20), axis=1)
        prom = ls - signal.medfilt(ls, 41)
        peaks, _ = signal.find_peaks(prom, height=cap_db, distance=3)
        for i in peaks:
            if 30 < f[i] < 18000 and ls[i] > ls.max() - 60:  # not the MP3 preview's quiet lines above 15 kHz
                x = eq(x, "peak", f[i], 8.0, -(prom[i] - cap_db)) if f[i] < 1000 else notch(x, f[i], 30.0)
    return x


def declick(x, over_db=4.0):
    """Take out ticks and knocks: where the band above 2 kHz, and again above 5 kHz (2 ms frames), stands more than
    `over_db` over its own running median (200 ms), pull that band back to the median. The wash is left alone."""
    f = samples(0.002)
    for fc in (2000, 5000, 2000, 5000):
        hf = highpass(x, fc)
        env = np.sqrt(np.mean(hf[: len(hf) // f * f].reshape(-1, f) ** 2, axis=1)) + 1e-9
        g = np.minimum(1.0, signal.medfilt(env, 99) * 10 ** (over_db / 20) / env)
        g = np.interp(np.arange(len(x)), (np.arange(len(g)) + 0.5) * f, np.convolve(g, np.ones(3) / 3, "same"))
        x = x - hf * (1.0 - g)
    return x


def steady_start(x, seconds):
    """Start (samples) of the `seconds`-long stretch of `x` that stays closest to its own median level, over the
    whole band and above 1 kHz (10 ms frames, hop 0.25 s): the stretch with the fewest knocks, ticks and steps."""
    f = samples(0.01)
    w = int(seconds / 0.01)
    devs = []
    for y in (x, highpass(x, 1000), highpass(x, 5000)):
        db = 10 * np.log10(np.mean(y[: len(y) // f * f].reshape(-1, f) ** 2, axis=1) + 1e-12)
        devs.append(db)
    best, best_s = None, 0
    for s in range(0, max(1, len(devs[0]) - w), 25):
        score = max(np.max(np.abs(d[s:s + w] - np.median(d[s:s + w]))) for d in devs)
        if best is None or score < best:
            best, best_s = score, s
    return best_s * f


def legacy(family, name):
    """The placeholder shipped before the pipeline (sources/legacy/<family>/<name>.wav), at the mix rate."""
    x, sr = read_wav(SOURCES / "legacy" / family / f"{name}.wav")
    return to_sr(x, sr)
