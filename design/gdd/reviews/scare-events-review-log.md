# Review Log: Scare Events

Target: `design/gdd/scare-events.md`

## Review — 2026-10-12 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: none (lean review)
Blocking items: 2 | Recommended: 7
Summary: Authority, traceability and the cross-review B1–B3 fixes hold, and every required section is present. Two rules broke the pillars: the ambush lunge scare flinched a survivor during the very wind-up rule 14 protects, and room-entry and monitor triggers were defined for survivors only, so a disguised shapeshifter that fired no scare would be a learnable tell. Run headless: both blockers and all recommended items were revised in the same session with **(proposed)** defaults for the designer to confirm.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Core Rules 14 / three-sources table / Visual-Audio: ambush lunge scare carried a flinch, but rule 14 forbade a flinch during a lunge wind-up; "targeting that survivor's area" was undefined. Resolved: no flinch within `lunge_cue_radius_m` of a wind-up or Active lunge; ambush lunge is stinger only.
- [BLOCKING] Core Rules 2: "entering an authored room" and "viewing a monitor" were survivor actions; a disguised shapeshifter not firing them would be a tell (Human Deception). Resolved: rule 2a, any player fires location triggers, always gated as Survivor source.
- [RECOMMENDED] Three-sources table: no intensity class per scare, yet gating and ACs depend on Major/Minor. Resolved: Intensity column.
- [RECOMMENDED] Formulas: no state updates (does a reduced Minor reset `last_major`?); budget applied to all non-Monster scares in the formula but RoundScript only in the table. Resolved: on-delivery block; budget is RoundScript only; Blackout-volume block moved from Edge Cases into the formula.
- [RECOMMENDED] Three-sources table: slammed door "Survivor" trigger undefined and contradicted Facility Map (door anchors RoundScript only). Resolved: RoundScript only.
- [RECOMMENDED] Core Rules 5a: "line of sight into a volume" undefined and costly (history per survivor per volume). Resolved: line of sight to the monster's chest, one last-seen time per survivor.
- [RECOMMENDED] Phase table: "Final 2:00" ignored early Evacuation (Match Flow rule 6). Resolved: phases keyed to `RoundPhaseChanged`.
- [RECOMMENDED] Core Rules 18 / Edge Cases / Rule 19: install noise and barricade break missing from ducking list; hallucination "lunge range" undefined; audible range per scare unstated. Resolved.
- [RECOMMENDED] Acceptance Criteria: no AC for minor cooldown, phase budget, hallucination cap, slammed door, reconnect, rule 2a; feel AC "can point toward the origin" unmeasurable. Resolved: ACs added, feel AC now 8 of 10 within 45°.
- [INFO] Dependencies: Network Authority, Accessibility Options and Match Telemetry have no GDD yet (Not Started); `design/accessibility-requirements.md` marked not yet authored.
Reviewed-Content-Hash: design/gdd/scare-events.md b15169f3fa1dd5e5c6946ab2462398f57805d38b
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97

## Review — 2026-10-12 (re-review after design review and fourth cross-review W2, W3) — Verdict: APPROVED
Scope signal: L
Specialists: none (lean review, headless)
Blocking items: 0 | Recommended: 2
Summary: Both prior blockers hold: no flinch near a lunge wind-up (now also ending one already running), and any player fires location triggers. Gating, intensity and the alarm on install completion are consistent with Survivor Objectives, Match Flow and Facility Map. Two consistency edits were applied in the same session.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Three-sources table: the reveal and "disguised teammate transforms" were two Major entries on one FormChanged (prior cross-review W9). Resolved: merged.
- [RECOMMENDED] States and Transitions: no Low → Emergency transition for an early-armed terminal (prior cross-review W6). Resolved.
- [INFO] Accessibility Options, Network Authority and Match Telemetry have no GDD yet (Not Started).
Reviewed-Content-Hash: design/gdd/scare-events.md 036e78077dbd8c7a8aee0dee81abf9e4405e2746
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97

## Review — 2026-10-12 (after open cross-review warnings resolved, 30af36a) — Verdict: APPROVED
Scope signal: L
Specialists: none (lean review, headless)
Blocking items: 0 | Recommended: 2
Summary: A slammed door is now presentation only (W13), consistent with rule 4 and the Facility Map scare anchors. The Visual/Audio table still described a door swing.
Prior verdict resolved: Yes (cross-review changes reviewed)
Findings:
- [RECOMMENDED] Visual/Audio: 'Door swing' would show a closed-looking door the server treats as open, which is a false sightline cue. Resolved: shudder in place, no swing.
- [RECOMMENDED] Header: Last Updated not bumped. Resolved.
Reviewed-Content-Hash: design/gdd/scare-events.md 6afbf24940be33bd1d6b746961c4084ae9d269c0
Reviewed-Content-Hash: design/registry/entities.yaml 15702c72e53b21b1b20bc82bc9c8fe2a5de821fa
