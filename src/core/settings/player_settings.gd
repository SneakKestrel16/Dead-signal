class_name PlayerSettings extends RefCounted
## The local player's settings (design/game-brief.md MVP "settings menu"; design/accessibility-requirements.md;
## design/ux/hud.md Tuning Knobs). Typed values with defaults, loaded from and saved to a ConfigFile. The
## command-line flags `--reduced-motion` and `--reduced-flash` (after `--`) still turn their setting on for
## the session: the flagged value is not saved unless the player sets that setting in the menu.
## Presentation only (scare-events.md rule 29): the owners apply the values; LobbyScreen forwards `changed`.
## Usage:
##   var s := PlayerSettings.new()            # loads user://settings.cfg, applies the flags
##   s.set_value(&"master_volume", 0.5); s.apply_audio(); s.save()

signal changed(key: StringName)

const PATH := "user://settings.cfg"
const SECTION := "settings"
## key -> [default] for a toggle, [default, min, max] for a slider.
## Volumes 0-1, default 80% (accessibility-requirements.md Independent volume controls). flash_scale 0-1
## (scare-events.md rule 24). hud_scale 0.75-1.5 (hud.md Tuning Knobs). camera_flinch on (ADR-0015 §4).
## mouse_sensitivity rad/px and stick_rate rad/s: LocalInput's defaults; the 0.25x-4x and 1-6 rad/s ranges are
## NOT SOURCEABLE (inference; a playtest settles them).
const SPEC := {
	&"reduced_motion": [false],
	&"reduced_flash": [false],
	&"flash_scale": [1.0, 0.0, 1.0],
	&"camera_flinch": [true],
	&"master_volume": [0.8, 0.0, 1.0],
	&"effects_volume": [0.8, 0.0, 1.0],
	&"voice_volume": [0.8, 0.0, 1.0],
	&"stinger_volume": [0.8, 0.0, 1.0],
	&"scare_volume": [0.8, 0.0, 1.0],
	&"mouse_sensitivity": [0.0025, 0.000625, 0.01],
	&"stick_rate": [3.0, 1.0, 6.0],
	&"hud_scale": [1.0, 0.75, 1.5],
}
## User flag -> the toggle it turns on for the session.
const FLAGS := {"--reduced-motion": &"reduced_motion", "--reduced-flash": &"reduced_flash"}
## Volume setting -> ADR-0013 §1 bus written by apply_audio(). Stinger and Scare are written by ScareAudio
## (their owner, rule 26) from RoundClient.apply_settings.
const BUSES := {&"master_volume": &"Master", &"effects_volume": &"SFX", &"voice_volume": &"Voice"}

var reduced_motion := false
var reduced_flash := false
var flash_scale := 1.0
var camera_flinch := true
var master_volume := 0.8
var effects_volume := 0.8
var voice_volume := 0.8
var stinger_volume := 0.8
var scare_volume := 0.8
var mouse_sensitivity := 0.0025
var stick_rate := 3.0
var hud_scale := 1.0

var _path: String
## key -> the stored value a flag hides for this session (saved instead of the flagged one).
var _flagged: Dictionary[StringName, Variant] = {}


## Loads `path` (missing or unreadable = defaults), then applies the flags in `args`.
func _init(path: String = PATH, args: PackedStringArray = OS.get_cmdline_user_args()) -> void:
	_path = path
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		for key: StringName in SPEC:
			if cfg.has_section_key(SECTION, key):
				_store(key, cfg.get_value(SECTION, key))
	for flag: String in FLAGS:
		if args.has(flag):
			_flagged[FLAGS[flag]] = get(FLAGS[flag])
			set(FLAGS[flag], true)


## Sets `key` (clamped to its range; a value of the wrong type is ignored) and emits `changed`. A setting the
## player sets is no longer flag-held: its value is saved.
func set_value(key: StringName, value: Variant) -> void:
	if not SPEC.has(key) or not _store(key, value):
		return
	_flagged.erase(key)
	changed.emit(key)


## Writes every setting to the file; flag-held settings keep their stored value.
func save() -> Error:
	var cfg := ConfigFile.new()
	for key: StringName in SPEC:
		cfg.set_value(SECTION, key, _flagged.get(key, get(key)))
	return cfg.save(_path)


## The flash intensity scale presenters use: 0 under reduced flash (non-flashing change, rule 25).
func effective_flash_scale() -> float:
	return 0.0 if reduced_flash else flash_scale


## Writes the Master, SFX and Voice bus volumes. `write_db(bus, db)` defaults to AudioServer (tests fake it).
func apply_audio(write_db: Callable = Callable()) -> void:
	for key: StringName in BUSES:
		var db := linear_to_db(get(key))
		if write_db.is_valid():
			write_db.call(BUSES[key], db)
		elif AudioServer.get_bus_index(BUSES[key]) >= 0:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUSES[key]), db)


## Untrusted file values too: the type must match the default (an int is taken for a float); floats clamp.
func _store(key: StringName, value: Variant) -> bool:
	var spec: Array = SPEC[key]
	if spec[0] is bool:
		if not value is bool:
			return false
		set(key, value)
		return true
	if not (value is float or value is int):
		return false
	set(key, clampf(float(value), spec[1], spec[2]))
	return true
