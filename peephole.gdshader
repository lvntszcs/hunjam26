shader_type canvas_item;

uniform float radius = 0.35;
uniform float softness = 0.05;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float d = length(uv);
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(radius, radius + softness, d));
}