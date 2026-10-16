shader_type spatial;
// First-person arms (ASSET-011): the survivor body surface, drawn in front of the world.
// Author: technical-artist, 2026-10-15. Target: Forward+ (D3D12/Vulkan), Windows PC.
// Z_CLIP_SCALE is the vertex built-in BaseMaterial3D's use_z_clip_scale writes (Godot 4.7.2
// scene/resources/material.cpp): outside the shadow pass the clip-space depth is pulled toward the near plane,
// so a wall closer than the arms does not cut them. Cost: one multiply-add per vertex over the body shader.
#include "res://assets/art/characters/survivors/char_survivor_body.gdshaderinc"

uniform float z_clip_scale : hint_range(0.01, 1.0) = 1.0;

void vertex() {
	Z_CLIP_SCALE = z_clip_scale;
}
