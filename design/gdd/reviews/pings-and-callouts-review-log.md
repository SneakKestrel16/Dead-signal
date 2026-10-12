# Review Log: Pings & Callouts

Target: `design/gdd/pings-and-callouts.md`

## Review — 2026-10-11 — Verdict: NEEDS REVISION
Scope signal: M
Specialists: none (solo review)
Blocking items: 2 | Recommended: 6
Summary: Formulas and registry values agree with sibling GDDs, and earlier cross-review items R2, R-W13 and W1 are resolved. Two gaps blocked: a player warning ping that follows its target leaks transforms and is ambiguous under duplicate names, and the states table had no Seized or Escaped rows (cross-review R-W11). Revised in the same session by designer decision (static ping), together with the recommended items.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Core Rules 5: a following warning marker tracks a disguised monster through transforms and is ambiguous when two bodies share a name (rule 24). Resolved: the marker is static at the position the player stood, labelled with their displayed identity (designer decision); edge rows added.
- [BLOCKING] States: no Seized or Escaped rows (cross-review R-W11). Resolved: Seized blocks pings and callouts; Escaped sends nothing to living players. Healthy exits and rule 6 validation updated.
- [RECOMMENDED] Core Rules: hidden survivors (Survivor Defense rules 18–20) undefined. Added rule 14a (proposed): ping from the peek view, callout reveals the spot.
- [RECOMMENDED] Formulas: "max 30 per minute" ignored the full starting bucket. Now 30 steady state, 33 in a first minute.
- [RECOMMENDED] Formulas: unclear whether a rejected callout updated the cooldown timestamps. Now only accepted callouts do.
- [RECOMMENDED] Acceptance Criteria 1: "within 1 network round trip" not measurable. Now 250 ms from server acceptance; criteria added for static markers and Seized/Escaped rejection.
- [RECOMMENDED] Feel Acceptance Criteria: two criteria not measurable. Rewritten as a velocity check and a survey threshold over ≥10 rounds.
- [RECOMMENDED] Open Questions: monster receiving survivor pings links to the Downing rescue-camping leak. Noted on the question.
- [NICE-TO-HAVE] A False Signal "Need rescue" callout from a non-Downed position is a dead line a careful survivor can spot. Not applied; left to playtest.
Reviewed-Content-Hash: design/gdd/pings-and-callouts.md 64309ebf882bd0130f4fe74088b7819fa6f969ef
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97

Each hash is for the document as it was reviewed, before that entry's revisions. A re-review therefore sees the revised file as CHANGED and runs in full.

## Review — 2026-10-12 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (lean review)
Blocking items: 3 | Recommended: 7
Summary: Prior blockers (static warning ping, Seized and Escaped states) are resolved, and the formula examples check out. Three new gaps would have forced an implementer to guess: monster ping recipients, rate-limit state for fake callouts, and the label for a True Form target. All three were resolved by designer decision in the same session.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Core Rules 7: monster as ping recipient was open and would leak a Downed body through walls. Resolved: monster receives a ping only if the target is in its line of sight.
- [BLOCKING] Core Rules 17/26: fake callout effect on rate-limit state undefined. Resolved: a fake touches no cooldown, repeat block or ping token; only false_signal_cooldown_s limits it.
- [BLOCKING] Core Rules 5: warning ping on a True Form monster had no label. Resolved: allowed, labelled "Monster".
- [RECOMMENDED] Dependencies: Match Flow missing. Added.
- [RECOMMENDED] Core Rules 28: "(not you)" plus direction arrow is a near-certain reveal for a disguised monster calling out near its original. Documented as intended, playtest-gated.
- [RECOMMENDED] Acceptance Criteria: packet-inspection criterion scoped to the callout message; ping-delivery criterion split into accepted vs displayed with full-bucket precondition; criteria added for monster line-of-sight delivery, True Form label and fake-callout limits.
- [RECOMMENDED] Open Questions: monster ping question closed; voice-set question marked as gating rules 10, 21 and 26. Still open.
- [RECOMMENDED] Systems index: dependency lines list 3 of about 11 dependencies. Updated.
- [NICE-TO-HAVE] A False Signal "Need rescue" from a non-Downed position is a dead line. Left to playtest.
Reviewed-Content-Hash: design/gdd/pings-and-callouts.md 72223e4ab1ce60872d9b222bc27dcbc50bbb1687
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97

Each hash is for the document as it was reviewed, before that entry's revisions.

