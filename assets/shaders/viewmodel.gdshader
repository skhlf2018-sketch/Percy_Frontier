// 1인칭 무기 모델 전용 셰이더.
// - 플레이어 FOV 설정과 무관하게 고정 시야각으로 그려 모델 모양이 늘어나지 않게 한다.
// - 깊이를 가까운 평면 쪽으로 압축해 무기가 벽을 뚫고 보이지 않게 한다(기획서 §23.4).
//   Godot 4.3+는 모든 렌더러에서 역 Z 깊이(가까울수록 1.0)를 쓴다. Forward+와 호환 렌더러에서 검증했다.
shader_type spatial;
render_mode cull_back, shadows_disabled;

uniform vec4 albedo : source_color = vec4(0.4, 0.42, 0.45, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.55;
uniform float metallic : hint_range(0.0, 1.0) = 0.3;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// 1인칭 모델 전용 세로 시야각(도)
uniform float viewmodel_fov = 55.0;

void vertex() {
	float f = 1.0 / tan(radians(viewmodel_fov) * 0.5);
	mat4 proj = PROJECTION_MATRIX;
	float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
	// Vulkan 투영 행렬은 축 부호가 뒤집혀 있을 수 있으므로 부호를 보존한다.
	proj[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
	proj[0][0] = f / aspect * sign(PROJECTION_MATRIX[0][0]);
	POSITION = proj * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	POSITION.z = mix(POSITION.w, POSITION.z, 0.02);
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission.rgb * emission_energy;
}
