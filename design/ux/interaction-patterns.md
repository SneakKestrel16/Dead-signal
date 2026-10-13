# Interaction Pattern Library

> **Status**: Draft (all sections authored)
> **Author**: SneakKestrel16 + ux-designer
> **Last Updated**: 2026-10-12
> **Template**: Interaction Pattern Library

---

## Overview

This library defines the reusable interaction patterns of Dead Signal, so the HUD, lobby, results and settings specs reference one definition instead of reinventing it. No screen spec exists yet, so the patterns are extracted from the UI Requirements of the approved GDDs and from `design/accessibility-requirements.md` (Standard tier). Input is keyboard/mouse first, gamepad Partial, PC only (`technical-preferences.md`).

Three rules apply to every pattern:

1. **Server truth, local prediction.** Anything that shows game state comes from replicated server state. The only thing a client may predict is its own action (its hold bar, its door toggle), and the server can cancel it (`first-person-controller.md` rule 13, ADR-0002).
2. **Information parity.** No pattern may show a player something their character could not perceive, or distinguish a real action from a fake one (`scare-events.md` rule 28; `monster-abilities.md` False Signal; ADR-0004). Fake interactions, fake callouts and a disguised body must use exactly the same pattern as the real thing.
3. **Never block the body.** No UI pattern pauses the round or takes movement control. Wheels, feeds and the settings overlay all leave movement live (`pings-and-callouts.md` Game Feel).

Accessibility minimums (text size, contrast, colour backups, toggles) come from `design/accessibility-requirements.md` and are restated per pattern only where they change the pattern's behaviour.

---

## Pattern Catalog

| # | Pattern | Category | One-line description | Used by |
|---|---|---|---|---|
| P1 | Hold-to-Interact | Input | Timed, server-validated hold on a world target, with a Hold/Toggle mode | Objectives, rescue, hide, barricade, search, break, backup switch |
| P2 | Interaction Prompt | Feedback | Action name and bound input, shown only for a valid target | All interactables incl. instant doors and the monitor |
| P3 | Radial Hold Bar | Feedback | The actor's own progress ring at the crosshair, predicted, with cancel cause | P1 actors |
| P4 | World Progress Bar | Data display | Server-truth progress above an object, for nearby survivors | Objectives, rescue, barricade |
| P5 | Ping | Input | One press on the aimed point, object or player places a marker | Survivors, disguised shapeshifter, Downed survivors |
| P6 | Callout Wheel | Input | Radial menu of 8 authored lines; movement stays live | Survivors, disguised shapeshifter |
| P7 | World Marker | Data display | World-anchored icon with label, clamped to the screen edge off-screen | Pings, Downed marker, discovered points, dropped items, install alert |
| P8 | Screen-Edge Indicator | Feedback | Directional cue at the screen edge toward a source in range | Lunge wind-up, transform distortion, flinch-off pulse |
| P9 | Text Feed | Data display | Short-lived lines at the screen edge with scrollback | Callout feed, escape/disconnect feed |
| P10 | Rejection Feedback | Feedback | A local, visible reason when an action is refused | Ping rate limit, refused interaction, refused ability |
| P11 | State Vignette | Feedback | Full-screen edge treatment for one's own Seized/Downed/shocked state | Victim's own view |
| P12 | Persistent Checklist | Data display | Always-visible, zero-press objective state | Survivor and shapeshifter HUD |
| P13 | Cooldown Readout | Data display | Ability icon with remaining time | Shapeshifter HUD, taser cartridges |
| P14 | Aim-and-Confirm Placement | Input | Preview while aiming, confirm to cast | False Signal, Blackout |
| P15 | Non-Pausing Overlay | Overlay | Settings and help over a live round | In-round menu |
| P16 | Blocking Reason Dialog | Modal | A reason that needs acknowledgement before continuing | Join reject, session closed, kicked |
| P17 | Dual-Device Menu Focus | Navigation | Menus work by mouse, keyboard and gamepad focus | Main menu, lobby, settings, results |
| P18 | Input Glyph Switching | Feedback | Prompts show the glyph of the last-used device | Every prompt |
| P19 | Button | Standard control | Primary, secondary and destructive buttons | All menus |
| P20 | Toggle | Standard control | Binary setting with an explicit on/off label | Settings, lobby voice setting |
| P21 | Slider | Standard control | Continuous value with a number readout | Volumes, flash scale, head-bob, UI scale |
| P22 | Dropdown | Standard control | One choice from a short list | Resolution, colourblind mode, Hold/Toggle modes |
| P23 | List | Standard control | Vertical focusable rows | Lobby player list, rotation queue, results rows |
| P24 | Grid | Standard control | Fixed tiles with a selection state | Character picker C1–C5 |
| P25 | Tooltip | Standard control | Help text on focus or hover | Settings explanations |
| P26 | Input Field | Standard control | Single-line text entry with validation | Host/join address, port, display name |
| P27 | Tab Bar | Standard control | Top-level sections of one screen | Settings (Video, Audio, Controls, Accessibility) |
| P28 | Scroll Container | Standard control | Vertical scrolling region | Settings pages, help, results |
| P29 | Confirm Dialog | Modal | Two-button confirm for a destructive action, safe option focused | Leave session (results, lobby), Leave match, Kick |

