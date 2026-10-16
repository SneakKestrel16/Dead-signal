"""Build the game's sound files, the sound bank and the loudness table (audio pass, design/game-brief.md).

Run from anywhere (re-runnable; downloads are cached):
    python tools/audio/build_audio.py

Needs SoX on PATH (decodes/encodes Ogg Vorbis). CC0 sources (Kenney audio packs, AD-248) are downloaded to
tools/audio/.cache/ (gitignored). What no pack covers (beds, alarms, voices, distortion, stinger) is
synthesised here with the stdlib. Each file is mono 48 kHz, normalised to its category's integrated
loudness target (approximate ITU-R BS.1770 LUFS: K-weighted, 400 ms blocks, -70 LUFS absolute and -10 LU
relative gates; a file shorter than one block is measured whole). Outputs:
    assets/audio/<category>/<name>.wav|.ogg   (one-shots WAV, loops Ogg)
    data/audio/sound_bank.tres                (event id -> stream, bus, volume_db, pitch)
    production/qa/evidence/audio/loudness.md  (measured loudness of every file, stinger vs bed check)
Every source is recorded in assets/art/CREDITS.md "## Audio" (by hand; the list is SOURCES below).
"""
import math
import os
import random
import re
import subprocess
import tempfile
import urllib.request
import wave
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CACHE = os.path.join(ROOT, "tools", "audio", ".cache")
OUT = os.path.join(ROOT, "assets", "audio")
BANK = os.path.join(ROOT, "data", "audio", "sound_bank.tres")
REPORT = os.path.join(ROOT, "production", "qa", "evidence", "audio", "loudness.md")
SR = 48000
UA = {"User-Agent": "DeadSignal-audio-pipeline/1.0"}
# Kenney packs, each page states "Creative Commons CC0" (checked 2026-10-15).
PACKS = {
    "impact-sounds": "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
    "rpg-audio": "https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip",
    "interface-sounds": "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
    "sci-fi-sounds": "https://kenney.nl/media/pages/assets/sci-fi-sounds/6b296f9ecf-1677589334/kenney_sci-fi-sounds.zip",
}
# Category -> (target LUFS, default bus). Inference: no GDD gives numbers; the order follows the GDDs'
# priorities (objective noise loudest, ADR-0013 §1 gameplay cues never masked, beds quiet under everything).
# The stinger is authored at the bed's level minus a margin so ScareAudio's +stinger_max_db_rel (6 dB) puts
# it at most 6 dB over the bed (scare-events rule 26 / SE-8 AC-2).
CATEGORIES = {
    "foot": (-24.0, "GameplayCues"),
    "cue": (-20.0, "GameplayCues"),
    "world": (-22.0, "WorldSFX"),
    "voice": (-22.0, "Voice"),
    "scare": (-20.0, "ScareSFX"),
    "stinger": (-30.5, "Stinger"),
    "ambience": (-30.0, "Ambience"),
    "ui": (-26.0, "SFX"),
}
STINGER_GAIN_DB = 6.0  # data/knobs/scare.tres stinger_max_db_rel, read below
CHARS = [1, 2, 3, 4, 5]
# Per-survivor footstep/voice pitch (CharacterDef order). Inference: no GDD gives voices; five steps apart
# by ~6 % so each set is told apart by ear. A disguise plays the copied survivor's id, so it matches exactly.
CHAR_PITCH = {1: 1.0, 2: 0.93, 3: 1.07, 4: 0.87, 5: 1.13}
GAIT_DB = {"walk": 0.0, "sprint": 4.0, "crouch": -8.0, "crawl": -9.0}
SURFACES = ["tile", "concrete", "metal", "rubber"]


# ---------------------------------------------------------------- io

def fetch():
    for pack, url in PACKS.items():
        d = os.path.join(CACHE, pack)
        if os.path.isdir(d):
            continue
        os.makedirs(CACHE, exist_ok=True)
        z = d + ".zip"
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA)) as r, open(z, "wb") as f:
            f.write(r.read())
        with zipfile.ZipFile(z) as zf:
            zf.extractall(d)


def src(name):
    """Samples (floats, mono, SR) of Kenney file `name` (no extension), any pack."""
    for pack in PACKS:
        p = os.path.join(CACHE, pack, "Audio", name + ".ogg")
        if os.path.isfile(p):
            return read(p)
    raise FileNotFoundError(name)


