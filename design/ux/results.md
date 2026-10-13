# UX Spec: Results Screen

> **Status**: Draft (all sections authored)
> **Author**: SneakKestrel16 + ux-designer
> **Last Updated**: 2026-10-12
> **Journey Phase(s)**: Round end, between a round and the next lobby (no player journey map exists; see Open Questions)
> **Platform Target**: PC; keyboard/mouse primary, gamepad Partial; 16:9 at 1080p reference, 16:10 and 21:9 supported
> **Template**: UX Spec

Inputs: `match-flow.md` rules 17, 23–27 (Match Flow owns the data, HUD & Results Screen owns presentation), the results rows of `survivor-defense.md`, `downing-and-rescue.md`, `monster-abilities.md`, `borrowed-face.md` and `survivor-objectives.md`, `lobby-role-assignment.md` rules 17 and 19, `design/accessibility-requirements.md` (Standard tier) and `design/ux/interaction-patterns.md` (P16, P17, P19, P23, P28). Decisions made without the designer are logged as AD-29 to AD-33 in `production/auto-decisions.md`.

---

## Purpose & Player Need

The player arrives wanting to know **who won, why, and what happened to everyone**. In a deception game the round ends with open questions ("was that Ben or the monster?"), and the results screen is where the table finally sees the truth together. It must answer, in order of glance: the outcome, the reason, each survivor's fate, then the objective and stat detail that settles arguments. It never asks the player to do anything: the next round starts from the lobby (`match-flow.md` rule 27).

---

## Player Context on Arrival

The player has just finished about nine minutes of tension. They were either escaping, Downed, spectating after elimination, or playing the shapeshifter. The gameplay input froze one second ago and the screen faded (`match-flow.md` rule 17, round-end freeze row). Survivors who were eliminated early have been spectating and may already know part of the story; survivors who escaped know nothing of what happened behind them. The shapeshifter wants to see whether its disguises worked. Everyone is likely talking on voice chat at once: the screen must be readable at a glance, and must not race the conversation.

---

## Navigation Position

```
Main menu ─▶ Host / Join ─▶ Lobby ─▶ (Loading ─▶ Round) ─▶ RESULTS ─▶ Lobby
                                                      │
                                       Host left ─────┴─▶ Main menu (P16 "Host left")
```

Results is a leaf between the round and the lobby. It is not reachable from any menu, except the read-only **Last round** view opened from the lobby (Entry & Exit Points).

---

## Entry & Exit Points

| Entry | Trigger | Notes |
|---|---|---|
| Round end | Client receives `RoundEnded` with the results payload (`match-flow.md` rule 17) | Same moment on all clients, within 500 ms (`match-flow.md` timing table) |
| Lobby "Last round" button | Player activates it in the lobby | Read-only copy of the last payload held in client memory; no countdown; Back closes it (AD-31) |

| Exit | Trigger | Destination |
|---|---|---|
| Auto-return | `results_duration_s` (20 s) elapses on the server | Lobby, Ready cleared (`lobby-role-assignment.md` rule 17) |
| Leave session | Player activates **Leave session** and confirms | Main menu; the player leaves the lobby (AD-30) |
| Host left | `server_disconnected` during Results | Main menu with P16 "Host left" (`lobby-role-assignment.md` rule 19) |
| Back (Last round view only) | Esc / B / Back button | Lobby |

There is no "skip" or "continue" button: the return is server-timed so every player reaches the lobby together (AD-29).

---

## Layout Specification

### ASCII Wireframe

