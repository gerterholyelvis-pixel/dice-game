shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never;
// Drifting low mist sheet; transparent hole in the middle keeps the play area clear.

uniform vec3 fog_color : source_color = vec3(0.32, 0.12, 0.14);
uniform float density : hint_range(0.0, 2.0) = 0.5;
uniform float noise_scale = 0.12;
uniform vec2 drift = vec2(0.02, 0.006);
uniform float plane_size = 40.0;
uniform vec2 hole_half = vec2(0.0, 0.0);
uniform float hole_soft = 3.0;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = (UV - 0.5) * plane_size;
	vec2 q = p * noise_scale + drift * TIME;
	float n = fbm(q + fbm(q * 0.7 + TIME * 0.01) * 1.4);
	float edge = 1.0 - smoothstep(0.38, 0.5, max(abs(UV.x - 0.5), abs(UV.y - 0.5)));
	vec2 hq = abs(p) - hole_half;
	float hd = length(max(hq, 0.0));
	float hole = smoothstep(0.0, hole_soft, hd);
	float a = smoothstep(0.38, 0.85, n) * density * edge * hole;
	ALBEDO = fog_color;
	ALPHA = clamp(a, 0.0, 1.0);
}
