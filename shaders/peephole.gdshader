shader_type canvas_item;
// Peephole lens: a bodycam-style (barrel) wide-angle distortion inside a round
// opening, black outside it. Reads whatever the Peephole layer drew before
// this Mask node.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

// Lens radius, as a fraction of the screen height.
uniform float radius = 0.35;
uniform float softness = 0.05;
// Colour around the lens (outside the round opening). Default: #551822.
uniform vec4 outside_color : source_color = vec4(0.333, 0.094, 0.133, 1.0);
// Barrel strength: the centre stays 1:1 and sharp, the rim bends and looks
// further out (0 = flat, 0.8 = the rim shows 1.8x as far).
uniform float strength : hint_range(0.0, 3.0) = 0.4;
// How the bending grows from centre to rim: 2 = smooth (default), 1 = starts
// right away, higher = flat centre with a sharp bend near the rim.
uniform float curve : hint_range(0.5, 6.0) = 2.0;
// Magnification at the centre (1 = 1:1, >1 = zoomed in, <1 = zoomed out).
uniform float zoom : hint_range(0.25, 4.0) = 1.0;
// Darkening towards the rim of the lens.
uniform float vignette : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	// Circle space: centred, measured in screen heights so the lens stays round.
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 p = (UV - vec2(0.5)) * aspect;
	float d = length(p);

	// 0 at the centre, 1 at the rim of the lens.
	float r = clamp(d / radius, 0.0, 1.0);
	// Barrel mapping: scale 1/zoom at the centre, growing towards the rim so
	// the edges are pulled in from further out.
	vec2 src = p * (1.0 + strength * pow(r, curve)) / zoom;

	vec2 src_uv = clamp(vec2(0.5) + src / aspect, vec2(0.0), vec2(1.0));
	// Same full-screen rect, so shift SCREEN_UV by the UV offset.
	vec3 col = texture(screen_tex, SCREEN_UV + (src_uv - UV)).rgb;

	col *= 1.0 - vignette * r * r;
	float outside = smoothstep(radius, radius + softness, d);
	COLOR = vec4(mix(col, outside_color.rgb, outside), 1.0);
}
