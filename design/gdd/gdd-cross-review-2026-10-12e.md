## Cross-GDD Review Report (since last review)

Date: 2026-10-12 (seventh cross-review, after `gdd-cross-review-2026-10-12d.md`)
Mode: since-last-review (consistency + design theory + scenarios), headless
GDDs Reviewed: 10 of 10 present (changed since the 12d report: borrowed-face, downing-and-rescue, first-person-controller, lobby-role-assignment, match-flow, monster-abilities, scare-events, survivor-defense, survivor-objectives; pings-and-callouts is unchanged and was checked by targeted search only)
Not read: none. (`design/levels/research-facility.md` came in through the DEPS line; `systems-index.md`, `game-concept.md` and `design/registry/entities.yaml` were also checked.)
Systems Covered: all ten system GDDs plus the Facility Map, the index, the concept and the registry.

Pillars: Human Deception, Fair Fear, Counterplay, Readable Objectives, Small Shippable Scope. Anti-pillars: no AI monsters, not a combat game, not procedural, not voice-dependent, no progression or ranked.

Run notes:
- Headless. Phases 2 and 3 were done inline, not by spawned sub-agents: the scope is one fix commit (b803588) and the work was a diff-driven check of what it changed. No phase was skipped.
- Method: the full b803588 diff (13 files) was read, then each changed rule was traced to every other GDD that states the same fact (camera, interactable contract, footsteps, Match Flow link, player count, registry). Unchanged text of the touched GDDs was not re-read end to end; the 12d report covered it.
- Standard tier (`modes.workflow: standard`): no missing required section in any changed GDD. Advisory carried over: the Controller still has no Player Fantasy or Tuning Knobs section; the Lobby has no Player Fantasy section.
- Per instruction, no GDD, the index, the registry or `active.md` was edited, and nothing was committed.

---

## Status of the previous report's items

| Item | Status |
|---|---|
| 12d B1 camera conflict (Controller rule 7 against Scare Events flinch) | Resolved in text. Controller rule 7, its camera AC and its Scare Events row, Scare Events rules 13-14, Dependencies and Impact Moments, and the Downing and Survivor Defense camera rows now agree: the Scare Events flinch is the single server-applied rotation; everything else is a visual offset. New follow-on gaps are W1-W3 below |
| 12d W1 objective hold range 2.0 vs 2.25 | Resolved. Objectives rule 2 and its failure texture, and Downing rule 7, defer to the Controller pattern. Small leftover: I1 |
| 12d W2 interactable contract fields | Resolved for ranges. Survivor Defense rule 28a gives every field; backup switch (Monster Abilities rule 19) gives range, roots, cancel, lock and fake. Follow-on gaps are W4 |
| 12d W3 index readers, modifier row, layering loop | Resolved. Readers added to the four state rows, `PlayerConnectionChanged` consumer added, movement-modifier row added, Controller's Match Flow link made event-only in the Controller, the index row 3 and Match Flow's own row ("It depends on this"). Leftover housekeeping: I2 |
| 12d W4 Facility Map geometry, Lobby row, S5 overlay | Resolved (Geometry limits paragraph, Controller row extended, Lobby row added, overlay and spawn table agree on S5) |
| 12d W5 4-6 player wording and numbers | Resolved in concept Elevator Pitch, Player Count and MVP item 1, index Overview, registry (`survivor` `count_per_match` 4, `count_range` 3-5, `min_players`/`max_players` MVP config note, Lobby in `referenced_by`), Survivor Defense team stun budget, Downing `healthy_survivors`. Concept line 60 "Four survivors" and line 273 "Five players" remain; both describe the MVP config and are acceptable |
| 12d W6 stale text and unregistered constants | Resolved except the Lobby Cross-References table form (I3). The 12 listed constants are registered with the values the GDDs state (checked: 0.25, 4, 1.2, 0.3, 0.5, 1.0, 0.5, 20, 2.0, 1.5, 25, 8) |
| 12d D1 sprint shortens travel budgets | Resolved as asked: Facility Map AC 11 now records sprint share and monster-within-20-m telemetry. The design question itself stays a playtest item |
| 12d D2 monster attention load | Still open, advisory, unchanged by this diff. Carried |
| 12d D3 Lobby larger than the MVP | Resolved by a Delivery paragraph (Milestone 1 ships random role and characters). Leftover: I4 |
| 12d D4 public roles and voice | Carried as Info, no GDD change requested |
| 12d scenario warning: False Signal footsteps | Resolved in text (walk gait, 6 m, ~12 m path over 3 s). Follow-on gaps are W5 |
| 12d Info: host as shapeshifter; two dodge criteria | Dodge criteria resolved (Monster Abilities AC now names the Controller AC as authoritative). Host-as-shapeshifter stays an Info for the Network Authority ADR |

