# ADR-0014: UI and Input-Focus Framework

## Status
Accepted

Accepted 2026-10-15 by the user ("accept all seven"). Any Verification Required items below are still open: they are follow-up work, not a condition on this status.

## Date
2026-10-12

## Last Verified
2026-10-15 (Verification 1, 2, 4, 5, 6 run on 4.7.2; see Verification Results)

## Decision Makers
Designer (SneakKestrel16), with Claude Code (`/architecture-decision`, autonomous mode, AD-47) and `godot-specialist` engine validation. TD-ADR skipped — Lean mode. `godot-specialist` found no blocking issue; its MEDIUM findings (focus restore validity, layer hide order, `_unhandled_input` gating, NOT SOURCEABLE API names) are folded into §3–5, §9 and Verification 2 and 6.

## Summary
The HUD, callout wheel, in-round overlay, lobby, results and dialogs all compete for the same mouse, keyboard and gamepad, and nothing said who owns input at a given moment, how the gameplay input frame is kept clean while a menu is open, or how UI reads round state. A client `InputContextStack` decides which context owns input and is the only writer of the mouse mode and of the gameplay input mask; UI is built from stock `Control` nodes on fixed `CanvasLayer`s, menus use stock focus, and the HUD reads only a client `HudModel` fed by snapshots and `ClientEventRouter` payloads.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | UI, Input |
| **Knowledge Risk** | HIGH: dual focus (4.6), AccessKit screen-reader support (4.5), `Control.accessibility_live` type moved to `AccessibilityServer.AccessibilityLiveMode` (4.7), mouse/keyboard device IDs no longer 0 (4.7), SDL3 gamepad driver (4.5). `modules/ui.md` and `modules/input.md` are 4.6 snapshots |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/ui.md`, `modules/input.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; ADR-0002, ADR-0004, ADR-0005, ADR-0007, ADR-0008; `design/ux/hud.md`, `design/ux/results.md`, `design/ux/interaction-patterns.md`, `design/accessibility-requirements.md` |
| **Post-Cutoff APIs Used** | Dual focus (4.6); `Control` accessibility properties (`accessibility_name`, `accessibility_live`, 4.5; live-mode enum on `AccessibilityServer`, 4.7); `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` (4.7) |
| **Verification Required** | (1) `Input.get_vector` and `Input.is_action_pressed` still report held keys while a focused `Control` consumes the same keys, so the gameplay mask in §2 is needed (expected; inference); (2) after `grab_focus()` on a context push, keyboard and gamepad (SDL3 driver, 4.5) navigation start from that control, a mouse hover elsewhere does not move it (4.6 dual focus), and a pop restores focus correctly even after a mouse click moved it; (3) NVDA on Windows reads `accessibility_name` of focused results rows and a polite live region announces a feed line, and the results countdown is never announced; (4) switching `MOUSE_MODE_CAPTURED` → `VISIBLE` → `CAPTURED` produces no camera jump on the first relative motion after capture; (5) 40 world markers projected and clamped per frame cost under 0.2 ms, and markers land on their targets at `content_scale_factor` 1.0 and 1.5 (`unproject_position` space vs marker `Control` space); (6) `Input.mouse_mode`, the `MOUSE_MODE_*` constants and the `AccessibilityServer.AccessibilityLiveMode` value names exist as written in the 4.7.2 editor (NOT SOURCEABLE in the reference; `godot-specialist`, 2026-10-12) |

### Verification Results
2026-10-15, Godot 4.7.2, `tests/integration/ui-input-focus/adr_0014_verification_test.gd`; evidence `production/qa/evidence/ui-input-focus/adr-0014-verification.md`. Items 1, 2, 4, 5 and 6 PASS (5: 40 markers p99 47 us, 0.000 px error at scale 1.0 and 1.5). Item 4 failed first (nothing discarded the first motion after recapture, BUG-0014) and passes after the fix. Item 3 (NVDA) NOT ASSESSED, manual steps in the evidence file.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted): client input frame sampling and send. ADR-0011 (Proposed): results payload the results screen shows. ADR-0004 (Accepted): projected per-peer state is all the client knows. ADR-0005 (Accepted): `ClientEventRouter`, no gameplay autoloads, composition root. ADR-0007 (Accepted): device-ID rule. ADR-0008 (Accepted): hold start and predicted hold bar |
| **Enables** | HUD, lobby, results, settings and in-round overlay stories; Accessibility Options (VS) hooks; Pings & Callouts presentation (TR-pings-004/-005 feed and markers) |
| **Blocks** | Any story that builds a screen, the HUD or the callout wheel |
| **Ordering Note** | None |

## Context