def read(path):
    with tempfile.TemporaryDirectory() as t:
        w = os.path.join(t, "a.wav")
        subprocess.run(["sox", "-D", path, "-r", str(SR), "-c", "1", "-b", "16", w], check=True, capture_output=True)
        with wave.open(w) as f:
            raw = f.readframes(f.getnframes())
    return [int.from_bytes(raw[i:i + 2], "little", signed=True) / 32768.0 for i in range(0, len(raw), 2)]


def write(x, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = bytearray()
    for v in x:
        data += int(max(-1.0, min(1.0, v)) * 32767).to_bytes(2, "little", signed=True)
    if path.endswith(".wav"):
        tmp = path
    else:
        tmp = path + ".tmp.wav"
    with wave.open(tmp, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(bytes(data))
    if tmp != path:
        subprocess.run(["sox", tmp, "-C", "5", path], check=True, capture_output=True)
        os.remove(tmp)


# ---------------------------------------------------------------- dsp

def n(sec):
    return int(sec * SR)


def silence(sec):
    return [0.0] * n(sec)


def mix(*parts):
    """Sum of (samples, gain_db, offset_s) tuples or plain sample lists."""
    out = []
    for p in parts:
        x, g, off = (p, 0.0, 0.0) if isinstance(p, list) else (p + (0.0,))[:3]
        k = 10 ** (g / 20)
        o = n(off)
        if len(out) < o + len(x):
            out += [0.0] * (o + len(x) - len(out))
        for i, v in enumerate(x):
            out[o + i] += v * k
    return out


def biquad(x, b, a):
    b0, b1, b2 = b
    _, a1, a2 = a
    y = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y


def _rbj(kind, f, q):
    w = 2 * math.pi * f / SR
    al, c = math.sin(w) / (2 * q), math.cos(w)
    if kind == "lp":
        b = [(1 - c) / 2, 1 - c, (1 - c) / 2]
    elif kind == "hp":
        b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
    else:  # band-pass, 0 dB peak
        b = [al, 0.0, -al]
    a0 = 1 + al
    return [v / a0 for v in b], [1.0, -2 * c / a0, (1 - al) / a0]


def lp(x, f, q=0.707):
    return biquad(x, *_rbj("lp", f, q))


def hp(x, f, q=0.707):
    return biquad(x, *_rbj("hp", f, q))


def bp(x, f, q):
    return biquad(x, *_rbj("bp", f, q))


def noise(sec, seed):
    r = random.Random(seed)
    return [r.uniform(-1, 1) for _ in range(n(sec))]


def env(x, attack, release):
    """Linear attack, exponential-ish release over the whole tail."""
    a, L = max(1, n(attack)), len(x)
    return [v * min(1.0, i / a) * (1 - i / L) ** release for i, v in enumerate(x)]


def osc(sec, f0, f1=None, shape="sin"):
    f1 = f0 if f1 is None else f1
    out, ph, L = [], 0.0, n(sec)
    for i in range(L):
        ph += 2 * math.pi * (f0 + (f1 - f0) * i / L) / SR
        s = math.sin(ph)
        out.append(s if shape == "sin" else (ph / math.pi % 2) - 1 if shape == "saw" else (1 if s > 0 else -1))
    return out


def resample(x, ratio):
    """Pitch by `ratio` (>1 higher, shorter), linear interpolation."""
    L = int(len(x) / ratio)
    return [x[min(int(i * ratio), len(x) - 1)] for i in range(L)]


def trim(x, sec):
    return x[:n(sec)]


def clip(x, drive):
    return [math.tanh(v * drive) / math.tanh(drive) for v in x]


def crackle(sec, rate, seed):
    """Electric crackle: random impulse clicks (decaying noise bursts) at `rate` per second."""
    r = random.Random(seed)
    out = [0.0] * n(sec)
    t = 0.0
    while t < sec:
        t += r.expovariate(rate)
        s, L = n(t), r.randint(40, 400)
        a = r.uniform(0.3, 1.0)
        for i in range(L):
            if s + i < len(out):
                out[s + i] += r.uniform(-1, 1) * a * (1 - i / L) ** 2
    return hp(out, 900)


def voice(sec, f0s, formants, seed, breath=0.15):
    """A vowel-ish voice: glottal saw on an f0 contour (list of Hz over the length) through formant bands."""
    L = n(sec)
    r = random.Random(seed)
    src_, ph = [], 0.0
    for i in range(L):
        k = i / L * (len(f0s) - 1)
        j = min(int(k), len(f0s) - 2)
        f = f0s[j] + (f0s[j + 1] - f0s[j]) * (k - j)
        ph += f * (1 + 0.01 * math.sin(i / SR * 2 * math.pi * 5.5)) / SR
        src_.append(2 * (ph % 1.0) - 1 + r.uniform(-breath, breath))
    return mix(*[(bp(src_, fq, 8.0), g) for fq, g in formants])


def loopify(x, fade):
    """Seamless loop: the last `fade` s crossfades into the head, then is dropped."""
    f = n(fade)
    body = x[:len(x) - f]
    for i in range(f):
        k = i / f
        body[i] = body[i] * k + x[len(x) - f + i] * (1 - k)
    return body


# ---------------------------------------------------------------- loudness

K1 = ([1.53512485958697, -2.69169618940638, 1.19839281085285], [1.0, -1.69065929318241, 0.73248077421585])
K2 = ([1.0, -2.0, 1.0], [1.0, -1.99004745483398, 0.99007225036621])


def lufs(x):
    """Approximate integrated loudness (BS.1770, mono, 48 kHz)."""
    y = biquad(biquad(x, *K1), *K2)
    blk, hop = n(0.4), n(0.1)
    if len(y) < blk:
        ms = sum(v * v for v in y) / max(1, len(y))
        return -0.691 + 10 * math.log10(ms) if ms > 0 else -120.0
    ms = [sum(v * v for v in y[s:s + blk]) / blk for s in range(0, len(y) - blk + 1, hop)]
    g = [m for m in ms if m > 0 and -0.691 + 10 * math.log10(m) > -70]
    if not g:
        return -120.0
    rel = -0.691 + 10 * math.log10(sum(g) / len(g)) - 10
    g = [m for m in g if -0.691 + 10 * math.log10(m) > rel]
    return -0.691 + 10 * math.log10(sum(g) / len(g))


def peak_db(x):
    p = max(abs(v) for v in x)
    return 20 * math.log10(p) if p > 0 else -120.0


def normalise(x, target):
    """Gain to `target` LUFS, then a soft limiter keeps the peak under -1 dBFS (may land slightly under)."""
    g = 10 ** ((target - lufs(x)) / 20)
    y = [v * g for v in x]
    if max(abs(v) for v in y) > 0.89:
        y = [0.89 * math.tanh(v / 0.89) for v in y]
    return y


# ---------------------------------------------------------------- the sounds
# name -> (category, builder, [(event id, volume_db, pitch, bus or None)], loop)

def step_tile():
    return hp(resample(src("footstep_concrete_000"), 1.18), 350)


def step_concrete():
    return src("footstep_concrete_001")


def step_metal():
    return mix(src("footstep_concrete_002"), (hp(src("impactMetal_light_001"), 600), -5.0))


def step_rubber():
    return lp(src("footstep_carpet_000"), 1800)


def step_true():
    heavy = lp(resample(src("footstep_concrete_003"), 0.72), 1200)
    return mix(heavy, (resample(src("impactSoft_heavy_000"), 0.8), -4.0), (hp(src("scratch_002"), 2000), -14.0, 0.02))


def bed(seconds, seed, layers):
    x = mix(*layers)
    return loopify(x, 1.0)


def drips(sec, rate, seed):
    r = random.Random(seed)
    out = [0.0] * n(sec)
    t = r.uniform(0.5, 2.0)
    while t < sec - 0.3:
        f = r.uniform(900, 1700)
        d = osc(0.18, f * 1.4, f)
        d = env(d, 0.002, 4)
        for i, v in enumerate(d):
            out[n(t) + i] += v * r.uniform(0.3, 0.8)
        t += r.expovariate(rate)
    return out


def amb_a():  # fluorescent hum, ventilation, dripping, ventilation ticks
    L = 13.0
    hum = mix((osc(L, 120), -6), (osc(L, 240), -14), (osc(L, 360), -20), (lp(osc(L, 120, shape="sq"), 2500), -30))
    vent = lp(noise(L, 11), 500)
    ticks = lp(crackle(L, 0.6, 12), 3000)
    return bed(L, 1, [(hum, -10), (vent, -4), (drips(L, 0.35, 13), -16), (ticks, -24)])


def amb_b():  # server fans
    L = 13.0
    fan = bp(noise(L, 21), 700, 0.6)
    rumble = lp(noise(L, 22), 160)
    tones = mix((osc(L, 182), -18), (osc(L, 187), -18), (osc(L, 241), -24))
    return bed(L, 2, [(fan, 0), (rumble, 2), (tones, -6)])


def amb_c():  # low security tone, monitor buzz
    L = 13.0
    tone = mix((osc(L, 55), 0), (osc(L, 110), -9), (osc(L, 82.5), -16))
    buzz = bp(osc(L, 60, shape="saw"), 1800, 1.5)
    air = lp(noise(L, 31), 300)
    return bed(L, 3, [(tone, -6), (buzz, -14), (air, -6)])


def amb_link():  # service corridors: pipe hum, room tone, rarer drips (inference: no row in the level doc)
    L = 13.0
    pipe = mix((osc(L, 50), 0), (osc(L, 100), -10))
    air = lp(noise(L, 41), 220)
    return bed(L, 4, [(pipe, -12), (air, 0), (drips(L, 0.15, 42), -18)])


def alarm(sec, f_hi, f_lo, period, seed):
    out = []
    half = n(period / 2)
    for k in range(int(sec / period)):
        for f in (f_hi, f_lo):
            out += osc(half / SR, f, shape="sq")
    return lp(env(out, 0.01, 0.3), 3500)


def lunge_cue():  # rising growl, the wind-up's length
    L = 0.6
    g = voice(L, [70, 95, 140], [(400, 0), (900, -6), (2200, -14)], 51, breath=0.5)
    return clip(env(mix(g, (lp(noise(L, 52), 800), -6)), 0.05, 0.4), 2.5)


def lunge_scrape():
    return mix(lp(src("scratch_004"), 2500), (resample(src("impactMetal_medium_002"), 0.8), -8))


def lunge_hit():
    return mix(src("impactPunch_heavy_001"), (resample(src("impactSoft_heavy_002"), 0.85), -3))


def taser_crackle():  # cartridge pop, then crackle
    pop = src("impactGeneric_light_000")
    crk = env(mix(crackle(0.7, 120, 61), (osc(0.7, 60, shape="saw"), -18)), 0.005, 0.6)
    return mix(pop, (crk, -2, 0.04))


def taser_fizz():  # dull fizz on resist
    return lp(env(crackle(0.4, 60, 62), 0.01, 1.2), 1500)


def hide_creak(name, latch):
    return mix(src(name), (src(latch), -6, 0.15))


def hide_cue():  # breathing in hiding
    br = []
    for i, (a, s) in enumerate([(0.5, 0.6), (0.45, 0.8)]):
        br += env(bp(noise(a, 70 + i), 900, 0.8), a * 0.4, 1.5) + silence(0.15)
    return br


def fuse_install():
    return mix(src("metalLatch"), (src("impactMetal_heavy_001"), -2, 0.12), (src("metalClick"), -4, 0.3),
               (env(osc(0.5, 120, shape="saw"), 0.02, 1), -16, 0.35))


def distortion():  # transform distortion: wobbling ring-modulated drone with crackle, transform_duration_s long
    L = 2.0
    out, ph = [], 0.0
    for i in range(n(L)):
        t = i / SR
        ph += 2 * math.pi * 140 * (1 + 0.6 * math.sin(2 * math.pi * 9 * t)) / SR
        out.append(math.sin(ph) * math.sin(2 * math.pi * 37 * t))
    return env(mix(clip(out, 3.0), (crackle(L, 30, 81), -10), (lp(src("forceField_001") + silence(2.0), 2500)[:n(L)], -8)),
               0.15, 0.6)


def door_open():
    return src("doorOpen_1")


def door_close():
    return src("doorClose_1")


def barricade_build():
    return mix(*[(src("impactPlank_medium_00%d" % (i % 5)), -i * 0.5, i * 0.28) for i in range(4)])


def barricade_break():
    return mix(src("impactWood_heavy_000"), (src("impactPlank_medium_003"), -2, 0.05), (src("impactWood_heavy_003"), -4, 0.2))


def objective_dock():
    beep = env(osc(0.18, 880), 0.005, 1) + env(osc(0.25, 1320), 0.005, 1)
    return mix(src("metalClick"), (beep, -10, 0.15))


def callout_blip(c):
    """Non-verbal radio callout per voice set: squelch, a two-beep motif pitched per survivor, squelch tail."""
    p = CHAR_PITCH[c]
    sq = lambda s: bp(env(noise(0.08, 90 + c + s), 0.002, 1), 2200, 1.0)
    motif = [(700, 0.07), (1050, 0.09)] if c % 2 else [(1050, 0.07), (700, 0.09)]
    b = []
    for f, d in motif:
        b += env(osc(d, f * p, shape="sq"), 0.003, 0.5) + silence(0.03)
    b = bp(b, 1500, 0.7)
    return mix((sq(0), -4), (b, 0, 0.08), (sq(1), -6, 0.08 + len(b) / SR))


def grunt(c):  # survivor shocked grunt, pitched per voice set
    f = 130 * CHAR_PITCH[c]
    return env(voice(0.35, [f * 1.3, f * 1.1, f], [(650, 0), (1100, -4), (2500, -12)], 100 + c, 0.3), 0.01, 1.2)


def pain_cry():  # true-form pain cry
    v = voice(0.9, [90, 140, 110, 70], [(500, 0), (950, -2), (2100, -8)], 110, 0.6)
    return env(clip(mix(v, (lp(noise(0.9, 111), 1500), -8)), 3.0), 0.03, 0.8)


def door_burst():
    return mix(src("impactWood_heavy_001"), (src("impactMetal_heavy_002"), -2, 0.02),
               (lp(src("lowFrequency_explosion_000"), 600), -6))


def slammed_door():
    return mix(src("doorClose_4"), (src("impactWood_heavy_002"), -1, 0.02))


def glass_break():
    return mix(src("impactGlass_heavy_000"), (src("impactGlass_heavy_002"), -3, 0.06),
               (src("impactGlass_light_001"), -6, 0.25), (src("impactGlass_light_003"), -9, 0.45))


def ambush_lunge():
    return mix(lunge_hit(), (pain_cry()[:n(0.6)], -6))


def blackout():  # power-cut thunk, relay clack
    thunk = lp(src("lowFrequency_explosion_001"), 300)
    return mix(thunk, (src("metalLatch"), -4, 0.35), (env(osc(0.5, 60), 0.0, 3), -10))


def recording(seed):  # distorted voice from a speaker: babble through a phone band, static
    r = random.Random(seed)
    out = []
    for _ in range(9):
        d = r.uniform(0.12, 0.3)
        f = r.uniform(110, 160)
        fm = r.choice([(700, 1200), (400, 2000), (550, 900)])
        out += env(voice(d, [f, f * 0.9], [(fm[0], 0), (fm[1], -4)], r.random()), 0.02, 0.5) + silence(r.uniform(0.02, 0.1))
    v = bp(clip(out, 4.0), 1400, 0.9)
    return mix(v, (hp(noise(len(v) / SR, seed + 1), 3000), -18))


def surveillance_image():  # monitor static
    return mix(env(hp(noise(1.2, 120), 1500), 0.01, 0.5), (lp(src("computerNoise_001") + silence(1.2), 4000)[:n(1.2)], -6))


def stinger():  # dissonant swell, cut short
    L = 1.3
    cl = mix(*[(osc(L, f, shape="saw"), -6) for f in (110, 116.5, 155.6, 233)])
    cl = lp(cl, 1800)
    sw = [v * (i / n(L)) ** 0.3 for i, v in enumerate(cl)]
    return env(mix(sw, (hp(noise(L, 130), 2500), -14)), 0.01, 0.5)


def ui_click():
    return src("click_002")


def ping_rejected():  # local "too fast" click
    return src("error_004")


LINES = ["drive_here", "fuse_here", "need_rescue", "im_with_you", "follow_me", "wait", "danger", "that_wasnt_me"]
SCARES = ["transformation_reveal", "door_burst", "ambush_lunge", "blackout", "slammed_door", "glass_break",
          "alarm_fuse", "alarm_evacuation", "recording_room", "recording_script", "surveillance_image"]


def catalogue():
    """[(file name, category, builder, ids, loop)]; ids = [(id, volume_db, pitch, bus override)]."""
    c = []
    for s, fn in zip(SURFACES, [step_tile, step_concrete, step_metal, step_rubber]):
        c.append(("step_" + s, "foot", fn, [("c%d@%s" % (k, s), 0.0, CHAR_PITCH[k], None) for k in CHARS], False))
    c.append(("step_true_form", "foot", step_true, [("c0", 0.0, 1.0, None)], False))
    for z, fn in [("A", amb_a), ("B", amb_b), ("C", amb_c), ("link", amb_link)]:
        c.append(("amb_" + z.lower(), "ambience", fn, [("ambience/" + z, 0.0, 1.0, None)], True))
    for name, fn in [("lunge_cue", lunge_cue), ("lunge_scrape", lunge_scrape), ("lunge_hit", lunge_hit),
                     ("taser_crackle", taser_crackle), ("taser_fizz", taser_fizz), ("hide_cue", hide_cue),
                     ("distortion", distortion)]:
        c.append((name, "cue", fn, [(name, 0.0, 1.0, None)], False))
    c.append(("fuse_install", "cue", fuse_install, [("fuse_install", 4.0, 1.0, None)], False))  # loudest cue
    c.append(("hide_enter", "cue", lambda: hide_creak("creak1", "metalLatch"), [("hide_enter", -4.0, 1.0, None)], False))
    c.append(("hide_exit", "cue", lambda: hide_creak("creak3", "metalClick"), [("hide_exit", -4.0, 1.0, None)], False))
    for name, fn in [("door_open", door_open), ("door_close", door_close), ("barricade_build", barricade_build),
                     ("barricade_break", barricade_break), ("objective_dock", objective_dock)]:
        c.append((name, "world", fn, [(name, 0.0, 1.0, None)], False))
    c.append(("objective_alarm", "world", lambda: alarm(2.4, 740, 520, 0.6, 1), [("objective_alarm", 0.0, 1.0, None)], False))
    for k in CHARS:
        c.append(("callout_c%d" % k, "voice", lambda k=k: callout_blip(k), [("callout/voice_c%d" % k, 0.0, 1.0, None)], False))
        c.append(("grunt_c%d" % k, "voice", lambda k=k: grunt(k), [("voice_c%d.shocked_grunt" % k, 0.0, 1.0, None)], False))
    c.append(("pain_cry_true_form", "voice", pain_cry, [("voice_c0.pain_cry", 0.0, 1.0, None)], False))
    scare = {"transformation_reveal": lambda: mix(distortion()[:n(0.8)], (pain_cry(), -2, 0.3)),
             "door_burst": door_burst, "ambush_lunge": ambush_lunge, "blackout": blackout,
             "slammed_door": slammed_door, "glass_break": glass_break,
             "alarm_fuse": lambda: alarm(2.4, 880, 660, 0.4, 2),
             "alarm_evacuation": lambda: alarm(4.0, 620, 440, 1.0, 3),
             "recording_room": lambda: recording(140), "recording_script": lambda: recording(150),
             "surveillance_image": surveillance_image}
    for s in SCARES:
        c.append(("scare_" + s, "scare", scare[s], [("scare/" + s, 0.0, 1.0, None)], False))
    c.append(("scare_stinger", "stinger", stinger, [("scare/stinger", 0.0, 1.0, None)], False))
    c.append(("ui_click", "ui", ui_click, [("ui/click", 0.0, 1.0, None)], False))
    c.append(("ping_rejected", "ui", ping_rejected, [("ping/rejected", 0.0, 1.0, None)], False))
    return c


# ---------------------------------------------------------------- bank and report

def bank_tres(rows):
    ext = ['[ext_resource type="Script" path="res://src/core/audio/sound_bank.gd" id="1"]',
           '[ext_resource type="Script" path="res://src/core/audio/sound_bank_entry.gd" id="2"]']
    subs, entries = [], []
    for i, (path, cat, ids, loop) in enumerate(rows):
        ext.append('[ext_resource type="AudioStream" path="res://%s" id="s%d"]' % (path, i))
        bus = CATEGORIES[cat][1]
        for eid, vol, pitch, over in ids:
            sid = "e%d" % len(subs)
            subs.append('[sub_resource type="Resource" id="%s"]\nscript = ExtResource("2")\nstream = ExtResource("s%d")\n'
                        'bus = &"%s"\nvolume_db = %s\npitch_scale = %s\nloop = %s\n'
                        % (sid, i, over or bus, repr(float(vol)), repr(float(pitch)), "true" if loop else "false"))
            entries.append('&"%s": SubResource("%s")' % (eid, sid))
    gait = ", ".join('&"%s": %s' % (g, repr(float(d))) for g, d in GAIT_DB.items())
    head = ('[gd_resource type="Resource" script_class="SoundBank" load_steps=%d format=3]\n\n'
            '; GENERATED by tools/audio/build_audio.py; edit the script, not this file.\n\n'
            % (len(ext) + len(subs) + 1))
    body = ('[resource]\nscript = ExtResource("1")\nentries = Dictionary[StringName, Resource]({\n%s\n})\n'
            'suffix_db = Dictionary[StringName, float]({%s})\n'
            'surface_of_zone = Dictionary[StringName, StringName]({&"A": &"tile", &"B": &"metal", &"C": &"concrete", &"link": &"concrete"})\n'
            'default_surface = &"concrete"\n'
            % (",\n".join(entries), gait))
    return head + "\n".join(ext) + "\n\n" + "\n".join(subs) + "\n" + body


def main():
    global STINGER_GAIN_DB
    fetch()
    m = re.search(r"stinger_max_db_rel = ([-\d.]+)", open(os.path.join(ROOT, "data/knobs/scare.tres")).read())
    STINGER_GAIN_DB = float(m.group(1))
    rows, report = [], []
    for name, cat, fn, ids, loop in catalogue():
        x = normalise(fn(), CATEGORIES[cat][0])
        rel = "assets/audio/%s/%s.%s" % (cat, name, "ogg" if loop else "wav")
        write(x, os.path.join(ROOT, rel))
        y = read(os.path.join(ROOT, rel))  # measure what shipped (after the encoder)
        report.append((rel, cat, CATEGORIES[cat][1], CATEGORIES[cat][0], lufs(y), peak_db(y), len(y) / SR))
        rows.append((rel, cat, ids, loop))
        print("%-48s %6.1f LUFS" % (rel, report[-1][4]))
    os.makedirs(os.path.dirname(BANK), exist_ok=True)
    with open(BANK, "w", newline="\n", encoding="utf-8") as f:
        f.write(bank_tres(rows))
    st = next(r for r in report if r[1] == "stinger")
    beds = [r for r in report if r[1] == "ambience"]
    lines = ["# Audio loudness", "", "Generated by `tools/audio/build_audio.py` (approximate BS.1770 integrated loudness, mono "
             "48 kHz, measured on the shipped file after encoding). Targets are inference (no GDD number); see the "
             "script's CATEGORIES.", "", "## Stinger vs zone bed (scare-events rule 26, SE-8 AC-2: at most +6 dB)", "",
             "Stinger playback gain = `stinger_max_db_rel` %.1f dB (data/knobs/scare.tres), both at bus 0 dB." % STINGER_GAIN_DB, "",
             "| Bed | Bed LUFS | Stinger file LUFS | Stinger as played | Over bed | Within +6 dB |", "|---|---|---|---|---|---|"]
    for b in beds:
        over = st[4] + STINGER_GAIN_DB - b[4]
        lines.append("| %s | %.1f | %.1f | %.1f | %+.1f dB | %s |" % (os.path.basename(b[0]), b[4], st[4],
                     st[4] + STINGER_GAIN_DB, over, "yes" if over <= 6.0 else "NO"))
    lines += ["", "## Every file", "", "| File | Category | Bus | Target LUFS | Measured LUFS | Peak dBFS | Seconds |",
              "|---|---|---|---|---|---|---|"]
    for r in report:
        lines.append("| `%s` | %s | %s | %.1f | %.1f | %.1f | %.2f |" % r)
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", newline="\n", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
