shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never;
// Looming dragon backdrop: darkened art that keeps its fire-lit rim, plus a flare uniform.

uniform sampler2D art : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 body_tint : source_color = vec3(0.2, 0.11, 0.14);
uniform vec3 rim_color : source_color = vec3(1.0, 0.4, 0.1);
uniform float rim_boost = 0.45;
uniform float flare : hint_range(0.0, 1.0) = 0.0;
uniform float fade_bottom = 0.18;

void fragment() {
	vec4 c = texture(art, UV);
	float lit = clamp(c.r * 1.8 - c.b * 0.5, 0.0, 1.0);
	float flick = 0.85 + 0.15 * sin(TIME * 3.1) * sin(TIME * 1.7 + 1.0);
	vec3 col = c.rgb * body_tint + lit * lit * rim_color * rim_boost * flick;
	col += rim_color * flare * lit * 0.6;
	float fb = smoothstep(0.0, fade_bottom, 1.0 - UV.y);
	ALBEDO = col;
	ALPHA = c.a * fb;
}
