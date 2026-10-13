# HUD Design

> **Status**: Draft (all sections authored)
> **Author**: SneakKestrel16 + ux-designer
> **Last Updated**: 2026-10-12
> **Platform Targets**: PC (keyboard/mouse primary, gamepad Partial); 16:9 at 1080p reference, 16:10 and 21:9 supported
> **Template**: HUD Design

Inputs: the UI Requirements of nine approved GDDs (`first-person-controller`, `match-flow`, `survivor-objectives`, `downing-and-rescue`, `survivor-defense`, `borrowed-face`, `monster-abilities`, `pings-and-callouts`, `scare-events`), `design/accessibility-requirements.md` (Standard tier) and `design/ux/interaction-patterns.md` (P1–P28). `lobby-role-assignment.md` is a menu (lobby spec, not HUD); `research-facility.md` has no UI Requirements section and no HUD needs beyond diegetic signage. No player journey map exists (Open Questions).

---

## HUD Philosophy

**Minimal but present, objective-first.** The facility, its lights and its sounds carry the fear; the HUD carries only what Readable Objectives (Pillar 4) and Fair Fear (Pillar 2) require. Objective state, the clock and the team roster are always on screen, because deception must never hide what survivors need to do next. Everything else appears only in context: prompts near a target, progress while holding, markers while alive. There is no health bar (life is three states, not a number), no minimap (discovery is a rule) and no on-body name tags (identity is the deduction, `lobby-role-assignment.md` AC-LB-31).

The HUD must never tell a player something their character could not perceive, and never distinguish real from fake (`design/ux/interaction-patterns.md` rule 2). The shapeshifter's HUD is a different, richer layer that survivors never receive.

---

## Information Architecture

### Full Information Inventory

| # | Information | Source GDD | Who sees it |
|---|---|---|---|
| I1 | Time remaining | match-flow | All in round |
| I2 | Current phase | match-flow | All in round |
| I3 | Escape / disconnect feed | match-flow | All in round |
| I4 | Objective checklist (drives x/2, fuses x/2, terminal state) | survivor-objectives | Survivors and shapeshifter |
| I5 | Drive carriers by name | survivor-objectives | Survivors |
| I6 | Discovered points, dropped items (world markers) | survivor-objectives | Survivors |
| I7 | Object progress bars (world) | survivor-objectives, survivor-defense | Nearby survivors |
| I8 | Activation countdown and pause | survivor-objectives | Survivors (and terminal) |
| I9 | Install alert | survivor-objectives | Shapeshifter |
| I10 | Teammate state (Healthy / Wounded / Downed / Eliminated) | downing-and-rescue | Survivors |
| I11 | Downed teammate marker with bleed-out ring | downing-and-rescue | Living survivors, never the monster |
| I12 | Own bleed-out remaining | downing-and-rescue | Victim |
| I13 | Rescue progress | downing-and-rescue | Rescuer and victim |
| I14 | Own Seized / Downed state | downing-and-rescue | Victim |
| I15 | Taser cartridges | survivor-defense | Survivors |
| I16 | Stun / immunity remaining | survivor-defense | Shapeshifter |
| I17 | Hide / barricade / break progress | survivor-defense | Actor |
| I18 | Available faces + observation progress | borrowed-face | Shapeshifter |
| I19 | Current form and form cooldown | borrowed-face | Shapeshifter |
| I20 | Transforming progress | borrowed-face | Shapeshifter |
| I21 | Ability cooldowns (Lunge, False Signal, Blackout) | monster-abilities | Shapeshifter |
| I22 | False Signal placement preview | monster-abilities | Shapeshifter |
| I23 | Blackout target zone | monster-abilities | Shapeshifter |
| I24 | Ping markers | pings-and-callouts | Recipients |
| I25 | Callout wheel | pings-and-callouts | Sender |
| I26 | Callout feed (last 4 lines) | pings-and-callouts | Survivors in range |
| I27 | Rate-limit feedback | pings-and-callouts | Sender |
| I28 | Flinch-off substitute pulse | scare-events | Player with flinch off |
| I29 | Interaction prompt | first-person-controller | Actor |
| I30 | Hold bar with cancel cause | first-person-controller | Actor |
| I31 | Crosshair (minimal dot) | first-person-controller | All |
| I32 | Lunge wind-up and transform cue indicators | accessibility-requirements | Players in audible range |
| I33 | Captions for PA countdown and scare voice lines (off by default) | accessibility-requirements | Players who hear the line, captions on |

### Categorization