---

## Consistency Issues

### Blocking

None.

### Warnings

⚠️ **W1. The server-applied flinch has no defined interaction with the accessibility toggle or with client-sent view angles** (scare-events rules 13, 14 and 27; first-person-controller rules 7, 9, 10 and the camera AC).
- Scare Events rule 27: with the camera flinch toggle off, "rule 13's flinch is replaced by a screen-edge pulse". Controller rule 7 and Scare Events rule 13 now say the flinch is applied by the server and "the server's view direction and aim ray follow the nudge". Nothing says the server knows a player's toggle. If the toggle is client-side only, a toggled-off client keeps its view still while the server copy rotates, so taser aim, pings and interaction targeting (all server-ray, Controller rule 10) point where the player is not looking. That is the desync the B1 fix set out to avoid.
- Controller rule 9: the client sends absolute view yaw and pitch every tick. A server nudge needs a rule for how it combines with the next client yaw (additive server offset that the client also plays, or the server overwriting the client yaw for up to 0.3 s). The camera AC ("assert the server view direction moves with it for at most 0.3 s") also does not say whether the view returns after the flinch or stays rotated.
- Fix (needs a designer decision D1): state the toggle as a server-known per-player flag and the nudge model in Controller rule 7 and Scare Events rule 13.

⚠️ **W2. The flinch interface is missing from the index and the dependency rows are inconsistent** (systems-index, first-person-controller Dependencies, scare-events Dependencies).
- The index has a row for movement modifiers (Survivor Defense, Downing, Monster Abilities to the Controller) but none for the one new owner-to-Controller flow that actually rotates the view: Scare Events to Controller. The index state table sentence "A system may read another system's state only if that state is in the state table" applies to the flinch offset too.
- Index system row 12 (Scare Events) "Depends On" does not list the Controller; Scare Events' own Dependencies row says "Bidirectional"; the Controller's row says "Soft".
- The Controller Dependencies row added in b803588 has three cells in a four-column table (`| Scare Events | Soft | The camera flinch... |`): the Direction cell is missing, so the Hard/soft column renders the sentence.
- Fix: one index row for the view-nudge flow, add the Controller to row 12, make the two Dependencies rows agree, repair the table row. Mechanical.

⚠️ **W3. Borrowed Face still has a "small flinch" camera effect that rule 7 does not classify** (borrowed-face Impact Moments, first-person-controller rule 7).
- `borrowed-face.md` Impact Moments: "Camera impact (viewers of reveal) | <= 300 | Small flinch, no input lock". Controller rule 7 lists the downing impact and shake, the survivor-defense jitter and jolt as visual-only and names the Scare Events flinch as the single rotation. The reveal flinch is neither in the list nor named as the same effect. Scare Events AC (line 291) speaks of "a reveal flinch running when a wind-up starts", so the reveal is a Major scare with a flinch, but Borrowed Face does not point to it.
- If it is a separate effect it is a second view rotation, which rule 7 forbids; if it is the Scare Events reveal flinch, it inherits rule 14 suppression and the toggle, and the Borrowed Face row should say so.
- Fix (needs decision D2): make the row a reference to the Scare Events flinch, or mark it visual-offset only.

⚠️ **W4. Survivor Defense rule 28a and the backup switch leave small contract gaps** (survivor-defense 28a and Tuning Knobs, monster-abilities rule 19 and Tuning Knobs, first-person-controller Formulas, registry).
- 28a introduces `survivor_interact_range_m` = 2.0 as a second name for Survivor Objectives' `interact_range_m` = 2.0. It has no Tuning Knobs row or safe range in Survivor Defense and no registry entry; the registry has only `interact_range_m` (owned by Objectives). Two names for one value will drift when one is tuned.
- The Controller's `max_owner_range_m` row still names only Objectives (2.0) and Downing (1.5); it does not name Survivor Defense or the backup switch. The load-time check is satisfiable now (largest range 2.0 plus 0.7 is under the default `interact_ray_max_m` 3.0), but `backup_switch_range_m` has a safe range of 1.5-2.5, and at 2.5 the check needs a ray of 3.2, above the default. The same holds for the existing Objectives safe range up to 3.
- 28a gives Barricade, Remove barricade and Break each "one actor per door". It does not say whether that is one lock per door shared by all three (a survivor removing a barricade while the monster breaks it) or one lock per action. Search and Hide have the same shape per spot.
- `backup_switch_hold_s` and `backup_switch_range_m` are not in the registry (both are Monster Abilities-owned and cross-referenced by the Controller and the Facility Map).
- Fix: reference `interact_range_m` from 28a (or register the new name), add the owners to the Controller's range row, state the lock scope, register the switch constants. Values stay as proposed.

