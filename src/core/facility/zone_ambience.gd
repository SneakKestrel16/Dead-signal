class_name ZoneAmbience extends Node
## Client zone ambience (story facility-map/012; ADR-0013 §6; research-facility.md Audio Direction,
## TR-facility-008). Finds the listener's lighting volume with the analytic box test (MapQueries.volume_at,
## never Area3D: ADR-0007 §9) and crossfades two non-positional players on the Ambience bus to the bed of that
## volume's zone. Presentation only: it decides nothing and emits nothing. A listener in no volume (or parked
## below the map) keeps the last bed. The players are AudioStreamPlayer (non-positional), so the 4.7 AudioStreamPlayer3D area_mask
## default (breaking-changes.md) does not apply.
## Not here: the B3 machinery loop (a positional WorldSFX loop through ADR-0013's AudioDirector, not built
## yet), the Evacuation alarm bed (Scare Events / M4 audio pass) and ducking of Ambience (ADR-0013 §4).
## Beds come from the SoundBank (`ambience/<zone>`, audio pass); a zone with no entry keeps its placeholder tone.
## Usage:
##   var amb := ZoneAmbience.new(map, ZoneAmbience.bank_beds(SoundBank.load_shipped()), body)
##   add_child(amb); hud.add_child(amb.make_overlay())

## ADR-0013 §1 bus, looked up by name in default_bus_layout.tres.
const BUS := &"Ambience"
## Seconds a bed takes to fade fully in or out. NOT SOURCEABLE: ADR-0013 §6 and the level doc give no number;
## 1.5 s is a placeholder, promoted to a knob when the audio pass sets it.
const CROSSFADE_S := 1.5
## A listener below this height is parked off the map (RoundClient / RoundComposer park bodies 1000 m down
## before spawn) and does not count as being in the volume above it: volume tests use x and z only.
const PARKED_BELOW_Y := -100.0
## PLACEHOLDER beds: no audio assets yet, so each zone gets a distinct generated sine (Hz) to tell beds apart.
## The audio pass replaces them with the research-facility.md Audio Direction beds (A fluorescent hum, B
## server fans, C security tone). Inference: &"link" (service corridors) has no row in that table and gets
## its own bed; the level designer settles it.
const PLACEHOLDER_HZ: Dictionary[StringName, int] = {&"A": 110, &"B": 70, &"C": 220, &"link": 55}
const PLACEHOLDER_RATE := 22050
const PLACEHOLDER_AMPLITUDE := 0.2

## Zone whose bed is fading in or playing (&"" before the listener first enters a volume).
var active_zone: StringName = &""
## The listener's last volume id.
var active_volume: StringName = &""
## The two bed players, built once here (ADR-0013: no players created later).
var players: Array[AudioStreamPlayer] = []

var _queries: MapQueries
var _zone_of: Dictionary[StringName, StringName] = {}
var _beds: Dictionary[StringName, AudioStream]
var _listener: Node3D
var _overlay: Label
## Per player: fade weight 0..1 and the zone its stream belongs to.
var _weights: Array[float] = [0.0, 0.0]
var _zones: Array[StringName] = [&"", &""]
## Index of the player fading in.
var _active := 0


## `beds` maps a zone (MapVolume.zone) to its loop; a zone with none fades to silence. `listener` (the own
## body) is read every frame; null = driven by step() only (tests).
func _init(map: MapData, beds: Dictionary[StringName, AudioStream], listener: Node3D = null) -> void:
	_queries = MapQueries.new(map)
	for v in map.volumes:
		_zone_of[v.id] = v.zone
	_beds = beds
	_listener = listener
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		p.volume_db = linear_to_db(0.0)
		add_child(p)
		players.append(p)


func _process(delta: float) -> void:
	if _listener != null and is_instance_valid(_listener) and _listener.is_inside_tree():
		step(_listener.global_position, delta)
	if _overlay != null:
		_overlay.text = debug_text()


## Moves the fades `delta` seconds on with the listener at `at`.
func step(at: Vector3, delta: float) -> void:
	var vol := _queries.volume_at(at) if at.y > PARKED_BELOW_Y else &""
	if vol != &"":
		active_volume = vol
		if _zone_of[vol] != active_zone:
			_switch(_zone_of[vol])
	var rate := delta / CROSSFADE_S
	for i in 2:
		_weights[i] = move_toward(_weights[i], 1.0 if i == _active else 0.0, rate)
		var p := players[i]
		p.volume_db = linear_to_db(_weights[i])
		if _weights[i] > 0.0 and p.stream != null and not p.playing:
			p.play()
		elif _weights[i] == 0.0 and p.playing:
			p.stop()


## The fading-out player takes the new bed; if it already holds it (turning back mid-fade) it keeps its
## weight and fades back in without a restart.
func _switch(zone: StringName) -> void:
	active_zone = zone
	var other := 1 - _active
	if _zones[other] != zone:
		_zones[other] = zone
		_weights[other] = 0.0
		players[other].stop()
		players[other].stream = _beds.get(zone)
	_active = other
	print("AMBIENCE zone %s volume %s bus %s" % [zone, active_volume, BUS])


## One line for the debug overlay: zone, volume, bus and each bed's level.
func debug_text() -> String:
	var parts := PackedStringArray()
	for i in 2:
		parts.append("%s %.1f dB" % [_zones[i] if _zones[i] != &"" else "-", players[i].volume_db])
	return "Ambience: zone %s, volume %s, bus %s [%s]" % [active_zone, active_volume, BUS, " | ".join(parts)]


## A Label kept showing debug_text() (audio has no screenshot; the evidence capture reads this).
func make_overlay() -> Label:
	_overlay = Label.new()
	_overlay.position = Vector2(8.0, 8.0)
	return _overlay


## The bank's bed (`ambience/<zone>`, looping) for every zone in PLACEHOLDER_HZ, its placeholder tone where the
## bank has none.
static func bank_beds(bank: SoundBank) -> Dictionary[StringName, AudioStream]:
	var out := placeholder_beds()
	for zone: StringName in out:
		var e := bank.resolve(StringName("ambience/" + zone))
		if e != null and e.stream != null:
			out[zone] = e.stream
	return out


## PLACEHOLDER beds for every zone in PLACEHOLDER_HZ.
static func placeholder_beds() -> Dictionary[StringName, AudioStream]:
	var out: Dictionary[StringName, AudioStream] = {}
	for zone: StringName in PLACEHOLDER_HZ:
		out[zone] = placeholder_tone(PLACEHOLDER_HZ[zone])
	return out


## A one-second looping 16-bit mono sine at `hz` (whole cycles, so the loop is seamless). PLACEHOLDER asset.
static func placeholder_tone(hz: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(PLACEHOLDER_RATE * 2)
	for i in PLACEHOLDER_RATE:
		data.encode_s16(i * 2, int(sin(TAU * hz * i / float(PLACEHOLDER_RATE)) * PLACEHOLDER_AMPLITUDE * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = PLACEHOLDER_RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = PLACEHOLDER_RATE
	return w
