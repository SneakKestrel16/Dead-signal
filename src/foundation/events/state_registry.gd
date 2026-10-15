class_name StateRegistry extends RefCounted
## Read-only replicated state, looked up by key and expected class (ADR-0005).
## Plain object: the composition root creates and injects it; never an autoload, never signals.
## Not thread-safe: server main thread only.
## Owners register ONE getter-only view per key (StateKeys); readers never hold the owner.
## View classes expose getters only. Owners replace collection values whole, never element-wise
## (4.7: writing a packed-array element no longer calls the property setter).
## Usage:
##   registry.register_view(StateKeys.DOOR_STATE, &"FacilityMap", DoorStateView.new(facility))
##   var doors := registry.view(StateKeys.DOOR_STATE, DoorStateView) as DoorStateView

## When true a violation ends in assert(false). Default: debug builds only.
## Tests set false to observe the violation without aborting the run.
var fail_hard: bool = OS.is_debug_build()
## Every violation message since construction (not reset by clear()).
var violations: PackedStringArray = PackedStringArray()

var _views: Dictionary[StringName, Object] = {}
var _owners: Dictionary[StringName, StringName] = {}


## Registers `view` for `key`, owned by module `owner`. Once per key: a second registration is a
## violation and the first view is kept. Example: `registry.register_view(StateKeys.DOOR_STATE, &"FacilityMap", v)`.
func register_view(key: StringName, owner: StringName, view: Object) -> void:
	if _views.has(key):
		_violate("StateRegistry: key '%s' already registered by %s; %s may not register it again"
			% [key, _owners[key], owner])
		return
	_views[key] = view
	_owners[key] = owner


## Returns the view registered for `key` if it is an instance of `expected`, else null after
## recording a violation (unregistered key, or wrong class). Both messages name the key.
## Example: `var v := registry.view(StateKeys.DOOR_STATE, DoorStateView) as DoorStateView`.
func view(key: StringName, expected: Script) -> Object:
	if not _views.has(key):
		_violate("StateRegistry: key '%s' is not registered" % key)
		return null
	var v: Object = _views[key]
	if not is_instance_of(v, expected):
		_violate("StateRegistry: view '%s' (owner %s) is not an instance of the expected class"
			% [key, _owners[key]])
		return null
	return v


## True when a view is registered for `key`. No violation: for readers whose owner may not exist yet
## (ADR-0011: a missing stats view reads as zero). Example: `registry.has_view(StateKeys.STATS_DEFENSE)`.
func has_view(key: StringName) -> bool:
	return _views.has(key)


## Drops every view and owner record. Called at round end by the composition root; breaks the
## module -> registry -> view -> module reference cycle. Example: `registry.clear()`.
func clear() -> void:
	_views = {}
	_owners = {}


func _violate(msg: String) -> void:
	violations.append(msg)
	push_error(msg)
	assert(not fail_hard, msg)
