class_name VfxBurst extends RefCounted
## One-shot particle bursts for the VFX set (design/assets/specs/vfx-assets.md ASSET-079..085; art bible §4,
## §5 no gore, §8 tier S). Each burst is a GPUParticles3D named vfx_[name], built once by its presenter and
## fired with fire(); no textures (vertex-coloured quads or small boxes), so the §8 256 px cap holds trivially.
## Deviation from the spec's `.tscn` + `.tres` per VFX: built in code like every other client presenter here,
## so the look lives next to the event that fires it. Moving them to scenes is a data move, not a logic one.
## Budget (inference; profiling settles it): at most 40 particles per burst, one draw call each, unshaded
## glow bursts or lit opaque chunks, no shadows.
## Usage:
##   var dust := VfxBurst.make(&"door_dust", Color(0.5, 0.48, 0.45), 24, 1.2, Vector2(0.5, 1.5), 60.0, ...)
##   add_child(dust); VfxBurst.fire(dust, at)

## Particle look: a camera-facing quad (dust, sparks, cloth) or a small box (chunks, shards).
enum Shape { QUAD, CHIP }


## A burst named vfx_`name`: `amount` particles living `lifetime` s, leaving along `direction` within
## `spread_deg` at `speed` (min, max) m/s under `gravity`, each `size` m. `glow`: unshaded (sparks, arcs);
## otherwise lit by the scene (dust, debris). Not emitting until fire().
static func make(name: StringName, colour: Color, amount: int, lifetime: float, speed: Vector2,
		spread_deg: float, gravity: Vector3, size: float, shape: Shape = Shape.QUAD, glow: bool = false,
		direction: Vector3 = Vector3.UP) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = StringName("vfx_%s" % name)
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = direction
	pm.spread = spread_deg
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = gravity
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	pm.color = colour
	if shape == Shape.CHIP:
		pm.angular_velocity_min = -360.0
		pm.angular_velocity_max = 360.0
	var fade := Gradient.new() # fade out over life
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0) if shape == Shape.QUAD else Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	ramp.width = 32
	pm.color_ramp = ramp
	p.process_material = pm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if glow else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if shape == Shape.QUAD:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		var q := QuadMesh.new()
		q.size = Vector2(size, size)
		q.material = m
		p.draw_pass_1 = q
	else:
		m.roughness = 0.8
		var b := BoxMesh.new()
		b.size = Vector3(size, size * 0.3, size * 0.7)
		b.material = m
		p.draw_pass_1 = b
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	return p


## Starts `p`'s burst at `at` (its parent's space; every presenter here sits at the world origin).
static func fire(p: GPUParticles3D, at: Vector3) -> void:
	p.position = at
	p.restart()
