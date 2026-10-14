<!-- VERTICAL SLICE - NOT FOR PRODUCTION -->
<!-- Validation Question: does one networked greybox round deliver "you can't be sure the person next to you is a person"? -->
<!-- Date: 2026-10-13 -->
# Vertical Slice Report: Dead Signal

> **Date**: 2026-10-13
> **Slice Duration**: 1 build day (hard limit was 10)
> **Target Scope**: one full 9-minute round (Match Flow sets the length; longer than the template's 3–5 minutes by design)
> **Source GDD**: design/gdd/game-concept.md; scope in `production/milestones/milestone-01-vertical-slice.md` (AD-55)
> **Run**: first slice (not a re-run after a PIVOT)

---

## Validation Question

Do 3–5 players over Tailscale, starting at the main menu with no guidance, feel "you
can't be sure the person next to you is a person" within the first 5 minutes of a
round? And can one complete round (drives, terminal and escape, or the shapeshifter
downing everyone) be built in 10 working days at greybox quality?

---

## Scope Built

**Systems included:**
- Main menu, host or join by address, lobby, random shapeshifter, distinct survivor characters C1–C5
- The whole Research Facility, generated from the level doc's sketch: walls, glass, doors, archways, exit
- Dark lighting, flashlights, generated footsteps and cues
- Movement: walk, sprint, crouch, crawl
- Borrowed Face: observation, transform, cooldown, true form, reveal
- Predatory Lunge from true form, takedown commit, downs, bleed-out, rescue, elimination
- Taser with the GDD lock rules (one lock for all, no refresh, post-lock window)
- Two of six data drives, one of three terminals, docking, activation zone, ejected drives, exit and escape
- Round clock, phases, outcome checks and results screen
- HUD: clock, objective line, prompts, hold bar, roster, feed, shapeshifter panel

**Art/audio quality level:** Placeholder (greybox primitives, generated tones).
**Shortcuts taken deliberately:** owner-authoritative movement with no prediction or rewind (ADR-0002/0003); no per-peer information hiding (ADR-0004); hits against the server's latest positions.
**What was cut from original scope:** fuses, pings and callouts, scare events, Blackout and False Signal, hiding, barricades, cameras, spectating, reconnect, proximity voice.

---

## Build Velocity Log

| Day | Completed |
|-----|-----------|
| Day 1 (2026-10-13) | Entire slice: data, map generator, networking, lobby, all in-scope rules, HUD, results, bot and scenario tests (20/20 rule checks pass in the editor and exported build), 10 evidence screenshots, Windows export. Bug from the first designer session fixed the same day: the HUD crosshair swallowed mouse look (72a2c19). |

**Total elapsed:** 1 day for one complete greybox round with every in-scope rule.
**Velocity estimate:** greybox rule work is fast, because the GDDs already fix every number and edge case. The slow parts will be the ones the slice skipped: prediction, rewind and per-peer hiding (ADR-0002/0003/0004), art and audio. Do not use this day as the rate for production stories, which carry tests and ADR compliance.

---

## Playtest Results

| Attribute | Value |
|-----------|-------|
| Total sessions | 1 (designer, solo, two windows on one PC) |
| Internal testers | 1 |
| External testers | 0 |
| Avg session length | Not recorded; stopped partway after testing the mechanics |
| Time to first meaningful action | "When I saw the creature" (no time measured) |

---

## Observations

**Where testers succeeded without guidance:**
- "Pretty self-explanatory" for the build's stage (designer).
- All mechanics were tried; nothing blocked or confused the designer once mouse look was fixed.

**Where testers were confused or stuck:**
- Mouse look did not work in the first session (HUD crosshair ate mouse motion). Fixed in 72a2c19.

**Emotional reactions observed:**
- The first moment that felt like play was seeing the creature (true form).

---

## Metrics

| Metric | Target | Actual |
|--------|--------|--------|
| Time to first meaningful action | ≤ 2 min to first objective (milestone criterion 2) | Not measured |
| Session length | One full round | Stopped partway |
| Critical fun blockers found | 0 | 1, fixed (mouse look) |
| Pipeline blockers found | 0 | 0 |
| Architecture surprises | 0 | 1: Godot's default offline peer counts as "has a peer", which broke hosting until checked as ENet explicitly |

**Feel assessment:** Not assessed by a multi-player group. The designer's solo note was that it "looked fine for how long it took". The shapeshifter's true form has no light, so its view is very dark (`09`/`10` evidence shots); watch this in the group session.

---

## Recommendation: NOT ASSESSED — nobody has played a complete round with other people

The slice is built and every in-scope rule passes the automated round test, so the
feasibility half of the question is answered: one complete round took 1 day of the 10
allowed. The experience half is not. The only session was the designer alone with two
windows, which cannot test whether you doubt a teammate. It also stopped before the
results screen. Validation items 1 (a full loop without guidance) and 3 (core fantasy)
are therefore unchecked, not failed. **Designer's direction: PROCEED** (debrief Q6,
2026-10-13). It becomes the verdict once one group session completes a round.

**Designer decision, 2026-10-13:** skip the group playtest and continue production. The verdict stays NOT ASSESSED; the unvalidated fun is carried as milestone risk R4.

**Creative Director review (CD-PLAYTEST):** not run — lean mode, and the slice has not been played by a group yet.

---

## If Not Assessed

**Next step:** one unguided group session (3–5 players over Tailscale, at least one full
round to the results screen, think-aloud or recorded), then re-run `/vertical-slice`
from the debrief. It resumes from the checkpoint in `production/session-state/active.md`.

Watch for, in that session:
1. Does anyone, unprompted, doubt whether a teammate is the monster (milestone criterion 3)?
2. Time from round start to the first drive found (criterion 2).
3. Whether the shapeshifter can see enough in true form.

---

## Lessons Learned

- **What assumptions were broken by building to near-production quality?**
  The GDD numbers held up as written: no rule needed a new decision to implement.
  The visibility table (AD-51) was not needed for the slice, because the slice skipped per-peer hiding.
- **What surprised us about the pipeline or architecture?**
  Two engine traps that were invisible in headless tests. The default offline
  multiplayer peer reports `has_multiplayer_peer()` true, and a full-rect or centred
  `Control` with the default STOP filter eats captured-mouse motion before
  `_unhandled_input`. Both belong in a Godot gotchas page before production UI work.
- **What would we change about the slice scope if we ran this again?**
  Schedule the group playtest at the start, not the end: the build was not the bottleneck.

---

> *Vertical slice code location: `prototypes/dead-signal-vertical-slice/`*
> *This code is reference material only. Production implementation is written from scratch.*
> *Never import or refactor this code into production.*
