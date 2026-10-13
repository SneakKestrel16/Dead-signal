# Auto-Made Decisions — Review Log

Decisions taken without asking while `modes.automation` is `autonomous` (set in `project.local.yaml`, 2026-10-12). Each one is a default you have not yet confirmed. Change **Review** to `Accepted` or `Overridden: <what instead>`; an override means the cited file needs editing.

The raw, append-only log is `production/session-logs/decision-log.md` (gitignored, written by `log_decision`). This file is the tracked, reviewable copy and carries only the decisions that change a design document.

| ID | Date | Skill | Decision | Chosen | Alternatives | Why | Applied in | Review |
|---|---|---|---|---|---|---|---|---|
| AD-01 | 2026-10-12 | ux-design accessibility | Pause during a round | No pause; settings open as an overlay and apply live | Pause | An online PvP round cannot pause | `design/accessibility-requirements.md` Cognitive | Pending |
| AD-02 | 2026-10-12 | ux-design accessibility | Callout feed reading time | Each line ≥ 8 s, 10-line scrollback on one key | Auto-dismiss only | Feed is a gameplay channel | `design/accessibility-requirements.md` Cognitive; patterns P9 | Pending |
| AD-03 | 2026-10-12 | ux-design accessibility | Which sounds get a visual backup | Lunge wind-up and transform distortion only | All gameplay-critical audio | Backups for footsteps, install noise, False Signal or the hide cue would expose fakes or out-hear hearing players | `design/accessibility-requirements.md` Auditory | Pending (playtest at M5) |
| AD-04 | 2026-10-12 | ux-design accessibility | Mono audio | Deferred to Open Questions | Commit now | Above Standard tier; cheap but unscoped | `design/accessibility-requirements.md` Auditory, Open Questions | Pending |
| AD-05 | 2026-10-12 | ux-design accessibility | Menu screen reader | Not committed; menus must use stock `Control` nodes | Commit; no constraint | Comprehensive tier, but nearly free if menus stay stock | `design/accessibility-requirements.md` Platform; patterns P17 | Pending |
| AD-06 | 2026-10-12 | ux-design accessibility | Per-feature matrix status | Every gameplay system marked Partial | Addressed | Mitigations are designed, nothing is built | `design/accessibility-requirements.md` Matrix | Pending |
| AD-07 | 2026-10-12 | ux-design accessibility | Limitations list | 7 limitations incl. no proximity-voice captions (CVAA risk logged) | Fewer, or caption voice | No speech-to-text in scope; voice optional and off by default | `design/accessibility-requirements.md` Known Intentional Limitations | Pending |
| AD-08 | 2026-10-12 | ux-design patterns | Library source | 18 patterns extracted from GDD UI Requirements and the accessibility doc | Wait for screen specs | No screen spec exists; the gate needs the library | `design/ux/interaction-patterns.md` | Pending |
| AD-09 | 2026-10-12 | ux-design patterns | Warning ping on a point | Double-press within 0.4 s | Separate binding | Keeps one ping input | Patterns P5 (proposed) | Pending |
| AD-10 | 2026-10-12 | ux-design patterns | Character while the in-round overlay is open | Stops (client sends empty intent) | Keeps last input | No stuck sprint into danger | Patterns P15 (proposed) | Pending |
| AD-11 | 2026-10-12 | ux-design patterns | Progress bars shown to the shapeshifter | Hidden for objectives it cannot affect; break progress shown | Show all | Follows the GDD UI tables | Patterns P4 | Pending |
| AD-12 | 2026-10-12 | ux-design patterns | Callout wheel and mouse look | Wheel captures mouse look while open; strafing stays live | Look stays free | Inference; open question | Patterns P6 | Pending |
| AD-13 | 2026-10-12 | ux-design patterns | Hold-bar cancel causes | Six labels: Hit, Shocked, Moved away, Lost sight, Released, Taken | Generic "Cancelled" | Controller GDD: a reset always shows its cause | Patterns P3 | Pending |
