class_name LungeView extends RefCounted
## Read-only view of the Lunge state (StateKeys.LUNGE_STATE; monster-abilities.md "States and
## Transitions"; ADR-0005 §3), registered by MonsterAbilities.setup. Readers: Borrowed Face (rule 7
## rejects a transformation while attacking: `set_attack_source(view.is_attacking)`), Survivor Defense
## (rules 15-16), Scare Events, the Controller (wind-up root).
## Getters only (state_registry_test scans every *_view.gd). Holds the module weakly; after it is
## freed the view reads Ready, not attacking.
## Usage: `var v := registry.view(StateKeys.LUNGE_STATE, LungeView) as LungeView`

var _ma: WeakRef


func _init(ma: MonsterAbilities) -> void:
	_ma = weakref(ma)


## Current state, a MonsterAbilities.Lunge value.
func get_state() -> int:
	var ma := _ma.get_ref() as MonsterAbilities
	return ma.lunge_state() if ma != null else MonsterAbilities.Lunge.READY


## True when `player` is the shapeshifter and its lunge is in wind-up, Active or takedown commit.
## Signature of BorrowedFace's attack source, (player) -> bool.
func is_attacking(player: int) -> bool:
	var ma := _ma.get_ref() as MonsterAbilities
	return ma != null and player == ma.monster() and ma.attacking()
