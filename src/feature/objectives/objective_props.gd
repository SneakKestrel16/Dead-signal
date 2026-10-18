class_name ObjectiveProps extends Node
## Client presentation of the objective props MapGreybox placed at every candidate marker (Prop_<id>;
## survivor-objectives.md rules 5, 7; research-facility.md Authored Candidate Points; ADR-0012 §5).
## A drive or fuse prop shows only at an active point this client was granted (CandidateReplication's hidden
## entity, its spawn data carrying the marker position and `objective` id), so an inactive candidate never
## stands there with a drive or fuse in it, and an undiscovered one never reaches a survivor at all.
## Items (rules 10-20, ASSET-086): a Dropped drive or fuse lies where the server says (`at`), a drive with
## the soft cyan glow; docked drives stand in the terminal's dock slots, installed fuses in their box's
## socket; a carrier holds the drive / fuse in the right hand of its remote body (hold_items, from the
## snapshot's carried flags). The carried item is the sanctioned tell (LB-6): it is the server's carrier
## state, never part of a copied look, and the shapeshifter never carries.
## Glows (research-facility.md Lighting States and N-03; ASSET-057/058/060): a fuse box's indicator bar is dark
## on an inactive candidate, dim on an active one and lit once its fuse is in; The Core pulses once per
## install; the terminal screen is dark until power, then shows locked / armed / activating (the countdown) /
## paused / activated by colour and intensity (screen_state). VFX ASSET-082: brief sparks (vfx_fuse_sparks)
## at the box's socket when its fuse goes in; they are not The Core pulse (a light change). The sparks are a
## few small particles, no luminance flash, so they play at reduced flash too (inference; a photosensitivity
## review settles it). Reduced motion or reduced flash holds the
## countdown steady; reduced flash softens The Core's pulse (research-facility.md Accessibility).
## Client only, decides nothing: hidden entities, ObjectiveProgressChanged and the countdown's PROGRESS entry
## in, node visibility and emission out.
## Usage (RoundClient, rendering):
##   var props := ObjectiveProps.new(level, map)
##   add_child(props); props.watch(hidden)
##   router.subscribe(&"ObjectiveProgressChanged", props.on_objective)
##   router.subscribe(EventBatch.PROGRESS, props.on_progress)
##   props.hold_items(remote.get_node(^"Mesh"), entry.drive, entry.fuse)   # per remote body, per frame

## Marker types whose props this presenter drives.
const KINDS: Array[StringName] = [&"drive", &"fuse", &"fuse_box", &"terminal"]
## Objective cyan (tools/art/build_props.py CYAN; art bible §6) for the dropped drive's glow (ASSET-086).
const CYAN := Color("3FA9D6")
## Soft pool under a dropped drive. Inference: ASSET-086 says "soft cyan pool", no numbers; the VFX pass
## settles them.
const DROP_GLOW_ENERGY := 0.6
const DROP_GLOW_RANGE_M := 1.2
## Ejected drives both lie at the terminal point (rule 20): drawn this far apart along x so both show.
const EJECT_SPREAD_M := 0.3
## Prop-local placements, from tools/art/build_props.py (Blender x, y, z -> Godot x, z, -y): the terminal's
## first two dock slots and the fuse box's socket.
const DOCK_SLOTS: Array[Vector3] = [Vector3(-0.4, 0.96, -0.12), Vector3(0.0, 0.96, -0.12)]
const SOCKET := Vector3(0.12, 1.25, 0.0)
## A second carried item (drive and fuse together) sits this far along the first in the hand's grip frame.
const SECOND_ITEM := Vector3(0.0, 0.0, 0.12)
## Glow levels (emission energy multipliers). Inference: the level doc names the states, not the numbers;
## the lighting / VFX pass settles them. Screen colours: null = the model's own neutral `screen` emission,
## amber = the pilot-light amber (build_props.py), activated = The Core's bone white; never cyan
## (ASSET-058: cyan on the dock only).
const INDICATOR_ACTIVE := 1.0
const INDICATOR_INSTALLED := 4.0
const SCREEN_AMBER := Color("D98A2B")
const SCREEN_DONE := Color("E0D6BA")
## screen state -> [colour or null, energy]
const SCREEN := {&"dark": [null, 0.0], &"locked": [null, 1.0], &"armed": [null, 2.0],
	&"activating": [SCREEN_AMBER, 2.0], &"paused": [SCREEN_AMBER, 0.6], &"activated": [SCREEN_DONE, 3.0]}