---

## Patterns

### P1 Hold-to-Interact

**Category**: Input
**Used In**: HUD (in-round); every interactable in `survivor-objectives.md`, `downing-and-rescue.md`, `survivor-defense.md` rule 28a, Facility Map backup switch

**Description**: The one way a player "does a thing" that takes time. The player aims at a target and holds the interact input; the server starts, advances and completes the hold, and cancels it on hit, shock, range, sight loss, state change or input release (`first-person-controller.md` rules 11–16, ADR-0008). Durations are balance values and never change per player. A Hold/Toggle setting (accessibility, Motor) changes only how the input is held, not the rules.

**Specification**:
- Start: press interact while P2 shows a prompt. The client sends the interact bit and target; nothing changes until the server accepts.
- Hold mode: releasing the input cancels. Toggle mode: the first press starts, and the hold continues until a second press, an invalid target or any server cancel; the client keeps sending the interact bit. The server cannot tell the modes apart.
- Feedback: P3 for the actor, P4 for nearby survivors, the owning system's interact loop sound.
- Rooting holds (rescue) show no extra UI; movement input is simply ignored.
- Instant interactions (doors, the monitor) use P2 only, with no bar.
- A shapeshifter's fake interaction plays the same animation and loop and shows P3 to itself only; P4 does not move for anyone (`survivor-objectives.md` rule 25).
- Accessibility: Hold/Toggle per input group; the prompt names the current mode's verb ("Hold E" / "Press E").

**Implementation**: `HoldService` (ADR-0008) owns timing; the client sets `InputFrame.interact` + target each tick; Hold/Toggle is client input handling only.

**When to Use**: Any action whose GDD gives it a `duration_s` above 0.
**When NOT to Use**: Instant actions (use P2 alone); abilities (P14); pings and callouts (P5, P6).

### P2 Interaction Prompt

**Category**: Feedback
**Used In**: HUD (in-round)

**Description**: Tells the player what interact will do on the current target. It appears only when the target is valid for this player now (in range along the view ray, eligible, not locked), so a prompt is a promise that pressing will start (`first-person-controller.md` rule 12 and UI Requirements).

**Specification**:
- Text: verb + object ("Extract drive", "Rescue", "Barricade"), plus the input glyph (P18) and, for P1 targets, "Hold" or "Press" by the player's mode.
- Position: below the crosshair; one prompt at a time (nearest target along the ray).
- Disappears the tick the target becomes invalid; never shows for an out-of-range target behind a valid one.
- Disguised shapeshifter: the same prompts a survivor would see for objectives (fakes look identical to the actor), and none for actions a disguise is refused (`borrowed-face.md` permissions).
- Accessibility: 20 px minimum, 4.5:1 contrast with a backing plate.

**Implementation**: `Label` under the crosshair, fed by the client's local `interactable_on_ray` (ADR-0007) and the replicated eligibility it can see; hidden on server reject.

**When to Use**: Every interactable, including instant doors.
**When NOT to Use**: Pings (any surface is pingable; no prompt).

### P3 Radial Hold Bar

**Category**: Feedback
**Used In**: HUD (in-round)

**Description**: The actor's own progress ring around the crosshair. It is predicted locally so it responds within 100 ms (`survivor-objectives.md` Game Feel), and the server confirms or cancels it.

