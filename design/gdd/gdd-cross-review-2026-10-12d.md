# Cross-GDD Review Report (since last review)

Date: 2026-10-12 (sixth cross-review, after `gdd-cross-review-2026-10-12c.md`)
Mode: since-last-review (consistency + design theory + scenarios)
GDDs Reviewed: 10 of 10 present (all changed since the last review: first-person-controller and lobby-role-assignment are new; borrowed-face, match-flow, pings-and-callouts, monster-abilities and the unchanged-by-this-diff downing-and-rescue, scare-events, survivor-defense, survivor-objectives were read in full and checked against the new pair)
Not read: none
Systems Covered: all ten system GDDs, plus `design/levels/research-facility.md`, `design/gdd/game-concept.md`, `systems-index.md` and `design/registry/entities.yaml`.

Pillars: Human Deception, Fair Fear, Counterplay, Readable Objectives, Small Shippable Scope. Anti-pillars: no AI monsters, not a combat game, not procedural, not voice-dependent, no progression or ranked.

Run notes:
- Headless run. Phases 2 and 3 were done inline, not by spawned sub-agents (all ten GDDs, the level doc, the registry, the index and the concept were already read in full in this context). No phase was skipped.
- Scope: everything since the last review report. That covers the two new MVP GDDs (Controller, Lobby), the 4-6 player propagation (d373070), and the steering-pursuit dodge change in Monster Abilities (702a2e5). `review-scope.sh` lists all ten GDDs as changed because the cross-review resolution commit touched them; the DEPS line adds `research-facility.md`.
- Both new GDDs were read line by line and every Cross-References row of the Controller and every Cross-References bullet of the Lobby was checked against its target.
- Standard tier (`modes.workflow: standard`): the five required sections plus Formulas are present in both new GDDs. Advisory only: the Controller has no Player Fantasy or Tuning Knobs section (its Formulas variable tables carry safe ranges); the Lobby has no Player Fantasy section (its Overview closes with the player experience).
- The systems index and `active.md` were not edited (parent session handles them).

---

## Status of the previous report's items

| Item | Status |
|---|---|
| 12c W1 `FormChanged` consumers (index, Survivor Defense, Borrowed Face) | Resolved (index row lists Survivor Defense; both Dependencies rows name it) |
| 12c W2 registry comment for `stun_immunity_s` | Resolved (comment now names the lunge and disguise early ends and the post-lock window) |
| Earlier W1-W5, W8-W11, W13, D1 | Resolved per the 12c Resolution section; spot-checked, still in place |
| Earlier D2 (monster attention load) | Still open, advisory. Carried below as D2 |

---

## Consistency Issues

### Blocking

🔴 **B1. The Controller says no system ever changes a player's camera; Scare Events and two others do** (first-person-controller, scare-events, downing-and-rescue, survivor-defense).
- `first-person-controller.md` Core Rule 7: "Look is never taken ... No system rotates or locks a player's camera." The Acceptance Criteria make it a unit test: "no system call changes camera orientation. Test: apply every root, slow, lock, Downed, Seized, Transforming and Holding state and assert the view direction follows input only." Its Dependencies row for Scare Events says "Scares never move or lock the camera (Core Rule 7); a limit both GDDs state".
- `scare-events.md` rule 13 defines the opposite exception: a Major scare "may apply a camera flinch (involuntary view nudge) of at most `scare_max_control_loss_s` = 0.3 s". Impact Moments: "Camera flinch, <=300 ms, View nudge toward origin". Rule 27 and the AC "No flinch plays on a survivor within `lunge_cue_radius_m`..." test it. Scare Events states no such "never move the camera" limit; the Controller's claim about "both GDDs" is false.
- Related presentation: Downing Impact Moments "Camera impact (victim) 200 ms" and "Screen shake (victim) 300 ms decaying during commit"; Survivor Defense "camera jitter" for the shocked victim and "Camera impact (monster) 200 ms jolt on stun". Whether these rotate the view or only offset it visually is unstated.
- The two acceptance criteria cannot both pass: the Controller test fails the first time a flinch plays. The Controller also says the server owns the view direction used by taser aim and pings (rule 10), so it matters whether a flinch changes that direction.
- Needs a designer decision (see Decisions below). Fix is a few lines in the Controller whichever way it goes.

