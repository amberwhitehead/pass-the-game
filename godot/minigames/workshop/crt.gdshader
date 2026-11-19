shader_type canvas_item;
// The Futurescope's picture: scanlines, a curved vignette, a slow rolling bar,
// a cool phosphor tint, and snow when it is untuned (static_amount).

uniform float static_amount : hint_range(0.0, 1.0) = 0.0;
uniform float power : hint_range(0.0, 1.0) = 1.0;
uniform float alarm : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 c = uv - 0.5;
	// Slight barrel bulge.
	uv = 0.5 + c * (1.0 + 0.08 * dot(c, c));
	vec3 col = texture(TEXTURE, uv).rgb;
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(lum) * vec3(0.8, 1.0, 1.05), 0.45);
	col *= vec3(0.86, 1.0, 1.04);
	float scan = 0.82 + 0.18 * sin(uv.y * 480.0);
	col *= scan;
	float roll = smoothstep(0.0, 0.08, abs(fract(uv.y - TIME * 0.12) - 0.5));
	col *= 0.92 + 0.08 * roll;
	float snow = hash(floor(uv * vec2(240.0, 180.0)) + floor(TIME * 24.0));
	col = mix(col, vec3(snow), static_amount);
	col = mix(col, col * vec3(1.4, 0.55, 0.5), alarm * (0.5 + 0.5 * sin(TIME * 8.0)));
	float vig = smoothstep(0.75, 0.25, length(c * vec2(1.0, 1.1)));
	col *= mix(0.35, 1.0, vig);
	col = mix(vec3(0.05, 0.07, 0.07), col, power);
	COLOR = vec4(col, 1.0);
}
