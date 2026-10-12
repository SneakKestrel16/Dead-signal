# Cross-GDD Review Report

Date: 2026-10-11
GDDs Reviewed: 8 of 8 present (borrowed-face, downing-and-rescue, match-flow, monster-abilities, pings-and-callouts, scare-events, survivor-defense, survivor-objectives), plus game-concept.md, systems-index.md and design/registry/entities.yaml
Not read: none
Reviewers: game-designer ×2 — `[consistency]` (Phase 2) and `[design-theory]` (Phases 3–4). The parent session spot-verified blockers 1 and 4 against the files.

---

## Consistency Issues

### Blocking

🔴 **1. Nobody owns how a stunned disguised monster looks** `[consistency]`
`survivor-defense.md` hands this to Borrowed Face in three places: rule 11 ("what the monster's stagger looks like while disguised is owned by Borrowed Face"), the V/A row ("true-form treatment owned by Borrowed Face | Monster pain cry") and the Open Question "Does stunning a disguised monster reveal it? … Owned by Borrowed Face". `borrowed-face.md` has no such rule. Its States row says only "Stunned … Form unchanged", and its Open Questions hand the reverse question back to Survivor Defense. The pain cry also undercuts rule 11's "identical feedback" claim for shocking a real survivor. → Borrowed Face must define stun-while-disguised presentation, or Survivor Defense must take ownership.

🔴 **2. Signals sent outside the event table** `[consistency]`
`systems-index.md` says "Systems talk to each other through these server events only." These signals have no event in the table:
- borrowed-face rule 15 "asks Scare Events for a transformation reveal scare";
- scare-events Interactions says "Monster Abilities … send scare triggers";
- scare-events Cross-References cites a "Barricade break event";
- False Signal "requests a fake callout" (pings-and-callouts Interactions);
- "lunge resolved", which Downing sends to Monster Abilities, including the cancel-on-monster-disconnect path.

→ Add the events to the table, or relax the rule.

### Warnings

**Dependency direction (2a)**
- `survivor-objectives.md` says "Survivor Defense | It depends on this", but `survivor-defense.md` says "Survivor Objectives | Objectives depends on this". The two contradict each other.
- `match-flow.md` says Survivor Defense "depends on this … stops at round end". `survivor-defense.md` never lists Match Flow and has no round-end freeze rule.
- `borrowed-face.md` gives Survivor Objectives the direction "Depends on this", but Objectives says "Bidirectional".
- `downing-and-rescue.md` says Pings is "Bidirectional", but Pings says "This depends on it".
- The systems-index "Depends On" column and Dependency Map are stale against the GDD tables:
  - Borrowed Face lacks Survivor Defense, Downing and Facility Map.
  - Monster Abilities lacks Survivor Defense.
  - Downing lacks Survivor Defense.
  - Survivor Defense lacks Downing and Borrowed Face.
  - Pings lacks Downing, Objectives, Defense, Facility Map and Monster Abilities.

**Rule contradictions (2b)**
- The monster-abilities Cooldown row says the monster "may transform once any miss slow has ended". Borrowed-face rule 7's acceptance conditions have no miss-slow block.
- Three systems own lighting:
  - monster-abilities says "Round ends during Blackout | Lights state reset by Match Flow", but match-flow has no lighting rule;
  - scare-events rule 22 sets phase and Results lighting;
  - systems-index names Facility Map as the lighting consumer.
- The monster-abilities Weight profile says "survivors keep full control throughout". downing-and-rescue rule 4.2 roots the Seized victim.
- The monster-abilities hit formula `hit = survivor.state == Healthy …` omits the Seized, grace and hidden eligibility checks that its own rule 7 and downing rule 3 require.
- Objectives rule 2 says "being hit … cancels" a hold. Whether a friendly Taser shock cancels an objective hold is undefined (survivor-defense rule 11 covers only rescues).
- Pings rule 6 and its States table cover only "alive and not eliminated". There is no state for Escaped (match-flow rule 10 mutes them) or for Seized.

**Stale references (2c)**
- systems-index lists `SurvivorEscaped` consumers as "HUD, Match Telemetry", but Survivor Objectives also consumes it.
- These Open Questions are already answered:
  - survivor-defense asks whether lunge cooldown starts on a stun-cancel; monster-abilities rule 12 answers it.
  - downing asks whether the commit forces true form; this is moot because Lunge is True Form only.
  - monster-abilities asks when the Blackout cooldown starts; its own rule 21 answers it.
- game-concept's Technical table says the engine is "Not chosen yet". Godot 4.7.2 is pinned.
- The systems-index Progress Tracker counts are stale, and its "In Design" statuses disagree with GDD headers that say "Draft".

