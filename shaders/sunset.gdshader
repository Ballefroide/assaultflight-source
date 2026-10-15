shader_type canvas_item;
// Sunset time-of-day grade: slightly darkens the world and pushes it toward
// warm orange/red tones (evening feel). Reads the already-rendered screen.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// How much to darken the scene (0 = unchanged, 1 = black).
uniform float darkness : hint_range(0.0, 1.0) = 0.2;
// Per-channel color boost. Red raised, blue dropped -> orange/red warmth.
uniform vec3 tint : source_color = vec3(1.15, 0.75, 0.5);

void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	c *= (1.0 - darkness);
	c *= tint;
	COLOR = vec4(c, 1.0);
}
