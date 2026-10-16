shader_type canvas_item;
// Adds procedural reptile scales + a fire-lit flicker to the flat dragon art.
// Lit (reddish) pixels get the flicker and strongest scale relief; shadow stays dark.

uniform float scale_columns = 85.0;
uniform float scale_strength : hint_range(0.0, 1.0) = 0.38;
uniform float flicker_speed = 5.0;
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.22;
uniform vec4 fire_tint : source_color = vec4(1.0, 0.42, 0.08, 1.0);

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 grid = vec2(scale_columns, scale_columns * 0.5625 * 1.35);
	vec2 p = UV * grid;
	float row = floor(p.y);
	p.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;

	// Scale = rounded shield, dark rim at the bottom edge, bright crest at the top.
	float d = length(f * vec2(1.0, 0.9) + vec2(0.0, -0.08));
	float rim = smoothstep(0.30, 0.52, d);
	float crest = smoothstep(0.55, 0.0, length(f - vec2(0.0, 0.28))) * 0.6;
	float variation = 0.85 + 0.3 * hash(cell.x + cell.y * 57.0);

	float lit = clamp(base.r * 1.8 - base.b * 0.5, 0.0, 1.0);
	float body_mask = 1.0 - smoothstep(0.30, 0.65, base.g);
	float relief = (crest * variation - rim * 0.9) * scale_strength * body_mask;

	float t = TIME * flicker_speed;
	float flick = 1.0 + flicker_amount * (0.6 * sin(t) + 0.3 * sin(t * 2.3 + 1.7) + 0.1 * sin(t * 5.1));

	vec3 col = base.rgb;
	col += relief * (0.10 + lit * 0.9) * fire_tint.rgb * 0.5;
	col *= 1.0 - rim * scale_strength * 0.35 * (1.0 - lit * 0.4) * body_mask;
	col = mix(col, col * flick + fire_tint.rgb * lit * (flick - 1.0) * 0.25, lit);

	COLOR = vec4(col, base.a);
}
