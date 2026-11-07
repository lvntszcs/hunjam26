shader_type canvas_item;
// Pixel dissolve transition overlay. Every (design) pixel gets its own random
// moment within the transition: as [progress] goes 0 -> 1 the pixels switch to
// [cover_color] one by one in a random pattern; going back 1 -> 0 they switch
// back to whatever is underneath (with a new [seed], so a new pattern).

// 0 = fully see-through, 1 = every pixel shows cover_color.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Each pixel's own fade length, as a fraction of the transition:
// 0 = hard flip, 1 = every pixel fades across the whole transition.
uniform float softness : hint_range(0.0, 1.0) = 0.0;
// Default: #551822.
uniform vec4 cover_color : source_color = vec4(0.333, 0.094, 0.133, 1.0);
// Picks the random pattern.
uniform float seed = 0.0;
// Number of cells (pixels) across and down the overlay.
uniform vec2 grid = vec2(1280.0, 720.0);

// Dave Hoskins' hash: stable, no sin() precision issues on weak GPUs.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 cell = floor(UV * grid);
	float start = hash(cell + vec2(seed * 17.13, seed * 7.31)) * (1.0 - softness);
	float a = clamp((progress - start) / max(softness, 0.0001), 0.0, 1.0);
	COLOR = vec4(cover_color.rgb, a);
}