```
┌───────────────────────────────────────────────────────────────────┐
│                     SURVIVORS WIN                          [Z1]   │
│                  Evidence escaped  ·  8:12                        │
├──────────────────────────────────┬────────────────────────────────┤
│ [Z2 SURVIVORS]                   │ [Z3 OBJECTIVES]                │
│  Ana   Escaped  (2 drives)       │  Drives recovered  2/2   3:40  │
│        downs 1 · rescues 2       │  Drives docked     2/2   5:55  │
│  Ben   Eliminated (Bled out)     │  Fuses installed   2/2   6:30  │
│        downs 2 · rescues 0       │  Evacuation active Yes   7:44  │
│  Cy    Did not escape            │  Drives extracted  2/2   8:12  │
│  Dee   Disconnected              │                                │
│                                  │                                │
│  Shapeshifter: Eli               │                                │
├──────────────────────────────────┴────────────────────────────────┤
│ [Z4 STATS]  Match 8:12 │ Takedowns 3  Eliminations 1  Lunges 4/7  │
│  Stunned 2  Form changes 5  False Signals 3  Blackouts 1          │
│  Survivor stuns landed 2  Rescues 3                               │
├───────────────────────────────────────────────────────────────────┤
│ [Z5]  Returning to lobby in 14        [Leave session]             │
└───────────────────────────────────────────────────────────────────┘
```

### Layout Zones

| Zone | Position | Contents |
|---|---|---|
| Z1 Outcome | Top band, centred | Outcome line, reason line, final round time |
| Z2 Survivors | Left column | One row per survivor (P23), then the shapeshifter's name |
| Z3 Objectives | Right column | Five objective lines with completion times |
| Z4 Stats | Lower band | Match duration and the rule 26 stats, grouped shapeshifter then survivors |
| Z5 Footer | Bottom band | Countdown to the lobby; Leave session button |

All zones keep a 48 px safe margin at 1920 × 1080; at 21:9 the content sits in a centred 16:9 rect (same rule as `design/ux/hud.md` Platform Adaptation). Z2–Z4 sit in one P28 scroll container so 5 survivors at 150% UI scale still fit; Z1 and Z5 never scroll.

### Component Inventory

| ID | Component | Pattern | Content | Source |
|---|---|---|---|---|
| R1 | Outcome line | — (large text) | "SURVIVORS WIN" / "SHAPESHIFTER WINS" | rule 23 outcome |
| R2 | Reason line | — (text) | One of the five reasons in rule 23, plus final round time | rule 23 reason |
| R3 | Survivor row | P23 List row | Name, fate word, drives carried if Escaped, downs taken, rescues performed | rule 24 |
| R4 | Shapeshifter name | — (text) | "Shapeshifter: [name]" | rule 24 |
| R5 | Objective line | — (text) | Label, x/2 or Yes/No, completion time or "—" | rule 25 |
| R6 | Stats block | — (text grid) | Rule 26 counts, each with a word label | rule 26 |
| R7 | Countdown | — (text) | "Returning to lobby in N" | `results_duration_s` |
| R8 | Leave session | P19 secondary button | Opens a P16 confirm ("Leave this session?") | AD-30 |
| R9 | Back (Last round view) | P19 secondary button | Replaces R7 and R8 in the lobby view | AD-31 |

### Information Hierarchy

1. Outcome (R1) — read in under a second, largest text.
2. Reason and time (R2) — why the round ended; rule 23 failure texture ("the reason line always says why").
3. Survivor fates (R3) and the shapeshifter's name (R4) — the reveal the table discusses.
4. Objective progress (R5) — settles "how close were we".
5. Stats (R6) — detail; smallest type that still meets 24 px.
6. Countdown and Leave (R7, R8) — present but quiet.

---

## States & Variants

| State | Trigger | What changes |
|---|---|---|
| Survivors win | Outcome survivors | R1 "SURVIVORS WIN"; reason "Evidence escaped" |
| Shapeshifter wins | Outcome shapeshifter | R1 "SHAPESHIFTER WINS"; reason one of "All survivors eliminated", "Evidence lost", "Evacuation deadline expired" |
| Forfeit | Reason "Shapeshifter forfeited" | R1 "SURVIVORS WIN"; R4 reads "Shapeshifter: [name] (disconnected)" |
| Populated (normal) | Payload complete | As wireframe |
| Empty fields | Objective never completed | Time column shows "—"; counts show 0, never blank |
| 3 survivors | 4-player round | Z2 shows 3 rows; layout does not stretch |
| Disconnected survivor | Fate Disconnected | Row shows "Disconnected"; downs and rescues still shown |
| Payload error | `RoundEnded` arrives with a missing or invalid payload field | R1/R2 still shown if present; the unusable block shows "Results unavailable" in its zone; countdown unaffected; logged client-side (AD-32) |
| Loading | — | None: the payload arrives with `RoundEnded`; the 1 s round-end fade covers the transition |
| Host left during Results | `server_disconnected` | Screen closes at once; main menu with P16 "Host left"; the Last round copy is discarded |
| Last round view | Opened from lobby | No R7/R8; R9 Back shown; title "Last round" above R1 |
| Leave confirm open | R8 activated | P16 dialog over the screen; countdown keeps running; if it reaches 0 the dialog closes and the player goes to the lobby |

