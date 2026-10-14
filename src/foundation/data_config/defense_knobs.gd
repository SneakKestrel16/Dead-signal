class_name DefenseKnobs extends Resource
## Defense system knobs (ADR-0006 example section; remaining fields arrive in story 002).

@export_range(1.0, 3.0) var stun_duration_s: float = NAN
@export_range(1, 3) var stun_item_charges: int = KnobUnset.INT
