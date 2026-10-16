# /// script
# requires-python = ">=3.12"
# dependencies = ["numpy==2.5.3", "scipy==1.18.1", "soundfile==0.13.1"]
# ///
"""Build the A/B review page of a family: tools/audio/review/<family>/index.html (gitignored output).

    uv run tools/audio/review.py ambience

For each sound the family's module lists in CANDIDATES (name -> [A, B, C] Sounds) and PLAYS (name -> what happens
in the game when it plays): the old take as it shipped before the pipeline ("before", sources/legacy/<family>/),
then the candidates, each rendered exactly as export.py would master it. Also prints the checks Claude can make
without ears: lasting tones, peak limiting, seam jump, and writes media/<name>_spectrograms.png for a look.
"""
import importlib
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib import dsp, master, page  # noqa: E402
import analyze  # noqa: E402


def seam_jump(x):
    """Largest step across the loop seam against the 99.9th percentile step elsewhere: a click if over 1."""
    step = np.abs(np.diff(np.concatenate([x[-8:], x[:8]])))
    return float(step.max() / (np.percentile(np.abs(np.diff(x)), 99.9) + 1e-12))


def main(family):
    mod = importlib.import_module("sounds." + family)
    items = []
    for name, cands in mod.CANDIDATES.items():
        opts = [("before", dsp.legacy(cands[0].family, name))]
        for letter, snd in zip("ABC", cands):
            takes = [master.render(snd, v) for v in range(snd.variants)]
            take = takes[0]
            # a sound with variants is shown as its takes in a row (as a walk would play them)
            gap = np.zeros(dsp.samples(0.5))
            opts.append((letter, np.concatenate([a for t in takes for a in (t.x, gap)]) if len(takes) > 1 else take.x))
            m = analyze.measure(take.x, dsp.SR)
            print(f"{name} {letter}: {take.lufs:.1f} LUFS peak {take.peak_db:.1f} dBFS{' LIMITED' if take.limited else ''} "
                  f"seam {seam_jump(take.x) if snd.loop else 0:.1f}x tones {m['tones'] or 'none'}")
        items.append({"name": name, "doc": (mod.__doc__ or "").strip().split("\n")[0], "plays": mod.PLAYS[name],
                      "loop": cands[0].loop, "options": opts})
    print("page:", page.build(Path(__file__).resolve().parent / "review" / family, items, f"Review: {family}"))


if __name__ == "__main__":
    main(sys.argv[1])
