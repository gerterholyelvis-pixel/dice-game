shader_type spatial;
// Procedural dark basalt with faintly glowing fractured veins. World-space, no textures.

uniform vec3 stone_dark : source_color = vec3(0.07, 0.062, 0.07);
uniform vec3 stone_light : source_color = vec3(0.25, 0.215, 0.225);
uniform vec3 crack_glow : source_color = vec3(1.0, 0.33, 0.05);
uniform float crack_scale = 0.5;
uniform float glow_strength = 0.6;
uniform float bump_strength = 0.7;
uniform float altar_radius = 7.6;
uniform float altar_squash = 0.85;

varying vec3 wpos;
varying vec3 wnormal;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	float n = hash21(p);
	return vec2(n, hash21(p + n + 17.3));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(11.3, 5.7);
		a *= 0.5;
	}
	return v;
}

// returns (edge distance F2-F1, cell id hash, F1)
vec3 voronoi(vec2 p) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(ip + g);
			float d = length(g + o - fp);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				id = hash21(ip + g + 3.7);
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec3(f2 - f1, id, f1);
}

float height_at(vec2 p) {
	vec3 v = voronoi(p * crack_scale);
	float bevel = smoothstep(0.0, 0.22, v.x);
	return bevel * 0.7 + vnoise(p * 6.0) * 0.18 + vnoise(p * 17.0) * 0.08 + v.y * 0.1;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wpos.xz;
	if (abs(wnormal.y) < 0.5) {
		p = vec2(wpos.x + wpos.z, wpos.y * 1.5);
	}

	vec3 v = voronoi(p * crack_scale);
	vec3 v2 = voronoi(p * crack_scale * 2.7 + 31.0);
	float large = fbm(p * 0.9);
	float grain = fbm(p * 5.0);

	float tone = clamp(0.35 + large * 0.8 + (v.y - 0.5) * 0.45 + (grain - 0.5) * 0.5, 0.0, 1.0);
	vec3 col = mix(stone_dark, stone_light, tone);
	// grout darkening between slabs and a faint chipped-edge highlight
	float edge = smoothstep(0.0, 0.2, v.x);
	col *= mix(0.45, 1.0, edge);
	col += stone_light * 0.14 * smoothstep(0.2, 0.05, abs(v.x - 0.16));

	// glowing veins: main fractures broken up by noise, plus thin secondary veins
	float frag_mask = smoothstep(0.38, 0.62, fbm(p * 0.8 + 4.0));
	float crack = smoothstep(0.075, 0.0, v.x) * frag_mask;
	float fine = smoothstep(0.045, 0.0, v2.x) * smoothstep(0.5, 0.7, fbm(p * 1.3 + 9.0)) * 0.55;
	float pulse = 0.65 + 0.35 * sin(TIME * 0.7 + v.y * 40.0);
	float veins = (crack + fine) * pulse;
	float halo = smoothstep(0.3, 0.0, v.x) * frag_mask * 0.07 * pulse;

	// darken toward the rim of the altar top
	float r = length(vec2(wpos.x, wpos.z / altar_squash)) / altar_radius;
	col *= 1.0 - smoothstep(0.9, 1.0, r) * 0.6;

	ALBEDO = col;
	ROUGHNESS = mix(0.9, 0.45, smoothstep(0.55, 0.9, grain));
	SPECULAR = 0.35;
	EMISSION = crack_glow * (veins + halo) * glow_strength;

	if (abs(wnormal.y) > 0.5) {
		float e = 0.04;
		float h0 = height_at(p);
		float hx = height_at(p + vec2(e, 0.0));
		float hz = height_at(p + vec2(0.0, e));
		vec2 g = vec2(h0 - hx, h0 - hz) / e * 0.06 * bump_strength;
		NORMAL_MAP = vec3(0.5 + g.x, 0.5 + g.y, 1.0);
		NORMAL_MAP_DEPTH = 1.0;
	}
}