**Ownership (2d)**
- match-flow Dependencies says Borrowed Face "owns disguise restore on monster reconnect", yet match-flow rule 20 defines it.
- Extracted is defined twice: match-flow rule 10 and objectives rule 22. Both detect the exit volume.
- pings rule 29 assigns the fake-identity rule to Monster Abilities and Borrowed Face. Only Monster Abilities holds that Open Question.
- The 200 ms survivor camera impact on `SurvivorHit` is defined in both monster-abilities and downing-and-rescue.

**Formulas and acceptance criteria (2e/2f)**
- The survivor-defense `lock_share` bound ("at most 25%") and its "resisted" AC ignore rule 16, under which immunity ends early on lunge wind-up. The real bound depends on `lunge_cooldown_s`.
- downing-and-rescue says "team has at least 1.5 s to reach stun range". That ignores `stun_use_delay_s` = 0.2 s and the travel time to get within 5 m.

**Registry**
- In `entities.yaml`, the survivor `life_states` has no Escaped or Disconnected. Match-flow uses both.

---

## Game Design Issues

### Blocking

🔴 **3. Rescue camping is the dominant monster strategy** `[design-theory]`
- The rules involved are downing-and-rescue rules 3, 4, 6, 7 and 8, and monster-abilities rules 7 and 9.
- A Downed survivor cannot be targeted, but the rescuer is Healthy, rooted and a valid target.
- The 60 s bleed-out forces a rescue attempt.
- Call for Help tells the monster where the body is, from up to 40 m away.
- The rescuer's only dodge is releasing the hold during the 0.6 s wind-up. The 3 s grace protects only the rescued survivor.
- The counter is a third survivor's Taser (5 m). Survivor-defense rule 8 says the shot hits the first body in its path, so the rescuer can block it.
- Each rescue attempt risks another down, so the situation snowballs. This contradicts Counterplay and Fair Fear.
- Fix options: give the rescuer a reaction window, or pressure the camping monster (e.g. bleed-out pauses while the monster is within X m).

🔴 **4. A losing monster can rage-quit to force No Contest** `[design-theory]`
- Match-flow rule 20 gives No Contest when the monster disconnects for more than 60 s, unless the outcome is already locked (rule 14). A losing monster can turn a loss into a void.
- A deadline that passes during the grace period still counts as a monster win, so the rule only ever helps the monster.
- Fix: a monster forfeit should give a survivor win, or be decided by evidence progress.

### Warnings

- **W1. Disconnect dodges a hit.** Match-flow rule 19 covers only a disconnect while Seized. A disconnect during wind-up or dash removes the character, so the lunge misses. The survivor then reconnects Healthy.
- **W2. Observation is trivial, and disguised strikes always telegraph.** Borrowed-face rule 3 has no decay, so every face can be observed during Infiltration. Rule 11 adds a 2 s, 15 m cue before every lunge from disguise. Together these weaken the "choose the moment" fantasy. Playtest item, tied to Human Deception.
- **W3. The monster can stall Evacuation.** Objectives rule 5 shows the monster every active point. Rule 12 drops drives that never despawn. Rule 19 pauses the countdown whenever no Healthy survivor is in the zone. So the monster can guard a dropped drive or the terminal until the deadline without taking any downs.
- **W4. Attrition snowballs.** There are 8 charges per team with no refills (survivor-defense rule 7). Charges are lost on a down (rule 13), so each down also removes counterplay and compounds blocker 3. Stun-lock itself is fine: about 3% of the round.
- **W5. Monster attention budget exceeds 4 systems.** The monster tracks form, the observed list, 3 ability cooldowns plus the form cooldown, voice, pings, fake interactions, install alerts and Search. Survivors track about 5. Suggestion: one combined monster cooldown HUD.
- **W6. Infiltration may be dead time for the monster.** Whether attacks are allowed then is open (match-flow rule 7). If they are banned, the monster has about 2 minutes of trivial observing.
- **W7. Early escape removes a player from Fellowship.** Objectives rule 23 lets a survivor escape empty-handed. Match-flow rules 10 and 15 then leave them spectating with nothing to do.
- **W8. Blackout over the evacuation terminal.** Monster-abilities rule 17 leaves this open, while scare-events rule 23 requires the exit to stay readable. Close it before Vertical Slice.

---

## Cross-System Scenario Issues

Scenarios walked: 7. They were disguised lunge during rescue; Blackout in Evacuation with a Downed carrier; last two survivors with the monster stunned; disconnect mid-commit; stun during form change; timer expiry mid-rescue; pings received by the monster.

### Warnings
⚠️ **Disconnect mid-wind-up** (Match Flow, Monster Abilities, Downing): see W1.
⚠️ **Pings compound camping** (Pings & Callouts, Downing): Pings rule 7 proposes that the monster receive survivor pings. Danger pings from a Downed survivor would then guide it to blocker 3.

