// H13 world progress bar (design/ux/hud.md H13, interaction-patterns P4; ASSET-087), Claude Code for Dead Signal.
// A camera-facing quad: a black backing plate around a dark track, filled left to right in HUD white, matching the
// feed's white on black (hud.md: 7:1 on an opaque box). Unshaded so the dark facility cannot hide it; depth-tested
// so walls do. Target: Forward+ desktop; no texture reads, a few ALU ops per fragment, one draw per live bar.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

group_uniforms progress;
uniform float fill : hint_range(0.0, 1.0) = 0.0;
group_uniforms look;
uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 track_color : source_color = vec4(0.22, 0.22, 0.22, 1.0);
uniform vec4 back_color : source_color = vec4(0.0, 0.0, 0.0, 0.9);
// Backing plate border as a fraction of the quad: x of its width, y of its height.
uniform vec2 border = vec2(0.02, 0.2);
group_uniforms;

void vertex() {
	// billboard: keep the model's origin and its x/y scale, face the camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 inner = (UV - border) / (1.0 - 2.0 * border); // 0-1 across the track
	vec2 in_lo = step(vec2(0.0), inner);
	vec2 in_hi = step(inner, vec2(1.0));
	float inside = in_lo.x * in_lo.y * in_hi.x * in_hi.y; // 1 on the track, 0 on the plate
	float filled = step(inner.x, fill); // 1 left of the fill edge
	vec4 c = mix(back_color, mix(track_color, fill_color, filled), inside);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