**Specification**:
- Fills over the interaction's `duration_s`, starting from the owner's stored progress where the rule keeps progress (rescue keeps and decays).
- On a server cancel, the ring empties and a short cause label shows for 1 s: "Hit", "Shocked", "Moved away", "Lost sight", "Released", "Taken" (lock lost). A reset is never silent (`first-person-controller.md` UI Requirements).
- On completion: a brief fill flash (at flash scale; no flash at scale 0) and the owner's completion sound.
- Shape, not colour, signals state: a cancelled ring breaks into segments.

**Implementation**: `TextureProgressBar` (radial fill) driven by local prediction; reset by the server cancel event carrying the reason code.

**When to Use**: The actor's view of any P1 hold.
**When NOT to Use**: Other players' progress (P4); the shapeshifter's transform (P13 Transforming bar on its HUD).

### P4 World Progress Bar

**Category**: Data display
**Used In**: World space over objectives, Downed survivors under rescue, barricadable doors

**Description**: Server-truth progress anchored above the object, visible to survivors nearby. It is the verifiable tell against fake interactions: a fake never moves it (`survivor-objectives.md` rules 25–27).

**Specification**:
- Driven only by replicated server progress; never predicted.
- Visible to survivors whose relevance set includes the object (ADR-0004); hidden from the shapeshifter's HUD for objective progress it cannot affect except where a GDD shows it (break progress on a barricade it is breaking).
- Activation countdown (`survivor-objectives.md`): the bar shows a paused state with a "Paused" label when no Healthy survivor holds the zone.
- Rescue: the ring on the Downed marker shows rescue progress and bleed-out (`downing-and-rescue.md` UI Requirements); the monster never sees either.

- Accessibility: progress shown as fill plus a percentage number; "Paused" is text, not colour.

**Implementation**: World-space `Sprite3D` or `Label3D` above the object, from replicated objective, rescue or barricade state (ADR-0004 relevance).

**When to Use**: Any persistent progress other players need to verify.
**When NOT to Use**: The actor's own feedback (P3).

### P5 Ping

**Category**: Input
**Used In**: HUD (in-round)

**Description**: One press places a short-lived marker on whatever the view ray hits: a point, a pingable object (typed: drive, fuse, terminal) or a player (warning). One press, one unambiguous meaning (`pings-and-callouts.md`).

**Specification**:
- Input: the ping action, one press. The type is inferred from the target. A warning ping on a point is its own bindable action, "Warning ping"; a double press of the ping action within 0.4 s is an optional shortcut that can be turned off, so no warning needs a timed input (Standard tier; ux-review 2026-10-12).
- The server validates (alive, state, rate limit, range 40 m, line of sight) and attaches the sender's displayed identity. Result is a P7 marker for recipients.
- Rejected: P10 near the crosshair ("Too many pings", "Out of range"); a rejection to the monster gives the sender no signal (`pings-and-callouts.md` rule 7).
- Movement never stops.
- Accessibility: types are icon shapes, not colours alone.

**Implementation**: Reliable intent RPC with the frame `seq` (ADR-0002 §3); markers arrive as projected events (ADR-0004, ADR-0005).

**When to Use**: Marking a location, object or player for the team.
**When NOT to Use**: Messages with meaning beyond "here" or "this" (P6).

### P6 Callout Wheel

**Category**: Input
**Used In**: HUD (in-round)

**Description**: A radial menu of the 8 authored callout lines, opened at screen centre without pausing movement (`pings-and-callouts.md` rules 10–14, Game Feel).

**Specification**:
- Hold mode: hold the wheel input to open, aim with the mouse or right stick, release to send; release in the centre dead zone cancels.
- Toggle mode: press to open, click or press confirm to send, press the wheel input again to cancel.
- Opens in 50 ms; segments greyed and labelled "Cooldown" while the global or per-line block applies (rate-limit state from the server).
- Movement stays live; mouse look is captured by the wheel while open (inference: the player can still strafe and walk, not turn).
- Not available in blocking states (`pings-and-callouts.md` States): the input does nothing and shows P10 once.
- Accessibility: every segment has text and an icon; 8 segments maximum.

**Implementation**: Full-screen `Control` with 8 segments; reads the per-line cooldown state the server replicates to the sender.

**When to Use**: Sending an authored line.
**When NOT to Use**: Free text or voice (no free text exists).

### P7 World Marker

**Category**: Data display
**Used In**: Pings, Downed marker, discovered objective points, dropped items, monster install alert

**Description**: An icon anchored to a world point, with a label, visible through walls to its intended recipients and clamped to the screen edge when off-screen.

