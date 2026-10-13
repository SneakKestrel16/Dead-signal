extends Resource
## ADR-0006 knob section shape.

@export_range(1.0, 4.0) var stun_duration_s: float = NAN
@export_range(1, 3) var stun_item_charges: int = -2147483648
@export_range(0.0, 10.0, 0.1, "or_greater") var extra_s: float = NAN
