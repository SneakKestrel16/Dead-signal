# Review Log: Lobby & Role Assignment

## Review — 2026-10-12 — Verdict: APPROVED
Scope signal: L
Specialists: none (lean mode)
Blocking items: 0 | Recommended: 6
Summary: Complete at the standard tier (5/5 required sections plus Formulas; Player Fantasy and Tuning Knobs advisory). Rules, formulas and 29 ACs are consistent and implementable. The 4-6 player conflict with approved match-flow.md (exactly 5) is tracked in Open Questions but the entry is incomplete and unresolved.
Prior verdict resolved: First review
Findings:
- [RECOMMENDED] Open Questions: propagation entry omits Match Flow rules 2, 74/88/263 ("5"/"all 5"), the host-left rule, research-facility.md prerequisite line, Pings rules 18/25 ("all five"), and registry players_per_match supersession.
- [RECOMMENDED] Detailed Design: one unready or AFK player stalls the start forever; no host kick or ready timeout.
- [RECOMMENDED] Detailed Design rule 11: public roles vs Borrowed Face / proximity voice (monster's identity known, voice becomes a tell); state that in-match name tags are hidden.
- [RECOMMENDED] Open Questions: 3-survivor rounds shrink Borrowed Face's pool of targets; balance question covers numbers but not disguise viability.
- [RECOMMENDED] Acceptance Criteria: AC-LB-11 "each clash loser's dealt character is uniform within the same tolerance" is ambiguous (which trials, which denominator).
- [RECOMMENDED] Tuning Knobs: advisory section absent; min/max players, lobby_countdown_s and name length limits are scattered.
Reviewed-Content-Hash: design/gdd/lobby-role-assignment.md 1b524fad07c04b2c66a72514e283fe1ddd350d1d
Reviewed-Content-Hash: design/registry/entities.yaml ed63d1fc163b57e5d837b843b54f13b041c4bbcd
