shader_type canvas_item;
// Sunrise time-of-day grade: slightly darkens the world and nudges it toward a
// cool, blueish cast (early-morning feel). Reads the already-rendered screen.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// How much to darken the scene (0 = unchanged, 1 = black).
uniform float darkness : hint_range(0.0, 1.0) = 0.25;
// Per-channel color boost. Blue raised above red/green gives the blue cast.
uniform vec3 tint : source_color = vec3(0.9, 0.9, 1.12);

void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	c *= (1.0 - darkness);
	c *= tint;
	COLOR = vec4(c, 1.0);
}
