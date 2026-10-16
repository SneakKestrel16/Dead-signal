# Godot 4.7.2 Gotchas

Traps found by running code in this project. Each entry: symptom, cause, fix, source.

## Networking

### `has_multiplayer_peer()` is true before you host or join

- **Symptom:** "host if not connected" logic never hosts; `is_server()` reads true offline.
- **Cause:** the SceneTree's default `OfflineMultiplayerPeer` counts as a peer, and it reports itself as the server.
- **Fix:** test for the real transport: `multiplayer.multiplayer_peer is ENetMultiplayerPeer`.
- **Source:** vertical slice, 2026-10-13 (`prototypes/dead-signal-vertical-slice/net.gd`, `online()`); found by its headless round test hanging.

### An explicit ENet channel count starved unreliable sends

- **Symptom:** input sent every tick reached the server about once in 8 to 20 ticks. The server queue starved, and owner corrections of 1.3 m (20 lost frames) hit every client on the same ticks.
- **Cause:** with `create_server(..., 4)` and `create_client(..., 4)`, the client's `PEER_PACKET_THROTTLE_LIMIT` fell to 1 of 32. ENet then drops unreliable sends to match. With the default count (0, ENet's maximum) the limit stayed at 32. Why the count matters inside ENet was not traced, so this is an inference from the measurement.
- **Fix:** keep the default channel count; any channel number up to the maximum then works. Separately, ENet's adaptive throttle also cut input under 30 ms jitter (58 to 62 corrections per ~4360 states). `NetAuthority` pins it with `throttle_configure(5000, PACKET_THROTTLE_SCALE, 0)` on each peer, and ENet forwards that to the client.
- **Source:** network-authority story 006, 2026-10-13, `tests/integration/network/prediction_reconcile_test.gd` (5 clients, 150 ms RTT, 30 ms jitter, 2% loss). Diagnosed from `ENetPacketPeer.get_statistic` per tick.

### `move_and_slide()` outside the physics frame moves by the frame delta

- **Symptom:** owner reconciliation replayed the right frames but landed in the wrong place whenever a snapshot was handled from `peer_packet`.
- **Cause:** the SceneTree polls the multiplayer API in the idle (process) frame, so `peer_packet` handlers run there. Outside the physics frame, `move_and_slide()` moves by the process delta, not the physics delta. The engine reference does not cover this; the code review raised it, and a regression test proved it on 4.7.2.
- **Fix:** buffer the snapshot in the packet handler and replay it in the physics frame. `OwnerPredictor.receive()` only buffers; `predict()` and `apply_pending()` apply the snapshot.
- **Source:** network-authority story 006 code review, 2026-10-14. The proof is `prediction_reconcile_test.gd::test_snapshot_received_outside_the_physics_frame_replays_with_the_physics_delta`: with the buffering removed, it fails on corrections.

### A zero-motion `move_and_slide()` is not a no-op for a resting body

- **Symptom:** two bodies given the same inputs ended 0.6 to 5.9 m apart in about 1 run in 6, after walking into a step corner.
- **Cause:** one body got a few more idle steps, because its first input was still in flight. Each zero-velocity `move_and_slide()` can still move a resting body within its `safe_margin` (resting heights from -0.19 mm to +0.84 mm were measured). Corners amplify that sub-millimetre difference.
- **Fix:** skip `move_and_slide()` when the body is on the floor with zero velocity, as `tests/helpers/test_move_step.gd` now does. The controller's real movement step (controller story 002) should do the same.
- **Source:** network-authority story 006, 2026-10-14, `test_host_and_remote_client_end_with_identical_server_positions` (12 runs).

### A body's first `move_and_slide()` depends on how long the body has been in the space