### Warnings

⚠️ **W1. Objectives cancels a hold at 2.0 m; the Controller keeps it to 2.25 m** (survivor-objectives rule 2, first-person-controller rule 14).
- Objectives rule 2: a hold is cancelled by "moving out of `interact_range_m` = 2.0". Controller rule 14 (design-review decision): once Holding, range is checked against `range_m` + `hold_range_tolerance_m` (0.25), so the same walk-out cancels at 2.25 m. The Controller's own example says so ("walking out to 2.2 keeps the hold").
- The Controller also cancels on lost line of sight and on starting another hold or using an item; Objectives rule 2 and its "reset always has a visible cause (hit, moved, released)" failure texture list neither, so the UI cause list is short two causes.
- Fix: Objectives rule 2 and Game Feel point at the Controller pattern (range plus tolerance, line of sight, one hold per actor). Same for Downing rule 7's "leaves range" (moot there, rescue roots the actor).

⚠️ **W2. The Controller's interactable contract is not met by Survivor Defense or the backup switch** (first-person-controller rule 11, survivor-defense rules 19-27, monster-abilities rule 19).
- Rule 11 requires each owner to define: `range_m`, `duration_s`, `roots_actor`, progress on cancel, exclusive lock, whether the shapeshifter may fake it. Objectives (`interact_range_m` 2.0, cancel = reset, fakes = rule 25) and Downing (`rescue_range_m` 1.5, roots, keep-and-decay) comply.
- Survivor Defense defines durations for hide (1.0 s), barricade (3 s), remove (1 s), search (1.5 s), break (5 s, progress kept) but no `range_m` for any of them, no `roots_actor`, no exclusive-lock statement, and no range for door toggles. Monster Abilities defines `backup_switch_hold_s` = 1 s with no range or cancel rule.
- The Controller's load-time check (`interact_ray_max_m` >= largest owner range + 0.7) cannot be evaluated until those ranges exist. All of these owners are listed as Hard dependants of the Controller.
- Fix: add the missing fields to Survivor Defense and the backup switch row. Values are mechanical; propose 2.0 m for all (the Objectives value) unless the designer wants otherwise.

⚠️ **W3. The systems index does not list the Controller's reads, and its layering now has a loop** (systems-index, first-person-controller).
- The index says "A system may read another system's state only if that state is in the state table". The Controller reads, per its States table and Interactions table: the Transforming flag (Borrowed Face rule 8), Seized and Downed life states, Committing, Hidden, Lunge wind-up (root), plus root and slow modifiers from Survivor Defense, Downing and Monster Abilities. In the index, only the "Shock/stun lock" row names the Controller as a reader. "Transforming flag", "Hidden and item-use state", "Takedown eligibility (Seized, Downed, grace)", "Committing state" and "Lunge state" do not. There is no row for the movement modifier interface itself (root, slow, lock, with owner).
- `PlayerConnectionChanged` (Controller cancels holds, Controller Dependencies and Match Flow row) is not in its consumer list.
- Layering: the Dependency Map puts the Controller in the "Foundation Layer (no dependencies)", while its own index row says it depends on Network Authority and Match Flow (soft). Match Flow (Feature) depends on Objectives, which depends on the Controller. Foundation -> Feature -> Foundation is a loop that the Circular Dependencies section does not list. The Controller's actual need is only the `RoundEnded` and `PlayerConnectionChanged` events, which the index already delivers to "All systems".
- Fix: add the missing readers and a movement-modifier row; list the Controller as a consumer of `PlayerConnectionChanged`; either drop the Match Flow row from the Controller's Depends On and Dependency table (event-only) or add the loop to Circular Dependencies. Recommend event-only (see Decisions).

