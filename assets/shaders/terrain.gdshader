shader_type spatial;
// 필드 지형: 정점 색(지표 종류)에 세계 좌표 잡음으로 얼룩을 더하고, 가파른 곳은 바위색으로 덮는다.
render_mode diffuse_burley;

uniform vec3 rock_color : source_color = vec3(0.43, 0.41, 0.38);
uniform float rock_start = 0.34;
uniform float rock_end = 0.52;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 xz = world_pos.xz;
	float n = vnoise(xz * 0.35) * 0.55 + vnoise(xz * 1.9) * 0.3 + vnoise(xz * 7.0) * 0.15;
	vec3 col = COLOR.rgb * (0.82 + 0.36 * n);
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float strata = vnoise(vec2(xz.x * 0.2 + xz.y * 0.2, world_pos.y * 1.3));
	vec3 rock = rock_color * (0.78 + 0.35 * strata);
	col = mix(col, rock, smoothstep(rock_start, rock_end, slope + (n - 0.5) * 0.08));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