- **Symptom:** after the fix above, the same test still failed in about 1 run in 3, with the host body 6 m past the remote. Both bodies were stepped with seq 1..630, no gaps and the same frames. They differed from the very first step: the host ended at y 0.0, the remote at y -1.9 mm.
- **Cause:** the host body was created on the tick it first moved, but the remote body had existed for many physics frames. Inference: the new body was not yet fully registered in the physics space when the first test-motion query ran. Not confirmed in the Jolt source; a single-body test comparing first steps at age 0 and age 2 frames would settle it.
- **Fix:** create every body that a test compares at least a few physics frames before its first step. The game spawns players at round start, well before the first input, so it should not hit this.
- **Source:** network-authority story 006, 2026-10-14; per-step log of both server bodies in `prediction_reconcile_test.gd`; 6 of 6 runs passed after the fix.

### `set_visibility_for()` on a peer that `disconnect_peer()` already removed is an error

- **Symptom:** `Condition "!peers_info.has(p_peer)" is true` in `_update_sync_visibility`, raised when a reconnect revoked visibility for the evicted peer.
- **Cause:** `SceneMultiplayer.disconnect_peer()` drops the peer from the replication interface at once, so a later `set_visibility_for(old_peer, false)` names a peer it no longer knows.
- **Fix:** revoke the old peer's visibility before `disconnect_peer()`, as `NetAuthority._on_peer_connected` does. In tests, also free nodes holding a `MultiplayerSynchronizer` before unsetting their `SceneMultiplayer`; freeing them afterwards logs `on_replication_stop` and `on_reset` errors.
- **Source:** network-authority story 002, 2026-10-14, `tokens_reconnect_test.gd::test_visibility_follows_the_player_to_the_new_peer`.

### `StringName` `<` does not sort by text

- **Symptom:** sorting map markers by `id` (`&"S1"` .. `&"S5"`) with `a.id < b.id` gave an order that was not alphabetical; survivors spawned at S2..S5.
- **Cause:** the comparison of two `StringName` values orders by internal pointer, not by characters. Inference from the observed order: not checked against engine source.
- **Fix:** compare `String(a.id) < String(b.id)`.
- **Source:** match-flow story 004, 2026-10-14 (`src/feature/match_flow/round_lifecycle.gd`); the spawn test failed with the `StringName` compare and passed with the `String` one.

## UI and input

### A centred `Control` eats captured-mouse look

- **Symptom:** with `MOUSE_MODE_CAPTURED`, the camera does not turn; keyboard input works.
- **Cause:** captured motion events still carry the window-centre position, so GUI picking runs. `ColorRect`, `ProgressBar` and containers default to `MOUSE_FILTER_STOP`, so a crosshair at the centre consumes every motion event before `_unhandled_input`.
- **Fix:** read look in `_input`, and set `mouse_filter = MOUSE_FILTER_IGNORE` on HUD controls. ADR-0014's `InputContextStack` should own this in production.
- **Source:** vertical slice, 2026-10-13 (commit 72a2c19); invisible to headless tests, found by the designer's first session.

### A code-built InputEvent saves with a device ID, not "all devices"

- **Symptom:** actions created with `InputEventKey.new()` / `InputEventMouseButton.new()` and saved through `ProjectSettings.save()` wrote `"device":16` (keys) and `"device":32` (mouse buttons) into `project.godot`. Actions made in the editor's Input Map use `"device":-1`, which matches any device.
- **Cause:** inference: 4.7's new device IDs (`docs/engine-reference/godot/VERSION.md`, 4.7 row) give a new event a device constant for its kind instead of -1. Not checked against the class reference; a one-line print of `InputEvent.DEVICE_ID_*` would settle it.
- **Fix:** set `"device":-1` in the `[input]` section (done for the eleven ADR-0007 actions), or set `event.device = -1` before saving.
- **Source:** controller story 006, 2026-10-14, generating the InputMap with a throwaway script.

### The GDScript literal `-0.0` is `+0.0`; a computed `-0.0` serializes differently

- **Symptom:** a test meant to prove `-0.0` and `0.0` hash the same passed even with the normalization removed.
- **Cause:** `var a := -0.0` folds to +0.0 (`var_to_bytes` gives `0300000000000000`), but `-1.0 * zero` is a real -0.0 (`0300000000000080`). Both compare equal with `==`, and `str()` prints `0.0` for both.
- **Fix:** build a negative zero by computation in tests. Code that hashes floats (`Knobs.digest()`) maps any zero to +0.0 first.
- **Source:** data-config story 005 review, 2026-10-14, a headless print of `var_to_bytes` on 4.7.2.

