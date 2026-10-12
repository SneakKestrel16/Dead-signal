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
