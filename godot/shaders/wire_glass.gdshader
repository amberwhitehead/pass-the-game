shader_type spatial;
render_mode blend_mix, cull_disabled;
// Wire-reinforced safety glass: pale tinted pane with a diamond mesh of wire (spacing in metres).

uniform vec4 tint : source_color = vec4(0.62, 0.82, 0.78, 0.30);
uniform vec2 pane_size = vec2(0.26, 1.12);
uniform float spacing = 0.045;
uniform float wire = 0.05;

void fragment() {
	vec2 q = UV * pane_size / spacing;
	float d1 = abs(fract(q.x + q.y) - 0.5);
	float d2 = abs(fract(q.x - q.y) - 0.5);
	float line = step(min(d1, d2), wire);
	vec2 e = min(UV, 1.0 - UV) * pane_size;
	float rim = 1.0 - smoothstep(0.0, 0.02, min(e.x, e.y));      // darker where the glass meets the frame
	ALBEDO = mix(tint.rgb, vec3(0.2, 0.22, 0.22), max(line, rim * 0.6));
	ALPHA = mix(tint.a, 0.95, max(line, rim));
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
}
