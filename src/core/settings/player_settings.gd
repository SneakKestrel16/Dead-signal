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
## Choice lists of the [default, choices] settings below.
const WINDOW_MODES := ["Windowed", "Fullscreen", "Borderless"]
const FPS_LIMITS := ["Unlimited", "30", "60", "120", "144", "240"]
const MIC_MODES := ["Open mic", "Push to talk"]
## key -> [default] for a toggle, [default, min, max] for a slider, [default, choices] for a choice: an index
## into `choices`, or a String when `choices` is empty (filled at runtime: the microphone list).
## Volumes 0-1, default 80% (accessibility-requirements.md Independent volume controls). flash_scale 0-1
## (scare-events.md rule 24). hud_scale 0.75-1.5 (hud.md Tuning Knobs). camera_flinch on (ADR-0015 §4). captions
## off (hud.md H18, accessibility-requirements.md: PA and scare voice lines).
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
	&"captions": [false],
	# Video (design/ux/interaction-patterns.md P27 Video tab). Inference: the choice lists and the 50-100% render
	# scale floor are ours, no spec gives them.
	&"window_mode": [0, WINDOW_MODES],
	&"vsync": [true],
	&"fps_limit": [0, FPS_LIMITS],
	&"render_scale": [1.0, 0.5, 1.0],
	# Voice chat (pings-and-callouts.md rules 18-19). Stored for the voice module; the mic list is the system's.
	&"voice_chat_volume": [0.8, 0.0, 1.0],
	&"mic_volume": [1.0, 0.0, 2.0],
	&"mic_mode": [0, MIC_MODES],
	&"mic_device": ["Default", []],
}
## Bus the voice module plays other players' voices on; written by apply_audio() once it exists.
const VOICE_CHAT_BUS := &"VoiceChat"
## Settings file section of the input bindings (InputBindings codes).
const BINDINGS_SECTION := "bindings"
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
var captions := false
var window_mode := 0
var vsync := true
var fps_limit := 0
var render_scale := 1.0
var voice_chat_volume := 0.8
var mic_volume := 1.0
var mic_mode := 0
var mic_device := "Default"
## action -> {"kb": code, "pad": code} (InputBindings); only rebound slots are stored.
var bindings: Dictionary = {}

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
		if cfg.has_section(BINDINGS_SECTION):
			for action: String in cfg.get_section_keys(BINDINGS_SECTION):
				var v: Variant = cfg.get_value(BINDINGS_SECTION, action)
				if v is Dictionary:
					bindings[StringName(action)] = v
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
	for action: StringName in bindings:
		cfg.set_value(BINDINGS_SECTION, action, bindings[action])
	return cfg.save(_path)


## Rebinds `action`'s slot of `e`'s kind, live and in `bindings` (saved by save()); emits `changed` with
## &"bindings".
func set_binding(action: StringName, e: InputEvent) -> void:
	var code := InputBindings.encode(e)
	if code.is_empty():
		return
	InputBindings.bind(action, e)
	var slot := "pad" if InputBindings.slot_of(e) == InputBindings.Slot.PAD else "kb"
	var entry: Dictionary = bindings.get_or_add(action, {})
	entry[slot] = code
	changed.emit(&"bindings")


## Drops every rebinding: the project defaults return.
func reset_bindings() -> void:
	bindings.clear()
	InputBindings.reset_all()
	changed.emit(&"bindings")


## Applies the stored bindings over the project defaults (at load; the owner calls it once).
func apply_bindings() -> void:
	InputBindings.apply(bindings)


## Writes window mode, V-Sync, the frame cap and `viewport`'s 3D render scale. Skipped headless.
func apply_video(viewport: Viewport) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var modes: Array[DisplayServer.WindowMode] = [DisplayServer.WINDOW_MODE_WINDOWED,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, DisplayServer.WINDOW_MODE_FULLSCREEN]
	var mode := modes[window_mode]
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0 if fps_limit == 0 else String(FPS_LIMITS[fps_limit]).to_int()
	if viewport != null:
		viewport.scaling_3d_scale = render_scale


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
	if not write_db.is_valid():
		if AudioServer.get_bus_index(VOICE_CHAT_BUS) >= 0:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(VOICE_CHAT_BUS), linear_to_db(voice_chat_volume))
		if mic_device in AudioServer.get_input_device_list() and AudioServer.input_device != mic_device:
			AudioServer.input_device = mic_device


## Untrusted file values too: the type must match the default (an int is taken for a float); floats clamp.
func _store(key: StringName, value: Variant) -> bool:
	var spec: Array = SPEC[key]
	if spec[0] is String:
		if not value is String or (value as String).length() > 256:
			return false
		set(key, value)
		return true
	if spec[0] is int:
		if not value is int or value < 0 or value >= (spec[1] as Array).size():
			return false
		set(key, value)
		return true
	if spec[0] is bool:
		if not value is bool:
			return false
		set(key, value)
		return true
	if not (value is float or value is int):
		return false
	set(key, clampf(float(value), spec[1], spec[2]))
	return true
