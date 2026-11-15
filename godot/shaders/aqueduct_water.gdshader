shader_type spatial;
render_mode unshaded, cull_disabled;
// Water in the aqueduct channel: a strip mesh with UV.x = metres along the channel, UV.y = 0..1 across.
// `fill` (metres) is how far the water has reached; beyond it nothing is drawn. Streaks scroll along the flow.

uniform float fill = 0.0;
uniform float speed = 0.9;
uniform vec3 deep : source_color = vec3(0.05, 0.38, 0.55);
uniform vec3 bright : source_color = vec3(0.55, 0.95, 1.0);

void fragment() {
	if (UV.x > fill) {
		discard;
	}
	float across = abs(UV.y * 2.0 - 1.0);
	float s = UV.x * 9.0 - TIME * speed * 6.0;
	float streak = 0.5 + 0.5 * sin(s + sin(UV.y * 7.0 + UV.x * 3.0) * 1.6);
	float glints = smoothstep(0.82, 1.0, 0.5 + 0.5 * sin(UV.x * 23.0 - TIME * speed * 9.0 + UV.y * 11.0));
	float front = smoothstep(0.0, 0.12, fill - UV.x);               // foamy leading edge while filling
	vec3 col = mix(deep, bright, streak * 0.45 + glints * 0.6 + (1.0 - front) * 0.6);
	col *= 1.0 - 0.25 * across;                                      // darker towards the walls
	ALBEDO = col;
	ALPHA = 0.92;
}