### `CACHE_MODE_IGNORE_DEEP` reloads the resource's own script

- **Symptom:** a static loader such as `MapData.load_map()` that loads its own class's `.tres` with `ResourceLoader.CACHE_MODE_IGNORE_DEEP` gets the resource back. Then `res is MapData`, or `as MapData`, fails with `Condition ' !script_type ' is true` or `Internal script error! Opcode: 32`. The headless process can then crash with signal 11.
- **Cause:** `IGNORE_DEEP` also bypasses the cache for external dependencies, and those include the `Script` ext_resource. The loaded resource therefore carries a second copy of the class's GDScript, separate from the one the calling code was compiled against. Inference: the cause was not checked against engine source.
- **Fix:** use `CACHE_MODE_IGNORE`. It re-creates the file's main resource and its sub-resources, and reuses its dependencies, scripts included. That gives a fresh layout on every load.
- **Source:** facility-map story 001, 2026-10-14. Verified on 4.7.2: `src/core/facility/map_data.gd` loads, and the 10-load digest test passes, after the switch.

## Export

### `--path` aborts an exported binary

- **Symptom:** `ERROR: --path was specified on the command line, but this Godot binary was compiled without support for path overrides. Aborting.`
- **Fix:** run exported builds without `--path`; pass game arguments after `--`.
- **Source:** vertical slice launch, 2026-10-13.

## Testing

### A new `class_name` is unknown to the next headless test run

- **Symptom:** gdUnit4 run right after adding a script fails with the new class name not found (e.g. `StateRegistry`), although the file exists.
- **Cause:** the global class cache (`.godot/global_script_class_cache.cfg`) is refreshed by an import scan, and a `-s` script run does not always rescan first.
- **Fix:** run `godot --headless --import` once after adding a `class_name` script, then the tests. Commit the updated cache file (it is tracked).
- **Source:** event-catalog story 003, 2026-10-13 (engine-programmer run). Inference on the cause: not checked against engine source.

### gdUnit4 `assert_object(x)` keeps `x` alive

- **Symptom:** a leak test with `WeakRef` says an object is still alive after teardown, though nothing in the game holds it.
- **Cause:** the assertion object stores the value it checked, so a `RefCounted` passed to `assert_object` stays referenced for the rest of the test.
- **Fix:** check liveness with `assert_bool(ref.get_ref() != null)`, never by passing the object itself to an assertion.
- **Source:** event-catalog story 004, 2026-10-13 (`tests/integration/event_catalog/tick_order_test.gd`). Inference on the cause: not checked against gdUnit4 source.

### `SceneTree.set_multiplayer` per-path APIs leak unless unset

- **Symptom:** a test suite passes with 0 orphans but the engine prints "N resources still in use at exit"; `--verbose` lists leaked `SceneMultiplayer`, `ENetMultiplayerPeer` and `Scene*Interface` instances.
- **Cause:** the tree keeps a custom multiplayer registered for its path after the node is freed. A lambda connected to the API's own signal that captures the API is a reference cycle.
- **Fix:** before freeing the node, close and clear `multiplayer_peer`, clear `auth_callback`, disconnect the lambdas, then call `get_tree().set_multiplayer(null, node.get_path())`.
- **Source:** network-authority story 001, 2026-10-13. Verified on 4.7.2: the warning disappeared after the teardown change (123/123 pass).

### An inner class extending a sibling inner class leaks the script graph

- **Symptom:** every test file that loads the script (directly or through another class) passes with 0 orphans, but the engine prints "N ObjectDB instances were leaked at exit" and "N resources still in use at exit". The count is the same whichever test file runs. `--verbose` lists `GDScriptNativeClass` instances and every loaded `.gd` file, the gdUnit4 scripts included; no game object.
- **Cause:** `class DriveConsole extends Point:` where `Point` is another inner class of the same script. Removing `@abstract` from `Point` did not help; having the inner classes extend the top-level `Interactable` directly did. Inference on the mechanism (a script reference cycle at unload): not checked against engine source.
- **Fix:** put the shared base in its own top-level `class_name` script (`src/feature/objectives/objective_point.gd`) and let the inner classes extend that.
- **Source:** survivor-objectives story 003, 2026-10-14. Verified on 4.7.2 by bisecting the merged file: the warnings appear with the inner base and disappear with the top-level one (33/33 pass).

