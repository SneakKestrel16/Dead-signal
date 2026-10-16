class_name SurfaceMaterials extends Resource
## The level's surface materials by zone (AD-249): what MapGreybox puts on each floor, wall and ceiling it
## builds, keyed by MapVolume.zone (A, B, C, link). The texture pass swaps materials in
## data/art/surface_materials.tres only; the geometry code never names a colour or texture.
## Usage: `mesh.material_override = (load(MapGreybox.SURFACES) as SurfaceMaterials).wall_of(v.zone)`

@export var floors: Dictionary[StringName, Material] = {}
@export var walls: Dictionary[StringName, Material] = {}
@export var ceilings: Dictionary[StringName, Material] = {}
## Glass partitions (research-facility.md `:` walls).
@export var glass: Material
## Used for a zone missing from a table.
@export var fallback: Material


## Floor material of `zone`.
func floor_of(zone: StringName) -> Material:
	return floors.get(zone, fallback)


## Wall material of `zone`.
func wall_of(zone: StringName) -> Material:
	return walls.get(zone, fallback)


## Ceiling material of `zone`.
func ceiling_of(zone: StringName) -> Material:
	return ceilings.get(zone, fallback)
