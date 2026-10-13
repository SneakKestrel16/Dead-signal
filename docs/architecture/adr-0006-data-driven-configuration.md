# ADR-0006: Data-Driven Configuration (Knobs)

## Status
Accepted

## Date
2026-10-12

## Last Verified
2026-10-12

## Decision Makers
Designer (user), with Claude Code (`/architecture-decision`)

## Summary
About 120 tuning knobs across the 10 system GDDs must live outside code, be validated, and match on the host and on every predicting client. Each system gets a typed `Resource` class whose values ship as a `.tres` file in `res://data/knobs/`. One `Knobs` service bundles the files, validates ranges and cross-knob rules at load and refuses to host on any error, then freezes the set for the round. A hash of the set joins the build version in ADR-0001's join check.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (Resources, GDScript) |
| **Knowledge Risk** | MEDIUM: `Resource` and `.tres` are stable since 4.0; 4.5 added `duplicate_deep()` (`current-best-practices.md`). Load-time behaviours below are not covered by the engine reference |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `current-best-practices.md` (Resources 4.5+), `breaking-changes.md`, `deprecated-apis.md`; ADR-0001, ADR-0002, ADR-0005 |
| **Post-Cutoff APIs Used** | None required |
| **Verification Required** | A headless script per item, before acceptance. Each is NOT SOURCEABLE from `docs/engine-reference/godot/`: (1) `get_property_list()` on a script `Resource` returns `PROPERTY_HINT_RANGE` with a `"min,max"` hint string for `@export_range(min, max)` fields; (2) `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)` returns a fresh instance each call, and mutating it does not affect the next load; (3) `nan` round-trips through the `.tres` text format, a field left at its `NAN` default is omitted from the file and reported as unset after load, and an exported build (binary `.res` + `.remap`) loads `res://data/knobs/<section>.tres` by path; (4) `HashingContext` SHA-256 over `var_to_bytes` of the same values gives the same digest on two runs and two machines; (5) a `.tres` with one misspelled key loads without a fatal error, and the correctly named field reports unset |

**Verification results (2026-10-12, [`prototypes/adr-verification/README.md`](../../prototypes/adr-verification/README.md)).** (1) PASS: `"1.0,4.0"` (int fields also report floats, `"1.0,3.0"`). (2) PASS. (3) a field at its `NAN` default is **written** as `= nan`, not omitted, and loads as NAN, so the unset check holds; in a Windows export the file loads by its `res://` path through `.remap` with values and NAN intact. (4) PASS across loads and two runs; cross-machine NOT RUN. (5) PASS: a misspelled key loads silently and the real field stays unset.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005 (Accepted): composition root injects `Knobs` through `setup()`. ADR-0001 (Accepted): join auth carries the version string. ADR-0002 (Accepted): `sim_tick_hz` and tick-counted timers |
| **Enables** | Every Feature and Core epic (each reads knobs); `/test-setup` fixtures |
| **Blocks** | None beyond the epics above |
| **Ordering Note** | Amends architecture.md §Data/Config: `Knobs` becomes a `RefCounted` with typed sections, not a `Node` with `get_float(key)`, and a bad config refuses to host instead of falling back to defaults. Amends ADR-0001 §3: the client's `version` string gains the knob hash |

## Context

### Problem Statement
The coding standard requires every gameplay value to come from external config, and every GDD ends with "every value in Tuning Knobs is loaded from data". About 120 unique knobs are named across the GDDs, each owned by one GDD. Clients predict movement and hold bars from some of them, so the host and clients must agree. Rule timers count ticks (ADR-0002), but the GDDs give durations in seconds.