| Category | Items | Why |
|---|---|---|
| **Must Show** | I1, I2, I4, I5, I10, I31; shapeshifter: I19, I21 | Pillar 4: "what next" and the clock are never hidden; the shapeshifter's core decisions are its form and cooldowns |
| **Contextual** | I6, I7, I8, I9, I11, I12, I13, I14, I15, I16, I17, I20, I22, I23, I24, I25, I27, I28, I29, I30, I32, I33 | Appear only when the rule that owns them is active |
| **On Demand** | Feed scrollback (I26 history), I18 face list (shapeshifter hold), Help in the overlay | Re-reading and planning, never needed mid-chase |
| **Hidden** | Footsteps, interaction noise, False Signal, hide cue, monster position, other players' roles | Audio-only or deliberately unknown (information parity) |

I3, I26 and I33 are Contextual feeds (they show only while lines are live). The Must Show list has 6 survivor items, consistent with "minimal but present".

---

## Layout Zones

Reference 1920 × 1080; all zones scale with HUD scale and keep a 48 px safe margin from every edge (64 px at 21:9 so nothing sits in the far periphery).

```
┌───────────────────────────────────────────────────────────────────┐
│ [Z1 ROSTER]                [Z2 CLOCK 06:42]              [Z3 OBJ] │
│  Ana   ●                     INVESTIGATION                Drives  │
│  Ben   ◐ Wounded                                          1/2 ◆Ana│
│  Cy    ✚ Downed                                           Fuses   │
│  Dee   ○                                                  0/2     │
│                                                           Terminal│
│                                                           Locked  │
│                                                                   │
│ [Z8 EDGE CUES: any edge]                                          │
│                          [Z4 CENTRE]                              │
│                               ·        ← crosshair, hold ring     │
│                        Hold E  Extract drive  ← prompt            │
│                        [Z5 REJECT / CAUSE]                        │
│                                                                   │
│ [Z6 FEED]                                                [Z7 KIT] │
│  Ben: Need rescue  ↗                                    ⚡ x2     │
│  Dee: Over here    ←                                              │
└───────────────────────────────────────────────────────────────────┘
World markers (pings, Downed, points) are anchored in the world and clamp to the edge.
```

| Zone | Position | Contents |
|---|---|---|
| Z1 Roster | Top left | Teammate names + life-state icon + word; carrier mark |
| Z2 Clock | Top centre | Time remaining, phase label, activation countdown under it when active |
| Z3 Objectives | Top right | Checklist (P12) |
| Z4 Centre | Screen centre, within 6% of height | Crosshair, hold ring (P3), prompt (P2) below |
| Z5 Feedback | Below the prompt | Reject reason (P10), hold cancel cause |
| Z6 Feed | Bottom left | Callout feed, escape/disconnect lines (P9) and captions (H18) |
| Z7 Kit | Bottom right | Taser cartridges (survivor); ability cooldowns (shapeshifter) |
| Z8 Edge cues | All four edges | Cue indicators (P8), clamped world markers (P7) |

Alternatives considered: objectives bottom-right (rejected: conflicts with the kit and is further from the clock players check together); roster under the objectives (rejected: one cluttered corner). Decision logged as AD-19.

**Shapeshifter layout** uses the same zones: Z1 shows the face list (names with observation progress), Z3 the same checklist, Z7 the cooldowns for Lunge, False Signal, Blackout and form change, and a Transforming bar replaces the prompt in Z4 while transforming.

---

## HUD Element Specifications

