shader_type spatial;
// First pass of the focus outline: marks every pixel the targeted object covers in the
// stencil buffer (value 1) and draws nothing. The outline pass (focus_outline.gdshader,
// this material's next pass) then only draws where that mark is absent, so the white rim
// traces the object's outer silhouette rather than the edges of each of its parts.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
stencil_mode write, compare_always, 1;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
