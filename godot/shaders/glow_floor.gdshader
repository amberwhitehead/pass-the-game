shader_type spatial;
render_mode cull_back;
// Neon grid floor with a soft pulse radiating from the centre.

uniform vec4 base_color : source_color = vec4(0.04, 0.03, 0.09, 1.0);
uniform vec4 line_color : source_color = vec4(0.5, 0.3, 1.0, 1.0);
uniform float grid_size = 1.0;
uniform float line_px = 1.5;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 g = v_world.xz / grid_size;
	vec2 f = abs(fract(g - 0.5) - 0.5) / fwidth(g);
	float line = 1.0 - clamp(min(f.x, f.y) / line_px, 0.0, 1.0);
	float d = length(v_world.xz);
	float pulse = 0.5 + 0.5 * sin(d * 1.5 - TIME * 2.0);
	ALBEDO = base_color.rgb;
	EMISSION = line_color.rgb * line * (0.3 + 0.7 * pulse) * smoothstep(12.0, 2.0, d);
	ROUGHNESS = 0.4;
}
