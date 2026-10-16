shader_type canvas_item;
// Warps whatever is already drawn underneath, strongest at `center` (rect UV), to fake heat shimmer.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 0.03) = 0.006;
uniform float speed = 1.6;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec2 radius = vec2(0.5, 0.5);

void fragment() {
	vec2 d = (UV - center) / radius;
	float mask = smoothstep(1.0, 0.0, length(d));
	float t = TIME * speed;
	vec2 off = vec2(
		sin(UV.y * 40.0 + t * 3.0) + sin(UV.y * 17.0 - t * 2.1),
		cos(UV.x * 30.0 + t * 2.5) * 0.6 + sin((UV.x + UV.y) * 23.0 + t)
	) * strength * mask;
	COLOR = vec4(texture(screen_tex, SCREEN_UV + off).rgb, mask);
}
