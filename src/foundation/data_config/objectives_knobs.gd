class_name ObjectivesKnobs extends Resource
## Objectives knobs. Owning source: design/gdd/survivor-objectives.md.
## Defaults are unset sentinels; values come only from res://data/knobs/objectives.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.objectives.evac_activation_s`

@export_range(10.0, 25.0) var evac_activation_s: float = NAN
@export_range(3.0, 10.0) var drive_extract_s: float = NAN
@export_range(5.0, 12.0) var fuse_install_s: float = NAN
@export_range(1.0, 4.0) var dock_s: float = NAN
@export_range(0.5, 2.0) var pickup_s: float = NAN
@export_range(1, 2) var max_drives_carried: int = KnobUnset.INT
@export_range(0.5, 3.0) var activation_start_s: float = NAN
@export_range(1.5, 2.3) var interact_range_m: float = NAN
@export_range(5.0, 20.0) var alert_area_radius_m: float = NAN
@export_range(3.0, 10.0) var alert_duration_s: float = NAN
@export_range(15.0, 40.0) var install_noise_radius_m: float = NAN
@export_range(4.0, 15.0) var discover_range_m: float = NAN
@export_range(60.0, 120.0) var discover_fov_deg: float = NAN
@export_range(4, 8) var drive_candidates: int = KnobUnset.INT
@export_range(4, 9) var fuse_candidates: int = KnobUnset.INT
@export_range(2, 4) var fuse_box_candidates: int = KnobUnset.INT
@export_range(1, 3) var terminal_candidates: int = KnobUnset.INT


## Cross-knob rules arrive in story data-config/003; none yet.
func validate_cross() -> PackedStringArray:
	return []
