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
