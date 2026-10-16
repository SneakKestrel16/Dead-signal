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
