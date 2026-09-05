shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec4 base_color : source_color = vec4(1.0);
uniform float bands : hint_range(2.0, 4.0, 1.0) = 3.0;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.08;
uniform float rim_strength : hint_range(0.0, 0.4) = 0.10;
uniform float flash_mix : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = mix(base_color.rgb, vec3(1.0), flash_mix);
	ROUGHNESS = 0.82;
	METALLIC = 0.0;
	SPECULAR = specular_strength;
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0) * rim_strength;
	EMISSION = base_color.rgb * rim;
}

void light() {
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	float stepped = floor(ndl * bands) / max(bands - 1.0, 1.0);
	stepped = mix(0.32, 1.0, stepped);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * stepped * ATTENUATION;
	float hard_spec = step(0.82, dot(NORMAL, normalize(LIGHT + VIEW))) * specular_strength;
	SPECULAR_LIGHT += LIGHT_COLOR * hard_spec * ATTENUATION;
}
