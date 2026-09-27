// 1인칭 총구 섬광. viewmodel.gdshader와 같은 투영·깊이 규칙에 가산 혼합을 쓴다.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.45, 1.0);
uniform float intensity = 1.0;
uniform float viewmodel_fov = 55.0;

void vertex() {
	float f = 1.0 / tan(radians(viewmodel_fov) * 0.5);
	mat4 proj = PROJECTION_MATRIX;
	float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
	proj[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
	proj[0][0] = f / aspect * sign(PROJECTION_MATRIX[0][0]);
	POSITION = proj * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	POSITION.z = mix(POSITION.w, POSITION.z, 0.02);
}

void fragment() {
	// 가장자리로 갈수록 흐려지는 원형 섬광
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = clamp(1.0 - d, 0.0, 1.0);
	ALBEDO = color.rgb * a * a * intensity;
}
