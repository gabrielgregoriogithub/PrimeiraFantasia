shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform float outline_width : hint_range(0.001, 0.03) = 0.008;
uniform vec4 outline_color : source_color = vec4(0.015, 0.02, 0.035, 0.9);

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
