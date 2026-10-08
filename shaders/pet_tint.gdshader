shader_type canvas_item;

// Recolors a pet's art by remapping each pixel's brightness onto a
// shadow->highlight colour ramp, so one set of frames can be any coat colour
// (Noodles is the orange kitten art run through a brown ramp). Outlines and
// eyes stay dark because they sit at the bottom of the ramp.
uniform vec3 shadow_color : source_color = vec3(0.10, 0.06, 0.04);
uniform vec3 highlight_color : source_color = vec3(0.74, 0.50, 0.30);

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float t = smoothstep(0.08, 0.85, lum);
	COLOR = vec4(mix(shadow_color, highlight_color, t), col.a);
}
