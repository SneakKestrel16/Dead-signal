# ADR verification checks

Status: **concluded for single-machine items** (2026-10-12). Items that need a second
PC, a real network, a window or an export are listed as NOT RUN below and stay open.

## Hypothesis

The Verification Required items of ADR-0001 to ADR-0008 (`docs/architecture/`) hold
on Godot 4.7.2 with Jolt: the engine behaviours the ADRs assume but the repo's
engine reference does not cover.

## How to run

```bash
bash run.sh          # every ADR, about 1.5 minutes
bash run.sh 0004     # one ADR
```

Mouse-look check (ADR-0007 (8), opens a window and moves the real cursor): for each of `1152x648 none`, `576x324 stretch`, `576x324 none`, start `godot --path . res://mouse_look.tscn --resolution <WxH> -- <mode> <tag>` and run `powershell -File inject_mouse.ps1 -ReadyFile logs/mouse_<tag>.txt`; the result replaces the READY line in that file.

Export check (ADR-0006 (3)): `godot --headless --path . --export-debug "Windows Desktop" build/verify.exe`, then `build/verify.console.exe --headless`; it writes `build/export_result.txt`. Needs the 4.7.2 export templates. `export_presets.cfg` is gitignored repo-wide (presets can hold signing credentials); recreate it with:

```ini
[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="data/knobs/*"
exclude_filter=""
export_path="build/verify.exe"

[preset.0.options]

binary_format/embed_pck=true
```

Needs Godot 4.7.2 (path in `run.sh`, override with `GODOT=`). It runs `--import` once
(the class-name fixtures need the global class cache), then `run.gd` headless. Each
check prints `RESULT <id> <verdict> <observation>`; full output goes to `logs/run.log`.
Verdicts: PASS / FAIL against an expectation, OBSERVED for a value with no expectation,
NOT RUN with the reason.

Networking checks run a server and clients in one process, each on its own
`SceneMultiplayer` subtree (`SceneTree.set_multiplayer`). A UDP relay in `lib.gd`
(`UdpProxy`) sits between client and server for packet capture and loss injection.
Expected noise in the log: parse errors from the compile probes (ADR-0005, 0008), and
"The multiplayer instance isn't currently active" from polling closed test peers.

## Findings (Windows, one machine, 2026-10-12)

