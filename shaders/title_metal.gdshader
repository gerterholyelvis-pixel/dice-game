shader_type canvas_item;
// Forged-gold gradient plus a slow light sweep for the title Label.
// Only bright (fill) pixels are recoloured, so the dark outline stays intact.

uniform vec4 top_color : source_color = vec4(1.0, 0.96, 0.8, 1.0);
uniform vec4 mid_color : source_color = vec4(0.93, 0.74, 0.38, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.62, 0.3, 0.1, 1.0);
uniform vec2 label_size = vec2(860.0, 180.0);
uniform float sweep_period = 6.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	float fill = smoothstep(0.35, 0.6, lum);

	vec2 n = local_pos / label_size;
	float y = clamp(n.y * 1.1, 0.0, 1.0);
	vec3 grad = y < 0.5 ? mix(top_color.rgb, mid_color.rgb, y * 2.0) : mix(mid_color.rgb, bottom_color.rgb, (y - 0.5) * 2.0);

	float t = fract(TIME / sweep_period);
	float sweep_x = mix(-0.3, 1.3, t);
	float band = smoothstep(0.12, 0.0, abs(n.x + n.y * 0.25 - sweep_x));
	grad += band * 0.45;

	vec3 col = mix(base.rgb, grad, fill);
	COLOR = vec4(col, base.a);
}