### Info
ℹ️ **Blackout with a Downed carrier** (Objectives, Monster Abilities): no GDD says whether the dropped-drive world marker shows during Blackout.
ℹ️ **Last two survivors, monster stunned** (Defense, Downing): the 2 s stun plus 6 s immunity covers a 6 s rescue only if the monster does not wind up, because wind-up ends immunity early. Consistent otherwise.
ℹ️ **Timer expiry mid-rescue** (Match Flow, Downing): consistent. A Downed survivor during the 45 s post-lock window is recorded "Did not escape", so their bleed-out has no effect. This is fine but undocumented.
ℹ️ **Stun during form change**: consistent across survivor-defense rule 15, borrowed-face rule 10 and monster-abilities rule 2.

---

## Pillar Summary `[design-theory]`

Counterplay is broken by blocker 3, W3 and W4. Human Deception is diluted by W2. Fellowship is strained by W7. Readable Objectives is at risk from W8. Fair Fear holds: the scare flinch cap of 0.3 s is shorter than the 0.6 s wind-up (scare-events rules 13–14).

## Referenced Systems With No GDD (informational)

Network Authority & Replication; Lobby & Role Assignment; First-Person Controller & Interaction; HUD & Results Screen; Accessibility Options (only `design/accessibility-requirements.md` exists); Match Telemetry. Facility Map exists at `design/levels/research-facility.md`, not as a GDD.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| survivor-defense.md | Stun-while-disguised ownership (1); lock_share bound | Consistency | Blocking |
| borrowed-face.md | Stun-while-disguised ownership (1); reveal-scare signal (2) | Consistency | Blocking |
| downing-and-rescue.md | Rescue camping (3); "lunge resolved" signal (2) | Design Theory | Blocking |
| match-flow.md | Monster forfeit → No Contest (4); disconnect mid-wind-up (W1) | Design Theory | Blocking |
| systems-index.md | Event-only rule vs. actual signals (2); stale Depends On columns | Consistency | Blocking |
| monster-abilities.md | Hit formula eligibility; Weight profile; lighting ownership | Consistency | Warning |
| pings-and-callouts.md | No Escaped/Seized state; fake-callout signal | Consistency | Warning |
| scare-events.md | Scare-trigger and barricade signals; lighting ownership | Consistency | Warning |
| survivor-objectives.md | Extracted double-definition; Evacuation stall (W3) | Consistency / Design | Warning |

---

## Verdict: FAIL

There are four blocking issues. Two of them (1, 2) are clean-up edits. The other two (3 rescue camping, 4 monster forfeit) need designer decisions before architecture begins.

---

## Blocker Resolutions (2026-10-11)

| Blocker | Decision | Applied in |
|---------|----------|-----------|
| 1. Stun-while-disguised ownership | A stunned disguised monster stays disguised: stagger on the borrowed body, survivor grunt, no pain cry. Borrowed Face owns it. | borrowed-face rule 10 and States; survivor-defense rule 11, V/A row, Open Questions |
| 2. Signals outside the event table | Added `AbilityUsed`, `BarricadeBroken` and `PlayerConnectionChanged`. The reveal scare reads `FormChanged`. "Lunge resolved" reads `SurvivorDowned`, `SurvivorEliminated`, `MonsterStunned` or `PlayerConnectionChanged`. | systems-index event table; borrowed-face, scare-events, pings-and-callouts, survivor-defense, downing-and-rescue |
| 3. Rescue camping | Bleed-out pauses while the shapeshifter, in any form, is within `camp_pause_radius_m` = 10 m (radius proposed). | downing-and-rescue rule 6, Formulas, Edge Cases, Tuning Knobs, Acceptance Criteria, Open Questions |
| 4. Monster rage-quit | Grace expiry is a monster forfeit: the survivors win. The No Contest outcome is removed. | match-flow rules 14, 16, 20 and 23, Edge Cases, Acceptance Criteria, Open Questions |

The flagged GDDs stay Needs Revision until each passes `/design-review`. The warnings are still open.

---

## Re-review after blocker fixes (2026-10-11, since-last-review)

GDDs reviewed: 8 of 8 present (borrowed-face, downing-and-rescue, match-flow, pings-and-callouts, scare-events, survivor-defense changed; monster-abilities, survivor-objectives as dependencies). Not read: none. `design/levels/research-facility.md` was read only where a GDD cites it. Phases 2 (consistency) and 3 (design theory) ran as parallel `game-designer` agents. They were given file paths rather than pasted content, which deviates from the skill. Phase 4 scenarios were walked by the design-theory agent.

