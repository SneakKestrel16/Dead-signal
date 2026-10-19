class_name DevCommands extends RefCounted
## Server side of the dev menu (designer, 2026-10-18: "a dev menu to trigger each thing for testing"). A
## client's DevMenu sends one command; the server runs it on the real round, so what follows is what a real
## round would show. Debug builds only: an exported release build never builds this (enabled()), so no
## player can send these. Untrusted bytes: a size cap, a Dictionary with one String "dev", a known command.
## Commands:
##   evac, last60, last30, last10     the round clock jumps to that much time left (MatchFlow.dev_skip_to)
##   power                            the terminal's Power Restored presentation (as round_host --force=power)
##   blackout                         a Blackout at the sender, as Monster Abilities emits it
##   scare:<id>                       catalogue scare <id> at the sender: to the sender for a single-client scare,
##                                    to every live player for a shared one
##   win_survivors, win_shapeshifter  the round ends now with that outcome
## Usage (round composer, server):
##   if DevCommands.enabled(): dev = DevCommands.new(flow, scares, catalogue, bus, position_of, live_players)
##   dev.request(player_id, bytes)   # from peer_packet

## Largest accepted packet (a scare id is short).
const CAP_BYTES := 128
## Clock targets of the skip commands, seconds left.
const SKIPS := {"last60": 60.0, "last30": 30.0, "last10": 10.0}

## Commands run so far, newest last (checks).
var ran: Array[String] = []

var _flow: MatchFlow
var _scares: ScareEvents
var _catalogue: ScareCatalogue
var _bus: EventBus
var _evac_window_s: float
var _position_of: Callable
var _live: Callable


## Whether the dev menu exists in this build: debug builds (editor and console runs), never an exported release.
static func enabled() -> bool:
	return OS.is_debug_build()


## The packet a client sends for `command`.
static func packet(command: String) -> PackedByteArray:
	return var_to_bytes({"dev": command})


## `position_of(player) -> Vector3`, `live_players() -> Array[int]`; `evac_window_s` is
## match_flow.evacuation_window_s.
func _init(flow: MatchFlow, scares: ScareEvents, catalogue: ScareCatalogue, bus: EventBus, evac_window_s: float,
		position_of: Callable, live_players: Callable) -> void:
	_flow = flow
	_scares = scares
	_catalogue = catalogue
	_bus = bus
	_evac_window_s = evac_window_s
	_position_of = position_of
	_live = live_players


## Runs `player`'s command if `bytes` are one; returns whether they were a dev packet.
func request(player: int, bytes: PackedByteArray) -> bool:
	if bytes.size() > CAP_BYTES:
		return false
	var d: Variant = bytes_to_var(bytes)
	if not (d is Dictionary and d.size() == 1 and d.get("dev") is String):
		return false
	run(player, d["dev"])
	return true


## Runs one command for `player`. Unknown commands are ignored.
func run(player: int, command: String) -> void:
	var at: Vector3 = _position_of.call(player)
	if command == "evac":
		_flow.dev_skip_to(_evac_window_s)
	elif SKIPS.has(command):
		_flow.dev_skip_to(SKIPS[command])
	elif command == "power":
		var o := EvObjectiveProgressChanged.new()
		o.objective = SurvivorObjectives.TERMINAL_ID
		o.state = SurvivorObjectives.TerminalState.POWERED
		_bus.emit(o)
	elif command == "blackout":
		var a := EvAbilityUsed.new()
		a.ability = MonsterAbilities.Ability.BLACKOUT
		a.target = at
		_bus.emit(a)
	elif command.begins_with("scare:"):
		var entry := _catalogue.entry(StringName(command.trim_prefix("scare:")))
		if entry == null:
			return
		var to: Array = [player] if entry.scope == ScareEntry.Scope.SINGLE_CLIENT else _live.call()
		var who := -1 if entry.source == ScareEntry.Source.ROUND_SCRIPT else player
		_scares.fire(entry.scare_id, at, to, entry.source, who)
	elif command == "win_survivors":
		_flow.dev_end(MatchFlow.Outcome.SURVIVORS_WIN)
	elif command == "win_shapeshifter":
		_flow.dev_end(MatchFlow.Outcome.SHAPESHIFTER_WINS)
	else:
		return
	ran.append(command)
