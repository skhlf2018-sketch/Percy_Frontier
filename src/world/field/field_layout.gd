class_name FieldLayout
extends RefCounted
## 퍼시 외곽권(기획서 §12 지역 1: 시작 숲, 첫 마을, 기본 시스템 학습)의 배치와 지형 규칙.
## 좌표는 지도 중심이 원점, -Z가 북쪽, 단위는 m. 물 높이는 0이다.
## 지형 높이·식생 밀도·지표 색을 한곳에서 계산해 지형 메시, 충돌, 식생 배치가 서로 어긋나지 않게 한다.

const HALF_SIZE := 256.0
const WATER_LEVEL := 0.0
const SEED := 7031

## 주요 장소(x, z)
const DROP_SITE := Vector2(-182, 28)          # 강하선 잔해(새 게임 시작 지점, 첫 안전 거점)
const TOWN_CENTER := Vector2(150, 136)        # 퍼시 마을
const TOWN_RADIUS := 46.0
const TOWN_HEIGHT := 11.0
const TOWN_GATE := Vector2(104, 136)          # 서쪽 정문
const OLD_TREE := Vector2(12, -34)            # 고목(랜드마크)
const WATCHTOWER := Vector2(78, -58)          # 무너진 감시탑(전망 지점)
const CAMP := Vector2(46, -138)               # 북쪽 야영지(안전 거점)
const SHADE_CENTER := Vector2(-72, -140)      # 그늘 숲(짙은 숲, 밤의 포식자 영역)
const SHADE_RADIUS := 96.0
const POND_CENTER := Vector2(-150, 172)       # 남서 늪 연못
const POND_RADIUS := 25.0
const MEADOW_CENTER := Vector2(150, -104)     # 북동 초원 언덕
const MEADOW_RADIUS := 78.0
const BRIDGE := Vector2(-24, 52)              # 강을 건너는 나무다리

## 강하선 잔해 → 다리 → 퍼시 정문으로 이어지는 흙길
const ROAD: Array[Vector2] = [
	Vector2(-176, 30), Vector2(-150, 38), Vector2(-112, 46), Vector2(-70, 54),
	Vector2(-38, 53), Vector2(-10, 51), Vector2(24, 64), Vector2(58, 88),
	Vector2(84, 116), Vector2(104, 136), Vector2(150, 136),
]
## 퍼시에서 북쪽 야영지로 가는 샛길
const TRAIL: Array[Vector2] = [
	Vector2(58, 88), Vector2(66, 40), Vector2(70, -6), Vector2(62, -60),
	Vector2(52, -104), Vector2(46, -138),
]
## 북쪽 산에서 남쪽으로 흐르는 강(얕아서 걸어서 건널 수 있다)
const RIVER: Array[Vector2] = [
	Vector2(-44, -262), Vector2(-58, -190), Vector2(-34, -118), Vector2(-48, -44),
	Vector2(-24, 52), Vector2(-40, 120), Vector2(-14, 190), Vector2(-28, 262),
]
## 야외 무리: [종류, x, z, 수, 매복]. 시작 지점에서 멀어질수록 위험해진다(기획서 §4.3, §5.1).
const ENCOUNTERS := [
	[&"rabbits", -128, 62, 3, true],
	[&"rabbits", -150, 100, 3, true],
	[&"rabbits", -84, 22, 4, true],
	[&"rabbits", 14, 26, 4, true],
	[&"rabbits", 70, 60, 3, true],
	[&"rabbits", 32, -92, 3, true],
	[&"rabbits", 118, -70, 4, true],
	[&"charger", 150, -118, 1, false],
	[&"charger", 190, -62, 1, false],
	[&"charger", 120, -150, 1, false],
	[&"spitters", -128, 150, 2, false],
	[&"spitters", -170, 196, 2, false],
	[&"spitters", -22, -100, 2, false],
	[&"rabbits", -96, -150, 4, true],
]
const ROAD_HALF_WIDTH := 2.6
const RIVER_HALF_WIDTH := 5.0
const RIVER_DEPTH := 0.85
const POND_DEPTH := 1.1

var _n_base := FastNoiseLite.new()
var _n_mid := FastNoiseLite.new()
var _n_detail := FastNoiseLite.new()
var _n_biome := FastNoiseLite.new()


func _init() -> void:
	for n: FastNoiseLite in [_n_base, _n_mid, _n_detail, _n_biome]:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_base.seed = SEED
	_n_base.frequency = 0.0042
	_n_base.fractal_octaves = 3
	_n_mid.seed = SEED + 1
	_n_mid.frequency = 0.016
	_n_mid.fractal_octaves = 2
	_n_detail.seed = SEED + 2
	_n_detail.frequency = 0.07
	_n_detail.fractal_type = FastNoiseLite.FRACTAL_NONE
	_n_biome.seed = SEED + 3
	_n_biome.frequency = 0.02
	_n_biome.fractal_octaves = 2
	_drop_level = _raw_height(DROP_SITE.x, DROP_SITE.y)
	_camp_level = _raw_height(CAMP.x, CAMP.y)


