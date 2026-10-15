# Story survivor-defense/013: hiding marker facing and eject in front (design/gdd/survivor-defense.md
# rule 22; design/gdd/first-person-controller.md edge case "front is blocked"; AD-200).
# Unit: HidingSpots driven through its HidingHold callbacks on a one-room map; the map loader's yaw check
# on the shipped map.
extends GdUnitTestSuite

const A := 1 ## survivor
const ROOM := AABB(Vector3.ZERO, Vector3(10.0, 3.0, 10.0))

var _knobs: Knobs
var _placed: Array = []
var _hidden: Dictionary = {}


func before_test() -> void:
	_knobs = Knobs.load_all()
	_placed = []
	_hidden = {}


func _set_hidden(actor: int, on: bool) -> void:
	_hidden[actor] = on


func _yes(_actor: int) -> bool:
	return true


func _place(actor: int, at: Vector3) -> void:
	_placed.append([actor, at])


func _none(_a: Variant = null) -> Variant:
	return null


func _spots(map: MapData) -> HidingSpots:
	var holds := HoldService.new(_knobs, _none, _none, _none, _none, _none)
	var hs := HidingSpots.new(holds, map, _yes, _yes, _set_hidden, Callable(), _place)
	hs.setup(null, null, StateRegistry.new(), _knobs)
	return hs


## One 10 x 10 m room with one hiding marker at `pos` facing `yaw_deg`.
func _room_map(pos: Vector3, yaw_deg: float) -> MapData:
	var v := MapVolume.new()
	v.id = &"V"
	v.room = &"V"
	v.box = ROOM
	var m := MapMarker.new()
	m.id = &"h"
	m.type = &"hiding"
	m.volume = &"V"
	m.position = pos
	m.yaw_deg = yaw_deg
	var map := MapData.new()
	map.volumes.assign([v])
	map.markers.assign([m])
	return map


func _front(pos: Vector3, yaw_deg: float) -> Vector3:
	return pos + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3.FORWARD * _knobs.defense.hide_eject_offset_m


func _hide_then_search(hs: HidingSpots) -> void:
	hs.hide_started(A, 0)
	hs.hide_completed(A, 0)
	hs.search_completed(0)


# --- AC-1: yaw validated -------------------------------------------------------------------------------

func test_a_hiding_marker_without_yaw_fails_the_load_and_yaw_0_loads() -> void:
	var map := MapData.load_map()
	assert_array(map.errors()).is_empty()
	var h1: MapMarker = map.markers.filter(func(m: MapMarker) -> bool: return m.id == &"h1")[0]
	h1.yaw_deg = NAN
	assert_array(map.errors()).contains_exactly(["marker h1: hiding marker has no yaw_deg"])
	h1.yaw_deg = 0.0
	assert_array(map.errors()).is_empty()


# --- AC-2: eject in front ------------------------------------------------------------------------------

func test_search_ejects_to_the_marker_front_for_each_facing() -> void:
	for yaw: float in [0.0, 90.0, 180.0, -90.0]:
		_placed = []
		var pos := Vector3(5.0, 0.0, 5.0)
		_hide_then_search(_spots(_room_map(pos, yaw)))
		assert_array(_placed).override_failure_message("yaw %s" % yaw).is_equal([[A, _front(pos, yaw)]])
		assert_bool(_hidden[A]).is_false()


func test_search_during_entry_ejects_in_front_once_the_entry_finishes() -> void:
	var pos := Vector3(5.0, 0.0, 5.0)
	var hs := _spots(_room_map(pos, 90.0))
	hs.hide_started(A, 0)
	hs.search_completed(0)
	assert_array(_placed).is_empty()
	hs.hide_completed(A, 0)
	assert_array(_placed).is_equal([[A, _front(pos, 90.0)]])
	assert_int(hs.occupant(0)).is_equal(-1)


func test_the_offset_knob_moves_the_eject() -> void:
	_knobs.defense.hide_eject_offset_m = 1.2
	var pos := Vector3(5.0, 0.0, 5.0)
	_hide_then_search(_spots(_room_map(pos, 0.0)))
	assert_array(_placed).is_equal([[A, Vector3(5.0, 0.0, 3.8)]])


func test_every_shipped_spot_ejects_to_its_front() -> void:
	var map := MapData.load_map()
	var hs := _spots(map)
	var spot := 0
	for t: Resource in map.interactables():
		var m := t as MapMarker
		if m == null or m.type != &"hiding":
			continue
		_placed = []
		hs.hide_started(A, spot)
		hs.hide_completed(A, spot)
		hs.search_completed(spot)
		assert_array(_placed).override_failure_message(String(m.id)).is_equal([[A, _front(m.position, m.yaw_deg)]])
		spot += 1
	assert_int(spot).is_equal(6)


# --- AC-3: blocked front -------------------------------------------------------------------------------

func test_blocked_front_places_at_the_nearest_free_point_within_1m() -> void:
	## Facing the north wall (z = 0) from 0.1 m: the front is outside the room, the nearest free point is
	## one capsule radius inside the wall, straight back toward the marker.
	var pos := Vector3(5.0, 0.0, 0.1)
	var hs := _spots(_room_map(pos, 0.0))
	_hide_then_search(hs)
	assert_array(_placed).is_equal([[A, Vector3(5.0, 0.0, _knobs.controller.player_radius_m)]])
	assert_int(hs.occupant(0)).is_equal(-1)


func test_no_free_point_within_1m_the_exit_waits() -> void:
	_knobs.defense.hide_eject_offset_m = 1.5 ## front 1.4 m past the wall: nothing free within 1 m
	var pos := Vector3(5.0, 0.0, 0.1)
	var hs := _spots(_room_map(pos, 0.0))
	_hide_then_search(hs)
	assert_array(_placed).is_empty()
	assert_int(hs.occupant(0)).is_equal(A)
	assert_bool(_hidden[A]).is_true()