## Countdown pulse: rate (Hz) and depth (fraction of the energy).
const ACTIVATING_PULSE_HZ := 1.0
const ACTIVATING_PULSE_DEPTH := 0.5
## The Core's install pulse: peak multiple of its own emission, the reduced-flash peak, and its length.
const CORE_PULSE_PEAK := 2.5
const CORE_PULSE_REDUCED_PEAK := 1.3
const CORE_PULSE_S := 0.8

## Accessibility (hud.md / research-facility.md Accessibility); set by RoundClient.
var reduced_motion := false
var reduced_flash := false

var _map: MapData
var _mats: SurfaceMaterials
var _powered := false
var _paused := false
## The Core's glow material (own copy), its built energy, the install pulse time left, the pulse clock.
var _core: StandardMaterial3D
var _core_base := 0.0
var _core_left := 0.0
var _clock := 0.0
## Marker index -> its Prop_<id> node, for every candidate of KINDS the level has a prop for.
var _props: Dictionary[int, Node3D] = {}
## Objective id (SurvivorObjectives.DRIVE_ID + i, ...) -> marker index, from the granted hidden entities.
var _marker_of: Dictionary[int, int] = {}
## Objective id -> newest state the server reported.
var _states: Dictionary[int, int] = {}
## Objective id -> where it lies while Dropped.
var _at: Dictionary[int, Vector3] = {}
## Objective id -> its drawn item (dropped, docked or installed), built on first need.
var _items: Dictionary[int, Node3D] = {}
## Install sparks; look NOT SOURCEABLE (VFX art pass): a warm spark spray falling from the socket.
var _sparks := VfxBurst.make(&"fuse_sparks", Color(1.0, 0.8, 0.45), 20, 0.5, Vector2(1.0, 2.5), 60.0,
		Vector3(0, -9.8, 0), 0.025, VfxBurst.Shape.QUAD, true, Vector3.FORWARD)


## `level`: the root MapGreybox.build returned, or any ancestor of it.
func _init(level: Node, map: MapData) -> void:
	_map = map
	_mats = load(MapGreybox.SURFACES) as SurfaceMaterials
	add_child(_sparks)
	for i in map.markers.size():
		var m := map.markers[i]
		if m.type in KINDS:
			var p := level.find_child("Prop_%s" % m.id, true, false) as Node3D
			if p != null:
				_props[i] = p
	var core := level.find_child("BlockerCore", true, false)
	if core != null and core.has_node(^"Prop"):
		_core = _glow(core.get_node(^"Prop") as Node3D, &"core_glow")
		_core_base = _core.emission_energy_multiplier if _core != null else 0.0
	_refresh()


## Follows `hidden`'s entities: those already there and every one spawned later.
func watch(hidden: HiddenSpawner) -> void:
	hidden.spawned.connect(on_spawned)
	for e in hidden.get_node(^"Entities").get_children():
		on_spawned(e as Node3D)


## HiddenSpawner.spawned: binds an active point's objective id to the marker at its position. Untrusted
## server data is type-checked; anything else is ignored.
func on_spawned(node: Node3D) -> void:
	var d: Variant = node.get_meta(&"data", null) if node != null else null
	if not d is Dictionary:
		return
	var kind: Variant = d.get("kind")
	var pos: Variant = d.get("pos")
	var o: Variant = d.get("objective")
	if not ((kind is StringName or kind is String) and pos is Vector3 and o is int):
		return
	for i in _map.markers.size():
		var m := _map.markers[i]
		if m.type == StringName(kind) and m.position.is_equal_approx(pos):
			_marker_of[o] = i
			_refresh()
			return


## ClientEventRouter handler for ObjectiveProgressChanged (an install alert has no `objective`).
func on_objective(_tick: int, p: Dictionary) -> void:
	var o: Variant = p.get("objective")
	var s: Variant = p.get("state")
	if not (o is int and s is int):
		return
	if o == SurvivorObjectives.TERMINAL_ID and s == SurvivorObjectives.TerminalState.POWERED:
		_powered = true
		_refresh()
		return
	if o >= SurvivorObjectives.FUSE_BOX_ID and o < SurvivorObjectives.TERMINAL_ID \
			and s == SurvivorObjectives.FuseState.INSTALLED and _states.get(o, -1) != s:
		_core_left = CORE_PULSE_S
		var box: Node3D = _props.get(_marker_of.get(o, -1))
		if box != null: # the parent is a plain Node, so the position is the world one
			VfxBurst.fire(_sparks, (box.global_transform if box.is_inside_tree() else box.transform) * SOCKET)
	_states[o] = s
	var at: Variant = p.get("at")
	if at is Vector3 and (at as Vector3).is_finite():
		_at[o] = at
	_refresh()