Timer: the countdown is driven by the server's return; R7 counts down from `results_duration_s` using the client tick estimate and is cosmetic (the server's move to the lobby wins if they disagree).

---

## Interaction Map

| Action | Mouse | Keyboard | Gamepad (Partial) | Result |
|---|---|---|---|---|
| Read / scroll | Wheel over Z2–Z4 | Up/Down, PgUp/PgDn | Left stick / D-pad | P28 scroll |
| Focus rows | Hover | Tab / Shift+Tab through R3 rows, then R8 | D-pad | Focus ring on row (screen reader reads the row) |
| Leave session | Click R8 | Focus R8, Enter | Focus R8, A | P16 confirm: Leave / Stay |
| Back (Last round view) | Click R9 | Esc | B | Return to lobby |
| Esc on the live screen | — | Esc does nothing | B does nothing | Prevents accidental leave (AD-30) |

Focus order: R3 rows top to bottom, R8 (or R9). Initial focus: none on the live screen (no accidental activation from a held key at round end); R9 in the Last round view.

---

## Data Requirements

| Element | Source system | Owner | Update | Null handling |
|---|---|---|---|---|
| Outcome, reason, final time | Match Flow `RoundEnded` payload | Match Flow | Once | Payload error state |
| Survivor fate, drives carried | Match Flow (from Downing, Objectives) | Match Flow | Once | "Results unavailable" in Z2 |
| Downs taken, rescues performed | Downing & Rescue stats via Match Flow | Downing & Rescue | Once | 0 |
| Shapeshifter name | Lobby roster via Match Flow | Lobby & Role Assignment | Once | "Shapeshifter: unknown" |
| Objective counts and times | Survivor Objectives via Match Flow | Survivor Objectives | Once | "—" for missing times |
| Takedowns, eliminations, lunges landed/missed, False Signals, Blackouts | Monster Abilities via Match Flow | Monster Abilities | Once | 0 |
| Form changes | Borrowed Face via Match Flow | Borrowed Face | Once | 0 |
| Times stunned, survivor stuns landed | Survivor Defense via Match Flow | Survivor Defense | Once | 0 |
| Countdown | `results_duration_s` knob + client tick estimate | Match Flow | 1 Hz | Hidden if knob missing |

The UI owns no game state. The aggregation interface behind the payload is TR-matchflow-008 (Stats/results interface ADR, not yet written).

---

## Events Fired

| Player action | Event | Notes |
|---|---|---|
| Leave session confirmed | Client calls `NetAuthority` disconnect | Server sees a normal lobby leave (`lobby-role-assignment.md` rule 18) |
| Back (Last round view) | None | Local navigation |
| Scroll / focus | None | Local |

No gameplay event: results are read-only.

---

## Transitions & Animations

| Transition | Spec | Reduced motion |
|---|---|---|
| Enter from round | 1 s fade from the frozen frame (`match-flow.md` round-end freeze); R1 appears first, Z2–Z4 200 ms later | Cut |
| Outcome sting | Audio sting per role and outcome (`match-flow.md` audio row); no visual flash | Unchanged |
| Exit to lobby | 300 ms fade | Cut |
| Countdown tick | Number change only | Same |

No element flashes; no pulse.

---

## Input Method Completeness Checklist

