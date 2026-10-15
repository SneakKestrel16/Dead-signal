# Story 011: Client round scene

> **Epic**: Match Flow & Win Conditions
> **Status**: In Review
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 2 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]


## Context

A player needs a client scene that joins a composed round (story 010) and shows it: the greybox map, their own first-person body predicted from local input, the other players' bodies from snapshots, the predicted hold bar and the flashlight cones. This turns the server-only work of sprints 3 to 6 into something people can play. It also unblocks LB-6, the CI-16 240 fps capture and the owed playtests. Decided by the user (AD-201).

**GDD**: `design/gdd/match-flow.md`, `design/gdd/first-person-controller.md`, `design/gdd/borrowed-face.md` (body appearance)
**Requirement**: `TR-matchflow-001`; client sides of `TR-net-*` (prediction, interpolation)

**ADR Governing Implementation**: ADR-0002: Authoritative simulation, prediction and interpolation; secondary: ADR-0004 (per-peer handles, appearance in snapshots), ADR-0007, ADR-0010 (Borrowed Face rendering), ADR-0014 (UI layers and input focus)
**ADR Decision Summary**: Clients predict their own controller and reconcile against snapshots, interpolate remote bodies by handle, and render appearance from the snapshot's appearance byte.
**ADR Version**: 2026-10-15

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: D3D12 is the default renderer on Windows in 4.6+. The capture uses `--write-movie`.

**Control Manifest Rules (this layer)**:
- Required: the client never emits events; it reads only projected state (ADR-0004, ADR-0005)
- Forbidden: no gameplay rules on the client beyond prediction (ADR-0002)

---

## Acceptance Criteria

- [ ] A client scene joins a host running the composed round and renders the greybox map from the camera of its own predicted controller, with mouse look and movement.
- [ ] Every remote body visible to the client is interpolated from snapshots by handle and drawn with its appearance (greybox colour per form is enough, ADR-0010 minimal). The bodies of hidden survivors are not drawn.
- [ ] The predicted hold bar (`PredictedHoldBar`) and flashlight cones are wired. Holding a real interactable shows the bar, and toggling the flashlight shows the cone on every client.
- [ ] A 240 fps `--write-movie` capture at 150 ms simulated latency measures the hold bar appearing within 100 ms of a valid Start press. This closes CI-16 AC1; record it in `production/qa/evidence/predicted-hold-bar-evidence.md`.
- [ ] Retained screenshots in `production/qa/evidence/client-round-scene/` show a survivor view and the monster view in a running round.

---

## Implementation Notes

- Reuse the existing pieces: `tests/manual/net_check.gd` (join flow), the client display classes (`life_display.gd`, `objective_display.gd`, `defense_display.gd`, `transform_view.gd`), `FlashlightPredictor` and `PredictedHoldBar`.
- For the 150 ms capture, use the `UdpLink` latency shim from the five-client tests.

## Out of Scope

- The final HUD, lobby screen and results screen (lobby story 005, match-flow story 008 and the ADR-0014 stories).
- Final art and audio.

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/match-flow/client_round_scene_test.gd`, plus the screenshots and 240 fps capture above
**Status**: [ ] Not yet created

## Dependencies

- Depends on: match-flow story 010 (round composer)
- Unlocks: LB-6, CI-16 AC1, the monster-view lunge playtest and the 5-client survivor-defense playtest