The two design fixes were checked. The forfeit fix is sound: deadline is checked before forfeit, and the outcome lock prevents a flip. The camp-pause fix removes the bleed-out kill at the body, but it creates blocker R1 below and does not remove camping (R5).

### Prior warnings

| # | Status |
|---|--------|
| W1 Disconnect dodges a hit | Still open. Monster Abilities has no rule that consumes `PlayerConnectionChanged`, though the index lists it as a consumer. |
| W2 Observation trivial; disguised strikes telegraph | Still open. Deferred to the M5 playtest. Lunge now needs True Form, which narrows what deception can achieve (see R-W6). |
| W3 Monster stalls Evacuation | Still open. The camp pause can also keep a guarded Downed survivor alive while the deadline runs. |
| W4 Taser attrition snowballs | Partly resolved by survivor-defense rule 13 (charges persist through a down). A contested rescue now costs about 1–2 cartridges. |
| W5 Monster attention budget | Still open. |
| W6 Infiltration dead time | Still open. |
| W7 Early escape removes a player | Still open. |
| W8 Blackout over the terminal | Still open. Now part of R4. |

### Blocking

🔴 **R1. The bleed-out ring is a proximity radar for the monster** (downing-and-rescue, borrowed-face). Rule 6 pauses bleed-out while the shapeshifter, in any form, is within 10 m, measured through walls. The UI shows the ring "Per tick" to all living survivors. A frozen ring therefore reveals a disguised monster near the body, and walking a suspect past a body becomes a free identity test. This contradicts survivor-defense rule 11, whose aim is that a stun is not an identity test. The Open Question about whether the ring shows the pause is still unanswered.
- Options:
  - (a) Show only coarse states (bleeding, critical, being rescued).
  - (b) Keep the displayed timer draining while the server pauses, with an explicit rule that the displayed time is not the actual time.
  - (c) Any player within 10 m pauses bleed-out, so a pause carries no identity information.
  - (d) Pause only for a true-form monster, or only with line of sight.
  - (e) Accept the radar as a deliberate clue and record it in Borrowed Face.

🔴 **R2. A shocked survivor, a stunned disguised monster and an immune disguised monster can do different things afterwards** (survivor-defense, borrowed-face, survivor-objectives, pings-and-callouts).
- The three cases:
  - A stunned monster cannot attack, use abilities, transform, interact or use doors for 2 s (survivor-defense rule 14).
  - An immune disguised hit cancels nothing (rule 10).
  - A shocked survivor's restrictions are unspecified (rule 11): doors, interact, pings, firing its own taser, and whether the shock counts as "being hit", which cancels a hold under objectives rule 2.
- The presentation matches, but the actions differ, so "shock, then ask them to ping or open a door" is a test. This breaks survivor-defense AC line 383 and the borrowed-face stun ACs.
- Immune-hit presentation while Transforming is undefined.
- Survivor clients also receive `MonsterStunned` over the network. Pings rule 27 sets the precedent for hiding identity in packets.
- Options:
  - (a) One action lock for all three cases for `stun_duration_s`, with the shock counting as a hit for holds.
  - (b) No action lock while disguised, so the stun is presentation only.
  - (c) Accept a behavioural tell and narrow the ACs to visual and audio.
- In every option, survivor clients should receive one "shocked" event and never `MonsterStunned` or immunity data while the monster is disguised.

