# Milestone 1: Vertical Slice

> **Status**: Closed 2026-10-13 — slice built (1 day); group playtest skipped by designer decision, verdict NOT ASSESSED, direction PROCEED
> **Start**: 2026-10-13
> **Hard time limit**: 10 working days of build, then playtest
> **Chosen by**: designer, 2026-10-13 (first milestone after the Production gate)
> **Build**: `prototypes/dead-signal-vertical-slice/` (reference only; never refactored into production)

## Validation Question

Do 3–5 players over Tailscale, starting at the main menu with no guidance, feel
"you can't be sure the person next to you is a person" (core fantasy,
`design/gdd/game-concept.md`) within the first 5 minutes of a round? And can one
complete round — drives, terminal, escape, or the shapeshifter downing everyone —
be built in 10 working days at greybox quality?

## Scope

Auto-accepted (recommended option: smallest set that completes one round), 2026-10-13 (AD-55).

**In**
- Main menu: host / join by address, display name. Lobby: host starts with 2–6 players; one random shapeshifter; survivors get distinct characters C1–C5 (colour and silhouette).
- Whole Research Facility greybox generated from the map sketch (`design/levels/research-facility.md`): walls, glass, doors that toggle, archways, exit.
- Dark lighting with per-survivor flashlights.
- Movement: walk, sprint, crouch; crawl when Downed (`first-person-controller.md` values).
- Borrowed Face: observe a survivor in view for `observe_time_s`, 2 s transform with distortion cue, 12 s cooldown, true form (`borrowed-face.md`).
- Predatory Lunge from true form only: 0.6 s wind-up, 4 m / 0.3 s dash, hit → takedown commit 1.5 s → Downed (`monster-abilities.md`, `downing-and-rescue.md`).
- Downed: crawl, 60 s bleed-out, 6 s rescue hold, second down eliminates.
- Taser: 2 cartridges, 5 m, stun 2 s, immunity 6 s (`survivor-defense.md`).
- Objectives: 2 of 6 drive candidates (5 s extract), 1 of 3 terminals (15 s activation), exit opens, carrying both drives out wins (`survivor-objectives.md`, `match-flow.md` rule 11).
- Round clock 540 s with Infiltration / Investigation / Evacuation; monster wins on all eliminated or deadline; results screen.
- Minimal HUD: clock and phase, objective line, hold progress, prompts, taser charges; monster: observed faces, cooldown.

**Out (cut, not deferred quality)**: fuses, pings and callouts, scare events, Blackout and False Signal, hiding, barricades, cameras, spectating, reconnect, proximity voice, server-authoritative movement (positions are owner-authoritative in the slice; hits, downs, disguise and objectives are server-decided).

## Success Criteria

1. A round reaches a result screen from the main menu with no developer help (both outcomes seen across sessions).
2. A first-time survivor finds the first objective within 2 minutes of the round start.
3. At least one playtester, unprompted, describes doubting whether a teammate is the monster.
4. No crash or soft-lock in 3 consecutive rounds.
5. Velocity logged per build day in the slice REPORT.md.

## Risk Register

| # | Risk | Likelihood | Impact | Mitigation | Owner |
|---|------|-----------|--------|-----------|-------|
| R1 | Clock drift and Wi-Fi spikes untested (spike tests 4–5 skipped) | Medium | Medium | Server input buffer (ADR-0002); watch the slice sessions | network-programmer |
| R2 | Dodge margin 27 ms; WAN RTT p95 above the ~113 ms full-compensation bound | Medium | Medium | Keep the dodge AC as a regression test (ADR-0003) | gameplay-programmer |
| R3 | Slice uses owner-authoritative movement, so it says nothing about prediction feel | High | Low | Network feel already measured by the spike; production follows ADR-0002 | technical-director |
| R4 | No group playtest: designer skipped it 2026-10-13, so core-loop fun and the core fantasy are unvalidated going into Core work | High | High | Record sessions; think-aloud; 3+ sessions before Feature epics | designer |
| R5 | No art bible; greybox may misread tone | Medium | Low | `/art-bible` after the slice verdict | art-director |
| R6 | AD-01..AD-55 auto-decisions unreviewed | Medium | Medium | Designer review pass before Sprint 2 | designer |
