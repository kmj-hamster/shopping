shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 glass_tint : source_color = vec4(0.055, 0.075, 0.08, 1.0);
uniform float blur_lod : hint_range(0.0, 5.0, 0.05) = 3.0;
uniform float tint_strength : hint_range(0.0, 1.0, 0.01) = 0.52;
uniform float brightness : hint_range(0.5, 1.5, 0.01) = 0.82;
uniform float distortion_px : hint_range(0.0, 4.0, 0.05) = 1.15;
uniform float dispersion_px : hint_range(0.0, 4.0, 0.05) = 0.85;
uniform float corner_radius_px : hint_range(0.0, 48.0, 0.5) = 15.0;
uniform float edge_depth_px : hint_range(1.0, 32.0, 0.5) = 12.0;
uniform vec2 panel_size_px = vec2(700.0, 160.0);


float rounded_box_distance(vec2 point, vec2 half_size, float radius) {
	vec2 q = abs(point) - half_size + vec2(radius);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}


void fragment() {
	vec2 safe_size = max(panel_size_px, vec2(2.0));
	float radius = min(corner_radius_px, min(safe_size.x, safe_size.y) * 0.5 - 1.0);
	vec2 half_size = safe_size * 0.5 - vec2(1.0);
	vec2 point = (UV - vec2(0.5)) * safe_size;
	float distance_to_glass = rounded_box_distance(point, half_size, radius);
	float antialias_width = max(fwidth(distance_to_glass), 0.75);
	float glass_mask = 1.0 - smoothstep(-antialias_width, antialias_width, distance_to_glass);

	float left = rounded_box_distance(point - vec2(1.0, 0.0), half_size, radius);
	float right = rounded_box_distance(point + vec2(1.0, 0.0), half_size, radius);
	float up = rounded_box_distance(point - vec2(0.0, 1.0), half_size, radius);
	float down = rounded_box_distance(point + vec2(0.0, 1.0), half_size, radius);
	vec2 gradient = vec2(right - left, down - up);
	vec2 edge_normal = gradient / max(length(gradient), 0.0001);
	float inside_depth = max(-distance_to_glass, 0.0);
	float edge_factor = 1.0 - smoothstep(1.0, edge_depth_px, inside_depth);

	vec2 soft_warp = vec2(
		sin(UV.y * 19.0 + UV.x * 7.0),
		cos(UV.x * 17.0 - UV.y * 5.0)
	) * 0.16;
	vec2 refraction_direction = edge_normal * edge_factor + soft_warp * (1.0 - edge_factor);
	vec2 warped_uv = clamp(
		SCREEN_UV + refraction_direction * distortion_px * SCREEN_PIXEL_SIZE,
		SCREEN_PIXEL_SIZE,
		vec2(1.0) - SCREEN_PIXEL_SIZE
	);
	float sampled_lod = max(blur_lod - edge_factor * 0.65, 0.0);
	vec3 center_sample = textureLod(screen_texture, warped_uv, sampled_lod).rgb;
	vec2 chroma_offset = edge_normal * dispersion_px * edge_factor * SCREEN_PIXEL_SIZE;
	vec3 dispersed_sample = vec3(
		textureLod(screen_texture, warped_uv + chroma_offset, sampled_lod).r,
		center_sample.g,
		textureLod(screen_texture, warped_uv - chroma_offset, sampled_lod).b
	);

	vec3 glass_color = mix(dispersed_sample * brightness, glass_tint.rgb, tint_strength);
	vec2 light_direction = normalize(vec2(-0.62, -0.78));
	float directional_depth = dot(edge_normal, light_direction);
	glass_color += max(directional_depth, 0.0) * edge_factor * 0.10;
	glass_color -= max(-directional_depth, 0.0) * edge_factor * 0.055;
	COLOR = vec4(glass_color, glass_mask);
}
