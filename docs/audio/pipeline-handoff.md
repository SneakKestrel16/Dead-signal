# A code-built sound effects pipeline: how Infall does it

A handoff from the Infall project (a Godot 4.6 C# squad-tactics game) to another project that wants
the same thing. Every sound effect in Infall is built by Python code, with real recordings as raw
material, mastered to a loudness table and shipped as WAV. About 150 sounds, 300 takes, built from
scratch in about 15 s by one command. The owner's verdict on the guns after the quality pass:
"exactly what I wanted".

This file is written for a Claude Code session. Read **Part 1** first: it holds the lessons that
made the biggest difference to quality. The rest is the setup, the code, and the traps.

---

## Part 1: what actually fixed the sound quality

These are in order of how much they mattered.

### 1. Textbook synthesis recipes make musical instruments, not objects

The first pass built sounds the way synthesis books teach. The owner's first listen: "a lot of the
sounds sound very... musical?" Heavy impacts sounded "like drums", metal "like xylophone", liquids
"too squelchy", electronics "too clean". Each recipe *is* how an instrument is made:

| Recipe | What the ear hears | What to do instead |
|---|---|---|
| A sine that falls in pitch, for weight | A kick drum | Low-passed noise with a decay (`thump`) |
| 3-8 clean modes on fixed ratios, struck | A mallet, xylophone | Noise split into many third-octave bands, each with its own level and decay (`bands`, `click`) |
| Steel as a few modes | A bell, a note | Dozens of random modes, each with a twin a few cents off; low modes no louder or longer than the rest (`metal`) |
| A long midrange bubble (8-40 ms, 350-1600 Hz) | A cartoon "bloop" | Tiny high bubbles (1-6 ms, 1-7 kHz), many and quiet |
| A resonant band swept down | A wah pedal | Do not sweep a narrow band over noise |
| A pure oscillator beep | A test tone | Run every tone through a simulated cheap speaker (`speaker`) |
| White noise through resonances, for breath | Static | Pink noise, rolled off above 8 kHz |

Real objects have too many modes, damped too fast, to have a pitch. **The check is the
spectrogram: a horizontal line that outlasts the rest of the sound is a note.** Look for one in
every sound.

### 2. Build on real recordings, not only on synthesis

The biggest single jump in quality came from rebuilding the important sounds (voices, footsteps,
guns, creatures) **on CC0 / CC BY recordings from Freesound**, used as raw material: cut, pitched,
layered, and placed on the animation's beats by code. Pure synthesis got most mechanical and
electrical sounds (engines, forklift, dropship) to "excellent". It never got voices, steps, guns or
creatures there.

The recordings are committed to the repo, so the build stays deterministic and offline. See Part 4.

### 3. Measure real recordings before you build something that must sound real

When a sound would not come right (water that did not sound like water), the fix was to download
recordings of the real thing and **measure** them: per third-octave band, the level and how fast it
decays; how long the sound **holds** near its peak; the crest factor; how grainy the highs are; how
many short tonal blips (bubbles) it has. Then build to those numbers and measure the result against
the recording. See Part 5. Findings from that:

- **A gunshot is a held burst, not a blow.** Built like an impact (body + low thump + saturation),
  it sounded "like an impact, not the crack of gunpowder". Built from the measured per-band decays,
  every band peaked at once and died at its own rate, which is how a struck body rings: "hitting
  something with a wooden bat". A real shot holds near full, broadband, for 20-60 ms before it
  dies. Use the measured *spectrum* under one *held* envelope.
- **A shot without its 250 Hz-1.6 kHz blast sounds suppressed.**
- **Matching field recordings leaves a game shot thin.** A designed game gunshot carries its 60-80 Hz
  about 12 dB higher and rolls far longer than a close-miked field recording. Measure designed
  library shots too, and take from each what the game wants.
- **A footstep is mostly scrape**, the sole over grit, not a knock. A knock reads as "too impactful".
- **Puddle water is many short bubbles** (8-20 per step, ~6 ms, 1-6 kHz). With no bubbles it is
  "crunchy" (gravel, snow). With long resonant drops it is "plinky".
- **A body falling is not several blows.** Each part arrives over 8-30 ms, midrange under the low
  end, parts spread over a third of a second, then a slide. Blows sound like "a piece of wood".
- **A reload is two to four events on top**, irregular, over a bed of handling. A dozen equal clicks
  in a steady rhythm is "a drum solo", whatever their tone. A rack is a *cluster*: several hits in
  10-25 ms at nearly one level, a second cluster 25-32 ms on, then the receiver ringing. Pump and
  bolt steel lives at 1.2-12 kHz with the lows 25-40 dB down.
- **A motor heard as a pitch is a toy.** A heavy motor is a hum of mains harmonics plus the
  mechanism's rush, whose *strength*, not pitch, follows the load.
- **One event, one idea.** Voicing every motion on screen ("supply, self-test, lens, tilt motor,
  backlash, ready tone") was "a LOT of stuff going on here, too confusing".

### 4. Time each sound to what is on screen, from the source

The owner's rule: sounds "should line up, by length and composition, to what's happening on the
screen". Guessed timing was always wrong: a door's motor ran 1.4 s against a 0.3 s slide; a reload's
seat came 0.2 s early. **Read every beat off the animation clip or the effect's code**, account for
playback speed (a clip played at 1.2x), and write the beats into the sound with a comment naming the
source. See Part 7.

### 5. A human ear decides, through an A/B page

Claude cannot hear. What Claude can check: spectrograms and numbers (a cut-off ring, a click, a held
tone, a peak-limited take). What sounds *right* is always the human's call. The workflow that worked:

1. A **triage page** with every sound as it ships, each marked **good / rough / remove** with a note.
2. Rebuild the rough ones in **batches by family** (voices, steps, guns, creatures, ...).
3. For each important sound make **two candidate directions, A and B**.
4. A **before/after page**: old take, A, B, all synced so switching compares the same moment, dry
   or in a reverb preview, spectrograms drawn beside them. Buttons: **Keep A / Keep B / Revert /
   Unsure** plus a note. The verdicts are stored, and the next batch reads them.
5. Iterate on the notes ("too high pitched, sounds like a toy", "should have a long bam").

The owner, starting the quality pass: "please use creative license when doing so - if you make
something worse, that's a risk worth taking, we might end up with something really cool. and we
always have this to fall back to." Bold A/B candidates beat cautious tweaks.

### 6. Post-processing EQ is not where quality comes from

Infall ran a full "finishing" pass in SoX (shelves, EQ, compression, saturation) measured against
recordings. It moved most sounds under 2 dB, and the owner's verdict was: "I can't find any
difference between before/after at ALL". The quality pass rebuilt the sounds instead. Keep a
finishing stage for the odd sound that needs it, but **do not expect EQ to rescue a sound that is
built wrong**. Rebuild the source.

### 7. Ship mono and dry; let the engine place it and add the room

Reverb baked into a file is the same room everywhere, and doubles with the engine's reverb. Mono is
what 3D positioning needs. Every file is mono, dry, 16-bit PCM at the engine's mix rate (44.1 kHz in
Godot, so nothing is resampled).

### 8. Master every sound to a loudness table, not to a peak

Peak normalisation makes a click and a rumble "equally loud" and they are not. Each sound has a
target in LUFS over its loudest 400 ms, and the table puts the set in balance. See Part 6.

---

## Part 2: the pipeline layout

```
audio/
  export.py          entry point: builds every sound, writes the WAVs, --only, --check, --sheet
  lib/
    dsp.py           the building blocks (sources, filters, envelopes, bodies, grains, mixing)
    master.py        catalog entry (Sound), seeding, trim, loudness, WAV bytes
    finish.py        optional SoX finishing chain per sound
    sheet.py         the listening sheet (HTML: takes dry + in a corridor, spectrograms)
  sounds/            one module per family: weapons, steps, doors, creatures, ui, ...
                     each ends with SOUNDS = [Sound(...), ...]
  sources/           committed recordings: ID.mp3 (as downloaded) + ID.wav (decoded once)
    steps.toml       manifest per family: id, url, author, licence, why, sha256
  fetch.py           downloads what the manifests list and is not on disk
  analyze.py         measures recordings (file or URL) and compares a take against them
  page.py            the A/B before/after review page
  compare.py, verify.py   before/after numbers against a git ref (optional, later)
game/assets/audio/sfx/NAME.wav, NAME_0.wav, NAME_1.wav ...   the committed outputs
```

Commands:

```bash
uv run audio/export.py                                   # every sound, seconds
uv run audio/export.py --only step_                      # names starting so
uv run audio/export.py --only step_ --sheet _verify/audio   # and write _verify/audio/sheet.html
uv run audio/export.py --check                           # write nothing; fail if a WAV is stale
uv run audio/fetch.py                                    # fetch new manifest rows
uv run audio/analyze.py REF.wav URL --against sfx/step_water_0.wav --png _verify/png
```

**Dependencies are pinned in the script header** so `uv` installs exact versions and the same code
makes the same bytes:

```python
# /// script
# requires-python = ">=3.12"
# dependencies = ["numpy==2.5.3", "scipy==1.18.1"]
# ///
```

Extra tools: **SoX 14.4.2** on PATH only if you use the finishing stage (pin it; the export refuses
another version). **ffmpeg** only for `fetch.py` (decoding a new recording once) and `analyze.py`.
The export itself needs neither ffmpeg nor the network.

### The catalog entry

```python
@dataclass(frozen=True)
class Sound:
    name: str
    build: Callable[[np.random.Generator], np.ndarray]   # rng -> mono float array at 44.1 kHz
    level: float                # target LUFS over its loudest 400 ms
    variants: int = 1           # takes, each from its own seed
    loop: bool = False          # seamless loop: never trimmed, smpl chunk in the WAV
    synced: bool = False        # timed to a clip: keep the lead-in silence
    finish: tuple[str, ...] = ()  # optional SoX effect chain

    def file(self, variant: int) -> str:
        return f"{self.name}_{variant}.wav" if self.variants > 1 else f"{self.name}.wav"

# in sounds/impacts.py
SOUNDS = [
    Sound("impact_rock", impact_rock, level=-24, variants=3),
    Sound("door_slide", door_slide, level=-22, synced=True),
]
```

A sound is a function from a numpy `Generator` to a mono float array. Its docstring says what it
is; the listening sheet shows the docstring under the sound's name.

### Takes from seeds, and determinism

```python
def seed(name: str, variant: int) -> np.random.Generator:
    # crc32, not hash(): Python salts str hashes per run
    return np.random.default_rng([zlib.crc32(name.encode()), variant])
```

- **Every random draw comes from the Generator the sound is handed**, never from `random` or the
  clock. A sound's name and take number are the whole of what makes it.
- Takes differ the way real strikes do: a mode's pitch, a grain's time, a ricochet or none.
- With pinned numpy/scipy/SoX and the `wave` module (no timestamps), a re-export that changed
  nothing changes no file. So there is no cache: the whole catalog rebuilds in seconds.
- **Cross-platform caveat:** Windows and Linux numpy/scipy wheels round one sample in a few takes to
  the other side of a 16-bit step. The check accepts a take within one step in at most one sample in
  a thousand, and keeps the file on disk so it does not flip in git between machines.

### The commit hook

A pre-commit hook runs `uv run audio/export.py --check` on any commit that touches `audio/` or the
WAVs. It renders everything in memory and fails if a WAV is missing, differs from what the code
makes, or is made by no sound. So code and committed WAVs can never drift apart. A full export also
deletes WAVs no sound makes any more (a renamed sound, a smaller set).

---

## Part 3: the building blocks (lib/dsp.py)

Everything is mono float64 at SR = 44100. The core blocks, condensed from the real file:

```python
SR = 44100
def samples(s): return int(round(s * SR))
def clock(n): return np.arange(n) / SR
def norm(x): return x / (np.max(np.abs(x)) + 1e-12)

def noise(rng, n): return rng.standard_normal(n)

def colored(rng, n, slope):
    """1/f**slope noise (1 pink, 2 brown), shaped in the frequency domain."""
    spec = np.fft.rfft(rng.standard_normal(n)); f = np.fft.rfftfreq(n, 1 / SR)
    spec[0] = 0.0; spec[1:] /= f[1:] ** (slope / 2)
    x = np.fft.irfft(spec, n); return x / (np.std(x) + 1e-12)

def phase(freq, n):
    return 2 * np.pi * np.cumsum(np.broadcast_to(np.asarray(freq, float), (n,))) / SR

def partials(freq, n, weight, top=16000.0):
    """Band-limited tone from harmonics; each fades out below `top` instead of switching off,
    so a sweep neither aliases nor clicks."""
    f = np.broadcast_to(np.asarray(freq, float), (n,)); ph = phase(f, n); out = np.zeros(n)
    for k in range(1, int(top / f.min()) + 1):
        w = weight(k)
        if w: out += w * np.sin(k * ph) * np.clip((top - k * f) / (0.1 * top), 0.0, 1.0)
    return out

# Filters: Butterworth via scipy sos, designs cached (filter design costs more than running it
# over a 3 ms grain, and grains design the same few thousand filters).
@functools.lru_cache(maxsize=4096)
def _design(kind, f, order): return signal.butter(order, list(f) if isinstance(f, tuple) else f, btype=kind, fs=SR, output="sos")
def lowpass(x, f, order=2): return signal.sosfilt(_design("lowpass", float(f), order), x)
def highpass(x, f, order=2): return signal.sosfilt(_design("highpass", float(f), order), x)
def bandpass(x, lo, hi, order=2): return signal.sosfilt(_design("bandpass", (float(lo), float(hi)), order), x)

def biquad(kind, f0, q=0.7071, gain_db=0.0):
    """One RBJ audio-EQ cookbook section as an sos row: high, band, peak or highshelf.
    loudness() below needs it for the K-weighting."""
    a_ = 10 ** (gain_db / 40); w = 2 * np.pi * min(f0, 0.45 * SR) / SR
    cw, alpha = np.cos(w), np.sin(w) / (2 * q)
    a = [1 + alpha, -2 * cw, 1 - alpha]
    if kind == "high":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
    elif kind == "band":
        b = [alpha, 0.0, -alpha]
    elif kind == "peak":
        b = [1 + alpha * a_, -2 * cw, 1 - alpha * a_]; a = [1 + alpha / a_, -2 * cw, 1 - alpha / a_]
    elif kind == "highshelf":
        s = 2 * np.sqrt(a_) * alpha
        b = [a_ * ((a_ + 1) + (a_ - 1) * cw + s), -2 * a_ * ((a_ - 1) + (a_ + 1) * cw), a_ * ((a_ + 1) + (a_ - 1) * cw - s)]
        a = [(a_ + 1) - (a_ - 1) * cw + s, 2 * ((a_ - 1) - (a_ + 1) * cw), (a_ + 1) - (a_ - 1) * cw - s]
    else:
        raise ValueError(kind)
    b, a = np.asarray(b), np.asarray(a)
    return np.hstack([b / a[0], a / a[0]])[None, :]

def eq(x, kind, f0, q=0.7071, gain_db=0.0): return signal.sosfilt(biquad(kind, f0, q, gain_db), x)
# plus `sweep`: a biquad whose frequency follows a curve, retuned every 32 samples with its state carried.

# Envelopes
def curve(n, *points):             # piecewise linear through (seconds, value)
    ts, vs = zip(*points); return np.interp(clock(n), ts, vs)
def decay(n, tau, at=0.0):
    t = clock(n) - at; return np.where(t >= 0, np.exp(-np.maximum(t, 0) / tau), 0.0)
def wander(rng, n, rate):          # smooth random control signal in [-1, 1]
    x = lowpass(rng.standard_normal(n), rate); return x / (np.max(np.abs(x)) + 1e-12)
```

### Bodies: what a knock, click or clang is made of, with no note in it

```python
def bands(rng, n, lo, hi, level, tau, per_octave=3):
    """White noise split into fractional-octave bands, each at level(centre), dying in tau(centre):
    a body too dense in modes to ring at one pitch (a door, a receiver, a slab, a fist)."""
    t = clock(n); w = rng.standard_normal(n); out = np.zeros(n)
    edges = lo * 2 ** (np.arange(int(np.log2(hi / lo) * per_octave) + 1) / per_octave)
    for a, b in zip(edges[:-1], edges[1:]):
        if a < 0.44 * SR:
            fc = np.sqrt(a * b)
            out += level(fc) * bandpass(w, a, min(b, 0.45 * SR)) * np.exp(-t / tau(fc))
    return out

def peak_at(centre, width):       # a bell-shaped level for bands(), `width` octaves either side
    return lambda f: np.exp(-0.5 * (np.log2(f / centre) / width) ** 2)

def octaves(points):              # {Hz: value} table read between points by octave
    fs = sorted(points)
    return lambda f: float(np.interp(np.log2(f), np.log2(fs), [points[k] for k in fs]))

def profile(rng, n, levels, taus, lo=50.0, hi=16000.0):
    """Noise built to a measured profile ({Hz: dB}, {Hz: time constant}). Each band is scaled by
    the root of its width's inverse: a wider band of white noise is louder, so third-octave white
    noise measures 3 dB louder per octave up."""
    level, tau = octaves(levels), octaves(taus)
    return bands(rng, n, lo, hi, lambda f: 10 ** (level(f) / 20) * (1000 / f) ** 0.5, tau)

def click(rng, centre, tau, seconds=0.06):
    """A bolt, latch, relay, magazine seating: the tick of contact + a burst of bands."""
    n = samples(seconds); t = clock(n)
    tick = highpass(noise(rng, n), 1500) * np.exp(-t / 0.0004)
    body = bands(rng, n, centre / 4, min(centre * 4, 18000), peak_at(centre, 0.9),
                 lambda f: tau * (centre / f) ** 0.5)
    return norm(0.6 * norm(tick) + norm(body))

def thump(rng, n, cutoff, tau):
    """Low weight of an impact: low-passed noise. NOT a falling sine (that is a kick drum)."""
    return norm(lowpass(noise(rng, n), cutoff, 4) * decay(n, tau))

def ring(n, modes):               # damped sines (freq, tau, amp), each computed until -80 dB
    t = clock(n); out = np.zeros(n)
    for f, tau, amp in modes:
        if f < 0.45 * SR:
            m = min(n, int(tau * 9.2 * SR) + 1)
            out[:m] += amp * np.exp(-t[:m] / tau) * np.sin(2 * np.pi * f * t[:m])
    return out

def metal(rng, n, lo, hi, count, tau):
    """Steel: `count` random modes, each with a twin a few cents off to beat against, Rayleigh
    strengths, higher ones dying a little sooner. Low modes no louder or longer than the rest:
    when they were, the lowest pair outlasted everything and rang as a note."""
    modes = []
    for f in np.exp(rng.uniform(np.log(lo), np.log(hi), count)):
        a = rng.rayleigh(0.5) * (f / lo) ** 0.3
        d = tau * (lo / f) ** 0.3 * rng.uniform(0.5, 1.5)
        modes += [(f, d, a), (f * rng.uniform(1.001, 1.006), d, a * rng.uniform(0.3, 0.9))]
    return ring(n, modes)
```

### Grains

```python
def scatter(rng, n, rate, grain):
    """Grains at Poisson times; rate (per second) may change every sample."""
    rate = np.broadcast_to(np.asarray(rate, float), (n,)); out = np.zeros(n)
    for i in np.nonzero(rng.random(n) < rate / SR)[0]:
        g = grain(rng); m = min(len(g), n - i); out[i:i + m] += g[:m]
    return out

def speck(rng, lo, hi, seconds):  # an octave-wide speck of noise: debris, spray, grit, crackle
    m = max(8, samples(seconds)); c = np.exp(rng.uniform(np.log(lo), np.log(hi)))
    return bandpass(rng.standard_normal(m), c / 1.41, min(c * 1.41, 0.45 * SR)) * np.exp(-np.arange(m) / (m / 4))

def bubble(rng, f0, seconds, rise=3.5):
    """Farnell's bubble: a sine rising as it shrinks. Long + midrange = cartoon bloop. Real water:
    about 6 ms, 1-6 kHz, hardly rising."""
    n = samples(seconds); t = clock(n)
    return np.sin(phase(f0 * (1 + (rise - 1) * t / seconds), n)) * np.exp(-t / (seconds / 4))
```

Midrange specks (500 Hz up, dense, over a sheet of noise) are a **squelch**: right for flesh and
spit, wrong for water. Water's grain is high.

### Electronics: never ship a bare oscillator

```python
def speaker(rng, x, lo, hi, drive=2.0):
    """A cheap speaker in a panel or horn: band-limited, coloured by random cone resonances,
    overdriven lopsidedly, buzzing where loud, over faint hiss and 60 Hz hum."""
    n = len(x); y = highpass(lowpass(x, hi), lo)
    for _ in range(3):
        y = eq(y, "peak", np.exp(rng.uniform(np.log(lo * 1.5), np.log(hi / 1.5))), rng.uniform(3, 6), rng.uniform(4, 8))
    y = norm(y)
    y = highpass(np.tanh(drive * y + 0.3) - np.tanh(0.3), lo / 2)     # lopsided: cone travels further one way
    buzz = bandpass(noise(rng, n), 2000, 7000) * lowpass(np.abs(y), 40)
    hum = partials(60.0, n, lambda k: (1 / k) if k % 2 else 0.4 / k, top=1200)
    return norm(y) + 0.12 * norm(buzz) + 0.003 * highpass(noise(rng, n), 1000) + 0.004 * norm(hum)
```

The speaker's hiss/hum floor runs to the end of its buffer: **fade the buffer's last few ms**
before placing it into a longer sound, or the floor stops dead as a cut.

### Mixing

```python
def place(into, sound, at):       # add `sound` into `into` from `at` seconds
    i = samples(at); m = min(len(sound), len(into) - i)
    if m > 0: into[i:i + m] += sound[:m]
    return into

def drive(x, amount):             # tanh saturation with the peak kept: loud without peaking
    peak = np.max(np.abs(x)) + 1e-12
    return np.tanh(amount * x / peak) / np.tanh(amount) * peak

def loop(x, overlap):             # seamless loop for NOISY textures: equal-power crossfade of the overrun
    m = samples(overlap); length = len(x) - m; u = np.arange(m) / m
    y = x[:length].copy()
    y[:m] = x[:m] * np.sin(0.5 * np.pi * u) + x[length:] * np.cos(0.5 * np.pi * u)
    return y

@functools.cache
def _recording(sound_id):         # a committed recording, 16-bit mono 44.1 kHz WAV, read-only
    with wave.open(str(SOURCES / f"{sound_id}.wav")) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2") / 32768.0
    x.flags.writeable = False; return x

def recording(sound_id, start=0.0, end=None):   # material, as deterministic as noise
    x = _recording(sound_id); return x[samples(start): None if end is None else samples(end)].copy()
```

---

## Part 4: recordings as material

**Licence: only what allows a commercial sale.** CC0 and CC BY 3.0/4.0. Never NC, never Sampling+.
CC BY means crediting the author, so the manifest records the author. The fetch script checks the
licence on the sound's page against an allow-list and against the manifest, and checks the
uploader, before downloading anything.

**What to download: Freesound's high-quality preview** (MP3, 44.1 kHz, ~200 kbps), which needs no
login. Originals need a logged-in session or an approved API application. As material that is
filtered, pitched and layered, the preview's codec ceiling (~16 kHz) is above what the sound keeps.
Preview URL pattern: `https://cdn.freesound.org/previews/NNN/ID_USERID-hq.mp3`. Check the `-hq`
preview answers before adding a row (some sounds only have `-lq`).

**Fetch on the user's machine.** Freesound returned 403 to a cloud container (pages, API, CDN). Run
`fetch.py` locally and commit the results. Use it sparingly: add rows in a few batches.

**Decode once, commit the WAV.** ffmpeg decodes each MP3 into `ID.wav` (16-bit mono, 44.1 kHz, no
metadata) beside it; the build reads only the WAV. An MP3 decoder may round differently on another
machine; a committed WAV cannot. So the export never needs ffmpeg or the network.

**One manifest per family** (`sources/steps.toml`, `weapons.toml`, ...), so parallel batches never
edit one file:

```toml
[[recording]]
id = 788231
url = "https://freesound.org/s/788231/"
author = "amsaenz03"
licence = "CC0-1.0"
why = "step_concrete: boots jogging on gritty concrete, a footfall per take"
sha256 = "3726b835..."   # left "" in a new row; fetch.py writes it on first download
```

```python
ALLOWED = {
    "creativecommons.org/publicdomain/zero/1.0/": "CC0-1.0",
    "creativecommons.org/licenses/by/3.0/": "CC-BY-3.0",
    "creativecommons.org/licenses/by/4.0/": "CC-BY-4.0",
}
```

### Finding recordings

- Freesound's search ANDs every word: short queries find most ("rifle shot", "bolt action").
- The site answers 429 at more than about one page per 3 s. Wait 4 s between requests and back off.
- Every sound has a spectrogram image: take the preview URL, swap `/previews/` for `/displays/` and
  `-hq.mp3` for `_spec_L.jpg`. A contact sheet of those rules out reverberant, hummy and tonal
  recordings before anything is downloaded.
- **Read the description.** "Shotgun Reload" was a CO2 air pistol by the author's own note. Airsoft
  and plastic .22s are common.
- **One file can hold one event many times.** A "4takes" file was four mixes of one shot
  (cross-correlation 0.95-0.99): takes cut from it are one take. Cross-correlate events first.

### Cutting recordings

- **Find an onset by its rise, not by a level.** "12 dB over the 20 ms before" fired on a faint
  scuff ahead of the foot, so every footfall was cut 24-38 ms early and the steps sounded late. "The
  first frame within 20 dB of the peak", searched in a window that started inside an earlier event,
  found that event's ring. What works: find each event by the rise into it (dB per 2 ms) and the
  level of the 15 ms before it, then cut at the first frame within 20 dB of its own peak.
- **Start a cut 3 ms before its onset.** A cut's first 3 ms must rise into the event, never fall out
  of it. A cut that starts in the decay is a tail with no click: "the keys don't sound like keys".
- **44 samples are not a millisecond.** Framing in `int(0.001 * 44100)`-sample frames and reading
  frame k as k ms runs 0.23 % slow: 23 ms late at 10 s. Convert by `k * frame / SR`.
- **Place the cut so its onset falls on the beat**, at any varispeed.
- **A recording can carry a hidden note.** A real gun's blast can hide rings a few Hz wide (124 Hz
  under an autocannon, 74.5 Hz in a shotgun load, 12.6 kHz in a .50). Look for a peak's prominence
  over a third of an octave around it, past the FFT window's main lobe, up to 18 kHz (with a level
  floor: MP3 previews leave quiet lines above 15 kHz). Notch it narrowly (Q 8 or more).
