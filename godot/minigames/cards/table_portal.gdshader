shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;

// The destination has its own camera and world. Screen projection makes this an
// aperture onto that camera, so replacing a fully covering aperture with the
// destination viewport preserves pixel positions rather than stretching a card UV.
uniform sampler2D destination : source_color, filter_linear, repeat_disable;

vec3 preserve_compatibility_color(vec3 color) {
	// Compatibility converts ALBEDO with a cubic sRGB approximation, then uses a
	// different inverse approximation on output. Invert that cubic here so an
	// already-rendered viewport does not suffer a second, shadow-crushing roundtrip.
	// Applies with the hub's linear tonemapping (the table texture is already mapped).
	// https://github.com/godotengine/godot/blob/master/drivers/gles3/shaders/tonemap_inc.glsl
	vec3 linear_target = pow((color + vec3(0.055)) / 1.055, vec3(2.4));
	vec3 corrected = max(color, vec3(0.05));
	for (int iteration = 0; iteration < 5; iteration++) {
		vec3 decoded = corrected * (corrected * (corrected * 0.305306011 + 0.682171111) + 0.012522878);
		vec3 derivative = corrected * (corrected * 0.915918033 + 1.364342222) + 0.012522878;
		corrected = clamp(corrected - (decoded - linear_target) / derivative, vec3(0.0), vec3(1.0));
	}
	return corrected;
}

void fragment() {
	vec3 color = texture(destination, SCREEN_UV).rgb;
	ALBEDO = OUTPUT_IS_SRGB ? preserve_compatibility_color(color) : color;
	ALPHA = 1.0;
}
