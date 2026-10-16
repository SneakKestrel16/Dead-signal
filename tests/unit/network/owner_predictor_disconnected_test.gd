# BUG-0001: OwnerPredictor.predict must not send input once the peer to the host is no longer connected
# (after HOST_LEFT the net_check route loop kept predicting: one engine error per tick).
extends GdUnitTestSuite

const UNUSED_PORT := 30997 ## manual-capture range (house rules); nothing listens, the peer is closed at once

var _log: ErrorLog


## Collects every engine and script error message logged while installed.
class ErrorLog extends Logger:
	var lines: PackedStringArray = []

	func _log_error(function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		lines.append("%s: %s %s" % [function, code, rationale])


func after_test() -> void:
	if _log != null:
		OS.remove_logger(_log)
	_log = null


func test_predict_after_the_host_left_sends_nothing_and_logs_no_error() -> void:
	var smp := SceneMultiplayer.new()
	var peer := ENetMultiplayerPeer.new()
	assert_int(peer.create_client("127.0.0.1", UNUSED_PORT)).is_equal(OK)
	smp.multiplayer_peer = peer
	peer.close() ## what the client holds after server_disconnected / HOST_LEFT
	var body := CharacterBody3D.new()
	var visual := Node3D.new()
	body.add_child(visual)
	var p := OwnerPredictor.new(Knobs.load_all(), body, visual, _no_step, smp)
	_log = ErrorLog.new()
	OS.add_logger(_log)
	for i in 3:
		p.predict(InputFrame.new())
	OS.remove_logger(_log)
	var lines := _log.lines
	_log = null
	assert_array(Array(lines)).is_empty()
	assert_int(p.unacked_count()).is_equal(3) ## prediction itself still runs; only the send is skipped
	p.close()
	smp.multiplayer_peer = null
	body.free()


func _no_step(_body: CharacterBody3D, _frame: InputFrame, _mods: MovementModifiers) -> void:
	pass
