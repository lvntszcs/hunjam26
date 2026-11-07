shader_type canvas_item;
// Peephole lens: a fisheye (barrel) distortion inside a round opening, black
// outside it. Reads whatever the Peephole layer drew before this Mask node.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// Lens radius, as a fraction of the screen height.
uniform float radius = 1.55;
uniform float softness = 0.05;
// How strongly the centre bulges out (0 = flat, no fisheye).
uniform float strength : hint_range(0.0, 3.0) = 0.8;
// How far out the lens edge looks: 1 = only what is under the lens,
// higher = a wider view squeezed into the same circle.
uniform float coverage : hint_range(0.5, 3.0) = 1.6;
// Darkening towards the rim of the lens.
uniform float vignette : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	// Circle space: centred, measured in screen heights so the lens stays round.
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 p = (UV - vec2(0.5)) * aspect;
	float d = length(p);

	// 0 at the centre, 1 at the rim of the lens.
	float r = clamp(d / radius, 0.0, 1.0);
	// Barrel mapping: pixels near the centre sample close to the centre
	// (magnified), pixels near the rim sample far out (compressed).
	float src_dist = radius * coverage * pow(r, 1.0 + strength);
	vec2 src = d > 0.0 ? p / d * src_dist : vec2(0.0);

	vec2 src_uv = clamp(vec2(0.5) + src / aspect, vec2(0.0), vec2(1.0));
	// Same full-screen rect, so shift SCREEN_UV by the UV offset.
	vec3 col = texture(screen_tex, SCREEN_UV + (src_uv - UV)).rgb;

	col *= 1.0 - vignette * r * r;
	float outside = smoothstep(radius, radius + softness, d);
	COLOR = vec4(mix(col, vec3(0.0), outside), 1.0);
}
