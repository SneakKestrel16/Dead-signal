class_name LightingPresets extends Resource
## Light looks per lighting state, client side (facility-map story 010; research-facility.md Lighting States
## and Precedence; ADR-0009 §6: "Light looks must come from LightingPresets, never from code"). Values come
## only from res://data/lighting/lighting_presets.tres. Every number there is a greybox placeholder: the GDD
## gives looks in words only (zone colours, "Zone B dimmest", "~50%" in Evacuation, "faint" strips), and the
## M4 horror pass owns the real values.
## Fixture groups (ADR-0009 §6): overhead, emergency_strip, beacon (rotating; beacon_steady is its
## reduced-flash variant), fuse_indicator, terminal_alarm (pulsing; steady when reduced), exit_light.
## Not here: route lights to the terminal (needs the route through the map; later story).
## Usage: `var p := LightingPresets.load_shipped()`

const PATH := "res://data/lighting/lighting_presets.tres"

## Map zone (A, B, C, link) -> overhead colour.
@export var zone_colour: Dictionary[StringName, Color] = {}
## Overhead energy per FacilityLighting.Base (Low Power, Power Restored, Evacuation).
@export var overhead_energy: PackedFloat32Array = PackedFloat32Array()
## Map zone -> overhead energy scale under Low Power only ("Zone B dimmest").
@export var low_power_zone_scale: Dictionary[StringName, float] = {}
## Overheads sit on a grid of cells at most this wide, one downward spot per cell, m.
@export var overhead_cell_m: float = 6.0
@export var emergency_colour: Color = Color.RED
@export var emergency_energy: float = 0.2
## Floor-level strip light range, m (clipped to its cell).
@export var emergency_range_m: float = 2.0
## Volumes holding an Evacuation beacon (H-N, H-S, C2 toward C4, and C4).
@export var beacon_volumes: PackedStringArray = PackedStringArray()
@export var beacon_colour: Color = Color.ORANGE
@export var beacon_energy: float = 4.0
@export var beacon_spin_deg_s: float = 180.0
## The reduced-flash beacon: a steady light of this energy instead of the rotating one.
@export var beacon_steady_energy: float = 1.0
@export var fuse_colour: Color = Color.GREEN
@export var alarm_colour: Color = Color.RED
@export var exit_colour: Color = Color.GREEN
@export var overlay_energy: float = 2.0
## Fixture light range (beacons, indicators, alarms, exit), m (clipped to the volume).
@export var overlay_range_m: float = 6.0
## Terminal alarm pulse rate, Hz; at most 3 (scare-events.md rule 25 flash cap). Reduced flash: steady.
@export_range(0.0, 3.0) var alarm_pulse_hz: float = 1.0
## Camera environment: ambient light and glow (glow runs before tonemapping since 4.6, so strips and
## beacons bloom; tune here, not in code, ADR-0009 §6).
@export var ambient_colour: Color = Color.WHITE
@export var ambient_energy: float = 0.05
@export var glow_intensity: float = 0.8


## The shipped presets.
static func load_shipped() -> LightingPresets:
	return load(PATH) as LightingPresets


## A camera Environment from these presets: black background, ambient colour, glow on. API names are from
## training data (Environment existed before 4.4); `modules/rendering.md` lists only the 4.6 glow order.
func environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = ambient_colour
	e.ambient_light_energy = ambient_energy
	e.glow_enabled = glow_intensity > 0.0
	e.glow_intensity = glow_intensity
	return e