**Specification**:
- Content: type icon, label (sender name for pings, "Downed" + bleed-out ring for the Downed marker, object name for points), distance in metres.
- Off-screen: clamped to the nearest screen edge with an arrow pointing to it.
- Lifetime: by the owning rule (pings `ping_lifetime_s` 8; Downed marker while Downed; discovered points until consumed; install alert 5 s with a randomised centre, monster only).
- Recipients only: a marker is never drawn for a player the owning rule excludes (the monster never sees Downed markers or bleed-out).
- "(not you)" mark on a ping shown under your own name that you did not send, by the range rule (`pings-and-callouts.md` rule 27).
- Scales with HUD scale (accessibility).

**Implementation**: `Control` overlay placed with `Camera3D.unproject_position`, clamped to a screen-edge rect; one node per active marker.

**When to Use**: Anything a player must find in the world.
**When NOT to Use**: Directional sound cues (P8): a marker gives a position, an edge cue gives only a direction.

### P8 Screen-Edge Indicator

**Category**: Feedback
**Used In**: Lunge wind-up cue, transform distortion, flinch-off substitute pulse

**Description**: A short directional mark on the screen edge toward a source. It is the visual backup for deduction-critical sounds and the replacement for the camera flinch when that is turned off (`design/accessibility-requirements.md` Auditory; `scare-events.md` rule 27).

**Specification**:
- Shown only while the player is within the source's audible range and for the sound's duration; nothing outside range (information parity).
- Direction only, no distance, no marker in the world.
- Distinct shapes per source: lunge = sharp chevron, transform = wavering arc, flinch pulse = soft glow; not colour-coded alone.
- Flicker-free: no luminance flashing; respects flash scale.

**Implementation**: `Control` overlay on the HUD layer, driven by projected cue events (ADR-0004 §6) with direction only.

**When to Use**: A sound or scare the player must react to whose source may be off-screen.
**When NOT to Use**: Footsteps, interaction noise, False Signal sounds (deliberately audio-only).

### P9 Text Feed

**Category**: Data display
**Used In**: Callout feed (`pings-and-callouts.md`), escape/disconnect feed (`match-flow.md`)

**Description**: Lines that appear at the screen edge, newest at the bottom, fading after a delay; a scrollback opens without pausing play.

**Specification**:
- Callout line: `[Name]: [text]` plus a direction arrow toward the speaker, shown to survivors in range; the monster gets no line (rule 11). Fake callouts use the same format (rule 26).
- Shows the last 4 lines (`pings-and-callouts.md` UI Requirements); each line stays at least 8 s.
- Scrollback: one key shows the last 10 lines for as long as it is held (or toggled); movement stays live.
- 28 px minimum, 7:1 contrast on an opaque backing (accessibility).

**Implementation**: `VBoxContainer` of `Label`s with timers; scrollback is a second container showing the retained 10 lines.

**When to Use**: Discrete events a player may need to re-read.
**When NOT to Use**: Persistent state (P12).

### P10 Rejection Feedback

**Category**: Feedback
**Used In**: Pings, callouts, interactions, abilities

**Description**: When the server or the client refuses an action, the actor sees why, briefly, near the crosshair. A failure is never silent (`pings-and-callouts.md` Game Feel).

**Specification**:
- Short text ("Cooldown 3 s", "Too far", "Can't while hidden") and a soft deny sound; 1.5 s.
- Only the actor sees it; it never reveals hidden state (a ping refused because the monster cannot see the target shows no reason at all, by design).
- No modal, no pause.

- Accessibility: text plus a deny sound; never colour alone; 20 px minimum.

**Implementation**: One shared `Label` near the crosshair; reason codes map to localised strings.

**When to Use**: Any refused player request.
**When NOT to Use**: Server cancels of a running hold (P3 cause label).

### P11 State Vignette

**Category**: Feedback
**Used In**: Victim's own view (Seized, Downed, shocked)

**Description**: A full-screen edge treatment that makes one's own state unmistakable (`downing-and-rescue.md` UI Requirements).

**Specification**:
- Seized: tight dark edges; Downed: desaturated edges with the bleed-out readout on the HUD; shocked: brief edge jitter (visual offset only; the view direction is untouched, `first-person-controller.md` rule 7).
- Shown on change, removed on change; no flashing; respects reduced motion (jitter off).
- A text label accompanies each state for players who cannot read the treatment.

