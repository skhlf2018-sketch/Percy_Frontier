shader_type spatial;
// 나무·덤불(TreeKit): 나무껍질 관과 잎가지·솔잎 가지 카드를 한 재질로 그린다.
// UV2.x = 종류(0 껍질, 1 잎가지, 2 솔잎 가지), UV2.y = 카드마다 다른 난수. 정점 색 RGB = 바탕색, A = 흔들림.
// 잎 카드는 알파로 오려 내고(그림자도 오려진 모양), 수관 법선을 앞뒷면 모두 그대로 써 수관이 부드럽게 빛을 받는다.
render_mode diffuse_burley, cull_disabled;

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D needle_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D bark_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wind_strength = 0.16;
uniform float wind_speed = 1.1;
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float alpha_cut = 0.5;
// 멀리서는 잎이 얇아 보이지 않도록 오려 내는 기준을 낮춘다.
uniform float alpha_cut_far = 0.22;

varying float kind;
varying float rnd;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float w = COLOR.a;
	float phase = TIME * wind_speed + wp.x * 0.11 + wp.z * 0.09;
	float gust = sin(phase) * 0.55 + sin(phase * 2.7 + 1.3) * 0.22 + sin(phase * 0.37) * 0.35;
	vec2 d = normalize(wind_dir) * gust * wind_strength * w * w;
	VERTEX.x += d.x;
	VERTEX.z += d.y;
	kind = UV2.x;
	rnd = UV2.y;
	// 잎의 잔떨림
	if (kind > 0.5) {
		float f = sin(TIME * 5.3 + rnd * 40.0 + VERTEX.y * 2.0) * 0.03 * w;
		VERTEX += NORMAL * f;
	}
}

void fragment() {
	// 앞뒷면 모두 정점 법선(수관 법선·껍질 법선)을 그대로 쓴다.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	if (kind < 0.5) {
		vec4 b = texture(bark_tex, UV);
		ALBEDO = COLOR.rgb * (0.5 + 0.7 * b.a);
		NORMAL_MAP = b.rgb;
		NORMAL_MAP_DEPTH = 1.3;
		ROUGHNESS = 0.92;
		SPECULAR = 0.2;
		AO = mix(0.55, 1.0, b.a);
		AO_LIGHT_AFFECT = 0.4;
	} else {
		vec4 t = kind < 1.5 ? texture(leaf_tex, UV) : texture(needle_tex, UV);
		float dist = length(VERTEX);
		ALPHA = t.a;
		ALPHA_SCISSOR_THRESHOLD = mix(alpha_cut, alpha_cut_far, smoothstep(15.0, 110.0, dist));
		vec3 tint = COLOR.rgb * (0.86 + 0.28 * rnd);
		vec3 col = t.rgb * tint * 1.65;
		ALBEDO = col;
		ROUGHNESS = 0.72;
		SPECULAR = 0.32;
		// 잎은 빛을 조금 통과시킨다(역광에서 밝게 빛난다).
		BACKLIGHT = col * 0.45;
		// 수관 안쪽(아래를 향한 면)은 어둡게
		AO = mix(0.68, 1.0, clamp(dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz) * 0.5 + 0.6, 0.0, 1.0));
		AO_LIGHT_AFFECT = 0.5;
	}
}
