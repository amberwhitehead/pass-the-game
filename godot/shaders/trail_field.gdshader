shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D deposit_tex : filter_linear_mipmap;
uniform float decay : hint_range(0.8, 0.99) = 0.92;
uniform float deposit_strength : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(screen_texture, 0));
	vec4 acc = vec4(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			acc += texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * px);
		}
	}
	acc /= 9.0;
	vec4 dep = texture(deposit_tex, SCREEN_UV);
	COLOR = acc * decay + dep * deposit_strength;
}