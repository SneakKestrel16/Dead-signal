**GAME DESIGN DOCUMENT**

*Asymmetrical multiplayer psychological horror \| 1 Monster vs. 4
Survivors*

Version 1.0 — Prototype brief

# 1. High Concept

DEAD SIGNAL is a first-person, 5-player asymmetrical multiplayer horror
game. Four survivors enter an abandoned research facility to recover
evidence and activate an evacuation system. The fifth player controls a
shapeshifter that can imitate survivors, manipulate the environment, and
attack when the group is vulnerable. The horror comes from social
deception, sound, lighting, jumpscares, and tense objective play—not
monster AI.

Design pillars:

- Human deception: the monster is always controlled by a player.

- Fair fear: scares can surprise players but must not guarantee damage
  or remove control for long periods.

- Counterplay: survivors can hide, stun, rescue teammates, communicate,
  and escape.

- Readable objectives: players always have a clear short-term goal, even
  when they distrust one another.

- Small, shippable scope: prove one map and one complete match before
  adding content.

# 2. Product Goals and Non-Goals

## Goals

- Support exactly five players in the initial match format: one monster
  and four survivors.

- Deliver a tense round targeted at approximately nine minutes.

- Make disguise and deduction the signature mechanic.

- Include authored environmental and player-triggered jumpscares.

- Use server-authoritative rules for combat, objectives, cooldowns, and
  match results.

## Non-goals for the first prototype

- No AI-controlled monster or enemy creatures.

- No monster-killing weapons or complex combat system.

- No procedural map generation, progression economy, ranked matchmaking,
  or multiple maps.

- No requirement for voice imitation software; voice-free cues and pings
  must support the game.

# 3. Match Format and Win Conditions

Players: 1 human-controlled shapeshifter versus 4 human survivors.
First-person perspective. Initial target match duration: 9 minutes, to
be tuned in playtests.

Survivors win by recovering two data drives, restoring power with two
fuses, activating evacuation, and having at least one survivor escape
with the required evidence.

The monster wins if all survivors are eliminated or the evacuation
deadline expires. A survivor is downed on the first successful takedown
and eliminated on a second down. Teammates can rescue a downed player
with a risky six-second interaction.

Prototype flow:

1.  Lobby and role assignment.

2.  Infiltration: survivors spawn, orient themselves, and begin
    objectives; monster establishes a disguise.

3.  Investigation: survivors recover drives and fuses while the monster
    uses deception and opportunistic attacks.

4.  Evacuation: once requirements are met, survivors activate the exit
    terminal; the 15-second activation creates a final holdout.

5.  Results screen: show outcome, survival, objective progress, and
    basic match statistics.

# 4. Roles

## Survivors

Survivors are vulnerable individually but capable as a group. They
explore, complete objectives, compare observations, use hiding spots,
spend limited stun resources, barricade doors briefly, and rescue downed
teammates. Team communication should be useful but not mandatory.

## The Shapeshifter

The monster is a human player. It can copy the appearance and basic
movement presentation of a survivor it has observed. Its strength is
timing, social manipulation, and map knowledge—not permanent wallhacks
or unavoidable attacks.

# 5. Shapeshifter Ability Kit

## Borrowed Face

Transform into an observed survivor. Transformation takes 2 seconds and
creates a nearby audio distortion. Changing form has a 12-second
cooldown. Transformation cannot cancel an attack or instantly escape a
stun.

**Counterplay:** Survivors can listen for the cue, compare behavior and
location, and verify shared objective knowledge.

## False Signal

Create a fake teammate callout, footsteps, or familiar interaction sound
at a nearby location. 25-second cooldown.

**Counterplay:** Sound provides an approximate clue; survivors can
verify through sight and team communication.

## Blackout

Disable lights in a nearby room or short corridor for 6 seconds.
Emergency lights remain faintly visible. 45-second cooldown.

**Counterplay:** Flashlights, retreating to lit areas, and backup
switches offer counterplay.

## Predatory Lunge

A short forward attack with a clear wind-up and audible cue. 10-second
cooldown after the attack resolves. Missing briefly slows the monster.

**Counterplay:** Survivors can dodge sideways, slam a door, or use a
stun item.

# 6. Survivor Defense and Downing

- Stun items interrupt an attack and stagger the monster briefly; they
  do not kill it.

- Each survivor begins with a flashlight and one limited-use defensive
  item. Exact item and charge counts are to be tuned.

- Hiding spots buy time but are not permanently safe; the monster can
  investigate them.

- Some doors can be barricaded temporarily and eventually broken by the
  monster.

- A downed survivor can crawl slowly and call for help. A teammate can
  perform a risky six-second rescue.

- A second down eliminates the survivor. The monster must spend time
  committing to a down, creating an interruption opportunity.

# 7. Objectives and Round Pacing

## Required survivor objectives

6.  Recover two data drives from secured rooms. Each drive is carried by
    one player.

7.  Find and install two fuses to restore facility power. The
    interaction creates noise that alerts the monster to the general
    area.

8.  Use the recovered evidence and restored power at the evacuation
    terminal. Activation takes 15 seconds and requires the team to hold
    the area.

## Initial pacing targets

- 0:00–2:00 — Infiltration and first clues.

