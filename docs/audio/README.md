# Audio

How Dead Signal's sounds are made. Every sound is built by code in `tools/audio/` from real recordings (and
dense noise bodies where nothing real is needed), mastered to a loudness table, and shipped as mono 16-bit
44.1 kHz WAV under `assets/audio/<family>/`. The game reads them through `data/audio/sound_bank.tres`
(`src/core/audio/sound_bank.gd`), which the same build writes.

| Page | What it holds |
|---|---|
| [pipeline-handoff.md](pipeline-handoff.md) | The designer's instructions for how sounds must be made (from the Infall project): lessons, layout, building blocks, recordings, measuring, mastering, loops, review pages. Binding. |
| [gotchas.md](gotchas.md) | Traps hit in this project, with what was heard or seen. |

## Commands

```bash
uv run tools/audio/export.py                  # build every sound, the bank and production/qa/evidence/audio/loudness.md
uv run tools/audio/export.py --only amb_      # write only names starting so
uv run tools/audio/export.py --check          # write nothing; exit 1 if a file differs from what the code makes
uv run tools/audio/fetch.py                   # download manifest rows (tools/audio/sources/*.toml) not on disk
uv run tools/audio/fetch.py --search "room tone"      # CC0 hits with licence, author, description, spectrogram URL
uv run tools/audio/analyze.py 144046          # measure a recording (bands, hold, crest, lasting tones)
uv run tools/audio/review.py ambience         # build tools/audio/review/ambience/index.html (A/B page)
```

## Rules (designer)

- No sci-fi sounds: no lasers, force fields, space engines, sci-fi doors, glitch bleeps. Grounded horror in a
  research facility.
- Anything that must sound real (steps, voices, creature, doors, impacts, glass, room tone) is built on real
  recordings. Licence: CC0, CC BY 3.0/4.0 only; the author goes in the manifest.
- Hearing: -1 dBFS ceiling, loudness table in `tools/audio/lib/master.py` (`FAMILIES`), nothing harsh or piercing.
- The stinger as played (file + `stinger_max_db_rel`) stays at most 6 dB over every bed (SE-8 AC-2,
  `tests/unit/audio/sound_bank_test.gd`).

## State

| Family | Directory | Status |
|---|---|---|
| Ambience (amb_a, amb_b, amb_c, amb_link) | `ambience/` | Rebuilt from recordings; 3 candidates each on the review page, pick pending |
| Steps, voices, cues (creature), world (doors, impacts, alarms), scares, UI | `foot/ voice/ cue/ world/ scare/ ui/` | Placeholders: the earlier shipped sound, resampled, from `tools/audio/sources/legacy/`. Rebuilt in later batches. |