# --- 지형 높이 ---

var _drop_level: float
var _camp_level: float


## 평평하게 다지기 전의 자연 지형
func _raw_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := 7.0 + _n_base.get_noise_2d(x, z) * 9.0 + _n_mid.get_noise_2d(x, z) * 2.6
	# 북동 초원은 완만하게 굽이치는 언덕
	h += _falloff(p, MEADOW_CENTER, MEADOW_RADIUS) * (4.0 + _n_mid.get_noise_2d(x * 0.6, z * 0.6) * 5.0)
	# 감시탑 언덕과 고목 둔덕
	h += _bump(p, WATCHTOWER, 34.0) * 11.0
	h += _bump(p, OLD_TREE, 22.0) * 4.0
	# 북쪽 능선(지도 경계의 절벽)
	h += pow(clampf((-z - 196.0) / 60.0, 0.0, 1.0), 1.6) * 34.0
	# 가장자리 산: 보이지 않는 벽 대신 지형으로 지역을 닫는다
	var edge := HALF_SIZE - maxf(absf(x), absf(z))
	if edge < 44.0:
		var t := (44.0 - edge) / 44.0
		h += t * t * 46.0 + _n_mid.get_noise_2d(x * 2.0, z * 2.0) * 6.0 * t
	return h


## 큰 지형 + 평평한 장소(마을, 강하선 잔해, 야영지). 길은 이 높이를 따라간다.
func base_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := _raw_height(x, z)
	h = lerpf(h, TOWN_HEIGHT, _plateau(p, TOWN_CENTER, TOWN_RADIUS, 24.0))
	h = lerpf(h, _drop_level, _plateau(p, DROP_SITE, 17.0, 14.0))
	h = lerpf(h, _camp_level, _plateau(p, CAMP, 11.0, 10.0))
	return h


## 최종 높이: 기본 지형 + 잔 굴곡, 길 다지기, 강·연못 파기
func height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := base_height(x, z)
	var town := _plateau(p, TOWN_CENTER, TOWN_RADIUS, 24.0)
	h += _n_detail.get_noise_2d(x, z) * 0.45 * (1.0 - town)
	# 길: 주변보다 살짝 낮고 평평하게
	var road := road_factor(p)
	if road > 0.0:
		var near := _nearest_on_paths(p)
		h = lerpf(h, _road_level(near) - 0.08, road)
	# 강: 둑을 따라 완만하게 파인다
	var dr := distance_to_river(p)
	if dr < RIVER_HALF_WIDTH + 12.0:
		var bank := smoothstep(RIVER_HALF_WIDTH + 12.0, RIVER_HALF_WIDTH * 0.6, dr)
		var bed := WATER_LEVEL - RIVER_DEPTH * smoothstep(RIVER_HALF_WIDTH + 1.0, 0.0, dr)
		h = lerpf(h, minf(h, bed + (dr / (RIVER_HALF_WIDTH + 1.0)) * 1.2), bank)
	# 연못
	var dp := p.distance_to(POND_CENTER) / POND_RADIUS
	if dp < 1.6:
		var pond_bed := WATER_LEVEL - POND_DEPTH * (1.0 - clampf(dp, 0.0, 1.0) * clampf(dp, 0.0, 1.0))
		h = lerpf(h, minf(h, pond_bed + maxf(dp - 1.0, 0.0) * 3.0), smoothstep(1.6, 0.9, dp))
	return h


## 길 위의 높이(주변의 큰 굴곡만 따른다)
func _road_level(p: Vector2) -> float:
	return base_height(p.x, p.y)


# --- 거리와 영역 ---

static func distance_to_polyline(p: Vector2, line: Array[Vector2]) -> float:
	var best := INF
	for i in line.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])))
	return best


static func closest_on_polyline(p: Vector2, line: Array[Vector2]) -> Vector2:
	var best := INF
	var out := p
	for i in line.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])
		var d := p.distance_squared_to(c)
		if d < best:
			best = d
			out = c
	return out


func distance_to_river(p: Vector2) -> float:
	return distance_to_polyline(p, RIVER)


func distance_to_road(p: Vector2) -> float:
	return minf(distance_to_polyline(p, ROAD), distance_to_polyline(p, TRAIL))


func _nearest_on_paths(p: Vector2) -> Vector2:
	var a := closest_on_polyline(p, ROAD)
	var b := closest_on_polyline(p, TRAIL)
	return a if p.distance_squared_to(a) <= p.distance_squared_to(b) else b


## 0..1. 길 한가운데서 1
func road_factor(p: Vector2) -> float:
	var d := distance_to_road(p)
	if p.distance_to(TOWN_CENTER) < TOWN_RADIUS - 6.0:
		return 0.0
	return smoothstep(ROAD_HALF_WIDTH + 3.5, ROAD_HALF_WIDTH, d)


