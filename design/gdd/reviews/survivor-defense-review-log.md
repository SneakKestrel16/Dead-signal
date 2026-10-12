# Review Log: Survivor Defense

Target: `design/gdd/survivor-defense.md`

## Review — 2026-10-11 — Verdict: NEEDS REVISION
Scope signal: M
Specialists: none (lean review)
Blocking items: 1 | Recommended: 5
Summary: First review, after the cross-review blocker fixes in efbdd84. Rules, formulas and values agree with Monster Abilities, Downing and Borrowed Face. One blocker: a taser hit still revealed a disguised monster. Revised in the same session by designer decision, together with the recommended items.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Rules 10-11: a stunned disguised monster staggered and rooted, while a shocked survivor only slowed 30%; an immune disguised monster showed the "resisted" spark. Any observer could tell them apart, against Borrowed Face rule 10. Resolved: a friendly shock now mirrors the stun (stagger, `stun_root_s`, slow to `stun_duration_s`), and a disguised immune monster shows the same shock. `friendly_shock_s` removed here and in the registry.
- [RECOMMENDED] Rule 22: survivors cannot search, so "a disguised search looks like a survivor checking a cabinet" was false. Now a visible monster action (proposed).
- [RECOMMENDED] Feel Acceptance Criteria: both were unmeasurable. Rewritten as playtest thresholds.
- [RECOMMENDED] Acceptance Criteria: no criterion for the friendly shock, early immunity end, door blocking a lunge, rebarricade lockout or the long-hide cue. Five added.
- [RECOMMENDED] Rule 17: the 25% cap holds only when the monster disengages. Caveat added.
- [RECOMMENDED] Formulas: `monster_travel_to_alternate_route` had no variable table; header said Draft. Fixed.
Reviewed-Content-Hash: design/gdd/survivor-defense.md 20a6b2cb7e5ac5802c292a59012c555a35ec3d47
Reviewed-Content-Hash: design/registry/entities.yaml 882a83438b6118dc29520259d84f868ae97764ae

Each hash is for the document as it was reviewed, before that entry's revisions. A re-review therefore sees the revised file as CHANGED and runs in full.

## Review — 2026-10-11 (re-review after R2) — Verdict: NEEDS REVISION → APPROVED
Scope signal: L
Specialists: none (lean review)
Blocking items: 1 | Recommended: 4
Summary: Re-review after the cross-review re-review decisions in 55dd311 (one shock lock for all). Prior blocker is resolved, and the lock agrees with Pings rule 23 and Borrowed Face. A new blocker: a Seized victim could shield the monster from a rescuer's shot. Revised in the same session by designer decision, together with the recommended items, then approved.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Rule 8: the shot hits the first body, so a Seized victim next to the committing monster could block a rescue shot, and a shock on a Seized or Downed body was undefined. Resolved: the shot passes through Seized and Downed survivors and never shocks them; edge case and AC added.
- [RECOMMENDED] Tuning Knobs: `stun_slow_mult`, `stun_item_reuse_s`, `hide_noise_radius_m`, the barricade removal hold and the long-hide cue interval were missing. Added; the last two named `barricade_remove_s` and `hide_cue_interval_s`.
- [RECOMMENDED] Game Feel: "survivors keep full control" contradicted the friendly-shock root. Fixed.
- [RECOMMENDED] Interactions/Dependencies: Borrowed Face listed as one-way although this doc reads the disguised and Transforming state; no Pings row for the lock. Fixed.
- [RECOMMENDED] Header said Approved while the index said Needs Revision. Index now Approved.
Reviewed-Content-Hash: design/gdd/survivor-defense.md ea8806b2c8819d7f3c1f40ae783f93900f792a50
Reviewed-Content-Hash: design/registry/entities.yaml 2d26b4ae2b547500e777d53de28678ac521730f4

## Review — 2026-10-11 (re-review after second cross-review B1, B2, W7, W8) — Verdict: APPROVED
Scope signal: M
Specialists: none (solo review)
Blocking items: 0 | Recommended: 1
Summary: Re-review after e70f9ff, c41f126 and bbf127f. The no-refresh lock (rule 14) keeps `lock_share` valid in every form. The friendly shocks at rescues (W7) and on holds (W8) are accepted, with edge rows and a playtest AC. The `PlayerShocked` name matches the index and Scare Events.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Rule 1: event delivery outside a disguise was undefined. A survivor hit while the monster was in true form had no stated event, and a true-form stun "may" have reached survivor clients. As a result, Scare Events rule 18 never ducked for either case on survivor clients. Fixed: a survivor hit always sends `PlayerShocked`, and a true-form stun is sent to all clients as `MonsterStunned`. Scare Events rule 18 and the index `MonsterStunned` row are updated to match.
Reviewed-Content-Hash: design/gdd/survivor-defense.md 10d099e3a8c89d4e889c70f3d6cc13a5d89df18e
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97

## Review — 2026-10-12 (after cross-review B4 and fourth cross-review B1, W1) — Verdict: APPROVED
Scope signal: L
Specialists: none (lean review, headless)
Blocking items: 0 | Recommended: 3
Summary: The post-lock window (rule 14) and the new early end of immunity when a disguise completes (rule 16) are consistent across rules 10, 11, 14, 16 and 17, the States table, the Edge Cases and the ACs. No case was found where a shock tells a disguised monster from a survivor. Three clarifications were applied in the same session.
Prior verdict resolved: Yes (cross-review changes reviewed)
Findings:
- [RECOMMENDED] Rule 17 / Formulas: only the lunge wind-up was named as the monster's own way to exceed lock_share; the disguise-completion early end added. Resolved.
- [RECOMMENDED] Formulas: stun_immunity_s described as monster immunity only; now also every player's post-lock window. Resolved.
- [RECOMMENDED] Rule 27: Break had no form condition (prior cross-review W12). Resolved: any form, a visible monster action like Search (proposed).
- [INFO] Open from cross-reviews: stun items as item-ping targets have no world object (W8); stun and immunity state across a monster disconnect (W11).
Reviewed-Content-Hash: design/gdd/survivor-defense.md 88ced870a0699abc5285e39fc559b1d474fc9e1f
Reviewed-Content-Hash: design/registry/entities.yaml 2e0c9d7193ed0edcec84153a48600cb1f7e69e97

## Review — 2026-10-12 (after open cross-review warnings resolved, 30af36a) — Verdict: APPROVED
Scope signal: L
Specialists: none (lean review, headless)
Blocking items: 0 | Recommended: 1
Summary: The monster-disconnect edge case (W11) and the removal of taser pings (W8) agree with Match Flow rule 20 and Pings rule 5.
Prior verdict resolved: Yes (cross-review changes reviewed)
Findings:
- [RECOMMENDED] Header: Last Updated not bumped. Resolved.
Reviewed-Content-Hash: design/gdd/survivor-defense.md 10a935730dc94ed0900358047e002264f781982d
Reviewed-Content-Hash: design/registry/entities.yaml 15702c72e53b21b1b20bc82bc9c8fe2a5de821fa
