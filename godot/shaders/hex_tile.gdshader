shader_type spatial;
render_mode cull_disabled;
// One glowing hexagon tile (pointy-top). Mesh UVs are vertex.xz / (2R) + 0.5.
// Per-instance custom data: x = glow 0..1 (raised near the player), y = phase.

uniform vec4 base_color : source_color = vec4(0.04, 0.05, 0.08, 1.0);
uniform vec4 edge_color : source_color = vec4(0.25, 0.85, 1.0, 1.0);
uniform float edge_width = 0.09;
uniform float gap = 0.04;   // dark seam between tiles

varying float v_glow;
varying float v_phase;

void vertex() {
	v_glow = INSTANCE_CUSTOM.x;
	v_phase = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec2 q = abs((UV - 0.5) * 2.0);                // in units of circumradius
	float d = max(q.x, dot(q, vec2(0.5, 0.8660254)));
	float lim = 0.8660254 * (1.0 - gap);           // 0.866 = apothem
	if (d > lim) {
		discard;
	}
	float edge = smoothstep(lim - edge_width, lim - edge_width * 0.3, d);
	float idle = 0.5 + 0.5 * sin(TIME * 1.2 + v_phase * 6.2831);
	float inner = (1.0 - d / lim) * 0.12;
	ALBEDO = base_color.rgb;
	METALLIC = 0.6;
	ROUGHNESS = 0.35;
	EMISSION = edge_color.rgb * (edge * (0.35 + 0.25 * idle + 1.6 * v_glow) + inner * (0.4 + 2.0 * v_glow));
}
