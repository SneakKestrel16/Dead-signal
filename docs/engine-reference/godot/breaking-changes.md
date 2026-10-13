# Godot — Breaking Changes

Last verified: 2026-10-11 (4.6 → 4.7 span); 2026-02-12 (older spans)

Changes between Godot versions, focused on post-LLM-cutoff changes (4.4+).

## 4.6 → 4.7 (~Jun 2026 — POST-CUTOFF, HIGH RISK)

Source: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html
(fetched 2026-10-11). The guide lists no networking/multiplayer changes. Additive
optional parameters are omitted here; see the guide.

| Subsystem | Change | Details |
|-----------|--------|---------|
| GDScript | Overrides inherit the parent's typed return | An override of a method with a typed return now needs an explicit `return` (e.g. `return null`). Compile error until fixed. |
| GDScript | Setting a packed-array element no longer calls the property setter | `arr_prop[i] = x` used to fire the whole property's setter; it no longer does. Behaviour change. |
| Input | Mouse/keyboard device IDs no longer `0` | Compare `InputEvent.device` to `InputEvent.DEVICE_ID_MOUSE` / `InputEvent.DEVICE_ID_KEYBOARD`, or check the event type. |
| Audio | `AudioStreamPlayer3D` `area_mask` default is `0` (was layer 1; the property exists only on the 3D player) | Projects using `audio_bus_override` on `Area3D` must set the mask back to layer 1. |
| Audio | `AudioEffectSpectrumAnalyzer.tap_back_pos` removed | Source break. |
| Physics (Jolt) | `WorldBoundaryShape3D.plane.d` sign inverted | Flip the sign to match 4.6 behaviour. |
| Physics (Jolt) | `SoftBody3D` mass default 1 kg for whole body; `linear_stiffness` applied like Godot Physics | Retune `linear_stiffness` and `damping_coefficient`. |
| Physics (Jolt) | `Area3D` now reports `SoftBody3D` overlaps | Adjust layers/masks to exclude unwanted overlaps. |
| Physics 2D | `PhysicsServer2DExtension._body_set_shape_as_one_way_collision` gains `direction` | Breaks extension overrides. |
| Rendering | `CanvasItem` lines drop the antialiasing feather | Lines look thinner; increase width. |
| Rendering | `LinearToSRGB` visual shader no longer clamps to [0, 1] (Forward+/Mobile) | Behaviour change. |
| Rendering | `rendering/reflections/sky_reflections/roughness_layers` default 7 → 8 | Behaviour change if left at default. |
| Animation | `LookAtModifier3D.relative` default `true` → `false` | Behaviour change if left at default. |
| UI | `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` → `UPDATE_WIDTH_UNIT` | GDScript source break. `add_image`/`update_image` `width_in_percent`/`height_in_percent` become `width_unit`/`height_unit` (`RichTextLabel.ImageUnit`). |
| UI | `Control.accessibility_live` type moves to `AccessibilityServer.AccessibilityLiveMode` | GDScript OK; C# break. |
| Editor | `ResourceImporterDynamicFont.hinting` default 1 → 3; `EditorVCSInterface._commit` gains `amend` | |
| Project | New projects default stretch mode `canvas_items`, aspect `expand` | Was `disabled` / `keep`. Existing projects keep their value. |

## 4.5 → 4.6 (Jan 2026 — POST-CUTOFF, HIGH RISK)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Physics | Jolt is now the DEFAULT 3D physics engine | New projects use Jolt automatically. Existing projects keep their setting. Some HingeJoint3D properties (like `damp`) only work with GodotPhysics. |
| Rendering | Glow processes BEFORE tonemapping | Was after tonemapping. Scenes with glow will look different. Adjust intensity/blend in WorldEnvironment. |
| Rendering | D3D12 default on Windows | Was Vulkan. For better driver compatibility. |
| Rendering | AgX tonemapper new controls | White point and contrast parameters added. |
| Core | Quaternion initializes to identity | Was zero. Unlikely to affect most code but technically breaking. |
| UI | Dual-focus system | Mouse/touch focus now separate from keyboard/gamepad focus. Visual feedback differs by input method. |
| Animation | IK system fully restored | CCDIK, FABRIK, Jacobian IK, Spline IK, TwoBoneIK via SkeletonModifier3D nodes. |
| Editor | New "Modern" theme default | Grayscale replaces blue-tint. Restore: Editor Settings → Interface → Theme → Style: Classic |
| Editor | "Select Mode" keybind changed | New "Select Mode" (v key) prevents accidental transforms. Old mode renamed "Transform Mode" (q key). |
| 2D | TileMapLayer scene tile rotation | Scene tiles can now be rotated like atlas tiles. |
| Localization | CSV plural form support | No longer requires Gettext for plurals. Context columns added. |
| C# | Automatic string extraction | Translation strings auto-extracted from C# code. |
| Plugins | New EditorDock class | Specialized container for plugin docks with layout control. |

