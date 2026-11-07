// Full-screen post-process for the pixel art: a hand-drawn "boil" (the image
// wobbles by whole art pixels a few times per second) plus randomized grain.
// Put it on a ColorRect that covers the screen, on a CanvasLayer above the art.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;

group_uniforms wobble;
/// Max shift, in art pixels. 1 keeps it subtle.
uniform float wobble_pixels : hint_range(0.0, 4.0, 1.0) = 1.0;
/// Size of the areas that move together, in art pixels. Bigger = calmer.
uniform float wobble_scale : hint_range(4.0, 128.0, 1.0) = 24.0;
/// How many times per second the wobble changes. Low values feel hand-drawn.
uniform float wobble_rate : hint_range(1.0, 30.0, 1.0) = 6.0;

group_uniforms grain;
/// Brightness of the grain. 0 turns it off.
uniform float grain_strength : hint_range(0.0, 0.5, 0.005) = 0.08;
/// Grain speck size, in art pixels.
uniform float grain_size : hint_range(1.0, 8.0, 1.0) = 1.0;
/// How many times per second the grain pattern is re-rolled.
uniform float grain_rate : hint_range(1.0, 60.0, 1.0) = 12.0;

group_uniforms;
/// Height the art is drawn for (project viewport height). Used to convert
/// art pixels to screen pixels when the window is scaled.
uniform float design_height = 720.0;

// Hash without sine (Dave Hoskins): stable across GPUs, in [0, 1).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Smooth value noise in [0, 1).
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
			mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
			f.y);
}

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float art_pixel = screen_size.y / design_height;  // screen pixels per art pixel
	vec2 art_coord = SCREEN_UV * screen_size / art_pixel;

	// Wobble: a smooth random offset field, re-rolled wobble_rate times per
	// second and rounded to whole art pixels so the pixel art stays crisp.
	float wobble_step = floor(TIME * wobble_rate);
	vec2 noise_pos = art_coord / wobble_scale + wobble_step * vec2(7.31, 3.17);
	vec2 offset = vec2(
			value_noise(noise_pos),
			value_noise(noise_pos + vec2(41.7, 19.3))) * 2.0 - 1.0;
	offset = round(offset * wobble_pixels);
	vec2 uv = SCREEN_UV + offset * art_pixel * SCREEN_PIXEL_SIZE;
	vec3 color = texture(screen_tex, uv).rgb;

	// Grain: per-speck random brightness, re-rolled grain_rate times per second.
	float grain_step = floor(TIME * grain_rate);
	float grain = hash(floor(art_coord / grain_size) + grain_step * vec2(13.7, 5.9)) - 0.5;
	color = clamp(color + grain * grain_strength, 0.0, 1.0);

	COLOR = vec4(color, 1.0);
}
