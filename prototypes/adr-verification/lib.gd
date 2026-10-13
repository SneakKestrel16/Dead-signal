extends RefCounted
## Shared helpers for the ADR verification checks. Each check module extends this.

const WORLD := 1 << 0
const GLASS := 1 << 1
const DOORS := 1 << 2
const PLAYERS := 1 << 3

static var _port := 47600

var tree: SceneTree
var runner


func _init(t: SceneTree) -> void:
	tree = t
	runner = t


## Records one result line. verdict: PASS, FAIL, OBSERVED (value only, no
## expectation) or NOT RUN (with the reason in observed).
func rec(id: String, verdict: String, observed: String) -> void:
	runner.rec(id, verdict, observed)


func next_port() -> int:
	_port += 1
	return _port


func frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func physics_frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


## Waits until cond returns true or timeout_s passes. Returns the final cond value.
func until(cond: Callable, timeout_s: float, proxy: UdpProxy = null) -> bool:
	var end := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < end:
		if proxy:
			proxy.poll()
		if cond.call():
			return true
		await tree.process_frame
	return cond.call()


# --- networking -------------------------------------------------------------

## A SceneMultiplayer bound to its own subtree, so server and clients share one process.
func make_api(node_name: String) -> SceneMultiplayer:
	var n := Node.new()
	n.name = node_name
	tree.root.add_child(n)
	var api := SceneMultiplayer.new()
	tree.set_multiplayer(api, n.get_path())
	return api


func api_root(node_name: String) -> Node:
	return tree.root.get_node(node_name)


func close_api(api: SceneMultiplayer, node_name: String) -> void:
	if api.multiplayer_peer:
		api.multiplayer_peer.close()
	var n := tree.root.get_node_or_null(node_name)
	if n:
		n.queue_free()


func connected(api: SceneMultiplayer) -> bool:
	return api.multiplayer_peer != null \
		and api.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## UDP relay between one ENet client and a server, for packet capture and loss
## injection. The client connects to listen_port; packets go on to server_port.
class UdpProxy:
	var down := PacketPeerUDP.new()
	var up := PacketPeerUDP.new()
	var client_ip := ""
	var client_port := 0
	var drop_until_ms := 0
	var capture_down: Array[PackedByteArray] = []
	var capture_enabled := false
	var dropped := 0

	func start(listen_port: int, server_port: int) -> Error:
		var err := down.bind(listen_port, "127.0.0.1")
		if err != OK:
			return err
		return up.connect_to_host("127.0.0.1", server_port)

	func poll() -> void:
		while down.get_available_packet_count() > 0:
			var pkt := down.get_packet()
			client_ip = down.get_packet_ip()
			client_port = down.get_packet_port()
			up.put_packet(pkt)
		while up.get_available_packet_count() > 0:
			var pkt := up.get_packet()
			if Time.get_ticks_msec() < drop_until_ms:
				dropped += 1
				continue
			if capture_enabled:
				capture_down.append(pkt)
			if client_port != 0:
				down.set_dest_address(client_ip, client_port)
				down.put_packet(pkt)

	func stop() -> void:
		down.close()
		up.close()


# --- physics ----------------------------------------------------------------

func make_world(world_name: String) -> Node3D:
	var w := Node3D.new()
	w.name = world_name
	tree.root.add_child(w)
	return w


func add_box(parent: Node, pos: Vector3, size: Vector3, layer: int = WORLD) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = layer
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	b.add_child(cs)
	parent.add_child(b)
	b.global_position = pos
	return b


## Wedge rising along +Z from z0 (height 0) to z0 + depth (height), 4 m wide.
func add_wedge(parent: Node, z0: float, angle_deg: float, height: float) -> StaticBody3D:
	var depth := height / tan(deg_to_rad(angle_deg))
	var b := StaticBody3D.new()
	b.collision_layer = WORLD
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(-2, 0, z0), Vector3(2, 0, z0),
		Vector3(-2, 0, z0 + depth), Vector3(2, 0, z0 + depth),
		Vector3(-2, height, z0 + depth), Vector3(2, height, z0 + depth),
	])
	cs.shape = shape
	b.add_child(cs)
	parent.add_child(b)
	return b


## Player body per ADR-0007 §2-3: capsule r 0.30 h 1.8 built with .new(), floor settings.
func make_player(parent: Node, pos: Vector3, block_on_wall: bool = true, max_angle_deg: float = 40.0) -> CharacterBody3D:
	var p := CharacterBody3D.new()
	p.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	p.collision_layer = PLAYERS
	p.collision_mask = WORLD | GLASS | DOORS | PLAYERS
	p.floor_max_angle = deg_to_rad(max_angle_deg)
	p.floor_snap_length = 0.4
	p.floor_stop_on_slope = true
	p.floor_constant_speed = true
	p.floor_block_on_wall = block_on_wall
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.30
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	p.add_child(cs)
	parent.add_child(p)
	p.global_position = pos
	return p


## ADR-0007 §3 movement step: accel over 0.05 s, gravity off the floor, one move_and_slide.
func step(p: CharacterBody3D, dir: Vector3, speed: float = 4.0) -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var target := dir * speed
	var rate := speed / 0.05 * dt
	p.velocity.x = move_toward(p.velocity.x, target.x, rate)
	p.velocity.z = move_toward(p.velocity.z, target.z, rate)
	if p.is_on_floor():
		p.velocity.y = 0.0
	else:
		p.velocity.y += p.get_gravity().y * dt
	p.move_and_slide()


# --- GDScript compile probes ------------------------------------------------

## Compiles source at runtime. Returns the reload error (OK when it compiles).
func compile(src: String) -> Error:
	var s := GDScript.new()
	s.source_code = src
	return s.reload()
