shader_type canvas_item;
render_mode blend_disabled;
// Downsamples the simulation state to a tiny 8-bit mask for the maze solver: R = 1 where the
// pattern chemical is high (colour 1), else 0. Reading this back is far cheaper than reading back
// the full float simulation texture.

uniform sampler2D state : filter_nearest;
uniform float threshold = 0.135;

void fragment() {
	COLOR = vec4(texture(state, UV).g >= threshold ? 1.0 : 0.0, 0.0, 0.0, 1.0);
}
