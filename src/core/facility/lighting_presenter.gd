class_name LightingPresenter extends Node3D
## Client lighting of the greybox (facility-map story 010; research-facility.md Lighting States, Precedence,
## AC 9 and TR-facility-010 reduced flash; ADR-0009 §6). One child Node3D per map volume (named by volume
## id) holding its fixture groups, each a Node3D of dynamic lights: overhead (downward spots on a grid),
## emergency_strip (faint floor omnis), beacon (rotating spot) and beacon_steady (its reduced-flash variant),
## fuse_indicator, terminal_alarm (pulsing, steady when reduced) and exit_light. Looks come from
## LightingPresets only. Applies received records (EventBatch.LIGHTING, routed by ClientEventRouter) by
## precedence: base, then overlays on their own fixtures, then Blackout (every group off except
## emergency_strip). It never changes lighting state itself; a volume never received shows round start (Low
## Power). Changes are instant: light_fade_s is not sourceable yet (FacilityKnobs). Every light's reach is
## clipped to its own volume (ADR-0009 §6; lighting_presenter_test checks it).
## Not here: flicker (Scare Events), route lights, the load-time pre-warm (ADR-0009 §6, Verification 9).
## Usage:
##   var lights := LightingPresenter.new(map, LightingPresets.load_shipped())
##   parent.add_child(lights); camera.environment = lights.presets.environment()
##   router.subscribe(EventBatch.LIGHTING, lights.on_lighting)

const GROUPS: Array[StringName] = [&"overhead", &"emergency_strip", &"beacon", &"beacon_steady",
	&"fuse_indicator", &"terminal_alarm", &"exit_light"]
## Fixture heights below the ceiling and above the floor, m (greybox placement, not a look).
const CEILING_GAP_M := 0.1
const STRIP_HEIGHT_M := 0.1
## Beacon cone: half-angle and downward tilt, degrees (greybox placement).
const BEACON_ANGLE_DEG := 30.0
const BEACON_TILT_DEG := -45.0

## The presets in use.
var presets: LightingPresets
## The accessibility reduced-flash setting (Accessibility Options owns it; no settings store yet).
## Setting it re-applies every volume.
var reduced_flash := false:
	set(on):
		reduced_flash = on
		for v in _records:
			_apply(v)

## volume -> {base, overlays, dark_until} last applied.
var _records: Dictionary[StringName, Dictionary] = {}
var _zone: Dictionary[StringName, StringName] = {}
var _time := 0.0


func _init(map: MapData, presets_: LightingPresets) -> void:
	presets = presets_
	name = &"Lighting"
	for v in map.volumes:
		_zone[v.id] = v.zone
		_build(v)
		_records[v.id] = {"base": FacilityLighting.Base.LOW_POWER, "overlays": 0, "dark_until": 0}
		_apply(v.id)


## ClientEventRouter handler for EventBatch.LIGHTING: {volume, base, overlays, dark_until}. Server bytes, still
## checked: an unknown volume or a field of the wrong type or range drops the record.
func on_lighting(_tick: int, payload: Dictionary) -> void:
	var v: Variant = payload.get("volume")
	if not (v is StringName or v is String) or not _records.has(StringName(v)):
		return
	for k in ["base", "overlays", "dark_until"]:
		if not payload.get(k) is int:
			return
	if payload.base < 0 or payload.base >= FacilityLighting.Base.size():
		return
	_records[StringName(v)] = {"base": payload.base, "overlays": payload.overlays, "dark_until": payload.dark_until}
	_apply(StringName(v))


## The last applied record of `volume` ({base, overlays, dark_until}), {} for an unknown id.
func record_of(volume: StringName) -> Dictionary:
	return _records.get(volume, {})


## Spins visible beacons and pulses visible alarms; both hold still under reduced flash.
func _process(delta: float) -> void:
	_time += delta
	if reduced_flash:
		return
	var pulse := 0.5 + 0.5 * sin(TAU * presets.alarm_pulse_hz * _time)
	for v in _records:
		var vol := get_node(NodePath(String(v)))
		var beacon := vol.get_node(^"beacon") as Node3D
		if beacon.visible:
			beacon.rotation.y = deg_to_rad(presets.beacon_spin_deg_s) * _time
		var alarm := vol.get_node(^"terminal_alarm") as Node3D
		if alarm.visible:
			(alarm.get_child(0) as Light3D).light_energy = presets.overlay_energy * pulse


