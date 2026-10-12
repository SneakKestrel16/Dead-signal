# Cross-GDD Review Report

Date: 2026-10-12
Mode: full (consistency + design theory + scenarios)
GDDs Reviewed: 8 of 8 present
Not read: none
Systems Covered: Match Flow & Win Conditions, Survivor Objectives, Downing Rescue & Elimination, Survivor Defense, Borrowed Face, Monster Abilities, Pings & Callouts, Scare Events. Also read in full: `game-concept.md`, `systems-index.md`, `design/levels/research-facility.md` (Facility Map), `design/registry/entities.yaml`, and the previous report `gdd-cross-review-2026-10-11.md` (to avoid re-raising resolved items).

Pillars: Human Deception, Fair Fear, Counterplay, Readable Objectives, Small Shippable Scope.
Anti-pillars: not an AI-monster game, not a combat game, not procedurally generated, not voice-dependent, not a progression or ranked game.

Run notes:
- Headless run. Phases 2 (consistency) and 3 (design theory) were done inline in the orchestrating session, not by spawned `game-designer` sub-agents. Both phases ran in full. No phase was skipped.
- Each GDD was read in full, not as section slices, so the Edge Cases and Interactions sections were also checked.
- The systems index was **not** updated. This run may write only this report and the session extract.
- The entity registry was loaded and used as the baseline. Gaps are listed under Info.

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

🔴 **B1. Scare triggers name mechanics that no system defines** (scare-events, monster-abilities, research-facility)