- **Recorded voices hold their pitch** for 0.2-0.3 s, a line. Varispeed the recording along a
  designed pitch contour (a sob's slide, a scream's leap and collapse) to keep the throat and lose
  the note.
- **Measure a cut's highest pitch, not its median.** A moan that starts as a 620 Hz cry before
  settling at 250 Hz still squeaked after slowing.
- **Pitch and formants separate cheaply:** varispeed the recording, then stretch each 12 ms frame's
  cepstral envelope back by `formant / pitch` and apply it as a gain, phase untouched. No phasiness.
  A voice at one size in a throat of another is "not quite human". Slowed animal recordings read as
  what they are ("too much like a dog").

### Layering on recordings

- **Anything laid on a recording follows the recording's envelope.** Synth specks that sat under a
  60 ms synth hold stood out as clicks under a recorded shot that fell 20 dB in 42 ms.
- **A layer's first onset is not its hit.** A cannon's rumble rises 35 ms before its blast. Laid from
  its first onset under a shot, it is a second hit behind the crack, a flam. Cut each layer just
  before its own loudest hit.
- **A sub shorter than the roll above it ticks where it stops.** Fade it, or run it to the end.
- **Ducking a tail to hear the action shortens the shot** ("too short, should have a long bam").
  Instead, crossfade the tail into a zero-phase low-passed copy after ~0.15 s: the long bam stays,
  and the bolt's stops stand 12-20 dB over it at 1.5-9 kHz.
