class_name LightingView extends RefCounted
## Read-only view of facility lighting (ADR-0009 §4), registered by FacilityLighting.setup under both
## StateKeys.LIGHTING_STATE and StateKeys.BLACKOUT_ABLE. Readers: Monster Abilities (rule 17 Blackout
## target validation), Scare Events (ambush test, RoundScript block under Blackout).
## Getters only, named get_/is_ (state_registry_test scans every *_view.gd), so ADR-0009 §4's base(),
## overlays() and blackout_able() are get_base(), get_overlays() and is_blackout_able(). Holds the module weakly; after it is
## freed the view reads the round-start state: Low Power, no overlays, not dark, blackout_able.
## Usage: `var v := registry.view(StateKeys.LIGHTING_STATE, LightingView) as LightingView`

var _m: WeakRef


func _init(m: FacilityLighting) -> void:
	_m = weakref(m)


## The facility base state, a FacilityLighting.Base value.
func get_base() -> int:
	var m := _m.get_ref() as FacilityLighting
	return m.base() if m != null else FacilityLighting.Base.LOW_POWER


## Overlay bitmask (FacilityLighting.OVERLAY_*) of map volume `volume`; 0 for an unknown id.
func get_overlays(volume: StringName) -> int:
	var m := _m.get_ref() as FacilityLighting
	return m.overlays(volume) if m != null else 0


## True while a Blackout darkens `volume`.
func is_dark(volume: StringName) -> bool:
	var m := _m.get_ref() as FacilityLighting
	return m != null and m.is_dark(volume)


## True when `volume` may be blacked out (false for the active terminal room during Evacuation and
## for an unknown id).
func is_blackout_able(volume: StringName) -> bool:
	var m := _m.get_ref() as FacilityLighting
	return m.blackout_able(volume) if m != null else true
