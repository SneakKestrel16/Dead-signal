# Level: Research Facility (Greybox)

> **Status**: Approved
> **Author**: SneakKestrel16
> **Last Updated**: 2026-10-12 (re-review: approved; early-arming edge row, fuse box indicator in Low Power; design review: candidate replication matches Objectives rule 5, lighting precedence, Edge Cases; earlier: cross-review B1 scare anchors, B2 lighting owner, W5, W13, D1)
> **Last Verified**: 2026-10-12
> **Implements Pillar**: Readable Objectives, Counterplay, Fair Fear, Small Shippable Scope (supports Human Deception)

## Quick Reference

- **Area/Region**: One compact, hand-authored abandoned research facility; three connected zones (A Laboratories, B Server/Power, C Security/Evacuation) plus two service corridors and a lab spine.
- **Type**: Mixed: asymmetric 1v4 objective map (exploration, ambush, holdout). No combat in the conventional sense; no AI enemies of any kind.
- **Estimated Play Time**: one round, `round_duration_s` = 540 (~9 min), owned by Match Flow.
- **Difficulty**: N/A. Difficulty comes from the other humans.
- **Prerequisite**: Lobby & Role Assignment has placed 3–5 survivors and 1 shapeshifter in the match (`lobby-role-assignment.md`).
- **Status**: Layout (greybox spec for Milestone 1; untextured blockout, no art).
- **Footprint**: 60 m x 40 m, single floor **(proposed)**.

All geometry is fixed. The only per-round variation is which authored candidate points are active, chosen by the server at round start. No geometry is generated at runtime.

## Narrative Context

- **Story Moment**: Survivors enter the facility to recover evidence and leave through the evacuation exit. The source gives no further story.
- **Narrative Purpose**: Make "evidence" physical: drives sit in labs and the records archive; the exit is behind security.
- **Emotional Target**: Zone A: close-quarters suspicion. Zone B: exposed, noisy urgency. Zone C: a fragile foothold that must be held, then abandoned.
- **Lore Discoveries**: Environmental dressing only (abandoned desks, sealed specimen fridges, a security log screen) **(proposed)**. No collectibles. Content is deferred to the M4 horror pass.

## Zones and Rooms

IDs are also the callout vocabulary: Pings & Callouts should name these rooms, so names are short and distinct **(proposed)**.

| ID | Name | Zone | Size (m) | Purpose |
|----|------|------|----------|---------|
| A1 | Entry / Decon | A | 10x12 | Survivor spawn; orientation; three exits so spawn is never a trap |
| A2 | Lab Spine | A | 3x32 | Narrow north-south hall linking every lab; glass walls to A3/A4 create "I saw you over there" moments |
| A3 | Wet Lab | A | 10x14 | Evidence/fuse candidate; glass wall to the spine; hiding cabinet |
| A4 | Specimen Lab | A | 9x12 | Evidence candidate; glass on two sides; the lab door into B1 |
| A5 | Cold Storage | A | 9x10 | Evidence/fuse candidate; hiding locker; short link to the south corridor |
| A6 | Director's Office | A | 10x10 | Evidence candidate; hiding cabinet; corner room with two exits |
| A7 | Observation Gallery | A | 9x10 | Evidence candidate; glass floor-to-ceiling window down into A4 (landmark) |
| H-N | North Service Corridor | link | 48x4 | East-west route; blue floor stripe; fuse candidate |
| H-S | South Service Corridor | link | 50x4 | East-west route; orange floor stripe; fuse candidate; camera |
| B1 | Server Hall | B | 18x16 | Central objective area; "The Core" landmark; fuse box candidate; four entrances, one per side |
| B2 | Power Room | B | 18x8 | Breaker wall landmark; fuse box candidate |
| B3 | Cooling Plant | B | 18x8 | Fuse box candidate and fuse candidate; loud machinery masks footsteps **(proposed)** |
| C1 | Security Office | C | 12x12 | Camera monitor station; fuse candidate; barricadable doors |
| C2 | Checkpoint | C | 10x14 | Gate between B and C; terminal candidate; the non-barricadable archway into C4 |
| C3 | Records Archive | C | 20x8 | Only Zone C evidence candidate; terminal candidate |
| C4 | Evacuation Hall | C | 10x16 | Terminal candidate; the final exit door; evac beacon landmark |
| C5 | Backup Control | C | 8x10 | Backup controls panel; fuse candidate; hiding locker |

Room sizes are interior blockout dimensions read off the sketch (1 sketch column = 1 m, 1 sketch row = 2 m) **(proposed)**. Ceiling height 3 m everywhere except B1 at 6 m so The Core reads from every B1 doorway **(proposed)**.

## Layout

### Overview Map

