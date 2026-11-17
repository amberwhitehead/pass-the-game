shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Object-space detail stays fixed on the furniture and uses no animated noise.
uniform vec4 base_color : source_color = vec4(0.12, 0.22, 0.19, 1.0);
uniform vec4 grain_color : source_color = vec4(0.24, 0.13, 0.065, 1.0);
uniform float finish_roughness = 0.86;
uniform bool wood = false;
varying vec3 local_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 p = local_position.xz;
	if (wood) {
		float warp = noise(p * vec2(0.7, 2.4));
		float grain = sin(p.y * 96.0 + warp * 12.0 + sin(p.x * 1.4) * 1.5);
		float fine = sin(p.y * 260.0 + warp * 22.0);
		float grain_filter = 1.0 - smoothstep(0.6, 2.0, fwidth(p.y * 96.0));
		float fine_filter = 1.0 - smoothstep(0.5, 1.5, fwidth(p.y * 260.0));
		float tone = clamp(0.48 + grain * grain_filter * 0.18 + fine * fine_filter * 0.035 + warp * 0.16, 0.0, 1.0);
		ALBEDO = mix(base_color.rgb, grain_color.rgb, tone);
		ROUGHNESS = finish_roughness + (1.0 - tone) * 0.1;
	} else {
		float nap = noise(p * 125.0);
		float weave = sin(p.x * 900.0) * sin(p.y * 900.0);
		float filter_width = max(fwidth(p.x * 900.0), fwidth(p.y * 900.0));
		float weave_filter = 1.0 - smoothstep(0.4, 1.6, filter_width);
		ALBEDO = base_color.rgb * (0.94 + nap * 0.12 + weave * weave_filter * 0.025);
		ROUGHNESS = finish_roughness;
	}
	METALLIC = 0.0;
}
