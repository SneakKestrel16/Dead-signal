// Included by spatial_char_survivor_body.gdshader and viewmodel/spatial_char_viewmodel_arms.gdshader, so the
// body and the first-person arms draw one texture set and one look tint (art bible §8 shared-rig rule).
// Shared survivor body (ASSET-001) with the look's tint and retro-reflective stripe (ASSET-002..007).
// Author: technical-artist, 2026-10-15. Target: Forward+ (D3D12/Vulkan), Windows PC.
// One ShaderMaterial per look (BodyVisual), so the disguise copy is the same resource (LB-6). No variants.
// Cost: 5 texture reads, no branches, no custom light(). The stripe is never emissive (art bible §5).
// UV2 (TEXCOORD_1, tools/art/build_characters.py stripe_uv): chest area u 0-1, v 0-1; left sleeve band
// u 0-1 around the arm, v 2-3 along it; anything else gets no stripe.

// Rows in tex_survivor_stripe_mask_256.png, one per look; in each row the chest pattern fills u 0-0.8 and
// the sleeve band u 0.8-1.
const float STRIPE_ROWS = 5.0;
const float CHEST_U = 0.8;
const float SLEEVE_V0 = 2.0;
// Keeps linear filtering off the neighbouring pattern row (about one texel of a 51 px row).
const float ROW_INSET = 0.02;

group_uniforms body;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic; // alpha = tint mask
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic; // OpenGL Y+
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic;
// Suit colour (art bible §5 hex), applied where the albedo alpha is 1.
uniform vec4 tint : source_color = vec4(1.0);

group_uniforms stripe;
uniform sampler2D stripe_mask : hint_default_black, filter_linear, repeat_disable;
// Mask row of the look's pattern, 0-4; -1 = no stripe.
uniform int stripe_row = -1;
// Pale and high albedo but within sRGB 225 (art bible §6).
uniform vec3 stripe_albedo : source_color = vec3(0.88);
uniform float stripe_roughness : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	float sleeve = step(SLEEVE_V0, UV2.y);
	vec2 st = vec2(UV2.x, UV2.y - sleeve * SLEEVE_V0); // local 0-1 coordinates inside either area
	vec2 in2 = step(vec2(0.0), st) * step(st, vec2(1.0));
	float on = in2.x * in2.y * step(0.0, float(stripe_row));
	float mu = mix(st.x * CHEST_U, CHEST_U + st.x * (1.0 - CHEST_U), sleeve);
	float mv = (float(stripe_row) + clamp(st.y, ROW_INSET, 1.0 - ROW_INSET)) / STRIPE_ROWS;
	float s = on * texture(stripe_mask, vec2(clamp(mu, 0.0, 1.0), mv)).r;
	ALBEDO = mix(a.rgb * mix(vec3(1.0), tint.rgb, a.a), stripe_albedo, s);
	ROUGHNESS = mix(orm.g, stripe_roughness, s);
	METALLIC = 0.0;
	AO = orm.r;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
}
