# Story controller-interaction/013: the camera flinch toggle the client sends and the server holds
# (ADR-0015 §4): NetAuthority's request packets and state, and PlayerSettingsView.
extends GdUnitTestSuite

const PLAYER := 2
const PEER := 7

var _net: NetAuthority
var _changes: Array = []


func before_test() -> void:
	_net = auto_free(NetAuthority.new())
	_net.setup(Knobs.load_all(), "test", null)
	_net.flinch_enabled_changed.connect(_on_changed)
	_changes.clear()


func _on_changed(player_id: int, on: bool) -> void:
	_changes.append([player_id, on])


func test_request_packets_decode_and_nothing_else_does() -> void:
	assert_int(NetAuthority.flinch_request(NetAuthority.flinch_packet(true))).is_equal(1)
	assert_int(NetAuthority.flinch_request(NetAuthority.flinch_packet(false))).is_equal(0)
	assert_int(NetAuthority.flinch_request(var_to_bytes({"flinch_enabled": 1}))).is_equal(-1)
	assert_int(NetAuthority.flinch_request(var_to_bytes({"proximity_voice": true}))).is_equal(-1)
	assert_int(NetAuthority.flinch_request(PackedByteArray())).is_equal(-1)


func test_unknown_player_is_off_and_view_reads_the_session_value() -> void:
	var view := PlayerSettingsView.new(_net)
	assert_bool(view.is_flinch_enabled(PLAYER)).is_false()
	_net.set_flinch_enabled(PLAYER, true)
	assert_bool(view.is_flinch_enabled(PLAYER)).is_true()
	_net.set_flinch_enabled(PLAYER, false)
	assert_bool(view.is_flinch_enabled(PLAYER)).is_false()
	_net.close()
	assert_bool(view.is_flinch_enabled(PLAYER)).is_false()


func test_change_signals_once_per_change() -> void:
	_net.set_flinch_enabled(PLAYER, true)
	_net.set_flinch_enabled(PLAYER, true)
	_net.set_flinch_enabled(PLAYER, false)
	assert_array(_changes).is_equal([[PLAYER, true], [PLAYER, false]])


## Server packet routing: a bound peer's request sets its player's toggle; an unbound peer's, or any other
## packet, changes nothing. The binding is set directly: a real ENet join is covered by the net tests.
func test_server_packet_from_a_bound_peer_sets_its_player() -> void:
	_net._on_server_packet(PEER, NetAuthority.flinch_packet(true))
	assert_array(_changes).is_empty()
	_net._player_by_peer[PEER] = PLAYER
	_net._on_server_packet(PEER, var_to_bytes({"proximity_voice": true}))
	assert_array(_changes).is_empty()
	_net._on_server_packet(PEER, NetAuthority.flinch_packet(true))
	assert_bool(_net.flinch_enabled_of(PLAYER)).is_true()
	_net._on_server_packet(PEER, NetAuthority.flinch_packet(false))
	assert_array(_changes).is_equal([[PLAYER, true], [PLAYER, false]])
