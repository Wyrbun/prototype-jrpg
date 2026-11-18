// PS1-style screen: the 3D view drawn at a low resolution (fat pixels) in
// 15-bit colour with the console's 4x4 ordered dither.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D screen_smooth : hint_screen_texture, filter_linear;
// Light filter: each fat pixel blends into its neighbours instead of
// stepping (smoother, still low resolution).
uniform bool smooth_pixels = false;
// Lines on screen, top to bottom.
uniform float lines = 360.0;
// Levels per colour channel (32 = the PS1's 5 bits; a bit finer here).
uniform float levels = 48.0;
uniform float dither_strength = 0.6;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 screen_px = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 res = vec2(floor(lines * screen_px.x / screen_px.y), lines);
	vec2 cell = floor(SCREEN_UV * res);
	vec3 c = smooth_pixels ? texture(screen_smooth, SCREEN_UV).rgb : texture(screen, (cell + 0.5) / res).rgb;
	if (smooth_pixels) {
		// soften to the low resolution: average the cell's corners
		vec2 half_cell = 0.5 / res;
		c = 0.25 * (texture(screen_smooth, SCREEN_UV + vec2(-half_cell.x, -half_cell.y)).rgb
				+ texture(screen_smooth, SCREEN_UV + vec2(half_cell.x, -half_cell.y)).rgb
				+ texture(screen_smooth, SCREEN_UV + vec2(-half_cell.x, half_cell.y)).rgb
				+ texture(screen_smooth, SCREEN_UV + vec2(half_cell.x, half_cell.y)).rgb);
	}
	int i = int(mod(cell.y, 4.0)) * 4 + int(mod(cell.x, 4.0));
	c += (BAYER[i] / 16.0 - 0.5) * dither_strength / levels;
	c = floor(clamp(c, 0.0, 1.0) * (levels - 1.0) + 0.5) / (levels - 1.0);
	COLOR = vec4(c, 1.0);
}
