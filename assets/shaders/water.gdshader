shader_type spatial;
// 강과 연못의 수면: 깊이에 따라 색이 짙어지고, 가장자리에 흰 거품, 잔물결 법선.
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled, depth_draw_always;

uniform vec3 shallow_color : source_color = vec3(0.32, 0.52, 0.5);
uniform vec3 deep_color : source_color = vec3(0.08, 0.2, 0.24);
uniform float depth_range = 1.4;
uniform float foam_range = 0.22;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;

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
	vec3 col = mix(shallow_color, deep_color, t);
	float foam = smoothstep(foam_range, 0.0, water_depth) * (0.6 + 0.4 * ripple);
	ALBEDO = mix(col, vec3(0.85, 0.9, 0.9), foam * 0.7);
	ALPHA = mix(0.55, 0.92, t);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	float nx = vnoise(flow + vec2(3.1, 0.0)) - 0.5;
	float nz = vnoise(flow + vec2(0.0, 5.7)) - 0.5;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(nx * 0.35, 0.0, nz * 0.35, 0.0)).xyz);
}
