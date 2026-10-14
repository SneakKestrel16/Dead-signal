class_name NetKnobs extends Resource
## Network/simulation knobs (ADR-0001/0002/0003). Defaults are unset sentinels;
## values come only from data files.

## Simulation ticks per second. ponytail: 30..128 range is a placeholder (inference);
## ADR-0002 only fixes the value 60. Settle with the ADR-0002 owner before story 002.
@export_range(30, 128) var sim_tick_hz: int = KnobUnset.INT