- `scare-events.md` three-sources table, "Ambush lunge (lunge from hiding or out of darkness)", and `monster-abilities.md` Interactions, "a lunge out of a hiding place counts as a player-triggered scare". The monster can never be in a hiding place. Survivor Defense rule 19 says "Only Healthy survivors can hide", and Borrowed Face rule 12 says the disguised monster "cannot enter a hiding spot". "Out of darkness" has no server test either: no GDD says when a lunge counts as coming out of darkness (in a blacked-out volume? Outside the target's flashlight?).
- `scare-events.md` table, "Glass break | … Monster (moving through)". The Facility Map defines glass partitions as "see-through, not passable" (`:` in the legend). No player can move through glass, and no GDD makes glass breakable.
- `scare-events.md` rule 2, Survivor source: "opening a sealed room". The map has no sealed rooms. Map rule 2 says no room can be sealed, and "secured room" is still an Open Question in both Objectives and the map.
- `scare-events.md` rule 2 and the table, "trip point" and "running through a glass partition area". The map lists no scare anchors or trip points. Its Dependencies row promises "door/glass scare anchors", but no table holds them.

→ A reference to a mechanic that does not exist is Blocking (Phase 2c). The architecture would inherit triggers that nobody defined.
→ Fix: define "ambush lunge" as a server test, e.g. "wind-up starts while the monster stands in a volume that is blacked out, or that the target has not had in line of sight for N s". Remove "hiding place" from Monster Abilities. Cut the "Monster moving through glass" and "sealed room" triggers, or define them in the map. Add a scare-anchor table to `research-facility.md`.

🔴 **B2. Two documents own facility lighting, and they disagree** (scare-events, research-facility, monster-abilities)

Both `scare-events.md` rule 22 (phase lighting/audio states) and `research-facility.md` "Lighting States" define the lighting for the same triggers (`RoundPhaseChanged`, `ObjectiveProgressChanged`, Blackout, round end). The index lists both "Scare Events" and "Facility Map (lighting)" as consumers of those events. The results differ:

| Trigger | `scare-events.md` | `research-facility.md` |
|---|---|---|
| Evacuation | "red rotating lights, faint emergency floor lights" | "overheads drop to ~50%; rotating **amber** beacons along H-N, H-S and C2" |
| Investigation | "Unstable; flicker frequency rises over the phase" | No Investigation lighting state |
| Round end | Results state: "Neutral" lighting | Reset row: "every volume returns to the round-start Low Power state" |
| Blackout active in the active terminal room when Evacuation starts | Edge Cases: "Emergency state applies; Blackout overlay stays for its remaining duration" | `blackout_able` paragraph: the Blackout "ends at that moment". `monster-abilities.md` edge row says the same |

The last row is a direct state-transition contradiction. One system keeps the room dark, and the other two end the Blackout. The architecture needs one owner of per-volume lighting state.
→ Fix (designer decision): pick one owner. The Facility Map already claims server ownership of "lighting state per volume" (Technical Notes). Scare Events would then only *request* states and add flicker or stingers. Align colours and the results state. Scope Scare Events' Blackout-at-Evacuation row to rooms other than the active terminal room.

🔴 **B3. Deception scares tell survivors that a False Signal is fake** (scare-events vs pings-and-callouts, monster-abilities)

- `scare-events.md` table: "Fake voice behind a door | Deception | Monster (False Signal) | Shared to listeners in range". Rule 1: every scare is sent as `ScareTriggered(scare_id, scope, source, origin, intensity, recipients)`. The AC says "every Monster/Survivor source names a player".
- `pings-and-callouts.md` rule 27: "The difference [between a real and a fake callout] must not be detectable from network data, except the absent gesture event". The AC: "A False Signal fake callout is indistinguishable from a real one in the data received by survivor clients".
- `monster-abilities.md` rule 3a keeps `AbilityUsed` server-internal so that it locates nothing. Rule 15: fake sounds use the same assets and "carry no visual source".

A `ScareTriggered` with `source = Monster` at the fake's origin goes only with fakes, so a modified client flags every False Signal. A Major stinger on it would also flag it to an unmodified client. The same leak applies to fake footsteps and fake interaction sounds if they get a scare entry. Scare Events' own Open Question ("Does the fake voice … count as a Major scare?") presumes it plays as a scare.
→ Fix: False Signal gets no scare entry, or its scare must be byte-identical to what a real callout or sound produces. In practice that means no `ScareTriggered` at all. Also decide whether `source` and player identity in `ScareTriggered` are server-only fields. As written, a reveal or Blackout scare that names the shapeshifter player reaches survivor clients.

### Warnings (should resolve, but won't block)

⚠️ **W1. Status and progress mismatches.**
- `monster-abilities.md` header says "Status: In Review". The index says Approved, and `reviews/monster-abilities-review-log.md` ends with "Verdict: APPROVED".
- `scare-events.md` header says "Draft". The index says "In Design".
- The index Progress Tracker says "Design docs approved: 4" and "Vertical Slice systems with a Draft GDD (none approved): 2/3". Seven rows are now Approved, including Pings & Callouts, which is Vertical Slice.
- `game-concept.md` Technical Considerations still says "Recommended Engine: Not chosen yet". `project.yaml` pins Godot 4.7.2. The Open Question "Engine and networking stack" is half answered.

⚠️ **W2. The index Depends On column and some Dependencies tables are stale or one-sided.**
- Index row 4 (Match Flow) omits Facility Map, Network Authority and Borrowed Face. All three appear in `match-flow.md` Dependencies.
- Index row 6 (Downing) omits Network Authority, Survivor Defense, Match Flow and Pings.
- Index row 8 (Borrowed Face) omits Monster Abilities, which its own table marks Bidirectional.
- Index row 9 (Monster Abilities) omits Network Authority, Controller, Survivor Defense, Pings, Match Flow and Survivor Objectives ("This depends on it").
- Index row 12 (Scare Events) omits Survivor Defense, Survivor Objectives and Pings & Callouts.
- `match-flow.md` lists Survivor Defense ("supplies stun stats; stops at round end"), but `survivor-defense.md` has no Match Flow row.
- `match-flow.md` lists Borrowed Face as Bidirectional, but `borrowed-face.md` lists Match Flow only as "Depends on this". Borrowed Face reads round start and owns the reconnect restore (Match Flow rule 20).
- `survivor-objectives.md` lists Borrowed Face as Bidirectional, while `borrowed-face.md` lists Objectives one-way.

⚠️ **W3. The event and state tables do not cover reads the GDDs make.** The index rule says a system may read another's state only through the state table or an event.
- `SurvivorEscaped` consumers omit Monster Abilities (rule 14 rejects a fake callout as an Escaped survivor) and Borrowed Face (see W4).
- `PlayerConnectionChanged` consumers omit Survivor Objectives (rule 13 drops items on disconnect) and Borrowed Face (rule 6 rejects disconnected targets, and it owns the disguise loss on monster reconnect).
- The "Hidden and item-use state" readers list only Survivor Objectives. Downing (rules 3 and 7), Monster Abilities (rule 7) and Pings (rules 6, 7a and 14a) all read it.
- The "Shapeshifter form" and "Transforming flag" readers omit Monster Abilities. Rule 4 requires True Form and rule 2 blocks abilities while Transforming. Monster Abilities is not a `FormChanged` consumer either.
- Lunge state (wind-up, active, takedown commit) appears in no table. Borrowed Face rule 7 reads it to reject transforms. Survivor Defense rule 16 reads wind-up start to end immunity early, and Survivor Defense is not an `AbilityUsed` consumer. Downing's Committing state, which Survivor Defense and Borrowed Face read, is also absent.

⚠️ **W4. Behaviour toward Escaped survivors is undefined in Borrowed Face, and Pings cites a rule that does not cover it.** Borrowed Face rule 6 allows a target "who is Healthy or Downed" and rejects "Eliminated or disconnected". It says nothing about Escaped. Pings rule 21 says "If the borrowed survivor is Eliminated or Escaped … (Borrowed Face rule 13 keeps the disguise on)", but rule 13 covers only "downed or eliminated". Fix: add Escaped to Borrowed Face rules 6 and 13, plus an edge row.

⚠️ **W5. The map's candidate AC contradicts Objectives' discovery rule.**
- `research-facility.md` "Authored Candidate Points": the server "replicates it to all clients". AC 4: "all 5 clients show the same active drive, fuse, fuse box and terminal points".
- `survivor-objectives.md` rule 5 and its AC: survivors receive a drive room or fuse spawn "only once it is discovered", and "a survivor client receives no data for an undiscovered point". The monster receives every point.
- The two ACs cannot both pass. Fix: reword the map text and AC 4 to "agree with the server once discovered". Objectives owns the rule.

⚠️ **W6. Scare Events' phase model is stale against Match Flow.**
- The States table has no Low → Emergency transition. Match Flow rule 6 and its States table allow Infiltration → Evacuation when the terminal is armed early.
- Rule 22 still says "Final 2:00" and "2:00–7:00", but Evacuation can start at any time.
- The fuse-install alarm is triggered by the install *starting* (Objectives rule 16). `ObjectiveProgressChanged` fires only on state changes, and "install started" is not one. The index row lists "install" without saying start or completion.

⚠️ **W7. A reveal or ambush flinch overlaps the lunge wind-up** (scare-events, monster-abilities, borrowed-face). This is R-W18, still open.
- Lunge requires True Form (Borrowed Face rule 11), so every attack from disguise is: transform, reveal, lunge. The reveal is a Major scare with a flinch of up to 0.3 s on survivors within 10 m (Borrowed Face rule 15, Scare Events rule 13). A lunge wind-up can start on the tick the form changes, so the flinch covers the first 0.3 s of the 0.6 s wind-up.
- The "Ambush lunge" scare is a flinch layered on the wind-up itself. That contradicts Scare Events rule 14, "Flinch never fires … while the monster is in a lunge wind-up targeting that survivor's area".
- The Monster Abilities dodge window has a margin of about 20 ms ("at 18° a strafe from 0.42 s is caught"). Movement stays possible during a flinch, but a view nudge turns a camera-relative strafe.
- Fix: no flinch on a scare that starts or overlaps a wind-up aimed near the recipient (stinger only), and define "area". Alternatively, re-run the dodge check with the flinch included.

⚠️ **W8. "Stun item" as an item-ping target has no world object.** Pings rule 5 and Survivor Defense Dependencies make stun items item-pingable. Survivor Defense rules 7 and 29 have no pickups and no world items. Say whether this means a teammate's held taser, or remove it.

⚠️ **W9. Duplicate ownership.**
- The 200 ms survivor camera impact on a hit is defined in both `monster-abilities.md` Impact Moments and `downing-and-rescue.md` Impact Moments. This is R-W14, still open.
- Scare Events lists "Transformation reveal (monster drops disguise)" and "Disguised teammate transforms" as separate entries, both triggered by `FormChanged` and both owned by Borrowed Face. As written, one form change can fire two scares.

⚠️ **W10. Downing's "the team has at least 1.5 s to reach stun range after a hit lands"** (Formulas, Monster exposure) assumes a teammate is already within 5 m. This is R-W10, still open.

⚠️ **W11. Stun and immunity state across a monster disconnect is undefined.** Match Flow rule 20 keeps cooldowns running and drops the disguise, but nothing says whether a Stunned, Immune or shock-locked monster comes back in that state. This is the second half of R-W17. The cooldown half is an open question in `match-flow.md`.

⚠️ **W12. No rule says whether a disguised monster can break a barricade.** Survivor Defense rule 27 says "the monster holds Break" with no form condition. Rule 22 explicitly allows Search "in any form". Borrowed Face rule 12 and tell T4 list search but not break. Scare Events turns a break into a Monster-source "Door burst" scare, which would leak identity while disguised (see B3).

⚠️ **W13. RoundScript door slams change gameplay state.** Scare Events rule 4 says scares never change gameplay state. Rule 7 lets RoundScript close an open door. A closed door blocks a lunge (Survivor Defense rule 24) and blocks line of sight for observation (Borrowed Face rule 2), pings (rule 6) and hit validation (Monster Abilities rule 7). A scripted slam can therefore decide a lunge, which breaks the concept's "every threat is a human decision". Fix: slams only on doors with no player within N m, or presentation only (sound and swing, with the state unchanged).

---

## Game Design Issues

### Blocking

🔴 **B4. A disguised monster can still be chain-locked for up to 16 s** (survivor-defense, borrowed-face, monster-abilities)

The B2 fix from the second re-review ("a hit during an active lock does not extend or restart it", Survivor Defense rule 14) stops *overlapping* hits from chaining. It does not stop *back-to-back* hits.
- Survivor Defense rule 10 applies the full lock to a disguised monster that is immune, "with no new immunity". There is no immunity from the lock itself.
- After a real stun (2 s, then 6 s immunity), each hit timed as the previous lock ends locks again for 2 s. Four survivors with 8 cartridges and `stun_item_reuse_s` = 1 s can lock it from 0 to 16 s with gaps of about one tick.
- The lock blocks transforming (Borrowed Face rule 7), so the monster cannot leave the disguise to reach the true-form "resisted" rule. Its form-change cooldown is usually still running from taking the disguise anyway.
- Rule 14's closing claim, "no number of shooters can chain the lock, in either form", is false. So is rule 17's "always give it a window to retreat". `lock_share` (≤ 25%) holds only in true form.
- The same mechanism lets three teammates lock one real survivor for up to 12 s. W8 from the earlier review accepted griefing on the reasoning that it is bounded at 2 cartridges per shooter.
- The concept names stun-locking as a design risk, with the mitigation "give the monster ways to disengage". As the rules stand, the disguised form is more lockable than the true form.

→ Designer decision. One option that keeps the shot from being an identity test: after any lock ends, the player (survivor or disguised monster alike) ignores new locks for `stun_immunity_s`. The presentation still plays and the charge is still spent. Then fix the rule 14 and rule 17 text and `lock_share`, and add an AC with eight sequential hits.

### Warnings

⚠️ **D1. Nothing pushes a four-survivor group to split, and a full group defeats Borrowed Face** (survivor-objectives, borrowed-face, match-flow, research-facility).
- Tell T2 (two of the same survivor) is automatic when all four survivors stand together. Lunge requires a 2 s transformation cue within 15 m. Eight cartridges and a commit within 5 m of three teammates leave the monster little against a group of four.
- The time budget does not force a split. `min_work_s` is 50 s. The map estimates "2–3 min" of walking for a *split* team, and the full perimeter loop L1 takes 42 s. A single group touring every active point plausibly finishes inside the 300 s Investigation window plus the 120 s Evacuation window. That is inference: no GDD computes a grouped route.
- The concept's Key Dynamics ("split up for speed and regroup for safety, and argue about which") depends on splitting paying off. If grouping is dominant, Pillar 1 only acts during Infiltration.
- Recommend: compute a worst-case grouped route time against `round_duration_s`. Consider at least one objective that rewards parallel work, e.g. two fuse installs that must overlap, or a shorter clock. Add a playtest AC: the share of rounds won by a group that never split.

⚠️ **D2. Monster attention load at Vertical Slice.** During Investigation the monster manages observation progress, choosing a face, the form cooldown, Lunge, False Signal, Blackout, install alerts, Search and Break, fake interactions, pings and callouts as the borrowed identity, and (optionally) its own voice. That is more than 6 active decisions. The MVP kit (observation, transform, Lunge, fake interaction, search) is within budget. Track monster-side "too much to manage" in the M5 playtest. Advisory.

---

## Cross-System Scenario Issues

Scenarios walked: 6
1. Disguised attack: approach, transform to true form, reveal, lunge on a survivor within 10 m.
2. False Signal "Need rescue" in a teammate's voice, heard by two survivors.
3. Four survivors who suspect a disguise tase it in sequence.
4. A Blackout in the active terminal room (T2, C2) at 6:58; Evacuation starts at 7:00.
5. The monster, disguised as survivor X, keeps the disguise after X escapes, then pings and attempts a transform.
6. A disguised monster breaks a Zone C barricade to reach the holdout.

### Blockers
🔴 **Scenario 2** (Monster Abilities, Pings & Callouts, Scare Events): `AbilityUsed`, then the Scare Events "Fake voice" entry, then `ScareTriggered(source = Monster)` reaches both listeners at the fake origin. A real "Need rescue" never produces that event. The fake is exposed. See B3.
🔴 **Scenario 3** (Survivor Defense, Borrowed Face, Monster Abilities): stun at 0 s, immune from 2 s. Hits at 2, 4 and 6 s each lock for 2 s. A real stun applies at 8 s, then immunity from 10 s, then locks at 10, 12 and 14 s. The monster is rooted or slowed until 16 s and cannot transform out. See B4.
🔴 **Scenario 4** (Monster Abilities, Facility Map, Scare Events): at 7:00, Facility Map ends the Blackout in C2. Scare Events keeps the overlay until 7:04, and its emergency lighting is red rather than the map's amber. Clients would get two conflicting lighting states for C2. See B2.

### Warnings
⚠️ **Scenario 1** (Borrowed Face, Scare Events, Monster Abilities): `FormChanged` triggers the reveal, which is a Major scare with a 0.3 s flinch on survivors within 10 m. A wind-up starting on the same tick puts the flinch inside the dodge window (20 ms margin). If both of Scare Events' transformation entries fire, the survivor gets two scares from one event. See W7 and W9.
⚠️ **Scenario 5** (Borrowed Face, Pings & Callouts, Match Flow, Monster Abilities): Pings rejects X-attributed pings (rule 21) and Monster Abilities rejects X fake callouts. Borrowed Face does not say whether a new transform *into* X is accepted, and the rule 13 citation does not cover Escaped. See W4. Borrowed Face also has no event source for "Escaped". See W3.
⚠️ **Scenario 6** (Survivor Defense, Borrowed Face, Scare Events): no rule says whether Break is allowed while disguised. If it is, the Monster-source "Door burst" scare reaches every survivor in range while the monster is disguised. See W12.

### Info
ℹ️ **Last survivor inside is Seized** (Match Flow rule 13, Downing rule 4): "Evidence lost" counts only Healthy or Downed survivors as inside. If the other survivors have Escaped without both drives, the round ends at the hit, not when the commit resolves. In practice no one is left to stun, so the result is the same, but a monster disconnect mid-commit would have returned the victim to Healthy. Say "Healthy, Seized or Downed" if that edge matters.
ℹ️ **Fuse box lighting** (research-facility): the Low Power state says "fuse boxes and terminal dark", but N-03 says "Active fuse boxes show a lit indicator". Clarify that the indicator is on and the box lights are off.

---

## Info (registry and reference)

- Registry: `reveal_radius_m` and `distortion_radius_m` (owned by Borrowed Face, used in Scare Events) and the `blackout_able` flag (owned by Facility Map, read by Monster Abilities) cross documents but are not registered. The `taser` entry still has `revised: 2026-10-11` earlier than `added: 2026-10-12`. Run `/consistency-check` after fixes.
- R-W6 (Lunge requires True Form, so deception gets an approach and not a payoff) is now an accepted Open Question with an M5 playtest plan in Borrowed Face. It is not re-raised here.
- Pillar alignment: every system's "Implements Pillar" maps to at least one pillar. Survivor and monster fantasies are coherent ("solvable paranoia" and "patient predator"). No anti-pillar violation was found, apart from the RoundScript door slam in W13, which edges toward a non-human threat.
- Economy: by design there is no progression. Taser cartridges are a sink with no source, intended and bounded at 8 per team. Losing survivors reduces rescuers and tasers, a mild snowball toward the monster that is typical of the genre. Short rounds offset it.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| scare-events.md | B1, B2, B3, W6, W7, W9, W13 | Consistency | Blocking |
| research-facility.md | B1 (scare anchors), B2, W5 | Consistency | Blocking |
| survivor-defense.md | B4, W2, W12 | Design Theory + Consistency | Blocking |
| monster-abilities.md | B1 ("lunge out of a hiding place"), W1 (header status), W3, W9 | Consistency | Blocking |
| borrowed-face.md | B4 (lock blocks the transform escape), W2, W3, W4, W12 | Consistency | Warning |
| pings-and-callouts.md | W4 (rule 21 citation), W8 | Consistency | Warning |
| systems-index.md | W1, W2, W3 | Consistency | Warning |
| downing-and-rescue.md | W9, W10 | Consistency | Warning |
| match-flow.md | W11 | Consistency | Warning |
| survivor-objectives.md | D1, W5 (counterpart; no edit needed if the map changes) | Design Theory | Warning |
| game-concept.md | W1 (engine) | Consistency | Info |

The systems index was not changed (headless run). If the designer agrees, mark Scare Events (still In Design), Survivor Defense and Monster Abilities as "Needs Revision".

---

## Verdict: FAIL

Four blocking issues. Three of them (B1–B3) are concentrated in Scare Events, a Vertical Slice GDD that has not had its own `/design-review` yet. B4 reopens the stun-lock risk in the approved Survivor Defense.

### Required actions before re-running

1. **B1**: define "ambush lunge" as a server test, and remove "a lunge out of a hiding place" from `monster-abilities.md` Interactions. Cut or define "Monster moving through glass", "opening a sealed room" and "trip point" in `scare-events.md`. Add a scare-anchor table to `research-facility.md`.
2. **B2** (designer decision): name one owner of per-volume lighting state. Recommended: the Facility Map, with Scare Events requesting states. Reconcile the Evacuation colours, the round-end state and the Blackout-at-Evacuation edge row across `scare-events.md`, `research-facility.md` and `monster-abilities.md`.
3. **B3** (designer decision): remove the False Signal scare entry, or make it produce nothing on survivor clients that a real callout or sound does not. Decide whether `ScareTriggered.source` and player identity stay server-side.
4. **B4** (designer decision): add a post-lock window that ignores new locks, symmetric for survivors and the disguised monster, or another rule that bounds sequential locks. Correct Survivor Defense rules 14 and 17 and `lock_share`, and add a sequential-hit AC.

Then run `/design-review design/gdd/scare-events.md`, and re-run `/review-all-gdds since-last-review`.
