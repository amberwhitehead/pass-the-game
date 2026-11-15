shader_type canvas_item;
render_mode blend_disabled;
// One Gray-Scott reaction-diffusion step. State per texel: r = u (feed chemical), g = v (the
// pattern chemical; high v is "colour B"). Needs a float render target (SubViewport.use_hdr_2d).
// Several of these are chained, each reading the previous stage's output, so a frame runs
// several steps. Cylinders on the table pin the state beneath them to colour A or B.

uniform sampler2D prev : filter_nearest, repeat_enable;
uniform float feed = 0.055;
uniform float kill = 0.062;
uniform float du = 1.0;
uniform float dv = 0.5;
uniform bool reset_state = false;
// x, y = centre in texture UV, z = radius in UV, w = colour (0 = A, 1 = B). z <= 0 = unused.
uniform vec4 pins[16];

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(prev, 0));
	vec4 c;
	if (reset_state) {
		// all colour A, sprinkled with a few small seeds of colour B
		vec2 g = UV * 24.0;
		float seeded = (hash(floor(g)) > 0.94 && length(fract(g) - 0.5) < 0.45) ? 1.0 : 0.0;
		c = vec4(1.0 - 0.5 * seeded, seeded, 0.0, 1.0);
	} else {
		c = texture(prev, UV);
		vec2 lap = -c.rg;
		lap += 0.2 * (texture(prev, UV + vec2(px.x, 0.0)).rg + texture(prev, UV - vec2(px.x, 0.0)).rg
				+ texture(prev, UV + vec2(0.0, px.y)).rg + texture(prev, UV - vec2(0.0, px.y)).rg);
		lap += 0.05 * (texture(prev, UV + px).rg + texture(prev, UV - px).rg
				+ texture(prev, UV + vec2(px.x, -px.y)).rg + texture(prev, UV + vec2(-px.x, px.y)).rg);
		float u = c.r;
		float v = c.g;
		float reaction = u * v * v;
		u += du * lap.x - reaction + feed * (1.0 - u);
		v += dv * lap.y + reaction - (feed + kill) * v;
		c = vec4(clamp(u, 0.0, 1.0), clamp(v, 0.0, 1.0), 0.0, 1.0);
	}
	for (int i = 0; i < 16; i++) {
		if (pins[i].z > 0.0 && distance(UV, pins[i].xy) < pins[i].z) {
			c = pins[i].w > 0.5 ? vec4(0.5, 0.4, 0.0, 1.0) : vec4(0.2, 0.0, 0.0, 1.0);   // colour-0 pin: fuel-poor, so the pattern is suppressed around it
		}
	}
	COLOR = c;
}
