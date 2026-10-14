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
`export_presets.cfg` is gitignored, so set this on every Windows preset by hand:

```ini
include_filter="data/knobs/*"
```

In the export the files load by their `res://` path (through `.remap` entries), which is
why `Knobs` uses a fixed name list instead of listing the folder.

## Tests

- `tests/unit/data_config/knob_section_validation_test.gd`: range/unset checks.
- `tests/integration/data_config/shipped_knobs_test.gd`: every GDD knob has a field;
  shipped files load with no errors; misspelled key reported; paths stay under
  `res://data/knobs/`.