| ID | Element | Source | Category | Zone | Content | Visual form | Update | Trigger | Animation | Pattern |
|---|---|---|---|---|---|---|---|---|---|---|
| H1 | Clock | I1 | Must Show | Z2 | mm:ss remaining | Number | 1 Hz, server-corrected | Infiltration–Evacuation | Final 30 s: pulse in scale + ticking layer | P13 style |
| H2 | Phase label | I2 | Must Show | Z2 | "INFILTRATION" / "INVESTIGATION" / "EVACUATION" | Text | On `RoundPhaseChanged` | Always in round | 150 ms fade on change | — |
| H3 | Activation countdown | I8 | Contextual | Z2 | 15 s countdown, "Paused" when nobody holds | Number + text | Continuous | Terminal Activating | None | P4 |
| H4 | Roster | I10, I5 | Must Show | Z1 | Name, life-state icon + word, drive carrier mark | Text list | On change | Survivors, in round | 150 ms fade per row change | P12 |
| H5 | Objective checklist | I4 | Must Show | Z3 | Drives x/2 with state, fuses x/2, terminal state | Text list | On `ObjectiveProgressChanged` | Survivors and shapeshifter | Changed line highlights 1 s (no flash) | P12 |
| H6 | Crosshair | I31 | Must Show | Z4 | Dot | Icon | — | Always (hidden while Downed or hidden) | None | — |
| H7 | Interaction prompt | I29 | Contextual | Z4 | Verb, object, glyph, Hold/Press | Text | Per frame | Valid target | 150 ms fade | P2 |
| H8 | Hold ring | I30, I13, I17 | Contextual | Z4 | Progress, cancel cause | Radial bar | Per frame | Holding | 200 ms cancel/complete | P3 |
| H9 | Reject / cause label | I27 + any refusal | Contextual | Z5 | Short reason | Text | On reject | Refused action | 150 ms fade, 1.5 s | P10 |
| H10 | Callout and event feed | I26, I3 | Contextual | Z6 | `[Name]: [text]` + arrow; escapes, disconnects | Text lines | On event | Lines live | 150 ms fade, ≥ 8 s per line | P9 |
| H11 | Taser cartridges | I15 | Contextual | Z7 | Icon × count | Icon + number | On change | Survivor holding the item | Count change 150 ms | P13 |
| H12 | World markers | I6, I11, I24 | Contextual | World / Z8 | Pings, Downed + bleed-out ring, points, dropped items | Icon + label + metres | Per frame | Owning rule | Fade in 150 ms | P7 |
| H13 | World progress bars | I7 | Contextual | World | Server progress, "Paused" | Bar + % | Per tick | Object in progress | Linear | P4 |
| H14 | Edge cue indicators | I32, I28 | Contextual | Z8 | Lunge chevron, transform arc, flinch-off pulse | Shape | On cue | In audible range | 150 in / 300 out | P8 |
| H15 | Own state vignette | I14 | Contextual | Full screen | Seized / Downed / shocked + label | Edge treatment + word | On change | Own state | 250 ms | P11 |
| H16 | Own bleed-out | I12, I13 | Contextual | Z4 (replaces prompt) | Seconds remaining, rescue progress when rescued | Number + ring | Per tick | Own Downed | None | P3/P13 |
| H18 | Caption line | I33 | Contextual | Z6 | `PA: [text]` or `[Voice]: [text]`, no direction arrow | Text line | On voice line | Captions on, line heard | 150 ms fade, ≥ 8 s | P9 |
| H17 | Callout wheel | I25 | Contextual | Centre | 8 lines | Radial menu | On open | Wheel input | 100 ms open | P6 |
| S1 | Face list | I18 | Must Show (shapeshifter) | Z1 | Survivor names, observation progress, available mark | Text + bars | On change | Shapeshifter | None | P12 |
| S2 | Form and form cooldown | I19 | Must Show (shapeshifter) | Z7 | Current form name, cooldown | Text + sweep | 1 Hz | Shapeshifter | None | P13 |
| S3 | Ability cooldowns | I21 | Must Show (shapeshifter) | Z7 | Lunge, False Signal, Blackout | Icons + sweep + seconds | 0.1 s | Shapeshifter | Ready: shape change | P13 |
| S4 | Transforming bar | I20 | Contextual (shapeshifter) | Z4 | 2 s progress | Bar | Continuous | Transforming | Linear | P3 |
| S5 | Stun / immunity remaining | I16 | Contextual (shapeshifter) | Z4 | Seconds | Number + label | Per tick | Stunned or immune | None | P13 |
| S6 | Install alert | I9 | Contextual (shapeshifter) | World / Z8 | Randomised-centre area marker | Marker | 5 s | Fuse install alert | Fade | P7 |
| S7 | Placement preview | I22, I23 | Contextual (shapeshifter) | World | False Signal point/path, Blackout volume | Preview | Per frame | Aiming | None | P14 |

---

## HUD States by Gameplay Context

| State / Variant | Trigger | What Changes |
|---|---|---|
| Exploration (default) | Normal play, no hold, no threat cue | Must Show only + any live markers and feed lines |
| Combat / chase | Lunge cue, shock, or being Seized nearby | No extra elements: the HUD does not grow in a chase; edge cues (H14) appear; feed lines keep their timers |
| Holding | P1 hold started | Prompt replaced by hold ring; reject/cause label under it |
| Downed | Own state Downed | Vignette (H15), own bleed-out (H16) replaces the prompt; crosshair hidden; roster and objectives stay |
| Seized | Own state Seized | Vignette; prompt and ring hidden |
| Hidden | In a hiding spot | Crosshair hidden; prompt shows "Leave" only; everything else stays (peek view details: open gap) |
| Spectating | Eliminated or Escaped | Roster, clock, objectives; "Spectating: [Name]" label in Z2; no prompt, ring or kit (spectator spec: open gap) |
| Dialogue / cutscene | — | N/A: the game has no cutscenes or dialogue; Results is a separate screen |
| Paused | In-round overlay open (P15) | The round does not pause; HUD stays visible dimmed behind the overlay with "The round continues" |
| Loading / round start | Match Flow Loading | HUD hidden until Infiltration |
| Empty / no data | No teammates alive, no lines, no item | Element hidden, never an empty frame; roster keeps eliminated names with the word "Eliminated" |
| Final 30 s | Clock ≤ 30 s | Clock pulses in scale and ticks; no colour-only signal |

