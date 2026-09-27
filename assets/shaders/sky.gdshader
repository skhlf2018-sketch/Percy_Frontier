shader_type sky;
// 필드 하늘: 시간대별 색, 해와 달, 별, 구름. 값은 DayNight가 매 프레임 넣는다.

uniform vec3 top_color : source_color = vec3(0.28, 0.5, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.82, 0.92);
uniform vec3 ground_color : source_color = vec3(0.3, 0.33, 0.3);
uniform vec3 glow_color : source_color = vec3(1.0, 0.55, 0.28);
uniform float glow_amount = 0.0;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float sun_visible = 1.0;
uniform float moon_visible = 0.0;
uniform float star_amount = 0.0;
uniform float cloud_coverage = 0.42;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec2 cloud_offset = vec2(0.0);
uniform float darkness = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(h, 0.55));
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}
	// 해 뜰 녘·해 질 녘 지평선 노을
	float sun_side = max(dot(normalize(vec2(dir.x, dir.z) + 0.0001), normalize(vec2(sun_dir.x, sun_dir.z) + 0.0001)), 0.0);
	col += glow_color * glow_amount * pow(sun_side, 3.0) * exp(-abs(h) * 6.0);

	// 별(밤에만)
	if (star_amount > 0.0 && h > 0.0) {
		vec3 sp = dir * 220.0;
		vec3 cell = floor(sp);
		float rnd = hash3(cell);
		vec3 center = cell + 0.5 + (vec3(hash3(cell + 1.3), hash3(cell + 2.7), hash3(cell + 4.1)) - 0.5) * 0.6;
		float star = step(0.985, rnd) * smoothstep(0.38, 0.0, length(sp - center));
		float twinkle = 0.65 + 0.35 * sin(TIME * 1.7 + rnd * 60.0);
		col += vec3(0.88, 0.92, 1.0) * star * twinkle * star_amount * 1.6 * smoothstep(0.0, 0.2, h);
	}
	// 해
	float sd = dot(dir, sun_dir);
	col += vec3(1.0, 0.92, 0.75) * smoothstep(0.9994, 0.99975, sd) * 8.0 * sun_visible;
	col += vec3(1.0, 0.8, 0.55) * pow(max(sd, 0.0), 180.0) * 0.6 * sun_visible;
	// 달
	float md = dot(dir, moon_dir);
	float disc = smoothstep(0.99925, 0.9996, md);
	float crater = vnoise(dir.xy * 900.0) * 0.35;
	col = mix(col, vec3(0.86, 0.88, 0.95) * (1.1 - crater), disc * moon_visible);
	col += vec3(0.45, 0.55, 0.8) * pow(max(md, 0.0), 90.0) * 0.25 * moon_visible;

	// 구름
	if (h > 0.02) {
		vec2 uv = dir.xz / (h + 0.12) * 1.6 + cloud_offset;
		float c = fbm(uv);
		float cover = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.25, c);
		float shade = 0.75 + 0.25 * fbm(uv * 2.0 + 7.0);
		col = mix(col, cloud_color * shade, cover * smoothstep(0.02, 0.2, h) * 0.85);
	}
	col *= (1.0 - darkness);
	COLOR = col;
}
