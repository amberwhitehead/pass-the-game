shader_type spatial;
// Pulsing emissive crystal with fresnel rim; used for interactables.

uniform vec4 color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float pulse_speed = 2.0;
uniform float highlight : hint_range(0.0, 1.0) = 0.0;  // raised when player is near

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float pulse = 0.6 + 0.4 * sin(TIME * pulse_speed);
	ALBEDO = color.rgb * 0.5;
	EMISSION = color.rgb * (pulse * 0.6 + fres * 1.5 + highlight * 1.2);
	ROUGHNESS = 0.15;
	METALLIC = 0.3;
}
