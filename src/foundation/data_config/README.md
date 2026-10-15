# Data/Config (knobs)

Typed knob sections and their loader (ADR-0006). `Knobs.load_all()` loads the fixed
section list in `Knobs.SECTIONS` from `res://data/knobs/<section>.tres`, validates
ranges and unset fields, and reports every problem through `errors()`.

- One `<System>Knobs` class per section in this folder; field name = GDD knob name,
  `@export_range` = the GDD Safe Range, default = unset sentinel (`NAN` / `KnobUnset.INT`).
- Values live only in `data/knobs/*.tres`. A misspelled key in a file loads silently and
  leaves the real field unset, so `errors()` reports it.
- The loader never enumerates the folder and never loads from `user://` or a player path.
  `load_all(dir)` accepts another directory only in debug builds (test hook).

## Export

No scene references the knob files, so the export preset must include them explicitly.
The committed `export_presets.cfg` ("Dead Signal Windows", output under the ignored `build/`)
carries this on its Windows preset, and `tests/unit/data_config/export_preset_test.gd` checks it.
Keep it on any preset you add (secrets stay out of this file):

```ini
include_filter="data/knobs/*"
```

The preset also excludes `tests/` and `addons/gdUnit4/`: the first export shipped the test
framework in the pck (1.96 MB; 1.1 MB without it). On 2026-10-14 the exported pck gave the same
`Knobs.join_version("0.1.0")` as the editor, `0.1.0+85316932`, so release clients can join an
editor host. Godot does not create a missing output folder: `mkdir -p build/windows` before a
command-line export, or it writes nothing and still exits quietly.

In the export the files load by their `res://` path (through `.remap` entries), which is
why `Knobs` uses a fixed name list instead of listing the folder.

## Tests

- `tests/unit/data_config/knob_section_validation_test.gd`: range/unset checks.
- `tests/integration/data_config/shipped_knobs_test.gd`: every GDD knob has a field;
  shipped files load with no errors; misspelled key reported; paths stay under
  `res://data/knobs/`.
