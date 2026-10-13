extends Node
## Samples interpolated transforms from _process, where the engine documents them as valid.
## Records each child's offset from the parent's interpolated position.

var parent_ref: Node3D   # child with zero local offset, inheriting interpolation
var inherit: Node3D
var off: Node3D
var samples: Array = []


func _process(_dt: float) -> void:
	if parent_ref:
		var px := parent_ref.get_global_transform_interpolated().origin.x
		samples.append([inherit.get_global_transform_interpolated().origin.x - px, off.get_global_transform_interpolated().origin.x - px, Engine.get_physics_interpolation_fraction(), off.position.x])