- **A recording that runs on buries the beats after it.** Fade a crash before the debris lands.

### Voices behind a radio

Infall's squad speaks over a helmet radio, and the owner wanted the words "complete unrecognizable,
just sound like muffled/distorted radio from inside the helmet". **Clipped telephone-band speech is
still understood**: clipping is kind to speech, and the 300 Hz-3.4 kHz band keeps the consonants.
What takes the words away: smear each frequency's level in a short-time Fourier transform over
110-150 ms (phase kept, so pitch and cadence survive), a steep 450-650 Hz low pass for the visor,
then compression, a hard lopsided clip, a sample-rate drop with no anti-alias filter (fold-back
grit), the band limit, static that rises into the speaker's pauses, squelch ticks and a "kshh" at
the end, and finally the helmet's padding (a 900-1300 Hz low pass). Real recorded men worked better
than speech synthesizers (eSpeak, MBROLA, Flite were all rejected as robotic or painful).
**A band limit holds only after the last thing that distorts**: limit again after the speaker sim.

---

## Part 5: measuring recordings (analyze.py)

```bash
uv run audio/analyze.py REF.wav https://cdn.freesound.org/previews/... --against sfx/step_water_0.wav --png out/
```

A source is any file ffmpeg reads, or a URL fetched once into a gitignored cache. Each recording is
cut into events (an onset is a 5 ms frame 15 dB over the quietest of the 50 ms before it, within
20 dB of the loudest event, at least 0.3 s after the last), and the medians over events printed:

