# /// script
# requires-python = ">=3.12"
# dependencies = ["numpy==2.5.3", "scipy==1.18.1", "soundfile==0.13.1"]
# ///
"""Measure recordings and compare a take against them (pipeline-handoff.md Part 5).

    uv run tools/audio/analyze.py 788231                      # a source id (sources/ID.wav)
    uv run tools/audio/analyze.py ref.wav --against assets/audio/ambience/amb_a.wav

A source is a source id, or any file soundfile reads (wav, ogg, flac, mp3). Prints, over the whole file and over
its events: level per third-octave band (63 Hz-12.7 kHz) against the loudest band, hold (time within 6 / 20 dB of
the peak), crest factor, spectral flatness (near 1 is noise), graininess (bursts per 100 ms above 2 kHz), tonal
blips (short peaks 12 dB over their neighbours) and any lasting tone (a line 15 dB over the third-octave
neighbourhood held for 60 % of the file: a note, the thing to avoid). An event is a 5 ms frame 15 dB over the
quietest of the 50 ms before it, within 20 dB of the loudest event, at least 0.3 s after the last.
"""
import argparse
from pathlib import Path

import numpy as np
import soundfile
from scipy import signal

SOURCES = Path(__file__).resolve().parent / "sources"
BANDS = 63 * 2 ** (np.arange(0, 22) / 3)  # third-octave centres 63 Hz .. ~8 kHz and up to 12.7 kHz
BANDS = BANDS[BANDS < 12800]


def load(src):
    p = SOURCES / f"{src}.wav" if str(src).isdigit() else Path(src)
    x, sr = soundfile.read(p, dtype="float64", always_2d=True)
    return x.mean(axis=1), sr


def frames(x, sr, ms):
    n = int(sr * ms / 1000)
    return x[: len(x) // n * n].reshape(-1, n), n / sr


def events(x, sr):
    f, dt = frames(x, sr, 5)
    db = 10 * np.log10(np.mean(f ** 2, axis=1) + 1e-12)
    top, out, last = db.max(), [], -1e9
    for i in range(10, len(db)):
        if db[i] > db[i - 10:i].min() + 15 and db[i] > top - 20 and i * dt - last >= 0.3:
            out.append(i)
            last = i * dt
    return out, dt


def band_levels(x, sr):
    out = []
    for fc in BANDS:
        sos = signal.butter(2, [fc / 2 ** (1 / 6), min(fc * 2 ** (1 / 6), 0.45 * sr)], "bandpass", fs=sr, output="sos")
        y = signal.sosfilt(sos, x)
        f, _ = frames(y, sr, 5)
        out.append(10 * np.log10(np.max(np.mean(f ** 2, axis=1)) + 1e-12))
    return np.array(out) - max(out)


def measure(x, sr):
    f, dt = frames(x, sr, 5)
    db = 10 * np.log10(np.mean(f ** 2, axis=1) + 1e-12)
    ev, _ = events(x, sr)
    freqs, psd = signal.welch(x, sr, nperseg=min(len(x), 16384))
    flat = float(np.exp(np.mean(np.log(psd[1:] + 1e-20))) / (np.mean(psd[1:]) + 1e-20))
    # lasting tone: spectrogram column medians vs a wide median of the long-term spectrum
    ff, tt, s = signal.spectrogram(x, sr, nperseg=8192, noverlap=4096)
    ls = 10 * np.log10(s + 1e-20)
    base = signal.medfilt(np.median(ls, axis=1), 41)
    held = np.mean(ls > base[:, None] + 15, axis=1)
    tones = [(round(float(ff[i])), round(float(np.median(ls[i]) - base[i]), 1)) for i in np.nonzero(held > 0.6)[0] if 30 < ff[i] < 18000 and np.median(ls[i]) > np.median(ls, axis=1).max() - 60]
    hf = signal.sosfilt(signal.butter(4, 2000, "high", fs=sr, output="sos"), x)
    hfr, _ = frames(np.abs(hf), sr, 1.5)
    env = hfr.mean(axis=1)
    bursts = float(np.sum((env[1:-1] > env[:-2]) & (env[1:-1] > env[2:]) & (env[1:-1] > 2 * np.median(env))) / (len(env) * 1.5 / 100))
    return {
        "seconds": len(x) / sr, "events": len(ev), "bands": band_levels(x, sr),
        "hold6_s": float(np.sum(db > db.max() - 6) * dt), "hold20_s": float(np.sum(db > db.max() - 20) * dt),
        "crest_db": float(20 * np.log10(np.max(np.abs(x)) / (np.sqrt(np.mean(x ** 2)) + 1e-12))),
        "flatness": flat, "bursts_per_100ms": bursts, "tones": tones[:8],
    }


def show(name, m):
    print(f"\n{name}: {m['seconds']:.2f} s, {m['events']} events, crest {m['crest_db']:.1f} dB, flatness {m['flatness']:.3f}, "
          f"hold6 {m['hold6_s']:.2f} s, hold20 {m['hold20_s']:.2f} s, bursts/100ms>2k {m['bursts_per_100ms']:.1f}")
    print("  bands (Hz:dB) " + " ".join(f"{int(f)}:{v:.0f}" for f, v in zip(BANDS, m["bands"])))
    print("  lasting tones (Hz, dB over neighbours): " + (str(m["tones"]) if m["tones"] else "none"))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("--against", help="a take (wav) to measure beside the recording")
    a = ap.parse_args()
    x, sr = load(a.source)
    show(a.source, measure(x, sr))
    if a.against:
        y, sy = load(a.against)
        show(a.against, measure(y, sy))
        d = measure(y, sy)["bands"] - measure(x, sr)["bands"]
        print("  take minus recording per band (dB): " + " ".join(f"{int(f)}:{v:+.0f}" for f, v in zip(BANDS, d)))
