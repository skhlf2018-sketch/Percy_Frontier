shader_type spatial;
// 필드 지형(기획서 §23.1 사실적 재질): 풀밭·흙길·낙엽 바닥·자갈·진흙 결을 높이로 섞고, 가파른 곳은 바위를 삼면 투영으로 덮는다.
// 결 텍스처(TerrainTextures)는 RGB에 법선, A에 높이를 담는다. 정점 색은 풀밭의 바탕색(지역마다 다르다, sRGB로 적은 색이라
// 선형으로 바꿔 쓴다: 그대로 쓰면 풀밭이 허옇게 바래 보인다), CUSTOM0은 지표 종류 비율(r 흙길, g 젖은 진흙, b 낙엽 바닥, a 자갈·모래)이다.
render_mode diffuse_burley;

uniform sampler2D tex_grass : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_dirt : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rock : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_mud : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_litter : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_sand : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec3 rock_color : source_color = vec3(0.43, 0.41, 0.38);
uniform vec3 dirt_color : source_color = vec3(0.45, 0.36, 0.25);
uniform vec3 mud_color : source_color = vec3(0.21, 0.18, 0.13);
uniform vec3 litter_color : source_color = vec3(0.31, 0.24, 0.15);
uniform vec3 sand_color : source_color = vec3(0.55, 0.5, 0.41);
uniform float rock_start = 0.34;
uniform float rock_end = 0.52;
uniform float normal_strength = 1.1;
// 풀밭 바탕색의 밝기
uniform float grass_gain = 1.3;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 ground;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

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
	ground = CUSTOM0;
}

// 위에서 내려다본 투영. 두 크기로 섞어 반복 무늬를 감춘다. xyz = 결 법선(z가 위), w = 높이
vec4 top(sampler2D t, vec2 xz, float s) {
	vec4 a = texture(t, xz * s);
	vec4 b = texture(t, xz * s * 0.29 + vec2(0.37, 0.71));
	vec3 na = a.rgb * 2.0 - 1.0;
	vec3 nb = b.rgb * 2.0 - 1.0;
	return vec4(normalize(vec3(na.xy + nb.xy * 0.6, na.z)), a.a * 0.65 + b.a * 0.35);
}

// 높이 섞기: 비율이 높고 결이 높은 곳부터 위에 드러난다.
float layer(float weight, float layer_h, float base_h, float bias) {
	return smoothstep(0.0, 1.0, clamp(weight * 1.35 + (layer_h - base_h) * 0.55 - bias, 0.0, 1.0));
}

