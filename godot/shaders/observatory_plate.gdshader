shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform float layer_count : hint_range(0.0, 4.0) = 0.0;
uniform vec4 base_color : source_color = vec4(0.3, 0.25, 0.18, 0.3);
uniform vec4 solid_color : source_color = vec4(0.85, 0.7, 0.3, 1.0);
uniform vec4 etch_color : source_color = vec4(1.0, 0.9, 0.5, 1.0);

void fragment() {
	float t = clamp(layer_count / 4.0, 0.0, 1.0);
	vec3 col = mix(base_color.rgb, solid_color.rgb, t);
	float alpha = mix(base_color.a, solid_color.a, t);
	// etch lines when fully solid
	if (t > 0.95) {
		float grid = abs(fract(UV.x * 4.0) - 0.5) + abs(fract(UV.y * 4.0) - 0.5);
		if (grid < 0.08) {
			col = mix(col, etch_color.rgb, 0.6);
		}
	}
	ALBEDO = col;
	ALPHA = alpha;
	EMISSION = col * (t * 0.4);
	ROUGHNESS = 0.35;
	METALLIC = 0.6;
}