func _apply(v: StringName) -> void:
	var r := _records[v]
	var vol := get_node(NodePath(String(v)))
	var base: int = r.base
	var bits: int = r.overlays
	var lit: bool = r.dark_until == 0 ## Blackout: everything but emergency_strip off
	var energy := presets.overhead_energy[base]
	if base == FacilityLighting.Base.LOW_POWER:
		energy *= presets.low_power_zone_scale.get(_zone[v], 1.0)
	_show(vol, &"overhead", lit and energy > 0.0)
	for l: Light3D in vol.get_node(^"overhead").get_children():
		l.light_energy = energy
	_show(vol, &"emergency_strip", true)
	var beacon := lit and base == FacilityLighting.Base.EVACUATION and vol.get_node(^"beacon").get_child_count() > 0
	_show(vol, &"beacon", beacon and not reduced_flash)
	_show(vol, &"beacon_steady", beacon and reduced_flash)
	_show(vol, &"fuse_indicator", lit and bits & FacilityLighting.OVERLAY_FUSE_INSTALLED != 0)
	_show(vol, &"terminal_alarm", lit and bits & FacilityLighting.OVERLAY_TERMINAL_ACTIVATING != 0)
	(vol.get_node(^"terminal_alarm").get_child(0) as Light3D).light_energy = presets.overlay_energy
	_show(vol, &"exit_light", lit and bits & FacilityLighting.OVERLAY_EXIT_OPEN != 0)


func _show(vol: Node, group: StringName, on: bool) -> void:
	(vol.get_node(NodePath(String(group))) as Node3D).visible = on


func _build(v: MapVolume) -> void:
	var vol := Node3D.new()
	vol.name = v.id
	add_child(vol)
	vol.position = Vector3(v.box.get_center().x, v.box.position.y, v.box.get_center().z)
	var groups := {}
	for g in GROUPS:
		var n := Node3D.new()
		n.name = g
		vol.add_child(n)
		groups[g] = n
	var top := v.box.size.y - CEILING_GAP_M
	var nx := maxi(1, ceili(v.box.size.x / presets.overhead_cell_m))
	var nz := maxi(1, ceili(v.box.size.z / presets.overhead_cell_m))
	var cell := Vector2(v.box.size.x / nx, v.box.size.z / nz)
	var half := minf(cell.x, cell.y) / 2.0
	var colour: Color = presets.zone_colour.get(v.zone, Color.WHITE)
	for i in nx:
		for k in nz:
			var at := Vector3(-v.box.size.x / 2.0 + cell.x * (i + 0.5), 0.0, -v.box.size.z / 2.0 + cell.y * (k + 0.5))
			var s := SpotLight3D.new()
			s.light_color = colour
			s.spot_range = top * 1.3 ## past the floor, so the floor is not at the attenuation's zero
			s.spot_angle = rad_to_deg(atan(half / top)) ## the cone meets the floor inside its cell
			s.rotation_degrees.x = -90.0
			s.position = at + Vector3.UP * top
			groups[&"overhead"].add_child(s)
			groups[&"emergency_strip"].add_child(_omni(presets.emergency_colour, presets.emergency_energy,
					minf(presets.emergency_range_m, half), at + Vector3.UP * STRIP_HEIGHT_M))
	var reach := minf(presets.overlay_range_m, minf(v.box.size.x, v.box.size.z) / 2.0)
	var centre := Vector3.UP * top
	if String(v.id) in presets.beacon_volumes:
		var spot := SpotLight3D.new()
		spot.light_color = presets.beacon_colour
		spot.light_energy = presets.beacon_energy
		spot.spot_range = reach
		spot.spot_angle = BEACON_ANGLE_DEG
		spot.rotation_degrees.x = BEACON_TILT_DEG
		groups[&"beacon"].position = centre
		groups[&"beacon"].add_child(spot)
		groups[&"beacon_steady"].add_child(_omni(presets.beacon_colour, presets.beacon_steady_energy, reach, centre))
	groups[&"fuse_indicator"].add_child(_omni(presets.fuse_colour, presets.overlay_energy, reach, centre))
	groups[&"terminal_alarm"].add_child(_omni(presets.alarm_colour, presets.overlay_energy, reach, centre))
	groups[&"exit_light"].add_child(_omni(presets.exit_colour, presets.overlay_energy, reach, centre))


func _omni(colour: Color, energy: float, reach: float, at: Vector3) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.light_color = colour
	o.light_energy = energy
	o.omni_range = reach
	o.position = at
	return o