**Implementation**: `ColorRect` with a shader on a full-screen `CanvasLayer`, switched by the player's own replicated life state.

**When to Use**: The player's own incapacitating state.
**When NOT to Use**: Other players' states (P7, P4).

### P12 Persistent Checklist

**Category**: Data display
**Used In**: Survivor HUD, shapeshifter HUD

**Description**: The always-visible objective state: drives x/2 (with carriers), fuses x/2, terminal state, activation countdown (`survivor-objectives.md` UI Requirements). Zero presses to read.

**Specification**:
- Side panel; updates on `ObjectiveProgressChanged` only; server state only, so it is always true.
- Carriers shown by name next to teammate names; never shows a carried item on a disguise.
- The clock and phase label sit top centre (`match-flow.md`), with the phase as text.
- Teammate roster with life state (Healthy / Downed / Eliminated) for survivors (`downing-and-rescue.md`).

- Accessibility: 20 px minimum; states as words or icons ("Docked", "Carried by ..."), never colour alone; scales with HUD scale.

**Implementation**: `VBoxContainer` side panel bound to `ObjectiveProgressChanged` projections and the roster.

**When to Use**: State that drives "what next".
**When NOT to Use**: Transient events (P9).

### P13 Cooldown Readout

**Category**: Data display
**Used In**: Shapeshifter HUD (Lunge, False Signal, Blackout, form change, Transforming progress, stun/immunity); survivor item slot (taser cartridges)

**Description**: An icon per ability or item with remaining time or count.

**Specification**:
- Remaining time as a number plus a sweep; updated every 0.1 s (`monster-abilities.md` UI Requirements).
- Ready state signalled by shape change and a soft cue, not colour alone.
- Shapeshifter-only readouts never render on survivor clients (`borrowed-face.md`: survivors get no disguise UI).

**Implementation**: `TextureProgressBar` + `Label` per ability; times from replicated cooldown-end ticks and the client tick estimate (ADR-0002 §7).

**When to Use**: Any resource that recharges or depletes.
**When NOT to Use**: Hold progress (P3).

### P14 Aim-and-Confirm Placement

**Category**: Input
**Used In**: False Signal, Blackout (shapeshifter)

**Description**: Hold the ability input to show a placement preview where the view ray lands; release (or press confirm in toggle mode) to cast; a cancel input aborts at no cost (`monster-abilities.md` UI Requirements).

**Specification**:
- Preview: False Signal shows the snapped floor point and the truncated footstep path; Blackout highlights the target lighting volume. Shapeshifter only.
- An invalid target shows the preview crossed out with a reason (P10); releasing on it does nothing and costs no cooldown.
- Movement stays live while aiming.

- Accessibility: Hold/Toggle mode as in P6; an invalid preview is crossed out (shape), not only recoloured.

**Implementation**: Client-side preview from local raycasts; the server re-validates on cast (`monster-abilities.md`).

**When to Use**: Abilities with a chosen target point.
**When NOT to Use**: The lunge (direction is the view; no preview).

### P15 Non-Pausing Overlay

**Category**: Overlay
**Used In**: In-round menu (settings, help, controls, leave)

**Description**: The in-round menu opens over a live round. The round does not pause; the player's character stands still while the overlay has input focus (the client sends empty movement intent) **(proposed)**.

**Specification**:
- Opens with Esc / Start; closes with the same input.
- Every accessibility setting is available and applies at once; the flinch toggle is sent to the server on change.
- A persistent label says "The round continues".
- Help page: controls, hold rules, ping types, what a disguise copies.

- Accessibility: fully navigable by keyboard and gamepad (P17); every setting labelled; no timeouts.

**Implementation**: `CanvasLayer` above the HUD; while open the client sends zero movement intent.

**When to Use**: Anything a player may need mid-round that is not gameplay.
**When NOT to Use**: Gameplay choices (none are menu-driven).

### P16 Blocking Reason Dialog

**Category**: Modal
**Used In**: Join reject (`lobby_full`, `round_in_progress`, `version_mismatch`), session closed by host, kicked

**Description**: A modal with the reason in plain words and one acknowledge button; never auto-dismisses (`lobby-role-assignment.md` rules 2, 3, 19; ADR-0001 reject codes).

**Specification**:
- Title, one-sentence reason, and for `version_mismatch` both version strings.
- One button ("OK") returns to the main menu or lobby.
- Keyboard and gamepad focus starts on the button.