### Problem Statement
Three UX specs (`hud.md`, `results.md`, `interaction-patterns.md`) describe screens and 29 patterns, and three of them change who owns input mid-round: the callout wheel keeps movement live but captures look (P6), the in-round overlay stops movement but not the round (P15), and modal dialogs take everything (P16, P29). Godot's GUI consumes events for focused `Control`s, but polling (`Input.get_vector`, `is_action_pressed`) does not see that consumption, so without one owner a player navigating the overlay with WASD would also walk. No ADR fixed how UI reads round state, how focus is set and restored, where the mouse mode is written, or how AccessKit names are supplied (architecture gaps TR-ui-001 and TR-ui-002; TR-index-012 HUD half).

### Constraints
- Client UI knows only what ADR-0004 projected; the HUD never distinguishes a real from a fake (control manifest).
- No gameplay autoloads (ADR-0005 §6); client services are injected by a client composition root.
- Device detection by event type or `DEVICE_ID_*`, never `device == 0` (ADR-0007).
- Menus work by mouse, keyboard and gamepad (P17); every visible string goes through `tr()`.

### Requirements
- Exactly one place decides whether gameplay input, look, and the mouse cursor are live.
- Opening and closing any screen restores focus and input ownership exactly.
- HUD elements update from data, never poll gameplay modules.
- Screen-reader names and live regions on every menu control and on the feed.

## Decision

**1. Input contexts.** A client `InputContextStack` (`RefCounted`, injected by the client root) holds a stack of contexts. Each context declares four flags: `move` (movement and gait actions reach the input frame), `look` (mouse and right-stick look reach the camera), `actions` (interact, item, ping, wheel), and `cursor` (mouse visible). The top context wins:

| Context | Pushed by | move | look | actions | cursor |
|---|---|---|---|---|---|
| `GAMEPLAY` | Round start (base) | yes | yes | yes | no |
| `WHEEL` | Callout wheel open (P6) | yes | no (look steers the wheel) | no | no |
| `OVERLAY` | In-round menu (P15) | no | no | no | yes |
| `MENU` | Main menu, lobby, results, spectator menus (base outside a round) | no | no | no | yes |
| `MODAL` | P16, P29 dialogs | no | no | no | yes |

`push(ctx, owner_control)` and `pop(ctx)` are the only entry points; a pop must name the context it removes, so a stale pop is an error, not a silent removal of someone else's context. The stack resets to `GAMEPLAY` at round start and to `MENU` at round end and on return to the lobby, so a stale `OVERLAY` cannot persist (amended 2026-10-12 for architecture review 12d, AD-50).

**2. Gameplay mask.** The ADR-0002 input sampler builds each input frame from polled action state and then applies the top context's flags: `move` off sends a zero move vector and clears sprint and crouch; `actions` off clears the interact bit and blocks item, ping and callout RPCs, except that the callout wheel's own send is allowed while `WHEEL` is on top (the wheel sends, then pops) (amended 2026-10-12 for architecture review 12d, AD-50); `look` off freezes yaw and pitch at their last value. A hold in progress is released by the cleared interact bit, and ADR-0008 cancels it on the server as for any release.

**3. Mouse mode.** `InputContextStack` is the only code that writes `Input.mouse_mode`: `MOUSE_MODE_CAPTURED` when the top context has `cursor` off, `MOUSE_MODE_VISIBLE` otherwise. The mode is re-applied on `NOTIFICATION_APPLICATION_FOCUS_IN` (the client root forwards it), because alt-tab drops the capture. The first relative motion after a switch back to captured, or after focus returns, is discarded (Verification 4; the jump is NOT SOURCEABLE in the reference). Event-driven gameplay handlers (`_unhandled_input`) also check `allows_actions()`, so a menu key that the GUI did not consume cannot reach gameplay.

**4. Layers.** UI lives on fixed `CanvasLayer`s, numbered in one `UiLayers` constants class like `PhysicsLayers`: `WORLD_MARKERS` (1), `HUD` (2), `SCARE_FX` (3, ADR-0015), `CAPTIONS` (4), `OVERLAY` (10), `MODAL` (20); captions sit above scare flashes so they stay readable (amended for ADR-0015, AD-49). A context push shows its layer's root and a pop hides it before focus is restored; nothing else changes layer visibility. Hiding a `CanvasLayer` hides its whole subtree, and focus inside it is lost.

**5. Focus.** Menus use stock `Control` focus (P17): `focus_neighbor_*`, one theme-level `focus` stylebox (shape, not colour alone), and `grab_focus()` on the screen's declared default control when its context is pushed. The client root injects the root `Viewport` into the stack (a `RefCounted` has no `get_viewport()`). A push shows the layer first and then grabs focus, with `call_deferred` if the screen was instanced this frame, because `grab_focus()` fails on a control not visible in the tree. On push the stack remembers `viewport.gui_get_focus_owner()`; on pop it restores that control only if `is_instance_valid` and `is_visible_in_tree()`, else the lower screen's default control, because a hidden control loses focus and a mouse click may have moved it. HUD and world-marker `Control`s set `focus_mode = FOCUS_NONE` and `mouse_filter = MOUSE_FILTER_IGNORE`, so they never take focus or clicks. Mouse hover and keyboard focus are separate since 4.6; nothing moves keyboard focus on hover.