---

## Information Hierarchy

| Element | Tier | Why | When hidden, carried by |
|---|---|---|---|
| H1 Clock, H2 Phase, H5 Checklist | MUST KEEP | Pillar 4 | — |
| H6 Crosshair, H7 Prompt, H8 Ring, H16 Bleed-out, H17 Wheel | MUST KEEP (when active) | Required to act | — |
| H3 Activation countdown | MUST KEEP (when active) | Pillar 4: the escape window | Terminal screen, PA countdown |
| H14 Edge cues, H15 Vignette | MUST KEEP (when active) | Fair Fear warnings | Audio |
| S1–S3 shapeshifter core | MUST KEEP | Its core decisions | — |
| S4 Transforming, S5 Stun/immunity, S7 Placement preview | MUST KEEP (when active) | Required to act or wait | — |
| S6 Install alert | SHOULD KEEP | Pressure on survivors | Fuse install noise (25 m) |
| H4 Roster | SHOULD KEEP | Rescue decisions | Downed markers (H12) |
| H12 Markers, H13 World bars | SHOULD KEEP | Team coordination, fake detection | Callouts |
| H10 Feed, H18 Captions | SHOULD KEEP | Communication; captions are an accessibility opt-in | Callout and PA audio |
| H11 Kit | CAN HIDE | Count rarely changes | Item model in hand |
| H9 Reject label | CAN HIDE | Rare | Deny sound |
| Monster position, roles, real/fake | ALWAYS HIDE | Pillar 1, information parity | Nothing |

---

## Visual Budget

- Exploration: at most **8** HUD elements at once (5 Must Show elements carrying the 6 Must Show items, + 3 contextual) and at most **8%** of the screen area outside world markers.
- Busiest state (holding during an Evacuation with feed lines and markers): at most **14** elements and **12%** of the screen.
- At most 6 world markers at once (2 per sender × 3 senders typical, `pings-and-callouts.md`); further markers keep the newest.
- When over budget, drop in reverse tier order: CAN HIDE first (H11, then H9), then the oldest feed line, then roster rows collapse to icons with names on focus.
- The centre zone Z4 never holds more than crosshair + one of (prompt, ring, bleed-out, transforming bar) + one label.

---

## Feedback & Notification Systems

| Notification | Trigger system | Position | Duration | Max simultaneous | Priority | Queue behaviour |
|---|---|---|---|---|---|---|
| Callout line | Pings & Callouts | Z6 | ≥ 8 s | 4 visible (10 in scrollback) | High | Arrival order; never merged or dropped (`pings-and-callouts.md` edge case); the oldest scrolls off into scrollback |
| Escape / disconnect line | Match Flow | Z6 | 8 s | Shares the 4 | Medium | Same queue as callouts, arrival order |
| Caption line | Match Flow (PA), Scare Events | Z6 | ≥ 8 s | Shares the 4 | Medium | Same queue, arrival order; off by default |
| Reject reason | Any | Z5 | 1.5 s | 1 | Low | Newest replaces current |
| Hold cancel cause | Controller | Z5 | 1 s | 1 | High | Replaces a reject reason |
| Checklist change highlight | Survivor Objectives | Z3 | 1 s | All lines | Medium | Simultaneous; never queued |
| Edge cue | Monster Abilities, Borrowed Face, Scare Events | Z8 | Cue duration | 1 per source | Critical | Never queued or suppressed by anything |
| Phase change | Match Flow | Z2 | Label change | 1 | High | Immediate |
| Install alert (shapeshifter) | Survivor Objectives | World | 5 s | 1 per install | High | Concurrent |

Nothing is held back during a chase: the HUD has no combat suppression, because every notification here is either a warning or a team message.

---

## Platform Adaptation

