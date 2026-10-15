class_name RoundHost extends Node
## The server role of a shipped session (story match-flow/013; ADR-0001 Â§1, ADR-0005 composition root;
## match-flow.md rules 1, 2, 17, 27). On the lobby's roster lock (RosterHandoff.handed_off) it composes the
## round with RoundComposer over that roster and lets physics drive it. The server's copy of the map lives in
## a physics world of its own (a SubViewport with own_world_3d that is never drawn), so a local player's
## client scene in the same process neither sees nor collides with it. It holds no local player: a
## dedicated build can run it alone; a listen host adds its local player's client beside it (LobbyScreen).
## While a round runs ConnectionRouter routes drops to the round's bus (rule 19). Once the round is torn down
## it emits round_over(ended); the owner then calls finish(ended), which returns the lobby to Waiting through
## RosterHandoff (the queue advances only for Ended, lobby rule 9). The two steps are split so a listen host
## can let go of its local player's seat first, while the lobby is still In Match (a drop then is not a
## lobby leave).
## Named NODE_NAME: the session HiddenSpawner sits at NODE_NAME/Hidden under the multiplayer root, the path
## every client's RoundClient (also named NODE_NAME) uses (ADR-0004 Â§7a).
## Bodies use TestMoveStep (tests/helpers), as tests/manual/round_host.gd does: the controller epic has not
## shipped the real step. Swap both sides (here and LobbyScreen's RoundClient) when it does.
## Usage:
##   var rh := RoundHost.new(knobs, net, router, handoff, lobby)
##   session_root.add_child(rh)
##   rh.round_over.connect(func(ended: bool) -> void: rh.finish(ended))

## The round was composed (server side); clients load on the lobby's In Match packet.
signal round_started
## The round is torn down: true after Results, false for Cancelled (load timeout) or a refused compose.
signal round_over(ended: bool)

const NODE_NAME := &"Round"

## The running round; null outside one.
var composer: RoundComposer
var server: RoundServer
## The session HiddenSpawner, kept for the whole session at NODE_NAME/Hidden.
var hidden: HiddenSpawner

var _knobs: Knobs
var _net: NetAuthority
var _router: ConnectionRouter
var _handoff: RosterHandoff
var _lobby: LobbyState
var _map: MapData
var _view: SubViewport
var _looks: Dictionary[StringName, int] = {}
## The last round's composer, kept until the next round: over() can run mid-tick (Cancelled is decided in the
## MATCH_FLOW_BEGIN slot) and the later slots of that tick still call its hooks.
var _spent: RoundComposer


func _init(knobs: Knobs, net: NetAuthority, router: ConnectionRouter, handoff: RosterHandoff,
		lobby: LobbyState) -> void:
	name = NODE_NAME
	_knobs = knobs
	_net = net
	_router = router
	_handoff = handoff
	_lobby = lobby
	_map = MapData.load_map()
	for c in CharacterDef.load_all():
		_looks[c.id] = c.appearance_id
	hidden = HiddenSpawner.new()
	add_child(hidden)
	handoff.handed_off.connect(_on_handed_off)


## True while a round is composed and not yet over.
func is_running() -> bool:
	return composer != null


## Returns the lobby to Waiting after round_over: players whose peer is gone (dropped during the round) leave
## the lobby first, so Waiting lists only connected players (lobby rule 18); the host's own token stays.
func finish(ended: bool) -> void:
	for token in _lobby.tokens():
		if token != _lobby.host_token and _net.peer_id_of(_net.player_id_of_token(token)) == -1:
			_lobby.leave(token)
	_handoff.end_round(ended)


func _on_handed_off(roster: Roster) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)
	var world := Node3D.new()
	_view.add_child(world)
	MapGreybox.build(world, _map)
	composer = RoundComposer.new(_knobs, roster, _map, _net, multiplayer as SceneMultiplayer, world,
			TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _look_of.bind(roster))
	composer.hidden = hidden
	composer.on_over = _on_over
	server = RoundServer.new()
	add_child(server)
	var errs := composer.start(server, rng)
	if not errs.is_empty():
		push_error("RoundHost: round not started: %s" % "; ".join(errs))
		composer.stop()
		_on_over(false)
		return
	_handoff.publish(server.registry)
	_router.bus = server.bus
	round_started.emit()


## A survivor's own character appearance (CharacterDef.appearance_id of its roster character).
func _look_of(player_id: int, roster: Roster) -> int:
	return _looks.get(roster.entry(player_id).get("character", &""), -1)


## RoundComposer.on_over: the composer already stopped the round (called from inside its tick).
func _on_over(ended: bool) -> void:
	_router.bus = null
	_spent = composer
	composer = null
	if server != null:
		server.queue_free()
		server = null
	if _view != null:
		_view.queue_free()
		_view = null
	round_over.emit(ended)


func _exit_tree() -> void:
	if composer != null:
		composer.stop()
		composer = null
		_router.bus = null
