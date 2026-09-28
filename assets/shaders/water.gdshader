shader_type spatial;
// 강과 연못의 수면: 깊이에 따라 색이 짙어지고, 가장자리에 흰 거품, 잔물결 법선.
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled, depth_draw_always;

uniform vec3 shallow_color : source_color = vec3(0.32, 0.52, 0.5);
uniform vec3 deep_color : source_color = vec3(0.08, 0.2, 0.24);
uniform float depth_range = 1.4;
uniform float foam_range = 0.22;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;
// 늪(연못과 늪턱 구렁): 흐린 녹갈색 물과 물 위에 뜬 조류. xy = 중심(x, z), z = 반지름
uniform vec4 murk_a = vec4(-150.0, 172.0, 40.0, 0.0);
uniform vec4 murk_b = vec4(-196.0, 208.0, 34.0, 0.0);
uniform vec3 murk_shallow : source_color = vec3(0.3, 0.32, 0.2);
uniform vec3 murk_deep : source_color = vec3(0.1, 0.11, 0.06);

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

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float water_depth = clamp(VERTEX.z - view.z, 0.0, 100.0);
	float t = clamp(water_depth / depth_range, 0.0, 1.0);
	vec2 flow = world_pos.xz * 0.6 + vec2(TIME * 0.35, TIME * 0.22);
	float ripple = vnoise(flow) * 0.6 + vnoise(flow * 2.7 - vec2(TIME * 0.5, 0.0)) * 0.4;
	float murk = max(smoothstep(murk_a.z + 8.0, murk_a.z - 6.0, distance(world_pos.xz, murk_a.xy)),
		smoothstep(murk_b.z + 6.0, murk_b.z - 6.0, distance(world_pos.xz, murk_b.xy)));
	vec3 col = mix(mix(shallow_color, deep_color, t), mix(murk_shallow, murk_deep, sqrt(t)), murk);
	float foam = smoothstep(foam_range, 0.0, water_depth) * (0.6 + 0.4 * ripple) * (1.0 - murk * 0.6);
	col = mix(col, vec3(0.85, 0.9, 0.9), foam * 0.7);
	// 늪에 뜬 조류(개구리밥): 잘게 끊긴 녹색 얼룩, 바람에 천천히 흐른다
	vec2 ap = world_pos.xz * 1.3 + vec2(TIME * 0.05, TIME * 0.03);
	float patch = smoothstep(0.35, 0.7, vnoise(world_pos.xz * 0.12));
	float algae = smoothstep(0.6, 0.7, vnoise(ap) * 0.6 + vnoise(ap * 3.7) * 0.4) * murk * patch;
	ALBEDO = mix(col, vec3(0.28, 0.38, 0.12), algae * 0.85);
	ALPHA = mix(mix(0.55, 0.92, t), mix(0.8, 0.97, t), murk);
	ALPHA = max(ALPHA, algae);
	ROUGHNESS = mix(0.08, 0.16, murk) + algae * 0.6;
	METALLIC = 0.0;
	float nx = vnoise(flow + vec2(3.1, 0.0)) - 0.5;
	float nz = vnoise(flow + vec2(0.0, 5.7)) - 0.5;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(nx * 0.35, 0.0, nz * 0.35, 0.0)).xyz);
}
