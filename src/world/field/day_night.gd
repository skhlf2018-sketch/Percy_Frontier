class_name DayNight
extends Node3D
## 시간과 조명(기획서 §13.4 시간과 날씨, §23.2 시간대에 따른 조명 변화).
## 실제 20분이 게임 속 하루다. 해와 달, 하늘색, 안개, 주변광을 시간에 맞춰 바꾼다.
## 그늘 숲처럼 어두운 곳(local_shade)과 유니크 접근 시의 이상 징후(eerie)도 여기서 반영한다.

signal phase_changed(phase: int)
signal hour_changed(hour: int)

enum Phase { DAWN, DAY, DUSK, NIGHT }

const PHASE_NAMES := ["새벽", "낮", "해 질 녘", "밤"]
const SKY_SHADER := preload("res://assets/shaders/sky.gdshader")
## 실제 초당 게임 시간(시)
const DEFAULT_HOURS_PER_SEC := 24.0 / 1200.0
const NIGHT_START := 19.75
const NIGHT_END := 5.0
const SUNRISE := 5.5
const SUNSET := 19.0

var hour: float = 9.0
var hours_per_sec: float = DEFAULT_HOURS_PER_SEC
var paused: bool = false
## 0..1. 그늘 숲 안쪽일수록 1(짙은 안개와 어둠)
var local_shade: float = 0.0
## 0..1. 유니크 접근 시 빛이 사그라드는 정도
var eerie: float = 0.0
## 0..1. 밤눈(밤의 포식자의 각인): 밤과 그늘 숲이 덜 어둡다.
var night_vision: float = 0.0

var environment: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_material: ShaderMaterial

var _phase: int = -1
var _last_hour_int: int = -1
var _cloud_offset := Vector2.ZERO


func _ready() -> void:
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.1
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.6
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_sky_affect = 0.35
	environment.fog_height = 4.0
	environment.fog_height_density = 0.0
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.06
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 1.2
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.shadow_enabled = false
	moon.directional_shadow_max_distance = 70.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(moon)
	_apply()


func _process(delta: float) -> void:
	if not paused:
		hour = fposmod(hour + delta * hours_per_sec, 24.0)
	_cloud_offset += Vector2(0.004, 0.0015) * delta
	_apply()


# --- 조회 ---

func is_night() -> bool:
	return hour >= NIGHT_START or hour < NIGHT_END


func phase() -> int:
	if hour >= NIGHT_START or hour < NIGHT_END:
		return Phase.NIGHT
	if hour < 7.0:
		return Phase.DAWN
	if hour < 18.0:
		return Phase.DAY
	return Phase.DUSK


func phase_name() -> String:
	return PHASE_NAMES[phase()]


func clock_text() -> String:
	var m := int(hour * 60.0) % 1440
	return "%02d:%02d" % [m / 60, m % 60]


## 거점의 "기다리기": 목표 시각으로 바로 넘긴다(기획서 §13.4).
func advance_to(target_hour: float) -> void:
	hour = fposmod(target_hour, 24.0)
	_apply()


## 0..1. 해가 떠 있는 정도
func daylight() -> float:
	return clampf(smoothstep(-0.08, 0.22, _sun_height()), 0.0, 1.0)


# --- 계산 ---

## 해의 높이(-1..1). 해는 5:30에 떠서 19:00에 지고, 밤은 그보다 짧게 흐른다.
func _sun_height() -> float:
	return sin(_sun_phase())


## 0..2π. 0 = 해돋이, π = 해넘이
func _sun_phase() -> float:
	if hour >= SUNRISE and hour < SUNSET:
		return PI * (hour - SUNRISE) / (SUNSET - SUNRISE)
	var night_len := 24.0 - (SUNSET - SUNRISE)
	return PI + PI * fposmod(hour - SUNSET, 24.0) / night_len


static func _direction(elevation: float, azimuth: float) -> Vector3:
	return Vector3(cos(elevation) * sin(azimuth), sin(elevation), cos(elevation) * cos(azimuth)).normalized()