- per third-octave band, 63 Hz-12.7 kHz: level against the loudest band, when it peaks, time to fall 20 dB
- **hold**: how long the whole stays within 6 and 20 dB of its peak (a burst holds, a blow does not)
- crest factor
- graininess: bursts per 100 ms above 2 kHz
- **blips**: short tonal peaks 12 dB over their neighbours, held 3+ frames of 1.5 ms (bubbles, plinks)
- spectral flatness (near 1 is noise)
- any lasting tone

`--against` prints a take's profile beside the recording's. `--png` writes spectrograms.

**From measurement to sound:** copy the band levels and their 20 dB times (divided by 2.3 to get a
time constant) into `{Hz: value}` tables, build with `profile`, measure the take `--against` the
recording, close the gap. **A profile is not the whole sound**: per-band decays describe a body
ringing down (a blow). A burst (a shot) wants the spectrum under one held envelope: look at the
waveform too. Grain, blips and crackle are added as events, at the measured counts.

Measurement traps:

- Medians over 0.3 s events blur a pump's two strokes into one. Time an action's parts with 2-5 ms
  frames and a 25 ms gap.
- A long continuous recording (wading through water) cuts into hundreds of "events". Use the
  stricter thresholds above; medians resist the strays.
- Over 10-30 s an engine averages its tones away (7-9 dB over neighbours); over 1 s the same
  recording shows them at 11-18 dB. Compare take and recording over the same window.
