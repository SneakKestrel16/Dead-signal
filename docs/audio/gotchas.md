# Audio gotchas

Traps hit in this project. The general ones are in [pipeline-handoff.md](pipeline-handoff.md) Parts 1, 5 and 11.

## Tooling

- **Freesound's page `<meta name="description">` is a site boilerplate**, not the sound's description. The real text
  is in `<div id="soundDescriptionSection">`; `fetch.py --info` reads it. Read it before downloading: it tells you
  about traffic, beeps, "on/off" transients (source: sound pages 608741, 837886, 864882 checked 2026-10-16).
- **The `data-mp3` on a sound page is the `-lq` preview**; `fetch.py` swaps in `-hq`.
- **A worktree checks LFS files out as pointer files** (129 bytes starting `version https://git-lfs`). Run
  `git lfs pull --include="assets/audio/**"` before reading any WAV in a worktree, or `sox` and `wave` fail with a
  baffling format error.
- **The old beds were Ogg.** The 12 s loops are now WAV with a `smpl` chunk (Godot "Detect From WAV" loops them);
  the `.ogg.import` files must go with the Ogg, and the bank entry keeps `loop = true`.
- **Loudness numbers changed meaning.** The old build reported gated integrated loudness; `lib/master.py` measures
  the loudest 400 ms with no gate, and a clip under 400 ms counts as padded with silence. A placeholder kept "as
  shipped" reports its own measurement as target. The stinger is the one legacy sound that is levelled
  (`-30.5`), so SE-8 AC-2 keeps its number.
- **Resampling 48 kHz to 44.1 kHz overshoots**: `fuse_install` came back at -0.8 dBFS from a -1.0 file. `render`
  pulls a kept sound under the -1 dBFS ceiling.

## Sound (what was heard / measured)

- Not yet judged by the designer: ambience candidates are on the review page. Record the verdicts here.

## Godot

- **`tools/audio/` sits inside the Godot project, so the editor imports every recording and legacy WAV** (123 `.import`
  files appeared after `--import`). `tools/audio/.gdignore` stops it; keep the file.

## Family batches (2026-10-16)

- **`analyze.measure` fails on clips under 8192 samples** (186 ms: "noverlap must be less than nperseg"), which broke
  `review.py` for UI ticks. `nperseg=min(len(x), 8192)` fixes it (scares/UI batch).
- **`export.py --only` is a name prefix**: `--only ui_` does not export `ping_rejected`; use `--only ping_`.
- **Short ticks hit the -1 dBFS ceiling before -26 LUFS** (a clip under 400 ms counts as padded with silence): UI
  ticks are levelled at about -29.
- **`fetch.py --search` crashes with a cp1252 error** on pages containing "►": set `PYTHONIOENCODING=utf-8`.
- **Freesound search costs about 35 s with `--n 5`**: every hit is one info request at 4 s spacing.
- **A Python script run from `%LOCALAPPDATA%\Temp` imports whatever sits beside it**: an unrelated `inspect.py`
  there shadows the stdlib and breaks numpy. Keep scratch scripts in a clean folder.
- **Pitch estimates mislead on short, rough voiced sounds** (octave errors from autocorrelation and the
  `analyze.py` tone detector): never set a pitch ratio from one reading (voices batch).
- **Envelope correlation says nothing about whether words survive radio smearing**: only the designer's ear can
  (voices batch).
- **A "screams" recording has breath dips inside a segment** that an energy gate misses: print a 50 ms envelope and
  cut the steady stretch. Freesound 439441 (`bear_mad`) is one roar looped about 4 times, flat at -7 dB.
- **No recording of a pane that cracks but stays was found**: `scare_glass_break` is built from ice cracking and glass
  pieces; the designer's ear decides.
- **The export's loudness report used the family default as every sound's target**; a sound with its own `level`
  (pain cry -19.5) then failed `sound_bank_test`. The target column is now the sound's own level.
- **MP3 previews leave spectral lines at 15-17 kHz** that read as tones once a cut is pitched down: low-pass them
  (cues/world batch).
- **Sparks and mains recordings carry a hum** that moves to about 70 Hz when pitched: high-pass or de-line it.
- **Transient-heavy cuts** (stun gun, body hits, locker slams) come back peak-limited until saturated (`dsp.drive`).
- **A real siren's own pitch is a lasting line** (objective_alarm B/C at ~382 Hz): left in, de-lining blunts the
  alarm; the designer's ear decides.
- **Raw footstep takes are peak-limited at -24 LUFS** (worst came back at -26.4): `dsp.drive` of about 2.6 fixes it
  (steps batch).
- **Slowed claws ring at 4-7 kHz and a rubber carpet hums at 86/92 Hz**: notch per take on the live part only;
  measured on the padded buffer the silence dominates the median and nothing is found.
- **Scrapes rise slowly and an onset detector skips them**: cut them from 10 ms level regions read off the
  spectrogram.
