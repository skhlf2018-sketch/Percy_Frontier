shader_type spatial;
// 털 껍질(shell): 몸 표면을 법선 방향으로 조금씩 부풀린 여러 겹에 털 가닥 무늬만 남겨 그린다.
// 안쪽 겹은 어둡게(털 사이 그늘), 바깥 겹은 가닥이 가늘고 드물다. 정점 색 알파가 털 길이 비율이다.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float shell_t = 0.5;
uniform float fur_length = 0.025;
uniform float density = 9.0;
uniform float droop = 0.35;
uniform sampler2D strands : filter_linear_mipmap, repeat_enable;
// 공격 전조·피격 반짝임(개체마다 다르다)
instance uniform vec4 overlay_tint : source_color = vec4(0.0);

varying vec3 obj_pos;
varying vec3 obj_nrm;
varying float fur_amount;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	fur_amount = COLOR.a;
	float len = fur_length * COLOR.a * shell_t;
	VERTEX += NORMAL * len;
	// 끝으로 갈수록 무게로 처진다.
	VERTEX.y -= len * droop * shell_t;
	obj_pos = VERTEX;
	obj_nrm = NORMAL;
}

vec2 sample_tri(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec2 a = texture(strands, p.zy * density).rg;
	vec2 b = texture(strands, p.xz * density).rg;
	vec2 c = texture(strands, p.xy * density).rg;
	return a * w.x + b * w.y + c * w.z;
}

void fragment() {
	if (fur_amount < 0.05) {
		discard;
	}
	vec2 s = sample_tri(obj_pos, obj_nrm);
	// r: 가닥 중심에서 1, 가장자리로 0. g: 가닥마다 다른 길이.
	float radius = mix(0.55, 0.12, shell_t);
	if (s.r < 1.0 - radius || s.g < shell_t * 0.92) {
		discard;
	}
	vec3 base = srgb_to_linear(COLOR.rgb);
	float occl = mix(0.45, 1.05, shell_t);
	ALBEDO = base * occl;
	if (overlay_tint.a > 0.0) {
		ALBEDO = mix(ALBEDO, overlay_tint.rgb, overlay_tint.a * 0.6);
		EMISSION = overlay_tint.rgb * overlay_tint.a * 1.5;
	}
	ROUGHNESS = 0.95;
	SPECULAR = 0.25;
	BACKLIGHT = base * 0.25 * shell_t;
}
