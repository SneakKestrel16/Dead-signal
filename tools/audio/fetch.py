# /// script
# requires-python = ">=3.12"
# dependencies = ["numpy==2.5.3", "scipy==1.18.1", "soundfile==0.13.1"]
# ///
"""Fetch the Freesound recordings the manifests list (pipeline-handoff.md Part 4), and look for new ones.

    uv run tools/audio/fetch.py                    # download every manifest row not on disk
    uv run tools/audio/fetch.py --info 788231      # licence, author, duration, description, spectrogram URL
    uv run tools/audio/fetch.py --search "server room" [--by] [--n 8]   # top hits with their info (CC0, or CC BY)

Rules: only CC0 and CC BY 3.0/4.0 (a commercial sale must be allowed; never NC, never Sampling+). The licence is
read from the sound's own page and checked against the allow-list and against the manifest row, and so is the
uploader, before anything is downloaded. The file is the Freesound high-quality preview (MP3, needs no login).
The MP3 is decoded once to sources/ID.wav (16-bit mono 44.1 kHz); both are committed (Git LFS tracks wav), so
the build never needs the network or an MP3 decoder. Freesound answers 429 above ~1 page per 3 s: we wait 4 s.
Run it on the user's machine; a cloud container gets 403.
"""
import argparse
import hashlib
import html
import re
import sys
import time
import tomllib
import urllib.parse
import urllib.request
import wave
from pathlib import Path

import numpy as np
import soundfile
from scipy import signal

SOURCES = Path(__file__).resolve().parent / "sources"
ALLOWED = {
    "creativecommons.org/publicdomain/zero/1.0/": "CC0-1.0",
    "creativecommons.org/licenses/by/3.0/": "CC-BY-3.0",
    "creativecommons.org/licenses/by/4.0/": "CC-BY-4.0",
}
DELAY_S = 4.0
UA = {"User-Agent": "Mozilla/5.0 (DeadSignal audio pipeline; contact: repo owner)"}
_last = [0.0]


def get(url, binary=False):
    """GET with the 4 s spacing between requests and a back-off on 429."""
    for attempt in range(4):
        wait = DELAY_S * (attempt + 1) - (time.time() - _last[0])
        if wait > 0:
            time.sleep(wait)
        _last[0] = time.time()
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                data = r.read()
            return data if binary else data.decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if e.code != 429 or attempt == 3:
                raise
    raise RuntimeError("unreachable")


def info(sound_id):
    """Everything the page says about a sound: title, author, licence (allow-list key or None), duration,
    description, hq preview URL, spectrogram URL."""
    page = get(f"https://freesound.org/s/{sound_id}/")

    def meta(prop):
        m = re.search(r'property="og:%s" content="([^"]*)"' % re.escape(prop), page)
        return html.unescape(m.group(1)) if m else ""

    lic = next((k for k in ALLOWED if k in page), None)
    mp3 = re.search(r'data-mp3="([^"]*)"', page)
    spec = re.search(r'data-spectrum="([^"]*)"', page)
    dur = re.search(r'data-duration="([^"]*)"', page)
    desc = re.search(r'id="soundDescriptionSection">(.*?)</div>', page, re.S)
    return {
        "id": int(sound_id), "title": meta("audio:title"), "author": meta("audio:artist"),
        "licence": ALLOWED.get(lic), "duration": float(dur.group(1)) if dur else 0.0,
        "description": " ".join(html.unescape(re.sub(r"<[^>]+>", " ", desc.group(1))).split()) if desc else "",
        "hq": mp3.group(1).replace("-lq.mp3", "-hq.mp3") if mp3 else "",
        "spec": spec.group(1).replace("_spec_bw_L", "_spec_L") if spec else "",
    }


def show(i):
    print(f"{i['id']}  {i['licence']}  {i['author']}  {i['duration']:.1f}s  {i['title']}\n    {i['description'][:260]}\n    {i['spec']}")


def search(query, by=False, n=8):
    lic = "Attribution" if by else "Creative Commons 0"
    url = "https://freesound.org/search/?" + urllib.parse.urlencode({"q": query, "f": f'license:"{lic}"', "s": "score desc"})
    ids = list(dict.fromkeys(re.findall(r'href="/people/[^"/]+/sounds/(\d+)/"', get(url))))[:n]
    for sid in ids:
        show(info(sid))


def rows():
    for p in sorted(SOURCES.glob("*.toml")):
        for r in tomllib.loads(p.read_text(encoding="utf-8")).get("recording", []):
            yield p, r


def decode(mp3, wav):
    x, sr = soundfile.read(mp3, dtype="float64", always_2d=True)
    x = x.mean(axis=1)
    if sr != 44100:
        x = signal.resample_poly(x, 44100, sr) if 44100 % sr == 0 or sr % 100 == 0 else signal.resample(x, round(len(x) * 44100 / sr))
    with wave.open(str(wav), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(44100)
        w.writeframes((np.clip(x, -1, 1) * 32767).round().astype("<i2").tobytes())


def write_sha(manifest, sound_id, digest):
    text = manifest.read_text(encoding="utf-8")
    block = re.compile(r'(id = %d\b(?:(?!\[\[recording\]\]).)*?sha256 = )""' % sound_id, re.S)
    manifest.write_text(block.sub(lambda m: m.group(1) + f'"{digest}"', text, count=1), encoding="utf-8", newline="\n")


def fetch_all():
    for manifest, r in rows():
        sid, wav, mp3 = r["id"], SOURCES / f"{r['id']}.wav", SOURCES / f"{r['id']}.mp3"
        if mp3.exists() and wav.exists():
            if r.get("sha256") and hashlib.sha256(mp3.read_bytes()).hexdigest() != r["sha256"]:
                sys.exit(f"{mp3.name}: sha256 differs from {manifest.name}")
            continue
        i = info(sid)
        if i["licence"] is None or i["licence"] != r["licence"]:
            sys.exit(f"{sid}: page licence {i['licence']} is not the manifest's {r['licence']} (allowed: {sorted(ALLOWED.values())})")
        if i["author"] != r["author"]:
            sys.exit(f"{sid}: page author {i['author']!r} is not the manifest's {r['author']!r}")
        data = get(i["hq"], binary=True)
        mp3.write_bytes(data)
        decode(mp3, wav)
        if not r.get("sha256"):
            write_sha(manifest, sid, hashlib.sha256(data).hexdigest())
        print(f"{sid}: {i['licence']} {i['author']} {i['duration']:.1f}s -> {wav.name}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--info", type=int)
    ap.add_argument("--search")
    ap.add_argument("--by", action="store_true", help="search CC BY instead of CC0")
    ap.add_argument("--n", type=int, default=8)
    a = ap.parse_args()
    if a.info:
        show(info(a.info))
    elif a.search:
        search(a.search, a.by, a.n)
    else:
        fetch_all()
