// Transformation warp overlay (story borrowed-face/010; ADR-0010 §6). Author: Dead Signal gameplay code.
// VFX ASSET-078 (design/assets/specs/vfx-assets.md; art bible §5 Transformation).
// Set as material_overlay on every drawn art mesh of a body whose snapshot says Transforming; `warp` runs
// 0 -> 1 over the transform duration. Fragment-only shimmer: screen-space refraction plus a cold tint,
// never moving VERTEX (ADR-0010 §6, AD-43). With reduced_motion the shimmer stops and only the tint stays.
// Silhouette-first end (art bible §5 "a clean, high-contrast shape at the end of the warp"): over the last
// stretch of `warp` the ripple settles and the body flattens to one dark silhouette colour, so the last
// frame before the new form is a clean shape. The overlay leaves with the Transforming flag (LB-6).
// Pipeline: Forward+ (project renderer), transparent pass (reads the screen texture). Budget: one screen
// sample per fragment, a few trig ops; one body at most (one shapeshifter). No variants.
// PLACEHOLDER look: every default below is NOT SOURCEABLE (no VFX direction yet; the GDD asks only for a
// "subtle visual warp"). Settled by the VFX art pass.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

// Ripple time speed, screen-space ripple frequencies (y, x) and the x ripple's speed ratio.
const float RIPPLE_SPEED = 6.0;
const float RIPPLE_FREQ_Y = 70.0;
const float RIPPLE_FREQ_X = 55.0;
const float RIPPLE_X_RATIO = 1.3;
// Where on `warp` the silhouette starts and is complete. NOT SOURCEABLE: the last ~15% of the 2 s
// (inference: long enough to read as a frame, short enough to keep the ripple the main cue).
const float SILHOUETTE_FROM = 0.85;
const float SILHOUETTE_FULL = 0.98;

group_uniforms warp_state;
uniform float warp : hint_range(0.0, 1.0) = 0.0;
uniform bool reduced_motion = false;
group_uniforms look;
uniform float refraction_strength : hint_range(0.0, 0.1) = 0.008;
uniform vec4 tint : source_color = vec4(0.55, 0.8, 1.0, 0.12);
// Art bible §4 Void Charcoal (#14181A), the palette's shadow base: the reveal silhouette colour.
// Inference: the bible names no silhouette colour; art-director settles it.
uniform vec3 silhouette : source_color = vec3(0.078, 0.094, 0.102);
group_uniforms;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	// Intensity rises from half to full over the transformation, so the cue is visible from its start.
	float rise = 0.5 + 0.5 * warp;
	float motion = 1.0 - float(reduced_motion);
	float t = TIME * RIPPLE_SPEED;
	vec2 ripple = vec2(sin(SCREEN_UV.y * RIPPLE_FREQ_Y + t), cos(SCREEN_UV.x * RIPPLE_FREQ_X - t * RIPPLE_X_RATIO));
	float clean = smoothstep(SILHOUETTE_FROM, SILHOUETTE_FULL, warp);
	vec2 offset = ripple * refraction_strength * rise * motion * (1.0 - clean);
	vec3 behind = textureLod(screen_tex, SCREEN_UV + offset, 0.0).rgb;
	ALBEDO = mix(mix(behind, tint.rgb, tint.a * rise), silhouette, clean);
	ALPHA = 1.0;
}