| Item | Verdict | Result |
|---|---|---|
| 0001-1 | OBSERVED / PASS | Default ENet dead-peer detection on loopback: 5.8 s. `set_timeout(32, 1000, 2000)`: 3.0 s |
| 0001-2 | OBSERVED / PASS | `auth_timeout` default 3.0 s; a client that never sends auth fails at the timeout (`peer_authentication_failed`) |
| 0001-3 | OBSERVED | `server_relay` default is `true`; the ADR sets `false` |
| 0001-4 | PASS | `Crypto.generate_random_bytes(16)` returns 16 distinct bytes |
| 0001-5 | OBSERVED | Default bind accepts both `127.0.0.1` and `::1` |
| 0001-6 | **finding** | `send_auth` immediately followed by `disconnect_peer` loses the reason; with the ADR's 0.2 s delay it arrives. The delay is required |
| 0002-1 | PASS | A lost reliable packet (resent after ~150 ms) holds back no unreliable traffic: delay stays 7 ms, on separate channels **and** on one shared channel, for both `UNRELIABLE` and `UNRELIABLE_ORDERED` |
| 0002-2 | OBSERVED | `max_physics_steps_per_frame` default 8 |
| 0002-3 | PASS | With `SceneTree.physics_interpolation` on, a child with mode OFF shows a local offset change at once (145/145 frames) while riding the parent's interpolated position; an inheriting child smooths the same change over a tick. OFF does **not** detach the child from the parent's interpolation, which is what the correction offset and camera need. Measured on `get_global_transform_interpolated()` in `_process`; pixels not checked |
| 0002-4 / 0007-3 | PASS at 5 mm | Gravity and floor snap: 40° ramp climbed; 15 frames replayed in one physics frame match the recorded path within 1.6 mm (worst, at the ramp lip). Over the old 1 mm deadzone |
| 0002-5 | OBSERVED | Same machine: two identical runs match exactly. Cross-machine NOT RUN |
| 0002-6 / 0004-4 | PASS | 6-body snapshot: 144 B payload, 165 B datagram |
| 0002-7 | PASS | `apply_floor_snap()` after restoring position and velocity re-finds the floor; replay error 17 mm without it, 1.6 mm with it |
| 0003-1 | OBSERVED | Ray defaults: `hit_from_inside` false, `hit_back_faces` **true**, `collide_with_areas` false, `collide_with_bodies` true |
| 0003-4 | PASS | Steering pursuit (GDD model): walk strafe from 0.43 s dodges over 20 seeds at 60 Hz and 0.5 ms tests; crouch strafe is hit. Latest safe start: 0.486 s with no acceleration (GDD: ~0.49), 0.457 s with `accel_time_s` 0.05: margin **27 ms** (ADR inferred ~35) |
| 0003-4c | **finding** | `accel_time_s` 0.1 no longer dodges; ceiling 0.095 s. Controller safe range set to 0–0.09 |
| 0003-4d | **finding** | Monster Abilities ceilings at 0.43 s (one knob at a time): wind-up turn 26.5°/s, hit radius 1.33 m, cone 69.8°. The cone range 40–70 tops out above the ceiling |
| 0004-1 | PASS | Hidden spawn granted to one client only: the other gets no node, no `spawned` signal, and 36 B over 1 s (44 B idle) while the entity moves |
| 0004-2 | PASS | `set_visibility_for` right after `spawn()` in the same frame delivers the spawn |
| 0004-3 | OBSERVED | Visibility filters re-run every frame by default (`visibility_update_mode` 0); a flipped filter takes effect in 1 frame |
| 0004-5 | OBSERVED | The first RPC to `Player_4242` carries the name in clear; the ADR's fixed-name rule is needed |
| 0005-1 | PASS | `@abstract`: `FixtureEvent.new()` in code is a parse error ("Cannot construct abstract class"), in both own-line and one-line forms. `load(path).new()` at runtime still instantiates |
| 0005-2 | PASS | Missing branch `return` in a typed override fails, annotated or not; a different return type fails |
| 0005-3 | PASS | `Callable.is_valid()` false after the Node is freed |
| 0005-4 | OBSERVED | A named-method `Callable` does **not** keep its `RefCounted` alive; a module/view reference cycle does, until broken |
| 0005-5 | PASS | `is_instance_of(view, ClassName)` works with a `class_name` script |
| 0005-6 | PASS | `Dictionary[StringName, Array[Callable]]`: "Nested typed collections are not supported"; `Dictionary[StringName, Array]` with a cast works |
| 0006-1 | PASS | `@export_range` gives `PROPERTY_HINT_RANGE` with `"1.0,4.0"` (int fields too: `"1.0,3.0"`) |
| 0006-2 | PASS | `CACHE_MODE_IGNORE` loads are independent |
| 0006-3 | PASS / **finding** | A field left at `NAN` is **written** (`extra_s = nan`), not omitted, and loads as NAN: the unset check still works. In a Windows debug export (`export_main.tscn`, preset under How to run) `res://data/knobs/defense.tres` loads by path: the pack holds only the `.remap`, values and NAN survive the binary conversion |
| 0006-4 | PASS | Digest identical across loads and across two runs. Cross-machine NOT RUN |
| 0006-5 | PASS | A misspelled key loads without error and the real field stays NAN |
| 0007-1 | PASS | `3d/physics_engine="Jolt Physics"` |
| 0007-2 | OBSERVED | `safe_margin` 0.001, `max_slides` 6, `wall_min_slide_angle` 15° (training data was right) |
| 0007-4 | PASS | Stand-up `intersect_shape` with margin 0 and own RID excluded |
| 0007-5 | PASS | Code-built capsules are not shared |
| 0007-6 | PASS | No speed loss crossing a seam between coplanar boxes |
| 0007-7 | **FAIL** | Jolt queries and `move_and_slide` see other bodies where they were after the **last physics step**: a teleport or move this frame is invisible until the next step. Disabling or shrinking a shape is seen at once |
| 0007-9 | **finding** | The floor limit is `floor_max_angle` + about 0.5°: at 40.5° a 41° ramp is climbable. At 40.0°, 40.4° climbs and 40.6° blocks, so 40° climbs and 41° blocks, with or without `floor_block_on_wall` |
| 0007-8 | PASS | Windowed, mouse captured, 200 px of OS-injected motion (`inject_mouse.ps1`, `mouse_event`): half-size window with `canvas_items` stretch reads `relative` 400, `screen_relative` 200; unscaled or without stretch, both 200. `relative` is stretch-scaled; `screen_relative` is not |
| 0008-1 | PASS | A `void` override needs no `return`; a typed one missing a branch return fails |
| 0008-2 | PASS | `PROJECTILE` ray stops at glass, `SIGHT` passes it, door blockers are ignored by both (left to the analytic test) |

## NOT RUN (owner: designer, with a second PC or later work)

- Real network, second PC: ADR-0001/0002/0003 deferred list in `../networking-spike/README.md`; 0002-5 cross-machine drift; 0003-2 rewind against measured RTT; 0003-3 remote smoothness; 0006-4 digest on a second machine.
- Not yet written: 0008-3 `HoldService` lock contest (a unit test of production code).
- Slow host: 0002-2 behaviour when the host cannot hold 60 Hz.

## Limits

One machine, loopback, one process. Loss injection drops every server-to-client
packet for 60 ms; it does not model real loss patterns. The pursuit simulation is the
GDD's model reimplemented here, checked against its published 0.49 s figure.
