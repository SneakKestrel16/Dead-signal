class_name UdpLink extends RefCounted
## Loopback UDP relay between one real ENet client and the server that adds latency, jitter and loss
## (ENet has no built-in conditioner). Adapted from UdpProxy in prototypes/adr-verification/lib.gd.
## The caller passes its own clock as `now_s` to pump() (the test passes tick time, paced to real time).
## One-way delay = delay_s + uniform(-jitter_s / 2, +jitter_s / 2); each datagram is dropped with
## probability loss; drop_next_* drops that many consecutive datagrams (a burst). Seeded RNG.
## Direction names: up = client to server, down = server to client.

var delay_s: float = 0.0
var jitter_s: float = 0.0
var loss: float = 0.0
var drop_next_up: int = 0
var drop_next_down: int = 0
var dropped: int = 0
var forwarded: int = 0
## When true, every server-to-client datagram that is forwarded is kept in captured_down.
var record_down: bool = false
var captured_down: Array[PackedByteArray] = []

var _client_side := PacketPeerUDP.new()
var _server_side := PacketPeerUDP.new()
var _client_ip := ""
var _client_port := 0
var _rng := RandomNumberGenerator.new()
## Pending datagrams: {t: float, up: bool, data: PackedByteArray}.
var _queue: Array[Dictionary] = []


func _init(seed_value: int) -> void:
	_rng.seed = seed_value


## The client connects to `listen_port`; datagrams go on to `server_port`.
func start(listen_port: int, server_port: int) -> Error:
	var err := _client_side.bind(listen_port, "127.0.0.1")
	if err != OK:
		return err
	return _server_side.connect_to_host("127.0.0.1", server_port)


## Reads what arrived, schedules it, and forwards everything due at `now_s`.
func pump(now_s: float) -> void:
	while _client_side.get_available_packet_count() > 0:
		var pkt := _client_side.get_packet()
		_client_ip = _client_side.get_packet_ip()
		_client_port = _client_side.get_packet_port()
		_schedule(pkt, true, now_s)
	while _server_side.get_available_packet_count() > 0:
		_schedule(_server_side.get_packet(), false, now_s)
	var due: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for e in _queue:
		(due if e.t <= now_s else rest).append(e)
	_queue = rest
	due.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	for e in due:
		if e.up:
			_server_side.put_packet(e.data)
		elif _client_port != 0:
			_client_side.set_dest_address(_client_ip, _client_port)
			_client_side.put_packet(e.data)
			if record_down:
				captured_down.append(e.data)
		forwarded += 1


func stop() -> void:
	_client_side.close()
	_server_side.close()


func _schedule(pkt: PackedByteArray, up: bool, now_s: float) -> void:
	if up and drop_next_up > 0:
		drop_next_up -= 1
		dropped += 1
		return
	if not up and drop_next_down > 0:
		drop_next_down -= 1
		dropped += 1
		return
	if loss > 0.0 and _rng.randf() < loss:
		dropped += 1
		return
	var t := now_s + delay_s + (_rng.randf_range(-jitter_s / 2.0, jitter_s / 2.0) if jitter_s > 0.0 else 0.0)
	_queue.append({"t": t, "up": up, "data": pkt})