North is up. Width 60 m, depth 40 m. Legend (replaces the template legend; there are no combat, puzzle, boss or NPC nodes):
`D` ordinary door · `B` barricadable door · `O` open archway (no door) · `E` final exit · `:` glass partition (see-through, not passable) · `+`/`-`/`|` walls.

Structure:

```
+-----------------------------------------------+-----------+
| H-N NORTH SERVICE CORRIDOR (blue stripe)      B C1        |
+----D----+  +---D----+--------D--------+---D---+ SECURITY  |
|A6       |  |A7      | B2 POWER ROOM   |C5     | monitors  |
|DIRECTOR |  |OBSERV. | [breaker wall]  |BACKUP D           |
|OFFICE   |  DGALLERY |                 |CTRL   |           |
|         |A2|        +--------D--------+       +-+----B----+
+----D----+  +:::-::::+                 +---D---+-+         |
|A3 WET   :  :A4      | B1 SERVER HALL  |C2       | C4 EVAC |
|LAB      D  :SPECIMEN|                 |CHECK-   | HALL    E
|         :  DLAB     D (rack lanes)    BPOINT    O         E
|         :  :        |                 |         O [beacon]|
|         :  :        |     [ THE CORE ]|         |         |
|         :  +---D----+                 |         |         |
+----D----+  |        +--------D--------+----D----+----B----+
|A1       |  |A5 COLD | B3 COOLING PLANT| C3 RECORDS ARCHIVE|
|ENTRY    D  |STORAGE |                 |                   |
|DECON    |  |        |                 |                   |
|         +  +---D----+--------D--------+---------B---------+
|         O   H-S SOUTH SERVICE CORRIDOR (orange stripe)    |
+---------+-------------------------------------------------+
```

Placement overlay (same grid). `S1-S5` survivor spawns (S5 only in 5-survivor rounds) · `M1-M3` shapeshifter spawn candidates · `d1-d6` data drive candidates · `f1-f7` fuse candidates · `P1-P3` fuse box candidates · `T1-T3` evacuation terminal candidates · `h1-h6` hiding spots · `c1-c4` cameras (`c-monitors` = viewing station) · `s` backup light switch.

```
+-----------------------------------------------+-----------+
| f7                                            B   f6 s    |
+----D----+  +---D----+--------D--------+---D---+           |
|         |  |        | P1  s           |       | c-monitors|
|d1 h1    |  |d4 s    | M3              |f5 h6  D           |
|s        |  D        |                 |M2 s   |           |
|         |c4|        +--------D--------+       +-+----B----+
+----D----+  +:::-::::+                 +---D---+-+         |
|d3 f1    :  :d2 h3   |   c1   s        |T2 s     | T1 c3   |
|h2 s     D  :s       |                 |         | s       E
|         :  D        D                 B         O         E
|         :  :        |                 |         O         |
|         :  :        |     [P2 core]   |         |         |
|         :  +---D----+                 |         |         |
+----D----+  |        +--------D--------+----D----+----B----+
|S1 S2 S5 |  |d5 f2   | P3 f3 h5        | T3 d6 M1 s        |
|S3 S4    D  |h4 s    | s               |                   |
|s        |  |        |                 |                   |
|         +  +---D----+--------D--------+---------B---------+
|         O                       f4 c2                     |
+---------+-------------------------------------------------+
```

### Connectivity Graph

Nodes are rooms; edges are passages (`=` door, `#` barricadable door, `~` open archway or open corridor junction, `E` exit).

```
A1 = A2      A1 = A3      A1 ~ H-S
A2 ~ H-N     A2 ~ H-S     A2 = A3     A2 = A4     A2 = A7
A3 = A6      A6 = H-N     A7 = H-N    A4 = A5     A5 = H-S
A4 = B1      B1 = B2      B1 = B3     B2 = H-N    B3 = H-S
B1 # C2      H-N = C5     H-N # C1    C5 = C1     C5 = C2
C1 # C4      C2 ~ C4      C2 = C3     C3 # C4     C3 # H-S
C4 E Outside
```

Loops (every room sits on at least one):

| Loop | Route | Use |
|------|-------|-----|
| L1 Perimeter | H-N - A2 - H-S - C3 - C2 - C5 - H-N | The long escape loop around the whole map |
| L2 West labs | A2 - A3 - A6 - H-N - A2 | Lab chase loop |
| L3 South labs | A2 - A4 - A5 - H-S - A2 | Lab chase loop through the glass rooms |
| L4 Entry | A1 - A2 - A3 - A1 (and A1 - H-S - A2 - A1) | Spawn is never a dead end |
| L5 Core north | B1 - B2 - H-N - A2 - A4 - B1 | Reach B1 without the A4 door |
| L6 Core south | B1 - B3 - H-S - A5 - A4 - B1 | Second B1 loop |
| L7 B-C south | B1 - C2 - C3 - H-S - B3 - B1 | Fallback from C to B |
| L8 Evac triangle | C2 - C4 - C3 - C2 | Holdout circulation around the terminal |
| L9 Evac north | C2 - C4 - C1 - C5 - C2 | Second holdout escape |

