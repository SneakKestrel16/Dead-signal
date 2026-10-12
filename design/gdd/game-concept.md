# Game Concept: Dead Signal

*Created: 2026-10-11*
*Status: Draft*
*Source: `design/source/DEAD_SIGNAL_Game_Design_Document.docx` (v1.0 prototype brief) and `design/source/DEAD_SIGNAL_Build_Start_Prompt.txt`*

---

## Elevator Pitch

> It's a first-person, five-player psychological horror game where four survivors
> recover evidence and power up an evacuation system in an abandoned research
> facility, while the fifth player, a shapeshifter, walks among them wearing their
> friends' faces.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Asymmetrical multiplayer horror; social deception |
| **Platform** | PC first (to be confirmed — see Open Questions) |
| **Target Audience** | See Target Player Profile |
| **Player Count** | Exactly 5 per match: 1 monster vs. 4 survivors, all human |
| **Session Length** | ~9-minute rounds; sessions of several rounds back to back |
| **Monetization** | Not decided |
| **Estimated Scope** | Small-to-medium: one map, one monster kit, one complete round |
| **Comparable Titles** | Dead by Daylight, Among Us, Lethal Company |

---

## Core Fantasy

**Survivors:** you are four people in the dark who have to trust each other to
get out, and you can't be sure the person next to you is a person.

**Shapeshifter:** you are the thing in the facility. You don't win by being
stronger. You win by being patient, by being believed, and by choosing the
moment the group comes apart.

---

## Unique Hook

It's like Dead by Daylight, **and also** the killer can become one of your
teammates. The threat isn't only around the corner; it may be the friend
holding the flashlight. Every threat in the facility is a human decision. There
are no AI monsters, so every fake footstep, blackout and borrowed face was
chosen by a person.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Fellowship** (social connection) | 1 | Four survivors must cooperate on objectives and rescues while doubting each other |
| **Sensation** (sensory pleasure) | 2 | Lighting states, directional audio, authored jumpscares, transformation reveals |
| **Challenge** (obstacle course, mastery) | 3 | Reading disguises, timing stuns and lunges, managing the evacuation clock |
| **Fantasy** (make-believe, role-playing) | 4 | Playing the shapeshifter; surviving a horror film as a group |
| **Discovery** (exploration, secrets) | 5 | Randomized objective points among authored locations; learning the facility |
| **Narrative** (drama, story arc) | 6 | Emergent stories each round; environmental storytelling in the facility |
| **Expression** (self-expression) | N/A | Not a goal for the prototype |
| **Submission** (relaxation) | N/A | Opposite of the intended experience |

### Key Dynamics (Emergent player behaviors)

- Survivors verify each other: asking questions only a real teammate would know,
  comparing where people were, testing behaviour.
- Survivors split up for speed and regroup for safety, and argue about which.
- The shapeshifter builds trust before it betrays it: escorting, "helping" with
  objectives, then striking when a survivor is alone.
- Fake callouts and noises make survivors second-guess real ones.
- Rescues become tense bets: is it worth six seconds in the open?

### Core Mechanics (Systems we build)

1. **Borrowed Face** — the shapeshifter takes the appearance of a survivor it has observed.
2. **Deception and environment abilities** — False Signal, Blackout and Predatory Lunge.
3. **Objective round loop** — data drives, fuses, and a 15-second evacuation holdout against a clock.
4. **Downing, rescue and elimination** — two downs to eliminate, with a risky six-second rescue.
5. **Survivor counterplay** — flashlights, limited stuns, hiding spots, temporary barricades, voice-free pings.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Survivors choose routes, whom to trust and when to rescue; the shapeshifter chooses who to be and when to strike | Core |
| **Competence** | Correctly unmasking a disguise; landing a well-timed stun; a clean deception as the monster | Core |
| **Relatedness** | Group survival, shared scares and post-round stories | Core |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Socializers** — How: deduction, persuasion and cooperation are the core loop
- [x] **Killers/Competitors** — How: the shapeshifter role; outplaying the other side
- [x] **Explorers** — How: learning the facility's routes, loops and objective points
- [ ] **Achievers** — No progression in the prototype (deliberate)