**6. HUD data.** A client `HudModel` (`RefCounted`) is the HUD's only source. It is fed by two writers: the snapshot handler (own body state, gait, hold progress echo) and `ClientEventRouter` dispatch (objective progress, feed lines, markers, cooldowns, `RoundEnded`). It exposes typed getters and one signal per element group (`objectives_changed`, `feed_line_added`, `marker_changed`, `cooldowns_changed`, `own_state_changed`). HUD widgets are views: they connect to those signals and read getters, and never hold a gameplay module, the snapshot, or the router. The predicted hold bar (P3) is driven locally from the hold start the client sent (ADR-0008) and replaced by the server echo.

**7. World markers.** Markers (P7) are `Control`s on `WORLD_MARKERS`, positioned each frame from `Camera3D.unproject_position`, and clamped to a screen-edge inset with a direction arrow when off-screen. A target behind the camera (`is_position_behind`) is never hidden: its offset from screen centre is negated, because `unproject_position` mirrors it, and clamped to the edge, so the marker still points the right way (TR-pings-005) (amended 2026-10-12 for architecture review 12d, AD-50). Marker data comes only from `HudModel`.

**8. Glyphs.** An `InputGlyphs` helper (P18) maps an action to the glyph of its first `InputMap` event for the last-used device class; the device class switches on the event type (`InputEventKey`/`InputEventMouse*` vs `InputEventJoypad*`), never on `device == 0`. It reads the live `InputMap`, so remapped bindings show without restart.

**9. Accessibility.** Every focusable `Control` without its own visible text sets `accessibility_name` from a `tr()` key and re-applies it on `NOTIFICATION_TRANSLATION_CHANGED` (buttons and labels already expose their text); the callout feed (P9) and caption line (H18) are polite live regions (`accessibility_live`, typed `AccessibilityServer.AccessibilityLiveMode` in 4.7); countdowns are never live regions. UI scale is applied once through `Window.content_scale_factor` from the player's setting, with the project's stretch mode set explicitly to `canvas_items` and aspect `expand` (the 4.7 new-project defaults, `breaking-changes.md`; `project.godot` sets neither today). Every visible string goes through `tr()`.

### Architecture Diagram

```
ClientRoot (client composition root, no autoloads)
 ├─ InputContextStack ──▶ Input.mouse_mode (sole writer)
 │        │ top context flags
 │        ▼
 ├─ InputSampler (ADR-0002) ── masked frame ──▶ Network
 ├─ HudModel ◀── snapshot handler, ClientEventRouter (ADR-0005 §7)
 │        │ typed signals + getters
 │        ▼
 └─ CanvasLayers: WORLD_MARKERS(1) HUD(2) SCARE_FX(3) CAPTIONS(4) OVERLAY(10) MODAL(20)
          HUD widgets / markers (FOCUS_NONE, MOUSE_FILTER_IGNORE)
          screens push/pop contexts and grab_focus on push
```

### Key Interfaces

```gdscript
class_name InputContextStack extends RefCounted
enum Ctx { GAMEPLAY, WHEEL, OVERLAY, MENU, MODAL }
signal top_changed(ctx: Ctx)
func push(ctx: Ctx, focus_owner: Control) -> void   # grabs focus on focus_owner if not null
func pop(ctx: Ctx) -> void                          # error if ctx is not on top; restores previous focus
func allows_move() -> bool
func allows_look() -> bool
func allows_actions() -> bool

class_name UiLayers extends RefCounted
const WORLD_MARKERS := 1
const HUD := 2
const SCARE_FX := 3
const CAPTIONS := 4
const OVERLAY := 10
const MODAL := 20

class_name HudModel extends RefCounted
signal objectives_changed
signal feed_line_added(line: Dictionary)
signal marker_changed(marker_id: int)
signal cooldowns_changed
signal own_state_changed
func objective_lines() -> Array[Dictionary]
func markers() -> Array[Dictionary]
func cooldown_remaining_s(ability: StringName) -> float   # 0.0 when unknown; returns on every branch

class_name InputGlyphs extends RefCounted
func glyph_for(action: StringName) -> Texture2D
func note_event(event: InputEvent) -> void   # switches device class by event type
```

