shader_type spatial;
render_mode depth_prepass_alpha, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.28, 0.62, 0.78, 1.0);

void fragment() {
	float edge = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	float internal_facet = 0.5 + 0.5 * sin(UV.x * 13.0 + UV.y * 8.0);
	ALBEDO = mix(tint.rgb * (0.61 + internal_facet * 0.12), vec3(0.78, 0.92, 0.98), edge * 0.76);
	METALLIC = 0.12;
	ROUGHNESS = 0.13;
	SPECULAR = 0.9;
	CLEARCOAT = 0.7;
	CLEARCOAT_ROUGHNESS = 0.2;
	EMISSION = tint.rgb * 0.12 + edge * tint.rgb * 0.16;
	ALPHA = 0.72 + edge * 0.25;
	RIM = 0.35;
	RIM_TINT = 0.25;
}
