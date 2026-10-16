shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Glowing rune ring + play-area border, drawn on a flat plane just above the altar top.

uniform vec3 rune_color : source_color = vec3(1.0, 0.42, 0.08);
uniform vec3 flash_color : source_color = vec3(1.0, 0.15, 0.03);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float intensity = 0.7;
uniform float plane_size = 18.0;
uniform vec2 arena_half = vec2(4.4, 2.7);
uniform float squash = 0.85;
uniform float ring_inner = 5.7;
uniform float ring_outer = 6.6;
uniform float cells = 36.0;

float hash11(float n) {
	return fract(sin(n * 127.1 + 31.7) * 43758.5453);
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / (dot(ba, ba) + 0.0001), 0.0, 1.0);
	return length(pa - ba * h);
}

float glyph(vec2 q, float id) {
	vec2 p = q * 2.0 - 1.0;
	float d = 10.0;
	if (hash11(id * 1.7) > 0.45) {
		d = min(d, seg(p, vec2(0.0, -0.75), vec2(0.0, 0.75)));
	} else {
		d = min(d, seg(p, vec2(-0.7, 0.0), vec2(0.7, 0.0)));
	}
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		vec2 a = (floor(vec2(hash11(id * 3.3 + fk * 5.1), hash11(id * 7.7 + fk * 2.3)) * 3.0) - 1.0) * 0.7;
		vec2 b = (floor(vec2(hash11(id * 5.9 + fk * 1.9), hash11(id * 9.1 + fk * 4.7)) * 3.0) - 1.0) * 0.7;
		d = min(d, seg(p, a, b));
	}
	if (hash11(id * 11.3) > 0.6) {
		d = min(d, length(p - vec2(0.0, 0.9 * (hash11(id) - 0.5) * 2.0)) - 0.02);
	}
	return d;
}

float line(float d, float w) {
	return smoothstep(w, w * 0.25, d) + smoothstep(w * 6.0, 0.0, d) * 0.18;
}

void fragment() {
	vec2 p = (UV - 0.5) * plane_size;
	vec2 pe = vec2(p.x, p.y / squash);
	float r = length(pe);
	float ang = atan(pe.y, pe.x);
	float a01 = ang / TAU + 0.5;

	float breathe = 0.78 + 0.22 * sin(TIME * 0.9);
	float wave = 0.55 + 0.45 * sin(ang * 3.0 - TIME * 0.8);

	float v = 0.0;
	// glyph band
	if (r > ring_inner && r < ring_outer) {
		float u = a01 * cells;
		float cid = floor(u);
		vec2 q = vec2(fract(u), (r - ring_inner) / (ring_outer - ring_inner));
		float inside = step(0.1, q.x) * step(q.x, 0.9) * step(0.12, q.y) * step(q.y, 0.88);
		vec2 qq = (q - 0.5) / 0.8 + 0.5;
		float g = line(glyph(qq, cid + 1.0), 0.07) * inside;
		float on = smoothstep(0.15, 0.6, hash11(cid * 2.9 + floor(TIME * 0.12 + cid)) * 0.5 + 0.5 * wave);
		v += g * (0.55 + 0.7 * on);
	}
	// rings
	v += line(abs(r - ring_inner + 0.08), 0.022) * 0.8;
	v += line(abs(r - ring_outer - 0.08), 0.022) * 0.8;
	float dashes = step(0.5, fract(a01 * cells * 1.5));
	v += line(abs(r - (ring_outer + 0.32)), 0.03) * dashes * 0.7;
	v += line(abs(r - (ring_inner - 0.38)), 0.015) * 0.5;

	// play-area border (just inside the curb)
	vec2 q2 = abs(p) - (arena_half - vec2(0.12));
	float rd = length(max(q2, 0.0)) + min(max(q2.x, q2.y), 0.0);
	v += line(abs(rd), 0.022) * 0.55 * (0.7 + 0.3 * wave);
	float corner = step(abs(q2.x), 0.5) * step(abs(q2.y), 0.5);
	v += line(abs(rd + 0.14), 0.02) * 0.4 * corner;

	// very faint inner sigil under the dice
	v += line(abs(length(vec2(p.x, p.y / 0.9)) - 2.05), 0.014) * 0.12;
	v += line(abs(length(vec2(p.x, p.y / 0.9)) - 2.2), 0.01) * 0.08;

	float edge = 1.0 - smoothstep(plane_size * 0.46, plane_size * 0.5, max(abs(p.x), abs(p.y)));
	vec3 col = mix(rune_color, flash_color, flash);
	float e = intensity * breathe * (1.0 + flash * 2.2);
	ALBEDO = col * v * e * edge;
	ALPHA = 1.0;
}