## ClientEventRouter handler for EventBatch.PROGRESS: only the activation countdown's paused flag matters.
func on_progress(_tick: int, p: Dictionary) -> void:
	if p.get("key") is int and p["key"] == WorldProgress.ACTIVATION_KEY:
		_paused = p.get("paused", false) == true
		_refresh()


## Marker `index`'s terminal screen: dark (no power, or not the active terminal), locked, armed,
## activating, paused or activated.
func screen_state(index: int) -> StringName:
	if _marker_of.get(SurvivorObjectives.TERMINAL_ID, -1) != index:
		return &"dark"
	match _states.get(SurvivorObjectives.TERMINAL_ID, SurvivorObjectives.TerminalState.LOCKED):
		SurvivorObjectives.TerminalState.ARMED:
			return &"armed"
		SurvivorObjectives.TerminalState.ACTIVATING:
			return &"paused" if _paused else &"activating"
		SurvivorObjectives.TerminalState.ACTIVATED:
			return &"activated"
	return &"locked" if _powered else &"dark"


## Emission energy of the `surface` material on marker `index`'s prop: 0 when emission is off, -1 when the
## prop has no such surface.
func glow_energy(index: int, surface: StringName) -> float:
	var m := _glow(_props.get(index), surface)
	if m == null:
		return -1.0
	return m.emission_energy_multiplier if m.emission_enabled else 0.0


## The Core's emission energy multiplier now (-1 without The Core).
func core_energy() -> float:
	return _core.emission_energy_multiplier if _core != null else -1.0


func _process(delta: float) -> void:
	advance(delta)


## Runs the pulses `delta` seconds on: The Core's install pulse and the countdown on the screen.
func advance(delta: float) -> void:
	_clock += delta
	if _core != null:
		_core_left = maxf(_core_left - delta, 0.0)
		var peak := CORE_PULSE_REDUCED_PEAK if reduced_flash else CORE_PULSE_PEAK
		_core.emission_energy_multiplier = _core_base * lerpf(1.0, peak, _core_left / CORE_PULSE_S)
	var t := _terminal()
	if t != null and screen_state(_marker_of[SurvivorObjectives.TERMINAL_ID]) == &"activating" \
			and not (reduced_motion or reduced_flash):
		var wave := 0.5 * (1.0 + sin(TAU * ACTIVATING_PULSE_HZ * _clock))
		_glow(t, &"screen").emission_energy_multiplier = SCREEN[&"activating"][1] * (1.0 - ACTIVATING_PULSE_DEPTH * wave)


## Whether marker `index`'s drive or fuse lies at its console or spawn: active, granted, never taken.
func at_marker(index: int) -> bool:
	for o: int in _marker_of:
		if _marker_of[o] != index:
			continue
		if o < SurvivorObjectives.FUSE_ID:
			return _states.get(o, SurvivorObjectives.DriveState.SECURED) == SurvivorObjectives.DriveState.SECURED
		if o < SurvivorObjectives.FUSE_BOX_ID:
			return _states.get(o, SurvivorObjectives.FuseState.UNFOUND) == SurvivorObjectives.FuseState.UNFOUND
	return false


## Draws the carried drive / fuse in the right hand of the remote body art under `mesh` (BodyVisual's
## Visual; the flashlight is in the left). No skeleton yet (capsule only) = nothing to do.
func hold_items(mesh: Node, drive: bool, fuse: bool) -> void:
	var sk := mesh.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return
	var at := sk.get_node_or_null(NodePath(("held_%s" % BodyVisual.HAND_R).validate_node_name())) as Node3D
	if at == null:
		if not (drive or fuse):
			return
		at = BodyVisual.hold(sk, BodyVisual.HAND_R, _item(&"drive", &"Drive"))
		var f := _item(&"fuse", &"Fuse")
		at.add_child(f)
		f.transform = (at.get_node(^"Drive") as Node3D).transform.translated_local(SECOND_ITEM)
	(at.get_node(^"Drive") as Node3D).visible = drive
	(at.get_node(^"Fuse") as Node3D).visible = fuse


## The drawn item of objective `o` (dropped, docked or installed); null while none is drawn.
func item_of(o: int) -> Node3D:
	var n: Node3D = _items.get(o)
	return n if n != null and n.visible else null