**Implementation**: `AcceptDialog` (stock `Control`), text from the ADR-0001 reject code.

**When to Use**: Outside a round, when the player must know why something ended.
**When NOT to Use**: In-round events (P9, P10).

### P17 Dual-Device Menu Focus

**Category**: Navigation
**Used In**: Main menu, host/join form, lobby, settings, results

**Description**: Menus built from stock Godot `Control` nodes, navigable by mouse, by keyboard (Tab / arrows / Enter / Esc) and by gamepad focus, so remapping, AccessKit exposure and Partial gamepad support all work from one build (`design/accessibility-requirements.md` Platform; `modules/ui.md`).

**Specification**:
- Every interactive control has a focus neighbour and a visible focus ring (shape, not colour alone).
- Back is always Esc / B; confirm is Enter / A.
- No custom-drawn widgets that bypass `Control` focus.
- Whether every menu must be gamepad-complete is an open question (Partial support).

**Implementation**: Stock `Control` focus (`focus_neighbor_*`, `grab_focus`) and a theme-level focus stylebox.

**When to Use**: Every menu screen.
**When NOT to Use**: The in-round HUD (not focusable; P15 is the in-round menu).

### P18 Input Glyph Switching

**Category**: Feedback
**Used In**: Every prompt and help page

**Description**: Prompts show the binding of the last-used device, using the player's remapped bindings (`design/accessibility-requirements.md` Motor).

**Specification**:
- Switches on the first input from the other device; no restart.
- Shows the remapped binding, never the default.
- Device detection by event type, never `device == 0` (ADR-0007).

**Implementation**: Glyph lookup from the active `InputMap` events per action; switch on the last `InputEvent` type.

**When to Use**: Any text that names an input.
**When NOT to Use**: —

### Standard Controls (P19–P28)

All standard controls are stock Godot `Control` nodes styled by one project `Theme`, so focus, remapping and AccessKit exposure work everywhere (P17). Shared rules: a visible focus ring (shape, not colour alone), mouse hover moves focus, confirm = Enter / A, back = Esc / B, 24 px minimum menu text, 4.5:1 contrast, and nothing acts on hover alone.

| Pattern | States | Behaviour | Accessibility | Implementation | When NOT to Use |
|---|---|---|---|---|---|
| P19 Button | Normal, focused, pressed, disabled (with reason tooltip) | Activates on release; destructive buttons (Leave match, Kick, Leave session) confirm once with a P29 dialog | Label text always; a disabled button says why | `Button` | Settings that hold a value (P20–P22) |
| P20 Toggle | Off, on, focused, disabled | Confirm flips; "On" / "Off" shown as text beside the switch | State as text, not colour | `CheckButton` | More than two values (P22) |
| P21 Slider | Value, focused, dragging | Left/right or D-pad in 5% steps; mouse drag; live preview where safe (volumes, flash scale) | Numeric readout always visible | `HSlider` + `Label` | Discrete choices (P22) |
| P22 Dropdown | Closed, open, focused | Confirm opens; up/down moves; confirm selects; back closes unchanged | Current value shown as text when closed | `OptionButton` | Two values (P20) |
| P23 List | Row normal, focused, selected | Up/down moves focus; text first, icons second | Host and Ready marked by words, readable without icons | `ItemList` or `VBoxContainer` of rows | Choosing among visual tiles (P24) |
| P24 Grid | Tile available, focused, selected, locked (taken, or while Ready) | Arrows / D-pad move; confirm selects; locked tiles say why | Characters identified by name and silhouette, not colour alone (accessibility Visual) | `GridContainer` of `Button`s | Long text items (P23) |
| P25 Tooltip | Hidden, shown | Shows on focus (keyboard/gamepad) or after 0.5 s hover; never carries required information | 20 px minimum; dismissed on focus change | `tooltip_text` or a custom tooltip | Anything the player must know to proceed |
| P26 Input Field | Empty (placeholder), focused, valid, invalid (inline reason) | Validates on change (name 1–16 chars, port range); Enter submits the form | Error text beside the field, not colour alone | `LineEdit` | In-round text (none exists) |
| P27 Tab Bar | Tab normal, focused, current | Q/E or LB/RB switch tabs; click selects | Current tab marked by underline shape and weight | `TabContainer` / `TabBar` | Fewer than three sections |
| P28 Scroll Container | At top, scrolled, at bottom | Focus moving off-screen scrolls into view; mouse wheel; right stick | Scrollbar visible whenever content overflows | `ScrollContainer` | Content that fits one screen |
| P29 Confirm Dialog | Open, focus on safe button, focus on destructive button | Question plus two buttons (destructive named by its action, e.g. "Leave", safe "Stay"); focus starts on the safe button; Esc / B = safe; closes itself without acting if its context ends (e.g. the results countdown reaches 0) | Dialog title and buttons announced; destructive button never default | `ConfirmationDialog` | Acknowledge-only reasons (P16) |

