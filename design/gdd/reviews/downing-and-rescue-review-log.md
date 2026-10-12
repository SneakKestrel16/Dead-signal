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
