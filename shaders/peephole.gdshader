shader_type canvas_item;
// Peephole lens: a bodycam-style (barrel) wide-angle distortion inside a round
// opening, black outside it. Reads whatever the Peephole layer drew before
// this Mask node.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

// Lens radius, as a fraction of the screen height.
uniform float radius = 0.35;
uniform float softness = 0.05;
// Barrel strength: the centre stays 1:1 and sharp, the rim bends and looks
// further out (0 = flat, 0.8 = the rim shows 1.8x as far).
uniform float strength : hint_range(0.0, 3.0) = 0.4;
// Darkening towards the rim of the lens.
uniform float vignette : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	// Circle space: centred, measured in screen heights so the lens stays round.
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 p = (UV - vec2(0.5)) * aspect;
	float d = length(p);

	// 0 at the centre, 1 at the rim of the lens.
	float r = clamp(d / radius, 0.0, 1.0);
	// Barrel mapping: scale 1 at the centre (no blur), growing towards the rim
	// so the edges are pulled in from further out.
	vec2 src = p * (1.0 + strength * r * r);

	vec2 src_uv = clamp(vec2(0.5) + src / aspect, vec2(0.0), vec2(1.0));
	// Same full-screen rect, so shift SCREEN_UV by the UV offset.
	vec3 col = texture(screen_tex, SCREEN_UV + (src_uv - UV)).rgb;

	col *= 1.0 - vignette * r * r;
	float outside = smoothstep(radius, radius + softness, d);
	COLOR = vec4(mix(col, vec3(0.0), outside), 1.0);
}
