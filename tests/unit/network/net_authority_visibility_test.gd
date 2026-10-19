# TD-006 (NA-2 code review): NetAuthority.set_player_visibility drops freed synchronizers it still lists, so a
# later grant or rebind never touches a freed object. (A freed one cannot be passed in: the typed parameter
# rejects it at the call.)
extends GdUnitTestSuite

const PLAYER := 2

var _net: NetAuthority


func before_test() -> void:
	_net = auto_free(NetAuthority.new())
	_net.setup(Knobs.load_all(), "test", null)


func test_freed_synchronizers_are_ignored_and_dropped() -> void:
	var gone := MultiplayerSynchronizer.new()
	_net.set_player_visibility(gone, PLAYER, true)
	gone.free()
	var live: MultiplayerSynchronizer = auto_free(MultiplayerSynchronizer.new())
	_net.set_player_visibility(live, PLAYER, true)
	assert_array(_net._visibility[PLAYER]).is_equal([live])