- 2:00–7:00 — Investigation, objectives, deception, and rising
  environmental scares.

- Final two minutes — Evacuation pressure, emergency mode, and final
  encounters.

These timings are starting hypotheses, not proven balance. Tune from
playtest data.

# 8. Jumpscare Design

Three sources of scares:

- Player-triggered: the monster reveals its true form, bursts through a
  door, or lunges from a hiding place.

- Environment-triggered: power failures, slamming doors, glass breaks,
  alarms, and unsettling recordings.

- Deception-triggered: a disguised teammate transforms, a fake voice
  calls from behind a door, or surveillance briefly shows an impossible
  image.

Rules:

- Major scripted scares are spaced apart by cooldowns; repeated triggers
  are blocked or reduced.

- Directional audio should communicate useful information rather than
  being loud for its own sake.

- Scares must not lock player control long enough to guarantee a hit.

- Provide reduced-flash and reduced-volume options.

- Networked shared scares use a replicated event; individualized
  hallucinations are sent only to the intended client.

# 9. Map: Abandoned Research Facility

Build one compact, hand-authored map with three connected zones and
multiple routes between major areas.

## Zone A — Laboratories

Small rooms, hiding cabinets, glass partitions, short sightlines, and
evidence locations. Designed for ambushes and suspicious encounters.

## Zone B — Server and Power

Central objective area with multiple entrances. No single choke point
should control all access. Tasks create noise.

## Zone C — Security and Evacuation

Limited surveillance, barricadable doors, backup controls, and the final
exit. Defensible temporarily, never permanently safe.

- Use loops and alternate routes; avoid one-way traps unless an escape
  route is nearby.

- Place hiding spots sparingly so hiding buys time but does not
  guarantee safety.

- Randomize objective locations among authored points, not by generating
  geometry at runtime.

- Use clear landmarks and readable lighting states to help players
  navigate.

# 10. Networking and Technical Rules

- Use a server-authoritative model for hit validation, stuns, cooldowns,
  objective progress, downing, rescue, and win conditions.

- Replicate player transforms, disguise state, relevant animation state,
  objective state, and scare events.

- Validate attack range, line of sight where applicable, cooldowns, and
  interaction durations on the server.

- Avoid trusting client-reported damage or objective completion.

- Synchronize shared jumpscare events across relevant clients. Scope
  individual hallucinations to the target player.

- Support voice-free play with pings and authored callouts; proximity
  voice is optional rather than a hard dependency.

- Log match duration, objective completion times, attacks, stuns, downs,
  escapes, and disconnects for balancing.

# 11. Indie Implementation Plan

## Milestone 1 — Networked greybox

One blockout map, five-player lobby, role assignment, first-person
movement, replication, reconnect/disconnect handling.

## Milestone 2 — Complete round loop

Data drives, fuses, evacuation terminal, timer, downing, rescue,
elimination, results screen.

## Milestone 3 — Core monster and counterplay

Borrowed Face, attack, stun, hiding, doors, False Signal, and Blackout
with server validation.

## Milestone 4 — Horror pass

Lighting, spatial audio, authored jumpscares, transformation reveal,
accessibility controls.

## Milestone 5 — Closed playtest

Tune values and map flow from real groups. Add another map only after
the first is fun and stable.

# 12. Playtest Metrics and Acceptance Criteria

- A complete match can start, progress, and finish reliably with five
  clients.

- All clients agree on authoritative objective state, hits, stuns,
  downs, rescues, and outcome.

- Track survivor escape rate, average match length, objective completion
  time, stun success rate, down-to-rescue rate, and monster wins without
  attacks.

- Track disconnects, latency-related attack disputes, and failed
  interactions.

- Test both roles across multiple rounds; losing must still feel
  understandable and fair.

- Tune the monster's power only after separating balance problems from
  networking bugs.

# 13. Risks and Mitigations

- **Impersonation feels arbitrary:** Use subtle but learnable clues and
  shared experiences; never make one random tell the only answer.

- **Stun-locking:** Limit charges, keep stun durations short, and ensure
  the monster has opportunities to disengage.

- **Jumpscares become annoying:** Use authored cooldowns, variation,
  audio/flash options, and no unavoidable damage.

- **Scope grows too large:** Ship one map and one monster kit first;
  postpone progression, ranked play, and additional monsters.

- **Voice chat excludes players:** Provide pings, contextual callouts,
  and voice-free deception mechanics.

- **Network exploits:** Keep combat, cooldowns, and objective authority
  on the server.

# 14. First Build Task

Do not begin with polished art or advanced jumpscares. Build a networked
greybox in which five players can join, one is assigned the monster,
four are survivors, and all players can move through the same small
facility. Then implement one objective and one round-ending condition.
Once that works reliably, add disguise and combat.

# 15. Decisions Still Open

- Engine and networking stack (choose based on developer familiarity and
  target platforms).

- Dedicated servers versus listen-server hosting.

- Exact defensive item types and starting charges.

- Whether the monster can use proximity voice, preset lines only, or
  both.

- Final tuning for round length, attack recovery, and cooldowns.

- Target platform, accessibility scope, and visual performance budget.

**END OF DESIGN DOCUMENT**
