# Story 011: Shipped client form picker and transform input

> **Epic**: Borrowed Face
> **Status**: Complete
> **Layer**: Feature
> **Type**: UI
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

`BorrowedFace.request_packet(form)` exists and the server runs the 2 s transformation, but no shipped client code sends it; only `round_view` does. The shapeshifter cannot disguise in the shipped build. The HUD-6 face list (S1) already shows which survivors are observed and available.

**GDD**: `design/gdd/borrowed-face.md` rules 6-9, 14
**Requirement**: `TR-borrowedface-004`, `TR-ui-001` (TR-bf-001 corrected to the registry's transform-request id; TR-ui-001 is not in tr-registry.yaml yet, as for hud-results 006)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus; secondary: ADR-0004
**ADR Decision Summary**: The picker is a WHEEL-like context that keeps movement live; it reads the HudModel face list and sends one request; the server validates.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: the picker reads HudModel only
- Required: requests gated by the InputContextStack
- Forbidden: offering a form the server says is unavailable as if it were available

---

## Acceptance Criteria

*From GDD `design/gdd/borrowed-face.md`, scoped to this story:*

- [ ] A shapeshifter opens the form picker, sees each observed survivor plus true form with availability from the face list, and choosing one sends `request_packet`; the server starts the transformation.
- [ ] A request while on cooldown, stunned or mid-lunge is refused by the server and the picker shows the refusal through the HUD-3 label.
- [ ] Retained screenshots of the picker and of a completed disguise in the shipped lobby-to-round path.

---

## Implementation Notes

- The binding is inference; mark it.
- Check the TR id against docs/architecture/tr-registry.yaml and correct it in this story if it differs.

---

## Out of Scope

- Transformation visuals (stories 009, 010).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/client-form-picker/`

**Status**: [x] Created: `production/qa/evidence/client-form-picker-evidence.md` (lead sign-off pending)

---

## Dependencies

- Depends on: match-flow 013; hud-results 006
- Unlocks: None

## Progress Notes (2026-10-15)

Merged 606a777..ec2e346 (conflicts with MA-11 and HUD-4 resolved by the orchestrator keeping both; form_picker moved from R to T because MA-11 bound False Signal to R). FormPicker built for every client via FormPicker.for_client (opens only when HudModel.is_shapeshifter()); hold form_picker pushes a WHEEL context (movement live, look and actions off), mouse or right stick aims via wheel_pick, release sends BorrowedFace.request_packet reliably on channel 1. True form first, then survivors in S1 order; unavailable, Eliminated/Escaped and current form greyed with a text mark and never sent. FIRST MERGE ATTEMPT BACKED OUT: exit leak (376 ObjectDB) in tests/integration/hud-results from a one-shot connection on monster_state_changed that never fires on survivor clients; fixed by building up front and holding the session via WeakRef (gotcha recorded in docs/engine-reference/godot/gotchas.md; mechanism a guess). TR id corrected to TR-borrowedface-004. INFERENCE: refusal inferred when no transformation starts by send + RTT + slack_ticks (no server refusal message, rule 7; a late reliable resend could show a false "Not now"); disconnected survivors not greyed (not in HudModel); hold mode only (no settings store). Evidence via round_host + round_view (same RoundClient); stun and lunge refusals unit-tested only; wheel top segment overlaps the phase line and S1 overlaps the roster (ux pass). 11 unit tests (watched fail first); 3 mutations caught. Full suite 1521/1521, no leak lines.

## Closed (2026-10-15)

Closed on its retained screenshots (UI gate). The designer played the shipped build on 2026-10-15 (lobby to round to Results; survivor, shapeshifter and spectating sessions), then approved closing the sprint-9 UI stories in chat (AD-242). Orchestrator reviewed the evidence images. Earlier shots predate BUG-0010/0011 (fixed in b024355); after-fix shots are in production/qa/evidence/hud-budget-accessibility/after/.
