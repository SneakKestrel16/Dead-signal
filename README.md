# Dead Signal

A first-person, five-player asymmetric psychological horror game. Four
survivors enter an abandoned research facility to recover evidence and restore
power to an evacuation system. The fifth player is a shapeshifter that can wear
their faces.

- **Players:** exactly 5 — 1 human shapeshifter vs. 4 human survivors
- **Round:** ~9 minutes (tuned in playtests)
- **No AI monsters.** Every threat in the facility is controlled by a person.

## Status

**Concept / systems design.** No engine has been chosen yet and there is no
game code. Current work is design documentation.

| Document | What it is |
| --- | --- |
| [`design/gdd/game-concept.md`](design/gdd/game-concept.md) | Pitch, pillars, core loop, MVP definition |
| [`design/gdd/systems-index.md`](design/gdd/systems-index.md) | Every system, its priority, dependencies and design order |
| [`design/gdd/`](design/gdd/) | Per-system game design documents (drafts) |
| [`design/levels/research-facility.md`](design/levels/research-facility.md) | The single greybox map |
| [`design/source/`](design/source/) | The original game design document and build brief |

## Design pillars

1. **Human Deception** — the monster is always a player, and it can pretend to be one of you.
2. **Fair Fear** — scares surprise, but never guarantee damage or take control away for long.
3. **Counterplay** — every monster tool has a survivor answer.
4. **Readable Objectives** — players always know their next goal, even when they distrust each other.
5. **Small, Shippable Scope** — one map and one complete round before anything else.

## Development setup

This project uses the [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)
framework (MIT, see [`LICENSE`](LICENSE)): a set of Claude Code agents, skills,
hooks and document templates organized like a game studio.

Requirements: Git, [Claude Code](https://code.claude.com/docs/en/setup), Python 3
and Bash (jq recommended). Open Claude Code in this folder, then:

- `/help` — what to do next
- `/setup-engine` — choose and pin the engine (next step for this project)
- `/design-review design/gdd/<file>.md` — review a design doc
- `/review-all-gdds` — check the design docs against each other

Project settings live in [`project.yaml`](project.yaml) (rigor: `standard`).
See [`UPGRADING.md`](UPGRADING.md) to update the framework.

## Roadmap

1. Networked greybox — 5-player lobby, role assignment, first-person movement
2. Complete round loop — drives, fuses, evacuation, timer, downing, rescue, results
3. Core monster and counterplay — Borrowed Face, Lunge, stun, hiding, doors, False Signal, Blackout
4. Horror pass — lighting, spatial audio, jumpscares, accessibility
5. Closed playtest — tune from real groups

No second map, progression, ranked matchmaking or extra monsters until the
first map and full round work.