### Flow State Design

- **Onboarding curve**: The first two minutes of every round are infiltration —
  low threat, orientation, first clues. First-time players learn the map then.
- **Difficulty scaling**: Comes from the other humans; no difficulty settings.
- **Feedback clarity**: Results screen shows outcome, survival, objective progress
  and basic match statistics; deaths must be understandable (pillar: Fair Fear).
- **Recovery from failure**: Rounds are short (~9 minutes); a lost round is
  quickly followed by another, possibly in the other role.

---

## Core Loop

### Moment-to-Moment (30 seconds)

Survivors move through dark rooms, listen, scan teammates for tells and work on
objective interactions that make noise. The shapeshifter watches, chooses a
face, plants a false signal, or waits for someone to be alone.

### Short-Term (5-15 minutes)

One round: infiltration (0:00–2:00), investigation (2:00–7:00), evacuation
(final two minutes). Survivors recover 2 data drives, install 2 fuses, then hold
the evacuation terminal for 15 seconds, then carry both drives out through
the exit.

### Session-Level (30-120 minutes)

Several rounds with the same group, rotating who plays the shapeshifter. Groups
learn each other's habits, which feeds back into deception.

### Long-Term Progression

None in the prototype by design. Long-term growth is player mastery of the map,
the ability kit and reading other people.

### Retention Hooks

- **Curiosity**: Randomized objective placement among authored points.
- **Social**: Playing with the same friends; taking turns as the shapeshifter.
- **Mastery**: Better reads, better disguises, better routes.

---

## Game Pillars

### Pillar 1: Human Deception

The monster is always a human player, and its signature is pretending to be one of you.

*Design test*: If we're debating an ambient AI threat to fill quiet moments vs.
giving the shapeshifter another way to create doubt, we choose the shapeshifter.

### Pillar 2: Fair Fear

Scares can surprise players but must never guarantee damage or take control away for long.

*Design test*: If a jumpscare would freeze a survivor long enough to guarantee
a hit, we shorten it or remove the lock — even if the scare is less intense.

### Pillar 3: Counterplay

Every monster tool has a survivor answer: hiding, stuns, rescues, communication and escape.

*Design test*: A new monster ability ships only with a named survivor counter.

### Pillar 4: Readable Objectives

Players always have a clear short-term goal, even when they distrust one another.

*Design test*: If deception would hide what survivors need to do next, objective state wins and stays visible.

### Pillar 5: Small, Shippable Scope

Prove one map and one complete match before adding content.

*Design test*: A second map, progression, ranked matchmaking or another monster waits until the first map and full round work.

### Anti-Pillars (What This Game Is NOT)

- **NOT an AI-monster game**: No AI-controlled monsters or creatures. It would break Pillar 1.
- **NOT a combat game**: Survivors cannot kill the monster; there are no monster-killing weapons.
- **NOT procedurally generated**: One hand-authored facility; only objective placement is randomized among authored points.
- **NOT voice-dependent**: Pings and authored callouts must carry the game; proximity voice is optional.
- **NOT a progression or ranked game (yet)**: No unlock economy, ranked play or multiple maps in the prototype.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Dead by Daylight | 1v4 asymmetric horror; objectives, downing and rescue | The killer hides among survivors instead of only hunting them | Proves the 1v4 horror format has an audience |
| Among Us | Social deduction; "who is it?" paranoia | Real-time first-person horror, not meetings and votes | Proves deduction among friends is compelling |
| Lethal Company | Proximity voice, comedy-horror moments, mimicry | Human-only threat; deception is the core loop, not a side feature | Shows voice and mimicry create memorable stories |