🔴 **R3. The index rule "events only" contradicts reads of replicated state** (systems-index, borrowed-face, monster-abilities, downing-and-rescue, survivor-objectives). Index line 25 says systems talk "through these server events only". Several GDDs read replicated state instead:
- Borrowed Face rule 8 (today's decision) and the Pings state table read the transforming flag.
- Monster Abilities rule 7 reads Downing eligibility.
- The Downing formula reads `monster_distance_m`.
- Objectives reads the hidden state.
- Options:
  - (a) Amend the rule to "events, plus read-only replicated state listed in a state table", and add the table.
  - (b) Add `TransformStarted` and other events, and revert Borrowed Face rule 8.

🔴 **R4. References to mechanics that do not exist** (monster-abilities, match-flow, research-facility, scare-events).
- The Monster Abilities edge case "Lights state reset by Match Flow" has no matching Match Flow rule. The index gives lighting to Facility Map, and scare-events rule 22 sets the lighting states.
- Monster Abilities rule 17 relies on a "blackout-able" zone flag that `research-facility.md` does not define.
- Options:
  - (a) Move the reset to Scare Events or Facility Map on `RoundPhaseChanged`, and add a per-volume `blackout_able` flag, deciding the terminal volume (W8).
  - (b) Add a Match Flow lighting rule, and treat every volume as blackout-able.

🔴 **R5. Camping moved outward, not removed** (downing-and-rescue). Downing's own Tuning row says the monster "can wait just outside and still bleed the victim out". At 10.5 m behind a wall, the rescuer is still rooted for 6 s and within lunge reach. Camping also still keeps a survivor out of play and denies a downed carrier's drives. The rule's claim that "camping gains nothing" is false beyond 10 m. Monster speed is not assessed (there is no Controller GDD).
- Options:
  - Protect the rescuer (grace, or a faster rescue while the monster is near).
  - Playtest-gate the radius with an AC (median rescue success under camping).
  - Accept, and rewrite the claim to state what camping still gains.

The design-theory agent rated R5 a warning. It is listed here as blocking because it is the original blocker 3 only partly fixed. The designer may downgrade it.

### Warnings

⚠️ **R-W1. Index dependencies are stale.**
- Missing "Depends On" entries:
  - Downing lacks Survivor Defense.
  - Survivor Defense lacks Downing and Borrowed Face.
  - Monster Abilities lacks Survivor Defense.
  - Pings lacks Downing, Objectives, Defense, Facility Map and Monster Abilities.
- The Dependency Map still lists Borrowed Face as depending only on Network Authority and Controller.
- Borrowed Face sits in the Core layer but depends on Feature-layer systems.

⚠️ **R-W2. Event table gaps.**
- Objectives consumes `SurvivorEscaped`, but it is not listed as a consumer.
- `AbilityUsed` names Monster Abilities as emitter, but monster-abilities.md never names it.
- Monster Abilities is listed as a consumer of `PlayerConnectionChanged`, but no rule uses it.

⚠️ **R-W3. Dependency directions disagree.**
- Objectives and Defense each say the other depends on it.
- Objectives says the Borrowed Face link is bidirectional; Borrowed Face says only that Objectives depends on it.
- Defense omits Match Flow.
- Pings labels its Monster Abilities dependency in contradictory directions.
- match-flow line 162 says Borrowed Face owns disguise restore on reconnect, but match-flow rule 20 defines it.

⚠️ **R-W4. The miss-slow transform gate is only in Monster Abilities.** Borrowed Face rule 7 does not list it.

⚠️ **R-W5. Stale ownership text.**
- Survivor Defense rule 15 and its Open Question about the lunge cooldown after a stun are already answered by Monster Abilities rule 12.
- Downing rule 4.3 still says "(disguise handling owned by Borrowed Face)", although Lunge is now True Form only.

⚠️ **R-W6. Lunge requires True Form, so deception gets an approach and not a payoff** (monster-abilities, borrowed-face).
- Every down needs about 2.6 s of public warning, and a taser at 5 m cancels the transform.
- In groups this may push the monster toward isolation hunting in true form.
- Add a playtest AC (share of downs preceded by a disguised approach).

⚠️ **R-W7. The Monster Abilities hit formula** (`survivor.state == Healthy`) omits rule 7's exclusions: Seized, grace and hidden survivors. Its Weight profile still says "survivors keep full control", which conflicts with the friendly-shock root.

⚠️ **R-W8. Survivor Defense text needs updating.**
- The `lock_share` example ("at most 25% of the time") contradicts rule 17's "while it disengages".
- The "resisted" AC (line 377) and edge case (line 249) ignore the disguised case, where rule 10 plays the full shock.

⚠️ **R-W9. Camp-pause qualifier missing.**
- Downing edge row line 273 and the Downed States row omit "while ≥1 Healthy".
- The registry comment on `bleedout_s` mentions only the rescue pause.
- Whether a survivor in reconnect grace counts toward `healthy_survivors` is unstated.
- The pause also lapses for 1.5 s whenever the last Healthy survivor is Seized.

⚠️ **R-W10. Downing's claim that the team has "at least 1.5 s to reach stun range"** assumes a teammate is already within 5 m. This was a prior warning and is still open.

⚠️ **R-W11. Survivor state sets differ.**
- Registry `life_states` lacks Escaped.
- The Pings States table lacks Escaped and Seized.
- The Pings Transforming exit "back to the previous form" has no entry path, because `FormChanged` is not emitted on an interrupt.
- Monster reconnect is not covered.

⚠️ **R-W12. Scare Events is stale against Match Flow.**
- The phase table fixes Emergency at "Final 2:00", but Evacuation can start early. The registry comment on `evacuation_window_s` has the same problem.
- Low exits only to Investigation.
- The "Transformation reveal" and "Disguised teammate transforms" rows duplicate each other.
- Lighting ownership is split with Facility Map.

⚠️ **R-W13. No single owner** decides whether False Signal may impersonate an Eliminated survivor. Pings rule 29 and the Monster Abilities Open Question each defer to the other.

⚠️ **R-W14. The 200 ms survivor camera impact** is defined in both Monster Abilities and Downing.

⚠️ **R-W15. Status and date mismatches.**
- The index says "In Design" while the Monster Abilities, Pings and Scare Events headers say "Draft".
- Several decisions, the Objectives approval, the index header and the registry `last_updated` are dated 2026-10-12.
- The registry taser entry has `added` later than `revised`.
- The index Progress Tracker is fixed in this session.

⚠️ **R-W16. The Seized victim shields the monster** (survivor-defense rule 8, first body hit). A shot from the victim's side shocks the victim and does not cancel the commit. This undercuts the fantasy of "the taser shot that saves a friend mid-grab". Options: shots pass through Seized and Downed survivors, the commit pair shares one hitbox, or accept it as positional skill.

⚠️ **R-W17. A monster disconnect refreshes its kit** (match-flow rule 20). Reconnecting within grace returns every cooldown, at the cost of only the disguise. Whether stun and immunity persist across a disconnect is undefined.

⚠️ **R-W18. Ambush-lunge flinch conflicts with scare rule 14.** That rule forbids a flinch during a wind-up aimed at the survivor's area, but an ambush flinch necessarily falls inside it. A flinch already running when a wind-up starts is not cancelled.

### Cross-System Scenarios

Scenarios walked: 5.
1. A disguised monster near a Downed survivor gets tased.
2. The monster disconnects mid-commit.
3. Transform, reveal, then lunge on a group of three.
4. False Signal "Need rescue" while the real survivor is Healthy.
5. Evacuation with one survivor Downed at the terminal.

- 🔴 S1 (Downing, Defense, Borrowed Face): the ring freezes at 8 m (R1). `MonsterStunned` reaches clients, and whether the stunned monster can ping is undefined (R2).
- ⚠️ S2 (Match Flow, Downing, Defense): reconnect returns full cooldowns and an undefined stun state (R-W17).
- ⚠️ S3 (Borrowed Face, Scare Events, Monster Abilities): the reveal flinch overlaps the wind-up (R-W18). Group conversion is rare (R-W6).
- ℹ️ S4 (Monster Abilities, Pings, Downing): a fake "Need rescue" is disproved at once because there is no Downed marker. It is a dead line for False Signal.
- ℹ️ S5 (Objectives, Downing, Defense): consistent. The hidden survivor C keeps the camp pause alive, and the deadline supplies the pressure (W3).

### GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| downing-and-rescue.md | R1, R5, R-W5, R-W9, R-W10 | Design + Consistency | Blocking |
| survivor-defense.md | R2, R-W5, R-W8, R-W16 | Consistency + Design | Blocking |
| monster-abilities.md | R4, R-W2, R-W4, R-W6, R-W7, R-W13, R-W14, W1 | Consistency | Blocking |
| systems-index.md | R3, R-W1, R-W2, R-W15 | Consistency | Blocking |
| borrowed-face.md | R1 and R2 consumer, R-W4 | Consistency | Warning |
| survivor-objectives.md | R2 (shock as hit), R-W3, W3, W7 | Consistency | Warning |
| match-flow.md | R-W3, R-W17, W1, W6 | Consistency | Warning |
| pings-and-callouts.md | R2 (ping while stunned), R-W11, R-W13 | Consistency | Warning |
| scare-events.md | R4, R-W12, R-W18 | Consistency | Warning |
| research-facility.md | R4 (no blackout-able flag), W8 | Consistency | Warning |

The systems index marks Downing and Survivor Defense Needs Revision. Monster Abilities, Pings and Scare Events were not yet approved.

### Re-review Verdict: FAIL

The five blockers above must be resolved before architecture begins:
- R1, R2 and R5 need designer decisions.
- R3 and R4 need an ownership or rule decision followed by clean-up edits.

### Re-review blocker resolutions (2026-10-11)

| Blocker | Decision | Edits |
|---------|----------|-------|
| R1 | Any other non-Downed player within `camp_pause_radius_m` pauses bleed-out, so a pause carries no identity information. The ring shows the pause | downing-and-rescue rule 6, rule 10, States row, formula (`nearest_player_distance_m`), edge rows, ACs, Open Questions; registry `bleedout_s` comment |
| R2 | One action lock for all three cases for `stun_duration_s`: no doors, interact, items, pings or callouts. A shock cancels holds. An immune hit does not cancel a transform. Survivor clients get one "shocked" event and never `MonsterStunned` or immunity data while the monster is disguised | survivor-defense rules 1, 10, 11, 14, formula example, edge row, ACs; downing-and-rescue rule 7; borrowed-face Interactions and AC; survivor-objectives rule 2; pings-and-callouts rule 23 and AC; systems-index `MonsterStunned` row |
| R3 | Option (a): events plus read-only replicated state listed in a state table | systems-index Server events rule and new "Read-only replicated state" table |
| R4 | Option (a): Facility Map resets lighting on `RoundEnded`; per-volume `blackout_able` flag, false only for the active terminal room during Evacuation (settles W8, proposed) | research-facility lighting volumes and Lighting States Reset row; monster-abilities rule 17, edge rows, Open Question |
| R5 | Accepted: camping just outside the radius still lets bleed-out run; a playtest AC gates the radius. Drops to a warning | downing-and-rescue rule 6, tuning row, edge row, playtest AC |

R-W8 and the R-W9 qualifier gaps were fixed alongside. Still open: R-W1 (stale Depends On columns), R-W5 (Downing rule 4.3 ownership text), the R-W9 reconnect-grace question and the other warnings. Next: `/design-review` on downing-and-rescue and survivor-defense.

---

## Second Re-review (delta), 2026-10-11

Scope: every GDD edit since `08a40ae` (the R1–R5 resolutions in `55dd311` and the approvals in `2982d6d` and `e5a533b`). `review-scope.sh` listed only downing-and-rescue and survivor-defense because this report was itself edited in `55dd311`, which hid the seven GDDs changed in the same commit. GDDs reviewed: 7 of 8 present (borrowed-face, downing-and-rescue, monster-abilities, pings-and-callouts, survivor-defense, survivor-objectives; match-flow and scare-events for interfaces only), plus systems-index and research-facility. Not read: none. Entity registry loaded.

### Blocking

**B1. Monster Abilities and Borrowed Face do not honour the shock lock.** Survivor Defense rule 14: the lock "cannot attack, use any ability, transform", and rule 10 applies it to an immune disguised monster, which emits no `MonsterStunned`. Monster Abilities rule 2 ("No ability can be activated while the shapeshifter is Stunned or Transforming") and rule 4 (Lunge: "not Stunned or Transforming") therefore accept False Signal and Blackout during an immune lock, and a Lunge if a transformation completes into true form during it. Borrowed Face rule 7 ("the shapeshifter is not Stunned") and its States table contradict Borrowed Face's own AC ("a transformation request during the following `stun_duration_s` is rejected"). Fix: add "or under the shock lock (Survivor Defense rule 14)" to Monster Abilities rules 2 and 4 and to Borrowed Face rule 7 and States table; add Monster Abilities as a reader of the lock in the systems index; add an AC in Monster Abilities.

**B2. Repeat shocks are undefined.** No GDD says whether a taser hit on a player already under the lock refreshes it or is ignored. Because immune hits now lock a disguised monster, four survivors with `stun_item_reuse_s` 1 s and 8 cartridges can chain the lock through immunity, which breaks Survivor Defense rule 17 ("always give it a window to retreat"); the lock also blocks transforming away. The `lock_share` formula's "at most 25%" assumes no lock during immunity and is false for a disguised monster. Fix (designer decision): e.g. "a hit during an active lock does not extend it", or scope `lock_share` and rule 17 to true form; add an edge-case row either way.

### Consistency warnings

- **W1. Dependency tables not updated for the new reads.** borrowed-face Dependencies still says Survivor Defense "This depends on it" (Survivor Defense now says Bidirectional; it reads disguised form and Transforming). systems-index row 7 lists only Controller & Interaction and Monster Abilities; Survivor Defense now reads Borrowed Face and Downing (Seized/Downed, rule 8). downing-and-rescue's Survivor Defense row says it "reads Committing and Downed states" without Seized. pings-and-callouts (rule 23 lock), survivor-objectives (rule 2 shock) and downing-and-rescue (rule 7 shock interrupt) do not list the new Survivor Defense reads in their Dependencies.
- **W2. The read-only state table is incomplete.** "Shock/stun lock" readers omit Downing (rule 7), Monster Abilities (B1) and First-Person Controller & Interaction (root, slow, doors). "Takedown eligibility" omits Survivor Defense (rules 8 and 13). The disguised form Survivor Defense reads (rules 1 and 10) is not in the table, and `FormChanged` does not list Survivor Defense. `blackout_able` (Monster Abilities rule 17) is absent though it flips when Evacuation starts; add it as Facility Map state, or say Monster Abilities derives it from map data plus `RoundPhaseChanged`.
- **W3. The "shocked" event has no name or row.** Survivor Defense rule 1 sends survivor clients a "shocked" event; the index requires exact event names. Add a row (e.g. `PlayerShocked`, emitted by Survivor Defense, consumed by all clients for presentation).
- **W4. Escaped is invisible to Downing.** Downing rule 6 and `healthy_survivors` exclude Escaped players, but `SurvivorEscaped` lists only HUD and Match Telemetry as consumers, and the life-state row lists Healthy, Seized, Downed, Eliminated. Add Downing as a consumer or Escaped to the row.

### Design warnings

- **W5. Bleed-out only punishes abandoned bodies.** Downing rule 6 freezes bleed-out while any non-Downed player is within 10 m, through walls, hidden survivors included. Downs cluster at objectives, a Downed survivor can crawl (0.25×) to within 10 m of a teammate, and anyone holding the evacuation terminal keeps nearby Downed survivors alive, so rescue can be deferred until the objective is done. The 60 s clock's "rescue now or hold the objective" choice survives only for isolated downs, eroding the downing fantasy ("saving a friend… is the bravest thing you do"). Options: a nearby player slows bleed-out (e.g. ×0.25) instead of freezing it (still identity-neutral); a pause budget per down; exclude hidden survivors; or accept with a playtest AC measuring rescues deferred past objective completion.
- **W6. The freeze widens the payoff gap toward isolated, true-form hunts.** A down beside the group no longer bleeds; an isolated down does. This stacks on R-W6 (Lunge requires True Form) and pulls the monster's best play away from Human Deception. Options: resolve with W5, or add to the R-W6 M5 playtest AC (downs preceded by a disguised approach, isolated vs grouped).
- **W7. A friendly shock at a rescue removes both counters R5 relied on.** Survivor Defense rule 11 roots the rescuer and locks their taser; rule 8 hits the first body in the path with `stun_aim_tolerance_deg` 10° (about 0.9 m at 5 m). A defender firing past a rescuer can clip them, and the monster can set that up. R5 was accepted because "the rescuer can release and dodge a lunge and teammates can tase". Options: the aim cone prefers the monster when it is inside it, with the exact ray deciding between survivors; a Healthy survivor holding a rescue is pass-through; or accept with a playtest AC counting friendly shocks at rescues.
- **W8. Deliberate friendly fire is an untraceable grief tool.** A shock cancels an objective hold (Survivor Defense rule 11) and cancelled holds reset (Survivor Objectives rule 3); feedback is identical for teammate and monster. Bounded at 2 per player. Options: show friendly shocks per player on the results screen only; a shock pauses a hold with decay instead of resetting it; or accept under the charge cap. Tasering a suspected disguise is correctly dominated (no information; Objectives rule 26's progress bar is the better test).

### Cross-system scenario issues

Scenarios walked: friendly misfire on a rescuer during a contested rescue; immune hit on a disguised monster mid-transformation; Blackout active in the terminal room when Evacuation starts; hidden teammate near a Downed survivor.

- **S1 (Warning). Monster view of the ring is a hider radar.** If the monster sees the bleed-out ring, a pause while it is more than 10 m away tells it a survivor, possibly hidden, is within 10 m. Downing's open question "Proposed: the monster does not see the timer" now carries this, and the AC "The bleed-out ring looks identical … on every client" presumes an answer. Settle it.
- **S2 (Info).** A Blackout already active in the active terminal room when Evacuation starts: no GDD says whether it ends (at most 6 s). research-facility `blackout_able` paragraph.
- **S3 (Info).** Scare Events ducks audio on `MonsterStunned` (interface row, rule 18); survivor clients no longer receive it while the monster is disguised. Trigger on the shocked event.
- **S4 (Info).** A Healthy survivor disconnected inside reconnect grace is not counted in `healthy_survivors`, so the camp pause lapses for every Downed teammate. No edge-case row.
- **S5 (Info, registry).** `camp_pause_radius_m` has no entry and the `bleedout_s` comment hardcodes "10 m"; `stun_duration_s` `referenced_by` lacks pings-and-callouts.

### GDDs flagged for revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| monster-abilities.md | B1 | Consistency | Blocking |
| borrowed-face.md | B1, W1 | Consistency | Blocking |
| survivor-defense.md | B2, W7, W8 | Consistency + Design | Blocking |
| systems-index.md | W1, W2, W3, W4 | Consistency | Warning |
| downing-and-rescue.md | W1, W5, W6, S1, S4 | Design + Consistency | Warning |
| pings-and-callouts.md | W1 | Consistency | Warning |
| survivor-objectives.md | W1 | Consistency | Warning |
| scare-events.md | S3 | Consistency | Info |
| research-facility.md | S2 | Consistency | Info |

The systems index now marks Survivor Objectives, Downing, Survivor Defense, Borrowed Face, Monster Abilities and Pings & Callouts Needs Revision (designer approval, 2026-10-11).

### Second Re-review Verdict: FAIL

B1 is a mechanical edit. B2 needs a designer decision on repeat shocks; W5–W8 and S1 need designer decisions before Milestone 2.
