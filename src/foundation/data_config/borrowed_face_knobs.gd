class_name BorrowedFaceKnobs extends Resource
## BorrowedFace knobs. Owning source: design/gdd/borrowed-face.md.
## Defaults are unset sentinels; values come only from res://data/knobs/borrowed_face.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.borrowed_face.transform_duration_s`

@export_range(1.0, 4.0) var transform_duration_s: float = NAN
@export_range(6.0, 30.0) var form_change_cooldown_s: float = NAN
@export_range(8.0, 25.0) var distortion_radius_m: float = NAN
@export_range(8.0, 25.0) var observe_range_m: float = NAN
@export_range(60.0, 120.0) var observe_fov_deg: float = NAN
@export_range(1.0, 6.0) var observe_time_s: float = NAN
@export_range(5.0, 15.0) var reveal_radius_m: float = NAN


## Cross-knob rules within this section; [] = valid. None are named in its GDD or ADRs yet.
func validate_cross() -> PackedStringArray:
	return []