Map rules (all **(proposed)** unless noted):

1. Every room has at least two exits. No one-way traps exist, so the source's "unless an escape route is near" exception is never used (source rule: loops and alternate routes).
2. Every room keeps at least one entrance that cannot be barricaded. C4's archway from C2 is never barricadable, so C4 cannot be sealed (source rule: no permanent safe room).
3. Zone B has four independent approaches (A4, H-N via B2, H-S via B3, C2). Removing any one edge leaves B1 reachable (source rule: no single choke point controls all access).
4. Zone C has four entry points from the rest of the map (B1-C2, H-N-C5, H-N-C1, H-S-C3). Three are barricadable and one (H-N-C5) is not.

### Critical Path

Survivor objective flow. Selection and rules are owned by Survivor Objectives; this is the spatial route.

1. Survivors spawn in A1 (S1-S5) and orient during Infiltration (0:00-2:00).
2. Recover 2 data drives from active `d` points (mostly Zone A, possibly C3).
3. Find 2 fuses at active `f` points and install them at the 2 active `P` fuse boxes in Zone B. Each install is noisy and alerts the shapeshifter to the general area (source).
4. Carry drives to the active `T` terminal in Zone C and hold the area through the 15 s activation (`evac_activation_s`).
5. Escape through the exit `E` on C4's east wall. The exit is fixed **(proposed)**.

### Optional Paths

| Path | Access Requirement | Reward | Discovery Hint |
|------|-------------------|--------|---------------|
| H-N corridor | None | Fast west-east run; skips Zone B | Blue floor stripe |
| H-S corridor | None | Fast west-east run; reaches C3 and A1 | Orange floor stripe |
| A2 spine to A4 to B1 | None | Shortest spawn-to-Core route (~10 s) | Glass walls show B1's Core glow through A4 |
| C5 side entry | None | Unbarricadable way into Zone C | Backup Control signage |
| C1 monitor station | Reach C1 | Camera views of c1-c4 | Monitor glow visible from H-N |

## Authored Candidate Points

The server picks the active subset at round start and never lets a client choose or move a point. It replicates every active point to the monster at once. Survivor clients get the active fuse boxes and terminal at round start, and an active drive room or fuse spawn only once it is discovered (Survivor Objectives rules 5 and 7) (design review 2026-10-12, correcting the cross-review W5 wording). Selection rules and counts belong to Survivor Objectives (rules 5–6 there, which adopt the counts and constraints below); this map owns the placements.

| Set | Required (canon) | Candidates | Active per round | Locations |
|-----|------------------|-----------|------------------|-----------|
| Data drives | 2 (`data_drives_required`) | 6 **(proposed)** | 2 | d1 A6, d2 A4, d3 A3, d4 A7, d5 A5, d6 C3 |
| Fuses (pickup) | 2 (`fuses_required`) | 7 **(proposed)** | 2 | f1 A3, f2 A5, f3 B3, f4 H-S, f5 C5, f6 C1, f7 H-N |
| Fuse boxes (install) | 2 installs | 3 **(proposed)** | 2 **(proposed)** | P1 B2 breaker wall, P2 B1 Core, P3 B3 |
| Evacuation terminal | 1 | 3 **(proposed)** | 1 **(proposed: randomized; Open Question in Survivor Objectives)** | T1 C4, T2 C2, T3 C3 |

Placement constraints **(proposed)**:
- The two active drives are in different rooms.
- The two active fuses are in different zones (each service corridor counts as its own zone, Survivor Objectives rule 6), so the fuse hunt crosses the map.
- No drive or fuse candidate is in A1, so survivors cannot finish an objective without leaving spawn.
- All fuse boxes are in Zone B, so fuse noise always points the shapeshifter to the centre. It never points at spawn or the exit.
- If T3 (C3) is active, d6 (also C3) is not (an active terminal and an active drive never share a room).

Combinations: 15 drive pairs x up to 21 fuse pairs x 3 fuse box pairs x 3 terminals. This gives enough variety that routes cannot be memorised. Every combination is still reachable within the traversal budget below.

## Spawn Points

| ID | Role | Location | Notes |
|----|------|----------|-------|
| S1-S5 | Survivors | A1 Entry / Decon | One fixed group spawn **(proposed)**; S5 is used only in 5-survivor rounds (designer decision, 2026-10-12: up to 6 players). Unused spawns stay empty. A1 has three exits (A2, A3, H-S). |
| M1 | Shapeshifter | C3 Records Archive | One of M1-M3 chosen by the server per round **(proposed)** |
| M2 | Shapeshifter | C5 Backup Control | |
| M3 | Shapeshifter | B2 Power Room | |