- A band's level is its loudest 5 ms frame, so a long burst measures as its first frames. For long
  or continuous sounds, compare long-term spectra.
- **A clean tone in a dry file stands out further than it ever does in the world.** A recorded
  forklift beeper is 17 dB over the noise around it; a synth square through a speaker sim was 65.
  Rasp a tone with noise until its prominence matches a recording heard at a distance. Rasp a whine
  at a fraction of its pitch (20-150 Hz for a 790 Hz whine); a rasp as wide as the tone is noise.
- **A liked take is the reference; a recording gives the difference.** Real footstep recordings have
  far more low end than the shuffly step the owner liked. Build new floors from what the recordings
  *differ in* (a steel deck's ring, a grate's rattle) on top of the liked step, not to the
  recordings' balance.

---

## Part 6: mastering (lib/master.py)

`render` turns a built signal into the shipped take:

1. **25 Hz high pass**: no DC, nothing below what a speaker plays.
2. **Trim**: keep 1 ms before the first sample within 60 dB of the peak, 20 ms after the last, fade
   the last 10 ms. Silence before a sound delays it after the player's click. A `synced` sound keeps
   its lead-in (trimming would pull every beat early). A loop is never trimmed.
3. **Bring to level** in LUFS over its loudest 400 ms: K-weighted mean square (ITU-R BS.1770)
   "momentary" loudness, no gating. A sound shorter than 400 ms counts as padded with silence, so a
   click measures quieter than its peak, as the ear hears it.