func _refresh() -> void:
	for i: int in _props:
		if _map.markers[i].type in [&"drive", &"fuse"]:
			_props[i].visible = at_marker(i)
		elif _map.markers[i].type == &"fuse_box":
			var o: int = _marker_of.find_key(i) if _marker_of.values().has(i) else -1
			var installed: bool = _states.get(o, -1) == SurvivorObjectives.FuseState.INSTALLED
			_set_glow(_glow(_props[i], &"cyan_dim"), null,
					INDICATOR_INSTALLED if installed else (INDICATOR_ACTIVE if o >= 0 else 0.0))
		else:
			var s: Array = SCREEN[screen_state(i)]
			_set_glow(_glow(_props[i], &"screen"), s[0], s[1])
	var docked := 0
	for o: int in _states:
		var s: int = _states[o]
		if o < SurvivorObjectives.FUSE_ID:
			if s == SurvivorObjectives.DriveState.DROPPED and _at.has(o):
				_place(o, &"drive", null, _at[o] + Vector3.RIGHT * EJECT_SPREAD_M * (o - SurvivorObjectives.DRIVE_ID))
			elif s == SurvivorObjectives.DriveState.DOCKED and docked < DOCK_SLOTS.size() and _terminal() != null:
				_place(o, &"drive", _terminal(), DOCK_SLOTS[docked], Basis(Vector3.RIGHT, PI / 2.0))
				docked += 1
			else:
				_hide(o)
		elif o < SurvivorObjectives.FUSE_BOX_ID:
			if s == SurvivorObjectives.FuseState.DROPPED and _at.has(o):
				_place(o, &"fuse", null, _at[o])
			else:
				_hide(o)
		elif o < SurvivorObjectives.TERMINAL_ID:
			var box: Node3D = _props.get(_marker_of.get(o, -1))
			if s == SurvivorObjectives.FuseState.INSTALLED and box != null:
				_place(o, &"fuse", box, SOCKET, Basis(Vector3.RIGHT, -PI / 2.0))


## The fuse install sparks (tests and captures).
func install_sparks() -> GPUParticles3D:
	return _sparks


## The active terminal's position, Vector3.INF before this client knows it (ClientSfx's activation tone).
func terminal_at() -> Vector3:
	var t := _terminal()
	return t.global_position if t != null and t.is_inside_tree() else Vector3.INF


## The active terminal's prop, or null before this client knows it.
func _terminal() -> Node3D:
	return _props.get(_marker_of.get(SurvivorObjectives.TERMINAL_ID, -1))


## Shows objective `o`'s item, a `kind` prop, at `pos` (and `basis`) under `parent` (null: this node; world
## space). A dropped drive carries the cyan glow.
func _place(o: int, kind: StringName, parent: Node3D, pos: Vector3, basis := Basis.IDENTITY) -> void:
	var n: Node3D = _items.get(o)
	var host: Node = parent if parent != null else self
	if n == null:
		n = _item(kind, StringName("Item_%d" % o))
		if kind == &"drive":
			var glow := OmniLight3D.new()
			glow.name = &"Glow"
			glow.light_color = CYAN
			glow.light_energy = DROP_GLOW_ENERGY
			glow.omni_range = DROP_GLOW_RANGE_M
			glow.position.y = 0.1
			n.add_child(glow)
		_items[o] = n
	if n.get_parent() != host:
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		host.add_child(n)
	n.transform = Transform3D(basis, pos)
	n.visible = true
	var glow_node := n.get_node_or_null(^"Glow") as Node3D
	if glow_node != null:
		glow_node.visible = parent == null ## dropped only, not docked


## `prop`'s own copy of its material named `surface` (set as that surface's override on first use), or null.
func _glow(prop: Node3D, surface: StringName) -> StandardMaterial3D:
	if prop == null:
		return null
	for mi: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var own := mi.get_surface_override_material(s) as StandardMaterial3D
			if own != null and own.resource_name == surface:
				return own
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m != null and m.resource_name == surface:
				m = m.duplicate() as StandardMaterial3D
				m.set_meta(&"colour", m.emission)
				mi.set_surface_override_material(s, m)
				return m
	return null


## Emission of `m`: `colour` (null = the model's own) at `energy`; 0 turns emission off (dark).
func _set_glow(m: StandardMaterial3D, colour: Variant, energy: float) -> void:
	if m == null:
		return
	m.emission_enabled = energy > 0.0
	m.emission = colour if colour is Color else m.get_meta(&"colour")
	m.emission_energy_multiplier = energy


func _hide(o: int) -> void:
	if _items.has(o):
		_items[o].visible = false


## A fresh instance of the `kind` prop scene named `node_name`: no collision (props have none), no file path.
func _item(kind: StringName, node_name: StringName) -> Node3D:
	var n := (_mats.props[kind] as PackedScene).instantiate() as Node3D
	n.name = node_name
	n.scene_file_path = "" ## AC-LB-31: nodes under a remote body carry no script, meta or file path
	return n
