shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;
// Glowing hologram: fresnel rim + scrolling scanlines + vertex wobble.

uniform vec4 tint : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float scan_density = 40.0;
uniform float scan_speed = 1.5;
uniform float rim_power = 2.5;
uniform float wobble = 0.03;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
	VERTEX.x += sin(TIME * 6.0 + VERTEX.y * 12.0) * wobble;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	float scan = 0.5 + 0.5 * sin(v_local.y * scan_density - TIME * scan_speed * 6.0);
	float flicker = 0.9 + 0.1 * sin(TIME * 37.0);
	ALBEDO = tint.rgb * (0.35 + scan * 0.65 + fres) * flicker;
	ALPHA = clamp(0.25 + fres + scan * 0.35, 0.0, 1.0);
}
