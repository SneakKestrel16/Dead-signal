class_name FlashlightPredictor extends RefCounted
## Client side of the flashlight toggle (survivor-defense story 009; ADR-0002: predict locally, take the
## server's value). toggle() flips the shown state at once (Game Feel: local response within 50 ms; no
## tick or round trip in between) and returns the intent bytes to send. Snapshot values are taken as
## they arrive, except while a toggle is unconfirmed: the shown state holds the predicted one until the
## server reports it.
## Usage:
##   var light := FlashlightPredictor.new()
##   smp.send_bytes(light.toggle(), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE)  # on click
##   light.take_server(own_entry.flashlight)                                    # each own snapshot entry
##   cone.visible = light.is_on()

var _server_on := false
var _want := false
var _pending := false


## Flips the shown state and returns SurvivorDefense.light_packet for it.
func toggle() -> PackedByteArray:
	_want = not is_on()
	_pending = true
	return SurvivorDefense.light_packet(_want)


## Takes the server's flashlight state from the latest own snapshot entry.
## ponytail: a stale snapshot equal to the wanted state clears the prediction early, so on, off within
## one RTT can flash the cone once; carry the intent's seq in the snapshot if playtests show it.
func take_server(on: bool) -> void:
	_server_on = on
	if on == _want:
		_pending = false


## Whether the cone is shown.
func is_on() -> bool:
	return _want if _pending else _server_on
