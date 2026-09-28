class_name RenderQuality
extends RefCounted
## 그래픽 품질 설정을 실제 렌더 기능에 적용한다(기획서 §0: 모든 설정은 실제로 동작해야 한다, §23.1 사실적 조명).
##  낮음: 단순한 그림자(2단, 70m)와 거리 안개
##  보통: + 화면 공간 차폐(SSAO)·반사광(SSIL), 그림자 4단 110m
##  높음: + 전역 조명(SDFGI), 볼륨 안개(햇살 줄기, 구렁의 안개), 짐승 털 표현, 그림자 150m
##  최고: + 화면 공간 반사(SSR), 그림자 220m·큰 그림자 지도·고품질 부드러운 그림자, 전역 조명 고품질

const SHADOW_DISTANCE: Array[float] = [70.0, 110.0, 150.0, 220.0]
const SHADOW_ATLAS: Array[int] = [2048, 4096, 4096, 8192]


static func level() -> int:
	return Settings.graphics_quality()


## 환경(하늘·주변광·후처리)에 품질을 적용한다.
static func apply_environment(env: Environment, q: int = -1) -> void:
	if env == null:
		return
	if q < 0:
		q = level()
	env.ssao_enabled = q >= Settings.Quality.MEDIUM
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssao_detail = 0.6
	env.ssil_enabled = q >= Settings.Quality.MEDIUM
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.9
	env.sdfgi_enabled = q >= Settings.Quality.HIGH
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_bounce_feedback = 0.45
	env.sdfgi_cascades = 6 if q >= Settings.Quality.ULTRA else 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_energy = 1.15
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	env.volumetric_fog_enabled = q >= Settings.Quality.HIGH
	env.volumetric_fog_length = 96.0 if q >= Settings.Quality.ULTRA else 64.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.ssr_enabled = q >= Settings.Quality.ULTRA
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.glow_enabled = true


## 해·달(방향광)의 그림자 품질
static func apply_sun(light: DirectionalLight3D, q: int = -1) -> void:
	if light == null:
		return
	if q < 0:
		q = level()
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q <= Settings.Quality.LOW \
		else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	light.directional_shadow_max_distance = SHADOW_DISTANCE[clampi(q, 0, 3)]
	light.directional_shadow_blend_splits = q >= Settings.Quality.HIGH
	light.shadow_blur = 1.0 if q >= Settings.Quality.HIGH else 1.2
	light.light_volumetric_fog_energy = 1.4


## 렌더링 서버 전체 설정(그림자 지도 크기, 부드러운 그림자, 화면 공간 효과의 품질)
static func apply_global(q: int = -1) -> void:
	if q < 0:
		q = level()
	var lvl := clampi(q, 0, 3)
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS[lvl], true)
	var soft: Array[RenderingServer.ShadowQuality] = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH]
	RenderingServer.directional_soft_shadow_filter_set_quality(soft[lvl])
	RenderingServer.positional_soft_shadow_filter_set_quality(soft[lvl])
	var ssao: Array[RenderingServer.EnvironmentSSAOQuality] = [RenderingServer.ENV_SSAO_QUALITY_VERY_LOW,
		RenderingServer.ENV_SSAO_QUALITY_LOW, RenderingServer.ENV_SSAO_QUALITY_MEDIUM, RenderingServer.ENV_SSAO_QUALITY_HIGH]
	RenderingServer.environment_set_ssao_quality(ssao[lvl], true, 0.5, 2, 50.0, 300.0)
	var ssil: Array[RenderingServer.EnvironmentSSILQuality] = [RenderingServer.ENV_SSIL_QUALITY_VERY_LOW,
		RenderingServer.ENV_SSIL_QUALITY_LOW, RenderingServer.ENV_SSIL_QUALITY_MEDIUM, RenderingServer.ENV_SSIL_QUALITY_HIGH]
	RenderingServer.environment_set_ssil_quality(ssil[lvl], true, 0.5, 4, 50.0, 300.0)
	var rays: Array[RenderingServer.EnvironmentSDFGIRayCount] = [RenderingServer.ENV_SDFGI_RAY_COUNT_16,
		RenderingServer.ENV_SDFGI_RAY_COUNT_16, RenderingServer.ENV_SDFGI_RAY_COUNT_32, RenderingServer.ENV_SDFGI_RAY_COUNT_64]
	RenderingServer.environment_set_sdfgi_ray_count(rays[lvl])
	RenderingServer.environment_set_volumetric_fog_volume_size(96 if lvl >= 3 else 64, 96 if lvl >= 3 else 64)
	RenderingServer.environment_set_volumetric_fog_filter_active(lvl >= 3)


## 화면의 계단 현상 줄이기: 늘 FXAA, 높음 이상은 MSAA를 더한다(나뭇잎 가장자리는 알파 커버리지로 부드럽게).
static func apply_viewport(vp: Viewport, q: int = -1) -> void:
	if vp == null:
		return
	if q < 0:
		q = level()
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	var msaa: Array[Viewport.MSAA] = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
	vp.msaa_3d = msaa[clampi(q, 0, 3)]
	vp.use_debanding = q >= Settings.Quality.HIGH


## 장면의 환경과 방향광 모두에 적용한다(설정을 바꾸면 곧바로 바뀐다).
static func apply_all(root: Node) -> void:
	var q := level()
	apply_global(q)
	if root == null:
		return
	if root.is_inside_tree():
		apply_viewport(root.get_viewport(), q)
	for n in root.find_children("*", "WorldEnvironment", true, false):
		apply_environment((n as WorldEnvironment).environment, q)
	for n in root.find_children("*", "DirectionalLight3D", true, false):
		apply_sun(n as DirectionalLight3D, q)
