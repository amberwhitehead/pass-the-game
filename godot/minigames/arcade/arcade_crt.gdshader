shader_type canvas_item;
// CHRONO RAIDER's monitor: crisp pixels with soft scanlines, a faint RGB mask and a
// vignette. Kept light so the game stays readable.

uniform float scanline : hint_range(0.0, 1.0) = 0.22;
uniform vec2 source_size = vec2(384.0, 216.0);

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float line = 0.5 + 0.5 * cos(UV.y * source_size.y * 6.28318);
	col.rgb *= 1.0 - scanline * line;
	float mask = mod(floor(FRAGCOORD.x), 3.0);
	col.rgb *= vec3(mask == 0.0 ? 1.06 : 0.97, mask == 1.0 ? 1.06 : 0.97, mask == 2.0 ? 1.06 : 0.97);
	vec2 c = UV - 0.5;
	col.rgb *= 1.0 - dot(c, c) * 0.55;
	COLOR = col;
}
