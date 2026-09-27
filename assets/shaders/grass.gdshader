shader_type spatial;
// 풀잎 묶음: 양면으로 그리고, 끝으로 갈수록 밝아지며 바람에 흔들린다(정점 색 알파 = 흔들림 정도).
render_mode diffuse_burley, cull_disabled;

uniform float wind_strength = 0.22;
uniform float wind_speed = 1.6;
uniform vec2 wind_dir = vec2(1.0, 0.35);

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = COLOR.a;
	float phase = TIME * wind_speed + wp.x * 0.23 + wp.z * 0.19;
	float gust = sin(phase) * 0.6 + sin(phase * 2.3 + 0.7) * 0.3 + sin(wp.x * 0.05 + TIME * 0.5) * 0.4;
	vec2 d = normalize(wind_dir) * gust * wind_strength * w;
	VERTEX.x += d.x;
	VERTEX.z += d.y;
	VERTEX.y -= length(d) * 0.35;
}

void fragment() {
	// 풀잎은 앞뒤 구분 없이 위를 향한 법선으로 밝혀야 들판이 고르게 보인다(뒷면이 검게 보이지 않게).
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float t = COLOR.a;
	// 밑동은 그 자리 땅색을 조금 어둡게, 끝은 밝게(풀밭이 땅과 따로 놀지 않게)
	ALBEDO = COLOR.rgb * mix(0.62, 1.08, clamp(t * 1.1, 0.0, 1.0));
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	BACKLIGHT = COLOR.rgb * 0.3 * t;
}