**Non-game inspirations**: *The Thing* (1982) — paranoia about who is still
human; abandoned research-facility horror.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 16–35 |
| **Gaming experience** | Mid-core |
| **Time availability** | Evening sessions with a friend group |
| **Platform preference** | PC |
| **Current games they play** | Dead by Daylight, Lethal Company, Among Us |
| **What they're looking for** | Horror they can share with friends where the scares come from each other |
| **What would turn them away** | Unfair deaths, mandatory voice chat, long waits in lobbies |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Not chosen yet — run `/setup-engine`. Choose by developer familiarity and target platforms. |
| **Key Technical Challenges** | Server-authoritative validation of attacks, stuns, cooldowns and objectives; replicating disguise state; synchronizing shared scares while scoping individual hallucinations to one client |
| **Art Style** | 3D first-person; greybox first |
| **Art Pipeline Complexity** | Medium; greybox until the round loop is proven |
| **Audio Needs** | Adaptive/directional — audio carries gameplay information |
| **Networking** | Client-server with server authority; dedicated vs. listen server not decided |
| **Content Volume** | 1 map with 3 zones, 1 monster kit, 1 round format |
| **Procedural Systems** | None, except randomized objective placement among authored points |

---

## Risks and Open Questions

### Design Risks

- **Impersonation feels arbitrary**: use subtle but learnable clues and shared
  experiences; never one random tell as the only answer.
- **Stun-locking**: limit charges, keep stuns short, give the monster ways to disengage.
- **Jumpscares become annoying**: cooldowns, variation, audio/flash options, no unavoidable damage.

### Technical Risks

- **Network exploits**: keep combat, cooldowns and objective authority on the server.
- **Disguise replication**: every client must render the right appearance at the right time.

### Market Risks

- Asymmetric horror depends on enough concurrent players; 5-player matches need
  a full group or reliable matchmaking.

### Scope Risks

- Growth past one map and one monster before the round is fun. Mitigation: Pillar 5.

### Open Questions

- Engine and networking stack.
- Dedicated servers vs. listen-server hosting.
- Exact defensive item types and starting charges. *Item decided 2026-10-12: a Taser; cartridge count still to tune.*
- ~~Whether the monster can use proximity voice, preset lines only, or both.~~ *Decided 2026-10-12: both.*
- Final tuning for round length, attack recovery and cooldowns.
- Target platform, accessibility scope and visual performance budget.

---

## MVP Definition

**Core hypothesis**: Five players find a ~9-minute round fun and tense when one
of them is a human shapeshifter who can disguise as survivors, and losing feels
understandable on both sides.

**Required for MVP**:

1. Networked greybox: five-player lobby, role assignment, first-person movement.
2. Complete round loop: objectives, timer, win/loss, results.
3. Downing, rescue, elimination and one stun tool.
4. Borrowed Face with correct replication.

**Explicitly NOT in MVP** (defer to later):

- Polished art and the full jumpscare set
- A second map, progression, ranked matchmaking, more monsters

### Scope Tiers

| Tier | Content | Features |
| ---- | ---- | ---- |
| **MVP** | Greybox facility | Lobby, round loop, downing/rescue, one stun, Borrowed Face |
| **Vertical Slice** | Lit facility, all three zones | Full monster kit, all survivor tools, scares, accessibility options |
| **Alpha** | Content-complete map | Telemetry, closed-playtest tuning |
| **Full Vision** | Polished release | Only after the first map is fun and stable |

---

## Next Steps

- [ ] Choose engine and networking stack (`/setup-engine`)
- [ ] Review this concept (`/design-review design/gdd/game-concept.md`)
- [ ] Review the systems index (`design/gdd/systems-index.md`)
- [ ] Review the first system GDDs, then `/review-all-gdds`
- [ ] Create architecture and network-authority ADRs (`/create-architecture`)
- [ ] Prototype the networked greybox (`/prototype`)