## Review — 2026-10-12 (third) — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (lean review)
Blocking items: 2 | Recommended: 5
Summary: Prior blockers hold. Two information leaks remained in who receives what: the monster got a named, directional feed line for in-range callouts, and "(not you)" on pings had no range limit. Both resolved by designer decision in the same session and applied; re-review needed to confirm.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Core Rules 11: monster as callout recipient got feed line and arrow, a through-wall locator for "Need rescue" at 40 m. Resolved: monster gets audio only.
- [BLOCKING] Core Rules 28: "(not you)" on any ping at any range made every disguised ping a guaranteed reveal. Resolved: pings carry the mark only when the sender is within callout_range_m.
- [RECOMMENDED] Core Rules 28: fake callouts touch no limits, so cadence is a tell. Documented as a fair clue.
- [RECOMMENDED] Core Rules 5: occupied hiding-spot ping could expose the occupant. Added rule 7a.
- [RECOMMENDED] Dependencies: match-flow.md did not list Pings; research-facility.md did not list pingable switches. Both added.
- [RECOMMENDED] Acceptance Criteria: missing coverage for rules 11 (monster audio only), 14a, 24, 25 and 7a. Added.
- [RECOMMENDED] Open Questions: voice set per survivor slot still undecided; rules 10, 21, 26 stay proposed. Not applied.
- [RECOMMENDED] Dependency Graph: no GDDs yet for Network Authority, First-Person Controller, Facility Map, HUD, Match Telemetry.
Reviewed-Content-Hash: design/gdd/pings-and-callouts.md 72223e4ab1ce60872d9b222bc27dcbc50bbb1687
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97

Each hash is for the document as it was reviewed, before that entry's revisions. A re-review therefore sees the revised file as CHANGED and runs in full.

## Review — 2026-10-12 (fourth) — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (lean review)
Blocking items: 1 | Recommended: 8
Summary: Prior blockers hold and the information-leak rules agree with Downing and Borrowed Face. One gap remained: the monster's "line of sight" for receiving survivor pings was undefined. Resolved by designer decision in the same session, together with the recommended items below; re-review needed to confirm.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Core Rules 7: monster line of sight undefined (ray vs view cone, facing, range). Resolved: unobstructed server ray from the monster's eye within ping_max_range_m, facing ignored.
- [RECOMMENDED] Core Rules 11: "not a through-wall locator" overstated; positional audio is still a rough cue. Reworded, cites Downing rule 6.
- [RECOMMENDED] Core Rules 19: Escaped players not muted. Added.
- [RECOMMENDED] Core Rules 7 / Formulas: spectator reception undefined. Decided: Eliminated and Escaped receive, send nothing.
- [RECOMMENDED] Core Rules 6 / Edge Cases: warning ping on a hidden survivor undefined. Rejected as a target.
- [RECOMMENDED] Formulas: initial bucket and callout timestamps undefined. Added.
- [RECOMMENDED] Acceptance Criteria: missing global cooldown, rejected pending marker, attached item ping token, spectator voice and hidden-target cases; full-round criterion had no pass condition. Added or rewritten.
- [RECOMMENDED] Open Questions: voice set per survivor slot still undecided; rules 10, 21, 26 stay proposed. Not applied.
- [RECOMMENDED] Dependency Graph: no GDDs yet for Network Authority, First-Person Controller, Facility Map, HUD, Match Telemetry. Tracking note.
Reviewed-Content-Hash: design/gdd/pings-and-callouts.md 968847cd4cd75afea58467470fdafaff5e7e9fff
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97

Each hash is for the document as it was reviewed, before that entry's revisions. A re-review therefore sees the revised file as CHANGED and runs in full.

## Review — 2026-10-12 (fifth) — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (lean review)
Blocking items: 1 | Recommended: 3
Summary: The fourth review's revisions hold: monster line of sight, Escaped muting, hidden-target rejection and initial limiter state are all precise. That revision introduced one gap: a spectator's "position" for callout range was undefined. Resolved from Downing rule 9 (spectators watch a living survivor) without a new design decision; re-review needed to confirm.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Core Rules 7 / Formulas: spectator "in their position" undefined; spectators have no body. Resolved: a spectator receives exactly what the survivor they watch receives (Downing rule 9, Match Flow rule 10).
- [RECOMMENDED] Core Rules 13: zero-token behaviour of an attached ping stated only in Acceptance Criteria. Added to the rule: the callout plays without the ping.
- [RECOMMENDED] Acceptance Criteria: global-cooldown criterion self-contradictory. Reworded with t=0/1/3 timings.
- [RECOMMENDED] Open Questions: voice set per survivor slot still undecided; rules 10, 21, 26 stay proposed. Not applied.
Reviewed-Content-Hash: design/gdd/pings-and-callouts.md d752d34d94cc109bdd7293c9188576efd83a1913
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97

Each hash is for the document as it was reviewed, before that entry's revisions. A re-review therefore sees the revised file as CHANGED and runs in full.
