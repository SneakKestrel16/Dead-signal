extends Node
## RPC target for transport checks. RPC modes are set at runtime with rpc_config.

var unreliable_log: Array = []   # [seq, received_ms]
var reliable_ms := -1
var blob_sizes: Array[int] = []


func u(seq: int) -> void:
	unreliable_log.append([seq, Time.get_ticks_msec()])


func r() -> void:
	reliable_ms = Time.get_ticks_msec()


func blob(data: PackedByteArray) -> void:
	blob_sizes.append(data.size())


func ping(value: int) -> void:
	pass


static func configure(n: Node, unreliable_channel: int, reliable_channel: int) -> void:
	n.rpc_config(&"u", {"rpc_mode": MultiplayerAPI.RPC_MODE_AUTHORITY, "transfer_mode": MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, "call_local": false, "channel": unreliable_channel})
	n.rpc_config(&"blob", {"rpc_mode": MultiplayerAPI.RPC_MODE_AUTHORITY, "transfer_mode": MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, "call_local": false, "channel": unreliable_channel})
	n.rpc_config(&"r", {"rpc_mode": MultiplayerAPI.RPC_MODE_AUTHORITY, "transfer_mode": MultiplayerPeer.TRANSFER_MODE_RELIABLE, "call_local": false, "channel": reliable_channel})
	n.rpc_config(&"ping", {"rpc_mode": MultiplayerAPI.RPC_MODE_AUTHORITY, "transfer_mode": MultiplayerPeer.TRANSFER_MODE_RELIABLE, "call_local": false, "channel": reliable_channel})