⚠️ **W5. False Signal footsteps: the "~12 m" is a literal, and the path is not bounded by the existing validation** (monster-abilities rules 14-15, Edge Cases, Tuning Knobs, AC).
- Rule 14 and the AC say "up to ~12 m" and "3 s at walk cadence". 12 m is `walk_speed` 4.0 x 3 s, a derived number, but it is written as a constant. If the Controller's walk speed is tuned, the fake no longer matches real walking cadence, the exact tell the decision removed. There is no Tuning Knobs row for the footstep duration or the path length (the knobs list `false_signal_range_m` 20 only).
- Validation applies to the aim point only ("an aim point beyond 20 m or inside a wall is rejected"; Edge Cases: aimed through a wall is allowed). A path of 12 m from an aim point at 20 m ends up to 32 m from the monster, and nothing says what happens if the path crosses a wall, leaves the facility or ends inside a wall.
- The Monster Abilities Dependencies row for the Controller says "Movement for dash and slow; backup switch hold". It does not name the walk radius and walk speed the fake now depends on (the registry does: `footstep_radius_walk_m` lists Monster Abilities).
- Fix: derive the path length from `walk_speed` x duration, add the two knobs, and state whether the path stops at a wall (needs decision D3), then update the Dependencies row.

---

## Game Design Issues

### Blocking

None.

### Warnings

⚠️ **D2. Monster attention load (carried).** Unchanged by this diff. The backup switch hold adds no monster-side decision. Track in the M5 playtest.

ℹ️ **D1 (carried, advisory).** Free sprint and the grouping question now have telemetry (Facility Map AC 11). Nothing further until the M2 playtest.

ℹ️ **D4 (carried, Info).** Public roles with voice On make any spoken word from a disguised body a perfect identifier. Pings rule 25 and Lobby rule 11 accept this. A concept line and a playtest question would record it; no GDD change needed.

ℹ️ **D5. Backup switch cannot be faked.** Monster Abilities rule 19 (inferred, proposed): "the shapeshifter may not fake it". Objectives rule 25 lets a disguised monster fake objective holds so that standing at an objective is never a tell. For the switch the opposite holds: a disguised monster that walks up and does nothing cannot be told from a survivor who is deciding, so no tell is created, but the monster also cannot pretend to restore the zone it just blacked out. This is a deliberate design choice to confirm, not a conflict (Pillar: Human Deception). Listed under decisions as D4.

Checks with no finding: 3a (no progression loops), 3d (resources finite and sink-only; the team stun budget now scales with survivor count and still stays near 3 to 4 percent of a round), 3e (no scaling curves), 3f (the flinch decision keeps Fair Fear: one rotation, 0.3 s, suppressed near a wind-up; the False Signal decision serves Human Deception and Counterplay: survivors verify by sight), 3g (fantasies compatible; no anti-pillar violated).

---

## Cross-System Scenario Issues

Scenarios walked: 6
1. Major scare flinch reaches a survivor mid-hold, mid-taser-aim and 22 m from a wind-up (Scare Events, Controller, Survivor Defense, Monster Abilities).
2. Fuse install hold, walk out to 2.2 m, then a shock (Controller, Survivor Objectives, Survivor Defense).
3. Backup switch restore with two survivors holding it, then the Blackout cooldown (Monster Abilities, Controller, Facility Map).
4. Barricade, remove and break on one door at the same time (Survivor Defense, Controller).
5. False Signal footsteps against real gait footsteps, aimed at a wall (Monster Abilities, Controller, Pings).
6. Six-player round start with S5 spawn, then a mid-round disconnect while holding (Lobby, Match Flow, Facility Map, Controller, Objectives).

#### Blockers

None.

#### Warnings

⚠️ **Flinch with the toggle off, then a taser shot** — Scare Events, Controller, Survivor Defense. Step: a survivor with the flinch toggle off receives a Major scare; the screen-edge pulse plays, the client view stays still, the server copy of the view rotates toward the scare origin. The survivor fires a taser within the 0.3 s window and the server resolves the shot against the rotated ray. Same cause as W1; resolved by decision D1.

⚠️ **False Signal footsteps that end in or past a wall** — Monster Abilities, Controller. Step: aim point at 18 m, direction toward a wall; 12 m of path crosses it. Behaviour of the sound past the wall is undefined (W5; decision D3).

#### Info

