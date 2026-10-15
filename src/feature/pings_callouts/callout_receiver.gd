class_name CalloutReceiver extends RefCounted
## Client side of callout delivery (story pings-and-callouts/006; design/gdd/pings-and-callouts.md rules 10,
## 11): sends this client's callout requests and records every delivered callout. Decides nothing: playing the
## voice line and the feed UI are story 008, the "(not you)" mark story 007.
## Usage (client, on the fixed-name round root; keep a reference):
##   callouts = CalloutReceiver.new(router, multiplayer as SceneMultiplayer)
##   callouts.request(PingsCallouts.DANGER)

## Survivor callout payloads ({line, identity, origin, gesture, voice}), in arrival order.
var received: Array[Dictionary] = []
## Monster audio-only payloads ({line, voice, origin}), in arrival order.
var audio: Array[Dictionary] = []

var _smp: SceneMultiplayer


## `smp`: sends requests to the server; null = no sending.
func _init(router: ClientEventRouter, smp: SceneMultiplayer = null) -> void:
	_smp = smp
	router.subscribe(EventBatch.CALLOUT, on_callout)
	router.subscribe(EventBatch.CALLOUT_AUDIO, on_audio)


## Sends a callout request for `line`, attaching item ping `item` (-1 for none; rule 13).
func request(line: StringName, item: int = -1) -> void:
	if _smp != null:
		_smp.send_bytes(PingsCallouts.callout_packet(line, item), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE)


## ClientEventRouter handler for EventBatch.CALLOUT.
func on_callout(_tick: int, payload: Dictionary) -> void:
	received.append(payload)


## ClientEventRouter handler for EventBatch.CALLOUT_AUDIO.
func on_audio(_tick: int, payload: Dictionary) -> void:
	audio.append(payload)