| Platform | Adaptation |
|---|---|
| PC 16:9 (reference) | As laid out; 48 px margin |
| PC 16:10 | Same anchors; extra height unused |
| PC 21:9 / 32:9 | Corner zones anchored to a centred 16:9 safe rect (64 px margin) so nothing lands in far peripheral vision; world markers still clamp to the full screen edge |
| PC 4K | Scales with resolution; minimum sizes in accessibility doc are at 1080p |
| Gamepad (Partial) | Same HUD; prompts use gamepad glyphs (P18); wheel uses right stick |
| Console, mobile | Not targeted |

---

## Accessibility

Committed tier: Standard (`design/accessibility-requirements.md`).

- **Focus order**: the HUD has no focusable elements; the only interactive HUD layers are the wheel (P6, stick/mouse direction) and the overlay (P15, full P17 focus).
- **Text**: critical HUD text ≥ 20 px, feed ≥ 28 px at 1080p; 4.5:1 contrast via a backing plate; feed 7:1 on an opaque box.
- **No colour-only state**: roster states carry icon + word ("Wounded", "Downed"); checklist states are words; ping types are shapes; the final-30 s clock pulses in scale and ticks; cooldown ready is a shape change.
- **Reduced motion**: pulses become static, vignette jitter is off, fades become cuts (Animation Standards).
- **Flash**: no HUD element flashes; highlights are 1 s steady changes.
- **Non-text indicators**: every icon has a word nearby or in the Help page; AccessKit does not cover the in-round HUD (accessibility Open Questions).
- **Cue indicators**: H14 for the lunge wind-up and transform distortion, inside audible range only.

---

## Tuning Knobs

| Setting | Range | Default | Notes |
|---|---|---|---|
| HUD scale | 75–150% | 100% | Independent of menu scale |
| HUD opacity | 50–100% | 100% | Backing plates stay ≥ 4.5:1 |
| Feed line duration | 8–20 s | 8 s | Minimum is the accessibility floor |
| Show roster | On/Off | On | Off hides Z1 for survivors; Downed markers remain |
| Crosshair | Dot / Off | Dot | |
| Marker distance labels | On/Off | On | |
| Cue indicators (H14) | On/Off | On | Off only removes visuals; audio unchanged |
| Captions (H18) | On/Off | Off | PA and scare voice lines; callout feed is always on |
| Colourblind palette | Off / Red-green | Off | Accessibility Visual |
| Reduced motion | On/Off | Off | Shared with accessibility settings |

---

## Acceptance Criteria

- [ ] At 1920 × 1080, 2560 × 1080 and 1920 × 1200, every HUD element sits at least 48 px from every screen edge (64 px from the 16:9 safe rect at 21:9), verified on retained screenshots in `production/qa/evidence/`.
- [ ] In exploration a survivor sees exactly: clock, phase label, roster, objective checklist, crosshair, plus any live markers and feed lines; no element appears that the state table does not list.
- [ ] Downed: the vignette and the "Downed" word show, the crosshair hides, own bleed-out seconds replace the prompt, and roster and checklist stay visible.
- [ ] A survivor client never renders any of S1–S7 (shapeshifter elements), checked by inspecting the HUD tree on a survivor client.
- [ ] In exploration the HUD (excluding world markers) covers at most 8% of the screen; in the busiest state at most 12% (pixel count on screenshots).
- [ ] With the colourblind simulator (protanopia, deuteranopia, tritanopia) applied to screenshots, every roster state, checklist state and ping type is still distinguishable.
- [ ] Five callouts arriving within one second all appear in arrival order: four visible, the first in scrollback; none dropped.
- [ ] The lunge wind-up indicator appears for a player at 19 m from the source and not at 21 m (`lunge_cue_radius_m` 20).
- [ ] With reduced motion on, no HUD element moves or pulses; the final-30 s clock still ticks audibly.
- [ ] Critical HUD text measures at least 20 px tall and feed text at least 28 px at 1080p.

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Spectator HUD and target switching | SneakKestrel16 | Spectator spec | Gap (patterns) |
| Hide peek view HUD | SneakKestrel16 | Before Survivor Defense implementation | Gap (patterns) |
| Does the shapeshifter see the survivor roster with life states (Downing GDD says "Survivors only")? | SneakKestrel16 | Before HUD implementation | Assumed no; the shapeshifter's Z1 shows its face list instead |
| Player journey map does not exist; first-round onboarding of the HUD is undesigned | SneakKestrel16 | Before first playtest | Unresolved |
| Results screen (systems-index #13, shared with this HUD) has no spec | SneakKestrel16 | Before Match Flow implementation | Gap (patterns); `/ux-design results` |
| Final visual treatment (fonts, plates, icons) | art-director | Art bible | Layout only here; greybox mock: `production/qa/evidence/hud-mock/01-survivor-holding-investigation.png` (`prototypes/hud-mock/`) |