4. **Hold under a -1 dBFS ceiling.** A sound that cannot reach its level under it ships quieter and
   the export says so: `peak-limited, 0.5 dB short of -17`. Watch for that line.

```python
CEILING_DB = -1.0

def render(sound, variant):
    x = finishing.apply(sound.build(seed(sound.name, variant)), sound.finish, sound.loop)
    if sound.loop:
        x = dsp.highpass(np.tile(x, 2), 25)[len(x):]          # filtered as a circle: the seam sees what every sample does
    else:
        x = trim(dsp.highpass(x, 25), head=not sound.synced)
    gain_db = sound.level - loudness(x)
    peak_db = 20 * np.log10(np.max(np.abs(x))) + gain_db
    limited = peak_db > CEILING_DB
    if limited:
        gain_db -= peak_db - CEILING_DB
    y = x * 10 ** (gain_db / 20)
    return Take(sound.file(variant), y, loudness(y), 20 * np.log10(np.max(np.abs(y))), limited, sound.loop)

def trim(x, floor_db=-60.0, head=True):
    loud = np.nonzero(np.abs(x) > np.max(np.abs(x)) * 10 ** (floor_db / 20))[0]
    start = max(0, loud[0] - dsp.samples(0.001)) if head else 0
    y = x[start: loud[-1] + dsp.samples(0.02)].copy()
    m = min(len(y), dsp.samples(0.01)); y[-m:] *= np.linspace(1.0, 0.0, m)
    return y

def loudness(x):
    """Momentary loudness at its loudest, LUFS: K-weighted mean square over the loudest 400 ms."""
    k = signal.sosfilt(np.vstack([dsp.biquad("highshelf", 1681.97, 0.7072, 4.0),
                                  dsp.biquad("high", 38.13, 0.5003)]), x)
    w = dsp.samples(0.4)
    sq = np.concatenate([[0.0], np.cumsum(np.pad(k ** 2, (0, max(0, w - len(k)))))])
    return -0.691 + 10 * np.log10(np.max(sq[w:] - sq[:-w]) / w + 1e-20)

def wav_bytes(x, loop=False):
    """Mono 16-bit PCM; `wave` writes no timestamp, so same samples = same bytes. A loop carries a
    `smpl` chunk with one forward loop over the whole file (Godot's importer reads it by default)."""
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(dsp.SR)
        w.writeframes((np.clip(x, -1.0, 1.0) * 32767).round().astype("<i2").tobytes())
    data = buf.getvalue()
    if loop:
        body = struct.pack("<9I", 0, 0, round(1e9 / dsp.SR), 60, 0, 0, 0, 1, 0) + struct.pack("<6I", 0, 0, 0, len(x) - 1, 0, 0)
        chunk = b"smpl" + struct.pack("<I", len(body)) + body
        data = data[:4] + struct.pack("<I", len(data) + len(chunk) - 8) + data[8:] + chunk
    return data
```

### The loudness table (Infall's, as a starting point)

| Sound class | LUFS (loudest 400 ms) |
|---|---|
| Grenade / explosion (loudest thing) | -15 |
| Gunshots | -17.5 to -20 (suppressed 2-4 dB under open) |
| Squad radio voice | -17 |
| Impacts, doors | -17 to -24 |
| UI clicks; UI played most | -26; -28 to -30 |
| Running machines (loops) | -26 to -34 |
| Footsteps | -28 to -33, by floor |

Lessons:

- **A dry shot cannot reach a loud target.** A dry gunshot's crest is ~15 dB, so a rifle asked for
  -14 came back at -17 peak-limited; a grenade asked for -10 came back near -16. Set the table from
  what the sounds reach.
- **A spike cannot be driven under the ceiling.** `drive` keeps the peak and lifts what is under it.
  Lower the spike against the body.
- **Sounds that hand over must be levelled at the handoff.** A spool levelled by its loud cough ended
  5 dB under the idle loop it hands to. Measure the windows either side of a handoff in the shipped
  files, and re-measure whenever a layer changes in either sound.
- **Low noise is louder than it looks.** A sub of low-passed noise normalised to the same peak as the
  broadband gas came out the loudest band by 10 dB. A third of the level was right.
- **A dip on the loudest layer is a boost to the rest**, since the loudest 400 ms is pinned to the
  level.

---

## Part 7: timing to the screen

For each sound tied to an animation or effect, keep a table: the sound, what plays on screen and
where (clip name, length, playback speed, file), and each beat in seconds. Copy the beats into the
sound with a comment naming the source. A change to the clip means re-timing the sound. Example
rows from Infall:

| Sound | On screen | Beats |
|---|---|---|
| `reload` | `soldier_anims.reload`, 1.88 s, played at 1.2x: 1.567 s | hand on mag 0.25; stowed 0.6; drawn 0.75; seated 0.917; handle back 1.133; slam 1.3; settled 1.567 |
| `door_slide` | `DoorView.SlideSeconds` | slide 0.3 s, the stop at its end |
| `explosion` | `Fx/Explosion.cs` | flash 0.1 s, pressure wave 0.45, fireball 1.2, 14 chunks land within ~1.5 s |
| `drip` | `Drip.cs`: bead 0.6 s, falls 2.19 m | lands 1.27 s after the bead appears; 6 droplets back in 0.20-0.36 s later |

