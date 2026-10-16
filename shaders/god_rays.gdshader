shader_type canvas_item;
render_mode blend_add;
// Soft crepuscular rays radiating from the moon. Additive.
// Noise is sampled on a circle (cos/sin) so there is no seam where atan() wraps.

uniform vec2 origin = vec2(0.59, 0.39);
uniform vec4 ray_color : source_color = vec4(1.0, 0.5, 0.18, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.28;
uniform float falloff = 1.6;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV - origin;
	p.x *= 1.7778;
	float r = length(p);
	vec2 dir = p / max(r, 0.0001);
	float rays = vnoise(dir * 3.2 + vec2(TIME * 0.05, 0.0)) * 0.6 + vnoise(dir * 8.0 - vec2(0.0, TIME * 0.08)) * 0.4;
	rays = smoothstep(0.35, 0.9, rays);
	float fall = exp(-r * falloff);
	COLOR = vec4(ray_color.rgb, rays * fall * intensity);
}
