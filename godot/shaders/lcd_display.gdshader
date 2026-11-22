shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D text_tex : filter_nearest;
uniform vec4 lcd_color : source_color = vec4(0.55, 1.0, 0.65, 1.0);

void fragment() {
	vec4 t = texture(text_tex, UV);
	float lum = max(t.r, max(t.g, t.b));
	vec3 col = lcd_color.rgb * lum;
	// faint backlight glow so the panel reads as a display even when dark
	vec3 backlight = lcd_color.rgb * 0.045;
	ALBEDO = col + backlight;
	EMISSION = col * 3.0 + backlight;
	ALPHA = 1.0;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}