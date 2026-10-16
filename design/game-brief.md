# Game Brief: Dead Signal

<!-- Written 2026-10-15 when the project moved to rigor: minimal. Condensed from
design/gdd/game-concept.md and design/gdd/systems-index.md. The GDDs, ADRs and UX specs
stay as reference for systems already built; new work is scoped here. -->

**One-sentence pitch:** Four survivors in a dark research facility recover evidence and power the evacuation, while the fifth player, a shapeshifter, walks among them wearing their friends' faces.

## Core loop
- Survivors split up to find drives, fuses and the terminal under a 9-minute clock. Splitting up is fast, but it is when the shapeshifter strikes.
- The shapeshifter observes survivors, borrows a face and blends in. It lunges when someone is alone, then misleads with False Signal and Blackout.
- Survivors defend with flashlights, tasers, hiding, barricades and pings. A downed teammate must be rescued before bleed-out.
- The Results screen shows what happened, and the lobby starts the next round.

## Player goal & fail state — what "working" looks like
- **Survivors win** by carrying both drives out of the exit once evacuation is active.
- **The shapeshifter wins** if every survivor is eliminated, or if the 540 s deadline passes.
- **Elimination:** the second down eliminates a survivor, and so does a 60 s bleed-out.
- **A round works when** it goes from the lobby to Results with no developer help, and at least one survivor doubts whether a teammate is the monster.

## MVP — what must exist to be the game
All MVP systems are built and merged as of sprint 9 (2026-10-15):
- lobby and roles;
- first-person controller;
- match flow;
- objectives;
- downing and rescue;
- survivor defense;
- Borrowed Face;
- monster abilities;
- pings;
- facility greybox;
- scare events;
- HUD and Results.

What remains for a shippable MVP:
- **Art pass:** an art bible, then textures and materials on the greybox and characters.
- **Audio pass:** real sounds in place of the placeholders, and a mix.
- **A settings menu** for the accessibility options: reduced motion, reduced flash and volume. Today these are command-line flags only.
- **Group playtest readiness:** an exported Windows build, and a verified two-PC session over a real network.

## Out of scope — not building this
- A second map or a second monster.
- Proximity voice (PC-9 is blocked).
- Matchmaking or public servers; play is host-and-join by address.
- Progression, unlocks and monetisation.
- Remapping UI.
- Match telemetry (Alpha, later).

## Build order
1. Group playtest of the greybox. It needs the export build and a two-PC check. This tests the core fantasy before art spend.
2. The art bible, which must respect three game rules:
   - the disguise copies appearance, so it must copy textures too;
   - nothing on a body may mark the shapeshifter;
   - everything must read under a flashlight.
3. Asset specs, then textures on characters, then textures on the facility.
4. Sign off the 10 carried look-and-feel stories against the textured build.
5. Audio pass.
6. Settings menu.

---
**Who it's for / what they feel:** Friend groups of 4 to 6 who like Among Us and Lethal Company and want the dread of not trusting the person next to them.

**Art & audio direction:** Abandoned lab and security-wing horror, near-dark and flashlight-lit. The art bible will set the specifics (`design/levels/research-facility.md` defers to it).

**Reference game:** Dead by Daylight crossed with Among Us. Keep one map, one killer kit and one round type, with the killer hiding inside the team. Drop perks, meta-progression and multiple killers.