⚠️ **W4. The Facility Map does not author what the Controller expects of it** (research-facility, first-person-controller).
- Controller Interactions table: Facility Map flows in "Step and slope geometry, door swing areas". Dependencies: "step and slope limits, capsule (doorways >= 0.8 m clear)". AC: every doorway on the two routes "passes the 0.3 m capsule without snagging".
- `research-facility.md` defines no doorway width, no step height or slope limit, and no door swing area. Its Dependencies row for the Controller names only walk speed and hold-to-interact. It also has no Lobby row (Lobby lists the Map as a Soft downstream; the Map names Lobby only in its Prerequisite line and Spawn Points table).
- The placement overlay draws S1-S4 only; the Spawn Points table adds S5 (5-survivor rounds). Not wrong, but the overlay legend says `S1-S5`.
- Fix: add a "Geometry limits" line to the Map (minimum clear doorway 0.8 m, `step_height_m` 0.35, slope 40 degrees, door swing area per door), a Lobby row to Dependencies, and S5 to the overlay.

⚠️ **W5. The 4-6 player decision has not reached the concept, the index overview or a few numbers** (game-concept, systems-index, survivor-defense, downing-and-rescue, entities.yaml).
- `game-concept.md` still says "Player Count: Exactly 5 per match: 1 monster vs. 4 survivors", the pitch "five-player ... four survivors", the Core Fantasy "four people in the dark" and MVP item 1 "five-player lobby". Lobby rule 1 and Match Flow rule 1 now say 4-6, MVP config fixed at 5. The index Overview repeats "five-player ... one shapeshifter against four human survivors". True for the MVP config, false as a description of the system. The Lobby's open question listed the docs to update and omitted these two.
- `entities.yaml`: entity `survivor` has `count_per_match: 4`; `min_players` 4 and `max_players` 6 are registered but the MVP config override (5 and 5, Lobby Tuning Knobs) is not; `reconnect_grace_s` is used by Lobby but Lobby is not in `referenced_by`.
- Hard-coded 4-survivor figures in approved GDDs: Survivor Defense "Team stun budget: survivors * stun_item_charges = 4 * 2 = 8"; Downing `healthy_survivors` range "0-3". Match Flow, Pings and Scare Events acceptance criteria say "5 clients" (correct for the MVP config; no criterion exercises 4 or 6 outside Lobby AC-LB-01/10 and the Controller performance AC).
- All are acknowledged-untuned per Lobby Open Questions (balance at 3 and 5 survivors is a Milestone 5 item). They are text and registry drift, not rule conflicts.
- Fix: update the two concept/index lines ("4-6 players; MVP config 5"), the registry count and MVP config note, and make the two formulas read the survivor count.

