## Story match-flow/014 evidence driver: boots the shipped boot scene (res://src/main.tscn, so the lobby
## screen and its --lobby-* flags run unchanged) and, once the host's composed round is Running, plays a
## lunge down, a taser stun and a rescue on the server, then ends the round with SurvivorEliminated for
## every survivor (as lobby_to_round_wiring_test does). The lunge and the shot go through the composer's
## client-packet entry (the bytes a client sends); the bodies are frozen and lined up along each player's
## server view direction first, since nobody aims for real. The rescue calls Downing's completion entry
## (a real hold needs aimed input frames). Nothing here changes a rule: every count comes from the owners.
## Usage (host; joiners run main.tscn with --lobby-join):
##   godot --path . res://tests/manual/results_stats_host.tscn -- --lobby-host --lobby-port=N --lobby-ready \
##       --lobby-seed=6 --lobby-shots=DIR   (seed 6: the host seat is the shapeshifter, see the evidence page)
extends Node

var _lobby: LobbyScreen
var _c: RoundComposer
var _step := 0
var _wait := 0.0
var _victim := -1
var _shooter := -1
var _downed := false
var _stunned := false


func _ready() -> void:
	var main := (load("res://src/main.tscn") as PackedScene).instantiate()
	add_child(main)
	_lobby = main.get_node("Lobby") as LobbyScreen


func _physics_process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 0.25
	var host := _lobby.round_host
	if host == null or host.composer == null or host.composer.lifecycle.state() != RoundLifecycle.State.RUNNING:
		_c = null
		return
	if _c != host.composer:
		_c = host.composer
		_step = 0
		_downed = false
		_stunned = false
		_c.server.bus.subscribe(&"SurvivorDowned", _on_downed)
		_c.server.bus.subscribe(&"MonsterStunned", _on_stunned)
	match _step:
		0: # line up: shooter, then the monster 3 m along its view, then the victim 1 m along the monster's
			_victim = _c.survivors[0]
			_shooter = _c.survivors[1]
			var s := _c._position(_shooter)
			_place(_shooter, s)
			var m := s + _c.view.server_dir(_shooter) * 3.0
			_place(_c.monster, m)
			_place(_victim, m + _c.view.server_dir(_c.monster) * 1.0)
			_step = 1
			_wait = 1.0
		1:
			if _downed:
				_step = 2
			elif _c.ma.lunge_state() == MonsterAbilities.Lunge.READY:
				_send(_c.monster, MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))
		2:
			if _stunned:
				_c.downing.rescue_completed(_victim, _shooter)
				print("MF14 down, stun and rescue done")
				_step = 3
				_wait = 2.0
			else:
				_send(_shooter, SurvivorDefense.fire_packet())
		3:
			for id in _c.survivors:
				var e := EvSurvivorEliminated.new()
				e.survivor = id
				_c.server.bus.emit(e)
			_step = 4


func _place(id: int, at: Vector3) -> void:
	_c.sm.set_frozen(id, true)
	_c.bodies[id].global_position = at


## As if `player`'s client sent `bytes` (RoundComposer._on_packet is the server's client-packet entry).
func _send(player: int, bytes: PackedByteArray) -> void:
	_c._on_packet(_c.net.peer_id_of(player), bytes)


func _on_downed(_e: ServerEvent) -> void:
	_downed = true


func _on_stunned(_e: ServerEvent) -> void:
	_stunned = true