## 0..1. 그늘 숲 한가운데서 1
func shade_factor(p: Vector2) -> float:
	var warp := _n_biome.get_noise_2d(p.x, p.y) * 22.0
	return smoothstep(SHADE_RADIUS + 18.0, SHADE_RADIUS - 30.0, p.distance_to(SHADE_CENTER) + warp)


func meadow_factor(p: Vector2) -> float:
	var warp := _n_biome.get_noise_2d(p.x + 400.0, p.y) * 18.0
	return smoothstep(MEADOW_RADIUS + 10.0, MEADOW_RADIUS - 30.0, p.distance_to(MEADOW_CENTER) + warp)


func in_town(p: Vector2, margin: float = 0.0) -> bool:
	return p.distance_to(TOWN_CENTER) < TOWN_RADIUS + margin


## 나무를 두지 않는 곳(길, 물가, 마을, 거점, 랜드마크 주변)
func is_clear_area(p: Vector2) -> bool:
	if distance_to_road(p) < ROAD_HALF_WIDTH + 3.5:
		return true
	if distance_to_river(p) < RIVER_HALF_WIDTH + 4.0:
		return true
	if p.distance_to(POND_CENTER) < POND_RADIUS + 5.0:
		return true
	if in_town(p, 10.0):
		return true
	for spot: Vector2 in [DROP_SITE, CAMP]:
		if p.distance_to(spot) < 20.0:
			return true
	if p.distance_to(OLD_TREE) < 16.0 or p.distance_to(WATCHTOWER) < 14.0:
		return true
	return false


## 0..1 나무 밀도
func tree_density(p: Vector2) -> float:
	if is_clear_area(p):
		return 0.0
	var d := 0.34 + _n_biome.get_noise_2d(p.x * 1.7, p.y * 1.7) * 0.22
	d = lerpf(d, 0.95, shade_factor(p))
	d = lerpf(d, 0.05, meadow_factor(p))
	var edge := HALF_SIZE - maxf(absf(p.x), absf(p.y))
	if edge < 50.0:
		d = maxf(d, 0.55)
	# 길 가장자리는 조금 성기게
	d *= smoothstep(ROAD_HALF_WIDTH + 3.5, ROAD_HALF_WIDTH + 12.0, distance_to_road(p)) * 0.5 + 0.5
	return clampf(d, 0.0, 1.0)


## 0..1 풀 밀도
func grass_density(p: Vector2, h: float) -> float:
	if h < WATER_LEVEL + 0.25:
		return 0.0
	if road_factor(p) > 0.3:
		return 0.0
	if p.distance_to(TOWN_CENTER) < TOWN_RADIUS - 4.0:
		return 0.15
	var d := 0.75 + _n_biome.get_noise_2d(p.x * 2.3, p.y * 2.3) * 0.25
	d = lerpf(d, 0.25, shade_factor(p))
	d = lerpf(d, 1.0, meadow_factor(p))
	return clampf(d, 0.0, 1.0)


## 지표 색(지형 정점 색). 경사에 따른 바위색은 셰이더가 더한다.
func ground_color(p: Vector2, h: float) -> Color:
	var grass := Color(0.34, 0.47, 0.22)
	var v := _n_biome.get_noise_2d(p.x * 3.1, p.y * 3.1)
	grass = grass.lerp(Color(0.42, 0.52, 0.24), clampf(v * 0.5 + 0.5, 0.0, 1.0) * 0.6)
	var shade := shade_factor(p)
	grass = grass.lerp(Color(0.19, 0.26, 0.16), shade)
	grass = grass.lerp(Color(0.5, 0.58, 0.27), meadow_factor(p) * 0.7)
	if in_town(p, -4.0):
		grass = grass.lerp(Color(0.36, 0.36, 0.26), 0.5)
	# 길 색은 다져진 폭보다 좁고 또렷하게 칠한다.
	var road := 0.0
	if not in_town(p, -6.0):
		road = smoothstep(ROAD_HALF_WIDTH + 0.9, ROAD_HALF_WIDTH - 0.6, distance_to_road(p))
	var col := grass.lerp(Color(0.46, 0.37, 0.26), road)
	# 물가 모래와 물속 진흙
	if h < WATER_LEVEL + 0.6:
		col = col.lerp(Color(0.53, 0.48, 0.36), smoothstep(WATER_LEVEL + 0.6, WATER_LEVEL + 0.1, h))
	if h < WATER_LEVEL - 0.1:
		col = col.lerp(Color(0.24, 0.21, 0.16), smoothstep(WATER_LEVEL - 0.1, WATER_LEVEL - 0.6, h))
	return col


# --- 내부 도우미 ---

static func _bump(p: Vector2, center: Vector2, radius: float) -> float:
	var d := p.distance_to(center) / radius
	return 0.0 if d >= 1.0 else 0.5 + 0.5 * cos(d * PI)


static func _falloff(p: Vector2, center: Vector2, radius: float) -> float:
	return smoothstep(radius, radius * 0.3, p.distance_to(center))


static func _plateau(p: Vector2, center: Vector2, radius: float, blend: float) -> float:
	return smoothstep(radius + blend, radius, p.distance_to(center))
