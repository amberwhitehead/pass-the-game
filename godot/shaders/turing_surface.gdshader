shader_type spatial;
render_mode unshaded, cull_back;
// Draws the reaction-diffusion state on the table disc: two colours blended by v, with a light
// emboss from the gradient of v so the pattern reads as a surface.

uniform sampler2D state : filter_linear, repeat_disable;
uniform vec4 color_a : source_color = vec4(1.0, 0.55, 0.18, 1.0);
uniform vec4 color_b : source_color = vec4(0.10, 0.62, 0.78, 1.0);
uniform vec4 rim_color : source_color = vec4(0.55, 0.75, 1.0, 1.0);
uniform float table_radius = 2.2;

// Maze-solver overlay. reach.rgb / lane_path.rgb hold one channel per lane (0 = the colour-1 path,
// 1 and 2 = the colour-0 lanes either side). reach is a code that grows with distance from the lane's
// start (0 = not reached); lane_path = 1 along the route found from start to end.
uniform sampler2D reach : filter_linear, repeat_disable;
uniform sampler2D lane_path : filter_linear, repeat_disable;
uniform int viz_mode = 0;   // 0 off, 1 route
uniform vec4 lane_color_main : source_color = vec4(0.6, 1.0, 1.0, 1.0);
uniform vec4 lane_color_flank : source_color = vec4(1.0, 0.95, 0.6, 1.0);

varying vec2 v_pos;

void vertex() {
	v_pos = VERTEX.xz;
}

void fragment() {
	float r = length(v_pos);
	if (r > table_radius) discard;
	vec2 uv = v_pos / (2.0 * table_radius) + 0.5;
	vec2 px = 1.0 / vec2(textureSize(state, 0));
	float v = texture(state, uv).g;
	float t = smoothstep(0.07, 0.2, v);
	vec3 col = mix(color_a.rgb, color_b.rgb, t);
	float vx = texture(state, uv + vec2(px.x, 0.0)).g - texture(state, uv - vec2(px.x, 0.0)).g;
	float vy = texture(state, uv + vec2(0.0, px.y)).g - texture(state, uv - vec2(0.0, px.y)).g;
	vec3 n = normalize(vec3(-vx * 5.0, -vy * 5.0, 1.0));
	col *= 0.78 + 0.3 * dot(n, normalize(vec3(-0.4, -0.5, 0.8)));
	if (viz_mode == 1) {
		vec3 rc = texture(reach, uv).rgb * 255.0;
		vec3 pc = texture(lane_path, uv).rgb;
		vec3 lc[3] = vec3[3](lane_color_main.rgb, lane_color_flank.rgb, lane_color_flank.rgb);
		// The solver grid is coarser than the simulation, so keep the route to cells that are really
		// that lane's colour at full resolution: crisp edges, no blocky halo.
		float high = smoothstep(0.12, 0.15, v);
		vec3 on_colour = vec3(high, 1.0 - high, 1.0 - high);
		vec3 glow = vec3(0.0);
		for (int k = 0; k < 3; k++) {
			if (pc[k] > 0.3) {
				float wave = 0.5 + 0.5 * sin(rc[k] * 0.6 - TIME * 5.0);
				glow += lc[k] * (0.55 + 0.45 * wave) * on_colour[k];
			}
		}
		col += glow;
	}
	float rim = smoothstep(table_radius - 0.05, table_radius - 0.01, r);
	col = mix(col, rim_color.rgb, rim);
	ALBEDO = col;   // source_color uniforms arrive already linear
}
