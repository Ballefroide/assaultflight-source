shader_type canvas_item;
// Full-screen black vignette: transparent in the center, darkening toward the
// edges. The `intensity` uniform drives how dark the edges get (0 = invisible).

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float d = length(p);
	float vig = clamp(d, 0.0, 1.0);
	// Cube falloff keeps the center clear while the corners darken quickly.
	vig = pow(vig, 3.0);
	COLOR = vec4(0.0, 0.0, 0.0, vig * intensity);
}
