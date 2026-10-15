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
## Bodies are TestMoveStep stand-ins (the controller epic owns the real step) on the MapGreybox floors
## (MF-11: the client scene builds the same floors). Self-clients add the session HiddenSpawner at the
## server's fixed path, as every real client does (RoundClient), so candidate spawns resolve.
## --place=monitor (facility-map story 011) spawns the first survivor in front of the C1 monitor and the
## shapeshifter beside the second survivor in B1, in camera c1's view; everyone else spawns as usual.
## --force=<s>:power,<s>:evac (story facility-map/010 screenshots) emits a forced event on the server bus that
## many seconds after round start: power = ObjectiveProgressChanged terminal POWERED (Power Restored), evac =
## RoundPhaseChanged to Evacuation, blackout = AbilityUsed Blackout in B1 (story facility-map/011), hallucinate =
## the single-client surveillance_image scare to the first survivor at the C1 monitor (story scare-events/009), anchor =
## moves the first survivor into A3 (scare anchors sd1, sg1; story scare-events/006), so RoundScript fires there.
## Forced events skip the objective and timer rules; manual capture only.

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
var _place := ""
## --place=monitor spots (C1 in front of the monitor marker at 51, 7; B1 in c1's view of the Core).
const MONITOR_SPOT := Vector3(52.4, 0.0, 6.6)
const B1_MONSTER_SPOT := Vector3(28.6, 0.0, 22.8)
const B1_TARGET_SPOT := Vector3(30.0, 0.0, 23.4)
var _args := {}


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
	var args := _args
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	_want = int(args.get("players", "5"))
	_place = args.get("place", "")
	_knobs = Knobs.load_all()
	_root = Node3D.new()
	_root.name = "RoundHost"
	root.add_child(_root)
	set_multiplayer(SceneMultiplayer.new(), _root.get_path())
	_net = NetAuthority.new()
	_net.setup(_knobs, _knobs.join_version(SERVER_VERSION), _lobby)
	_root.add_child(_net)
	var port := int(args.get("port", "24690"))
	var err := _net.host(port)
	if err != OK:
		print("HOST FAILED %s" % error_string(err))
		quit(1)
		return
	_net.player_joined.connect(_on_joined)
	MapGreybox.build(_root, MapData.load_map())
	print("HOSTING port %d, waiting for %d players" % [port, _want])
	if args.has("self-clients"):
		for i in _want:
			var r := Node.new()
			r.name = "Client%d" % i
			root.add_child(r)
			set_multiplayer(SceneMultiplayer.new(), r.get_path())
			var c := NetAuthority.new()
			c.setup(_knobs, _knobs.join_version(SERVER_VERSION), Lobby.new())
			r.add_child(c)
			r.add_child(HiddenSpawner.new())
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


## A survivor's character appearance (1-5, C1-C5). Inference: CharacterAssignment owns the real pick
## (lobby epic); any distinct id per player is enough for the greybox colours (ADR-0010 minimal).
func _look(id: int) -> int:
	return 1 + id % 5


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
			TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _look)
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
	_server.bus.subscribe(&"ScareTriggered", _on_scare)
	if _place == "monitor":
		_c.lifecycle.spawn = _placed_spawn
	print("ROUND STARTED: monster %d, survivors %s" % [_c.monster, _c.survivors])
	for f in String(_args.get("force", "")).split(",", false):
		var at_what := f.split(":")
		create_timer(float(at_what[0])).timeout.connect(_force.bind(at_what[1]))
	for r in _client_roots:
		(r.multiplayer as SceneMultiplayer).send_bytes(RoundLifecycle.map_loaded_packet(), 1,
				MultiplayerPeer.TRANSFER_MODE_RELIABLE)


## --place=monitor: the composer's spawn at the story-011 spots.
func _placed_spawn(id: int, at: Vector3) -> void:
	if id == _c.monster:
		at = B1_MONSTER_SPOT
	elif id == _c.survivors[0]:
		at = MONITOR_SPOT
	elif _c.survivors.size() > 1 and id == _c.survivors[1]:
		at = B1_TARGET_SPOT
	print("PLACED %d at %s" % [id, at])
	_c._spawn(id, at)
## Emits one forced lighting trigger (see --force).
func _force(what: String) -> void:
	if _server == null or _server.bus == null:
		return
	if what == "evac":
		var e := EvRoundPhaseChanged.new()
		e.phase = MatchFlow.Phase.EVACUATION
		_server.bus.emit(e)
	elif what == "power":
		var o := EvObjectiveProgressChanged.new()
		o.objective = SurvivorObjectives.TERMINAL_ID
		o.state = SurvivorObjectives.TerminalState.POWERED
		_server.bus.emit(o)
	elif what == "blackout": # story facility-map/011: a Blackout in B1, as Monster Abilities emits it
		var a := EvAbilityUsed.new()
		a.ability = MonsterAbilities.Ability.BLACKOUT
		a.target = Vector3(31.0, 0.0, 20.0)
		_server.bus.emit(a)
	elif what == "hallucinate": # story scare-events/009: the catalogue's single-client hallucination
		var who: int = _c.survivors[0]
		_c.scares.fire(ScareVisuals.HALLUCINATION, Vector3(51.0, 0.0, 7.0), [who], ScareEntry.Source.SURVIVOR, who)
	elif what == "anchor": # story scare-events/006: walk into A3, between scare anchors sd1 and sg1
		_c.bodies[_c.survivors[0]].global_position = Vector3(9.5, 0.0, 21.5)
	print("FORCED %s" % what)


func _on_event(e: ServerEvent) -> void:
	print("tick %d %s" % [e.tick, e.type()])


func _on_scare(e: ServerEvent) -> void:
	var s := e as EvScareTriggered
	print("tick %d ScareTriggered %s source %d origin %s to %d" % [s.tick, s.scare_id, s.source, s.origin, s.recipient])


func _on_over(ended: bool) -> void:
	print("ROUND OVER: %s" % ("results ended" if ended else "cancelled (load timeout)"))
	for r in _client_roots:
		for n in r.get_children():
			if n is NetAuthority:
				n.close()
	_net.close()
	quit(0 if ended else 2)
