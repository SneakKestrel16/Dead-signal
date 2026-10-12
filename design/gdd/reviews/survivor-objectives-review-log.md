# Review Log: Survivor Objectives

Target: `design/gdd/survivor-objectives.md`

## Review — 2026-10-12 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (lean review)
Blocking items: 1 | Recommended: 3
Summary: Objectives, formulas and registry values are complete and agree with Match Flow. Rule 11 let only a survivor with no drive pick one up, which contradicted the cap of 2 and made a lone-survivor win impossible after activation. Revised in the same session, together with the recommended items.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Core Rules 11: pickup required "without a drive", contradicting `max_drives_carried` = 2 (rules 9, 20). Fixed: pickup allowed while carrying fewer than `max_drives_carried`; criterion added for one survivor extracting both ejected drives.
- [RECOMMENDED] Core Rules 19: no rule for hiding survivors holding the activation zone. Resolved by designer decision: hidden survivors do not count; formula variable and edge case updated.
- [RECOMMENDED] Core Rules 3: cross-reference pointed at rule 16 instead of rule 19. Fixed.
- [RECOMMENDED] Edge Cases: "downed in the same tick a teammate starts rescuing" was impossible (rescue needs a Downed survivor). Reworded to a rescuer next to a dropped drive.
- [RECOMMENDED] Acceptance Criteria: two feel criteria and the install-alert "not centred" criterion were not measurable. Rewritten as survey thresholds over ≥10 rounds and a >1 m offset.
Reviewed-Content-Hash: design/gdd/survivor-objectives.md 8787d554312b6a3435cc7c6fb2b072be9d488ed1
Reviewed-Content-Hash: design/registry/entities.yaml 882a83438b6118dc29520259d84f868ae97764ae

## Review — 2026-10-12 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (solo review)
Blocking items: 2 | Recommended: 0
Summary: The prior blocker is resolved. Two new blockers: the fuse-box rules left install capacity and fake-interaction locking undefined, and three acceptance criteria were not independently testable. Revised in the same session by designer decision.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Core Rules 15/25: undefined whether a box takes one fuse or many, and whether a fake interaction holds the one-interaction lock. Resolved: each active box takes exactly one fuse; fakes never hold the lock, and a real interaction cancels the fake. Two edge cases added.
- [BLOCKING] Acceptance Criteria: "points vary" had no bar; the third-pickup criterion was vacuous; the fuse feel survey was free text. Rewritten: ≥4 distinct drive pairs and all 3 terminals over 20 rounds; `max_drives_carried` = 1 override test; fixed-choice survey question.
Reviewed-Content-Hash: design/gdd/survivor-objectives.md 8ca3abe3aa5059b4f68fd1098cc7efc8ad492775
Reviewed-Content-Hash: design/registry/entities.yaml 882a83438b6118dc29520259d84f868ae97764ae

The hash is for the document as it was reviewed, before the revisions. A re-review therefore sees the revised file as CHANGED and runs in full.
