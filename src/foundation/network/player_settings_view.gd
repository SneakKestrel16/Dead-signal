class_name PlayerSettingsView extends RefCounted
## Read-only view of the per-player settings the server holds for the session (StateKeys.
## CAMERA_FLINCH_TOGGLE; ADR-0015 §4, story controller-interaction/013): getters only. Scare Events reads
## it before requesting a flinch; the Controller's ViewOffset gets the changes from
## NetAuthority.flinch_enabled_changed. Registered per round by the round composer.
## Deviation, naming only: ADR-0015 names the key `player_settings` and the getter flinch_enabled();
## the state table already has the Camera flinch toggle row (camera_flinch_toggle) and views name
## getters get_/is_/has_ (state_registry_test).
## Usage: `var v := registry.view(StateKeys.CAMERA_FLINCH_TOGGLE, PlayerSettingsView) as PlayerSettingsView`

var _net: NetAuthority


func _init(net: NetAuthority) -> void:
	_net = net


## Whether the player takes the flinch rotation; false for unknown ids.
func is_flinch_enabled(player_id: int) -> bool:
	return _net.flinch_enabled_of(player_id)
