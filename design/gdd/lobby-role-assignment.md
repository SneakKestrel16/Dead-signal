# Lobby & Role Assignment

> **Status**: Approved
> **Creative Director Review (CD-GDD-ALIGN)**: skipped — Lean mode
> **Author**: SneakKestrel16 + agents
> **Last Updated**: 2026-10-12
> **Last Verified**: 2026-10-12
> **Implements Pillar**: Human Deception; Small, Shippable Scope

## Summary

Lobby & Role Assignment brings 4–6 players together by direct join and starts a round once everyone is Ready. Each round it picks one shapeshifter from a per-session rotation queue and gives each survivor one of five distinct characters, then hands Match Flow the locked roster and takes the players back after Results. It exists so turns at the monster are fair and teammate identities are stable enough for Borrowed Face to steal.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Network Authority & Replication, Match Flow & Win Conditions`

## Overview

Lobby & Role Assignment is the session layer between "a group of friends wants to play" and Match Flow's Loading state. One player hosts and the others join by direct address (IP and port). The lobby holds 4 to 6 players (`min_players` to `max_players`), owns the session-wide settings (proximity voice, Off by default), and starts a round only when at least four are connected and all are ready. Every round has one shapeshifter and 3 to 5 survivors. At the start of each round the server assigns roles. The shapeshifter comes from a rotation queue whose random order is fixed at the session's first round, so with N players each is the shapeshifter once every N rounds. Each survivor gets one of five survivor characters, distinct within the round, each with its own look, colour and voice set. A player keeps the character they picked in the lobby, and a clash is settled at random. The server then hands Match Flow the locked roster with fixed roles and characters, and takes them back on Results or Cancelled. Players feel the system as fair turns at the monster and stable teammate identities, the identities Borrowed Face exists to steal.

## Detailed Design

### Core Rules

A round always has exactly one shapeshifter and `player_count` − 1 survivors, with `player_count` between `min_players` = 4 and `max_players` = 6 (designer decision, 2026-10-12: plan for 1 monster vs 3 survivors and up to 6 players). The approved GDDs are tuned for 4 survivors. **MVP runs 5 players only**: the code handles 4–6, but the MVP config sets `min_players` = `max_players` = 5, so only the tuned 1 vs 4 round is played and playtested; 4 and 6 are unlocked at Milestone 5 after balance work (designer decision, 2026-10-12, gate check, producer recommendation). The fifth survivor character C5 is still budgeted.

**Session and joining**
1. One player hosts a lobby on a configurable port, and the others join by address and port (designer decision, 2026-10-12: direct join for MVP; no matchmaking, Pillar 5). With a listen server the host's process is the server. Whether a dedicated server is also supported belongs to the Network Authority ADR.
2. The server validates every join and rejects it with a reason if the lobby already has `max_players` players, a round is in progress (only Match Flow reconnects within `reconnect_grace_s` are accepted, `match-flow.md` rules 19–20), or the game version string differs from the host's (exact match).
3. Each player brings a display name of 1–16 characters; the server rejects a join with any other length. Names are compared case-insensitively, and the server makes them unique by appending the lowest free suffix " (2)", " (3)" and so on, skipping any suffixed name a player already holds; the suffix may take a name past 16 characters.
4. A lobby with fewer than `min_players` waits. No bot or AI ever fills a seat (anti-pillar: no AI monsters, and no AI survivors either).

**Survivor characters**
5. There are five survivor characters, C1–C5, one for each seat of the largest survivor team. Each has its own look, colour and voice set (one voice set per character). The shapeshifter's true form is a separate model, not one of the five.
6. Each player keeps a preferred character in the lobby, which defaults to a random one (designer decision, 2026-10-12: lobby pick, kept between rounds). Preferences can overlap.
7. At round start, every survivor whose preference no other survivor shares gets their pick. Where several survivors share a preference, the server keeps it for one at random and deals the leftover characters to the others at random. Survivors (at most 5) never outnumber characters (5), so the survivor team always ends up with distinct characters, fixed for the round.

**Roles**
8. Before the session's first round, the server shuffles all connected players into a rotation queue (designer decision, 2026-10-12: rotation). The head of the queue is the shapeshifter; everyone else is a survivor. Clients cannot request a role.
9. After a round that reaches Ended (any outcome, including a forfeit), the head moves to the back. A Cancelled round does not advance the queue.
10. The queue holds a per-session player token for everyone who has joined the session, not peer IDs, so a reconnect keeps its place. A player who leaves keeps their position; absent players are skipped when the shapeshifter is picked. A player who rejoins gets their old position back, so a skipped turn is owed and comes first (designer decision, 2026-10-12: no dodging the monster turn by leaving and rejoining). A first-time joiner goes to the back. With a stable roster of N players, each player is the shapeshifter once every N rounds.
11. Roles are public (designer decision, 2026-10-12). The lobby shows the queue order and the next shapeshifter. The monster player can be deduced at spawn anyway; deception is about which body is real, not which player is the monster. Rounds therefore show no name tags or role indicators on bodies: players identify each other only by character look and colour, which Borrowed Face copies (designer decision, 2026-10-12, design review). Pings and callouts carry the displayed identity (Pings & Callouts rule 8), and proximity voice is the player's real voice, which Pings & Callouts rule 25 already accepts.

**Start**
12. Each player toggles Ready. A Ready player cannot change their character preference.
13. When at least `min_players` are connected and every connected player is Ready, a `lobby_countdown_s` = 5 countdown runs. It is cancelled if anyone un-readies, leaves or joins (designer decision, 2026-10-12: all-ready countdown, no host Start button).
14. When the countdown reaches 0, the server locks the roster, assigns roles (rule 8) and characters (rule 7), and hands Match Flow the roster: session ID, round index, `player_count`, and for each player the peer ID, display name, role and (survivors only) character. Match Flow's Loading state begins.
15. The player count is fixed for the round. A join during a round is rejected (rule 2), and the next round uses whoever is in the lobby then.

**Settings**
16. Proximity voice (Off by default, `pings-and-callouts.md` rule 18) can be changed by the host only, in the lobby and outside the countdown (designer decision, 2026-10-12). It applies to every player.

**Return and teardown**
17. After Results or Cancelled, every connected player returns to the lobby. Ready flags reset; preferences and the queue persist. A player whose reconnect grace expired is not in the lobby, but keeps their queue position (rule 10), as does any player who leaves the lobby.
18. A non-host player who disconnects in the lobby is removed at once; there is no lobby grace.
19. If the host leaves, in any state including mid-round, the session closes for everyone with "Host left". A round in progress gets no result. There is no host migration (designer decision, 2026-10-12; Pillar 5).
20. In Waiting, the host can kick any other player, so one player who never readies cannot stall the lobby (designer decision, 2026-10-12, design review). A kicked player is removed like a leaver, keeps their queue position (rule 10), and may rejoin.

### States and Transitions

| State | Entry | Exit | Behaviour |
|-------|-------|------|-----------|
| Waiting | Host creates lobby; return from match; countdown cancelled | ≥ `min_players` connected and all Ready → Countdown; host leaves → Closed | Join, leave, pick, ready, settings |
| Countdown | Rule 13 met | Reaches 0 → In Match; cancel trigger → Waiting; host leaves → Closed | Picks and settings locked |
| In Match | Roster handed to Match Flow (rule 14) | Results ended or Cancelled → Waiting; host leaves → Closed | Lobby dormant; Match Flow owns play; only reconnects accepted |
| Closed | Host leaves | — | All clients return to the main menu with the reason |

### Interactions with Other Systems

| System | Data in | Data out | Responsibility |
|--------|---------|----------|----------------|
| Network Authority & Replication | Peer connect/disconnect, peer IDs, build version | Join accept/reject | ADR owns the transport; Lobby owns rules 2, 18, 19 |
| Match Flow & Win Conditions | Return signal tagged Ended or Cancelled | Locked roster (rule 14) | Lobby assigns roles; Match Flow never does. Match Flow rule 24's "shapeshifter name revealed" is redundant now that roles are public |
| Borrowed Face | — | Each survivor's character (a disguise copies the target's character) | Lobby owns character assignment |
| Pings & Callouts | — | Voice set per character; proximity voice setting | Lobby owns the setting |
| Facility Map | — | — (Match Flow spawns survivors at S1–S4; S5 needed for 5 survivors) | Map owns spawn points |
| HUD & Results Screen | — | Lobby screen data (players, queue, picks, ready, countdown) | HUD presents |
| Match Telemetry | — | Session ID, round index, player count, roles, characters | — |

**Proposed read-only state** for the systems index: **Player roster** (`player_count`; per player display name, role, character), owned by Lobby & Role Assignment, read by every system and client, fixed for the round.

## Formulas

`systems-designer` consulted (lean mode, Formulas section).

### Roster size

The roster_size formula is defined as:

`survivor_count = player_count - 1`, valid only if `min_players <= player_count <= max_players`

**Variables:**

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| player_count | int | 4–6 | calculated: connected players when the countdown ends (rule 14) | Players in the round, fixed for the round |
| min_players / max_players | int | 4 / 6 | data file (lobby config) | Start and join limits |
| survivor_count | int | 3–5 | calculated | Survivors in the round; never more than the 5 characters |

**Output Range:** 3 to 5. There is always exactly 1 shapeshifter.
**Example:** 6 connected gives 5 survivors; 4 connected gives 3.

### Rotation queue

The shapeshifter formula is defined as:

`shapeshifter(r) = first t in Q_r where present(t)`; after a round that reaches Ended, `Q_{r+1} = (Q_r without shapeshifter(r)) + [shapeshifter(r)] + new_tokens`. For a stable roster, `shapeshifter(r) = Q_1[(r - 1) mod N]`.

**Variables:**

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| Q_r | ordered list of player tokens | length ≥ 4 | calculated (server) | Queue at the start of round r. `Q_1` is a uniform random shuffle (rule 8). Absent players keep their position (rule 10) |
| present(t) | bool | — | server | Token t is connected and in the lobby |
| r | int | ≥ 1 | server | Index of rounds that reached Ended. A Cancelled round does not advance it (rule 9) |
| N | int | 4–6 | calculated | Present players in a stable roster |
| new_tokens | list of player tokens | 0–2 | join order | First-time joiners, appended at the back |

**Output Range:** exactly one shapeshifter per round. With a stable roster each player gets one turn per N rounds, so the monster share is 1/N (25% at 4 players, about 16.7% at 6).
**Example:** `Q_1 = [A,B,C,D,E]`, so A is the shapeshifter in round 1, and the queue becomes `[B,C,D,E,A]`. B leaves before round 2, so C is the shapeshifter in round 2 and the queue becomes `[B,D,E,A,C]`. B rejoins before round 3, is at the front, and is the shapeshifter in round 3.

### Character assignment

The character_assignment formula is defined as:

`W` = one uniformly random survivor from each group of survivors sharing a preference; `L` = survivors not in `W`; `free = {C1..C5} - {pref(w) : w in W}`; each survivor in `L` is dealt a distinct character from `free` by a uniform random permutation.

**Variables:**

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| pref(p) | enum C1–C5 | 5 values | lobby pick, default random (rule 6) | Preferred character. Only survivors' preferences count |
| k | int | 1–5 | calculated | Survivors sharing one preference; each keeps it with probability 1/k |
| abs(W) | int | 1–survivor_count | calculated | Distinct preferences among survivors |
| abs(L) | int | 0–4 | calculated | `survivor_count - abs(W)`, survivors who lost a clash |
| abs(free) | int | 0–4 | calculated | `5 - abs(W)`, characters nobody kept |

**Output Range:** `abs(free) - abs(L) = 5 - survivor_count >= 0`, so every survivor always gets a distinct character. Slack is 0 at 5 survivors and 2 at 3 survivors.
**Example:** 5 survivors prefer C1, C1, C2, C4, C4. W keeps one C1, the C2 and one C4. The two clash losers are dealt C3 and C5 in random order, so all five are distinct.

### Lobby countdown

The lobby_countdown formula is defined as:

`starts when connected >= min_players AND ready_count == connected`; `remaining(t) = max(0, lobby_countdown_s - (t - t_start))`. The roster locks when `remaining == 0`, and any cancel trigger (rule 13) resets `t_start`.

**Variables:**

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| connected / ready_count | int | 0–6 | server | Connected players and players with Ready set |
| t, t_start | float (s) | ≥ 0 | server clock | Clients display the value; they never decide |
| lobby_countdown_s | float (s) | 5 (safe 3–10) | data file (lobby config) | Time to un-ready before the lock. Provisional, not playtested |

**Output Range:** `remaining` is clamped to 0–5 s.
**Example:** all 5 players Ready at t = 100.0 s gives remaining = 1.8 s at t = 103.2 s; the roster locks at t = 105.0 s.

## Edge Cases

| Situation | Resolution |
|-----------|------------|
| The shapeshifter's reconnect grace expires mid-round | Match Flow rule 20 makes it a forfeit and the round reaches Ended, so the turn counts and their token moves to the back. If they rejoin later they keep that position. |
| A survivor's grace expires mid-round | They are not in the lobby afterwards (rule 17), but their token keeps its queue position (rule 10). |
| A round is Cancelled (load timeout) | The queue does not advance and the same player is the shapeshifter next round. Characters are redrawn. |
| Fewer than `min_players` remain between rounds | The lobby waits in Waiting; no bot fills a seat (rule 4). |
| A 7th player tries to join, or anyone joins during In Match (including Results) | Rejected with the reason "Lobby full" or "Round in progress, try again shortly". Only a Match Flow reconnect is accepted (rule 2). |
| The host is the shapeshifter and leaves mid-round | Rule 19: the session closes and no result is recorded. There is no forfeit because no server remains. |
| A client loses its session token (game restarted) and rejoins | Treated as a first-time joiner and goes to the back, so a determined player can still dodge their turn. Accepted for MVP; a platform account ID (e.g. Steam) closes the gap later. |
| Every survivor prefers the same character | One keeps it at random; the rest are dealt free characters (Character assignment formula). |
| One player keeps losing character clashes | Losses are not remembered. Accepted, because the effect is cosmetic. |
| The shapeshifter's own character preference | Ignored that round and kept for later rounds. |
| Someone disconnects in the same server tick the countdown reaches 0 | At lock the server checks rule 13 again. If it no longer holds, the countdown is cancelled and the lobby returns to Waiting. |
| Tokens of players who left accumulate in the queue | Accepted: a session sees a handful of players, so the queue stays small. Absent tokens are skipped (rule 10). |
| A player never readies | The host kicks them (rule 20). |
| Two players use the same display name | The server appends " (2)" (rule 3). |
| A client's game build differs from the host's | Join rejected with both version strings shown. |

## Dependencies

| System | Direction | Nature | Status | Interface |
|--------|-----------|--------|--------|-----------|
| Network Authority & Replication | Upstream | Hard | No ADR yet: interface **provisional** | Peer connect/disconnect, peer IDs, build version, transport (direct ENet for MVP) |
| Match Flow & Win Conditions | Downstream | Hard | Approved, updated 2026-10-12 (d373070) | Takes the locked roster (`player_count`, roles, characters); returns players tagged Ended or Cancelled. Its rule 1 now takes 4–6 |
| Borrowed Face | Downstream | Hard | Approved | Reads each survivor's character; a disguise copies the target's character |
| Pings & Callouts | Downstream | Hard | Approved, updated 2026-10-12 (d373070) | One voice set per character (C1–C5) settles its voice-set open question; proximity voice setting |
| Facility Map | Downstream | Soft | Approved, updated 2026-10-12 (d373070) | Survivor spawns S1–S5 (S5 for 5-survivor rounds) |
| HUD & Results Screen | Downstream | Hard | Not started | Lobby screen data |
| Match Telemetry | Downstream | Soft | Not started | Session ID, round index, player count, roles, characters |

Bidirectional entries in Match Flow, Borrowed Face, Pings & Callouts, Facility Map and the systems index are pending propagation (Open Questions).

## Tuning Knobs

| Knob | Default | Safe range | Affects | Owner |
|------|---------|------------|---------|-------|
| `min_players` | 4 (MVP config: 5) | 4–5 | Smallest round (3 survivors). Raising it to 5 drops 3-survivor rounds | This GDD |
| `max_players` | 6 (MVP config: 5) | 5–6 | Largest round (5 survivors). Above 6 needs a sixth character and spawn | This GDD |
| `lobby_countdown_s` | 5 s | 3–10 s | Time to back out before the roster locks | This GDD |
| Display name length | 1–16 | — | UI fit of names in lists and feed | This GDD |
| `reconnect_grace_s` | 60 s | — | How long a dropped player keeps their round seat | `match-flow.md` |

## Visual/Audio Requirements

The lobby is a menu with no horror presentation. Each player sees a preview of their preferred character in its colour. The countdown ticks once per second. Character look, colour and voice set are owned by the art bible and audio direction, not this GDD.

## Game Feel

Getting back into a round must be fast: the concept's target players are turned away by "long waits in lobbies" (`game-concept.md`, Target Player Profile). From the last Ready to Match Flow Loading takes `lobby_countdown_s` (5 s). Results return straight to the lobby with preferences and the queue kept, so a repeat round costs one Ready click per player.

## UI Requirements

Lobby screen, to be specified with `/ux-design`:

- Host/join form: address, port, display name
- Player list: name, Ready, preferred character
- Rotation queue order, with the next shapeshifter highlighted (rule 11)
- C1–C5 character picker, locked while Ready (rule 12)
- Proximity voice toggle: the host can change it, others can only see it (rule 16)
- Countdown
- Reject and close reasons (rules 2, 3, 19)

## Cross-References

- `design/gdd/match-flow.md`: rules 1, 2, 19–21, 24, 27 (roster in, return out, disconnect grace, results)
- `design/gdd/pings-and-callouts.md`: rules 10, 18, 21 and the voice-set Open Question (one voice set per character, settled here)
- `design/gdd/borrowed-face.md`: "What the disguise copies" (body, outfit, colour identity are the target's character)
- `design/levels/research-facility.md`: Spawn Points (S1–S4)
- `design/gdd/game-concept.md`: Session-Level loop (rotating who plays the shapeshifter)

## Acceptance Criteria

`qa-lead` consulted (lean mode, Acceptance Criteria section).

- [ ] **AC-LB-01** [unit] Given rosters of 4, 5 and 6 players, when the roster is built, then it has exactly 1 shapeshifter and `player_count` − 1 survivors (3, 4, 5). Given 3 or 7 players, the roster is refused.
- [ ] **AC-LB-02** [integration/playtest] Given a host lobby on a configured non-default port, when a client joins by address and port, then every peer sees that client in the lobby list.
- [ ] **AC-LB-03** [unit] Given an injected lobby state, when a join is validated, then it is rejected with "Lobby full" at 6 players, with "Round in progress, try again shortly" during In Match (including Results), and with both version strings shown when the version differs. A Match Flow reconnect with a valid token inside `reconnect_grace_s` is accepted during In Match.
- [ ] **AC-LB-04** [unit] Given three joins named "Ann", when they are registered, then they appear as "Ann", "Ann (2)" and "Ann (3)". A name of 0 or 17 characters is rejected.
- [ ] **AC-LB-05** [unit] Given 3 connected players who are all Ready, when the lobby ticks, then it stays in Waiting, no countdown starts, and the roster holds only the 3 human tokens (no bot or AI seat).
- [ ] **AC-LB-06** [unit] Given the character data file, when it is loaded, then it defines exactly 5 survivor characters C1–C5, each with a distinct look, colour and voice-set ID. The shapeshifter's true-form model is none of the five.
- [ ] **AC-LB-07** [unit] Given a new player and a seeded RNG, when they join, then their preference is one of C1–C5 chosen from the RNG. That preference is unchanged after 3 rounds.
- [ ] **AC-LB-08** [unit] Given survivors whose preferences are all distinct, when characters are assigned, then every survivor gets their pick.
- [ ] **AC-LB-09** [unit] Given survivor preferences C1, C1, C2, C4, C4 and a fixed seed, when characters are assigned, then the C2 survivor keeps C2, one C1 claimant keeps C1, one C4 claimant keeps C4, and the two losers get {C3, C5}. All five characters are distinct.
- [ ] **AC-LB-10** [unit] Given 1,000 seeded random preference sets at each of 3, 4 and 5 survivors (including "all prefer C1"), when characters are assigned, then every result is distinct, a sole claimant always keeps their pick, and every survivor holds exactly one character.
- [ ] **AC-LB-11** [unit] Given k = 2, 3 and 5 survivors sharing one preference over 10,000 fixed-seed trials, when characters are assigned, then each claimant keeps the shared character in 1/k ± 0.02 of trials, and, over the trials in which a given survivor loses the clash, each free character is dealt to them in 1/|free| ± 0.02 of those trials (±0.02 is over 4σ at these trial counts).
- [ ] **AC-LB-12** [unit] Given a shapeshifter whose preference is C3, when characters are assigned, then the shapeshifter has no character and a survivor may receive C3. The shapeshifter's preference is still C3 next round.
- [ ] **AC-LB-13** [unit] Given N connected tokens and a seeded RNG before the session's first round, when the queue is built, then Q_1 holds each token exactly once, its order is reproducible from the seed, and its head is the shapeshifter.
- [ ] **AC-LB-14** [integration/playtest] Given a client that sends a role request RPC, when the server receives it, then the request is ignored and the assigned roles are unchanged.
- [ ] **AC-LB-15** [unit] Given a stable roster of N = 4, 5 and 6, when 2N rounds reach Ended (including a round ended by forfeit), then `shapeshifter(r) = Q_1[(r − 1) mod N]` and every token is the shapeshifter exactly twice.
- [ ] **AC-LB-16** [unit] Given a round that is Cancelled, when the next round starts, then the queue is unchanged, the same token is the shapeshifter, and character assignment runs again.
- [ ] **AC-LB-17** [unit] Given Q_1 = [A, B, C, D, E], A in round 1, then B absent for round 2 and present again for round 3, when the rounds resolve, then C is the shapeshifter in round 2 with the queue becoming [B, D, E, A, C], and B is the shapeshifter in round 3.
- [ ] **AC-LB-18** [unit] Given a player who reconnects with the same session token under a new peer ID, then their queue position is unchanged. Given a player who rejoins with a new token (lost token), or joins for the first time after round 1, then they are appended at the back of the queue.
- [ ] **AC-LB-19** [integration/playtest] Given a lobby with an absent token at the queue head, when the lobby screen is shown, then every client displays the server's queue order and names the first present token as the next shapeshifter. A screenshot is retained in `production/qa/evidence/`.
- [ ] **AC-LB-20** [unit] Given a Ready player, when they change their preference, then the change is rejected. After they un-ready, the change is accepted.
- [ ] **AC-LB-21** [unit] Given an injected clock with 5 players all Ready at t = 100.0, when time advances, then remaining = 1.8 at t = 103.2, the roster locks at t = 105.0, and remaining stays within [0, 5] throughout. The countdown does not start while `ready_count < connected`.
- [ ] **AC-LB-22** [unit] Given a running countdown, when a player un-readies, leaves or joins, then each trigger alone returns the lobby to Waiting. When all players are Ready again, the countdown restarts at the full `lobby_countdown_s`.
- [ ] **AC-LB-23** [unit] Given a disconnect processed in the same tick that remaining reaches 0, when the server locks, then it re-checks rule 13, returns to Waiting, and hands no roster to Match Flow.
- [ ] **AC-LB-24** [integration/playtest] Given a countdown that reaches 0, when Match Flow receives the roster, then it has `player_count` and, for each player, the peer ID, display name and role. Survivors also have a character and the shapeshifter has none. Loading begins on every peer, and `player_count` does not change for the rest of the round.
- [ ] **AC-LB-25** [unit] Given a new session, then proximity voice is Off. A change from a non-host is rejected, a change from the host during Countdown or In Match is rejected, and a change from the host in Waiting is accepted.
- [ ] **AC-LB-26** [integration/playtest] Given a host who toggles proximity voice in Waiting, when the change is applied, then every client reports the new value.
- [ ] **AC-LB-27** [integration/playtest] Given a round that ends in Results, and separately one that is Cancelled, when it ends, then every connected peer is back in Waiting with Ready cleared and with preferences and queue unchanged. A survivor whose grace expired mid-round is absent from the lobby, but their token keeps its queue position.
- [ ] **AC-LB-28** [integration/playtest] Given a non-host peer that disconnects in Waiting or Countdown, when the server sees the disconnect, then that player is removed from the lobby on the same tick, with no grace period.
- [ ] **AC-LB-29** [integration/playtest] Given the host leaves in Waiting, in Countdown and in In Match (including while the host is the shapeshifter), then every client returns to the main menu with "Host left", and no round result or forfeit is recorded.
- [ ] **AC-LB-30** [unit] Given a lobby in Waiting, when the host kicks a player, then that player is removed, their queue position is kept, and they can rejoin. A kick from a non-host, or by the host outside Waiting, is rejected.
- [ ] **AC-LB-31** [integration/playtest] Given a running round, when any player looks at another body, then no name tag or role indicator is shown; only character look and colour identify it. A screenshot is retained in `production/qa/evidence/`.

Not covered by a criterion: rule 1's dedicated-server support (Network Authority ADR); rule 11's "deduced at spawn" and the Overview's "fair turns" are experience claims for playtest.

## Open Questions

| Question | Owner | Target | Resolution |
|----------|-------|--------|------------|
| Update the approved docs for 4–6 players. `match-flow.md`: rules 1 and 2 ("all 5 clients"), Overview, Loading state, dependency rows, the load-timeout AC, rule 24's now-redundant name reveal, and a new rule for "host left, no result" (Lobby rule 19). Registry: mark `players_per_match` superseded by `min_players`/`max_players`. `research-facility.md`: prerequisite line ("4 survivors") and spawn S5. `pings-and-callouts.md`: rules 18 and 25 ("all five"), voice sets per character C1–C5. Lobby dependency entries in Match Flow, Borrowed Face, Pings & Callouts and Facility Map | SneakKestrel16 | Before re-running `/gate-check technical-setup` | Resolved 2026-10-12: all listed edits applied; `players_per_match` deprecated in the registry |
| Balance at 3 and 5 survivors: objective counts, bleed-out, camping slow, taser cartridges and lunge cooldown are tuned for 4. Borrowed Face also has only 3 disguise targets at 3 survivors, fewer after the first elimination. MVP balance stays at 4 survivors; 3 and 5 are playable but untuned until Match Telemetry data exists | SneakKestrel16 | Milestone 5 playtest | |
| A lost session token lets a player dodge their monster turn; a platform account ID (e.g. Steam) would close it | SneakKestrel16 | Post-MVP | |
| Listen server vs dedicated server, and the transport | Network Authority ADR | Technical Setup | |
