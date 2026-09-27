// 회색 상자 단계용 격자 재질. 월드 좌표 기준 1m 격자로 거리와 높이를 읽기 쉽게 한다.
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.55, 0.57, 0.6, 1.0);
uniform vec4 line_color : source_color = vec4(0.36, 0.38, 0.41, 1.0);
uniform float grid_size = 1.0;
// 굵은 선 간격(칸 수)
uniform float major_every = 4.0;
// 선 두께(픽셀)
uniform float line_pixels = 1.2;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid_mask(vec2 p, float size, float thickness) {
	vec2 coord = p / size;
	vec2 d = abs(fract(coord - 0.5) - 0.5) / max(fwidth(coord), vec2(1e-5));
	return 1.0 - min(min(d.x, d.y) / thickness, 1.0);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv;
	if (n.y >= n.x && n.y >= n.z) {
		uv = world_pos.xz;
	} else if (n.x >= n.z) {
		uv = world_pos.zy;
	} else {
		uv = world_pos.xy;
	}
	float minor = grid_mask(uv, grid_size, line_pixels) * 0.45;
	float major = grid_mask(uv, grid_size * major_every, line_pixels * 1.6);
	ALBEDO = mix(base_color.rgb, line_color.rgb, max(minor, major));
	ROUGHNESS = roughness;
}