## 4.4 → 4.5 (Late 2025 — POST-CUTOFF, HIGH RISK)

| Subsystem | Change | Details |
|-----------|--------|---------|
| GDScript | Variadic arguments added | Functions can accept `...` arbitrary params — new language feature |
| GDScript | `@abstract` decorator | Abstract classes and methods now enforceable |
| GDScript | Script backtracing | Detailed call stacks available even in Release builds |
| Rendering | Stencil buffer support | New capability for advanced visual effects |
| Rendering | SMAA 1x antialiasing | New post-processing AA option |
| Rendering | Shader Baker | Pre-compiles shaders — reportedly 20x faster startup on some demos |
| Rendering | Bent normal maps, specular occlusion | New material features |
| Accessibility | Screen reader support | Control nodes work with accessibility tools via AccessKit |
| Editor | Live translation preview | Test GUI layouts in different languages in-editor |
| Physics | 3D interpolation rearchitected | Moved from RenderingServer to SceneTree. API unchanged but internals differ. |
| Animation | BoneConstraint3D | New: AimModifier3D, CopyTransformModifier3D, ConvertTransformModifier3D |
| Resources | `duplicate_deep()` added | New explicit method for deep duplication of nested resources |
| Navigation | Dedicated 2D navigation server | No longer a proxy to 3D navigation; smaller export for 2D games |
| UI | FoldableContainer node | New accordion-style container for collapsible UI sections |
| UI | Recursive Control behavior | Disable mouse/focus interactions across entire node hierarchies |
| Platform | visionOS export support | New platform target |
| Platform | SDL3 gamepad driver | Delegated gamepad handling to SDL library |
| Platform | Android 16KB page support | Required for Google Play targeting Android 15+ |

## 4.3 → 4.4 (Mid 2025 — NEAR CUTOFF, VERIFY)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Core | `FileAccess.store_*` return `bool` | Was `void`. Methods: `store_8`, `store_16`, `store_32`, `store_64`, `store_buffer`, `store_csv_line`, `store_double`, `store_float`, `store_half`, `store_line`, `store_pascal_string`, `store_real`, `store_string`, `store_var` |
| Core | `OS.execute_with_pipe` | Added optional `blocking` parameter |
| Core | `RegEx.compile/create_from_string` | Added optional `show_error` parameter |
| Rendering | `RenderingDevice.draw_list_begin` | Many parameters removed; `breadcrumb` parameter added |
| Rendering | `Shader.set_default_texture_parameter()` / `get_default_texture_parameter()` | Parameter/return type changed from `Texture2D` to `Texture`; the shading language did not change |
| Particles | `.restart()` method | Added optional `keep_seed` parameter (CPU/GPU 2D/3D) |
| GUI | `RichTextLabel.push_meta` | Added optional `tooltip` parameter |
| GUI | `GraphEdit.connect_node` | Added optional `keep_alive` parameter |

## 4.2 → 4.3 (In Training Data — LOW RISK)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Animation | `Skeleton3D.add_bone` returns `int32` | Was `void` |
| Animation | `bone_pose_updated` signal | Replaced by `skeleton_updated` |
| TileMap | `TileMapLayer` replaces `TileMap` | One node per layer instead of multi-layer single node |
| Navigation | `NavigationRegion2D` | Removed `avoidance_layers`, `constrain_avoidance` properties |
| Editor | `EditorSceneFormatImporterFBX` | Renamed to `EditorSceneFormatImporterFBX2GLTF` |
| Animation | AnimationMixer base class | AnimationPlayer and AnimationTree now extend AnimationMixer |
