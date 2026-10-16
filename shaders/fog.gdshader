shader_type canvas_item;
// Procedural drifting fog band (domain-warped fbm). No textures needed.

uniform vec4 fog_color : source_color = vec4(0.55, 0.2, 0.1, 1.0);
uniform float density : hint_range(0.0, 2.0) = 0.6;
uniform float noise_scale = 3.0;
uniform vec2 drift = vec2(0.02, 0.0);
uniform float height_center : hint_range(0.0, 1.0) = 0.85;
uniform float height_spread : hint_range(0.05, 1.0) = 0.25;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	uv.x *= 1.7778;
	vec2 p = uv * noise_scale + drift * TIME;
	float n = fbm(p + fbm(p * 0.7 + TIME * 0.01) * 1.5);
	float dy = (UV.y - height_center) / height_spread;
	float band = exp(-dy * dy);
	float a = smoothstep(0.35, 0.85, n) * band * density;
	COLOR = vec4(fog_color.rgb, clamp(a, 0.0, 1.0));
}
