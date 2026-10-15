extends SceneTree
## Standalone headless host for smoke QA path 4 (story match-flow/010 AC-4): hosts a real ENet server,
## waits for --players clients (4-6) to join, locks a roster, composes the round with RoundComposer and
## lets physics drive it until RoundLifecycle's over hook (Results ended, or Cancelled on load timeout).
## Prints one line per round event and the result, then quits (exit 0 = ended, 2 = cancelled).
## Usage:
##   <godot> --headless --path <repo> -s res://tests/manual/round_host.gd -- [--port=24690] [--players=5] [--self-clients]
## Clients: any client that joins and sends RoundLifecycle.map_loaded_packet() (MF-11 client round scene).
## --self-clients joins --players ENet clients from this process on 127.0.0.1 that report their map loaded
## and send nothing else: the round runs to the deadline (round_duration_s) and Results, then exits 0.
## Bodies are TestMoveStep stand-ins (the controller epic owns the real step) on an empty world.

const SERVER_VERSION := "0.1.0"
const EVENTS: Array[StringName] = [&"RoundPhaseChanged", &"SurvivorDowned", &"SurvivorEliminated",
	&"MonsterStunned", &"ObjectiveProgressChanged", &"SurvivorEscaped", &"RoundEnded"]

var _knobs: Knobs
var _net: NetAuthority
var _root: Node3D
var _server: RoundServer
var _c: RoundComposer
var _joined: Array[int] = []
var _want := 5


class Lobby extends RefCounted:
	var count := 0

	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return count


var _lobby := Lobby.new()
var _client_roots: Array[Node] = []


func _initialize() -> void:
	_setup.call_deferred() # root is not in the tree yet inside _initialize


func _setup() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	_want = int(args.get("players", "5"))
	_knobs = Knobs.load_all()
	_root = Node3D.new()
	_root.name = "RoundHost"
	root.add_child(_root)
	set_multiplayer(SceneMultiplayer.new(), _root.get_path())
	_net = NetAuthority.new()
	_net.setup(_knobs, SERVER_VERSION, _lobby)
	_root.add_child(_net)
	var port := int(args.get("port", "24690"))
	var err := _net.host(port)
	if err != OK:
		print("HOST FAILED %s" % error_string(err))
		quit(1)
		return
	_net.player_joined.connect(_on_joined)
	print("HOSTING port %d, waiting for %d players" % [port, _want])
	if args.has("self-clients"):
		for i in _want:
			var r := Node.new()
			r.name = "Client%d" % i
			root.add_child(r)
			set_multiplayer(SceneMultiplayer.new(), r.get_path())
			var c := NetAuthority.new()
			c.setup(_knobs, SERVER_VERSION, Lobby.new())
			r.add_child(c)
			c.join("127.0.0.1", port, "Bot%d" % i)
			_client_roots.append(r)


func _on_joined(pid: int) -> void:
	_joined.append(pid)
	_lobby.count = _joined.size()
	print("JOINED %d (%d/%d)" % [pid, _joined.size(), _want])
	if _joined.size() == _want:
		_start.call_deferred()


func _info(token: String) -> Dictionary:
	var pid := token.trim_prefix("t").to_int()
	return {"player_id": pid, "name": _net.display_name_of(pid)}


func _no_look(_id: int) -> int:
	return 0


func _start() -> void:
	var tokens := PackedStringArray()
	for pid in _joined:
		tokens.append("t%d" % pid)
	var rng := RandomNumberGenerator.new()
	var roster := Roster.lock(tokens, _info, "host-%d" % Time.get_unix_time_from_system(), 1, _knobs,
			RotationQueue.new(), rng)
	if roster == null:
		print("ROSTER REFUSED for %d players" % tokens.size())
		quit(1)
		return
	_c = RoundComposer.new(_knobs, roster, MapData.load_map(), _net, _root.multiplayer as SceneMultiplayer, _root,
			TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _no_look)
	_c.on_over = _on_over
	var hidden := HiddenSpawner.new()
	_root.add_child(hidden)
	_c.hidden = hidden
	_server = RoundServer.new()
	_root.add_child(_server)
	var errs := _c.start(_server, rng)
	if not errs.is_empty():
		print("ROUND REFUSED: %s" % "; ".join(errs))
		quit(1)
		return
	for type in EVENTS:
		_server.bus.subscribe(type, _on_event)
	print("ROUND STARTED: monster %d, survivors %s" % [_c.monster, _c.survivors])
	for r in _client_roots:
		(r.multiplayer as SceneMultiplayer).send_bytes(RoundLifecycle.map_loaded_packet(), 1,
				MultiplayerPeer.TRANSFER_MODE_RELIABLE)


func _on_event(e: ServerEvent) -> void:
	print("tick %d %s" % [e.tick, e.type()])


func _on_over(ended: bool) -> void:
	print("ROUND OVER: %s" % ("results ended" if ended else "cancelled (load timeout)"))
	for r in _client_roots:
		for n in r.get_children():
			(n as NetAuthority).close()
	_net.close()
	quit(0 if ended else 2)
