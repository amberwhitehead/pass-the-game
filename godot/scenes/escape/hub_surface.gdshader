shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.16, 0.19, 0.21, 1.0);
uniform float metalness = 0.5;
uniform float surface_roughness = 0.46;
uniform float grain_amount = 0.045;
varying vec3 world_position;
varying vec4 instance_tint;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	instance_tint = COLOR;
}

void fragment() {
	// Low-cost metal grain and broad manufacturing variation; no texture uploads.
	float fine = hash31(floor(world_position * 220.0));
	float broad = hash31(floor(world_position * 1.7));
	float brushed = sin(world_position.y * 165.0 + world_position.z * 7.0) * 0.5 + 0.5;
	float variation = (fine - 0.5) * grain_amount + (broad - 0.5) * 0.025;
	ALBEDO = base_color.rgb * instance_tint.rgb * (1.0 + variation);
	METALLIC = metalness;
	ROUGHNESS = clamp(surface_roughness + (fine - 0.5) * 0.07 + (brushed - 0.5) * 0.035, 0.1, 0.95);
}