### Constraints
- Dependency injection; no gameplay autoloads (ADR-0005).
- A listen server where the host is a player; no dedicated server.
- Values per round must not change (determinism; ADR-0002 tick timers).
- Untrusted data must never become code (ADR-0001's `bytes_to_var_with_objects` ban follows the same reasoning).

### Requirements
- Every Tuning Knobs value is in data, with its GDD's safe range checked at load.
- Cross-knob rules named in GDDs and ADRs are checked at load.
- Typos in knob names fail before the round starts: at parse time in code, at load in data files.
- Unit tests can build knobs without file I/O.

## Decision

**1. Typed sections.** Each system has one `Resource` class named `<System>Knobs` (`ControllerKnobs`, `LobbyKnobs`, `MatchFlowKnobs`, `ObjectivesKnobs`, `DowningKnobs`, `DefenseKnobs`, `BorrowedFaceKnobs`, `AbilityKnobs`, `PingKnobs`, `ScareKnobs`), plus `NetKnobs` for ADR-0001/0002/0003 values, `CoreKnobs` for ADR-0005/0008 values and `FacilityKnobs` for ADR-0009's lighting values (`light_fade_s`, `max_flashes_per_s`, `max_shadowed_omni`, `max_shadowed_spot`, `max_shadowed_flashlights`, `feed_resolution`; amended 2026-10-12 for architecture review N1, AD-35; `max_shadowed_flashlights` added for review 12c, AD-43). `blackout_duration_s` and `backup_switch_hold_s` stay in `AbilityKnobs`, their owning GDD. The render caps are in the digest like every other knob: all players see the same lighting and shadows (Pillar 2, Fair Fear). Each GDD knob is one `@export_range(min, max)` field whose name is the GDD name unchanged and whose range is the GDD's Safe Range. A knob lives only in its owning GDD's section; other systems read it there (e.g. `interact_range_m` is in `ObjectivesKnobs`).

**2. No values in code.** Float fields default to `NAN` and int fields to `KnobUnset.INT` (`-2147483648`). The validator rejects either. So every value must be present in the `.tres` file, and a script default can never silently become the shipped value.

**3. Files.** One `.tres` per section in `res://data/knobs/<section>.tres`. Files are loaded only from `res://`, never from `user://` or any path a player supplies, because a resource file can embed a script. `Knobs` loads a fixed list of section names. It never enumerates the folder, because an export converts `.tres` to binary with `.remap` entries. No scene references these files, so the export preset must include `data/knobs/*` explicitly.

**4. Load and validate.** At boot, `Knobs.load_all()` loads each file with `CACHE_MODE_IGNORE` and runs:
- **Range check**, derived from each field's `PROPERTY_HINT_RANGE` hint string (`split(",")`, first two entries; trailing flags such as `or_greater` ignored), so the GDD range is written once, in the `@export_range`;
- **Unset check** (rule 2). This is also what catches a misspelled key in a `.tres`: the loader most likely drops a property the script does not declare, so the real field stays at its unset default. That drop is inference (`godot-specialist`, 2026-10-12 review; NOT SOURCEABLE), settled by Verification Required item 5;
- **Cross-knob rules**: each section's `validate_cross()` and `Knobs.validate_cross()` for rules spanning sections, each check citing its GDD or ADR (e.g. `hold_range_tolerance_m` < `interact_range_m`; the ADR-0003 dodge budget from `max_rewind_ms`, `lunge_windup_s` and the interpolation delay).

Errors are collected, not stopped at the first. Any error means the game refuses to host and shows the list; debug builds also assert. A client with invalid knobs cannot join, because its hash will not match.

**5. Frozen per round.** The composition root takes the loaded `Knobs` at round start and passes it to every module's `setup()`. Modules read knobs in `setup()` or later and must never write them. A debug-only `reload` command re-runs `load_all()`, and the result applies at the next round start, never mid-round.

**6. Seconds to ticks.** Knobs stay in GDD units. `Knobs.ticks(seconds)` returns `roundi(seconds * sim_tick_hz)`, so every module converts the same way.

**7. Host-client agreement (amends ADR-0001 §3).** `Knobs.digest()` is a SHA-256 over `var_to_bytes` of every section's field names and values, in sorted field order. It covers only properties with `PROPERTY_USAGE_SCRIPT_VARIABLE` and never the file bytes, which differ between the editor `.tres` and the exported binary. The client's auth `version` becomes `"<build_version>+<digest first 8 hex>"`, and the existing `version_mismatch` reject covers a knob mismatch, with both strings shown. A playtest tune means every player updates their files.

**8. Map data is not knobs.** Facility Map content (interactables, visibility sets, zones) is level data owned by Facility Map and covered by the build version.

### Architecture Diagram

```
res://data/knobs/*.tres ──load (CACHE_MODE_IGNORE)──▶ Knobs.load_all()
                                                     ├─ range check (from @export_range hints)
                                                     ├─ unset check (NAN / UNSET)
                                                     ├─ cross-knob rules (per section + global)
                                                     └─ errors? ─▶ refuse to host, list errors
Composition root (round start) ── knobs ──▶ module.setup(..., knobs)   # frozen for the round
Client auth version = build + knobs.digest()[0..8] ──▶ ADR-0001 version check
```

### Key Interfaces

```gdscript
class_name DefenseKnobs extends Resource   # one class per section; example
@export_range(1.0, 4.0) var stun_duration_s: float = NAN
@export_range(1, 3) var stun_item_charges: int = KnobUnset.INT
func validate_cross() -> PackedStringArray:   # [] when valid
	return []

class_name KnobUnset   # standalone, so sections do not reference Knobs (no cyclic class reference)
const INT := -2147483648

class_name Knobs extends RefCounted
var controller: ControllerKnobs
var defense: DefenseKnobs
# ... one typed field per section
static func load_all() -> Knobs                   # never returns a partial set; see errors()
func errors() -> PackedStringArray                # [] = valid
func digest() -> String                           # SHA-256 hex over values in sorted field order
func ticks(seconds: float) -> int                 # roundi(seconds * net.sim_tick_hz)
```

### Implementation Guidelines
- Every GDD tuning knob **must** be an `@export_range` field in its owning section, named exactly as in the GDD.
- Gameplay code **must never** contain a tuning literal; it reads `knobs.<section>.<name>`.
- Knob fields **must** default to `NAN` or `KnobUnset.INT`, never to a real value.
- Knob files **must** load only from `res://data/knobs/`. Loading a knob or other resource file from `user://` or a player-supplied path **must never** happen.
- A validation error **must** prevent hosting. There **must** be no silent fallback.
- Modules **must never** write knob fields.
- Rule timers **must** convert with `Knobs.ticks()`.
- Every cross-knob check **must** cite its source GDD or ADR in a comment.
- Unit tests **must** build sections with `.new()` and set fields directly. One integration test loads the shipped files and asserts `errors()` is empty.

## Alternatives Considered

### Alternative 1: One JSON or ConfigFile key-value store
- **Description**: `get_float(&"stun_duration_s")` over one parsed file (architecture.md's original API).
- **Pros**: Plain text, diff-friendly, one file.
- **Cons**: A typo in a key is found only when that line runs; types are checked by hand; ranges need a separate schema.
- **Rejection Reason**: Typed fields catch code-side name errors at parse time and file-side ones at load (unset check), and `@export_range` carries the range once.

### Alternative 2: Constants in a GDScript file
- **Description**: `const STUN_DURATION_S := 2.0`.
- **Pros**: Zero loading code.
- **Cons**: Values are code; violates the coding standard's external-config rule.
- **Rejection Reason**: Ruled out by the coding standard.

### Alternative 3: Host sends knob values to clients
- **Description**: Clients adopt the host's values after join.
- **Pros**: The host can tune alone.
- **Cons**: A validated typed payload and a client-relevant subset to maintain.
- **Rejection Reason**: The hash in the existing version check costs nothing and keeps everyone on shipped data.

### Alternative 4: Fall back to defaults on a bad file
- **Description**: Log and continue with built-in defaults.
- **Pros**: The game always starts.
- **Cons**: Defaults become a second source of truth, and a typo ships a quietly different game.
- **Rejection Reason**: Refusing to host makes the error visible at once.

## Consequences

### Positive
- Knob-name typos in code fail at parse time; typos in data files fail the unset check at load. Ranges are written once.
- Host and clients provably run the same values.
- `.tres` files are editable in the Godot inspector with range sliders.

### Negative
- About 12 section classes to write and keep in step with the GDD tables.
- A knob outside its GDD safe range cannot be playtested without widening the range first.
- Every playtester must update data files for a tune.

## Risks
- **GDD-table drift.** A GDD knob added or renamed without its field. Mitigation: a test lists every Tuning Knobs name in `design/gdd/*.md` and asserts a matching field exists.
- **Hint-string format.** If `@export_range` hint strings differ on 4.7, range checks silently pass. Mitigation: Verification item 1, and a test with an out-of-range fixture that must fail.
- **Cache mutation.** A module writing a cached resource would leak into the next round. Mitigation: `CACHE_MODE_IGNORE` and the no-write rule.
- **Float digest instability.** The same values could serialize differently across platforms. Mitigation: Verification item 4; MVP targets Windows PC only.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| All 10 system GDDs | "Every value in Tuning Knobs is loaded from data, not hardcoded" (AC in each) | §1–3 |
| All 10 system GDDs | Safe ranges per knob | §4 range check from `@export_range` |
| first-person-controller.md | Client-predicted movement and hold bars use the same values as the server | §7 digest in the join check |
| lobby-role-assignment.md | Rule 2: reject a version mismatch with a reason | §7 reuses `version_mismatch` |
| monster-abilities.md | `max_rewind_ms` bound by the dodge budget (ADR-0003) | §4 cross-knob rule |

## Performance Implications
- **CPU**: Load and validation once per boot and debug reload; well under 10 ms (inference: about 12 small files).
- **Memory**: About 120 values; negligible.
- **Load Time**: About 12 small resource loads at boot.
- **Network**: 9 more characters in the auth version string.

## Migration Plan
No production code exists. architecture.md §Data/Config and ADR-0001 §3 get amendment notes alongside this ADR.

## Validation Criteria
- An integration test loads the shipped files and gets no errors.
- An out-of-range value, a missing value and a broken cross-knob rule each produce a named error and block hosting.
- A client with one changed knob is rejected with `version_mismatch`.
- A test asserts every GDD Tuning Knobs name has a section field.

## Related
- ADR-0001 (amended: version string), ADR-0002 (`sim_tick_hz`), ADR-0003 (dodge-budget rule), ADR-0005 (injection), ADR-0008 (hold values)
- `docs/architecture/architecture.md` §Data/Config (amended)
- All `design/gdd/*.md` Tuning Knobs sections