### Implementation Guidelines
- `InputContextStack` **must** be the only writer of `Input.mouse_mode`.
- The input sampler **must** apply the top context's flags to every frame it sends; UI code **must never** send intent or block input any other way.
- Every screen **must** push its context when shown and pop the same context when hidden; a pop of a context that is not on top **must** raise an error.
- HUD widgets **must** read only `HudModel`; they **must never** hold a gameplay module, the snapshot or `ClientEventRouter`.
- HUD and world-marker `Control`s **must** set `focus_mode = FOCUS_NONE` and `mouse_filter = MOUSE_FILTER_IGNORE`.
- Menus **must** use stock `Control` focus and the theme focus stylebox; custom-drawn widgets that bypass `Control` focus **must never** be used.
- Device class **must** be detected by event type or `InputEvent.DEVICE_ID_*`, never `device == 0`.
- Every focusable `Control` **must** set `accessibility_name` from a `tr()` key; countdowns **must never** be live regions.
- Every visible string **must** go through `tr()`.
- Layer numbers **must** come from `UiLayers`.

## Alternatives Considered

### Alternative 1: Each screen sets mouse mode and blocks input itself
- **Description**: The overlay, wheel and dialogs each call `Input.mouse_mode` and set a "blocked" flag the sampler reads.
- **Pros**: No new class.
- **Cons**: Two screens open at once (overlay then a confirm dialog) leave the mouse and mask in whichever state the last closer wrote.
- **Rejection Reason**: Nested screens are the normal case (P15 → P29).

### Alternative 2: Rely on GUI event consumption alone
- **Description**: Gameplay reads input only in `_unhandled_input`, so focused `Control`s consume keys first.
- **Pros**: Uses the engine's propagation.
- **Cons**: Movement is sampled by polling every tick (ADR-0002), and polling does not see consumption; P6 needs movement live while look is taken, which consumption cannot express.
- **Rejection Reason**: Does not cover the sampler or the wheel.

### Alternative 3: HUD widgets subscribe to `ClientEventRouter` directly
- **Description**: Each widget registers for the payload types it shows.
- **Pros**: No model class.
- **Cons**: Snapshot-driven elements need a second path; widgets duplicate parsing; tests need a router.
- **Rejection Reason**: One model gives one test seam.

## Consequences

### Positive
- One owner for input, mouse and focus; nested screens restore exactly.
- HUD testable without a network: feed `HudModel`, assert widget state.

### Negative
- Every screen carries a push/pop pair; a missed pop leaves the player unable to move (mitigated by the error on stale pop and a round-start reset to `GAMEPLAY`).

## Risks
- **Dual-focus surprises (4.6).** Mitigation: Verification 2 on every menu screen.
- **AccessKit coverage on Windows is NOT SOURCEABLE in the reference.** Mitigation: Verification 3 with NVDA; the accessibility doc's commitments stand either way.
- **Polling vs consumption assumption wrong.** If Verification 1 shows polling respects consumption, the mask still holds and costs nothing.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| pings-and-callouts.md | TR-pings-004 (feed line and arrow), TR-pings-005 (markers through walls with direction and distance); rules 10–14 wheel keeps movement live | §6 `HudModel`, §7 markers, §1 `WHEEL` context |
| systems-index.md | TR-index-012 (HUD and Results Screen half): UI consumes contracts other systems expose | §6 `HudModel` fed only by projected data |
| lobby-role-assignment.md | Lobby screen (architecture gap TR-ui-002): host/join, ready, picker, queue, countdown display (TR-lobby-007 clients display only) | §1 `MENU`, §5 focus, §9 accessibility |
| first-person-controller.md | TR-controller-013: InputMap actions, device IDs not 0 | §2 mask on polled actions, §8 glyphs by event type |
| accessibility-requirements.md | Remapping, UI scale, screen reader, captions | §8, §9 |
| design/ux/interaction-patterns.md | P6, P15, P16, P17, P18, P29 | §1–5, §8 |

## Performance Implications
- **CPU**: Flag checks per frame; marker projection per frame (Verification 5).
- **Memory**: A few `CanvasLayer` trees.
- **Load Time**: None beyond scene load.
- **Network**: None; the mask only zeroes fields already sent.

## Migration Plan
No code exists yet.

## Validation Criteria
- With the overlay open, holding W for 2 s moves the body 0 m on the server.
- With the wheel open, W moves the body and mouse motion does not turn it.
- Overlay → Leave → Cancel returns focus to the Leave button and the overlay context; closing the overlay returns to captured mouse and `GAMEPLAY`.
- A unit test feeds `HudModel` a scripted payload sequence and asserts each signal fires once per change.

## Related
- ADR-0002 (input sampling), ADR-0004 (projection), ADR-0005 (client router, no autoloads), ADR-0007 (device IDs), ADR-0008 (holds), ADR-0011 (results payload)
- `design/ux/hud.md`, `design/ux/results.md`, `design/ux/interaction-patterns.md`, `design/accessibility-requirements.md`
