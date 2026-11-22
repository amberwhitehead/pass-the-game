shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D text_tex : filter_nearest;
uniform vec4 lcd_color : source_color = vec4(0.55, 1.0, 0.65, 1.0);
uniform vec2 dot_grid = vec2(64.0, 24.0);
uniform float dot_radius = 0.40;

void fragment() {
	vec2 uv = UV;
	// sample the rendered text (green on black)
	vec4 t = texture(text_tex, uv);
	float lum = max(t.r, max(t.g, t.b));
	// dot-matrix mask
	vec2 cell = fract(uv * dot_grid) - 0.5;
	float dot_mask = smoothstep(dot_radius, dot_radius - 0.08, length(cell));
	float lit = lum * dot_mask;
	vec3 col = lcd_color.rgb * lit;
	// faint unlit grid so the panel reads as a display even when dark
	float ghost = dot_mask * 0.06;
	ALBEDO = col + lcd_color.rgb * ghost;
	EMISSION = col * 3.2 + lcd_color.rgb * ghost;
	ALPHA = 1.0;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}