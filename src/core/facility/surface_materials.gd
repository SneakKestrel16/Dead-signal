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
## Door and exit leaves (BUG-0018; placeholder until the door models, ASSET-048/049).
@export var door: Material
## The planks drawn on a barricaded door (BUG-0018; placeholder until ASSET-049).
@export var barricade: Material
## Used for a zone missing from a table.
@export var fallback: Material
## Prop scenes (ASSET-052..064, assets/art/props/, tools/art/build_props.py) MapGreybox draws instead of posts,
## looked up by MapMarker.id first, then MapMarker.type (so h4..h6 can be lockers while `hiding` is a cabinet).
## Also &"exit" (frame at the MapPassage.EXIT opening), &"exit_lit" (its lamp lens, shown while the exit is
## open) and LOS blocker node names of the level scene (&"BlockerCore", &"BlockerBreakerWall"). Visual only.
@export var props: Dictionary[StringName, PackedScene] = {}


## Floor material of `zone`.
func floor_of(zone: StringName) -> Material:
	return floors.get(zone, fallback)


## Wall material of `zone`.
func wall_of(zone: StringName) -> Material:
	return walls.get(zone, fallback)


## Ceiling material of `zone`.
func ceiling_of(zone: StringName) -> Material:
	return ceilings.get(zone, fallback)


## Prop scene of marker `m`: by its id, else by its type; null when it has none.
func prop_of(m: MapMarker) -> PackedScene:
	return props.get(m.id, props.get(m.type))
