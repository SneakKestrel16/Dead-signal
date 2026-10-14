<!-- VERTICAL SLICE - NOT FOR PRODUCTION -->
<!-- Validation Question: does one networked greybox round deliver "you can't be sure the person next to you is a person"? -->
<!-- Date: 2026-10-13 -->
# Dead Signal — Vertical Slice

**Status**: built; verdict NOT ASSESSED (designer direction PROCEED) until one group session plays a full round. Report: [REPORT.md](REPORT.md).
Milestone and scope: `production/milestones/milestone-01-vertical-slice.md` (AD-55).
Reference only: production code is rewritten from the GDDs and ADRs, never copied from here.

## Validation question

Do 3–5 players over Tailscale, starting at the main menu with no guidance, feel "you
can't be sure the person next to you is a person" within the first 5 minutes of a
round? And can one complete round be built in 10 working days at greybox quality?

## How to play (players)

1. The host runs `DeadSignalSlice.exe`, types a name, presses **Host a session**,
   and tells the others their Tailscale IP (`tailscale ip -4`, a `100.x.y.z` address).
   On first launch Windows asks to allow network access: allow it on private networks.
2. Everyone else runs the exe, types a name and the host's address, and presses **Join**.
3. The host presses **Start round** (2–6 players; balance assumes 5). One player is
   picked at random as the shapeshifter; everyone sees who, but not which body.

Controls: WASD move · Shift sprint · Ctrl crouch · E interact (hold) · F flashlight ·
LMB taser (survivor) or Lunge (shapeshifter, true form only) · 1–5 borrow an observed
face · Q true form · Esc release the mouse (click to recapture).

Survivors: find the 2 glowing data drives, dock them at the terminal (its room is on
the HUD), hold the terminal area for 15 s, pick the ejected drives up and carry them
out through the exit on C4's east wall. Shapeshifter: watch a survivor for 3 s to
copy their look, walk among them, change to true form to Lunge; two downs eliminate.

## How to run (developer)

```bash
bash run_test.sh                 # headless round: 20 rule checks, prints SCENARIO PASS
```

Godot 4.7.2 (path in `run_test.sh`, override with `GODOT=`). Screenshot capture
(windowed host, two headless bots):
`godot --path . -- --host --monster_name=BotA --autostart=3 --scenario=shots --nocapture --shots_dir=<abs dir>`
plus two `godot --headless --path . -- --join=127.0.0.1 --name=BotA|BotB --bot=idle`.
`--monster=1` instead gives the shapeshifter-view shots.

Export: `godot --headless --path . --export-release "Windows Desktop" build/DeadSignalSlice.exe`.
`export_presets.cfg` is gitignored repo-wide; recreate it with one `Windows Desktop`
preset, `include_filter="data/*"`, `binary_format/embed_pck=true`.

## What is in the slice

Menu and lobby (`menu.gd`, `net.gd`); the whole Research Facility generated from the
level doc's sketch (`map_builder.gd`, `data/facility.txt`); movement, flashlight,
footsteps and appearance (`player.gd`); every rule on the host (`game.gd`): Borrowed
Face observation, transform and cooldown, Lunge and takedown, downs, bleed-out and
rescue, taser with one lock for all and the post-lock window, drives, terminal,
activation zone, exit, clock, phases and outcome; HUD (`hud.gd`). Values come from
`data/knobs.json` (GDD Tuning Knobs; slice-only inferences listed in its `_notes`).

**Known deviations from the ADRs** (slice shortcuts, not decisions): movement is
owner-authoritative, with no prediction or rewind (ADR-0002/0003); every client
gets every player's state, so nothing is hidden per peer (ADR-0004); hits use the
server's latest positions without rewind.

## Velocity log

| Day | Date | Built |
|---|---|---|
| 1 | 2026-10-13 | Whole slice: data, map generator, networking, lobby, all in-scope rules, HUD, results, bot and scenario tests (20/20 pass, editor and exported build), 10 evidence screenshots (`production/qa/evidence/vertical-slice/`), Windows export |

## Findings

See [REPORT.md](REPORT.md). Designer solo session 2026-10-13: self-explanatory, no blockers after the mouse-look fix, first real play moment was seeing the creature; stopped before the results screen.
