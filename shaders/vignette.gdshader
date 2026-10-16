shader_type canvas_item;
// Full-screen darkening toward the edges, plus a faint film grain.

uniform float strength : hint_range(0.0, 1.5) = 0.95;
uniform float radius : hint_range(0.1, 1.5) = 0.62;
uniform float softness : hint_range(0.05, 1.0) = 0.55;
uniform float grain : hint_range(0.0, 0.2) = 0.035;

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= 1.15;
	float d = length(uv);
	float v = smoothstep(radius, radius + softness, d) * strength;
	float n = fract(sin(dot(UV * 1000.0 + TIME, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(v + n * grain, 0.0, 1.0));
}
