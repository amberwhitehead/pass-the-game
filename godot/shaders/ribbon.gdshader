shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
// A glowing ribbon along a strip mesh: UV.x runs 0..1 along it, UV.y 0..1 across. `progress` reveals it from
// the start (0..1). Colour blends from color_a to color_b; a soft bright core and slow pulses run along it.

uniform vec3 color_a : source_color = vec3(1.0, 0.8, 0.3);
uniform vec3 color_b : source_color = vec3(0.4, 0.8, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float glow = 1.6;

void fragment() {
	if (UV.x > progress) {
		discard;
	}
	float edge = 1.0 - abs(UV.y * 2.0 - 1.0);               // 1 on the centre line, 0 at the edges
	float pulse = 0.75 + 0.25 * sin(UV.x * 40.0 - TIME * 5.0);
	float head = 1.0 + 2.0 * smoothstep(0.06, 0.0, progress - UV.x) * step(progress, 0.999);   // bright leading edge while growing
	vec3 col = mix(color_a, color_b, UV.x);
	ALBEDO = col * glow * pulse * head * (0.35 + 0.9 * edge);
	ALPHA = clamp(edge * 1.4, 0.0, 1.0);
}
