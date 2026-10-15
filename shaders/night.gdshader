shader_type canvas_item;
// Night time-of-day grade: strongly darkens the world and tints it with deep
// blue shades (night feel). Reads the already-rendered screen.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// How much to darken the scene (0 = unchanged, 1 = black).
uniform float darkness : hint_range(0.0, 1.0) = 0.5;
// Per-channel color boost. Strong blue keeps the dark scene in blue shades.
uniform vec3 tint : source_color = vec3(0.55, 0.6, 1.0);

void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	c *= (1.0 - darkness);
	c *= tint;
	COLOR = vec4(c, 1.0);
}