### A string literal spanning a line break picks up `\r` on a CRLF checkout

- **Symptom:** a test comparing text built by the code passes in an agent worktree and fails on main with `'1. Bob (away)<CR>'`.
- **Cause:** `"\n".join(lines)` written with a real line break inside the quotes. The repo has `core.autocrlf=true` and no `eol` rule for `*.gd`, so main's checkout stores CRLF and the literal becomes `"\r\n"`; a fresh worktree checkout can be LF, so the bug only shows on one side.
- **Fix:** always write the escape `"\n"`, never a literal line break inside a string. Find offenders with `grep -rnE '(\(|= |return |, )"\r?$' src tests`.
- **Source:** lobby-role-assignment story 012, 2026-10-15 (`LobbyScreen.queue_text`; the same pattern was in `src/main.gd`).

### A never-fired one-shot connection with bound collaborators leaks the script graph

- **Symptom:** a real-ENet suite passes with 0 orphans but prints "N ObjectDB instances were leaked at exit" and "N resources still in use at exit"; `--verbose` lists only `GDScript` / `GDScriptNativeClass` instances.
- **Cause:** `model.monster_state_changed.connect(_spawn.bind(layer, model, contexts, knobs, ...), CONNECT_ONE_SHOT)` on a survivor client, where the signal never fires. Removing the widget spawn and the bound Callables did not help; removing the connection did. ShapeshifterHud's identical pattern binding only `(layer, model, camera)` does not leak. Inference on the mechanism (the bound `Knobs` resource or `InputContextStack` kept alive by the connection): not checked against engine source.
- **Fix:** construct the widget up front and let it gate itself on model state (`FormPicker.for_client`), instead of deferring construction through a bound connection.
- **Source:** borrowed-face story 011, 2026-10-15. Verified on 4.7.2 by bisecting `tests/integration/hud-results` (leak with the connection, clean without).

### Iterating an array property of a temporary loaded Resource leaks the script graph

- **Symptom:** a test passes with 0 orphans but the engine prints "N ObjectDB instances were leaked at exit" and "N resources still in use at exit"; `--verbose` lists only `GDScript` / `GDScriptNativeClass` instances and scripts.
- **Cause:** `for v in MapData.load_map().volumes:` (also `var vs := MapData.load_map().volumes; for v in vs:`). Holding the resource itself in a local (`var m := MapData.load_map(); for v in m.volumes:`) does not leak. Inference on the mechanism (the array outliving its owner keeps the sub-resources' scripts referenced at unload): not checked against engine source.
- **Fix:** keep the loaded resource in a local and iterate its property.
- **Source:** audio pass, 2026-10-16 (`tests/unit/audio/sound_bank_test.gd`). Verified on 4.7.2 by bisecting a one-test suite: the three forms above, leak / leak / clean; same with `ScareCatalogue.load_shipped().entries`.

## Rendering

### A lit mesh with render `layers = 0` logs "indexing did not unpair geometries from light" at teardown

- **Symptom:** a windowed round_view run prints 20 lines of `ERROR: BUG, indexing did not unpair geometries from light.` (`renderer_scene_cull.cpp:844`, `instance_set_scenario`) when the scene is freed; no visible fault.
- **Cause:** `BodyVisual` hid each remote body's greybox capsule with `MeshInstance3D.layers = 0` (the node cannot be hidden: the character art is its child) while flashlight spots lit it. Inference on the mechanism (the light pairing is keyed on the layer mask and the unpair misses it): not checked against engine source.
- **Fix:** detach the mesh resource instead (`mi.mesh = null`, restored while needed).
- **Source:** character art (ASSET-001..010), 2026-10-15. Verified on 4.7.2 by A/B: 20 errors with `layers = 0`, none with the mesh detached.
