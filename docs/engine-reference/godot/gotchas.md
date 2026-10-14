# Godot 4.7.2 Gotchas

Traps found by running code in this project. Each entry: symptom, cause, fix, source.

## Networking

### `has_multiplayer_peer()` is true before you host or join

- **Symptom:** "host if not connected" logic never hosts; `is_server()` reads true offline.
- **Cause:** the SceneTree's default `OfflineMultiplayerPeer` counts as a peer, and it reports itself as the server.
- **Fix:** test for the real transport: `multiplayer.multiplayer_peer is ENetMultiplayerPeer`.
- **Source:** vertical slice, 2026-10-13 (`prototypes/dead-signal-vertical-slice/net.gd`, `online()`); found by its headless round test hanging.

## UI and input

### A centred `Control` eats captured-mouse look

- **Symptom:** with `MOUSE_MODE_CAPTURED`, the camera does not turn; keyboard input works.
- **Cause:** captured motion events still carry the window-centre position, so GUI picking runs. `ColorRect`, `ProgressBar` and containers default to `MOUSE_FILTER_STOP`, so a crosshair at the centre consumes every motion event before `_unhandled_input`.
- **Fix:** read look in `_input`, and set `mouse_filter = MOUSE_FILTER_IGNORE` on HUD controls. ADR-0014's `InputContextStack` should own this in production.
- **Source:** vertical slice, 2026-10-13 (commit 72a2c19); invisible to headless tests, found by the designer's first session.

## Export

### `--path` aborts an exported binary

- **Symptom:** `ERROR: --path was specified on the command line, but this Godot binary was compiled without support for path overrides. Aborting.`
- **Fix:** run exported builds without `--path`; pass game arguments after `--`.
- **Source:** vertical slice launch, 2026-10-13.