- A sound timed to a clip is `synced=True` and keeps its lead-in silence.
- A sound triggered by the event itself (a shot with its round) starts at the event and needs nothing.
- **Read the game's own timing, not only the clip's.** Death clips handed the body to a ragdoll 0.3 s
  in, so a landing timed to the clip at 0.62 s played to nothing.
- **Read what a constant measures.** `BoltThrow 0.1` was 0.10 m of travel, not seconds.
- **A drop's let-go is not its landing.** The hands open at 0.28 s; the item lands 0.16 s later.
- **A control the screen steps is an edit in the sound.** An engine throttle that jumps in one frame
  stopped the roar like a cut. Smooth it (an engine answers in tens of ms).
- If a clip fuses two parts the ear needs apart (charging handle released and bolt slammed 17 ms
  apart), the clip can be re-keyed to give the sound room. The owner did this for the reloads:
  "slowing the racks in the animations sounds like a good idea!"

---

## Part 8: loops

- **Noisy textures** (fire, wind, hum with grit): build a second longer than the loop, crossfade the
  overrun into the start at equal power (`dsp.loop`).
- **Tonal loops** (a whine, an engine line): a crossfade adds a tone to itself (sin + cos) and it
  swells 3 dB through the overlap. Build periodic instead: noise made in the frequency domain
  (circular by construction), every oscillator and LFO a whole number of cycles in the loop length,
  filters run over the loop twice with the second pass kept, reverb convolved circularly.
- **Loops of events** (breaths, claws): place each event modulo the loop length, the overrun added
  at the start. No crossfade (it would play events in the overlap twice).
- Mastering filters a loop as a circle (tile twice, keep the second copy) and never trims it.
- **The WAV's `smpl` chunk makes it loop** in Godot whatever plays it (import loop mode "Detect From
  WAV"). A sound that changes from a one-shot to a loop must change its call site, or it loops where
  it was meant to play once.

---

## Part 9: the listening sheet and the review page

**The sheet** (`--sheet DIR` writes `DIR/sheet.html` and `DIR/media/`): every take twice, **dry**
and **in a corridor** (a synthetic impulse response: early reflections, a 1.3 s decay, highs dying
sooner, used only for previews), each with a log-frequency spectrogram (30 Hz-20 kHz), length,
loudness and peak, and the sound's docstring and chain. Where the export changed a take, the old file
plays beside it. `--changed REF` holds only takes that differ from a git ref's committed files
(compare against git, not the files on disk, or takes already exported fall off the sheet).

Judge gunshots in the corridor: dry, a shot is a short thing; underground, most of it is the space.

**What Claude checks in a spectrogram:**

- a horizontal line outlasting the rest: a note (the main one)
- a vertical line through the whole spectrum: a click (an envelope that stops above zero, a buffer
  that ends mid-ring, a crackle whose last tick is as loud as the rest, a linear fade to zero)
- a tail held up by saturation
- `peak-limited` in the export output

**The review page** (`page.py OUT --only PREFIX`): a folder with an `index.html`, the catalog
inlined, published as a shareable page. Per sound: before, A, B, played in sync, dry or corridor,
spectrograms in the browser, docstring and why. Marks stored per sound with a note. `--all` makes
the triage page (every take as it ships, good / rough / remove). A candidate is named `NAME_b`
beside `NAME`.

**A kept candidate keeps its bytes.** The seed hashes the name, so keeping `spit_b` as `spit`
redraws every random choice and the take the owner picked is gone. The kept build re-seeds itself
from the name it was heard under: `rng = master.seed("spit_b", master.take(rng))`. Check with `cmp`.

---

## Part 10: playing them in the engine (Godot 4.6 notes)

- **The camera is not the ear.** An orthographic camera 60 m back puts every sound ~60 m away, all
  equally faint. Hang an `AudioListener3D` over the floor at the middle of the screen, turned with
  the camera, raised as the camera zooms out.
- **Use your own distance curve, not the engine's.** Each sound has a **reach** class: full level
  within a near distance, -6 dB per doubling past it, then a fade to nothing over its last stretch so
  nothing stops at an edge. Infall's classes: Faint (2 m, gone by 6-11 m: lamp buzz, drip), Hum (3 m,
  9-16: machines), Close (4 m, 16-26: steps, reloads), Room (6 m, 28-42: doors, impacts), Far (9 m,
  45-70: gunshots, alarms), Map (14 m, across the whole map: explosions, ships).
- **Spread the balance back out in the game.** Files are mastered close together; the game adds a
  per-sound **trim** (blast +6 dB, guns +2 to +3, steps -2, lamps -3), the reach, and the listener's
  height. Measured in the game's own mix: a grenade -12 LUFS, a burst -17, a step ~25 dB under a
  burst. The world sits 3 dB under the radio and UI. A limiter on master (-0.5 dBFS) catches stacks.
- **Rooms lend the reverb**: one bus per kind of space (cave, hall, corridor), each with its reverb.
- **Through walls**: a sound whose path to the listener's side crosses matter plays through a bus
  with a 900 Hz low pass. Not for being out of sight: down an open corridor it is only farther.
