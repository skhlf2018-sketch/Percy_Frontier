extends TestCase
## 그래픽 품질 설정이 실제 렌더 기능을 켜고 끄는지(기획서 §0: 모든 설정은 실제로 동작해야 한다).
## 낮음: 화면 공간 효과·전역 조명·볼륨 안개 없음, 2단 그림자 / 보통: SSAO·SSIL / 높음: SDFGI·볼륨 안개·털 / 최고: SSR·먼 그림자

var day_night: DayNight


func before_each() -> void:
	Settings.load_settings("user://test_quality.cfg")
	day_night = DayNight.new()
	runner.add_child(day_night)
	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(day_night):
		day_night.queue_free()
	await wait_frames(1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_quality.cfg"))
	Settings.load_settings(Settings.DEFAULT_PATH)


func test_low_disables_expensive_effects() -> void:
	Settings.set_value(&"graphics_quality", Settings.Quality.LOW, false)
	var env := day_night.environment
	assert_false(env.ssao_enabled, "낮음: SSAO 없음")
	assert_false(env.ssil_enabled, "낮음: SSIL 없음")
	assert_false(env.sdfgi_enabled, "낮음: 전역 조명 없음")
	assert_false(env.volumetric_fog_enabled, "낮음: 볼륨 안개 없음")
	assert_false(env.ssr_enabled)
	assert_eq(day_night.sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "낮음: 단순한 그림자")
	assert_false(Settings.creature_fur_enabled(), "낮음: 털 표현 없음")


func test_medium_adds_screen_space_effects() -> void:
	Settings.set_value(&"graphics_quality", Settings.Quality.MEDIUM, false)
	var env := day_night.environment
	assert_true(env.ssao_enabled and env.ssil_enabled, "보통: 화면 공간 차폐·반사광")
	assert_false(env.sdfgi_enabled)
	assert_eq(day_night.sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)


func test_high_adds_gi_fog_and_fur() -> void:
	Settings.set_value(&"graphics_quality", Settings.Quality.HIGH, false)
	var env := day_night.environment
	assert_true(env.sdfgi_enabled, "높음: 전역 조명(SDFGI)")
	assert_true(env.volumetric_fog_enabled, "높음: 볼륨 안개")
	assert_true(Settings.creature_fur_enabled(), "높음: 털 표현")
	assert_false(env.ssr_enabled)


func test_ultra_adds_reflections_and_far_shadows() -> void:
	Settings.set_value(&"graphics_quality", Settings.Quality.HIGH, false)
	var high_dist := day_night.sun.directional_shadow_max_distance
	Settings.set_value(&"graphics_quality", Settings.Quality.ULTRA, false)
	var env := day_night.environment
	assert_true(env.ssr_enabled, "최고: 화면 공간 반사")
	assert_gt(day_night.sun.directional_shadow_max_distance, high_dist, "최고: 더 먼 그림자")


func test_volumetric_fog_follows_time_and_shade() -> void:
	Settings.set_value(&"graphics_quality", Settings.Quality.HIGH, false)
	day_night.advance_to(12.0)
	var noon := day_night.environment.volumetric_fog_density
	day_night.local_shade = 1.0
	day_night.advance_to(12.0)
	assert_gt(day_night.environment.volumetric_fog_density, noon, "그늘 숲 안은 안개가 짙다")
