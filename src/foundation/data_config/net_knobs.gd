class_name NetKnobs extends Resource
## Network/simulation knobs (ADR-0001/0002/0003). Defaults are unset sentinels;
## values come only from data files.

## Simulation ticks per second. Range 30..128 kept by designer decision 2026-10-13;
## ADR-0002 fixes only the value 60.
@export_range(30, 128) var sim_tick_hz: int = KnobUnset.INT
