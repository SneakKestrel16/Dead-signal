extends SceneTree
## Writes assets/art/materials/mat_*.tres from the textures built by
## tools/art/build_textures.py. Run after an import pass:
##   godot --headless --path . -s res://tools/art/make_materials.gd
## Tileables: world triplanar, 1024 px = 4 m (art bible §6, 256 px/m).

const ENV := "res://assets/art/environment/"
const MAT := "res://assets/art/materials/"
const TILEABLES := [
	"floor_tile_a", "concrete_a", "painted_block_a", "steel_plate_a", "ceiling_panel_a",
	"rubber_mat_a", "checker_plate_a", "server_rack_a", "metal_grate_a",
]


func _initialize() -> void:
	for n: String in TILEABLES:
		_save(_orm("tileable", n, n, 1024, true), n)
	for zone: String in ["zone_a", "zone_c"]:  # zone variants share normal/ORM
		_save(_orm("tileable", "painted_block_" + zone, "painted_block_a", 1024, true),
				"painted_block_" + zone)
	for n: String in ["trim_concrete", "trim_metal", "trim_markings"]:
		_save(_orm("trim", n, n, 2048, false), n)
	var glass := _orm("trim", "trim_glass", "trim_glass", 2048, false)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_save(glass, "trim_glass")
	var decal := _orm("decals", "decal_set", "decal_set", 1024, false)
	decal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_save(decal, "decal_set")
	_save(_orm("decals", "signage", "signage", 1024, false), "signage")
	_save(_stripe("stripe_hn", false), "stripe_hn")
	_save(_stripe("stripe_hs", true), "stripe_hs")
	quit()


## Albedo from [param albedo], normal and ORM from [param shared].
func _orm(sub: String, albedo: String, shared: String, size: int, triplanar: bool) -> ORMMaterial3D:
	var m := ORMMaterial3D.new()
	var base := "%s%s/tex_" % [ENV, sub]
	m.albedo_texture = load("%s%s_albedo_%d.png" % [base, albedo, size])
	m.normal_enabled = true
	m.normal_texture = load("%s%s_normal_%d.png" % [base, shared, size])
	m.orm_texture = load("%s%s_orm_%d.png" % [base, shared, size])
	m.ao_enabled = true
	m.ao_light_affect = 0.4  # inference: AO shows under the flashlight too; playtest settles it
	m.roughness = 1.0  # ORM G is the roughness; the scalar multiplies it
	m.metallic = 1.0  # ORM B is the metallic; the scalar multiplies it
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.25  # one texture repeat per 4 m
	return m


## Corridor stripe: albedo-only, low emissive (wayfinding emissive, art bible §4).
func _stripe(n: String, dashed: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("%sdecals/tex_%s_albedo_256.png" % [ENV, n])
	m.roughness = 0.6
	m.emission_enabled = true
	m.emission = Color.WHITE
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY  # ADD (default) would add white
	m.emission_texture = m.albedo_texture
	m.emission_energy_multiplier = 0.2  # inference: "low"; playtest settles it
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if dashed:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	return m


func _save(m: Material, n: String) -> void:
	DirAccess.make_dir_recursive_absolute(MAT)
	var err := ResourceSaver.save(m, "%smat_%s.tres" % [MAT, n])
	if err != OK:
		push_error("save mat_%s failed: %d" % [n, err])
