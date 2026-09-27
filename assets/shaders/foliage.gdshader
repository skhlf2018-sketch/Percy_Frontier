shader_type spatial;
// 나무·덤불: 정점 색이 곧 색이고, 정점 색의 알파가 바람에 흔들리는 정도다(줄기 밑동 0 → 잎 1).
render_mode diffuse_burley;

uniform float wind_strength = 0.16;
uniform float wind_speed = 1.1;
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float night_dim = 0.0;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float w = COLOR.a;
	float phase = TIME * wind_speed + wp.x * 0.11 + wp.z * 0.09;
	float gust = sin(phase) * 0.55 + sin(phase * 2.7 + 1.3) * 0.22 + sin(phase * 0.37) * 0.35;
	vec2 d = normalize(wind_dir) * gust * wind_strength * w;
	VERTEX.x += d.x;
	VERTEX.z += d.y;
	VERTEX.y += sin(phase * 4.3 + VERTEX.x * 3.0 + VERTEX.z * 2.0) * 0.035 * w;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.88;
	SPECULAR = 0.2;
	// 잎이 빛을 조금 통과시키는 느낌
	BACKLIGHT = COLOR.rgb * 0.25 * COLOR.a;
}
