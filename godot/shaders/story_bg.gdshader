shader_type canvas_item;
// Animated twilight gradient with twinkling stars and drifting haze, for the intro.

uniform vec4 top_color : source_color = vec4(0.05, 0.03, 0.18, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.45, 0.18, 0.4, 1.0);
uniform float stars : hint_range(0.0, 1.0) = 1.0;
uniform float show_secret : hint_range(0.0, 1.0) = 0.0;
uniform float secret_bright : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, pow(uv.y, 1.3));
	// stars
	vec2 grid = floor(uv * vec2(90.0, 50.0));
	float h = hash(grid);
	vec2 cell = fract(uv * vec2(90.0, 50.0)) - 0.5;
	float star = step(0.985, h) * smoothstep(0.4, 0.0, length(cell)) * (0.5 + 0.5 * sin(TIME * (1.0 + h * 4.0) + h * 50.0));
	col += vec3(star) * (1.0 - uv.y) * stars;
	// A secret star at cell (79, 36). Its brightness is driven from the title screen so
	// the click target and the visible twinkle stay exactly in step.
	float is_secret = 1.0 - step(0.5, abs(grid.x - 79.0) + abs(grid.y - 36.0));
	float secret = show_secret * is_secret * smoothstep(0.45, 0.0, length(cell)) * secret_bright;
	col += vec3(1.0, 0.92, 0.72) * secret * stars;
	// haze
	float haze = sin(uv.x * 6.0 + TIME * 0.2) * sin(uv.y * 4.0 - TIME * 0.15);
	col += vec3(0.08, 0.04, 0.12) * haze * 0.5;
	COLOR = vec4(col, 1.0);
}
