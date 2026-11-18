// PS1-style surface: vertices snap to a coarse screen grid (the wobble),
// lighting per vertex (Gouraud), textures mapped affine (they warp at an
// angle) and sampled without filtering. Flat colour if no texture is set.
shader_type spatial;
render_mode vertex_lighting, specular_disabled, cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_nearest, hint_default_white;
// Lines of the snapping grid, top to bottom (the PS1 drew at 240; a
// little finer here, so the wobble is gentler). 0: no snapping (the screen
// filter's Off).
uniform float snap_lines = 320.0;

varying vec3 affine_uv;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = vec2(snap_lines * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap_lines) * 0.5;
	if (snap_lines > 0.0) {
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = affine_uv.xy / affine_uv.z;
	vec4 c = albedo * texture(tex, uv);
	ALBEDO = c.rgb;
}