⚠️ **W6. Stale cross-reference text and incomplete registry coverage** (low priority housekeeping).
- Lobby Cross-References bullet says "Spawn Points (S1-S4)"; the Map has S1-S5. Lobby Dependencies ends "Bidirectional entries ... are pending propagation (Open Questions)" while its Open Questions row says all are resolved. Lobby Cross-References is a bullet list, not the template table with a Nature column.
- Controller Dependencies row for Match Flow says "`match-flow.md` does not yet name this system (one-directional; to fix)"; Match Flow Dependencies now has the row (resolved in the Controller's own Open Questions).
- Downing "Crawl speed": "`walk_speed` is owned by First-Person Controller (no GDD yet)". The GDD exists; walk_speed is 4.0.
- Match Flow Open Questions still carries "Should the results screen reveal the shapeshifter player's name? Proposed: yes"; rule 24 and the Lobby make roles public, so the question is moot. Borrowed Face's "name label" row and AC apply "wherever labels exist"; Lobby rule 11 and AC-LB-31 say rounds show none on bodies, so that row is currently vacuous (feed and ping names still apply).
- Registry: constants the Controller consumes across systems are unregistered (`crawl_speed_mult`, `lunge_distance_m`, `lunge_hit_radius_m`, `lunge_dash_s`, `miss_slow_multiplier`, `stun_root_s`, `stun_slow_mult`, `lunge_cue_radius_m`, `interact_range_m`, `rescue_range_m`, `install_noise_radius_m`, `hide_noise_radius_m`). `gait_speed` lists `crawl_speed_mult` as a variable with no registry entry behind it.

---

## Game Design Issues

### Blocking
None.

### Warnings

⚠️ **D1. Unlimited sprint shortens every travel budget the Map and the grouping concern were computed at** (first-person-controller, research-facility, survivor-objectives).
- The Map's traversal table, the "any room to any room in 20 s" target and the cross-review D1 grouped-route estimate (about 2-3 min against 420 s) all use walk speed 4.0. The Controller gives every survivor sprint 5.0 m/s with no stamina; the only cost is noise within 20 m. Travel time drops by 20 percent, so the clock forces a split even less than D1 already feared. A group can sprint everywhere whenever the shapeshifter is not within 20 m and still holds the objective work in series (`min_work_s` 50).
- Sprint is also the one continuous decision the Controller adds to a survivor: free unless the monster is near, which survivors cannot see. That favours "always sprint, walk when something is close", a thin choice. The Controller's own Open Question ("Is a 1.0 m/s sprint gain worth its noise?") and Map AC 11 (grouping telemetry) already cover this.
- No design change proposed now. Recommend adding sprint to the AC 11 telemetry (share of time spent sprinting, and how often the monster was within 20 m when a survivor sprinted) so the M2 playtest can settle both questions.

⚠️ **D2. Monster attention load (carried from earlier reports, still open).** Unchanged by this diff. The Controller adds no new monster-side decision (disguised movement is automatic parity). Track in the M5 playtest.

⚠️ **D3. The Lobby is larger than the MVP the concept describes** (lobby-role-assignment, game-concept; Pillar 5 Small, Shippable Scope).
- The concept's MVP item is "five-player lobby, role assignment, first-person movement". The Lobby GDD specifies direct join with version check, name uniqueness, a persistent rotation queue with owed turns and token persistence, five characters with preference persistence and clash resolution, host kick, host-only settings and a 5 s all-ready countdown: 31 acceptance criteria, and code paths for 4, 5 and 6 players although only 5 is played and tuned in the MVP.
- Each piece was a deliberate designer decision. The risk is cost, not coherence. Suggestion for the sprint plan: ship Milestone 1 with a random shapeshifter and random characters, then add rotation, preference and kick when the round loop works.

ℹ️ **D4. Public roles and the disguise (Info).** Lobby rule 11 shows the next shapeshifter in the lobby, so survivors know which player is the monster; deception is which body is real. Core Fantasy in the concept ("you can't be sure the person next to you is a person") and the Key Dynamics still hold at the body level, but with proximity voice On any spoken word from a disguised body is a perfect identifier (survivors know that player's voice). Pings rule 25 and Lobby rule 11 already accept this as a fair tell, so voice On means the monster stays silent while disguised. Worth a line in the concept and a playtest question; no GDD change needed.

Checks with no finding: 3a (no progression loops by design), 3d (resources are finite and sink-only by design: tasers, cartridges, bleed-out; stamina was removed, so nothing accumulates), 3e (no scaling curves; the three phases are fixed), 3f (the Controller serves Fair Fear, Counterplay and Human Deception through speed parity, a bounded chase and visible footsteps; the Lobby serves Human Deception and Small Scope; no anti-pillar is violated), 3g (fantasies stay compatible).

---

## Cross-System Scenario Issues

Scenarios walked: 6
1. Fuse install hold, then the survivor shifts position or is shocked (Controller, Survivor Objectives, Survivor Defense, Scare Events).
2. Sprint chase to a lunge, taser, door slam (Controller, Monster Abilities, Survivor Defense, Downing).
3. Major scare reaches a survivor mid-dodge or mid-hold (Scare Events, Controller, Monster Abilities).
4. False Signal footsteps against real gait footsteps (Monster Abilities, Controller, Pings).
5. Six-player round start to results (Lobby, Match Flow, Facility Map, Borrowed Face, Objectives).
6. Host is the shapeshifter and leaves or lags (Lobby, Match Flow, Monster Abilities).

#### Blockers
None beyond B1, which scenario 3 confirms: a Major scare's flinch on a survivor outside the 20 m radius must break the Controller's "view follows input only" test.

#### Warnings

⚠️ **False Signal footsteps move at crawl pace but are heard like walking** — Monster Abilities rules 14-15, Controller rule 8, Controller Open Questions.
- Step: the monster plays "3 s of survivor footsteps ... moving up to 3 m" (rule 14). That is at most 1.0 m/s, the crawl speed. Rule 15 says the sound reaches survivors "within the audible range of the real sound it imitates". Real footsteps now have gait-dependent ranges (crouch and crawl 2 m, walk 6 m, sprint 20 m), and the Controller's open question proposes walk (6 m) for the fake. Real walking footsteps cover 12 m in 3 s; a fake covering 3 m in 3 s has a cadence-to-distance mismatch an attentive listener can use to tell it apart. That contradicts the intent that a fake is an approximate clue, not a free tell.
- The Controller's Open Question ("False Signal footsteps need a gait for their audible range") is still unresolved and Monster Abilities was last edited for the dodge model only.
- Needs a designer decision (see Decisions).

#### Info

ℹ️ **Host as shapeshifter** — Lobby rule 1 (listen server: the host's process is the server) with Monster Abilities `max_rewind_ms` and the latency budget. When the host is the monster it has zero latency and all survivors are clients, so the 150 ms rewind and the survivors' reaction budget (Monster Abilities "Survivor latency") assume the opposite. It is rotation-fair over a session, and the host leaving ends the session (Lobby rule 19). Listed so the Network Authority ADR decides listen versus dedicated with this in view.
ℹ️ **Two dodge criteria for one scenario** — Monster Abilities' AC (strafe from 0.25 s after the cue with a 150 ms-latency monster) and the Controller's AC (strafe from 0.40 s, steering monster, 20 seeds) test the same 0.40 s budget with different parameterisation. Make one authoritative to avoid two differently-failing tests.
ℹ️ **Scenarios 2 and 5 consistent.** The chase numbers agree end to end (catch gap 1.0 m at 5.0 m/s, taser gain 7.1 m, miss slow gain 3.2 m, dodge margin 1.25, joint cap 5.4 m/s) between the Controller and Monster Abilities. A 6-player round has spawns S1-S5, one character per survivor, and unchanged objective counts.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|---|---|---|---|
| first-person-controller.md | B1 camera rule 7 and its AC; W3 Match Flow dependency/layer; W6 stale Match Flow note | Consistency | Blocking |
| scare-events.md | B1 flinch against the Controller's "look is never taken" | Consistency | Blocking |
| downing-and-rescue.md | B1 camera impact/shake wording; W1 note; W6 "no GDD yet" | Consistency | Warning |
| survivor-defense.md | B1 camera jitter/jolt wording; W2 ranges and interactable fields; W5 team stun budget | Consistency | Warning |
| survivor-objectives.md | W1 range/cancel causes defer to the Controller pattern | Consistency | Warning |
| monster-abilities.md | W2 backup switch range and cancel; False Signal footstep gait | Consistency / Scenario | Warning |
| research-facility.md | W4 geometry limits, Lobby row, S5 overlay | Consistency | Warning |
| lobby-role-assignment.md | W6 S1-S5, stale propagation line, Cross-References table; D3 scope split | Consistency / Design Theory | Warning |
| systems-index.md | W3 readers, modifier row, layering; W5 Overview | Consistency | Warning |
| game-concept.md | W5 player count; D4 wording | Consistency | Warning |
| entities.yaml (registry) | W5 count and MVP config; W6 unregistered constants | Consistency | Warning |

---

## Verdict: FAIL

One blocking issue (B1: the Controller's "no system changes the camera" rule and test against Scare Events' camera flinch and the camera impacts elsewhere). It needs one designer decision and a few lines of text. Everything else is a warning.

### If FAIL — required actions before re-running:
1. Decide B1, then edit `first-person-controller.md` rule 7, its camera acceptance criterion and the Scare Events Dependencies row to match; add a one-line statement in `scare-events.md`, `downing-and-rescue.md` and `survivor-defense.md` of whether their camera effects rotate the view or only offset it visually.
2. Clear or accept W1-W6 and decide the False Signal footstep gait before `/create-architecture`. W3 (index readers and the layering loop) matters most for architecture because the ADRs derive the event and state interfaces from the index.

### Recommended next
Resolve B1 and the False Signal footstep decision with the designer, apply the mechanical fixes (W1-W6) in one pass, then re-run `/review-all-gdds since-last-review`. After a CONCERNS-or-better result, re-run `/gate-check` for Technical Setup.
