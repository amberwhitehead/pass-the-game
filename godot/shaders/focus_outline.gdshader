shader_type spatial;
// A screen-space outline for the thing the player is targeting: pushes each vertex out
// along its normal by a fixed number of pixels and shows only the back faces, so a thin
// rim appears round each part. Drawn after focus_mask.gdshader, and only where that pass
// did not mark the object, so only the rim round the whole object's silhouette remains.
render_mode unshaded, cull_front, shadows_disabled, depth_draw_never;
stencil_mode read, compare_not_equal, 1;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float width_px = 2.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	if (length(dir) > 0.0001) {
		dir = normalize(dir);
	}
	clip.xy += dir * width_px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = color.rgb;
}