### Animation Standards

| Class | Duration | Easing | Reduced motion | Applies to |
|---|---|---|---|---|
| Menu screen change | 150 ms fade | Ease-out | Cut | P17 screens |
| Overlay open/close | 100 ms fade | Ease-out | Cut | P6, P15, P16 |
| Focus change | 80 ms | Linear | Unchanged (no motion) | P17–P28 |
| HUD element appear/disappear | 150 ms fade | Ease-out | Cut | P2, P7, P9, P10, P13 |
| Progress fill | Follows the predicted or server value | Linear | Unchanged | P3, P4, P13 |
| Hold cancel / completion | 200 ms | Ease-out | Static icon, no pulse | P3 |
| Edge indicator | 150 ms in, holds for the cue, 300 ms out | Ease-in-out | Unchanged (opacity only, no movement) | P8 |
| State vignette | 250 ms in/out | Ease-in-out | Jitter off; edges still shown | P11 |

No UI animation flashes luminance more than 3 times per second, and every flash respects the flash scale (accessibility Visual).

### Sound Standards

UI sounds play on the **UI** bus (independent volume, accessibility Auditory), never on the Stinger or Scare buses, and scares never duck them (`scare-events.md`).

| Event | Sound | Patterns | Note |
|---|---|---|---|
| Focus move | Soft tick | P17–P28 | Menus only; silent in a round |
| Confirm | Short click | P19–P24, P26 | |
| Back / cancel | Lower click | P17, P22 | |
| Deny / reject | Muted buzz | P10, disabled P19 | Same sound everywhere; never silent |
| Ping sent / received | Sender tone / positional tone for recipients | P5, P7 | |
| Wheel open / select | Whoosh / click | P6 | 50 ms latency target |
| Hold complete | The owning system's completion sound | P1, P3 | Owned by each GDD |
| Hold cancelled | Short drop tone | P3 | Plays with the cause label |
| Countdown tick | One tick per second | Lobby countdown, final 30 s clock | Owned by `lobby-role-assignment.md`, `match-flow.md` |
| Dialog open | Low tone | P16 | |

---

## Gaps & Patterns Needed

| Gap | Needed by | Note |
|---|---|---|
| Spectator view and target switching | `match-flow.md` spectators, ADR-0004 §8 | Which survivor is watched, how to switch, what HUD a spectator sees |
| Hide peek view | `survivor-defense.md` rules 19–21 | Restricted cone framing, exit prompt, what HUD remains |
| Surveillance monitor view | `research-facility.md`, ADR-0009 §8 | Camera cycling (press cycles 1→4→off), feed framing, leaving the monitor |
| Lobby character picker and rotation queue display | `lobby-role-assignment.md` UI Requirements | Belongs to the lobby screen spec |
| Results screen layout | `match-flow.md` rules 23–26 | Specced in `design/ux/results.md` (no new pattern); payload still needs the stats interface ADR (TR-matchflow-008) |
| First-launch flow (photosensitivity warning, gamma calibration, input choice) | `design/accessibility-requirements.md` Visual | No onboarding is designed |

Next screen specs: `/ux-design hud`, `/ux-design lobby`, `/ux-design results`, `/ux-design settings`.

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Warning ping on a point: double-press within 0.4 s, or a separate binding? | SneakKestrel16 | HUD spec | Resolved 2026-10-12 (ux-review): separate bindable action; double-press is an optional shortcut |
| Does the callout wheel take mouse look while open (player can strafe but not turn)? | SneakKestrel16 | HUD spec | Inference; confirm in prototype |
| Does opening the in-round overlay stop the character (empty intent) or keep the last movement? | SneakKestrel16 | Settings spec | Proposed: stop |
| P8 shapes and P11 treatments need the art bible | art-director | Art bible | Unresolved |
