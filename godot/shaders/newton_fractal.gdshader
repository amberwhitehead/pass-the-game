shader_type spatial;
render_mode unshaded, cull_back;
// Generalised Newton fractal, drawn on a flat disc (local XZ -> complex plane).
//
//   z <- z - relax * (z^p - 1) / (p * z^(p-1)),     p = exponent (complex)
//
// z^p is evaluated as exp(p * log z) with the principal branch, so non-integer
// or complex p shows the branch cut as seams. Integer p gives the classic
// p-basin picture. Colour: hue = argument of the final z (which root it fell
// to), brightness = how quickly it converged (dark = never converged).

uniform vec2 exponent = vec2(3.0, 0.0);   // p: x = real part, y = imaginary part
uniform float relax = 1.0;                // a: step relaxation (1 = plain Newton)
uniform float view_scale = 1.8;           // complex-plane radius shown at the disc edge
uniform float rotation = 0.0;             // rotates the plane (radians)
uniform vec2 view_center = vec2(0.0);
uniform int max_iter : hint_range(4, 96) = 40;
uniform float tolerance = 0.0005;
uniform float table_radius = 2.2;
uniform vec4 rim_color : source_color = vec4(0.55, 0.75, 1.0, 1.0);

varying vec2 v_pos;

vec2 cmul(vec2 a, vec2 b) {
	return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

vec2 cdiv(vec2 a, vec2 b) {
	return cmul(a, vec2(b.x, -b.y)) / max(dot(b, b), 1e-30);
}

vec2 clog(vec2 z) {
	return vec2(log(max(length(z), 1e-20)), atan(z.y, z.x));
}

vec2 cexp(vec2 z) {
	return exp(clamp(z.x, -40.0, 40.0)) * vec2(cos(z.y), sin(z.y));
}

// Cyan / yellow / magenta triad (sRGB). Keep in sync with NewtonMath.palette().
// Colour wheel position h in [0,1): three keys at 0, 1/3, 2/3, with short blends between
// them so most of each basin reads as one of the three key colours.
// discrete_colors: snap to the nearest key (exactly three colours). Off: continuous rainbow
// of the wheel, which shows each root as its own hue (nice when p has many roots).
uniform bool discrete_colors = true;

vec3 palette(float h) {
	vec3 keys[3] = vec3[3](vec3(0.20, 0.85, 0.95), vec3(1.0, 0.85, 0.25), vec3(0.92, 0.28, 0.72));
	float x = fract(h) * 3.0;
	if (discrete_colors) {
		return keys[int(floor(x + 0.5)) % 3];
	}
	int i = int(floor(x));
	float f = smoothstep(0.3, 0.7, x - float(i));
	return mix(keys[i], keys[(i + 1) % 3], f);
}

void vertex() {
	v_pos = VERTEX.xz;
}

void fragment() {
	float r = length(v_pos);
	vec2 z0 = (v_pos / table_radius) * view_scale;
	float cr = cos(rotation);
	float sr = sin(rotation);
	vec2 z = view_center + vec2(cr * z0.x - sr * z0.y, sr * z0.x + cr * z0.y);
	vec2 pm1 = exponent - vec2(1.0, 0.0);
	float smooth_n = float(max_iter);
	bool converged = false;

	for (int i = 0; i < 96; i++) {
		if (i >= max_iter) break;
		vec2 zp1 = cexp(cmul(pm1, clog(z)));        // z^(p-1)
		vec2 f = cmul(zp1, z) - vec2(1.0, 0.0);     // z^p - 1
		vec2 fp = cmul(exponent, zp1);              // p z^(p-1)
		vec2 dz = relax * cdiv(f, fp);
		z -= dz;
		float m = length(dz);
		if (m < tolerance) {
			// fractional iteration count; error roughly squares each step
			smooth_n = float(i) + 1.0 - log2(max(log(m) / log(tolerance), 1.0));
			converged = true;
			break;
		}
		if (dot(z, z) > 1e8) break;
	}

	float hue = atan(z.y, z.x) / TAU;   // root angle picks the colour (NewtonMath.HUE_OFFSET = 0)
	float shade = exp(-smooth_n * 0.11);
	float v = converged ? 0.3 + 0.7 * shade : 0.06;
	vec3 col = palette(hue) * v;

	// thin bright rim + soft darkening toward the edge
	float rim = smoothstep(table_radius - 0.05, table_radius - 0.01, r);
	col = mix(col, rim_color.rgb, rim);
	if (r > table_radius) discard;

	ALBEDO = pow(col, vec3(2.2));   // authored in sRGB, ALBEDO is linear
}
