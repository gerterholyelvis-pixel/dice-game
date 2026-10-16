shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Carved bone die with ember-filled pip sockets. Compatibility-safe.

uniform vec4 faces_a = vec4(1.0, 2.0, 3.0, 4.0);
uniform vec2 faces_b = vec2(5.0, 6.0);
uniform vec4 body_color : source_color = vec4(0.93, 0.85, 0.68, 1.0);
uniform vec4 edge_color : source_color = vec4(0.42, 0.3, 0.18, 1.0);
uniform vec4 pip_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float pip_heat : hint_range(0.0, 1.0) = 0.0;

const float PIP_R = 0.085;
const float SPACING = 0.25;

varying vec3 v_obj_pos;
varying float v_face;

float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x),
			mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x),
			mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		s += a * vnoise(p);
		p = p * 2.03 + 11.7;
		a *= 0.5;
	}
	return s;
}

int pip_mask(int n) {
	if (n == 1) return 16;     // centre
	if (n == 2) return 257;    // two opposite corners
	if (n == 3) return 273;    // diagonal
	if (n == 4) return 325;    // four corners
	if (n == 5) return 341;    // four + centre
	if (n == 6) return 365;    // two columns of three
	return 0;
}

void vertex() {
	v_obj_pos = VERTEX;
	v_face = COLOR.r * 8.0;
}

void fragment() {
	int fi = int(floor(v_face + 0.5));
	float cnt = 0.0;
	if (fi == 0) cnt = faces_a.x;
	else if (fi == 1) cnt = faces_a.y;
	else if (fi == 2) cnt = faces_a.z;
	else if (fi == 3) cnt = faces_a.w;
	else if (fi == 4) cnt = faces_b.x;
	else cnt = faces_b.y;
	int mask = pip_mask(int(floor(cnt + 0.5)));

	// nearest pip (distance in face uv, and direction to its centre)
	vec2 uv = UV;
	float pd = 10.0;
	vec2 to_c = vec2(0.0);
	for (int k = 0; k < 9; k++) {
		if (((mask >> k) & 1) == 1) {
			vec2 c = vec2(0.5) + vec2(float(k % 3 - 1), float(k / 3 - 1)) * SPACING;
			vec2 d = uv - c;
			float l = length(d);
			if (l < pd) {
				pd = l;
				to_c = -d;
			}
		}
	}
	float inside = 1.0 - smoothstep(PIP_R - 0.006, PIP_R + 0.004, pd);
	float core = 1.0 - smoothstep(PIP_R * 0.15, PIP_R * 0.68, pd);
	float hot = 1.0 - smoothstep(0.0, PIP_R * 0.5, pd);

	// bone material
	vec3 op = v_obj_pos;
	float grain = fbm(op * 9.0 + vec3(3.1, 1.7, 5.3));
	float mott = fbm(op * 3.0 + vec3(7.0));
	float fibre = vnoise(vec3(op.x * 3.0, op.y * 40.0, op.z * 3.0) + vec3(op.z * 30.0, 0.0, op.x * 30.0));
	vec3 bone = body_color.rgb * vec3(0.96, 0.95, 0.97);
	bone *= mix(0.88, 1.06, grain);
	bone = mix(bone, bone * vec3(0.92, 0.84, 0.72), smoothstep(0.4, 0.75, mott) * 0.35);
	bone *= mix(0.94, 1.04, fibre);

	// edge wear: 0 on flats, ->1 at the crest of the rounded edge
	vec3 q = max(abs(op) - vec3(0.39), vec3(0.0));
	float ed = clamp(length(q) / 0.11, 0.0, 1.0);
	float wear = smoothstep(0.35, 1.0, ed) * mix(0.55, 1.0, grain);
	bone = mix(bone, edge_color.rgb * mix(0.8, 1.2, grain), wear * 0.9);
	// faint pit scratches
	float pits = smoothstep(0.8, 0.86, vnoise(op * 55.0));
	bone *= 1.0 - pits * 0.12;

	// pip socket: dark carved hole with ember core
	float ring = smoothstep(PIP_R + 0.045, PIP_R, pd) * (1.0 - inside);   // soot halo around the hole
	vec3 albedo = mix(bone, bone * 0.3, ring * 0.85);
	albedo = mix(albedo, vec3(0.02, 0.012, 0.01), inside);
	ALBEDO = albedo;

	// bump at pip rim: wall normal leans towards the pip centre
	float rim = exp(-pow((pd - PIP_R) / 0.012, 2.0));
	vec2 bdir = to_c / max(length(to_c), 0.0001);
	vec3 nrm = NORMAL + (TANGENT * bdir.x - BINORMAL * bdir.y) * rim * 1.1;
	// micro bump from grain
	nrm += (vec3(grain - 0.5, fibre - 0.5, mott - 0.5)) * 0.06;
	NORMAL = normalize(nrm);

	ROUGHNESS = mix(0.5 + 0.18 * (1.0 - grain), 0.9, inside);
	METALLIC = 0.0;
	SPECULAR = 0.55;

	// ember emission
	float flick = 0.88 + 0.12 * sin(TIME * 5.0 + float(fi) * 1.7 + cnt * 0.9);
	vec3 ember = mix(pip_color.rgb, vec3(1.0, 0.9, 0.6), hot * 0.45);
	vec3 emis = ember * inside * (0.35 + core * 1.7 + hot * 0.6) * flick * (1.0 + pip_heat * 2.2);
	emis += pip_color.rgb * ring * 0.12 * (1.0 + pip_heat * 2.0);

	// frozen/selected gold rim
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 gold = vec3(1.0, 0.72, 0.22);
	emis += gold * (fres * 1.8 + 0.12) * glow;
	emis += flash_color.rgb * flash_amount * (0.9 + fres * 1.5);
	EMISSION = emis;
}