- **Voice limits**: at most N of a sound at once (a new one takes the oldest's place). Loops: only
  the nearest few of a kind, re-sorted several times a second.
- **Take choice**: each play draws a take, never the one played last. Sounds not timed to a clip
  wander a few percent in pitch and ~1 dB in level, so a burst's rounds are not identical.
- **A loop coming back in starts where its own clock says**, not from its first offset, or every
  re-entry sounds like a restart.
- Import: WAV (Godot compresses it with QOA by default), Ogg only for music and long speech.

Godot traps found:

- **The distance filter is on even with attenuation model `Disabled`.** A high shelf at 5 kHz
  (`attenuation_filter_cutoff_hz`), depth `attenuation_filter_db` (-24) times one less the player's
  linear level: a player at -20 dB loses ~22 dB of highs. Know it's there.
- **`max_db` caps volume at 3 dB by default**: a trim past it is lost silently. Raise it.
- **A bus sends only to a bus before it** in the list. `AudioServer` outlives a scene: lay out buses once.
- **Audio ignores `Engine.TimeScale`.** Slow motion leaves sounds at speed, off their clips.
  `AudioEffectPitchShift` on transients at 3.3x sounded "SUPER distorted" (a phase vocoder smears
  every crack) although a check built of tones passed it. **A measure is not an ear.** Infall
  pre-renders time-stretched variants at the game's clock speeds at boot (WSOLA) and hands over.
- **A 3D player starts its stream on its next physics tick, not at `Play`.**
- **A WAV's playback position runs up to 128 samples ahead** of what was heard (the resampler reads ahead).
- **The dummy audio driver (`--headless`) mixes in lumps** of up to 0.3 s: fades become steps. Use
  `--headless --audio-driver WASAPI` to measure the mix without a window.
- **Never play sounds from an effect's spawner** if effects are pre-warmed off-map: they play there.
- Godot's movie writer records the mix in step with frames: the game's own mix can be measured.

---

## Part 11: more synthesis traps (quick reference)

- **Taking a layer out changes everything drawn after it** (one Generator, drawn in order). To add a
  layer without moving liked ones, draw it from `np.random.default_rng(rng.integers(2**63))` taken
  after every other draw.
- **A refactor's default must reproduce the old formula.** After any change to `lib/`, count how many
  takes changed against git. More than intended means a default moved.
- **A ring cut off by its buffer is a truncation.** Size the buffer to ~5 time constants of the
  slowest mode, or fade the sound yourself.
- **Every layer placed into a longer sound must end at zero on its own.**
- **A straight fade to nothing is a cliff** (in dB it drops 40 dB in its last hundredth). Fade
  through halving points (0.3, 0.08, 0) or exponentially.
- **Saturating a whole sound hard makes its tail ring**: saturation compresses tails as much as
  peaks. A gentle drive does round off the in-phase spike when 80 struck modes start together.
- **A motor's tone held for seconds is the loudest line in the spectrum**, even when it looks quiet
  in the waveform. Make long motors as noise in a band, chopped at the rotor's speed.
- **A knock every N cm at speed is a buzz** (115 knocks/s is a 115 Hz tone). Rattle is Poisson at a
  rate that follows speed; only the few real joints are placed by distance.
- **An engine's whine left running after its roar is a note.** Running, the roar hides it; cut, it
  goes with the roar. Line width as a share of frequency (2-4 %), not fixed Hz.
- **A crossfade from a muffled copy to a clear one brings the highs in as a step.** Use a moving
  low pass instead.
- **Steady rustle under a whole clip is hiss.** Cloth is a patter of fine friction grains over a
  soft swish, thickening with speed.
- **A struck bar ringing 10 ms under a low pass is wood** ("putting down some sticks"). Metal rings
  45-70 ms at 1-4 kHz after the knock, contact tick and highs left in.
- **A machine's death is its own sound dying** (its motors spinning down, its contactor dropping out),
  not generic bangs and fizz.
- **Performance:** per-grain filter design is slow by the thousand. Cache designs (snap centres to a
  sixth of an octave), filter fixed-band grains once as a whole, build short layers short, and make
  very narrow noise bands at a 32nd of the sample rate and interpolate up.
- **Never pipe the export into `head`**: it dies on the next print and later takes are not written.
- **`--only` is a prefix**: `--only machine_` also matches `machine_short`. Export by full names when
  two people work at once.

---

## Part 12: the optional SoX finishing stage

A per-sound chain of SoX effects run before mastering, written as SoX's command line, e.g.
`finish=finish.band(300, 0.7, 4) + finish.glue(2, attack=0.0005)`. Blocks: `air` (treble shelf,
slope 0.5), `weight` (bass shelf), `band` (equalizer, Q 2 at most: a narrow boost on noise is a
note), `floor`/`top` (2-pole high/low pass), `glue` (compand, soft knee), `drive` (overdrive).

How a take goes through: peak set to -12 dBFS first (SoX clips at full scale between effects, and
level-dependent effects then mean the same for every take); last 10 ms faded, then 0.25 s of
silence appended so filter ringing is kept; loops go through three times and the middle copy is
kept; `sox -R -D` (seeded randomness, no dither), 32-bit float both ways; any clipping or length
change fails the export; a sound with no chain never touches SoX.

**Never in a chain**: anything that adds a room (reverb, echo, chorus, flanger) or moves time or
length (tempo, pitch, speed, pad, trim, fade).

Traps: a compressor with a 3 ms attack on a 60 ms hit *raises* the crest (it is a transient shaper);
use 0.5-1 ms for glue. SoX's shelves at slope 0.5 are broad: `treble -3 8000` cuts only 1.5 dB at
8 kHz. Sounds levelled against each other (spool, idle, lift-off) need the same chain, or none.

As said in Part 1: in Infall the owner heard no difference from this whole stage. It is optional.

---

## Part 13: setting it up in a new project

1. Install `uv`. Make `audio/` with `export.py` (pinned numpy/scipy in the header), `lib/dsp.py`,
   `lib/master.py`, `sounds/`. Copy the code in Parts 3 and 6.
2. Set SR to the engine's mix rate. Output mono 16-bit PCM WAV into the game's assets folder, named
   `NAME.wav` or `NAME_0.wav`, `NAME_1.wav`... Commit the WAVs.
3. Seed every take from `[crc32(name), take]`. No other randomness.
4. Write a loudness table and give every `Sound` a `level`.
5. Add the listening sheet early: dry + corridor + spectrogram per take. It is how Claude "looks" at
   sound.
6. Add `--check` and a pre-commit hook running it on `audio/` and the WAVs.
7. Add `fetch.py` + per-family manifests + licence allow-list; download Freesound HQ previews on the
   user's machine; decode once to WAV; commit both.
8. Add `analyze.py` to measure recordings before building anything that must sound real.
9. Make a triage page, then an A/B page with stored verdicts, and work in batches by family. Start
   with what sounds worst. The owner's order in Infall was voices, steps, weapons, enemies.
10. For each sound tied to an animation, write its beats table from the clip/effect source first.
11. In the engine: own listener, own distance curve with reach classes, trims, room reverb buses, a
    low-pass bus for through-walls, voice limits, no-repeat take choice, small pitch/level wander, a
    master limiter.
12. Record every trap you hit in a gotchas file, with what the human heard, in their words.
