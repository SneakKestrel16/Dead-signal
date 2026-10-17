# /// script
# requires-python = ">=3.12"
# dependencies = ["numpy==2.5.3", "scipy==1.18.1", "soundfile==0.13.1"]
# ///
"""Build the A/B review page of a family: tools/audio/review/<family>/index.html (gitignored output).

    uv run tools/audio/review.py ambience
    uv run tools/audio/review.py cues --round 2      # review/cues/r2/: what ships now, then the module's ROUND2 D, E, F

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
import export  # noqa: E402


def seam_jump(x):
    """Largest step across the loop seam against the 99.9th percentile step elsewhere: a click if over 1."""
    step = np.abs(np.diff(np.concatenate([x[-8:], x[:8]])))
    return float(step.max() / (np.percentile(np.abs(np.diff(x)), 99.9) + 1e-12))


def render(snd, label, name):
    """The option as export.py masters it; a sound with variants is its takes in a row (as a walk would play them)."""
    takes = [master.render(snd, v) for v in range(snd.variants)]
    take = takes[0]
    gap = np.zeros(dsp.samples(0.5))
    m = analyze.measure(take.x, dsp.SR)
    print(f"{name} {label}: {take.lufs:.1f} LUFS peak {take.peak_db:.1f} dBFS{' LIMITED' if take.limited else ''} "
          f"seam {seam_jump(take.x) if snd.loop else 0:.1f}x tones {m['tones'] or 'none'}")
    return np.concatenate([a for t in takes for a in (t.x, gap)]) if len(takes) > 1 else take.x


def main(family, rnd=1):
    mod = importlib.import_module("sounds." + family)
    items = []
    for name, cands in (mod.CANDIDATES if rnd == 1 else mod.ROUND2).items():
        if rnd == 1:
            opts = [("before", dsp.legacy(cands[0].family, name))] + [(l, render(s, l, name)) for l, s in zip("ABC", cands)]
        else:  # what ships now (picks.py), then the round's candidates
            now = export.shipped(name, mod.CANDIDATES[name], mod)
            opts = [("now", render(now, "now", name))] + [(l, render(s, l, name)) for l, s in zip("DEF", cands)]
        items.append({"name": name, "doc": (mod.__doc__ or "").strip().split("\n")[0], "plays": mod.PLAYS[name],
                      "loop": cands[0].loop, "options": opts})
    out = Path(__file__).resolve().parent / "review" / family
    if rnd > 1:
        out = out / f"r{rnd}"
    print("page:", page.build(out, items, f"Review: {family}" + (f" round {rnd}" if rnd > 1 else ""),
                              "picks.json" if rnd == 1 else f"picks_{family}_r{rnd}.json"))


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[2] == "--round" else 1)
