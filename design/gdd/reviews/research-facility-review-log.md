# Review Log: Level: Research Facility (Facility Map)

Target: `design/levels/research-facility.md`

## Review — 2026-10-12 — Verdict: NEEDS REVISION
Scope signal: M
Specialists: none (lean review, headless)
Blocking items: 2 | Recommended: 5
Summary: Layout, loops, choke-point rules and placements are sound and match every GDD. Two blockers: candidate replication said every point waits for discovery, contradicting Survivor Objectives rules 5 and 7 (fuse boxes and terminal are sent at round start; introduced by the cross-review W5 wording), and lighting-state precedence was undefined. Both were revised in the same session from existing docs; precedence is proposed.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Authored Candidate Points / AC 4: discovery applied to fuse boxes and the terminal too. Resolved: only drive rooms and fuse spawns wait for discovery.
- [BLOCKING] Lighting States: no precedence when Power Restored, Evacuation, Blackout and overlays overlap. Resolved: base state is the latest phase or objective state, overlays stay on their fixtures, Blackout overrides its volume, Reset clears all (proposed), plus AC 12.
- [RECOMMENDED] Placement constraints: corridor zone wording differed from Objectives rule 6. Resolved.
- [RECOMMENDED] Targets / Lighting States: "final 2:00" ignored early Evacuation. Resolved.
- [RECOMMENDED] AC 7: 25 s bound against a 20 s target. Resolved: 20 s.
- [RECOMMENDED] Structure: no Edge Cases for the runtime rules this map owns (not in the level template). Resolved: Edge Cases table added.
- [RECOMMENDED] Open Questions: C1 monitor use already assumed by Scare Events rule 2a. Resolved: cross-referenced; question stays open.
Reviewed-Content-Hash: design/levels/research-facility.md c62c6c77241708b6651ac6af430e0c50d74ceec1
Reviewed-Content-Hash: design/registry/entities.yaml 15702c72e53b21b1b20bc82bc9c8fe2a5de821fa

## Review — 2026-10-12 (re-review) — Verdict: APPROVED
Scope signal: M
Specialists: none (lean review, headless)
Blocking items: 0 | Recommended: 2
Summary: Both prior blockers hold. Candidate replication now matches Survivor Objectives rules 5 and 7, and the lighting precedence is complete and covered by AC 12. Two wording fixes were applied in the same session.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Edge Cases: early arming said "Low Power (or Power Restored)", but arming needs both fuses, so it is always Power Restored. Resolved.
- [RECOMMENDED] Lighting States: Low Power said fuse boxes are dark, while N-03 lights an indicator on active boxes (earlier cross-review Info). Resolved: housings dark, active indicator lit.
Reviewed-Content-Hash: design/levels/research-facility.md a401202224601726fab0564a4e22f01d33508452
Reviewed-Content-Hash: design/registry/entities.yaml 15702c72e53b21b1b20bc82bc9c8fe2a5de821fa
