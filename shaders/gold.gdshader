shader_type spatial;
// Gold coins / treasure: per-instance tint, glints, warm fresnel. Works on MultiMesh or a single mesh.

uniform vec3 gold : source_color = vec3(1.0, 0.76, 0.28);
uniform float brightness = 1.0;
uniform float sparkle_strength = 1.2;

varying float seed;

void vertex() {
	seed = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
}

void fragment() {
	float tint = 0.8 + seed * 0.4;
	vec3 base = gold * tint * brightness;
	float t = TIME * (1.2 + seed * 2.5) + seed * 60.0;
	float glint = pow(max(0.0, sin(t)), 30.0) * sparkle_strength;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = base;
	METALLIC = 0.55;
	ROUGHNESS = 0.34;
	SPECULAR = 0.7;
	EMISSION = base * (0.10 + fres * 0.45) + vec3(1.0, 0.85, 0.5) * glint * brightness;
}