void fragment() {
	vec2 xz = world_pos.xz;
	float dist = length(VERTEX);
	float detail_fade = 1.0 - smoothstep(35.0, 150.0, dist);
	float macro = vnoise(xz * 0.035) * 0.6 + vnoise(xz * 0.13) * 0.4;

	vec4 g = top(tex_grass, xz, 0.45);
	vec4 d = top(tex_dirt, xz, 0.5);
	vec4 m = top(tex_mud, xz, 0.28);
	vec4 l = top(tex_litter, xz, 0.55);
	vec4 s = top(tex_sand, xz, 0.9);

	// 풀밭: 지역 바탕색에 결의 명암과 마른 풀 끝
	vec3 base = srgb_to_linear(COLOR.rgb);
	// 들풀은 잔디처럼 새파랗지 않다: 채도를 조금 누른다.
	base = mix(vec3(dot(base, vec3(0.2126, 0.7152, 0.0722))), base, 0.86);
	vec3 col = base * grass_gain * (0.66 + 0.55 * g.w) * (0.88 + 0.24 * macro);
	// 볕에 마른 풀 얼룩: 넓게 누렇게 바랜 곳이 섞여야 잔디밭처럼 고르게 보이지 않는다.
	float dry = smoothstep(0.42, 0.8, vnoise(xz * 0.021 + vec2(17.3, 5.1)) * 0.7 + vnoise(xz * 0.09) * 0.3);
	col = mix(col, col * vec3(1.25, 1.02, 0.58), dry * 0.7);
	col = mix(col, col * vec3(1.1, 1.04, 0.78), smoothstep(0.55, 0.92, g.w) * 0.45);
	vec3 n = g.xyz;
	float h = g.w;
	float rough = 0.93;

	float wr = layer(ground.r, d.w, h, 0.2);
	col = mix(col, dirt_color * (0.62 + 0.58 * d.w) * (0.9 + 0.2 * macro), wr);
	n = normalize(mix(n, d.xyz, wr));
	h = mix(h, d.w, wr);
	rough = mix(rough, 0.96, wr);

	float wl = layer(ground.b, l.w, h, 0.15);
	vec3 litter_c = litter_color * (0.52 + 0.72 * l.w);
	litter_c = mix(litter_c, litter_c * vec3(0.78, 1.12, 0.66), vnoise(xz * 0.8) * 0.55);
	col = mix(col, litter_c, wl);
	n = normalize(mix(n, l.xyz, wl));
	h = mix(h, l.w, wl);
	rough = mix(rough, 0.9, wl);

	float ws = layer(ground.a, s.w, h, 0.15);
	col = mix(col, sand_color * (0.72 + 0.4 * s.w), ws);
	n = normalize(mix(n, s.xyz, ws));
	h = mix(h, s.w, ws);
	rough = mix(rough, 0.85, ws);

	float wm = layer(ground.g, m.w, h, 0.2);
	col = mix(col, mud_color * (0.75 + 0.45 * m.w), wm);
	// 진흙의 낮은 곳에 고인 물: 짙고 매끈하다
	float puddle = smoothstep(0.42, 0.3, m.w) * wm * ground.g;
	col *= 1.0 - puddle * 0.35;
	n = normalize(mix(mix(n, m.xyz, wm), vec3(0.0, 0.0, 1.0), puddle));
	rough = mix(mix(rough, 0.38, wm), 0.06, puddle);
	h = mix(h, m.w, wm);

	// 바위: 가파른 곳을 삼면 투영으로 덮는다.
	vec3 wn = normalize(world_normal);
	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	float rock_amt = smoothstep(rock_start, rock_end, slope + (macro - 0.5) * 0.12 + (h - 0.5) * 0.08);
	vec3 bw = pow(abs(wn), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec4 rx = texture(tex_rock, world_pos.zy * 0.22);
	vec4 ry = texture(tex_rock, world_pos.xz * 0.22);
	vec4 rz = texture(tex_rock, world_pos.xy * 0.22);
	float rh = rx.a * bw.x + ry.a * bw.y + rz.a * bw.z;
	vec3 rnx = rx.rgb * 2.0 - 1.0;
	vec3 rny = ry.rgb * 2.0 - 1.0;
	vec3 rnz = rz.rgb * 2.0 - 1.0;
	vec3 rock_n = normalize(wn + (vec3(0.0, rnx.y, rnx.x) * bw.x + vec3(rny.x, 0.0, rny.y) * bw.y
		+ vec3(rnz.x, rnz.y, 0.0) * bw.z) * 1.2 * (0.4 + 0.6 * detail_fade));
	float strata = vnoise(vec2(xz.x * 0.2 + xz.y * 0.2, world_pos.y * 1.3));
	vec3 rock_c = rock_color * (0.55 + 0.6 * rh) * (0.85 + 0.3 * strata);

	// 지표 결 법선(위쪽 투영: 접선 +X, 종접선 +Z)을 세계 법선으로
	vec3 ground_n = normalize(wn + vec3(n.x, 0.0, n.y) * normal_strength * detail_fade);
	vec3 final_n = normalize(mix(ground_n, rock_n, rock_amt));
	col = mix(col, rock_c, rock_amt);
	rough = mix(rough, 0.82, rock_amt);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.25;
	AO = mix(mix(0.72, 1.0, h), mix(0.62, 1.0, rh), rock_amt);
	AO_LIGHT_AFFECT = 0.3;
	NORMAL = normalize((VIEW_MATRIX * vec4(final_n, 0.0)).xyz);
}