ℹ️ **Scenario 2 consistent.** Objectives rule 2 (start at 2.0 m, keep to 2.25 m, cancel on lost line of sight, another hold or item use) matches Controller rules 13-16 and the Game Feel failure texture. Objectives omits "hiding" from the cancel list (Controller rule 16 includes it); hiding is already excluded for a hidden survivor by the Hidden-state interaction rule, so the player-visible result is the same (I1).
ℹ️ **Scenario 3.** The switch hold is consistent with the Controller pattern (walk, no sprint, reset on cancel, no lock). Two survivors may hold it together and the first to finish restores the zone; the second hold ends with the zone already lit (cancel on completion is implied, not stated).
ℹ️ **Scenario 6 consistent.** S5 is used only at 5 survivors, `PlayerConnectionChanged` cancels the hold (index consumer list, Controller, Match Flow row all agree).
ℹ️ **Host as shapeshifter** (carried): listen-server latency assumptions in Monster Abilities for the Network Authority ADR.

---

### Housekeeping (Info, not blocking)

- I1. Survivor Objectives rule 2 and its failure texture list the Controller causes except hiding.
- I2. The index Dependency Map heading reads "Foundation Layer (no dependencies)" and lists the Controller, which depends on Network Authority; the Systems Enumeration labels it "Core". Pre-existing label mismatch, no longer a loop.
- I3. Lobby Cross-References is a bullet list, not the template table with a Nature column.
- I4. Lobby acceptance criteria for rotation (AC-LB-13 to 19), preference persistence (AC-LB-07 to 12, 20) and kick (AC-LB-30) are not tagged by milestone although the Delivery paragraph defers those features past Milestone 1. Tag them so QA does not read them as Milestone 1 gates.
- I5. `monster-abilities.md` header "Last Updated" does not mention the 12d changes.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| scare-events.md | W1 toggle and server view; W2 interface row and Dependencies | Consistency | Warning |
| first-person-controller.md | W1 flinch model against client-sent yaw; W2 malformed Scare Events row; W4 range row | Consistency | Warning |
| systems-index.md | W2 flinch interface row; Scare Events Depends On; I2 | Consistency | Warning |
| borrowed-face.md | W3 reveal "small flinch" row | Consistency | Warning |
| survivor-defense.md | W4 range name, knobs, lock scope | Consistency | Warning |
| monster-abilities.md | W4 switch constants and range; W5 footstep path; D4 switch fake | Consistency / Scenario | Warning |
| design/registry/entities.yaml | W4 `backup_switch_*`, interact range name | Consistency | Warning |
| lobby-role-assignment.md | I3, I4 | Housekeeping | Info |
| survivor-objectives.md | I1 | Housekeeping | Info |

---

## Verdict: CONCERNS

The one blocker from the 12d report (B1) and all of its warnings are resolved in text; no blocking issue remains. Five new warnings come from the fixes themselves, mostly gaps in the flinch model (W1 to W3, one designer decision each) and mechanical bookkeeping (W2, W4, W5). None block `/create-architecture`, but W1 and W2 should be settled before the Network Authority ADR, because the ADR derives view-direction authority and the interface list from them.

### Designer decisions needed
- D1 (W1). Flinch with the accessibility toggle and client yaw. Options: (a) the toggle is a server-known per-player flag; with it off the server applies no rotation and the screen-edge pulse plays alone; the nudge is a server-held offset added to client yaw that settles within 0.3 s and stays (recommended: no desync, matches Scare Events rule 27); (b) server always rotates and the client always plays the nudge, the toggle only softens the animation; (c) drop the toggle and the rotation, flinch becomes a visual offset (reopens the B1 decision).
- D2 (W3). Borrowed Face reveal "small flinch". Options: (a) it is the Scare Events reveal flinch, so Borrowed Face references it (recommended: one rotation source, inherits rule 14 and the toggle); (b) visual offset only.
- D3 (W5). False Signal footstep path against walls. Options: (a) the fake path stops at the first wall and the path length derives from walk speed x 3 s (recommended: simplest, matches real footsteps that cannot pass a wall); (b) it passes through walls and sound attenuation handles it; (c) the path is clamped to the walkable map.
- D4 (D5). Backup switch fake. Options: (a) keep "cannot be faked" and playtest (recommended: no evidence of a tell, value was inferred); (b) allow a fake hold like Objectives rule 25.

### Required actions before re-running
None blocking. Recommended: apply the mechanical fixes (W2, W4, W5 derivations, I1 to I5) in one pass after D1 to D4, then re-run `/review-all-gdds since-last-review` and `/gate-check` for Technical Setup.

### Recommended next
Settle D1 and D2 (they change Controller rule 7, Scare Events rule 13 and the Borrowed Face row), apply the mechanical pass, then re-run this review.
