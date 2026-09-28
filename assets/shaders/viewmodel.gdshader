// 1인칭 무기·손 모델 전용 셰이더.
// - 플레이어 FOV 설정과 무관하게 고정 시야각으로 그려 모델 모양이 늘어나지 않게 한다.
// - 깊이를 가까운 평면 쪽으로 압축해 무기가 벽을 뚫고 보이지 않게 한다(기획서 §23.4).
//   Godot 4.3+는 모든 렌더러에서 역 Z 깊이(가까울수록 1.0)를 쓴다. Forward+와 호환 렌더러에서 검증했다.
// - 표면 결(금속의 잔 흠, 수지의 오톨도톨함, 나뭇결, 가죽·천의 결)을 물체 공간 삼면 투영 법선으로 입힌다.
shader_type spatial;
render_mode cull_back, shadows_disabled;

uniform vec4 albedo : source_color = vec4(0.4, 0.42, 0.45, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.55;
uniform float metallic : hint_range(0.0, 1.0) = 0.3;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// 1인칭 모델 전용 세로 시야각(도)
uniform float viewmodel_fov = 55.0;
// 표면 결: 법선(RGB)·높이(A)
uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail_scale = 20.0;
uniform float detail_strength = 0.0;
// 결의 높이로 거칠기·밝기를 흔든다(얼룩, 닳은 자국)
uniform float detail_rough = 0.15;
uniform float detail_albedo = 0.1;
// 손·소매처럼 정점 색을 쓰는 모델(정점 색은 sRGB로 적은 색이라 선형으로 바꿔 쓴다)
uniform bool use_vertex_color = false;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

varying vec3 obj_pos;
varying vec3 obj_n;

void vertex() {
	obj_pos = VERTEX;
	obj_n = NORMAL;
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
	vec3 base = albedo.rgb;
	if (use_vertex_color) {
		base *= srgb_to_linear(COLOR.rgb);
	}
	float rough = roughness;
	if (detail_strength > 0.0) {
		vec3 n = normalize(obj_n);
		vec3 w = pow(abs(n), vec3(4.0));
		w /= (w.x + w.y + w.z);
		vec4 tx = texture(detail_tex, obj_pos.zy * detail_scale);
		vec4 ty = texture(detail_tex, obj_pos.xz * detail_scale);
		vec4 tz = texture(detail_tex, obj_pos.xy * detail_scale);
		vec3 nx = tx.rgb * 2.0 - 1.0;
		vec3 ny = ty.rgb * 2.0 - 1.0;
		vec3 nz = tz.rgb * 2.0 - 1.0;
		vec3 pert = vec3(0.0, nx.y, nx.x) * w.x + vec3(ny.x, 0.0, ny.y) * w.y + vec3(nz.x, nz.y, 0.0) * w.z;
		vec3 n_obj = normalize(n + pert * detail_strength);
		NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(n_obj, 0.0))).xyz);
		float h = tx.a * w.x + ty.a * w.y + tz.a * w.z;
		rough = clamp(rough + (h - 0.5) * detail_rough, 0.04, 1.0);
		base *= 1.0 + (h - 0.5) * detail_albedo;
	}
	ALBEDO = base;
	ROUGHNESS = rough;
	METALLIC = metallic;
	EMISSION = emission.rgb * emission_energy;
}
