# Review Log: Downing, Rescue & Elimination

Target: `design/gdd/downing-and-rescue.md`

## Review — 2026-10-12 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (lean review)
Blocking items: 1 | Recommended: 4
Summary: Rules, formulas and registry values are complete and consistent; every formula example checks out. One gap between this doc and Match Flow let a Seized victim dodge a takedown by disconnecting. Revised in the same session by designer decision, together with the recommended items.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Edge Cases: a victim disconnecting while Seized was undefined (Match Flow rule 19 restores only Healthy/Downed), so a rage-quit could dodge a down. Resolved: the commit resolves on schedule while they are disconnected; row mirrored in match-flow.md.
- [RECOMMENDED] Core Rules 3: eligibility omitted post-release grace and hidden survivors (Monster Abilities, Survivor Defense). Fixed.
- [RECOMMENDED] Core Rules 6/7: "can ping normally" overstated Pings & Callouts rule 14; hidden survivors could rescue, contradicting Survivor Defense. Fixed.
- [RECOMMENDED] Feel Acceptance Criteria: two criteria were not measurable. Rewritten as survey thresholds over ≥10 rounds.
- [RECOMMENDED] Acceptance Criteria: no criterion for grace durations, the one-rescuer rule, hidden rescue or Seized disconnect. Four added.
- [NICE-TO-HAVE] Formulas: `lunge_windup` renamed `lunge_windup_s`; monster-disconnect edge case names `post_release_grace_s`. Applied.
Reviewed-Content-Hash: design/gdd/downing-and-rescue.md ad9dd887ea96472dc05f690e76506db5da597bed
Reviewed-Content-Hash: design/registry/entities.yaml 882a83438b6118dc29520259d84f868ae97764ae

Each hash is for the document as it was reviewed, before that entry's revisions. A re-review therefore sees the revised file as CHANGED and runs in full.

## Review — 2026-10-11 — Verdict: APPROVED
Scope signal: L
Specialists: none (lean review)
Blocking items: 0 | Recommended: 3
Summary: Prior blocker (Seized disconnect) is resolved and mirrored in match-flow.md. Formula examples check out, and values agree with match-flow, monster-abilities and survivor-defense. Remaining items are acceptance-criteria gaps.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Acceptance Criteria: no criterion for crawl speed, Call for Help range/repeat block, or monster disconnect during a commit.
- [RECOMMENDED] Acceptance Criteria: same-tick orderings (stun vs commit completion, hit vs rescue completion) are edge cases with no criterion.
- [RECOMMENDED] Detailed Design rule 7: does not say whether stored rescue progress resets on re-down (likely moot).
Reviewed-Content-Hash: design/gdd/downing-and-rescue.md 5c57ba75acefc0097acbb36e98a22140f6231e09
Reviewed-Content-Hash: design/registry/entities.yaml 882a83438b6118dc29520259d84f868ae97764ae

## Review — 2026-10-11 (re-review after cross-review blockers) — Verdict: APPROVED
Scope signal: L
Specialists: none (lean review)
Blocking items: 0 | Recommended: 4
Summary: Re-review after the cross-review blocker fixes in efbdd84 (camp pause, PlayerConnectionChanged). Values and events agree with the systems-index event table. The new camp pause had contradicted rule 10's no-stall claim. Revised in the same session by designer decision, together with the other recommended items.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Rule 6 / rule 10: with every survivor Downed, the camp pause let the monster freeze bleed-out until the deadline, contradicting "can no longer stall". Resolved: the pause applies only while at least one survivor is Healthy; formula, variable and acceptance criterion added.
- [RECOMMENDED] Open Questions: the bleed-out pause row was stale after rule 6 decided it. Updated.
- [RECOMMENDED] Formulas: `monster_distance_m` basis was unstated. Now straight-line through walls and floors (proposed).
- [RECOMMENDED] Interactions/Dependencies: no `PlayerConnectionChanged` input row; Pings & Callouts listed the dependency as one-way. Both fixed.
- [NICE-TO-HAVE] Formulas: the monster exposure window ignores `stun_use_delay_s` (0.2 s). Not applied.
Reviewed-Content-Hash: design/gdd/downing-and-rescue.md e808f38bd6f5076b081e78f90fe77d427419a97f
Reviewed-Content-Hash: design/registry/entities.yaml 882a83438b6118dc29520259d84f868ae97764ae
