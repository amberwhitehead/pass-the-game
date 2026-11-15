shader_type canvas_item;
// Screen-space vignette + gentle colour wash. Put on a full-screen ColorRect.
// (No screen texture read, so it's cheap on mobile / web.)

uniform vec4 wash : source_color = vec4(0.2, 0.1, 0.4, 0.0);
uniform float strength : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 d = UV - 0.5;
	float v = smoothstep(0.35, 0.85, length(d * vec2(1.2, 1.0)));
	COLOR = vec4(mix(wash.rgb, vec3(0.0), v), v * strength + wash.a);
}