Every M point is at least ~25 m of walking from A1 (about 6 s) and out of A1's line of sight **(proposed)**. The shapeshifter has to approach the group and observe a survivor before it can borrow a face (Borrowed Face owns the observation rule). Whether the shapeshifter starts disguised is an Open Question.

## Defense, Surveillance and Lighting Fixtures

**Hiding spots** (6 total, sparse **(proposed)**). Behaviour is owned by Survivor Defense: a hiding spot buys time but is not safe, and the shapeshifter can investigate it.

| ID | Room | Type |
|----|------|------|
| h1 | A6 | Lab cabinet |
| h2 | A3 | Lab cabinet |
| h3 | A4 | Lab cabinet |
| h4 | A5 | Storage locker |
| h5 | B3 | Locker behind cooling plant |
| h6 | C5 | Locker |

Four of the six are in Zone A (the source places hiding cabinets in the labs). No hiding spot is in B1, C4 or any corridor **(proposed)**, so the objective and holdout spaces stay readable.

**Barricadable doors** (5, all in Zone C, per the source's "barricadable doors" in Security/Evacuation) **(proposed count)**: B1-C2, H-N-C1, C1-C4, C3-C4, H-S-C3. Survivor Defense owns barricade duration and break time. All other `D` doors can be opened and closed (so "slam a door" works as counterplay) but cannot be barricaded **(proposed)**.

**Surveillance** ("limited surveillance", source):

| ID | Covers | Purpose |
|----|--------|---------|
| c1 | B1 Server Hall, facing the Core | Watch fuse work from Zone C |
| c2 | H-S south corridor | Watch the southern approach to C3 |
| c3 | C4 Evacuation Hall | Watch the exit and T1 |
| c4 | A2 Lab Spine | Watch lab traffic |

Feeds can be watched only at the C1 monitor station, one feed at a time **(proposed)**. Zone A rooms, A1 spawn and H-N are uncovered on purpose. The feeds are the only place an "impossible surveillance image" scare (Scare Events) can appear. What a disguised shapeshifter looks like on a feed is decided by Borrowed Face (Open Question).

**Scare anchors** (cross-review B1). The only places a door or glass scare from Scare Events can play. Scare Events owns which scare fires and when (RoundScript only); this map owns placement. Every anchor is presentation only: a door anchor never changes its door's open or closed state (Scare Events rule 7), and a glass anchor's pane cracks but stays see-through and not passable **(proposed)**.

| ID | Type | Location | Scare (Scare Events) |
|----|------|----------|----------------------|
| sd1 | Door | A2-A3 door | Slammed door |
| sd2 | Door | A4-A5 door | Slammed door |
| sd3 | Door | A6-H-N door | Slammed door |
| sd4 | Door | B1-B3 door | Slammed door |
| sd5 | Door | C2-C3 door | Slammed door |
| sd6 | Door | C5-C2 door | Slammed door |
| sg1 | Glass | A2-A3 glass wall | Glass break |
| sg2 | Glass | A2-A4 glass wall | Glass break |
| sg3 | Glass | A7 window into A4 | Glass break |

All door anchors are ordinary `D` doors, never a barricadable `B` door or exit E, so a slam never touches a barricade or the exit **(proposed)**. Six doors spread over all three zones and three glass anchors in Zone A **(proposed counts)**.

**Backup light switches** (`s`): one per room, none in corridors or the A2 spine **(proposed)**. They are the source's counterplay to Blackout. Their effect (for example, ending a Blackout early) is owned by Monster Abilities. With no switches in corridors, a blackout there is the riskier one for survivors. C5 also holds the **backup controls panel** named in the source; its function is an Open Question.

**Lighting volumes**: Blackout affects "a nearby room or short corridor" (source). Each room is one lighting volume. H-N and H-S are each split into four ~12 m segments and A2 into three ~11 m segments, so a blackout never darkens a whole corridor **(proposed)**.

Each lighting volume carries a **`blackout_able`** flag that Monster Abilities rule 17 reads (cross-review re-review R4, 2026-10-11). Every volume is `blackout_able` except the room holding the active evacuation terminal (T1 C4, T2 C2 or T3 C3), which is not `blackout_able` once the Evacuation phase starts **(proposed; settles W8)**. This keeps the rule below that lighting never fully darkens the route to the active terminal during Evacuation. Before Evacuation the terminal room can be blacked out like any other. A Blackout already active in that room when Evacuation starts ends at that moment and the room returns to its normal Evacuation lighting **(proposed; settles cross-review second re-review S2; costs the monster at most 6 s of darkness)**.

**Visibility sets** (ADR-0004, 2026-10-12). The server sends a client only the bodies its player could plausibly see, using a per-volume visibility table this map owns. For each lighting volume (rooms and corridor segments above), list: the volume itself, every volume seen through an open doorway or archway from it, and every volume seen through glass. Entries through a door are cut while that door is closed or barricaded; entries through glass and archways are not. A missing entry makes bodies pop in late; an extra entry sends bodies a player cannot see. The table is not yet authored (Open Questions).

| Volume | Visible through doorways/archways | Visible through glass |
|--------|-----------------------------------|-----------------------|
| *(to be authored for all 17 room volumes and corridor segments)* | | |

## Dimensions and Traversal

**Geometry limits** (from `first-person-controller.md`: capsule `player_radius_m` 0.3, `step_height_m` 0.35, slope limit 40 degrees; cross-review 12d W4). The greybox must respect them: every doorway and archway at least 0.8 m clear width; steps no higher than `step_height_m` 0.35 m, each with an invisible ramp collider no steeper than 40 degrees (ADR-0007); slopes no steeper than 40 degrees; floors built from large box colliders, not many small coplanar pieces (ADR-0007, Jolt seam snagging); each hiding spot authors a hide point, an exit point and at least one alternate exit point; each door's swing area kept clear of fixtures and props, since a door close is rejected while a capsule overlaps the swing area. The map has no jumps and no drops.

Traversal times use a reference walk speed of 4.0 m/s **(proposed)**. First-Person Controller owns the real speed; if it differs, scale every time below by the ratio.

| Route | Path length | Walk time |
|-------|------------|-----------|
| A1 spawn to B1 Core (A2, A4) | ~39 m | ~10 s |
| A1 spawn to C4 exit (H-S, C3) | ~66 m | ~17 s |
| B1 Core to T1 (C2 archway) | ~25 m | ~6 s |
| A6 to C3 (longest room-to-room, via H-N) | ~72 m | ~18 s |
| Full perimeter loop L1 | ~170 m | ~42 s |

Targets **(proposed)**:
- Any room to any other room in 20 s or less at walk speed.
- Every drive and fuse candidate is within 5 s of a hiding spot, a door that can be closed, or a second exit.
- Every active terminal is within 25 s of every other objective room, so the Evacuation phase (normally the final 2:00; it starts earlier when the terminal is armed, Match Flow rule 6) leaves time for at least one rescue (`rescue_duration_s` = 6) and a retreat around L8 or L9.
- Every terminal candidate is within 15 s of exit E at walk speed **(proposed)**. Since 2026-10-12 the drives eject at the terminal and must be carried out through E (`survivor-objectives.md` rule 22), so the terminal-to-exit run is the final, contested carry. It should be short enough to finish and long enough to contest; the route should offer two paths (for example via C2 or C1).
- Total minimum survivor walking for a split team is about 2-3 min of the 5-min Investigation window. This leaves room for verification, hiding and rescues. Confirm in M2 playtests.
- **Grouped worst case** (cross-review D1, 2026-10-12): one group of four touring every active point walks roughly the L1 loop (~42 s) plus room spurs, about 1-2 min, and does the objective work in series (`min_work_s` 50 s, Survivor Objectives): about 2-3 min in total. That is well inside the 420 s from Investigation start to the deadline, so the clock alone does not force a split. This is inference from the route table; time a grouped greybox run in M2 to settle it.

## Encounters

There are no enemies and no AI. "Encounters" here are spaces the layout sets up for the human shapeshifter and the survivors.

### Encounter Spaces

| ID | Position | Setup | Pressure | Arena Notes |
|----|----------|-------|----------|-------------|
| E-01 | A2 spine + A3/A4 glass | Suspicious sighting: a "teammate" seen through glass where they should not be | Medium | Short sightlines; glass shows people but blocks movement, so sight and route differ |
| E-02 | A3, A4, A5, A6 doors | Lab ambush at a cabinet or drive | Medium-high | Small rooms with two exits each; the escape is always a door, not a corridor |
| E-03 | B1 rack lanes | Noisy fuse install at the Core while the shapeshifter closes in | High | Four entrances; racks cut sightlines into 2-3 m lanes; The Core is visible from every doorway |
| E-04 | C2 / C4 | Evacuation holdout for 15 s | Peak | C4 can never be sealed (archway); barricades slow the other two doors; L8/L9 let survivors scatter |
| E-05 | H-N / H-S segments | Corridor blackout chase | Medium | Long sightlines; no backup switch; side doors every ~10 m |

### Non-Combat Encounters

| ID | Position | Type | Description | Solution Hint |
|----|----------|------|-------------|---------------|
| N-01 | C1 | Surveillance | Check cameras to confirm where teammates are | Monitor glow visible from H-N |
| N-02 | Any `s` | Light recovery | Restore a room after Blackout | Switch has its own faint indicator light **(proposed)** |
| N-03 | Zone B fuse boxes | Power restoration | Install fuses at the active fuse boxes | Active fuse boxes show a lit indicator; inactive ones are dark **(proposed)** |

## Lighting States and Sightline Intent

| Zone | Sightline intent | Base lighting intent |
|------|------------------|---------------------|
| A Labs | Short, mostly ≤10 m. Glass gives see-through without walk-through, supporting deception ("I saw you in A4"). | Cool white-green lab panels, many lit at low intensity; pools of darkness between benches |
| B Server/Power | Medium (18 m hall), broken by rack lanes. The Core is the one long sightline. | Amber equipment glow; The Core's light column is the brightest point on the map |
| C Security/Evac | Medium-long (C3 20 m, C4 16 m). Exposed to make holding hard. | Red security tones; monitor glow in C1; beacon in C4 |
| Corridors | Longest (48-50 m), segmented by lighting | Stripe-coloured floor guides (blue north, orange south) |

Emergency lights (faint floor-level strips plus exit signage) are always on in every volume, including during Blackout **(proposed)**, matching the source's "emergency lights remain faintly visible".

**Lighting states** (server-driven; every client shows the same state). This map owns per-volume lighting state. Scare Events only requests these states and adds flicker and stingers on top; it defines no lighting state of its own (designer decision, 2026-10-12, cross-review B2).

| State | Trigger | Look |
|-------|---------|------|
| Low Power | Round start | Zone base lighting at reduced level; Zone B dimmest; fuse box and terminal housings dark, except the small indicator on each active fuse box (N-03) **(proposed)** |
| Fuse Installed (1/2) | `ObjectiveProgressChanged` | The fuse box's indicator lights; B1 Core pulses once **(proposed)** |
| Power Restored (2/2) | `ObjectiveProgressChanged` | Overheads up to full in B and C; active terminal screen lights; route lights from B1 to the terminal **(proposed)** |
| Blackout (local) | Blackout activation (Monster Abilities) | One volume dark for `blackout_duration_s` = 6; emergency strips stay faintly visible (canon) |
| Evacuation | `RoundPhaseChanged` to Evacuation (7:00, or earlier when the terminal is armed) | Emergency mode: overheads drop to ~50%; rotating amber beacons along H-N, H-S and C2 toward C4; exit sign over E brightens **(proposed)** |
| Terminal Activating | `ObjectiveProgressChanged` (activation started) | C4 beacon spins red; alarm lights in the terminal room **(proposed)** |
| Exit Open | Activation complete | Exit door E opens; green light floods C4 from the doorway **(proposed)** |
| Reset | `RoundEnded`, and round start | Any active Blackout ends; every volume returns to the round-start Low Power state, so the results screen and the next round start clean (cross-review re-review R4, 2026-10-11) **(proposed)** |

**Precedence** (design review 2026-10-12, **(proposed)**). Each volume shows one base state plus overlays:
- The base state is the latest of Low Power → Power Restored → Evacuation. Evacuation replaces Power Restored's full overheads with its ~50% emergency mode, but keeps the route lights to the active terminal.
- Fuse Installed (1/2), Terminal Activating and Exit Open are overlays on their own fixtures (fuse box indicator, terminal room alarm lights and C4 beacon, exit door light). They never change another volume.
- Blackout (local) overrides everything in its one volume except the emergency strips, for its duration. The volume then returns to whatever its base state and overlays are at that moment.
- Reset clears every overlay and Blackout and sets every volume to Low Power.

In reduced-flash mode, rotating and pulsing lights become steady colour changes **(proposed)**; Accessibility Options owns the setting. Lighting changes never fully darken the route to the active terminal during Evacuation **(proposed)**, so Readable Objectives holds when the stakes are highest.

## Pacing Chart

```
Intensity
10 |                                                    *  *
 8 |                                         *    *   *  **
 6 |                       *    *   *   *  *  * *  * *
 4 |            *   *   * *  *  **  * *  **
 2 | *  *  *  *  * *  *
 0 |S------------------------------------------------------E
    0:00     2:00                        7:00          9:00
    [Infiltration][ Investigation (fuse noise spikes)][Evac]
```

Valleys: Infiltration in Zone A (orientation, first drive). Spikes: every fuse install in Zone B (noise), lab ambushes. Peak: the 15 s terminal hold in Zone C. Brief dips come after successful barricades or hides; they never become permanent safety.

## Audio Direction

| Zone/Moment | Music Track | Ambience | Key SFX |
|-------------|------------|----------|---------|
| Zone A | None (greybox) | Fluorescent hum, dripping, ventilation ticks | Cabinet doors, glass taps |
| Zone B | None | Server fans; B3 machinery loud enough to mask footsteps **(proposed)** | Fuse install noise (canon: alerts the shapeshifter) |
| Zone C | None | Low security tone, monitor buzz | Barricade build and strain |
| Evacuation | Owned by Scare Events / audio pass (M4) | Alarm bed facility-wide | Terminal activation loop; exit door |

Audio should carry useful direction rather than volume (source). Scare Events owns detailed audio.

## Visual Direction

- **Lighting**: See Lighting States. Readable state changes come first; mood comes later in the M4 horror pass.
- **Color Palette**: Zone colour coding for navigation **(proposed)**: A cool white-green, B amber, C red, H-N blue stripe, H-S orange stripe.
- **Mood Board References**: Abandoned lab and security-wing horror. Specifics are deferred to the Art Bible.
- **Landmarks**: The Core (B1, double height, light column); A7 Observation Gallery window; B2 breaker wall; C1 monitor wall; C4 evac beacon and exit sign; A1 decon arch; floor stripes in both corridors.
- **Sight Lines**: From A1, the A2 spine leads north and B1's glow shows through A4 glass. From every B1 doorway, The Core is visible. From C2, the C4 beacon is visible through the archway.

## Collectibles and Secrets

None. Objective items are listed under Authored Candidate Points. There are no secrets or optional collectibles in the prototype.

## Technical Notes

- **Estimated Object Count**: Greybox only. 17 room/corridor volumes, about 26 doors and archways, 6 hiding props, 4 cameras, 14 switches, 19 candidate markers **(proposed)**.
- **Streaming Zones**: None. The map is small enough to load whole **(proposed)**.
- **Performance Concerns**: B1 rack lanes and glass partitions (overdraw/transparency); measure once the engine is chosen.
- **Required Systems**: Network Authority & Replication; First-Person Controller & Interaction; Survivor Objectives; Survivor Defense; Monster Abilities; Scare Events; Pings & Callouts; Match Flow & Win Conditions.
- **Server authority**: The server owns the active candidate set, door open/closed/barricaded state, lighting state per volume, camera feed content and exit state. It sends these to clients. Clients never select candidates, open the exit or change lighting state locally. The one exception is individual hallucinations sent only to their target client by Scare Events.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Terminal armed during Infiltration | Lighting goes Power Restored (arming needs both fuses) straight to Evacuation; the Investigation flicker never plays | Match Flow rule 6; precedence takes the latest base state |
| Blackout in a room when Power Restored lands | Room stays dark for the rest of the Blackout, then shows Power Restored | Blackout overrides its volume only for its duration |
| Blackout in the active terminal room when Evacuation starts | Blackout ends at that moment; room shows Evacuation lighting | `blackout_able` paragraph |
| Blackout in any other room when Evacuation starts | Blackout runs its remaining duration, then the room shows Evacuation lighting | Precedence |
| Round ends during Terminal Activating or Exit Open | Reset clears all overlays; Low Power everywhere | Reset row |
| A drive or fuse spawn is active in a room a survivor never sees within `discover_range_m` | No survivor client receives it; the monster's does | Survivor Objectives rules 5 and 7 |
| Slammed-door anchor fires on an open door | Door plays the slam and shudder but stays open | Scare Events rule 7 |

## Dependencies

| System | Direction | Interface |
|--------|-----------|-----------|
| First-Person Controller & Interaction | Map depends on it | Walk speed (traversal times), hold-to-interact at switches, doors, terminals; step and slope limits, capsule and door swing areas (Geometry limits under Dimensions and Traversal) |
| Lobby & Role Assignment | Map depends on it | Places 3–5 survivors and 1 shapeshifter; survivor spawns S1–S5 and shapeshifter candidates M1–M3 (Spawn Points) |
| Survivor Objectives | Bidirectional | Candidate point sets (d, f, P, T), terminal zone, exit E; Objectives owns selection rules, counts and `ObjectiveProgressChanged`; the map reads objective state for lighting |
| Survivor Defense | Depends on map | Hiding spot (h) and barricadable door (B) placement; Defense owns their behaviour |
| Monster Abilities | Depends on map | Lighting volumes for Blackout; switch (s) placement; room/door geometry for Predatory Lunge and False Signal positions |
| Scare Events | Depends on map | Camera feeds, lighting states (this map owns them; Scare Events requests them), lighting volumes for the ambush test, door/glass scare anchors (Scare anchors table) |
| Pings & Callouts | Depends on map | Room IDs and names as callout locations; backup light switches (s) are item-pingable |
| Match Flow & Win Conditions | Map depends on it | `RoundPhaseChanged` drives Evacuation lighting; exit E ends a survivor's round |
| Borrowed Face | Depends on map | Spawn distances for the observation rule; camera-feed appearance of a disguise |
| Network Authority & Replication | Map depends on it | Server-owned map state listed in Technical Notes |
| Accessibility Options | Depends on map | Reduced-flash variants of beacons and pulses |

## Cross-References

- design/gdd/match-flow.md
- design/gdd/survivor-objectives.md
- design/gdd/downing-and-rescue.md
- design/gdd/survivor-defense.md
- design/gdd/borrowed-face.md
- design/gdd/monster-abilities.md
- design/gdd/pings-and-callouts.md
- design/gdd/scare-events.md
- design/accessibility-requirements.md (not yet written)
- design/source/DEAD_SIGNAL_Game_Design_Document.md §9 (map brief)

## Acceptance Criteria

1. **Exits**: In the greybox, every room in the Zones and Rooms table has at least two traversable exits. Pass: a walk-through confirms each room; zero rooms fail.
2. **No sealed rooms**: With all five barricadable doors barricaded, a player can still walk from H-N to C4 and to every other room. Pass: route walked successfully.
3. **No single choke**: Block each single edge into Zone B in turn (A4-B1, B2-H-N, B3-H-S, B1-C2). B1 stays reachable from A1 every time. Pass: all four tests succeed.
4. **Candidate agreement (5 clients)**: In 10 consecutive rounds with 5 connected clients, every client shows the active fuse boxes and terminal from round start where the server log has them; each survivor client shows an active drive room or fuse spawn only after its discovery, at the logged position; the monster's client shows every active point from round start; and no survivor client holds data for an undiscovered drive room or fuse spawn (Survivor Objectives rules 5 and 7). Pass: 10/10 rounds agree.
5. **Candidate variety**: Over 20 rounds, at least 4 different drive pairs and all 3 terminal candidates appear, and no round breaks a placement constraint. Pass: log review.
6. **No runtime geometry**: Wall, door and room layout is identical across 10 rounds; only candidate activation differs. Pass: visual and log comparison.
7. **Traversal budget**: At the controller's walk speed, A1 to C4 exit takes 20 s or less and A6 to C3 takes 20 s or less (the Targets bound). Pass: stopwatch in greybox.
8. **Lighting states (5 clients)**: On the Evacuation phase change and on power restored, all 5 clients enter the new lighting state within 1 s of each other **(proposed tolerance)**. Pass: recorded on all clients.
9. **Blackout scope**: A Blackout darkens exactly one lighting volume, and emergency strips stay visible in it. Pass: verified in each room and each corridor segment.
10. **Exit gating**: Exit E stays closed until the server reports activation complete. A client cannot open it by interacting early. Pass: attempted on 5 clients, 0 openings.
11. **Grouping (playtest)** (cross-review D1, 2026-10-12): across at least 10 M2 rounds, Match Telemetry records whether the survivors ever split (any two Healthy survivors more than 20 m apart for 30 s or more) and the win rate of teams that never split. It also records each survivor's share of time spent sprinting and, for each sprint, whether the shapeshifter was within 20 m, plus each survivor's total time with the monster within 20 m (cross-review D1, 2026-10-12), so the M2 playtest can settle whether free sprint is a thin choice (`first-person-controller.md` Open Questions). Pass: the designer reviews both before Milestone 3; if never-split teams win more often than split ones, revisit D1 (an objective that rewards parallel work, or a shorter clock).
12. **Lighting precedence (5 clients)**: With both fuses installed, then Evacuation, then a Blackout in a Zone B room, all 5 clients show that room dark with emergency strips; when the Blackout ends it shows Evacuation lighting, not Power Restored. After `RoundEnded`, every volume is Low Power on all clients.

## Open Questions

| Question | Owner | Deadline |
|----------|-------|----------|
| What makes a room "secured" for data drives (locked door, timed hack, nothing extra)? | SneakKestrel16 | Before Milestone 2 |
| Are fuse boxes randomized (2 of 3 proposed) or fixed in B1/B2? (rule owned by Survivor Objectives) | SneakKestrel16 | Before Milestone 2 |
| Is the exit fixed at C4, or does it follow the active terminal? | SneakKestrel16 | Before Milestone 2 |
| What do C5's "backup controls" do beyond per-room switches (zone light reset, camera power, nothing)? | SneakKestrel16 | Before Milestone 3 |
| Does the shapeshifter spawn disguised, or must it observe someone first? (Borrowed Face) | SneakKestrel16 | Before Milestone 3 |
| Can the shapeshifter use the C1 monitors? (Scare Events rule 2a already assumes any player, including the shapeshifter, can view one.) How does a disguised shapeshifter appear on a feed? | SneakKestrel16 | Before Milestone 3 |
| Is a 60 x 40 m single floor the right size for 4–6 players, or too tight for hiding and deception? | SneakKestrel16 | Before Milestone 5 |
| Should survivors have more than one spawn group to vary the openings? | SneakKestrel16 | Before Milestone 5 |
| Is 6 hiding spots the right density? | SneakKestrel16 | Before Milestone 5 |
| Author the visibility-set table for every lighting volume (ADR-0004 relevance) | SneakKestrel16 / level-designer | Before ADR-0004 is Accepted |