func _apply() -> void:
	var phase_angle := _sun_phase()
	var sh := sin(phase_angle)
	# 해: 동(+X)에서 떠서 남쪽 하늘(+Z, 지도의 아래쪽)을 지나 서(-X)로 진다.
	var sun_el := asin(clampf(sh, -1.0, 1.0)) * (62.0 / 90.0)
	var sun_az := PI * 0.5 - clampf(phase_angle, -0.3, PI + 0.3)
	var sun_dir := _direction(sun_el, sun_az)
	# 달: 해와 반대 쪽을 돈다.
	var mh := -sh
	var moon_el := asin(clampf(mh, -1.0, 1.0)) * (50.0 / 90.0)
	var moon_az := PI * 0.5 - clampf(phase_angle - PI, -0.3, PI + 0.3)
	var moon_dir := _direction(moon_el, moon_az)
	_orient(sun, sun_dir)
	_orient(moon, moon_dir)

	var day := daylight()
	var dusk := clampf(1.0 - absf(sh) * 4.0, 0.0, 1.0) * clampf(sh * 3.0 + 1.0, 0.0, 1.0)
	var night := 1.0 - day
	var shade := clampf(local_shade * 0.85 * (1.0 - night_vision * 0.45) + eerie, 0.0, 1.0)

	# 햇빛: 낮게 뜰수록 따뜻한 색
	var warm := clampf(1.0 - sh * 2.2, 0.0, 1.0)
	sun.light_color = Color(1.0, 0.96, 0.9).lerp(Color(1.0, 0.62, 0.36), warm)
	sun.light_energy = day * 1.25 * (1.0 - shade * 0.45) * (1.0 - eerie * 0.6)
	sun.visible = sun.light_energy > 0.01
	moon.light_energy = clampf(mh * 3.0, 0.0, 1.0) * night * 0.5 * (1.0 - eerie * 0.8)
	moon.visible = moon.light_energy > 0.01
	# 그림자는 한 번에 하나만 켠다.
	sun.shadow_enabled = day > 0.15
	moon.shadow_enabled = not sun.shadow_enabled and moon.visible

	var top := Color(0.26, 0.48, 0.84).lerp(Color(0.025, 0.04, 0.1), night)
	var horizon := Color(0.72, 0.82, 0.92).lerp(Color(0.08, 0.11, 0.19), night)
	horizon = horizon.lerp(Color(0.95, 0.62, 0.42), dusk * 0.55)
	sky_material.set_shader_parameter("top_color", top)
	sky_material.set_shader_parameter("horizon_color", horizon)
	sky_material.set_shader_parameter("ground_color", horizon.darkened(0.55))
	sky_material.set_shader_parameter("glow_amount", dusk * 0.9)
	sky_material.set_shader_parameter("sun_dir", sun_dir)
	sky_material.set_shader_parameter("moon_dir", moon_dir)
	sky_material.set_shader_parameter("sun_visible", clampf(sh * 6.0 + 0.6, 0.0, 1.0))
	sky_material.set_shader_parameter("moon_visible", clampf(mh * 6.0 + 0.6, 0.0, 1.0) * (1.0 - eerie))
	sky_material.set_shader_parameter("star_amount", clampf(night * 1.3 - 0.3, 0.0, 1.0) * (1.0 - eerie * 0.8))
	sky_material.set_shader_parameter("cloud_color", Color(1.0, 0.98, 0.95).lerp(Color(0.12, 0.14, 0.2), night).lerp(Color(1.0, 0.7, 0.55), dusk * 0.5))
	sky_material.set_shader_parameter("cloud_offset", _cloud_offset)
	sky_material.set_shader_parameter("darkness", eerie * 0.7)

	# 주변광과 안개: 밤에도 달빛 아래 지형 윤곽은 보이게 한다.
	var ambient := Color(0.58, 0.63, 0.72).lerp(Color(0.26, 0.32, 0.5), night).lerp(Color(0.85, 0.6, 0.5), dusk * 0.3)
	environment.ambient_light_color = ambient
	environment.ambient_light_energy = lerpf(0.62, 0.62, night) * (1.0 - shade * 0.35) * (1.0 - eerie * 0.35) \
		+ night * night_vision * 0.35
	var fog_col := horizon.lerp(Color(0.1, 0.13, 0.12), shade * 0.7)
	environment.fog_light_color = fog_col
	environment.fog_density = lerpf(0.0022, 0.0055, night) + shade * 0.012 + eerie * 0.012
	environment.fog_height_density = shade * 0.05

	var p := phase()
	if p != _phase:
		var first := _phase < 0
		_phase = p
		if not first:
			phase_changed.emit(p)
	var hi := int(hour)
	if hi != _last_hour_int:
		_last_hour_int = hi
		hour_changed.emit(hi)


static func _orient(light: DirectionalLight3D, toward_light: Vector3) -> void:
	# 빛은 -Z 방향으로 나아가므로, 광원 쪽의 반대편을 바라보게 한다.
	var forward := -toward_light
	var up := Vector3.UP if absf(forward.y) < 0.98 else Vector3.FORWARD
	light.global_transform = Transform3D(Basis.looking_at(forward, up), Vector3.ZERO)
