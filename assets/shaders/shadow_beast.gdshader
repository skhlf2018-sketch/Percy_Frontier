shader_type spatial;
// 밤의 포식자: 정점 색(또는 단색)과 발광. fade가 1보다 작으면 점무늬로 구멍을 내며 사라진다(정렬 문제 없는 투명).
render_mode diffuse_burley;

uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform bool use_vertex_color = true;
uniform vec3 albedo : source_color = vec3(1.0);
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	ivec2 cell = ivec2(mod(floor(FRAGCOORD.xy), 4.0));
	float threshold = (BAYER[cell.x + cell.y * 4] + 0.5) / 16.0;
	if (fade < 0.999 && fade <= threshold) {
		discard;
	}
	ALBEDO = use_vertex_color ? COLOR.rgb : albedo;
	EMISSION = emission_color * emission_energy;
	ROUGHNESS = 0.88;
	SPECULAR = 0.25;
}