**Keyboard/mouse**
- [x] Every action reachable by mouse
- [x] Every action reachable by keyboard alone (Tab, Enter, Esc, arrows)
- [x] Focus order defined; focus visible
- [x] No hover-only information

**Gamepad (Partial)**
- [x] Leave and Back reachable by D-pad and face buttons
- [x] Scroll by stick or D-pad
- [ ] Whether every menu must be fully gamepad-navigable is open project-wide (`accessibility-requirements.md` Open Questions); this screen already is

---

## Accessibility

Committed tier: Standard.

- **Text**: menu minimum 24 px at 1080p (stats included); R1 at least 48 px; scales with UI scale 75–150%.
- **Contrast**: body ≥ 4.5:1, R1 ≥ 3:1 as large text, verified on retained screenshots.
- **No colour-only state**: outcome and fates are words; win/lose colour is decoration only.
- **Reading time**: the screen does not wait for input, but the full results stay readable afterwards through the lobby's Last round view (`accessibility-requirements.md` Reading time row; AD-31).
- **Screen reader** (constraint taken although not committed at Standard): stock `Control` nodes; every row and button has an accessible name ("Ana, Escaped with 2 drives, 1 down, 2 rescues").
- **Reduced motion**: fades become cuts.

---

## Localization Considerations

| Text | Max chars (English) | Notes |
|---|---|---|
| R1 outcome | 20 | Plan for 40% expansion; R1 shrinks to 40 px before wrapping |
| R2 reason | 32 | Longest English: "Evacuation deadline expired" (27) |
| Fate word | 16 | "Did not escape" (14); row wraps to two lines if needed |
| Objective label | 22 | Column width allows 40% expansion |
| Stat label | 20 | Grid reflows to more rows rather than truncating |
| Player names | 16 | Fixed by `lobby-role-assignment.md` (1–16 chars) |
| Countdown | 32 | "Returning to lobby in {n}" with a number placeholder |

No string is concatenated from fragments; counts use plural-aware formats.

---

## Acceptance Criteria

- [ ] With 5 clients, every client shows the results screen within 500 ms of `RoundEnded`, with identical outcome, reason, fates, objective lines and stats.
- [ ] Each of the five rule 23 reasons produces the matching R1 and R2 text (one forced round per reason).
- [ ] A survivor who disconnected shows "Disconnected"; one who bled out shows "Eliminated (Bled out)"; an escaped carrier shows the drive count.
- [ ] Objectives never completed show "—" in the time column and 0 or "No" in the count; no field is blank.
- [ ] After 20 s every client is in the lobby with Ready cleared; no input is needed.
- [ ] Pressing Esc or B on the live screen does nothing; Leave session requires the confirm.
- [ ] The lobby's Last round view shows the same content as the live screen, with Back and no countdown.
- [ ] With a 4-player round and 150% UI scale at 1920 × 1080, all content is reachable by scroll and every text element measures at least 24 px (retained screenshots in `production/qa/evidence/`).
- [ ] At 1920 × 1080, 2560 × 1080 and 1920 × 1200 every element keeps the 48 px safe margin (64 px from the 16:9 safe rect at 21:9).
- [ ] The screen renders its first frame within 100 ms of `RoundEnded` on the reference PC (excluding the 1 s fade).
- [ ] With a deliberately corrupted payload field, the affected zone shows "Results unavailable" and the countdown still returns the player to the lobby.

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Player journey map not yet created. Author it from the template at `.claude/docs/templates/player-journey.md` to establish player context for this screen. | SneakKestrel16 | Before first playtest | Unresolved |
| Stats/results interface ADR (TR-matchflow-008) not written; the payload shape is assumed | technical-director | Before Match Flow implementation | Unresolved |
| Should survivors' own disguise encounters ("Ben was the monster at 4:10") be shown? Not in any GDD | SneakKestrel16 | Before Milestone 2 | Not shown (no GDD requirement) |
| Must every menu be fully gamepad-navigable (Input checklist, unticked)? | SneakKestrel16 | Before UI ADR | Project-wide open question; this screen already is |
| Final visual treatment | art-director | Art bible | Layout only |
