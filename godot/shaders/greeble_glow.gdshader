shader_type spatial;
render_mode unshaded;
// Tiny glowing indicator rectangles on the room's walls: instance colour is the light's colour.

uniform float strength = 1.6;

void fragment() {
	ALBEDO = COLOR.rgb * strength;
}
