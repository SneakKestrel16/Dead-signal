class_name KnobUnset
## Sentinel for an int knob that no data file has set (ADR-0006 rule 2).
## Standalone so knob sections never reference Knobs (no cyclic class reference).
## Usage: `@export_range(1, 3) var stun_item_charges: int = KnobUnset.INT`

const INT := -2147483648
